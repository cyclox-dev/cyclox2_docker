-- ressys /race/{id} 高速化の索引案  ※ 本番へは未適用。適用は人間が判断・実施する。
-- 作成: 2026-11-14   対象DB: 本番 cyclox2（MySQL 5.7.20, InnoDB）

-- ============================================================
-- 0. 事前確認（読み取り専用）
-- ============================================================
SELECT TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, CARDINALITY
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('entry_categories','entry_groups','hold_points','category_races_categories')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
-- 下記と同名・同列の索引が既にあれば、その行はスキップすること。

-- ============================================================
-- 1. 適用案（任意。本番に無い4テーブル5索引。小テーブルのため効果は小さい）
--    MySQL 5.7 の InnoDB は ADD INDEX をオンラインDDL（INPLACE, 読み書き継続可）で実行できる。
--    LOCK=NONE を明示することで、不可能な場合は実行前にエラーとなり安全側に倒れる。
--    適用時間帯: 更新のない時間帯（結果アップロードが無いとき）を推奨。ローカルでは各数秒以内。
-- ============================================================
ALTER TABLE entry_categories ADD INDEX index_entry_group_id (entry_group_id), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE entry_categories ADD INDEX index_races_category_code (races_category_code), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE entry_groups ADD INDEX index_meet_code (meet_code), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE hold_points ADD INDEX index_racer_result_id (racer_result_id), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE category_races_categories ADD INDEX index_races_category_code (races_category_code), ALGORITHM=INPLACE, LOCK=NONE;
-- 注: ローカル検証では x_ 接頭辞の名前で作成した。本番の既存命名（index_xxx）に合わせた名前を上記に採用。
-- 適用後: ANALYZE TABLE entry_categories, entry_groups, hold_points, category_races_categories;

-- ============================================================
-- 2. ロールバック（索引の削除のみ。データへの影響なし）
-- ============================================================
-- ALTER TABLE entry_categories DROP INDEX index_entry_group_id, DROP INDEX index_races_category_code;
-- ALTER TABLE entry_groups DROP INDEX index_meet_code;
-- ALTER TABLE hold_points DROP INDEX index_racer_result_id;
-- ALTER TABLE category_races_categories DROP INDEX index_races_category_code;

-- ============================================================
-- 3. 開発DB用（ローカル／新規構築の環境）: 本番に既にある4索引を再現
--    本番ではこれらは存在するため実行しないこと。
-- ============================================================
-- ALTER TABLE time_records ADD INDEX in_result_id (racer_result_id);
-- ALTER TABLE entry_racers ADD INDEX index_entry_cat_id (entry_category_id);
-- ALTER TABLE point_series_racers ADD INDEX index_racer_result_id (racer_result_id);
-- ALTER TABLE category_racers ADD INDEX index_racer_result_id (racer_result_id);
