-- =====================================================================
-- 系統間連動の多重付与 — 是正前のバックアップ
-- spec: lineage-propagation-idempotency-2026-27 / タスク5.1
--
-- 【用途】03_fix_duplicates.sql を適用する直前に実行する（Requirement 4.6）。
-- 【副作用】バックアップ表を1つ作成する。既存データは変更しない。
--
-- 日付部分は実行日に合わせて書き換えること。同名の表が既に存在する場合は中断される
-- （誤って2回実行し、是正後の状態でバックアップを上書きすることを防ぐため、DROP はしない）。
-- =====================================================================

CREATE TABLE category_racers_bk_20260925 LIKE category_racers;
INSERT INTO category_racers_bk_20260925 SELECT * FROM category_racers;

-- 件数の一致を確認する（両者が同じ値であること）
SELECT
    (SELECT COUNT(*) FROM category_racers)              AS source_rows,
    (SELECT COUNT(*) FROM category_racers_bk_20260925)  AS backup_rows;
