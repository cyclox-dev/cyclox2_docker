-- =====================================================================
-- 降格判定セット生成 2026-27版（再利用可能）
-- 出典: .kiro/specs/season-rules-2026-27/design.md「SQL資産層 > 判定セット生成SQL」
--       （Requirements 2.1-2.5, 3.1-3.4, 4.1-4.3, 5.1-5.4, 6.2-6.4, 7.1, 8.1-8.2）
-- 対応ペア定義（C2⇔CM1, C3⇔CM2, C1→CM1）・降格先マッピングは
--   me-mm-linkage-2026-27 の CategoryLineageMap（app/Cyclox/Const/CategoryLineageMap.php）
--   を出典とする複製である。対応表が変更された場合は本ファイルの追随が必要
--   （Revalidation Trigger）。
--
-- 2025-26版（rider-demotion-2025-26/sql/01_build_demote_set.sql）との変更点:
--   1. 残留ラインを冒頭のSET変数へ集約（2025-26版はSQL本文中にリテラル埋め込み）
--   2. ME2/ME3の順位ラインを260/280→240へ変更（AJOCC 2026-27改正）
--   3. WE1に順位ライン80位を新設し、2025-26版が持っていた出走ゲート（Requirement 2.4:
--      出走していなければ順位基準の充足有無にかかわらず不充足）を「順位<=80 AND 出走」
--      として自基準判定に統合（順位判定と出走ゲートは独立に併存。どちらも失敗すれば不充足）
--   4. 系統横断残留判定（C2⇔CM1, C3⇔CM2）・ME1単独判定例外・連動降格を追加
--   5. 出力を survive_flags（第1段・自基準充足の中間表）と demote_all（第2段・
--      救済適用後の最終降格対象）の2段構成に変更
--   6. 有効保有の候補集合・救済側結合に apply_date<=@pt の上限フィルタを追加（未来日の
--      apply_dateを持つ行が誤って対象に混入することを防止。独立レビュー指摘・2026-08-29）
--
-- 使い方: docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < 01_build_demote_set.sql'
-- =====================================================================

-- ---------------------------------------------------------------------
-- ★毎年変更するパラメータ
-- ---------------------------------------------------------------------
-- 【重要】以下は2026-27シーズン（本番）向けの既定値。season_idは実行前に必ず
-- seasonsテーブルで確認すること（誤った値のまま実行すると別シーズンのランキングで
-- 降格リストを生成してしまう。独立レビューで指摘済み・2026-08-29）。
-- ローカルダンプでのシミュレーション時は、この値を検証対象シーズンへ一時的に
-- 書き換えて実行し、実行後は必ずこの本番既定値へ戻すこと。
SET @s  := 17;               -- 対象season_id（2026-27。実行時に必ずseasonsテーブルで確認）
SET @pf := '2026-09-01';    -- 今季昇格（基準3）判定窓：開始
SET @pt := '2027-03-31';    -- 今季昇格（基準3）判定窓：終了

-- ME 順位ライン（2026-27新値。出典: AJOCC公式改正文, 2026-08-29確認）
--   C1（ME1）=240（変更なし）, C2（ME2）=240（旧260から変更）, C3（ME3）=240（旧280から変更）
SET @line_c1 := 240;
SET @line_c2 := 240;
SET @line_c3 := 240;

-- MM 点数ライン（変更なし）
SET @pt_cm1 := 80;
SET @pt_cm2 := 40;

-- WE1 順位ライン（2026-27新設。旧版は出走ベースのみで順位基準なし。出典: AJOCC公式改正文）
SET @line_cl1 := 80;

-- =====================================================================
-- 第1段: survive_flags（racer_code × category_code ごとの自基準充足フラグ）
-- =====================================================================
DROP TABLE IF EXISTS survive_flags;
CREATE TABLE survive_flags (
  racer_code VARCHAR(16),
  category_code VARCHAR(16),
  meets_own TINYINT(1),   -- 自基準（順位/点数ライン）を満たすか
  is_promoted TINYINT(1), -- 今季昇格者か（基準3。満たす場合は自動的に充足扱い）
  ord_rank INT,           -- 参考値（順位。ME/WE1のみ）
  ord_pt DECIMAL(10,2)    -- 参考値（点数。MMのみ）
);

