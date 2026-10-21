#!/usr/bin/env bash
# PHP2Shell 暫定対策のローカル検証（使い捨てコンテナで実施。常駐コンテナには触れない）
#
#   verify_local.sh up        # 使い捨てコンテナを起動（docker-compose.yml と同じマウント構成）
#   verify_local.sh test      # 検証を実行（失敗があれば終了コード 1）
#   verify_local.sh down      # 使い捨てコンテナを削除
#
# 前提: 常駐の cyclox2_mysql が起動中、web のサブモジュールを worktree で init 済み、
#       メインチェックアウトに .env と cyclox2_svr/cyclox2_conf/database.php がある。
#       環境変数 MAIN_CHECKOUT でメインチェックアウトのパスを上書きできる。
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MAIN="${MAIN_CHECKOUT:-$(cd "$ROOT" && git worktree list --porcelain | awk '/^worktree /{print $2; exit}')}"
NET=cyclox2_docker_fixed_compose_network
WEB=php2shell_verify_web
RES=php2shell_verify_ressys
WEB_HTTP=8090
WEB_HTTPS=8493
RES_HTTP=8092

# docker-compose.yml の各サービスの volumes を読み、ホスト側の相対パスを $ROOT 基準に直して -v 引数にする。
# database.php（git 管理外）はメインチェックアウトのものを使う。
compose_volumes() {
  local svc="$1"
  awk -v svc="$svc" '
    $0 ~ "^  "svc":" {in_svc=1; next}
    in_svc && /^  [a-z]/ {in_svc=0}
    in_svc && /^    volumes:/ {in_vol=1; next}
    in_svc && in_vol && /^      #/ {next}
    in_svc && in_vol && /^      - / {sub(/^      - /,""); print; next}
    in_svc && in_vol && !/^      - / {in_vol=0}
  ' "$ROOT/docker-compose.yml" | while IFS= read -r v; do
    local host="${v%%:*}" cont="${v#*:}"
    host="${host#./}"
    if [ "$host" = "cyclox2_svr/cyclox2_conf/database.php" ]; then
      echo "-v" "$MAIN/$host:$cont:ro"
    else
      echo "-v" "$ROOT/$host:$cont"
    fi
  done
}

up() {
  set -a; . "$MAIN/.env"; set +a
  # shellcheck disable=SC2046
  docker run -d --name "$WEB" --network "$NET" --memory=1g --user 0:0 \
    -p "$WEB_HTTP:80" -p "$WEB_HTTPS:443" \
    $(compose_volumes cyclox2_svr | tr '\n' ' ') \
    kyamady/img_cyclox2_svr >/dev/null || return 1
  # shellcheck disable=SC2046
  docker run -d --name "$RES" --network "$NET" --memory=1g --user 0:0 \
    -p "$RES_HTTP:80" \
    -e DB_HOSTNAME=cyclox2_mysql -e DB_USERNAME="$RESSYS_DB_USERNAME" \
    -e DB_PASSWORD="$RESSYS_DB_PASSWORD" -e DB_DATABASE=cyclox2 \
    $(compose_volumes cyclox2ressys_svr | tr '\n' ' ') \
    kyamady/img_cyclox2ressys_svr >/dev/null || return 1
  # web のログは worktree にマウントされ残るため、前回分を消してから数える
  docker exec "$WEB" sh -c ': > /var/www/html/logs/error_log; : > /var/www/html/logs/ssl_error_log'
  for i in $(seq 1 30); do
    curl -s -o /dev/null "http://localhost:$WEB_HTTP/" && curl -s -o /dev/null "http://localhost:$RES_HTTP/" && break
    sleep 1
  done
  echo "up: web http=$WEB_HTTP https=$WEB_HTTPS / ressys http=$RES_HTTP"
}

down() { docker rm -f "$WEB" "$RES" >/dev/null 2>&1; echo "down"; }

