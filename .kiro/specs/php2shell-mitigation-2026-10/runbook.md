# 本番適用手順書: PHP2Shell 暫定対策（cyclox-web / ressys）

設計の根拠は [design.md](design.md)。ホスト名・ドメイン・IP は本書に書かない。`<web-domain>` `<ressys-domain>` は実際の値に置き換える。

- 両サーバーとも同じ流れ。サーバーごとの違いは【web】【ressys】で示す。
- 編集・再起動には sudo が必要。
- 1台ずつ行う。**ressys を先に**（閲覧専用で影響が小さく、手順の確認になる）。
- 作業中は各手順の出力を控えておき、`test-results.md` に貼る（ホスト名・IP は伏せる）。

---

## 0. 事前確認（読み取りのみ。変更はしない）

```bash
cat /etc/redhat-release; httpd -v; httpd -V | grep -i mpm
```

- httpd のバージョン（2.2 / 2.4）と MPM（prefork のはず）を控える。
- CentOS 6 なら再起動は `service httpd ...`、CentOS 7 なら `systemctl ... httpd`。

```bash
php --ini
```

- 【web】`Scan for additional .ini files in:` が `/etc/php.d` であることを確認する。違う場合は、以降の `/etc/php.d/` をそのディレクトリに読み替える。スキャン先が無い（`(none)`）場合は中止して相談。

```bash
php -r 'foreach (array("memory_limit","post_max_size","upload_max_filesize","session.upload_progress.enabled","session.save_handler","session.save_path","open_basedir","always_populate_raw_post_data") as $k) echo $k,"=",var_export(ini_get($k),true),"\n";'
```

- 現在の値を控える（切り戻し時の参考）。
- `memory_limit` は `128M` のはず（2026-10-22 にユーザーが本番 `/etc/php.ini` で確認）。**違う値だった場合は、2. の追加ファイルの「適用前の memory_limit」行をその値に書き換え、agreement-log.md にも記録する。**
- **中止条件**: `upload_max_filesize` が 2M を超えている → CSV のサイズ要件を確認してから値を決めるため、中止して相談。

```bash
sudo httpd -S
```

- アプリを提供している VirtualHost（http と https）の設定ファイルと行番号を控える。VirtualHost が無い構成なら、5. の Include 先は `/etc/httpd/conf/httpd.conf` になる。

```bash
grep -rnE 'RewriteEngine|DocumentRoot|KeepAlive |MaxRequestsPerChild|MaxConnectionsPerChild|MaxClients|MaxRequestWorkers' /etc/httpd/conf /etc/httpd/conf.d /etc/httpd/conf.modules.d 2>/dev/null
```

- DocumentRoot（7. の確認用ファイルの置き場所）と、既存の Rewrite 設定・KeepAlive・子プロセス数を控える。

```bash
free -m; ps -C httpd -o pid,rss,cmd --sort=-rss | head -5
```

- 空きメモリと httpd の最大 RSS を控える（memory_limit=-1 後の比較用）。

```bash
sudo grep -iE 'PHP (Warning|Deprecated|Notice).*(Unknown|on line 0|Startup)' /var/log/httpd/error_log | tail -20
```

- 起動時やリクエスト開始時に PHP の警告が出ていないか確認する。出ている場合は内容を控えて相談（109619 の経路③に当たりうる）。

---

## 1. バックアップ

```bash
sudo cp -p /etc/httpd/conf.d/php.conf /etc/httpd/conf.d/php.conf.bak-20261022
```

VirtualHost を定義しているファイルも同様にバックアップする（0. で控えたファイル）。

```bash
sudo cp -p <VirtualHostの設定ファイル> <VirtualHostの設定ファイル>.bak-20261022
```

**注意**: バックアップ名は `.conf` で終わらせない（`conf.d/*.conf` は自動で読み込まれる）。

---

## 2. PHP 設定の追加ファイルを作成

【ressys】

```bash
sudo tee /etc/php.d/99-php2shell.ini > /dev/null <<'EOF'
; PHP2Shell (CVE-2026-109618/109619) 暫定対策 2026-10
; 恒久対応(PHP更新)後に memory_limit を有限値へ戻すこと
; 適用前の memory_limit = 128M （/etc/php.ini の値。戻すときはこの値）
memory_limit = -1
post_max_size = 8M
upload_max_filesize = 2M
session.upload_progress.enabled = 0
; /etc/httpd/conf.d/php.conf の php_value から移設（値は同一）
session.save_handler = files
session.save_path = "/var/lib/php/session"
soap.wsdl_cache_dir = "/var/lib/php/wsdlcache"
EOF
```

【web】上と同じ内容に、末尾の1行を加える。