-- ---- C1（ME1）: 順位<=240 ----
INSERT INTO survive_flags
SELECT cr.racer_code, 'C1',
  COALESCE((SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C1' AND t.racer_code=cr.racer_code) <= @line_c1, 0),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='C1' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C1' AND t.racer_code=cr.racer_code),
  NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C1' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- ---- C2（ME2）: 順位<=240（新値） ----
INSERT INTO survive_flags
SELECT cr.racer_code, 'C2',
  COALESCE((SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C2' AND t.racer_code=cr.racer_code) <= @line_c2, 0),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='C2' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C2' AND t.racer_code=cr.racer_code),
  NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C2' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- ---- C3（ME3）: 順位<=240（新値） ----
INSERT INTO survive_flags
SELECT cr.racer_code, 'C3',
  COALESCE((SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C3' AND t.racer_code=cr.racer_code) <= @line_c3, 0),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='C3' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='C3' AND t.racer_code=cr.racer_code),
  NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='C3' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- ---- CM1（MM1）: 合計点>=80（変更なし） ----
INSERT INTO survive_flags
SELECT cr.racer_code, 'CM1',
  COALESCE((SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM1' AND t.racer_code=cr.racer_code) >= @pt_cm1, 0),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='CM1' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  NULL,
  (SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM1' AND t.racer_code=cr.racer_code)
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CM1' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- ---- CM2（MM2）: 合計点>=40（変更なし） ----
INSERT INTO survive_flags
SELECT cr.racer_code, 'CM2',
  COALESCE((SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM2' AND t.racer_code=cr.racer_code) >= @pt_cm2, 0),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='CM2' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  NULL,
  (SELECT MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CM2' AND t.racer_code=cr.racer_code)
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CM2' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- ---- CL1（WE1）: 順位<=80（新設）かつ当該シーズンにCL1/UCIWEで出走していること
--      （Requirement 2.4）。出走していない場合は順位基準の充足有無にかかわらず
--      自基準不充足として扱う（独立レビュー指摘・2026-08-29で追加。旧版はこのゲートが
--      欠落しており、女子選手の登録数が80名を下回るシーズンでは唯一の実効フィルタ
--      だった出走ゲートが機能しなくなる潜在的な穴だった）。
INSERT INTO survive_flags
SELECT cr.racer_code, 'CL1',
  COALESCE((SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CL1' AND t.racer_code=cr.racer_code) <= @line_cl1, 0)
    AND EXISTS (
      SELECT 1 FROM racer_results rr
      JOIN entry_racers er ON rr.entry_racer_id=er.id AND er.deleted=0 AND er.racer_code=cr.racer_code
      JOIN entry_categories ec ON er.entry_category_id=ec.id AND ec.deleted=0 AND ec.races_category_code IN ('CL1','UCIWE')
      JOIN entry_groups eg ON ec.entry_group_id=eg.id AND eg.deleted=0
      JOIN meets m ON eg.meet_code=m.code AND m.season_id=@s AND m.deleted=0
      WHERE rr.deleted=0 AND rr.status<>0
    ),
  EXISTS (SELECT 1 FROM category_racers WHERE category_code='CL1' AND racer_code=cr.racer_code AND reason_id=2 AND apply_date BETWEEN @pf AND @pt AND cancel_date IS NULL AND deleted=0),
  (SELECT MIN(`rank`) FROM tmp_ajoccpt_racer_sets t WHERE t.season_id=@s AND t.type=1 AND t.ajoccpt_local_setting_id IS NULL AND t.category_code='CL1' AND t.racer_code=cr.racer_code),
  NULL
FROM (SELECT DISTINCT racer_code FROM category_racers WHERE category_code='CL1' AND apply_date<=@pt AND cancel_date IS NULL AND deleted=0) cr;

-- 参考: WE1出走照合の一覧出力（Requirement 8.1, 8.2）。出走ゲート自体は上のsurvive_flags
-- 生成に既に組み込まれているため判定への影響はないが、人間が目視で「誰が出走扱いに
-- なったか」を確認できるよう一覧として出力する。
-- category_races_categoriesからCL1の集計対象race_categoryが正しくUCIWEを含むかも
-- あわせて確認する。
SELECT '=== 参考: WE1出走照合（CL1・UCIWE, status<>0） ===' AS info;
SELECT DISTINCT er.racer_code
FROM racer_results rr
JOIN entry_racers er ON rr.entry_racer_id=er.id AND er.deleted=0
JOIN entry_categories ec ON er.entry_category_id=ec.id AND ec.deleted=0 AND ec.races_category_code IN ('CL1','UCIWE')
JOIN entry_groups eg ON ec.entry_group_id=eg.id AND eg.deleted=0
JOIN meets m ON eg.meet_code=m.code AND m.season_id=@s AND m.deleted=0
WHERE rr.deleted=0 AND rr.status<>0;

SELECT '=== 参考: CL1の集計対象race_category一覧（UCIWE包含の目視確認） ===' AS info;
SELECT races_category_code FROM category_races_categories WHERE category_code='CL1' AND deleted=0;

-- ===== 第1段 確認出力 =====
SELECT '=== survive_flags 集計 ===' AS info;
SELECT category_code, meets_own, is_promoted, COUNT(*) cnt
FROM survive_flags GROUP BY category_code, meets_own, is_promoted
ORDER BY FIELD(category_code,'C1','C2','C3','CM1','CM2','CL1'), meets_own, is_promoted;

-- =====================================================================
-- 第2段: demote_all（対応ペア救済・ME1単独判定例外・連動降格を適用した最終降格対象）
--   対応ペア: C2⇔CM1, C3⇔CM2, C1→CM1（片方向。CM1→C1の救済は行わない）
--   （出典: me-mm-linkage-2026-27 CategoryLineageMap の複製。対応表変更時は要追随）
-- =====================================================================
DROP TABLE IF EXISTS demote_all;
CREATE TABLE demote_all (racer_code VARCHAR(16), src VARCHAR(16), ord_rank INT, ord_pt DECIMAL(10,2));

-- 各カテゴリーの「自基準充足（含む今季昇格）」を1本化したビュー的サブクエリとして
-- survive_flags を都度参照する（satisfied = meets_own OR is_promoted）。

-- ---- C2: 自充足でなく、かつ「CM1を有効保有しCM1が充足」でない場合に降格 ----
INSERT INTO demote_all
SELECT sf.racer_code, 'C2', sf.ord_rank, NULL
FROM survive_flags sf
WHERE sf.category_code='C2' AND NOT (sf.meets_own OR sf.is_promoted)
  AND NOT EXISTS (
    SELECT 1 FROM category_racers cr2
    JOIN survive_flags sf2 ON sf2.racer_code=cr2.racer_code AND sf2.category_code='CM1'
    WHERE cr2.racer_code=sf.racer_code AND cr2.category_code='CM1' AND cr2.apply_date<=@pt AND cr2.cancel_date IS NULL AND cr2.deleted=0
      AND (sf2.meets_own OR sf2.is_promoted)
  );

-- ---- CM1: 自充足でなく、かつ「C2充足」でも「C1充足（C1→CM1の非対称ペア）」でもない場合に降格 ----
INSERT INTO demote_all
SELECT sf.racer_code, 'CM1', NULL, sf.ord_pt
FROM survive_flags sf
WHERE sf.category_code='CM1' AND NOT (sf.meets_own OR sf.is_promoted)
  AND NOT EXISTS (
    SELECT 1 FROM category_racers cr2
    JOIN survive_flags sf2 ON sf2.racer_code=cr2.racer_code AND sf2.category_code='C2'
    WHERE cr2.racer_code=sf.racer_code AND cr2.category_code='C2' AND cr2.apply_date<=@pt AND cr2.cancel_date IS NULL AND cr2.deleted=0
      AND (sf2.meets_own OR sf2.is_promoted)
  )
  AND NOT EXISTS (
    SELECT 1 FROM category_racers cr3
    JOIN survive_flags sf3 ON sf3.racer_code=cr3.racer_code AND sf3.category_code='C1'
    WHERE cr3.racer_code=sf.racer_code AND cr3.category_code='C1' AND cr3.apply_date<=@pt AND cr3.cancel_date IS NULL AND cr3.deleted=0
      AND (sf3.meets_own OR sf3.is_promoted)
  );

-- ---- C3: 自充足でなく、かつ「CM2を有効保有しCM2が充足」でない場合に降格 ----
INSERT INTO demote_all
SELECT sf.racer_code, 'C3', sf.ord_rank, NULL
FROM survive_flags sf
WHERE sf.category_code='C3' AND NOT (sf.meets_own OR sf.is_promoted)
  AND NOT EXISTS (
    SELECT 1 FROM category_racers cr2
    JOIN survive_flags sf2 ON sf2.racer_code=cr2.racer_code AND sf2.category_code='CM2'
    WHERE cr2.racer_code=sf.racer_code AND cr2.category_code='CM2' AND cr2.apply_date<=@pt AND cr2.cancel_date IS NULL AND cr2.deleted=0
      AND (sf2.meets_own OR sf2.is_promoted)
  );

-- ---- CM2: 自充足でなく、かつ「C3充足」でない場合に降格 ----
INSERT INTO demote_all
SELECT sf.racer_code, 'CM2', NULL, sf.ord_pt
FROM survive_flags sf
WHERE sf.category_code='CM2' AND NOT (sf.meets_own OR sf.is_promoted)
  AND NOT EXISTS (
    SELECT 1 FROM category_racers cr2
    JOIN survive_flags sf2 ON sf2.racer_code=cr2.racer_code AND sf2.category_code='C3'
    WHERE cr2.racer_code=sf.racer_code AND cr2.category_code='C3' AND cr2.apply_date<=@pt AND cr2.cancel_date IS NULL AND cr2.deleted=0
      AND (sf2.meets_own OR sf2.is_promoted)
  );

-- ---- C1（ME1）: 自充足でない場合に降格（MM1による救済なし。Requirement 4.1, 4.2） ----
INSERT INTO demote_all
SELECT sf.racer_code, 'C1', sf.ord_rank, NULL
FROM survive_flags sf
WHERE sf.category_code='C1' AND NOT (sf.meets_own OR sf.is_promoted);

-- ---- CL1（WE1）: 自充足（順位80位以内）でない場合に降格（対応ペアなし・単独判定） ----
INSERT INTO demote_all
SELECT sf.racer_code, 'CL1', sf.ord_rank, NULL
FROM survive_flags sf
WHERE sf.category_code='CL1' AND NOT (sf.meets_own OR sf.is_promoted);

-- ===== 第2段 確認出力 =====
SELECT '=== demote_all カテゴリー別件数 ===' AS info;
SELECT src, COUNT(*) cnt FROM demote_all GROUP BY src ORDER BY FIELD(src,'C1','C2','C3','CM1','CM2','CL1');
SELECT '総計' lbl, COUNT(*) FROM demote_all;

SELECT '=== 系統横断救済の適用者数（自基準不充足だが対応ペア側の充足で残留） ===' AS info;
SELECT sf.category_code, COUNT(*) cnt
FROM survive_flags sf
WHERE NOT (sf.meets_own OR sf.is_promoted)
  AND sf.racer_code NOT IN (SELECT racer_code FROM demote_all WHERE src=sf.category_code)
  AND sf.category_code IN ('C2','C3','CM1','CM2')
GROUP BY sf.category_code;

SELECT '=== 連動降格ペア数（C2+CM1, C3+CM2, C1+CM1が同時にdemote_allへ計上） ===' AS info;
SELECT a.src AS src_a, b.src AS src_b, COUNT(*) cnt
FROM demote_all a JOIN demote_all b ON a.racer_code=b.racer_code AND a.src < b.src
WHERE (a.src='C2' AND b.src='CM1') OR (a.src='C1' AND b.src='CM1') OR (a.src='C3' AND b.src='CM2')
GROUP BY a.src, b.src;

SELECT '=== 対応外ペア保有者数（参考。救済判定の対象外であることの確認） ===' AS info;
-- C4/CM3（最下位・救済ロジックの対象外）は正常な単独保有の組み合わせに大量に出て
-- ノイズになるため除外する。ここで見たいのは救済判定対象（C1〜C3, CM1, CM2）の中で
-- 3つの正当ペア以外の組み合わせを持つ選手のみ。
SELECT racer_code, GROUP_CONCAT(category_code ORDER BY category_code) AS held
FROM category_racers
WHERE category_code IN ('C1','C2','C3','CM1','CM2') AND cancel_date IS NULL AND deleted=0
GROUP BY racer_code
HAVING COUNT(*) > 1
  AND NOT (held = 'C2,CM1' OR held = 'C1,CM1' OR held = 'C3,CM2');

-- 異常な重複降格（同一系統内の複数降格、または対応ペア以外の組み合わせでの複数降格）。
-- C2+CM1・C1+CM1・C3+CM2は連動降格として正常系のため除外する（03_verify.sqlの再定義と同じ基準）。
SELECT '=== 異常な重複降格(要対応・対応ペア以外での複数計上) ===' AS info;
SELECT racer_code, GROUP_CONCAT(src ORDER BY src) srcs
FROM demote_all
GROUP BY racer_code
HAVING COUNT(*)>1
  AND GROUP_CONCAT(src ORDER BY src) NOT IN ('C2,CM1', 'C1,CM1', 'C3,CM2');
