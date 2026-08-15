# テスト結果記録: jcx-lineage-lock-2026-27

| 項目 | 内容 |
|---|---|
| タスクID | `jcx-lineage-lock-2026-27` |
| 実行日 | 2026-08-15 |
| 実行者 | Claude |
| テストフレームワーク | PHPUnit 3.7.38（CakePHP 2.10.24 組込みテストランナー経由） |
| 実行コマンド | `docker compose exec cyclox2_svr bash -c "cd /var/www/html/app && ./Console/cake test app <対象パス>"` |
| 実行環境 | Docker（`cyclox2_svr` コンテナ、`cyclox2_mysql` 接続） |

---

## テスト項目一覧（タスク別）

### タスク2.1〜2.3: コア判定ロジック（`JcxLineageLockTest`）

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 1 | `testLineageOfRacesCategoryResolvesElite`/`Masters` | 正常系 | 種目→系統解決（elite/masters） | 一致 | ✅ |
| 2 | `testLineageOfRacesCategoryReturnsNullForNonManagedOnly` | 境界値 | 対応表対象外カテゴリー（CL2等）は対象外 | 一致 | ✅ |
| 3 | `testLineageOfRacesCategoryReturnsNullForMixedLineage` | 異常系 | 両系統混在種目は判定不能（null） | 一致 | ✅ |
| 4 | `testLineageOfRacesCategoryReturnsNullForNoMapping` | 異常系 | 紐づけ無し種目は判定不能（null） | 一致 | ✅ |
| 5 | `testFixedLineageIsNullWithNoEntries` | 正常系 | 未エントリーは未確定（null） | 一致 | ✅ |
| 6 | `testFixedLineagePicksEarliestAtDate` | 正常系 | 開催日昇順の先頭を固定系統とする | 一致 | ✅ |
| 7 | `testFixedLineageTieBreaksBySameDateByEntryRacerId` | 境界値 | 同日開催時はentry_racer.id昇順でタイブレーク | 一致 | ✅ |
| 8 | `testFixedLineageExcludesDeletedEntries` | 異常系 | 取消済み（deleted）エントリーは算出対象外 | 一致 | ✅ |
| 9 | `testFixedLineageIgnoresNonJcxAndOtherSeasonEntries` | 正常系 | 非JCX大会・他シーズンは不算入 | 一致 | ✅ |
| 10 | `testFixedLineageExcludeParameterShiftsBasis` | 正常系 | exclude指定（meetCode/entryRacerIds）で根拠が変わる | 一致 | ✅ |
| 11 | `testIsCheckTargetFalseForPreEffectiveFromSeason` | 境界値 | 適用開始前シーズンは対象外 | 一致 | ✅ |
| 12 | `testIsCheckTargetTrueForJcxMeetInApplicableSeason` | 正常系 | 適用開始後・JCX大会は対象 | 一致 | ✅ |
| 13 | `testIsCheckTargetFalseForNonJcxMeet` | 正常系 | 非JCX大会は対象外 | 一致 | ✅ |
| 14 | `testIsCheckTargetFalseForUnknownMeet` | 異常系 | 存在しない大会はfail-open（対象外） | 一致 | ✅ |
| 15 | `testCheckPassesWhenNoFixedLineage` | 正常系 | 未確定時は通過 | 一致 | ✅ |
| 16 | `testCheckPassesWhenLineageMatches` | 正常系 | 一致時は通過 | 一致 | ✅ |
| 17 | `testCheckReturnsViolationWithFullDetailWhenLineageMismatches` | 正常系（違反明細） | 選手・固定系統・違反系統・根拠大会・開催日を含む | 一致 | ✅ |
| 18 | `testCheckPassesForNonJcxMeetRegardlessOfLineage` | 正常系 | 非JCX大会は系統に関わらず通過 | 一致 | ✅ |
| 19 | `testCheckPassesForUnresolvableRacesCategory` | 正常系 | 判定不能種目は通過 | 一致 | ✅ |
| 20 | `testCheckBulkAggregatesMultipleViolations` | 正常系 | 複数選手の違反を集約 | 一致 | ✅ |
| 21 | `testCheckBulkPassesEntirelyForNonJcxMeet` | 正常系 | 大会不存在時は安全側で通過 | 一致 | ✅ |
| 22 | `testModeReadsConfigureWithFallback` | 異常系 | 不正値/未設定時は'warn'へフォールバック | 一致 | ✅ |
| 23 | `testDetectViolatorsInSeasonFindsOnlyRacersWithBothLineages` | 正常系 | 両系統保有選手のみ検出 | 一致 | ✅ |
| 24 | `testDetectViolatorsInSeasonIncludesRequiredOutputFields` | 正常系 | 出力項目（選手・大会・開催日・系統）を含む | 一致 | ✅ |
| 25 | `testDetectViolatorsInSeasonReturnsEmptyWhenNoViolators` | 正常系 | 違反無しは空配列 | 一致 | ✅ |
| 26 | `testCheckBulkFixedLineageQueryCountIsConstantRegardlessOfItemCount` | 性能 | 20選手でもクエリ回数は定数（3回以内） | 一致 | ✅ |

