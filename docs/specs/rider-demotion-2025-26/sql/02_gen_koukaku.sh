#!/bin/bash
# =====================================================================
# downlist 出力 + 降格SQL(koukaku)生成（再利用可能）
# 前提: 01_build_demote_set.sql 実行済み（cyclox2.demote_all が存在）
# 使い方: bash 02_gen_koukaku.sh <出力先dir>
#
# ★毎年変更: APPLY / CANCEL / NOTE / カテゴリーの降格先(DEST)・ライン方式
# 出力: <dir>/{c1,c2,c3,m1,m2,we1}_downlist.txt
#        <dir>/{c1,c2,c3,m1,m2,we1}_koukaku.sql
# 注意: 二重降格がある場合は別途 00_dup_fix.sql を用意し、該当racerを
#        対応する downlist から手動除外すること（runbook §4参照）。
# =====================================================================
set -euo pipefail
OUT="${1:?usage: bash 02_gen_koukaku.sh <出力先dir>}"
mkdir -p "$OUT"

# パスワードはハードコードしない。.env の MYSQL_ROOT_PASSWORD を環境変数 MYSQL_PWD に設定して渡す。
#   例: export MYSQL_PWD="$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)"
: "${MYSQL_PWD:?set MYSQL_PWD to MYSQL_ROOT_PASSWORD (see .env / docker-compose.yml)}"
DB_EXEC=(docker exec -e MYSQL_PWD cyclox2_mysql sh -c)
MYSQL='mysql -u root cyclox2 -N'

APPLY='2026-04-01'
CANCEL='2026-03-31'
NOTE='2025-26シーズン成績の降格処理による'

# src  downlistファイル  並び順
emit_downlist() { # $1=src $2=file $3=order
  "${DB_EXEC[@]}" "$MYSQL -e \"SELECT racer_code FROM demote_all WHERE src='$1' ORDER BY $3\"" > "$OUT/$2"
}
# src DEST downlist koukakufile
gen_sql() { # $1=SRC $2=DEST $3=downlist $4=out
  local src="$1" dest="$2" dl="$OUT/$3" out="$OUT/$4" n
  n=$(wc -l < "$dl" | tr -d ' ')
  {
    echo "-- ${src} -> ${dest}  (${n}名)  apply=${APPLY} cancel=${CANCEL} reason_id=4"
    while IFS= read -r rc; do
      [ -z "$rc" ] && continue
      echo "INSERT INTO category_racers (racer_code, category_code, apply_date, reason_id, reason_note, created, modified) VALUES ('${rc}', '${dest}', '${APPLY}', 4, '${NOTE}', now(), now());"
      echo "UPDATE category_racers SET cancel_date = '${CANCEL}', modified = now() WHERE deleted = 0 AND category_code = '${src}' AND cancel_date IS NULL AND racer_code = '${rc}';"
    done < "$dl"
  } > "$out"
  echo "  ${out##*/}: ${n} 名 (INSERT/UPDATE 各${n})"
}

# ME=順位昇順(無出走NULLは末尾), MM=点数昇順, WE1=racer_code
emit_downlist C1  c1_downlist.txt  "ord_rank IS NULL, ord_rank, racer_code"
emit_downlist C2  c2_downlist.txt  "ord_rank IS NULL, ord_rank, racer_code"
emit_downlist C3  c3_downlist.txt  "ord_rank IS NULL, ord_rank, racer_code"
emit_downlist CM1 m1_downlist.txt  "ord_pt DESC, racer_code"
emit_downlist CM2 m2_downlist.txt  "ord_pt DESC, racer_code"
emit_downlist CL1 we1_downlist.txt "racer_code"

echo "=== 降格SQL生成 ==="
gen_sql C1  C2  c1_downlist.txt  c1_koukaku.sql
gen_sql C2  C3  c2_downlist.txt  c2_koukaku.sql
gen_sql C3  C4  c3_downlist.txt  c3_koukaku.sql
gen_sql CM1 CM2 m1_downlist.txt  m1_koukaku.sql
gen_sql CM2 CM3 m2_downlist.txt  m2_koukaku.sql
gen_sql CL1 CL2 we1_downlist.txt we1_koukaku.sql
echo "完了: $OUT"
