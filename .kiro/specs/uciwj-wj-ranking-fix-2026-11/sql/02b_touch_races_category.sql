-- 02b_touch_races_category.sql — 種目 UCIWJ の更新日時を進め、デスクトップアプリに対応の変更を配信する（書き込み。本番は要承認）
-- 期待: affected = 1
-- アプリの基本データ同期（ApiController の updated_base_data）は、いずれかの種目の modified が前回同期より
-- 新しいときだけ全種目の対応カテゴリー一覧（qualifiedCatCodes）を返す。対応表に行を足しただけでは届かない。
-- 取り消し（99a）でも同じ更新を行い、対応の削除を配信する。

UPDATE races_categories SET modified = NOW() WHERE code = 'UCIWJ' AND deleted = 0;
SELECT ROW_COUNT() AS affected;

SELECT code, name, modified FROM races_categories WHERE code = 'UCIWJ';
