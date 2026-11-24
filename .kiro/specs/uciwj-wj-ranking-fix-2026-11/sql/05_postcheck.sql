-- 05_postcheck.sql — 事後確認（SELECT のみ。承認不要）
-- 期待: mapping_rows=1 / 8件すべて WJ / noncat_2026_27=0 / flags_pending=0 /
--       全国版で6件すべて pt_ok=1 / 関東(設定26)で松伏2件 pt_ok=1 /
--       種目 UCIWJ の modified が 2023-24 WJ ランキングの最終生成より新しい（＝02b 実行済みで、2023-24 は作り直されていない）/
--       POSTCHECK=OK
-- 2023-24 WJ ランキングの最終生成日時は 01 の (5) で控えた値と同じであること（目視で照合）。

SELECT 'mapping_rows' AS chk, COUNT(*) AS val
  FROM category_races_categories WHERE races_category_code = 'UCIWJ' AND category_code = 'WJ' AND deleted = 0;

SELECT rr.id, er.entry_category_id, er.racer_code, rr.as_category, rr.ajocc_pt
  FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
 WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447, 277933, 277934) ORDER BY rr.id;

SELECT 'races_category_UCIWJ_modified' AS chk, modified AS val FROM races_categories WHERE code = 'UCIWJ';
SELECT 'ranking_2324_WJ_last_modified' AS chk, MAX(modified) AS val
  FROM tmp_ajoccpt_racer_sets WHERE season_id = 14 AND category_code = 'WJ';

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

-- 未処理の更新フラグ（この2出走カテゴリー分）
SELECT 'flags_pending' AS chk, COUNT(*) AS val
  FROM tmp_result_update_flags WHERE entry_category_id IN (28856, 29071) AND ajoccpt_sumuped = 0;

-- ランキング（WJ, 2026-27）に6件のポイントが載っているか。
-- 見出し行(type=0)の大会配列から大会の位置を求め、選手行の point_json のその位置にポイントがあるかを見る。
-- point_json は、大会位置が 0 から連続していると PHP の json_encode により配列（[["200"],["900"]]）、
-- 歯抜けだとオブジェクト（{"0":["200"],"2":["810"]}）になるため、両方の形式で読む。
SELECT IFNULL(CAST(s.ajoccpt_local_setting_id AS CHAR), 'national') AS ranking,
       m.code AS meet, er.racer_code, rr.ajocc_pt,
       JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)) AS meet_path,
       COALESCE(JSON_EXTRACT(s.point_json, CONCAT('$."', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), '"')), JSON_EXTRACT(s.point_json, CONCAT('$[', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), ']'))) AS pts_in_ranking,
       IFNULL(JSON_CONTAINS(COALESCE(JSON_EXTRACT(s.point_json, CONCAT('$."', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), '"')), JSON_EXTRACT(s.point_json, CONCAT('$[', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), ']'))), JSON_QUOTE(CAST(rr.ajocc_pt AS CHAR))), 0) AS pt_ok
  FROM racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
  JOIN entry_categories ec ON ec.id = er.entry_category_id
  JOIN entry_groups eg ON eg.id = ec.entry_group_id
  JOIN meets m ON m.code = eg.meet_code
  JOIN tmp_ajoccpt_racer_sets s ON s.season_id = 17 AND s.category_code = 'WJ' AND s.type = 1 AND s.racer_code = er.racer_code
  JOIN tmp_ajoccpt_racer_sets h ON h.season_id = 17 AND h.category_code = 'WJ' AND h.type = 0
       AND (h.ajoccpt_local_setting_id <=> s.ajoccpt_local_setting_id)
 WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447)
   AND (s.ajoccpt_local_setting_id IS NULL OR (s.ajoccpt_local_setting_id = 26 AND m.code = 'MDX-267-002'))
 ORDER BY ranking, m.code, er.racer_code;

-- 総合判定（全国版6件＋関東2件の計8行がすべて pt_ok=1、ほか各条件）
SELECT CASE WHEN
    (SELECT COUNT(*) FROM category_races_categories WHERE races_category_code = 'UCIWJ' AND category_code = 'WJ' AND deleted = 0) = 1
AND (SELECT COUNT(*) FROM racer_results WHERE id IN (359429, 359430, 360444, 360445, 360446, 360447, 277933, 277934) AND as_category = 'WJ' AND deleted = 0) = 8
AND (SELECT modified FROM races_categories WHERE code = 'UCIWJ')
    > (SELECT IFNULL(MAX(modified), '1970-01-01') FROM tmp_ajoccpt_racer_sets WHERE season_id = 14 AND category_code = 'WJ')
AND (SELECT COUNT(*) FROM tmp_result_update_flags WHERE entry_category_id IN (28856, 29071) AND ajoccpt_sumuped = 0) = 0
AND (SELECT COUNT(*)
       FROM racer_results rr
       JOIN entry_racers er ON er.id = rr.entry_racer_id
       JOIN entry_categories ec ON ec.id = er.entry_category_id
       JOIN entry_groups eg ON eg.id = ec.entry_group_id
       JOIN meets m ON m.code = eg.meet_code
       JOIN tmp_ajoccpt_racer_sets s ON s.season_id = 17 AND s.category_code = 'WJ' AND s.type = 1 AND s.racer_code = er.racer_code
       JOIN tmp_ajoccpt_racer_sets h ON h.season_id = 17 AND h.category_code = 'WJ' AND h.type = 0
            AND (h.ajoccpt_local_setting_id <=> s.ajoccpt_local_setting_id)
      WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447)
        AND (s.ajoccpt_local_setting_id IS NULL OR (s.ajoccpt_local_setting_id = 26 AND m.code = 'MDX-267-002'))
        AND IFNULL(JSON_CONTAINS(COALESCE(JSON_EXTRACT(s.point_json, CONCAT('$."', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), '"')), JSON_EXTRACT(s.point_json, CONCAT('$[', SUBSTRING_INDEX(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_SEARCH(h.point_json, 'one', m.code)), '[', -1), ']', 1), ']'))), JSON_QUOTE(CAST(rr.ajocc_pt AS CHAR))), 0) = 1) = 8
  THEN 'OK' ELSE 'NG' END AS POSTCHECK;