### タスク3.1〜3.2: モデル層の強制点

| # | テスト項目名（クラス） | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 27-33 | `EntryRacerTest`（7件） | 正常系/異常系 | 非JCX無影響／JCX初回通過／違反拒否+明細保持／override通過／blockでoverride無効／racer_codeのみ更新は対象外／skipsJcxLineageCheckで完全バイパス | 全一致 | ✅ |
| 34-37 | `EntryCategoryTest`（4件） | 正常系/異常系 | 新規作成は無発火／他フィールド更新は無発火／races_category_code変更で所属選手全員検証／override通過 | 全一致 | ✅ |

### タスク4.1〜4.2: 管理画面UX

| # | テスト項目名（クラス） | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 38-41 | `EntryRacersControllerTest`（4件） | 正常系/異常系 | warn時警告表示／確認付き再送信で保存+ログ記録／blockモードは確認UI無し／正常登録は無影響 | 全一致 | ✅ |
| 42-46 | `EntryCategoriesControllerTest`（5件） | 正常系/異常系 | edit()のwarn/block分岐、`__checkJcxLineageLockForResultImport()`の検知（非ブロック） | 全一致 | ✅ |

### タスク5.1: 外部API一括登録

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 47 | `testAddEntryWarnModeCompletesDespiteViolation` | 正常系 | warnモードでは違反があっても登録完了 | 一致 | ✅ |
| 48 | `testAddEntryBlockModeRejectsAndSavesNothing` | 異常系 | blockモードは削除も行わず拒否 | 一致 | ✅ |
| 49 | `testAddEntrySameMeetReuploadDoesNotSelfConflict` | 正常系 | 自大会の旧エントリーはexcludeで自己衝突しない | 一致 | ✅ |
| — | 既存4件（me-mm-linkage-2026-27分、`upload_category_racers`） | 回帰 | 無変更で成功 | 一致 | ✅ |

### タスク6.1: 違反検出シェル

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 50 | `testDetectListsOnlyBothLineageRacersWithRequiredFields` | 正常系 | 両系統選手のみ、選手・大会・開催日・系統を出力 | 一致 | ✅ |
| 51 | `testDetectOutputsCsvFormatWhenRequested` | 正常系 | --csvでヘッダ+選手×エントリー単位の行 | 一致 | ✅ |
| 52 | `testDetectHandlesNoViolatorsGracefully` | 正常系 | 違反無しはエラーにならず案内文言 | 一致 | ✅ |
| 53 | `testDetectStopsWithErrorForNonExistentSeason` | 異常系 | 不在シーズンはexit 1 | 一致 | ✅ |
| 54 | `testDetectResolvesCurrentSeasonWhenOmitted` | 正常系 | season省略時は本日が属するシーズンを自動解決 | 一致 | ✅ |

---

## 実行結果サマリー（アプリ全体、2026-08-15最終実行）

