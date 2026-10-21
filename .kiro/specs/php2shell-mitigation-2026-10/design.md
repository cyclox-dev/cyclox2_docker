# 設計: PHP2Shell（CVE-2026-109618 / 109619）暫定対策

## 1. 全体方針

公式見解は「設定で完全には防げない。更新だけが安全」。本設計は攻撃の成立条件を減らす多層の暫定策であり、恒久対応（PHP 更新）を置き換えない。

| 層 | 対策 | 効く対象 |
|---|---|---|
| Web サーバー（PHP より前） | ressys: GET/HEAD 以外を 403。web: CSV 読込 URL 以外への multipart と、Content-Length が7桁の数字でない本文を 403。LimitRequestBody | 109618 の主入口（multipart）、mod_php のフォームPOST経路 |
| PHP 設定（起動時） | memory_limit=-1、post_max_size=10M（web）/ 8M（ressys）、upload_progress=0 ほか | 109618 の OOM 経路、109619 の upload_progress 経路 |
| リクエスト単位設定の除去 | php.conf の php_value を php.d へ移設 | 109619 の経路③ |
| ワーカー使い捨て | MaxRequestsPerChild 1 ＋ KeepAlive Off | 109619 のリクエスト跨ぎ全般（109619 への主な防御。処理能力に毎秒約32接続の上限ができる） |

## 2. PHP 設定（追加ファイル `/etc/php.d/99-php2shell.ini`）

php.ini 本体は触らず、最後に読まれる追加ファイルで上書きする。切り戻しはファイル名を `.ini` 以外に変えて再起動するだけ。

```ini
; PHP2Shell (CVE-2026-109618/109619) 暫定対策 2026-10
; 恒久対応(PHP更新)後に memory_limit を有限値へ戻すこと
; 適用前の memory_limit = 128M （/etc/php.ini の値。戻すときはこの値）
memory_limit = -1
post_max_size = 8M   ; web は 10M（下表と 4. を参照）
upload_max_filesize = 2M
session.upload_progress.enabled = 0
; /etc/httpd/conf.d/php.conf の php_value から移設（値は同一）
session.save_handler = files
session.save_path = "/var/lib/php/session"
soap.wsdl_cache_dir = "/var/lib/php/wsdlcache"
```

cyclox-web（PHP 5.6）だけ次の1行を追加する。

```ini
; PHP 5.6: 生POSTの自動格納を止め、リクエスト開始時の E_DEPRECATED を出さない
always_populate_raw_post_data = -1
```

### 値の根拠

| 設定 | 値 | 根拠・注意 |
|---|---|---|
| memory_limit | -1 | 公式が「更新できない場合の主な設定」とする。1リクエストがメモリを使い切れるようになるため、手順書で監視する。**適用前の値は `128M`**（本番 `/etc/php.ini`、2026-10-22 ユーザー確認）。php.ini 本体は書き換えないので値はそこにも残るが、恒久対応後に戻す値として追加ファイルのコメントと本 spec に記録する |
| post_max_size | web 10M / ressys 8M | 公式推奨は 8M（アップロード無し）/ 32M（有り）。web は 2026-10-22 のローカル検証を受けて 10M にした（4. の Content-Length ルールと対で、PHP に届く本文が必ず上限内に収まるようにするため。ユーザー承認）。CSV 上限は 2M なので足りる |
| upload_max_filesize | 2M | 現行ローカル値と同じ。post_max_size 未満を保つ。本番の現行値が 2M を超える場合は事前確認で止めて相談 |
| session.upload_progress.enabled | 0 | 両バージョンとも既定で有効。アプリは使っていない |
| session.save_* / soap.wsdl_cache_dir | 現行と同値 | php.conf からの移設。web は CakePHP の Session `defaults => php` で save_path を使う。ressys は CI3 が `sys_get_temp_dir()` を使うため影響なし。ressys は soap 拡張が無く、行は無視される |
| always_populate_raw_post_data | -1 | **公式勧告に記載は無く、本設計の推論による追加**（2026-10-22 採用）。PHP 5.6 は既定値 0 のとき、フォーム以外の Content-Type の POST でリクエスト開始時に E_DEPRECATED を出す。攻撃者が任意に起こせる早期の警告であり、109619 の経路③と同類と判断した。アプリ（app/ 配下全体）は `$HTTP_RAW_POST_DATA` を使っていない |

### 変更しない設定（保留）

