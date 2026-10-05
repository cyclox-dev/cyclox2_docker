-- a. サーバー: 10/6 に重複アップロードされた C4 (CXK-267-0025〜0037) 26行を論理削除
-- 1) 事前確認: 26行であること
SELECT COUNT(*) AS target_rows FROM category_racers
 WHERE id BETWEEN 269156 AND 269181
   AND racer_code BETWEEN 'CXK-267-0025' AND 'CXK-267-0037'
   AND category_code = 'C4' AND meet_code = 'CXK-267-003' AND reason_id = 1
   AND created IN ('2026-10-06 00:05:40','2026-10-06 00:06:17')
   AND deleted = 0;
-- 2) 論理削除（modified を更新し、アプリの差分同期で削除が配信されるようにする）
START TRANSACTION;
UPDATE category_racers
   SET deleted = 1, deleted_date = NOW(), modified = NOW()
 WHERE id BETWEEN 269156 AND 269181
   AND racer_code BETWEEN 'CXK-267-0025' AND 'CXK-267-0037'
   AND category_code = 'C4' AND meet_code = 'CXK-267-003' AND reason_id = 1
   AND created IN ('2026-10-06 00:05:40','2026-10-06 00:06:17')
   AND deleted = 0;
SELECT ROW_COUNT() AS updated_rows;   -- 26 でなければ ROLLBACK
COMMIT;
-- 3) 事後確認: 各選手の有効な C4 が 1 行 (269115〜269127) になっていること
SELECT racer_code, GROUP_CONCAT(id ORDER BY id) AS active_c4_ids, COUNT(*) AS n
  FROM category_racers
 WHERE racer_code BETWEEN 'CXK-267-0025' AND 'CXK-267-0037'
   AND category_code = 'C4' AND deleted = 0
 GROUP BY racer_code;