| スイート | 合計テスト | 合格 | 失敗 |
|---|---|---|---|
| `Cyclox/Util/JcxLineageLockTest` | 27 | 27 | 0 |
| `Model/EntryRacerTest` | 7 | 7 | 0 |
| `Model/EntryCategoryTest` | 4 | 4 | 0 |
| `Controller/EntryRacersControllerTest` | 4 | 4 | 0 |
| `Controller/EntryCategoriesControllerTest` | 5 | 5 | 0 |
| `Controller/ApiControllerTest`（jcx分3件+me-mm-linkage分4件） | 7 | 7 | 0 |
| `Console/Command/JcxLineageCheckShellTest` | 5 | 5 | 0 |
| **jcx-lineage-lock-2026-27 小計** | **59** | **59** | **0** |
| `Cyclox/Const/CategoryLineageMapTest`（既存・回帰） | 11 | 11 | 0 |
| `Cyclox/Util/CategoryLineageLinkerTest`（既存・回帰） | 45 | 45 | 0 |
| `Cyclox/Util/PointCalculatorTest`（既存・回帰） | 6 | 6 | 0 |
| `Controller/Component/ResultParamCalcComponentTest`（既存・回帰） | 25 | 25 | 0 |
| `Controller/CategoryRacersControllerTest`（既存・回帰） | 11 | 11 | 0 |
| `Controller/OrgUtilControllerTest`（既存・回帰） | 6 | 6 | 0 |
| `Console/Command/CatLimitShellTest`（既存・回帰） | 5 | 5 | 0 |
| `Integration/MeMmLinkageIntegrationTest`（既存・回帰） | 7 | 7 | 0 |
| `Model/CategoryRacerTest`（既存・回帰） | 15 | 15 | 0 |
| `Model/CategoryRacerFixtureDataTest`（既存・回帰） | 8 | 8 | 0 |
| **既存（me-mm-linkage-2026-27/ajocc-point-267-prod）小計** | **139** | **139** | **0** |
| **アプリ全体合計** | **198テスト / 787アサーション** | **198** | **0** |

（`app/Test/Case/` 配下の全17テストケースファイルを実行。jcx-lineage-lock-2026-27 の実装が
既存の me-mm-linkage-2026-27 / ajocc-point-267-prod の機能に一切影響していないことを確認済み。
Requirement 7.1「非JCX戦の非影響」は、各スイートの既存テストが全て無変更で成功していることで
裏付けられる）

---

## 失敗項目の詳細

なし（全件成功）。

### 実装中に発生し、原因究明のうえ解消した問題（参考記録）

タスク7時点で新規の失敗は無いが、実装過程で1件、テスト間の副作用が見つかり解消済み
（詳細は agreement-log.md 参照）:

- `JcxLineageLockTest`（タスク2、Util層単体テスト）は `EntryRacer::beforeSave()` の強制点
  実装（タスク3）より前に書かれており、テストデータ投入ヘルパーが通常の `Model::save()` を
  使っていたため、タスク3導入後は意図的な「逆順」データ投入が、フック自身に本物の違反として
  保存拒否されてしまっていた。`skipsJcxLineageCheck=true` を設定して解消した。

---

## 性能検証（タスク7.2, 7.3）

### 7.3: `checkBulk()` のクエリ回数（選手数非依存）

初版実装は `checkBulk()` が内部で選手ごとに `check()`→`fixedLineage()` を呼んでおり、
選手数に比例したクエリが発行される状態だった（design.md が意図していた「IN句1クエリへの
集約」が未達成）。実装中に気づき、`__fixedLineagesForRacers()` へリファクタリングして
`EntryRacer.racer_code IN (...)` の単一クエリへ集約した（コミット `2479bcd`）。

`testCheckBulkFixedLineageQueryCountIsConstantRegardlessOfItemCount` で、20選手分の
`checkBulk()` 呼び出しにおける固定系統算出クエリが3回以内（選手数に依存しない定数）に
収まることを確認済み。

### 7.2: 個別チェックの追加クエリ数（メモ化）

`check()` 1回あたりの概算クエリ数（同一リクエスト内でメモ化が効く2回目以降は減少）:

| 呼び出し | 初回 | 2回目以降（同一 meetCode/racesCategoryCode） |
|---|---|---|
| `isCheckTarget()`（Meet+Season解決） | 2 | 0（`$meetCache` でメモ化） |
| `lineageOfRacesCategory()` | 1 | 0（`$lineageCache` でメモ化） |
| `fixedLineage()`（選手ごと） | 1 | 1（選手が変われば毎回） |
| `__racerName()`（違反時のみ） | 1 | 1（選手が変われば毎回） |

