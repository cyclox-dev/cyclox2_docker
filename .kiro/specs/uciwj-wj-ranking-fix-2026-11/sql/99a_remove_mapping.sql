-- 99a_remove_mapping.sql — 取り消し①: 対応行の削除と、デスクトップアプリへの配信（書き込み。要承認）
-- 期待: affected_mapping = 1 / affected_touch = 1
-- 対応行は物理削除する。論理削除（deleted=1）では、判定処理の関連取得（RacesCategory→CategoryRacesCategory の
-- hasMany に削除条件が無い）が行を拾い続ける可能性があるため。
-- 02 実行前に UCIWJ の行が無かったこと（01 の mapping_rows=0）が前提。

DELETE FROM category_races_categories WHERE races_category_code = 'UCIWJ' AND category_code = 'WJ';
SELECT ROW_COUNT() AS affected_mapping;

UPDATE races_categories SET modified = NOW() WHERE code = 'UCIWJ' AND deleted = 0;
SELECT ROW_COUNT() AS affected_touch;