```bash
sudo tee /etc/php.d/99-php2shell.ini > /dev/null <<'EOF'
; PHP2Shell (CVE-2026-109618/109619) 暫定対策 2026-10
; 恒久対応(PHP更新)後に memory_limit を有限値へ戻すこと
; 適用前の memory_limit = 128M （/etc/php.ini の値。戻すときはこの値）
memory_limit = -1
post_max_size = 8M
upload_max_filesize = 2M
session.upload_progress.enabled = 0
; /etc/httpd/conf.d/php.conf の php_value から移設（値は同一）
session.save_handler = files
session.save_path = "/var/lib/php/session"
soap.wsdl_cache_dir = "/var/lib/php/wsdlcache"
; PHP 5.6: 生POSTの自動格納を止め、リクエスト開始時の E_DEPRECATED を出さない
always_populate_raw_post_data = -1
EOF
```

CLI で読み込みと警告の有無を確認する（警告が出たら中止）。

```bash
php --ini | grep 99-php2shell; php -r 'echo ini_get("memory_limit"),"\n";' 2>&1
```

---

## 3. php.conf の php_value をコメントアウト

```bash
sudo sed -i -E 's/^([[:space:]]*)php_value (session\.save_handler|session\.save_path|soap\.wsdl_cache_dir)/\1#php_value \2/' /etc/httpd/conf.d/php.conf
```

```bash
grep -n 'php_value' /etc/httpd/conf.d/php.conf
```

- 3行とも `#php_value` になっていることを確認する。

---

## 4. ワーカーの使い捨て

- **中止条件**: 0. の MPM が `prefork` でない → 中止して相談。
- 0. の検索で VirtualHost 内に `KeepAlive On` があった場合は、その行もコメントアウトする（VirtualHost の設定が conf.d より優先されるため）。

```bash
sudo tee /etc/httpd/conf.d/zz-php2shell-mpm.conf > /dev/null <<'EOF'
# PHP2Shell 暫定対策 2026-10: 子プロセスを1接続ごとに作り直し、リクエスト跨ぎの状態を残さない
KeepAlive Off
<IfModule prefork.c>
    MaxRequestsPerChild 1
</IfModule>
EOF
```

---

## 5. Web サーバーの遮断ルールを作成し、各 VirtualHost に Include

【ressys】

```bash
sudo tee /etc/httpd/conf.d/php2shell-rules.inc > /dev/null <<'EOF'
# PHP2Shell 暫定対策 2026-10: ressys は閲覧専用のため GET/HEAD 以外を PHP 到達前に拒否
RewriteEngine On
RewriteCond %{REQUEST_METHOD} !^(GET|HEAD)$
RewriteRule ^ - [F]
LimitRequestBody 1048576
EOF
```

【web】

```bash
sudo tee /etc/httpd/conf.d/php2shell-rules.inc > /dev/null <<'EOF'
# PHP2Shell 暫定対策 2026-10: multipart は CSV 読込と API(.json) のみ許可
RewriteEngine On
RewriteCond %{HTTP:Content-Type} multipart/ [NC]
RewriteCond %{REQUEST_URI} !/entry_categories/check_result_file/
RewriteCond %{REQUEST_URI} !\.json$
RewriteRule ^ - [F]
LimitRequestBody 10485760
EOF
```

アプリを提供する **各 VirtualHost（http / https の両方）** の `<VirtualHost ...>` の直後（既存の Rewrite ルールより前）に、エディタで次の1行を追加する。

```apache
Include conf.d/php2shell-rules.inc
```

---

## 6. 構文確認と完全再起動

```bash
sudo apachectl configtest
```

`Syntax OK` 以外なら再起動せず、5. → 3. → 2. の順に戻す（9. 参照）。

CentOS 7:

```bash
sudo systemctl restart httpd
```

CentOS 6:

```bash
sudo service httpd restart
```

**graceful（`apachectl graceful` / `reload`）は使わない。** mod_php は子プロセスが入れ替わらないと古い状態が残る。

---

## 7. 確認

### 7-1. Web 経由の ini 値

確認用ファイルを推測されにくい名前で置く（`<rand>` は適当な英数字に置き換える）。

- 【web】`<DocumentRoot>/app/webroot/php2shell_check_<rand>.php`（DocumentRoot が webroot そのものなら直下）
- 【ressys】`<ressysの公開ディレクトリ>/assets/php2shell_check_<rand>.php`（`index.php` へのリライト対象外）

```bash
sudo tee <置き場所>/php2shell_check_<rand>.php > /dev/null <<'EOF'
<?php
header('Content-Type: text/plain');
echo php_sapi_name(), ' ', PHP_VERSION, "\n";
foreach (array('memory_limit', 'post_max_size', 'upload_max_filesize',
    'session.upload_progress.enabled', 'session.save_handler', 'session.save_path',
    'always_populate_raw_post_data') as $k) {
    echo $k, '=', var_export(ini_get($k), true), "\n";
}
EOF
```

```bash
curl -s https://<ドメイン>/<公開パス>/php2shell_check_<rand>.php
```

