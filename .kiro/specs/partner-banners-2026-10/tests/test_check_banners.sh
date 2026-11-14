#!/usr/bin/env bash
# check_banners.py の回帰テスト。res-sys の過去コミットのテンプレートを一時ディレクトリに展開し、
# www の基準HTML（tests/fixtures/www-13.html、2026-11-08 時点の www トップページ抜粋）と比較する。
# 使い方: bash tests/test_check_banners.sh <cyclox2res_sys のパス>
set -u
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../check_banners.py"
repo=${1:?cyclox2res_sys のパスを指定}
fixture="file://$here/fixtures/www-13.html"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0

extract() { # $1=commit $2=dir
  mkdir -p "$2/application/views/templates"
  for f in header footer; do
    git -C "$repo" show "$1:application/views/templates/$f.php" > "$2/application/views/templates/$f.php"
  done
}
expect() { # $1=名前 $2=期待終了コード $3=出力に含むべき文字列(空可) 以降=コマンド
  local name=$1 code=$2 needle=$3; shift 3
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" != "$code" ] || { [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; }; then
    echo "FAIL $name (rc=$rc, 期待=$code, 文字列='$needle')"; echo "$out" | sed 's/^/    /'; fail=1
  else echo "PASS $name"; fi
}

extract da7abc9 "$tmp/ok";   extract c5ad656 "$tmp/old11"
expect "13件一致(da7abc9)は OK"            0 "OK   application/views/templates/header.php (13件)" python3 "$script" "$tmp/ok" --url "$fixture"
expect "11件(c5ad656)は GALFER 欠落で NG"  1 "欠落: <li><a href=\"http://www.nasktrading.biz/\"" python3 "$script" "$tmp/old11" --url "$fixture"
expect "NG 時は貼り付け用の全行を出す"      1 "#ptnr_logo_list01 の <li> を次の13行にする" python3 "$script" "$tmp/old11" --url "$fixture"

# 相対パス画像の検出（data 側で 404 になる）
cp -r "$tmp/ok" "$tmp/rel"
sed -i '' 's#https://www.cyclocross.jp/img/partners/ptnr_logo_actcyc.png#/img/partners/ptnr_logo_actcyc.png#' "$tmp/rel/application/views/templates/footer.php"
expect "相対パス画像は NG"                  1 "相対パス画像あり" python3 "$script" "$tmp/rel" --url "$fixture"

# 順序違い
cp -r "$tmp/ok" "$tmp/order"
python3 - "$tmp/order/application/views/templates/header.php" <<'PY'
import sys,re; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
g=re.search(r'^.*alt="GALFER".*\n',s,re.M).group(0); r=re.search(r'^.*alt="RDCX".*\n',s,re.M).group(0)
s=s.replace(g+r,r+g); open(p,'w',encoding='utf-8').write(s)
PY
expect "順序違いは NG"                      1 "(順序のみ不一致)" python3 "$script" "$tmp/order" --url "$fixture"

# 重複は原因行を「重複」として表示する
cp -r "$tmp/ok" "$tmp/dup"
python3 - "$tmp/dup/application/views/templates/header.php" <<'PY'
import sys,re; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
g=re.search(r'^.*alt="GALFER".*\n',s,re.M).group(0); s=s.replace(g,g+g); open(p,'w',encoding='utf-8').write(s)
PY
expect "重複は原因行を表示して NG"          1 '重複: <li><a href="http://www.nasktrading.biz/" target="_blank"><img src="https://www.cyclocross.jp/img/partners/ptnr_logo_galfer.svg"' python3 "$script" "$tmp/dup" --url "$fixture"

# テンプレートが無い場合は Traceback ではなく NG 表示
cp -r "$tmp/ok" "$tmp/nofile"; rm "$tmp/nofile/application/views/templates/footer.php"
expect "テンプレート無しは NG 表示"          1 "NG   application/views/templates/footer.php: ファイルが見つかりません" python3 "$script" "$tmp/nofile" --url "$fixture"
expect "テンプレート無しで Traceback を出さない" 0 "" bash -c 'if python3 "$0" "$1" --url "$2" 2>&1 | grep -q Traceback; then exit 1; fi' "$script" "$tmp/nofile" "$fixture"

# 取得失敗は終了コード2
expect "www 取得失敗は rc=2"                2 "取得に失敗" python3 "$script" "$tmp/ok" --url "file://$tmp/does-not-exist.html"

# 旧スナップショットモード（2026-10-03 の10件）も残す
extract 94ab475 "$tmp/snap10"
expect "--snapshot は 10件時点で OK"        0 "(10件)" python3 "$script" "$tmp/snap10" --snapshot

exit $fail
