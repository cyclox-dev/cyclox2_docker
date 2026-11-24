-- 99c_revert_2324.sql — 取り消し③: 2023-24 の2件を UCIWJ に戻す（書き込み。要承認）
-- 期待: affected = 2（03b を実行していなければ 0 で正常）

UPDATE racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
   SET rr.as_category = 'UCIWJ', rr.modified = NOW()
 WHERE rr.id IN (277933, 277934)
   AND er.entry_category_id = 19879
   AND rr.as_category = 'WJ'
   AND rr.deleted = 0 AND er.deleted = 0;
SELECT ROW_COUNT() AS affected;
