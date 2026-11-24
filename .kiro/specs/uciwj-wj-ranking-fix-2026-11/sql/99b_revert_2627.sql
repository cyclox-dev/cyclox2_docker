-- 99b_revert_2627.sql — 取り消し②: 2026-27 の6件を UCIWJ に戻す（書き込み。要承認）
-- 期待: affected = 6（03 が途中までしか効いていない場合は、そのとき実際に WJ になっている件数）

UPDATE racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
   SET rr.as_category = 'UCIWJ', rr.modified = NOW()
 WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447)
   AND er.entry_category_id IN (28856, 29071)
   AND rr.as_category = 'WJ'
   AND rr.deleted = 0 AND er.deleted = 0;
SELECT ROW_COUNT() AS affected;
