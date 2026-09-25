-- =====================================================================
-- 系統間連動の多重付与 — 是正後の検証
-- spec: lineage-propagation-idempotency-2026-27 / タスク5.1
--
-- 【用途】03_fix_duplicates.sql の適用後に実行する（Requirement 4.7）。
-- 【副作用】読み取りのみ。
-- 【期待結果】(1)(2)(3) がいずれも「異常なし」であること。
-- =====================================================================

-- (1) 本欠陥由来の重複が残っていないこと（期待: 0）
SELECT COUNT(*) AS remaining_duplicates
FROM category_racers c
JOIN racer_results rr ON rr.id = c.racer_result_id
WHERE c.reason_id = 12
  AND c.deleted = 0
  AND c.cancel_date IS NULL
  AND rr.deleted = 1
  AND EXISTS (
      SELECT 1
      FROM category_racers k
      JOIN racer_results kr ON kr.id = k.racer_result_id
      WHERE k.reason_id = 12
        AND k.deleted = 0
        AND k.cancel_date IS NULL
        AND kr.deleted = 0
        AND k.racer_code = c.racer_code
        AND k.category_code = c.category_code
        AND k.apply_date = c.apply_date
        AND k.meet_code = c.meet_code
  );

-- (2) 対象だった選手が、連動先カテゴリーをちょうど1件ずつ保有していること
--     （是正で対応ペアが消えていないことの確認。期待: 全行 active_rows = 1）
SELECT t.racer_code, t.category_code, t.apply_date,
       (SELECT COUNT(*) FROM category_racers a
         WHERE a.racer_code = t.racer_code
           AND a.category_code = t.category_code
           AND a.deleted = 0
           AND a.cancel_date IS NULL) AS active_rows
FROM (SELECT DISTINCT racer_code, category_code, apply_date
        FROM lineage_dup_fix_targets_20260925) t
ORDER BY t.racer_code;

-- (3) 是正対象以外の連動行を巻き添えにしていないこと
--     （バックアップ時点で有効だった reason_id = 12 の行のうち、是正対象に含まれないものが
--       すべて現在も有効であること。期待: 0）
SELECT COUNT(*) AS unexpectedly_removed
FROM category_racers_bk_20260925 b
JOIN category_racers c ON c.id = b.id
WHERE b.reason_id = 12
  AND b.deleted = 0
  AND b.cancel_date IS NULL
  AND c.deleted = 1
  AND b.id NOT IN (SELECT id FROM lineage_dup_fix_targets_20260925);
