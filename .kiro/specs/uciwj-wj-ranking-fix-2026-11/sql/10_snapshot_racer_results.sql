-- 10_snapshot_racer_results.sql — 前後比較用に racer_results 全行を出力（SELECT のみ。承認不要）
-- 使い方: `mysql -B cyclox2 < 10_snapshot_racer_results.sql > outputs/snapshot_<before|after>.tsv`
-- 比較は tools/compare_snapshots.py で行う（要件1.3, 2.4, 2.5）。
-- 出力は .kiro/specs/<id>/outputs/（git 管理外）に置く。

SELECT * FROM racer_results ORDER BY id;
