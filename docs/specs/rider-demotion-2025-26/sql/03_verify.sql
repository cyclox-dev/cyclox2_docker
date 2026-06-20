-- =====================================================================
-- 降格処理 最終検証（再利用可能）
-- 使い方: docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < 03_verify.sql'
-- ★毎年変更: @note（reason_note）, @apply（降格先 apply_date）
-- =====================================================================
SET @note  := '2025-26シーズン成績の降格処理による';
SET @apply := '2026-04-01';

SELECT '=== 1. 降格先別の投入件数 ===' AS info;
SELECT category_code AS dest, COUNT(*) AS cnt
FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply
GROUP BY category_code
ORDER BY FIELD(category_code,'C2','C3','C4','CM2','CM3','CL2');
SELECT '総計' AS lbl, COUNT(*) AS cnt FROM category_racers WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply;

SELECT '=== 2. 二重降格(同一racerが2回INSERT)=0期待 ===' AS info;
SELECT racer_code, COUNT(*) c FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply
GROUP BY racer_code HAVING COUNT(*)>1;

SELECT '=== 3. 降格者が旧カテゴリーにアクティブ行を残していないか(全0期待) ===' AS info;
SELECT 'C1' src, COUNT(*) v FROM category_racers WHERE category_code='C1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply)
UNION ALL SELECT 'C2', COUNT(*) FROM category_racers WHERE category_code='C2' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C3' AND reason_id=4 AND reason_note=@note AND apply_date=@apply)
UNION ALL SELECT 'C3', COUNT(*) FROM category_racers WHERE category_code='C3' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C4' AND reason_id=4 AND reason_note=@note AND apply_date=@apply)
UNION ALL SELECT 'CM1', COUNT(*) FROM category_racers WHERE category_code='CM1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CM2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply)
UNION ALL SELECT 'CM2', COUNT(*) FROM category_racers WHERE category_code='CM2' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CM3' AND reason_id=4 AND reason_note=@note AND apply_date=@apply)
UNION ALL SELECT 'CL1', COUNT(*) FROM category_racers WHERE category_code='CL1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CL2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply);
