# 設計: 2025-26シーズン AJOCC実績レポート（判定ロジック・データ構造・手順）

非コーディング（DB集計・レポート作成）作業のため、フェーズを踏まず本ファイルで
判定ロジック・データ構造・抽出手順のみを記述する（`docs/sdd/workflow.md`「非コーディング作業の
ドキュメント化」節に準拠）。

## シーズン日付境界
`at_date >= '2025-04-01' AND at_date < '2026-04-01'`（4月始まり年度、`docs/sdd`外の過去ログ慣習に準拠）

## 地域・シリーズマッピング（`meet_groups`テーブル、実データで検証済み）

`meets.meet_group_code` → `meet_groups.code` で地域を特定する。**`meet_groups.short_name`をそのまま
使うと2件だけ実際のレポート表記とズレる**ため、レポート表記への読み替えが必要（24-25シーズンの実データで
地域別エントリー合計が PDF P.7 の値（21,268件、16地域）と完全一致することで検証済み）。

| meet_group_code | DB short_name | レポート表記 | 備考 |
|---|---|---|---|
| KNS | 関西 | 関西 | |
| TKI | 東海 | 東海 | |
| CXK | 関東 | **茨城** | DB名は歴史的経緯（秩父・茨城クロス）で「関東」のままだが、レポートでは実態に合わせ「茨城」表記 |
| CHB | 千葉 | 千葉 | |
| CCM | 信州 | 信州 | |
| TCX | 東北 | 東北 | |
| MDX | 野田 | 野田 | |
| SHN | 湘南 | 湘南 | |
| CCS | 四国 | 四国 | |
| MBS | 前橋 | 前橋 | |
| YGC | 山口 | 山口 | |
| MMJ | もみじ | もみじ | |
| XTK | 東京 | 東京 | |
| CCH | 中国 | 中国 | |
| QCX | 九州 | 九州 | |
| TYM | 富山 | **北陸** | DB名は「富山」だが、レポートでは広域地方名「北陸」表記 |
| JPN | 全日本 | （集計除外） | AJOCC全体（68戦・21,268件等）の集計対象外。P.5下段の「全日本選手権エントリー推移」で別途扱う |
| HKD | 北海道 | - | 24-25シーズンに実績なし（0件）。25-26で実績があれば追加検討 |
| UCX | 宇都宮 | - | 同上 |

検証SQL（24-25シーズンで実行し、PDF P.7の地方別合計と完全一致を確認済み）:
```sql
SELECT m.meet_group_code, mg.short_name, COUNT(*) AS entry_count
FROM entry_racers er
INNER JOIN entry_categories ec ON ec.id = er.entry_category_id
INNER JOIN entry_groups eg ON eg.id = ec.entry_group_id
INNER JOIN meets m ON m.code = eg.meet_code
LEFT JOIN meet_groups mg ON mg.code = m.meet_group_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0
  AND m.at_date >= '<season_start>' AND m.at_date < '<season_end>'
  AND er.entry_status = 0
GROUP BY m.meet_group_code, mg.short_name
ORDER BY entry_count DESC;
```
（JCX/ローカル大会の切り分けは `meets.is_jcx` フラグで判定）

## カテゴリー大分類マッピング

**重要な発見**: 25-26シーズンでカテゴリーコード体系そのものが変更されている（AJOCC側の制度変更、
得点表改定と同時期）。24-25版の `ME1-4`/`WE1-3`/`MM1-6` 等のコードは25-26データには存在せず、
以下の新コードに置き換わっている。大分類（男子実力別/女子/男子14-18歳/マスターズ/小学生/その他）の
枠組み自体は24-25版から変更なし（合意事項#4）だが、コードから大分類への対応表は新コード基準で
作り直した（2026-07-02、ユーザー確認済み）。

| 大分類 | 24-25の該当コード（参考・旧） | 25-26の該当コード（新） |
|---|---|---|
| 男子実力別 | ME1, ME2, ME3, ME4 | **C1, C2, C3, C4, C3+4**、UCIME（UCI男子エリート、合算） |
| 女子 | WE1, WE2, WE2+3, WE3, WJ, WU15, WU17, WM | **CL1, CL2, CL3, CL2+3**, WJ, WU15, WU17, WM、UCIWE（UCI女子エリート、合算） |
| 男子14-18歳 | CJ, MU15, MU17 | CJ, MU15, MU17（変化なし）、UCIMJ（UCI男子ジュニア、合算） |
| 男子マスターズ | MM1, MM2, MM3, MM35, MM40, MM50, MM60 | **CM1, CM2, CM3**（旧MM1-3相当）＋ **MM35, MM40, MM45, MM50, MM55, MM60, MM65, MM70, MM75**（年齢帯別に細分化、いずれもマスターズ扱い） |
| 小学生 | CK1, CK2, CK3 | CK1, CK2, CK3, CK1+2（変化なし） |
| その他 | Ex, 上記以外 | CC, SS, Exhibition |

（`ec.races_category_code` の値で判定。25-26シーズンの実データで新コードの網羅性を確認済み）

## 全日本選手権（P.5下段）
- 25-26シーズン開催: **2025-12-14、会場: 二色の浜**（合意事項#3）

## Web閲覧数（P.3/P.4/P.14/P.15）
- 実データ未入手のため **仮値 100,000（月平均ビュー数として）を採用し、レポート上で「（仮）」と明記**する（合意事項#1）
- P.14/P.15のページ別内訳・Top10ランキングは仮値のみでは構成できないため、**「実データ入手後に更新予定」の注記付きプレースホルダ**とする

## 既知の修正事項
- 24-25版PDF P.3の見出し誤字（「2023-2024 シーズンまとめ」だが中身は2024-2025データ）は25-26版で正しい年度表記に修正する

## 出力先
- 抽出CSV: `.kiro/specs/ajocc-report-2025-26/outputs/`（git管理外）
- レポート本体: `.kiro/specs/ajocc-report-2025-26/outputs/25-26_AJOCC_report.pptx`（git管理外、個人情報を含み得るため）
