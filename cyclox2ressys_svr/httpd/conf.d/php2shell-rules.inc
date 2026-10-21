# PHP2Shell 暫定対策 2026-10: ressys は閲覧専用のため GET/HEAD 以外を PHP 到達前に拒否
RewriteEngine On
RewriteCond %{REQUEST_METHOD} !^(GET|HEAD)$
RewriteRule ^ - [F]
LimitRequestBody 1048576