# ---- 検証 ----
PASS=0; FAIL=0
check() { # check <ID> <説明> <期待> <実際>
  if [ "$3" = "$4" ]; then PASS=$((PASS+1)); printf 'PASS %-5s %s\n' "$1" "$2"
  else FAIL=$((FAIL+1)); printf 'FAIL %-5s %s（期待=%s 実際=%s）\n' "$1" "$2" "$3" "$4"; fi
}
check_not() { # check_not <ID> <説明> <期待しない値> <実際>
  if [ "$3" != "$4" ]; then PASS=$((PASS+1)); printf 'PASS %-5s %s（%s）\n' "$1" "$2" "$4"
  else FAIL=$((FAIL+1)); printf 'FAIL %-5s %s（%s になった）\n' "$1" "$2" "$4"; fi
}
check_rejected() { # check_rejected <ID> <説明> <実際>  403 か 413 なら合格（どちらも PHP 到達前の拒否。警告が出ないことは W-LOG で確認）
  case "$3" in 403|413) PASS=$((PASS+1)); printf 'PASS %-5s %s（%s）\n' "$1" "$2" "$3" ;;
    *) FAIL=$((FAIL+1)); printf 'FAIL %-5s %s（403/413 でなく %s）\n' "$1" "$2" "$3" ;; esac
}
# web の error_log にある post_max_size 超過警告の件数（PHP 到達前に拒否できたかを個別に確かめる）
exceeds() { docker exec "$WEB" sh -c "cat /var/www/html/logs/error_log /var/www/html/logs/ssl_error_log 2>/dev/null | grep -c 'exceeds the limit' || true" | tr -d ' '; }
rejected_before_php() { # rejected_before_php <ID> <説明> <curl の引数...>  403/413 かつ警告が増えないこと
  local id="$1" desc="$2" before st; shift 2
  before="$(exceeds)"; st="$(code "$@")"
  check_rejected "$id" "$desc" "$st"
  check "$id-LOG" "$desc: PHP の超過警告が出ない" "$before" "$(exceeds)"
}
code() { curl -sk -o /dev/null -w '%{http_code}' "$@"; }

CHECK_PHP='<?php header("Content-Type: text/plain"); echo "sapi=", php_sapi_name(), "\n", "pid=", getmypid(), "\n"; foreach (array("memory_limit","post_max_size","upload_max_filesize","session.upload_progress.enabled","soap.wsdl_cache_dir") as $k) { echo $k, "=", var_export(ini_get($k), true), "\n"; }'
NAME="php2shell_check_$$.php"
WEB_CHECK_DIR=/var/www/html/app/webroot
RES_CHECK_DIR=/var/www/html/ajocc_xsys/public/assets

put_check() { docker exec -i "$1" sh -c "cat > '$2/$NAME'" <<<"$CHECK_PHP"; }
rm_check() { docker exec "$WEB" rm -f "$WEB_CHECK_DIR/$NAME" 2>/dev/null; docker exec "$RES" rm -f "$RES_CHECK_DIR/$NAME" 2>/dev/null; }
val() { grep "^$1=" <<<"$2" | head -1 | cut -d= -f2-; }

ini_checks() { # ini_checks <ID接頭辞> <URL> <期待する post_max_size>
  local out; out="$(curl -s "$2")"
  check "$1-1" "SAPI が mod_php" "apache2handler" "$(val sapi "$out")"
  check "$1-2" "memory_limit=-1" "'-1'" "$(val memory_limit "$out")"
  check "$1-3" "post_max_size=$3" "'$3'" "$(val post_max_size "$out")"
  check "$1-4" "upload_max_filesize=2M" "'2M'" "$(val upload_max_filesize "$out")"
  local up; up="$(val session.upload_progress.enabled "$out")"
  if [ "$up" = "'0'" ] || [ "$up" = "''" ]; then check "$1-5" "session.upload_progress.enabled=0" x x
  else check "$1-5" "session.upload_progress.enabled=0" "'0'" "$up"; fi
  check "$1-6" "soap.wsdl_cache_dir は php.d の値（php_value 移設後も同値）" \
    "'/var/opt/rh/rh-php73/lib/php/wsdlcache'" "$(val soap.wsdl_cache_dir "$out")"
}

