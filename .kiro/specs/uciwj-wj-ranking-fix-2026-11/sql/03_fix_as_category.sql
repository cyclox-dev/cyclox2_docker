-- 03_fix_as_category.sql — 是正対象6件の成績対象カテゴリーを UCIWJ → WJ に更新（書き込み。本番は要承認）
-- 期待: affected = 6。WHERE 句（id・出走カテゴリー・現在値の3条件）により、最大でも6行しか変わらない。
-- 6未満なら停止して報告（必要なら 99_rollback）。as_category と modified 以外の列は変更しない。

UPDATE racer_results rr
  JOIN entry_racers er ON er.id = rr.entry_racer_id
   SET rr.as_category = 'WJ', rr.modified = NOW()
 WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447)
   AND er.entry_category_id IN (28856, 29071)
   AND rr.as_category = 'UCIWJ'
   AND rr.deleted = 0 AND er.deleted = 0;
SELECT ROW_COUNT() AS affected;

SELECT rr.id, er.entry_category_id, er.racer_code, rr.as_category, rr.ajocc_pt, rr.modified
  FROM racer_results rr JOIN entry_racers er ON er.id = rr.entry_racer_id
 WHERE rr.id IN (359429, 359430, 360444, 360445, 360446, 360447) ORDER BY rr.id;
