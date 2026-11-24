# 手順書: UCIWJ → WJ 対応追加と、2026-27 の6件・2023-24 の2件の是正

本番の接続・安全ルールは prod-access スキル（`~/.claude/skills/prod-access/SKILL.md`）に従う。
以下、`$S` は `.kiro/specs/uciwj-wj-ranking-fix-2026-11`、出力はすべて `$S/outputs/`（git 管理外）に置く。

## 期待件数と停止条件（一覧）

| 手順 | 種別 | 承認 | 期待 | 止まる条件 |
|---|---|---|---|---|
| 01_precheck | SELECT | 不要 | `PRECHECK=OK`（対応行0、8件 row_ok=1、ecat 件数 28856:2 / 29071:4 / 19879:2、noncat=6）、DB 時刻 JST | NG・JST 以外 → 何も変えずに停止し、出力を報告 |
| 10_snapshot（前） | SELECT | 不要 | 全行出力 | 出力失敗 → 停止 |
| 02_add_mapping | INSERT | **要** | affected=1 | 0 → 停止（誰かが先に追加した可能性） |
| 02b_touch_races_category | UPDATE | **要** | affected=1 | 1以外 → 停止 |
| 03_fix_as_category | UPDATE | **要** | affected=6 | 6未満 → 停止 |
| 03b_fix_as_category_2324 | UPDATE | **要** | affected=2 | 2未満 → 停止 |
| 04_enqueue_ranking | INSERT | **要** | affected=2 | 2以外 → 停止 |
| バッチ待ち | — | — | 2時間以内に flags_pending=0 | 2時間超 → 停止して報告（手動再生成は別途承認） |
| 05_postcheck | SELECT | 不要 | `POSTCHECK=OK`。2023-24 WJ ランキングの最終生成日時が 01 で控えた値と同じ | NG → 停止して報告 |
| 10_snapshot（後）＋比較 | SELECT | 不要 | 8件は UCIWJ→WJ で他列不変、他行の差分なし | 他行に差分 → 一覧を報告（他の運営者の取込かを人間が判断） |

- 03・03b の WHERE 句は id・出走カテゴリー・現在値の3条件で絞っているため、期待件数を超えて変わることはない。不一致は「少ない」側にしか起きない。
- 認証失敗（`Permission denied` / `Access denied`）が出たら即停止し、人間に初期設定を依頼する。
- 本番には、松伏（ecat 28856）の再取込で立った既存フラグが残っていることがある（ダンプ時点で id 16514）。02・03 より前にバッチがこれを処理しても、UCIWJ としてスキップされるだけで害はない。04 で新しいフラグを立てるので手順は変わらない。
- 本番の DB は JST（2026-11-24 確認: `@@system_time_zone=JST`、5.7.23）。ローカルは UTC なので、ローカルの出力に出る SQL 由来の時刻は9時間ずれて見える。

## 途中で止まったときの戻し方（すべて要承認・件数照合）

| 実行済みの手順 | 実行する取り消し | 期待件数 |
|---|---|---|
| 02（＋02b） | 99a_remove_mapping | 対応行1・更新日時1 |
| 03 | 99b_revert_2627 → 99d_enqueue_wj_regen（04 まで進んでバッチが走った後なら必須。走る前でも実行して害はない） | 実際に WJ になっている件数（通常6）・1 |
| 03b | 99c_revert_2324 | 実際に WJ になっている件数（通常2） |
| 04 のみ（03 を戻さない） | 不要（フラグは処理されるだけ） | — |

全部を戻すときは 99a → 99b → 99c → 99d の順に1つずつ。99d は「2026-27 で WJ の成績を持つ別の出走カテゴリー」にフラグを立てる。是正対象の出走カテゴリーに立てても、as_category が UCIWJ に戻っているためバッチがスキップし、WJ ランキングに松伏・琵琶湖が残る（リハーサルで確認）。

## A. ローカルリハーサル（本番複製のローカル DB）

```bash
cd /Users/kyamady/workspace/cyclox2_docker && export MYSQL_PWD="$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)"
docker exec -i -e MYSQL_PWD cyclox2_mysql mysql -uroot cyclox2 < $S/sql/<file>.sql
```

1. `01_precheck` → OK、`10_snapshot`（前）
2. `02` → `02b` → `tools/run_local_cake.sh as_category_check`（6名・WJ非保有が WJ、他は不変）
3. `03` → `03b` → `04` → `tools/run_local_cake.sh result updateAjoccPtRankings`
4. `05_postcheck` → OK、`10_snapshot`（後）→ `python3 -I tools/compare_snapshots.py before after` → OK
5. `99a` → `99b` → `99c` → `99d` → ランキング再生成 → 判定が UCIWJ に戻り、`01_precheck` OK、WJ 2026-27 が全国3・関東1に戻る
6. 再適用（2〜4）して「適用済み」で止める。結果を `test-results.md` に記録

## B. 本番適用

```bash
ssh -o BatchMode=yes cyclox2-prod 'mysql cyclox2' < $S/sql/<file>.sql
```

1. **ダンプ取得**（prod-access の手順。同日2本目なので `20261124_2_dump.sql.gz` などの別名）。末尾 `-- Dump completed` と、手元へ転送したファイルのハッシュ一致を確認
2. `01_precheck` → `PRECHECK=OK`、JST。(5) の2つの日時（UCIWJ の modified、2023-24 WJ ランキングの最終生成）を控える
3. `10_snapshot` → `outputs/prod_snapshot_before.tsv`（`mysql -B`）
4. **承認①** `02_add_mapping`（期待1）
5. **承認②** `02b_touch_races_category`（期待1）
6. **承認③** `03_fix_as_category`（期待6）
7. **承認④** `03b_fix_as_category_2324`（期待2）
8. **承認⑤** `04_enqueue_ranking`（期待2）
   - 各承認では、実行する SQL ファイル名・中身・期待件数を示す。実行後に affected を照合し、違えば以降に進まない
9. **バッチ待ち**: 毎時（目安: :24 前後に生成、:30 前後にフラグ処理済み）。`05_postcheck` の flags_pending が0になるまで、確認は数十分おき。上限2時間
10. `05_postcheck` → `POSTCHECK=OK`。2023-24 WJ ランキングの最終生成日時が手順2で控えた値と同じ
11. `10_snapshot` → `outputs/prod_snapshot_after.tsv`、比較。8件以外の差分は、他の運営者の取込（別大会・適用後の modified）かを確認して報告
12. **公開サイトの確認**（ressys DB の反映を待ってから）
    - WJ ランキング https://data.cyclocross.jp/ajocc_ranking/17/0/WJ に「松伏」「琵琶湖」の大会列。小林 碧 1000/1000、皆木 海音 900/810、野口 依央 900、本多 美緒 730
    - 関東シリーズの WJ ランキングに松伏の列（皆木 900・小林 1000）
    - 松伏・琵琶湖・JPN-234-002 のレース結果ページで AJOCC pt が「ポイント/WJ」と表示される
13. 結果を `test-results.md` と `integration-test-checklist.md` に記録

## C. 取り消し（必要な場合のみ・要承認）

1. 上の「途中で止まったときの戻し方」に従い、99a〜99d を1つずつ承認・件数照合して実行
2. バッチ待ち → WJ 2026-27 ランキングが是正前（全国3大会・関東1大会）に戻ることを確認
3. それでも戻らない場合は、手順 B-1 のダンプから該当テーブルの復元を人間と相談する