- `max_input_vars` / `max_input_nesting_level`: 公式は引き下げを勧めるが、計測アプリの API（`upload_racers` など）が選手配列を一括POSTしており、上限を下げると同期データが黙って切り捨てられる恐れがある。現行値を維持する。
- `max_multipart_body_parts`: PHP 8.0.29 以降にしか無い。

## 3. php.conf の php_value 無効化

両サーバーの `/etc/httpd/conf.d/php.conf` 47〜49行をコメントアウトする（値は 2. で php.d に移設済み）。

- バックアップは `php.conf.bak-20261022` のように **`.conf` で終わらない名前**にする（`conf.d/*.conf` は自動で読み込まれるため）。
- php.conf はパッケージの設定ファイル（noreplace）なので、PHP パッケージを更新しても上書きされず、新版は `.rpmnew` で置かれる。更新後に php_value が戻っていないか確認する。

## 4. Web サーバー層の遮断（mod_rewrite）

httpd 2.2 / 2.4 のどちらでも動く mod_rewrite で書く。サーバー全体（main server）の Rewrite 設定は VirtualHost に継承されないため、**アプリを提供する各 VirtualHost（http / https の両方）に Include する**。

ルールは `/etc/httpd/conf.d/php2shell-rules.inc` に置く（`.conf` ではないので自動では読まれない）。各 VirtualHost に次の1行を足す。

```apache
Include conf.d/php2shell-rules.inc
```

### ressys 用 `php2shell-rules.inc`

```apache
# PHP2Shell 暫定対策 2026-10: ressys は閲覧専用のため GET/HEAD 以外を PHP 到達前に拒否
RewriteEngine On
RewriteCond %{REQUEST_METHOD} !^(GET|HEAD)$
RewriteRule ^ - [F]
LimitRequestBody 1048576
```

ressys のコントローラ・ビューに POST を受ける箇所は無い（検索フォームも GET）。

### cyclox-web 用 `php2shell-rules.inc`

```apache
# PHP2Shell 暫定対策 2026-10: multipart は CSV 読込のみ許可（計測アプリの API は application/json で送るため multipart を使わない）
RewriteEngine On
# 最初のリクエストだけで判定する（CakePHP の .htaccess が index.php へ内部リダイレクトすると
# REQUEST_URI が /index.php に変わり、許可した URL まで拒否してしまうため）
RewriteCond %{ENV:REDIRECT_STATUS} ^$
RewriteCond %{HTTP:Content-Type} multipart/ [NC]
# 許可 URL は先頭から完全一致で判定する（部分一致だと任意の URL の後ろに付けてすり抜けられる）
RewriteCond %{REQUEST_URI} !^/entry_categories/check_result_file/[0-9]+/?$
RewriteRule ^ - [F]
# Content-Length が「数字だけで7桁以内」（9,999,999 バイト以下）でない本文は PHP に渡さない。
# post_max_size(10M) を超える本文を受け取ると、PHP は本文を読む前（リクエスト開始時）に警告を出すため。
# LimitRequestBody は PHP の手前では効かない。`+11000000` のような表記も Apache は受け付けるので、
# 「8桁以上を拒否」ではなく「7桁以内の数字だけを許可」で書く
RewriteCond %{HTTP:Content-Length} !^$
RewriteCond %{HTTP:Content-Length} !^[0-9]{1,7}$
RewriteRule ^ - [F]
# Content-Length の無い（chunked の）本文を post_max_size で止める
LimitRequestBody 10485760
```

