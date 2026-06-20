-- =====================================================================
-- 降格判定セット生成（再利用可能）
-- 出力: cyclox2.demote_all (racer_code, src, ord_rank, ord_pt)
--        + 確認用カウント + 二重降格検出
-- 使い方: docker exec cyclox2_mysql sh -c 'mysql -u root -pYamaken0 cyclox2 < 01_build_demote_set.sql'
--
-- ★毎年変更するパラメータ（下記の @s / 期間 / 各ラインの数値）
--   - @s     : 対象 season_id
--   - @pf/@pt: 今季昇格(基準3)の判定窓（シーズン期間）
--   - ME各ラインの順位（240/260/280）, MM各ラインの点数（80/40）
--   - WE1の出走判定 race_category（'CL1','UCIWE'）は category_races_categories で要確認
-- =====================================================================
SET @s  := 16;
SET @pf := '2025-09-01';
SET @pt := '2026-03-31';

DROP TABLE IF EXISTS demote_all;
CREATE TABLE demote_all (racer_code VARCHAR(16), src VARCHAR(16), ord_rank INT, ord_pt DECIMAL(10,2));

-- 共通: 全国版ランキング在席判定のためのビュー的サブクエリは各INSERTにインライン展開
-- ---- ME1 / C1 : 順位<=240 残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'C1',
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C1' AND t.racer_code=cr.racer_code), NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C1' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (SELECT racer_code FROM tmp_ajoccpt_racer_sets WHERE season_id=@s AND type=1 AND ajoccpt_local_setting_id IS NULL AND category_code='C1' AND `rank`<=240)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='C1' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ---- ME2 / C2 : 順位<=260 残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'C2',
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C2' AND t.racer_code=cr.racer_code), NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C2' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (SELECT racer_code FROM tmp_ajoccpt_racer_sets WHERE season_id=@s AND type=1 AND ajoccpt_local_setting_id IS NULL AND category_code='C2' AND `rank`<=260)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='C2' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ---- ME3 / C3 : 順位<=280 残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'C3',
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C3' AND t.racer_code=cr.racer_code), NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C3' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (SELECT racer_code FROM tmp_ajoccpt_racer_sets WHERE season_id=@s AND type=1 AND ajoccpt_local_setting_id IS NULL AND category_code='C3' AND `rank`<=280)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='C3' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ---- MM1 / CM1 : 合計点>=80 残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'CM1', NULL,
  (SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM1' AND t.racer_code=cr.racer_code)
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CM1' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (SELECT racer_code FROM tmp_ajoccpt_racer_sets WHERE season_id=@s AND type=1 AND ajoccpt_local_setting_id IS NULL AND category_code='CM1' AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))>=80)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='CM1' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ---- MM2 / CM2 : 合計点>=40 残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'CM2', NULL,
  (SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM2' AND t.racer_code=cr.racer_code)
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CM2' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (SELECT racer_code FROM tmp_ajoccpt_racer_sets WHERE season_id=@s AND type=1 AND ajoccpt_local_setting_id IS NULL AND category_code='CM2' AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))>=40)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='CM2' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ---- WE1 / CL1 : 出走(CL1+UCIWE, status<>0)で残留 ----
INSERT INTO demote_all
SELECT cr.racer_code,'CL1', NULL, NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CL1' AND cancel_date IS NULL AND deleted=0) cr
WHERE cr.racer_code NOT IN (
   SELECT DISTINCT er.racer_code FROM racer_results rr
   JOIN entry_racers er ON rr.entry_racer_id=er.id AND er.deleted=0
   JOIN entry_categories ec ON er.entry_category_id=ec.id AND ec.deleted=0 AND ec.races_category_code IN ('CL1','UCIWE')
   JOIN entry_groups eg ON ec.entry_group_id=eg.id AND eg.deleted=0
   JOIN meets m ON eg.meet_code=m.code AND m.season_id=@s AND m.deleted=0
   WHERE rr.deleted=0 AND rr.status<>0)
  AND cr.racer_code NOT IN (SELECT racer_code FROM category_racers WHERE category_code='CL1' AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0);

-- ===== 確認 =====
SELECT src, COUNT(*) cnt FROM demote_all GROUP BY src ORDER BY FIELD(src,'C1','C2','C3','CM1','CM2','CL1');
SELECT '総計' lbl, COUNT(*) FROM demote_all;
-- 二重降格（要・事前重複修正）
SELECT '二重降格(要対応)' lbl, racer_code, GROUP_CONCAT(src ORDER BY src) srcs
FROM demote_all GROUP BY racer_code HAVING COUNT(*)>1;