```bash
sudo rm -f <置き場所>/php2shell_check_<rand>.php
```

期待値（**削除まで必ず行う**）:

| 項目 | 期待値 |
|---|---|
| SAPI | `apache2handler` |
| memory_limit | `'-1'` |
| post_max_size / upload_max_filesize | `'8M'` / `'2M'` |
| session.upload_progress.enabled | `'0'` または `''` |
| session.save_handler / save_path | `'files'` / `'/var/lib/php/session'` |
| always_populate_raw_post_data（web） | `'-1'` |

### 7-2. 遮断が効くこと

【ressys】

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://<ressys-domain>/
```

期待値 `403`。

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<ressys-domain>/
```

期待値 `200`。

【web】multipart をトップに送る:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -F x=1 https://<web-domain>/
```

期待値 `403`。

許可した URL には届くこと（403 以外。未ログインなのでログイン画面へのリダイレクトや 401 になる）:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -F x=1 https://<web-domain>/entry_categories/check_result_file/1
```

```bash
curl -s -o /dev/null -w '%{http_code}\n' -F x=1 https://<web-domain>/api/updated_meet_codes.json
```

### 7-3. 機能の回帰（ブラウザ・アプリで確認）

| # | サーバー | 確認内容 | 期待 |
|---|---|---|---|
| 1 | ressys | トップ・大会結果・選手検索・ランキングを開く | 従来どおり表示 |
| 2 | web | ログイン → 何画面か遷移 → しばらく後も ログイン状態が続く | セッションが保たれる |
| 3 | web | 任意の出走カテゴリーで「エントリー・リザルト読込」から CSV を選び、**確認画面まで**進む（書込みボタンは押さない。確認画面までは DB を変更しない） | 確認画面が表示される |
| 4 | web | 計測アプリ（Cyclox2.jar）でサーバーからの同期（ダウンロード）を実行 | エラーにならない |
| 5 | web | 計測アプリからのアップロード | 次に本番で送る機会に確認（テスト目的で本番に送らない） |

### 7-4. エラーログ

```bash
sudo tail -50 /var/log/httpd/error_log
```

- PHP の警告、`Unknown`、`Segmentation fault`、`child pid ... exit signal` が増えていないこと。
- 【web】7-3 の 4・5 で 403 が出たら、`/var/log/httpd/*access_log` の該当行の URL を控えて相談（許可 URL の追加が必要）。

---

## 8. 適用後の監視（memory_limit=-1 の影響）

翌日以降、1日1回程度、および大会の結果アップロード日に確認する。

```bash
free -m; ps -C httpd -o pid,rss,cmd --sort=-rss | head -5
```

- 応答速度: ワーカー使い捨てで1接続ごとにプロセスを作るため、大会の結果公開直後など混雑時に ressys の表示が極端に遅くならないかを見る。遅い場合は相談（4. だけを切り戻せる）。
- 判断基準: 0. の値と比べて httpd の最大 RSS が大きく増えた、または available が総メモリの 10% を切った場合は相談（memory_limit を有限値に戻すかどうかは、主対策を外すことになるため人間判断）。
- error_log に `Out of memory`、`Cannot allocate memory`、OOM killer（`dmesg | grep -i oom`）が出ていないこと。

---

## 9. 切り戻し

問題が出た層だけ戻せる。戻したら 6. の手順で configtest と完全再起動を行う。

| 戻すもの | 手順 |
|---|---|
| 遮断ルール | 各 VirtualHost の `Include conf.d/php2shell-rules.inc` 行を削除（または `cp -p <file>.bak-20261022 <file>`） |
| php_value のコメントアウト | `sudo cp -p /etc/httpd/conf.d/php.conf.bak-20261022 /etc/httpd/conf.d/php.conf` |
| PHP 設定 | `sudo mv /etc/php.d/99-php2shell.ini /etc/php.d/99-php2shell.ini.disabled`（`.ini` 以外にすれば読まれない）。**php.conf の php_value も同時に戻す**（session.save_path の設定元が無くなるため） |
| ワーカー使い捨て | `sudo mv /etc/httpd/conf.d/zz-php2shell-mpm.conf /etc/httpd/conf.d/zz-php2shell-mpm.conf.disabled`（VirtualHost の `KeepAlive On` をコメントアウトした場合はそれも戻す） |

---

## 10. 恒久対応後の後始末

PHP を修正版（または LTS ベンダーのバックポート）へ更新したら:

- `memory_limit` を元の値 `128M`（`99-php2shell.ini` の「適用前の memory_limit」行に記録）に戻す。追加ファイルの `memory_limit = -1` 行を消せば php.ini 本体の値に戻る。
- `session.upload_progress.enabled = 0` は機能を使っていないため維持する（公式も推奨）。
- 遮断ルール・ワーカー使い捨ての継続要否を判断する。
