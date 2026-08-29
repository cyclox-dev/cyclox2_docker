-- =====================================================================
-- 降格処理 最終検証 2026-27版（再利用可能）
--
-- 【重要・実行方法】本番適用時（§9のTRANSACTION内でCOMMIT前）は通常どおり別セッションで
-- 実行してよいが、シミュレーション時（ROLLBACKで終える場合）は、判定SQL・降格SQL適用と
-- **同一のmysqlセッション内で `SOURCE 03_verify.sql;` として実行すること**。
-- 別コネクション（別のdocker exec呼び出し）から実行すると、REPEATABLE READのデフォルト
-- 分離レベルにより未コミットのINSERTが見えず、本ファイルの検証項目が全て0件（=異常なし）
-- という誤った結果を返す（独立レビュー指摘・2026-08-29。runbook.md §7参照）。
--
-- ★毎年変更: @note（reason_note）, @apply（降格先 apply_date）
--
-- 2025-26版（rider-demotion-2025-26/sql/03_verify.sql）からの変更点:
--   「二重降格」の定義を再定義した（Requirement 7.3, 7.4）。
--     - 同一系統内の複数降格（例: 同一racerがC2とC3の両方で降格INSERT）= 0期待（異常）
--     - 対応外ペアの同時降格（例: C3とCM1の組み合わせでの同時降格）= 0期待（異常）
--     - 対応ペアの連動降格（C2+CM1, C3+CM2, C1+CM1の同時降格）= 正常系として件数を出力
--   §2bの判定が「連動降格ペアの降格先が対応表上の正当なペアか」の検証（Requirement 8.3の
--   一部）を兼ねる（正当なペア以外を異常として検出するため、意味的に同一の検証）。
--   WE1集計対象の目視確認クエリ（§4）も追加した。
-- =====================================================================
SET @note  := '2026-27シーズン成績の降格処理による';
SET @apply := '2027-04-01';

SELECT '=== 1. 降格先別の投入件数 ===' AS info;
SELECT category_code AS dest, COUNT(*) AS cnt
FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0
GROUP BY category_code
ORDER BY FIELD(category_code,'C2','C3','C4','CM2','CM3','CL2');
SELECT '総計' AS lbl, COUNT(*) AS cnt FROM category_racers WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0;

SELECT '=== 2a. 異常系: 同一系統内の複数降格（0期待） ===' AS info;
-- 同一racerが「エリート系統（C系）」または「マスターズ系統（CM系）」の中で複数回降格した場合を検出
SELECT racer_code, GROUP_CONCAT(category_code ORDER BY category_code) AS dests
FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0
GROUP BY racer_code
HAVING SUM(category_code IN ('C2','C3','C4')) > 1
    OR SUM(category_code IN ('CM2','CM3')) > 1;

SELECT '=== 2b. 異常系: 対応外ペアの同時降格・連動降格ペアの妥当性検証（0期待） ===' AS info;
-- 正当な連動降格の降格先ペアは、C3+CM2（C2+CM1の降格）・C2+CM2（C1+CM1の降格）・
-- C4+CM3（C3+CM2の降格）のいずれかのみ（出典: me-mm-linkage-2026-27 CategoryLineageMap:
-- C2=>CM1, C1=>CM1, C3=>CM2 の降格先C3/C2/C4とCM1=>CM2/CM2=>CM3を組み合わせたもの）。
-- これ以外の組み合わせで同一racerが2件以上降格している場合は対応表との不整合（異常）。
-- これは「連動降格ペアの降格先が対応表上の正当なペアであること」の検証（Requirement 8.3）
-- を兼ねる（正当なペア以外を検出する、という意味で同一の検証のため重複実装しない）。
SELECT racer_code, GROUP_CONCAT(category_code ORDER BY category_code) AS dests
FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0
GROUP BY racer_code
HAVING COUNT(*) > 1
   AND GROUP_CONCAT(category_code ORDER BY category_code) NOT IN ('C3,CM2', 'C2,CM2', 'C4,CM3');

SELECT '=== 2c. 正常系: 連動降格（対応ペアの同時降格）の選手一覧と件数 ===' AS info;
SELECT racer_code, GROUP_CONCAT(category_code ORDER BY category_code) AS dest_pair
FROM category_racers
WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0
GROUP BY racer_code
HAVING COUNT(*) > 1
   AND GROUP_CONCAT(category_code ORDER BY category_code) IN ('C3,CM2', 'C2,CM2', 'C4,CM3');

SELECT dest_pair, COUNT(*) AS pair_cnt FROM (
  SELECT racer_code, GROUP_CONCAT(category_code ORDER BY category_code) AS dest_pair
  FROM category_racers
  WHERE reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0
  GROUP BY racer_code
  HAVING COUNT(*) > 1
     AND GROUP_CONCAT(category_code ORDER BY category_code) IN ('C3,CM2', 'C2,CM2', 'C4,CM3')
) t
GROUP BY dest_pair;

SELECT '=== 3. 降格者が旧カテゴリーにアクティブ行を残していないか(全0期待) ===' AS info;
SELECT 'C1' src, COUNT(*) v FROM category_racers WHERE category_code='C1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0)
UNION ALL SELECT 'C2', COUNT(*) FROM category_racers WHERE category_code='C2' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C3' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0)
UNION ALL SELECT 'C3', COUNT(*) FROM category_racers WHERE category_code='C3' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='C4' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0)
UNION ALL SELECT 'CM1', COUNT(*) FROM category_racers WHERE category_code='CM1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CM2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0)
UNION ALL SELECT 'CM2', COUNT(*) FROM category_racers WHERE category_code='CM2' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CM3' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0)
UNION ALL SELECT 'CL1', COUNT(*) FROM category_racers WHERE category_code='CL1' AND deleted=0 AND cancel_date IS NULL AND racer_code IN (SELECT racer_code FROM category_racers WHERE category_code='CL2' AND reason_id=4 AND reason_note=@note AND apply_date=@apply AND deleted=0);

SELECT '=== 4. WE1(CL1)集計対象race_category一覧（UCIWE包含の目視確認） ===' AS info;
SELECT races_category_code FROM category_races_categories WHERE category_code='CL1' AND deleted=0;