- multipart を受けるのは CSV 読込（`EntryCategoriesController::check_result_file`）だけ。
- 計測アプリ（Cyclox2.jar）の API は `*.json` の URL に POST する（`AppController::_isApiCall`）。jar の `ApiManager` を調べ、`HttpURLConnection` で `Content-Type: application/json` を付けて送っていること、multipart を使っていないことを確認した（2023年版・2026-02版・2026-09版の3つの jar で同じ。2026-10-22）。そのため当初の `.json` の例外は削除した（reviewer 指摘 M1。例外があると、どの URL でも末尾を `.json` にすれば multipart が PHP に届いていた）。
- **限界**: 許可した CSV 読込の URL には攻撃者も multipart を送れる（PHP は認証より前に multipart を解析する）。この URL への狙い撃ちは PHP 設定とワーカー使い捨ての層で受ける。
- 既存の VirtualHost に RewriteEngine とルール（https リダイレクト等）がある場合は、その前に Include する。
- **`REDIRECT_STATUS` の条件は必須**（2026-10-22 ローカル検証で判明）。これが無いと、CakePHP の `.htaccess` による `index.php` への内部リダイレクトの際にルールが再評価され、`REQUEST_URI` が `/index.php` になるため、CSV 読込（と当時許可していた API）まで 403 になる。
- `LimitRequestBody` は PHP の手前では効かない（2026-10-22 ローカル検証で判明）。mod_php は本文を読む前に `Content-Length` と `post_max_size` を比べ、超えていればリクエスト開始時に警告（`POST Content-Length of ... exceeds the limit`）を出す。その後 Apache が本文の読み込みで 413 を返すが、警告はすでに出ている。攻撃者がいつでも起こせる早い段階の警告で、109619 が悪用する種類に当たる。
- そこで `Content-Length` が「数字だけで7桁以内」でない本文を mod_rewrite で拒否し、`post_max_size` を 10M（10,485,760）にする。PHP に届く本文は最大 9,999,999 バイトなので、必ず上限内に収まり警告が出ない。正規表現なので httpd 2.2 でも動く（2.4 の数値比較 `-gt` は 2.2 に無い）。
- 「8桁以上を拒否」と書くと、Apache が受け付ける `Content-Length: +11000000` のような表記ですり抜けられる（tester が再現）。そのため許可する形（7桁以内の数字だけ）で書く。
- 許可 URL は `^/entry_categories/check_result_file/[0-9]+/?$` と先頭から完全一致で判定する。部分一致だと `/racers/index/entry_categories/check_result_file/` のように任意の URL の後ろに付けてすり抜けられる（tester が再現）。本番でアプリがドメイン直下以外に置かれている場合は、手順書 0. で確認して `^` の後にそのパスを足す。
- `Content-Length` の無い chunked の本文は、`LimitRequestBody` を `post_max_size` と同じ 10485760 にして止める（ローカル検証で、11MB の chunked 送信が警告なしで 413 になることを確認）。

## 5. ワーカーの使い捨て（2026-10-22 採用）

prefork の子プロセスを1接続ごとに作り直し、リクエストを跨いで残る状態（109619）をなくす。公式勧告の FPM `pm.max_requests=1` に相当する。

`/etc/httpd/conf.d/zz-php2shell-mpm.conf` に置く（切り戻しはファイル名を `.conf` 以外に変えるだけ）。

```apache
# PHP2Shell 暫定対策 2026-10: 子プロセスを1接続ごとに作り直し、リクエスト跨ぎの状態を残さない
KeepAlive Off
<IfModule prefork.c>
    MaxRequestsPerChild 1
</IfModule>
```

- KeepAlive が On だと1接続で複数リクエストを処理するため、Off も必要。
- `KeepAlive` / `MaxRequestsPerChild` は後に書かれた値が有効になる。CentOS 6（httpd 2.2）の `Include conf.d/*.conf` は httpd.conf の既定値より後、CentOS 7（2.4）の `IncludeOptional conf.d/*.conf` は末尾にあるため、conf.d のファイルが既定値に勝つ。ただし VirtualHost 内に `KeepAlive On` があると、その VirtualHost では負けるため、事前確認で探す。
- httpd 2.4 では `MaxConnectionsPerChild` が正式名だが、旧名 `MaxRequestsPerChild` も受け付ける。
- prefork 以外（worker / event）ではプロセス内でスレッドが状態を共有するため効果が変わる。MPM が prefork でなければ中止して相談。
- コスト: 1接続ごとに fork が発生し、応答が遅くなりCPU負荷が上がる。HTTPS では接続ごとに TLS ハンドシェイクが発生する。
- **処理能力の上限**（reviewer 指摘 B1）: prefork は子プロセスを終了と同時には補充せず、約1秒ごとの保守処理で1回に最大32個まで作る。1接続ごとに子プロセスを使い切るので、**サーバーごとに毎秒約32接続**が持続的な上限になる（静的ファイルも1接続。httpd 2.2 / 2.4 共通）。ressys のイメージでの計測では、静的ファイルで毎秒約25リクエスト（p99 4.8秒）、使い捨てなしでは毎秒約7,000リクエストだった。ressys の1ページに静的ファイルが15〜20個あると、1秒に1.5〜2ページ程度しか返せない。毎秒32接続程度で詰まらせられるので、手軽な DoS の入口にもなる。
- **それでも両サーバーに採用する**（2026-10-22 ユーザー判断、agreement-log 決定17）。理由は次項。手順書 8. で、混雑時の1秒あたりのリクエスト数と応答時間を監視する（`server seems busy` は info レベルで、標準の `LogLevel warn` では記録されないため、ログ検索には頼らない。reviewer 再レビュー指摘）。
- **109619 に対して実際に効くのはこの層だけ**（reviewer 指摘 M2）。ini 設定では、リクエスト開始時の警告を完全には防げない。たとえば GET パラメータを `max_input_vars`（1000）超で送ると `Input variables exceeded` の警告が出る（ressys の GET のみのルールも通る）。Cookie や、壊れた multipart を許可 URL に送っても同様。4. の Content-Length ルールは警告の一部を減らすが、この種類の警告を塞ぎきるものではない。したがって、この層を切り戻すと 109619 への主な防御が外れる。
- 1リクエスト内で完結する攻撃には効かない。

