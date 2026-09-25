-- =====================================================================
-- 系統間連動の多重付与 — 是正対象の検出
-- spec: lineage-propagation-idempotency-2026-27 / タスク5.1
--
-- 【用途】適用前（対象の確認・人間の承認用）と適用後（0件であることの確認）の両方で使う。
-- 【副作用】読み取りのみ。DBを変更しない。
--
-- 【対象の定義】Requirement 4.1, 4.2, 4.3, 4.4
--   本欠陥（再取込のたびに連動先カテゴリーが増える）が生成した余剰行に限定する:
--     (a) reason_id = 12（系統連動による自動付与）であること
--         → 昇格そのものの行（reason_id = 2）や手動付与・エントリー補完の行は対象外
--     (b) 現在有効であること（deleted = 0 かつ cancel_date IS NULL）
--     (c) 紐づくリザルトが既にソフト削除済みであること（= 過去の取込世代の行）
--     (d) 同一の（選手・カテゴリー・有効開始日・大会）に、生存リザルトへ紐づく兄弟行が
--         存在すること（= 最新の取込に対応する行が別に残っている）
--   (d) により、重複していない単独の連動行は決して対象にならない（Requirement 4.3）。
--
-- 【注意】エントリー補完による連動行は meet_code が未設定で racer_result_id も NULL のため、
-- JOIN の時点で対象から外れる。
-- =====================================================================

SELECT
    c.id,
    c.racer_code,
    c.category_code,
    c.apply_date,
    c.meet_code,
    c.racer_result_id,
    c.created,
    c.reason_note
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
  )
ORDER BY c.racer_code, c.apply_date, c.id;

-- 参考: 選手ごとの要約（承認時の確認用）
SELECT
    c.racer_code,
    c.category_code,
    c.apply_date,
    c.meet_code,
    COUNT(*) AS surplus_rows
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
  )
GROUP BY c.racer_code, c.category_code, c.apply_date, c.meet_code
ORDER BY surplus_rows DESC, c.racer_code;
