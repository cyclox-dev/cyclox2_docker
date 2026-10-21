# PHP2Shell 暫定対策 2026-10: multipart は CSV 読込のみ許可（計測アプリの API は application/json で送るため multipart を使わない）
RewriteEngine On
# 最初のリクエストだけで判定する。CakePHP の .htaccess が index.php へ内部リダイレクトすると
# REQUEST_URI が /index.php に変わり、許可した URL まで拒否してしまうため
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
