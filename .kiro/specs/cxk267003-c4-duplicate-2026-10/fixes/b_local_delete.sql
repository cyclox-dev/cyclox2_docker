-- b. ローカル: 未送信のまま残った C4 13行を削除（サーバー版 269115〜269127 は残す）
SELECT COUNT(*) FROM category_racers WHERE id BETWEEN 300429 AND 300441 AND id_on_svr IS NULL AND category_code='C4' AND meet_code='CXK-267-003';
BEGIN;
DELETE FROM category_racers WHERE id BETWEEN 300429 AND 300441 AND id_on_svr IS NULL AND category_code='C4' AND meet_code='CXK-267-003';
SELECT changes();
COMMIT;
SELECT racer_code, group_concat(id||':'||ifnull(id_on_svr,'NULL')) FROM category_racers WHERE racer_code BETWEEN 'CXK-267-0025' AND 'CXK-267-0037' AND category_code='C4' GROUP BY racer_code;
SELECT COUNT(*) AS pending_upload FROM category_racers WHERE id_on_svr IS NULL;
