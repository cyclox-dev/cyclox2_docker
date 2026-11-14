# PHP 実行環境のセキュリティ上の注意

## 対象

cyclox2web・cyclox2res-sys の PHP / Apache の設定を変えるとき（脆弱性の暫定対策、ini の変更、
Rewrite ルールの追加など）。詳細な経緯は `.kiro/specs/php2shell-mitigation-2026-10/` を参照。

## 環境の事実（2026-10-22 時点）

- 本番: cyclox-web は PHP 5.6.40、ressys は PHP 7.1.12。どちらも Apache + mod_php（prefork）で、
  公式のセキュリティ修正が出ないバージョン。各アプリの `doc/update_plan` にあるバージョン記載は古い。
- **PHP の更新（恒久対応）が未実施。** 2026-10 の PHP2Shell（CVE-2026-109618/109619）は設定による
  暫定対策のみで、`memory_limit = -1` など恒久対応後に戻す設定が残っている（spec の runbook.md 10.）。
- ローカル: 両コンテナとも centos/php-73（PHP 7.3、httpd 2.4、mod_php）。PHP の設定は
  `/etc/opt/rh/rh-php73/php.ini` と `php.d/`。**docker-compose.yml の `cyclox2_svr/php/php.ini` の
  マウント先（`/usr/local/etc/php/php.ini`）は読まれていない。** 設定を足すときは php.d へのマウントを使う。

## 押さえるべき仕組み

1. **mod_php はリクエスト開始時の警告が危険になりうる。** リクエスト単位の ini 設定（`.htaccess` や
   httpd 設定の `php_value`）や、`post_max_size` を超える POST が出す警告は、アプリのコードより前に出る。
   PHP2Shell ではこの種の警告が悪用経路になった。`php_value` は使わず php.ini / php.d に書く。
   ただし ini 設定だけでは塞ぎきれない（GET パラメータを `max_input_vars` 超で送るだけで警告が出る）。
   2026-10 時点の主な防御はワーカーの使い捨て（`MaxRequestsPerChild 1` ＋ `KeepAlive Off`）で、
   これは prefork の補充速度のためサーバーごとに毎秒約32接続の上限を生む（その兆候の `server seems busy` は
   info レベルで、標準の `LogLevel warn` では記録されない）。外すときは人間が判断する。
2. **`LimitRequestBody` は mod_php の手前では効かない。** PHP は本文を読む前に `Content-Length` と
   `post_max_size` を比べて警告を出し、その後で Apache が 413 を返す。本文の大きさで PHP に渡さない
   ようにするには mod_rewrite で `%{HTTP:Content-Length}` を見て拒否する。
3. **CakePHP（cyclox2web）の `.htaccess` は index.php へ内部リダイレクトする。** サーバー / VirtualHost の
   Rewrite ルールは内部リダイレクト後にも再評価され、`REQUEST_URI` が `/index.php` になる。URL で例外を
   作るルールには `RewriteCond %{ENV:REDIRECT_STATUS} ^$` を付けて最初のリクエストだけで判定する。
4. **サーバー全体の Rewrite ルールは VirtualHost に継承されない。** http と https の各 VirtualHost に
   Include する。
5. 設定の反映は httpd の完全再起動で行い（graceful では古い子プロセスが残る）、値は CLI ではなく
   Web 経由（mod_php）で確かめる。

- 計測アプリ（Cyclox2.jar）は API に `Content-Type: application/json` で POST し、multipart を使わない
  （`jp.ajocc.cyclox2.dat.ApiManager`、2023〜2026 の jar で確認）。cyclox2web で multipart を受けるのは
  CSV 読込（`/entry_categories/check_result_file/<id>`）だけ。

## 検証方法

`.kiro/specs/php2shell-mitigation-2026-10/verify_local.sh` が、docker-compose.yml と同じマウント構成の
使い捨てコンテナで ini 値・遮断ルール・警告の有無を確かめる。Apache / PHP の設定を変えたら再実行する。