worker_checks() { # worker_checks <ID接頭辞> <URL>
  # 子プロセス数（既定で最大 10 程度）より多い 20 回を順に送る。使い捨てなら PID は全て異なる。
  local pids hdr i n
  pids="$(for i in $(seq 1 20); do val pid "$(curl -s "$2")"; done)"
  n="$(sort -u <<<"$pids" | grep -c .)"
  check "$1-1" "20 回の連続リクエストが全て別の子プロセスで処理される（MaxConnectionsPerChild 1）" "20" "$n"
  hdr="$(curl -s -o /dev/null -D - --http1.1 "$2" | tr -d '\r' | grep -i '^connection:' | awk '{print tolower($2)}')"
  check "$1-2" "KeepAlive Off（Connection: close）" "close" "$hdr"
}

test_all() {
  trap rm_check EXIT
  put_check "$WEB" "$WEB_CHECK_DIR"; put_check "$RES" "$RES_CHECK_DIR"
  # ローカルの 443 番 VirtualHost は SSL が有効になっておらず平文 HTTP を返す（既存の状態）。
  # VirtualHost への Include の確認が目的なので、http で叩く。
  local W="http://localhost:$WEB_HTTP" WS="http://localhost:$WEB_HTTPS" R="http://localhost:$RES_HTTP"

  echo "== web: PHP 設定（Web 経由）"; ini_checks W-INI "$W/$NAME" 10M
  echo "== ressys: PHP 設定（Web 経由）"; ini_checks R-INI "$R/assets/$NAME" 8M

  echo "== php.conf の php_value が無効化されている"
  # M2 の参考: max_input_vars 超の GET は ini では防げない（ワーカー使い捨てが主な防御）。ここでは扱わない
  check W-PV "web: 有効な php_value が無い" "0" "$(docker exec "$WEB" sh -c "grep -rhE '^[[:space:]]*php_(admin_)?(value|flag)' /etc/httpd/conf /etc/httpd/conf.d | wc -l" | tr -d ' ')"
  check R-PV "ressys: 有効な php_value が無い" "0" "$(docker exec "$RES" sh -c "grep -rhE '^[[:space:]]*php_(admin_)?(value|flag)' /etc/httpd/conf /etc/httpd/conf.d | wc -l" | tr -d ' ')"

  echo "== web: multipart の遮断（http）"
  check W-MP1 "トップへの multipart は 403" "403" "$(code -F x=1 "$W/")"
  check W-MP2 "任意の画面への multipart は 403" "403" "$(code -F x=1 "$W/racers/index")"
  check W-MP3 "Content-Type の大文字小文字を変えても 403" "403" "$(code -H 'Content-Type: Multipart/Form-Data; boundary=x' --data-binary $'--x--\r\n' "$W/")"
  check_not W-MP4 "CSV 読込 URL への multipart は通す" "403" "$(code -F x=1 "$W/entry_categories/check_result_file/1")"
  check W-MP14 "許可 URL を別の URL の後ろに付けても 403（部分一致ですり抜けない）" "403" "$(code -F x=1 "$W/racers/index/entry_categories/check_result_file/")"
  check W-MP15 "index.php 経由の許可 URL への multipart は 403" "403" "$(code -F x=1 "$W/index.php/entry_categories/check_result_file/1")"
  check W-MP5 "API(.json) への multipart も 403（計測アプリは multipart を使わない）" "403" "$(code -F x=1 "$W/api/updated_meet_codes.json")"
  check W-MP5b "任意の URL の末尾に .json を付けた multipart も 403" "403" "$(code -F x=1 "$W/racers/index.json")"
  check_not W-MP5c "計測アプリと同じ application/json の POST は通す" "403" "$(code -H 'Content-Type: application/json' -d '{}' "$W/api/add_entry.json")"
  check_not W-MP6 "通常のフォーム POST（ログイン）は通す" "403" "$(code -d 'data[User][email]=x' "$W/users/login")"
  check W-MP7 "GET の画面表示は従来どおり（ログイン画面 200）" "200" "$(code "$W/users/login")"
  head -c 11000000 /dev/zero > "/tmp/php2shell_big_$$.bin"
  rejected_before_php W-MP8 "1000万バイト以上の multipart は許可 URL でも拒否" -F "f=@/tmp/php2shell_big_$$.bin" "$W/entry_categories/check_result_file/1"
  rejected_before_php W-MP9 "Content-Length 11MB の urlencoded POST は拒否" -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@/tmp/php2shell_big_$$.bin" "$W/users/login"
  check W-MP10 "chunked で 11MB 送ると LimitRequestBody で 413" "413" "$(code -H 'Transfer-Encoding: chunked' -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@/tmp/php2shell_big_$$.bin" "$W/users/login")"
  head -c 10000000 /dev/zero > "/tmp/php2shell_big_$$.bin"
  check W-MP11 "ちょうど1000万バイト（8桁）の POST は 403" "403" "$(code -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@/tmp/php2shell_big_$$.bin" "$W/users/login")"
  head -c 11000000 /dev/zero > "/tmp/php2shell_big_$$.bin"
  rejected_before_php W-MP13 "Content-Length に + を付けた 11MB（+11000000）も拒否" -H 'Content-Type: application/x-www-form-urlencoded' -H 'Content-Length: +11000000' --data-binary "@/tmp/php2shell_big_$$.bin" "$W/users/login"
  head -c 9999999 /dev/zero > "/tmp/php2shell_big_$$.bin"
  check_not W-MP12 "9,999,999 バイト（7桁）の POST は PHP まで届く（post_max_size 10M 以内）" "403" "$(code -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@/tmp/php2shell_big_$$.bin" "$W/users/login")"
  rm -f "/tmp/php2shell_big_$$.bin"

  echo "== web: multipart の遮断（443 番の VirtualHost）"
  check W-MPS1 "443 の VirtualHost でもトップへの multipart は 403" "403" "$(code -F x=1 "$WS/")"
  check_not W-MPS2 "443 の VirtualHost でも CSV 読込 URL は通す" "403" "$(code -F x=1 "$WS/entry_categories/check_result_file/1")"

  echo "== ressys: GET/HEAD 以外の遮断"
  check R-M1 "POST は 403" "403" "$(code -X POST "$R/")"
  check R-M2 "multipart POST は 403" "403" "$(code -F x=1 "$R/")"
  check R-M3 "PUT は 403" "403" "$(code -X PUT "$R/")"
  check R-M4 "GET トップは 200" "200" "$(code "$R/")"
  check R-M5 "HEAD トップは 200" "200" "$(code -I "$R/")"
  check R-M6 "GET の選手検索（フォームは GET）は 200" "200" "$(code "$R/racers?keyword=a")"

  echo "== ressys: 8443 番（SSL）の VirtualHost でも同じ遮断（ポート非公開のためコンテナ内から確認）"
  check R-SSL1 "8443 で POST は 403" "403" "$(docker exec "$RES" curl -sk -o /dev/null -w '%{http_code}' -X POST https://localhost:8443/)"
  check R-SSL2 "8443 で multipart は 403" "403" "$(docker exec "$RES" curl -sk -o /dev/null -w '%{http_code}' -F x=1 https://localhost:8443/)"
  check R-SSL3 "8443 で GET は 200" "200" "$(docker exec "$RES" curl -sk -o /dev/null -w '%{http_code}' https://localhost:8443/)"

  echo "== ワーカーの使い捨て"
  worker_checks W-WK "$W/$NAME"
  worker_checks R-WK "$R/assets/$NAME"

  echo "== 起動・リクエスト時に PHP の警告が出ていない"
  check W-LOG "web: error_log に PHP の警告が無い" "0" "$(docker exec "$WEB" sh -c "cat /var/www/html/logs/error_log /var/www/html/logs/ssl_error_log 2>/dev/null | grep -ciE 'PHP (Warning|Notice|Deprecated|Startup)' || true" | tr -d ' ')"
  check R-LOG "ressys: error_log に PHP の警告が無い" "0" "$(docker exec "$RES" sh -c "grep -ciE 'PHP (Warning|Notice|Deprecated|Startup)' /var/log/httpd24/error_log 2>/dev/null || true" | tr -d ' ')"

  echo "---- PASS=$PASS FAIL=$FAIL"
  [ "$FAIL" -eq 0 ]
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  test) test_all ;;
  *) echo "usage: $0 up|test|down" >&2; exit 2 ;;
esac
