-- 総エントリー数の検証用 SQL（ressys のモデルと同じ条件）
-- 使い方: mysql ... < verify_total_entries.sql（@meet を書き換える）
SET @meet = 'KNS-267-003';

-- ressys の実装と同じ定義（T1/T2）
SELECT COUNT(*) AS total_entries
FROM entry_groups eg
JOIN entry_categories ec ON ec.entry_group_id = eg.id
JOIN entry_racers er ON er.entry_category_id = ec.id
WHERE eg.meet_code = @meet AND eg.deleted = 0 AND ec.deleted = 0 AND er.deleted = 0;

-- deleted を無視した場合（T2 の比較用）
SELECT COUNT(*) AS total_entries_ignoring_deleted
FROM entry_groups eg
JOIN entry_categories ec ON ec.entry_group_id = eg.id
JOIN entry_racers er ON er.entry_category_id = ec.id
WHERE eg.meet_code = @meet;

-- racer_results 結合版（T3 の比較用。リザルトのある選手のみ）
SELECT COUNT(*) AS entries_with_result
FROM entry_groups eg
JOIN entry_categories ec ON ec.entry_group_id = eg.id
JOIN entry_racers er ON er.entry_category_id = ec.id
JOIN racer_results rr ON rr.entry_racer_id = er.id AND rr.deleted = 0
WHERE eg.meet_code = @meet AND eg.deleted = 0 AND ec.deleted = 0 AND er.deleted = 0;
