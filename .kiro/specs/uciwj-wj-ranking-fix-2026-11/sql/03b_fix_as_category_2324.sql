-- 03b_fix_as_category_2324.sql — 2023-24 JPN-234-002 の2件の成績対象カテゴリーを UCIWJ → WJ（書き込み。本番は要承認）
-- 期待: affected = 2。公開サイトのレース結果ページの表示を「pt/WJ」に揃えるため（要件5.1）。
-- 2023-24 のランキングは作り直さない（更新フラグは立てない。要件5.3）。
-- 2名とも大会日に WJ を保有していない（CL1 のみ）。WJ ランキングは保有者しか載せないため、
-- 仮に 2023-24 WJ ランキングが作り直されても2名は載らない。

UPDATE racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
   SET rr.as_category = 'WJ', rr.modified = NOW()
 WHERE rr.id IN (277933, 277934)
   AND er.entry_category_id = 19879
   AND rr.as_category = 'UCIWJ'
   AND rr.deleted = 0 AND er.deleted = 0;
SELECT ROW_COUNT() AS affected;

SELECT rr.id, er.entry_category_id, er.racer_code, rr.as_category, rr.ajocc_pt, rr.modified
  FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
 WHERE rr.id IN (277933, 277934) ORDER BY rr.id;
