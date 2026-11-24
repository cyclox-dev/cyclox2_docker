-- 02_add_mapping.sql — 種目 UCIWJ をカテゴリー WJ に対応付ける（書き込み。本番は要承認）
-- 期待: affected = 1。UCIWJ の行が既にある場合は何も追加しない（affected = 0 → 停止して報告）。
-- 既存の UCIMJ→CJ（id 60, 2018-11-26）と同じ形。

INSERT INTO category_races_categories (category_code, races_category_code, created, modified, deleted_date, deleted)
SELECT 'WJ', 'UCIWJ', NOW(), NOW(), NULL, 0
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM category_races_categories WHERE races_category_code = 'UCIWJ');
SELECT ROW_COUNT() AS affected, LAST_INSERT_ID() AS inserted_id;

SELECT * FROM category_races_categories WHERE races_category_code = 'UCIWJ';
