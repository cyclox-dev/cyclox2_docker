-- 99d_enqueue_wj_regen.sql — 取り消し④: WJ×2026-27 ランキングの作り直しを予約（書き込み。要承認）
-- 期待: affected = 1。99b の後に実行する。
--
-- 【リハーサルで判明】ランキング更新バッチは「フラグの出走カテゴリーが現在持つ as_category」のランキングしか
-- 作り直さない。6件を UCIWJ に戻したあと是正対象（28856, 29071）にフラグを立てても、UCIWJ はカテゴリーとして
-- 認識されずスキップされ、WJ ランキングに松伏・琵琶湖が残る。そのため、2026-27 で as_category=WJ の成績を
-- 持つ別の AJOCC 対象出走カテゴリーにフラグを立て、通常のバッチで WJ×2026-27 を作り直させる。

INSERT INTO tmp_result_update_flags (entry_category_id, result_updated, points_sumuped, ajoccpt_sumuped, created, modified)
SELECT MIN(ec.id), NOW(), 1, 0, NOW(), NOW()
  FROM racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
  JOIN entry_categories ec ON ec.id = er.entry_category_id
  JOIN entry_groups eg ON eg.id = ec.entry_group_id
  JOIN meets m ON m.code = eg.meet_code
 WHERE rr.as_category = 'WJ' AND rr.deleted = 0 AND er.deleted = 0
   AND ec.deleted = 0 AND eg.deleted = 0 AND m.deleted = 0
   AND ec.applies_ajocc_pt = 1 AND m.season_id = 17
   AND ec.id NOT IN (28856, 29071)
HAVING MIN(ec.id) IS NOT NULL;
SELECT ROW_COUNT() AS affected, LAST_INSERT_ID() AS inserted_flag_id;
