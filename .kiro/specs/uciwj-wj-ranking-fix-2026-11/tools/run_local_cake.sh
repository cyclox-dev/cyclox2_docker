#!/usr/bin/env bash
# ローカル検証専用: worktree の cyclox2web を使い捨てコンテナで動かし、cake コマンドを実行する。
# 接続先はローカル docker の cyclox2_mysql（本番複製）。本番では使わない。
# 使い方: tools/run_local_cake.sh as_category_check
#         tools/run_local_cake.sh result updateAjoccPtRankings
set -euo pipefail

SPEC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE="$(cd "$SPEC_DIR/../../.." && pwd)"
MAIN_REPO=/Users/kyamady/workspace/cyclox2_docker           # database.php はメインチェックアウトの git 管理外ファイル
APP_TMP="${APP_TMP:-${TMPDIR:-/tmp}/uciwj-apptmp}"

mkdir -p "$APP_TMP"/{cache/models,cache/persistent,logs,sessions}
chmod -R 777 "$APP_TMP"

# ファイル単位のマウントで Docker が worktree 側に作る空のマウント先を、終了時に片付ける
cleanup() {
  for f in "$WORKTREE/cyclox2_svr/cyclox2/app/Console/Command/AsCategoryCheckShell.php" \
           "$WORKTREE/cyclox2_svr/cyclox2/app/Config/database.php"; do
    if [ -f "$f" ] && [ ! -s "$f" ]; then rm -f "$f"; fi
  done
}
trap cleanup EXIT

docker run --rm --memory=1g --network cyclox2_docker_fixed_compose_network --entrypoint bash \
  -v "$WORKTREE/cyclox2_svr/cyclox2:/var/www/html" \
  -v "$MAIN_REPO/cyclox2_svr/cyclox2_conf/database.php:/var/www/html/app/Config/database.php:ro" \
  -v "$APP_TMP:/var/www/html/app/tmp" \
  -v "$SPEC_DIR/tools/AsCategoryCheckShell.php:/var/www/html/app/Console/Command/AsCategoryCheckShell.php:ro" \
  -v "$SPEC_DIR/tools/email_local_debug.php:/var/www/html/app/Config/email.php:ro" \
  kyamady/img_cyclox2_svr -c "cd /var/www/html/app && Console/cake $*"
