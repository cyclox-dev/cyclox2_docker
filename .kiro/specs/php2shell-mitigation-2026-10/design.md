# 設計: PHP2Shell（CVE-2026-109618 / 109619）暫定対策

## 1. 全体方針

公式見解は「設定で完全には防げない。更新だけが安全」。本設計は攻撃の成立条件を減らす多層の暫定策であり、恒久対応（PHP 更新）を置き換えない。

| 層 | 対策 | 効く対象 |
|---|---|---|
| Web サーバー（PHP より前） | ressys: GET/HEAD 以外を 403。web: 許可URL以外の multipart を 403。LimitRequestBody | 109618 の主入口（multipart）、mod_php のフォームPOST経路 |
| PHP 設定（起動時） | memory_limit=-1、post_max_size=8M、upload_progress=0 ほか | 109618 の OOM 経路、109619 の upload_progress 経路 |
| リクエスト単位設定の除去 | php.conf の php_value を php.d へ移設 | 109619 の経路③ |
| ワーカー使い捨て | MaxRequestsPerChild 1 ＋ KeepAlive Off | 109619 のリクエスト跨ぎ全般 |

## 2. PHP 設定（追加ファイル `/etc/php.d/99-php2shell.ini`）

php.ini 本体は触らず、最後に読まれる追加ファイルで上書きする。切り戻しはファイル名を `.ini` 以外に変えて再起動するだけ。

```ini
; PHP2Shell (CVE-2026-109618/109619) 暫定対策 2026-10
; 恒久対応(PHP更新)後に memory_limit を有限値へ戻すこと
memory_limit = -1
post_max_size = 8M
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
| memory_limit | -1 | 公式が「更新できない場合の主な設定」とする。1リクエストがメモリを使い切れるようになるため、手順書で監視する |
| post_max_size | 8M | 公式推奨（アップロード有りでも 8M で足りる: CSV 上限 2M） |
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
# PHP2Shell 暫定対策 2026-10: multipart は CSV 読込と API(.json) のみ許可
RewriteEngine On
RewriteCond %{HTTP:Content-Type} multipart/ [NC]
RewriteCond %{REQUEST_URI} !/entry_categories/check_result_file/
RewriteCond %{REQUEST_URI} !\.json$
RewriteRule ^ - [F]
LimitRequestBody 10485760
```

- multipart を受けるのは CSV 読込（`EntryCategoriesController::check_result_file`）だけ。
- 計測アプリ（Cyclox2.jar）の API は `*.json` の URL に POST する（`AppController::_isApiCall`）。送信形式（urlencoded か multipart か）が確認できていないため API は許可しておく。
- **限界**: 許可した URL には攻撃者も multipart を送れる。この遮断は「任意の URL を狙う無差別な攻撃」を減らすものであり、許可 URL への狙い撃ちは PHP 設定の層だけで受ける。
- 既存の VirtualHost に RewriteEngine とルール（https リダイレクト等）がある場合は、その前に Include する。

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
- コスト: 1接続ごとに fork が発生し、応答が遅くなりCPU負荷が上がる。HTTPS では接続ごとに TLS ハンドシェイクが発生する。大会当日のアクセス集中時に応答を監視する。
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

- cyclox2_svr の php.ini マウント先 `/usr/local/etc/php/php.ini` は、イメージが読む場所ではない（実際は `/etc/opt/rh/rh-php73/php.ini`）。本番と同じく追加ファイル `99-php2shell.ini` を `/etc/opt/rh/rh-php73/php.d/` にマウントする方式に揃え、既存のマウントの扱いはフェーズ2で決める。
- Rewrite ルールと MPM 設定を両コンテナの httpd 設定に反映する。
- テスト（先行作成）: Web 経由の ini 値、multipart / POST の 403、CSV 読込・ログイン・API・ressys 閲覧の回帰。

## 8. 技術要件・制約チェック

| 項目 | 確認 |
|---|---|
| 公開インターフェース | ressys の POST、web の許可 URL 以外への multipart を拒否する（外部から見た挙動の変更）。正規の利用経路は無い・許可済みであることを確認済み |
| 秘密情報 | 本番のホスト名・IP・ドメインは本 spec に書かない（`<ドメイン>` 等で表記） |
| 可逆性 | 追加ファイル・Include 行・コメントアウトの解除と再起動で戻せる |
| リソース | memory_limit=-1 でメモリが上限なしになる。手順書で監視手順と判断基準を定める |
| 恒久対応 | PHP 更新が必要。steering / roadmap に記録する |