大会・種目のメモ化により、同一大会・同一種目への複数選手のチェック（`checkBulk()` の実利用
シーン）では大会解決コストが1回に抑えられている。個別選手ごとの固定系統算出クエリ自体は
選手ごとに必要な情報のため削減できないが、`checkBulk()` 経路ではこれも1クエリへ集約済み。

### 【人間への提案】インデックス不足（実装せず、提案として記録）

Requirement 7.2/7.3 の検証にあたり `EXPLAIN` を確認したところ、本機能が新たに発行する
JOINクエリ（`entry_racers` → `entry_categories` → `entry_groups` → `meets`）で、
以下のテーブル・カラムに**インデックスが存在せず、フルテーブルスキャンが発生する**ことを
確認した（本番相当データ、`entry_racers` 554,130行）。

```
EXPLAIN SELECT ... FROM entry_racers AS EntryRacer
INNER JOIN entry_categories AS EntryCategory ON EntryRacer.entry_category_id = EntryCategory.id
INNER JOIN entry_groups AS EntryGroup ON EntryCategory.entry_group_id = EntryGroup.id
INNER JOIN meets AS Meet ON EntryGroup.meet_code = Meet.code
WHERE EntryRacer.racer_code IN (...) AND ... AND Meet.is_jcx=1 AND Meet.season_id=...;

+----+-------------+--------------+------+---------------+------+
| id | table       | type         | key  | rows          | Extra
+----+-------------+--------------+------+---------------+------+
| 1  | EntryRacer  | ALL          | NULL | 554130        | Using where
| 1  | EntryCategory | eq_ref (PK)| PRIMARY | 1          | Using where
| 1  | Meet        | ALL          | NULL | 792           | Using where; Using join buffer
| 1  | EntryGroup  | eq_ref (PK)| PRIMARY | 1             | Using where
```

**提案**: 以下のインデックス追加を推奨する（本specのスコープ外のため実装はしていない）。

| テーブル | 追加候補 | 理由 |
|---|---|---|
| `entry_racers` | `racer_code`（非ユニーク） | `WHERE racer_code IN (...)` の絞り込み。現状PKのみでフルスキャン |
| `entry_categories` | `entry_group_id`（非ユニーク） | JOIN条件。現状PKのみ |
| `entry_groups` | `meet_code`（非ユニーク） | JOIN条件。現状PKのみ |
| `meets` | `(season_id, is_jcx)` の複合、または `season_id` 単独 | `WHERE season_id=... AND is_jcx=1` の絞り込み |
| `category_races_categories` | `races_category_code`（非ユニーク） | `lineageOfRacesCategory()` の絞り込み。現状PKのみ |

現状のデータ規模（`entry_racers` 55万行、`meets` 792行）とJCX大会の頻度（792件中62件、
約8%）を踏まえると、本機能の呼び出し頻度（エントリー登録・種目変更・API一括登録の都度）で
体感できる遅延が生じる可能性がある。ただし影響度・優先度の判断とインデックス追加の実施は
DBスキーマ変更を伴うため、人間の判断を仰ぐこととし、本spec側では実装しない
（tasks.md「インデックス不足が判明した場合は追加を実装せず人間へ提案として記録する」に従う）。

---

## テスト出力（抜粋）

```
$ docker compose exec cyclox2_svr bash -c "cd /var/www/html/app && ./Console/cake test app Cyclox/Util/JcxLineageLock"
PHPUnit 3.7.38 by Sebastian Bergmann.
...........................
Time: 1.79 seconds, Memory: 14.00Mb
OK (27 tests, 57 assertions)

$ docker compose exec cyclox2_svr bash -c "cd /var/www/html/app && ./Console/cake test app Console/Command/JcxLineageCheckShell"
PHPUnit 3.7.38 by Sebastian Bergmann.
.....
Time: 446 ms, Memory: 12.00Mb
OK (5 tests, 14 assertions)
```
