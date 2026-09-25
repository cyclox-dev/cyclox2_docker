-- =====================================================================
-- 系統間連動の多重付与 — 是正の適用
-- spec: lineage-propagation-idempotency-2026-27 / タスク5.1
--
-- 【前提】
--   1. 本specのコード修正が本番へ適用済みであること（Requirement 4.5、agreement-log 決定事項#14）。
--      適用前に是正しても、次の再取込で同じ重複が再発する。
--   2. 01_detect_duplicates.sql の出力を人間が確認し、承認済みであること。
--   3. 02_backup.sql を実行済みであること。
-- 【副作用】対象行を deleted = 1（ソフト削除）へ更新する。物理削除はしない。
--
-- 【実装上の注意】MySQL は UPDATE 対象の表を同じ文のサブクエリから直接参照できない（ERROR 1093）
-- ため、対象 id を作業表へ確定させてから更新する。作業表は監査証跡として残す
-- （Requirement 6.4: 是正した行を事後に特定できる記録）。
-- =====================================================================

CREATE TABLE lineage_dup_fix_targets_20260925 (
    id INT(10) UNSIGNED NOT NULL PRIMARY KEY,
    racer_code   VARCHAR(16) NOT NULL,
    category_code VARCHAR(16) NOT NULL,
    apply_date   DATE NOT NULL,
    meet_code    VARCHAR(11) NULL,
    racer_result_id INT(10) UNSIGNED NULL,
    detected_at  DATETIME NOT NULL
);

INSERT INTO lineage_dup_fix_targets_20260925
SELECT c.id, c.racer_code, c.category_code, c.apply_date, c.meet_code, c.racer_result_id, NOW()
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

-- 確定した対象件数を確認してから次の UPDATE を実行すること
SELECT COUNT(*) AS fix_target_rows FROM lineage_dup_fix_targets_20260925;

UPDATE category_racers
SET deleted = 1,
    deleted_date = NOW(),
    modified = NOW()
WHERE id IN (SELECT id FROM lineage_dup_fix_targets_20260925)
  AND deleted = 0;

SELECT ROW_COUNT() AS updated_rows;
