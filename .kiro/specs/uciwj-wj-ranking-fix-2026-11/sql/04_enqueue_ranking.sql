-- 04_enqueue_ranking.sql — ランキング再生成用の更新フラグを2行追加（書き込み。本番は要承認）
-- 期待: affected = 2。毎時のランキング更新バッチが拾い、WJ×2026-27 の全国版・全地域版を作り直す。
-- points_sumuped = 1: ポイントシリーズは as_category に依存しないため再計算させない。

INSERT INTO tmp_result_update_flags (entry_category_id, result_updated, points_sumuped, ajoccpt_sumuped, created, modified)
VALUES (28856, NOW(), 1, 0, NOW(), NOW()),
       (29071, NOW(), 1, 0, NOW(), NOW());
SELECT ROW_COUNT() AS affected, LAST_INSERT_ID() AS first_inserted_id;

SELECT * FROM tmp_result_update_flags WHERE entry_category_id IN (28856, 29071) ORDER BY id DESC LIMIT 2;
