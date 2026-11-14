# ローカルDB変更記録

## 2026-11-14: 本番同等の4索引をローカルDB `cyclox2_mysql` に恒久適用（人間の指示）
- 目的: ローカルDBが本番の古いコピーで索引が欠落しており、`/race/{id}` が約12秒かかる問題の解消（本番に合わせる）。
- 対象: ローカルDB `cyclox2`（`cyclox2_test` / `cyclox2_test_me1` は未変更）。本番には一切変更なし。
- 適用SQL（本番と同名・同列。`ALGORITHM=INPLACE, LOCK=NONE`、各数秒以内で完了、ANALYZE TABLE 済み）:
  ```sql
  ALTER TABLE time_records        ADD INDEX in_result_id (racer_result_id);
  ALTER TABLE entry_racers        ADD INDEX index_entry_cat_id (entry_category_id);
  ALTER TABLE point_series_racers ADD INDEX index_racer_result_id (racer_result_id);
  ALTER TABLE category_racers     ADD INDEX index_racer_result_id (racer_result_id);
  ```
- 適用後の索引構成: `evidence/local_indexes_after_prod_equiv_applied.txt`（適用前は `evidence/local_indexes_before.txt`）。
- 効果: `/race/24693` 約12.1秒 → 約0.5秒（`test-results.md` ②）。
- 本番に無い4索引（`proposed-index.sql` §1）はローカルにも**適用していない**。
- ロールバック（ローカルのみ）: `proposed-index.sql` §3 の4索引を `ALTER TABLE <表> DROP INDEX <索引名>;`。
- 注意: 索引はDBのデータディレクトリ（`cyclox2_mysql/var/mysql`、git管理外）にのみ存在する。DBを本番ダンプから作り直すと
  欠落状態に戻るため、再構築時は同SQLを再適用すること（恒久対策は `agreement-log.md` の未解決事項「開発DBの索引欠落対策」）。
