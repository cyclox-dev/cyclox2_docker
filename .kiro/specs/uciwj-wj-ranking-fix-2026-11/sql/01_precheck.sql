-- 01_precheck.sql — 事前確認（SELECT のみ。承認不要）
-- 期待: mapping_rows=0 / 8件すべて row_ok=1 / ecat_rows: 28856+29071=6, 19879=2 / noncat_2026_27=6 /
--       DB 時刻が JST / PRECHECK=OK
-- 1つでも違えば何も変更せず停止し、出力を人間に報告する（要件2.6）。

-- (1) 対応表に UCIWJ の行が無いこと（論理削除済みの行も数える）
SELECT 'mapping_rows' AS chk, COUNT(*) AS val
  FROM category_races_categories WHERE races_category_code = 'UCIWJ';

-- (2) 是正対象8件（2026-27 の6件＋2023-24 の2件）が期待値どおりであること
SELECT e.rr_id, e.ecat, e.racer_code, e.rnk, e.pt,
       rr.as_category, rr.deleted AS rr_deleted, er.deleted AS er_deleted,
       (rr.id IS NOT NULL AND er.entry_category_id = e.ecat AND er.racer_code = e.racer_code
        AND rr.`rank` = e.rnk AND rr.ajocc_pt = e.pt AND rr.as_category = 'UCIWJ'
        AND rr.deleted = 0 AND er.deleted = 0) AS row_ok
  FROM (SELECT 359429 rr_id, 28856 ecat, 'XTK-178-0059' racer_code, 2 rnk,  900 pt UNION ALL
        SELECT 359430, 28856, 'CXK-156-0033', 1, 1000 UNION ALL
        SELECT 360444, 29071, 'CXK-156-0033', 1, 1000 UNION ALL
        SELECT 360445, 29071, 'XTK-178-0059', 3,  810 UNION ALL
        SELECT 360446, 29071, 'KNS-201-0043', 2,  900 UNION ALL
        SELECT 360447, 29071, 'KNS-234-0063', 4,  730 UNION ALL
        SELECT 277933, 19879, 'TKI-156-0175', 1,  100 UNION ALL
        SELECT 277934, 19879, 'KNS-167-0104', 2,   80) e
  LEFT JOIN racer_results rr ON rr.id = e.rr_id
  LEFT JOIN entry_racers er ON er.id = rr.entry_racer_id
 ORDER BY e.rr_id;

-- (3) 対象出走カテゴリーの有効リザルト件数（再取込で増減していないか）
SELECT er.entry_category_id AS ecat, COUNT(*) AS ecat_rows
  FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
 WHERE er.entry_category_id IN (28856, 29071, 19879) AND rr.deleted = 0 AND er.deleted = 0
 GROUP BY er.entry_category_id ORDER BY er.entry_category_id;

-- (4) 2026-27 の AJOCC ポイント付与ありの UCI 種目で、成績対象カテゴリーが実在しない成績の件数
SELECT 'noncat_2026_27' AS chk, COUNT(*) AS val
  FROM racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
  JOIN entry_categories ec ON ec.id = er.entry_category_id
  JOIN entry_groups eg ON eg.id = ec.entry_group_id
  JOIN meets m ON m.code = eg.meet_code
  LEFT JOIN categories c ON c.code = rr.as_category AND c.deleted = 0
 WHERE rr.deleted = 0 AND er.deleted = 0 AND ec.deleted = 0 AND m.deleted = 0
   AND ec.applies_ajocc_pt = 1 AND ec.races_category_code LIKE 'UCI%'
   AND m.season_id = 17 AND c.code IS NULL;

-- (5) 参考値（事後確認での比較用に控える）: 種目 UCIWJ の更新日時、2023-24 WJ ランキングの最終生成日時
SELECT 'races_category_UCIWJ_modified' AS chk, modified AS val FROM races_categories WHERE code = 'UCIWJ';
SELECT 'ranking_2324_WJ_last_modified' AS chk, MAX(modified) AS val
  FROM tmp_ajoccpt_racer_sets WHERE season_id = 14 AND category_code = 'WJ';

-- (6) 環境（本番 DB の時刻が JST であること。NOW() で入れる時刻の基準になる）
SELECT NOW() AS now_, @@system_time_zone AS system_tz, @@time_zone AS session_tz, VERSION() AS version_;

-- (7) 総合判定（(1)〜(4) をすべて含める）
SELECT CASE WHEN
    (SELECT COUNT(*) FROM category_races_categories WHERE races_category_code = 'UCIWJ') = 0
AND (SELECT COUNT(*)
       FROM (SELECT 359429 rr_id, 28856 ecat, 'XTK-178-0059' racer_code, 2 rnk,  900 pt UNION ALL
             SELECT 359430, 28856, 'CXK-156-0033', 1, 1000 UNION ALL
             SELECT 360444, 29071, 'CXK-156-0033', 1, 1000 UNION ALL
             SELECT 360445, 29071, 'XTK-178-0059', 3,  810 UNION ALL
             SELECT 360446, 29071, 'KNS-201-0043', 2,  900 UNION ALL
             SELECT 360447, 29071, 'KNS-234-0063', 4,  730 UNION ALL
             SELECT 277933, 19879, 'TKI-156-0175', 1,  100 UNION ALL
             SELECT 277934, 19879, 'KNS-167-0104', 2,   80) e
       JOIN racer_results rr ON rr.id = e.rr_id
       JOIN entry_racers er ON er.id = rr.entry_racer_id
      WHERE er.entry_category_id = e.ecat AND er.racer_code = e.racer_code
        AND rr.`rank` = e.rnk AND rr.ajocc_pt = e.pt AND rr.as_category = 'UCIWJ'
        AND rr.deleted = 0 AND er.deleted = 0) = 8
AND (SELECT COUNT(*) FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
      WHERE er.entry_category_id IN (28856, 29071) AND rr.deleted = 0 AND er.deleted = 0) = 6
AND (SELECT COUNT(*) FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
      WHERE er.entry_category_id = 19879 AND rr.deleted = 0 AND er.deleted = 0) = 2
AND (SELECT COUNT(*)
       FROM racer_results rr
       JOIN entry_racers er ON er.id = rr.entry_racer_id
       JOIN entry_categories ec ON ec.id = er.entry_category_id
       JOIN entry_groups eg ON eg.id = ec.entry_group_id
       JOIN meets m ON m.code = eg.meet_code
       LEFT JOIN categories c ON c.code = rr.as_category AND c.deleted = 0
      WHERE rr.deleted = 0 AND er.deleted = 0 AND ec.deleted = 0 AND m.deleted = 0
        AND ec.applies_ajocc_pt = 1 AND ec.races_category_code LIKE 'UCI%'
        AND m.season_id = 17 AND c.code IS NULL) = 6
  THEN 'OK' ELSE 'NG' END AS PRECHECK;
