# 降格処理 再利用SQL/スクリプト

`runbook.md`（1つ上の階層）とセットで使用する。PIIを含まない再利用資産のみをここに置く。
生成される downlist / koukaku SQL / ログは `../outputs/`（git管理外）へ出力すること。

## ファイル
| ファイル | 役割 |
|---|---|
| `01_build_demote_set.sql` | 3基準で `demote_all`（降格対象）を生成＋件数・二重降格を確認 |
| `02_gen_koukaku.sh` | `demote_all` から downlist と `*_koukaku.sql` を生成 |
| `03_verify.sql` | 実行後の最終検証（件数・二重降格・旧所属残存） |

## 手順（要約）
```bash
OUT=docs/specs/rider-demotion-2025-26/outputs   # PII出力先(git管理外)

# 1) 判定セット生成
docker cp docs/specs/rider-demotion-2025-26/sql/01_build_demote_set.sql cyclox2_mysql:/tmp/
docker exec cyclox2_mysql sh -c 'mysql -u root -pYamaken0 cyclox2 < /tmp/01_build_demote_set.sql'
#   → 二重降格が出たら 00_dup_fix.sql を作成し、該当racerを対応downlistから除外

# 2) downlist + 降格SQL 生成
bash docs/specs/rider-demotion-2025-26/sql/02_gen_koukaku.sh "$OUT"

# 3) ローカル実行（カテゴリー単位 TRANSACTION→検証→COMMIT, runbook §6）
for f in 00_dup_fix c1_koukaku c2_koukaku c3_koukaku m1_koukaku m2_koukaku we1_koukaku; do
  docker cp "$OUT/$f.sql" cyclox2_mysql:/tmp/
done
#   各カテゴリーを START TRANSACTION; SOURCE ...; <検証SELECT>; COMMIT; で実行

# 4) 最終検証
docker cp docs/specs/rider-demotion-2025-26/sql/03_verify.sql cyclox2_mysql:/tmp/
docker exec cyclox2_mysql sh -c 'mysql -u root -pYamaken0 cyclox2 < /tmp/03_verify.sql'
```

## 毎年変更する箇所
- `01_build_demote_set.sql` 冒頭: `@s`(season_id), `@pf`/`@pt`(期間), 各ライン数値(240/260/280/80/40)。
- `02_gen_koukaku.sh` 冒頭: `APPLY`/`CANCEL`/`NOTE`、必要なら DEST マッピング。
- `03_verify.sql` 冒頭: `@note`/`@apply`。
- WE1出走の集計 race_category（`'CL1','UCIWE'`）は `category_races_categories` で毎年確認。