## 6. 確認方法（Web 経由）

CLI の `php -i` は mod_php と異なる値を示しうるため、mod_php で動く確認用ファイルで値を見る。

```php
<?php
header('Content-Type: text/plain');
echo php_sapi_name(), ' ', PHP_VERSION, "\n";
foreach (array('memory_limit', 'post_max_size', 'upload_max_filesize',
    'session.upload_progress.enabled', 'session.save_handler', 'session.save_path',
    'always_populate_raw_post_data') as $k) {
    echo $k, '=', var_export(ini_get($k), true), "\n";
}
```

- 推測されにくい名前で置き、確認後すぐ削除する。
- 置き場所: web は CakePHP の `app/webroot/`（実在ファイルはそのまま配信される）。ressys はリライトで `index.php` に回されない `assets/` 配下。
- 期待値: SAPI `apache2handler`、memory_limit `'-1'`、upload_progress `'0'` または `''`、ほかは 2. の値。

## 7. ローカル（Docker）への反映（フェーズ2）

本番と同じ構成を、両コンテナに docker-compose.yml のマウントで入れる。ローカルは PHP 7.3（rh-php73）・httpd 2.4（prefork）・mod_php。

| ファイル（リポジトリ） | マウント先 | 内容 |
|---|---|---|
| `<svr>/php/99-php2shell.ini` | `/etc/opt/rh/rh-php73/php.d/99-php2shell.ini` | 2. の設定。web は post_max_size 10M。session 系はローカルでは php_value に無いので書かない。`always_populate_raw_post_data` は PHP 7 で廃止のため書かない |
| `<svr>/httpd/conf.d/rh-php73-php.conf` | `/etc/httpd/conf.d/rh-php73-php.conf` | イメージ同梱ファイルの `php_value soap.wsdl_cache_dir` をコメントアウトしたもの（本番の php.conf に相当） |
| `<svr>/httpd/conf.d/php2shell-rules.inc` | `/etc/httpd/conf.d/php2shell-rules.inc` | 4. の遮断ルール |
| `<svr>/httpd/conf.d/zz-php2shell-mpm.conf` | `/etc/httpd/conf.d/zz-php2shell-mpm.conf` | 5. のワーカー使い捨て |

- 遮断ルールは httpd.conf のメインサーバー（80番）に Include する。web は `conf.d/ssl.conf` の `<VirtualHost _default_:443>` にも Include する。
- cyclox2_svr の php.ini マウント（`/usr/local/etc/php/php.ini`）はイメージが読まない場所だが、変更しない（読まれる場所に直すと `extension=pdo_mysql` の二重読み込みで起動時に警告が出るため）。docker-compose.yml にコメントで注記する。
- ローカルの 443 番の VirtualHost は SSL が有効になっておらず平文 HTTP を返す（既存の状態、今回の範囲外）。
- 検証は `verify_local.sh`（使い捨てコンテナで docker-compose.yml と同じマウントを再現）で行い、結果を test-results.md に記録する。

## 8. 技術要件・制約チェック

| 項目 | 確認 |
|---|---|
| 公開インターフェース | ressys の POST、web の許可 URL 以外への multipart を拒否する（外部から見た挙動の変更）。正規の利用経路は無い・許可済みであることを確認済み |
| 秘密情報 | 本番のホスト名・IP・ドメインは本 spec に書かない（`<ドメイン>` 等で表記） |
| 可逆性 | 追加ファイル・Include 行・コメントアウトの解除と再起動で戻せる |
| リソース | memory_limit=-1 でメモリが上限なしになる。手順書で監視手順と判断基準を定める |
| 恒久対応 | PHP 更新が必要。steering / roadmap に記録する |
