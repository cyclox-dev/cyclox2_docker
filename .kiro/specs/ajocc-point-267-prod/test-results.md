# テスト結果記録: ajocc-point-267-prod

| 項目 | 内容 |
|---|---|
| タスクID | `ajocc-point-267-prod` |
| 実行日 | 2026-07-22 |
| 実行者 | Claude（kiro-impl autonomous mode） |
| テストフレームワーク | PHPUnit 3.7.38（CakePHP 2.10.24 組込みテストランナー経由） |
| 実行コマンド | `docker exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test app <対象パス>"` |
| 実行環境 | Docker（`cyclox2_svr` コンテナ、`cyclox2_mysql` 接続） |

---

## テスト項目一覧

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 1 | `PointCalculatorTest::testGetCalculator13ReturnsAjocc267Calculator` 他 | 正常系 | `val=13`計算器がリネーム後も取得できる | 一致 | ✅ |
| 2 | `PointCalculatorTest` 順位1位=1000点／109位=1点／110位=null | 境界値 | JCX表の境界値が正しい | 一致 | ✅ |
| 3 | `PointCalculatorTest` グレード1/2で同一結果 | 正常系 | グレード非依存であること | 一致 | ✅ |
| 4 | `PointCalculatorTest` name/description に TEST/テスト/シミュレーション文言なし | 正常系（命名整理） | 本番用文言のみ | 一致 | ✅ |
| 5 | `PointCalculatorTest` JCX_245（calc_rule=11）回帰 | 回帰 | 本改修前と同一結果 | 一致 | ✅ |
| 6 | `ResultParamCalcComponentTest::testNonJcxNewTableDivisionBoundaries` | 境界値 | 出走人数区分境界(4/5,9/10,19/20,39/40,59/60,79/80,99/100)で正しいポイント | 一致 | ✅ |
| 7 | `ResultParamCalcComponentTest::testNonJcxNewTableOutOfRangeReturnsZero` | 異常系（範囲外） | 各区分の表範囲外はポイント0 | 一致 | ✅ |
| 8 | `ResultParamCalcComponentTest` JCX rank1/109/110 | 境界値 | 1位=1000点/109位=1点/110位=0点 | 一致 | ✅ |
| 9 | `ResultParamCalcComponentTest::test{NonJcx,Jcx}DateBoundarySwitchesTables` | 境界値 | 2026-08-31は旧表、2026-09-01は新表 | 一致 | ✅ |
| 10 | `ResultParamCalcComponentTest::testNewTableAppliesPermanentlyWithoutAnyFlagCall` | 正常系（恒久適用） | フラグ未操作でも新表が適用される | 一致 | ✅ |
| 11 | `ResultParamCalcComponentTest::testStartedCountZeroOrLessReturnsErrorValueRegardlessOfDate` | 異常系 | 出走人数0人以下はエラー値-1（日付に無関係） | 一致 | ✅ |
| 12 | `ResultParamCalcComponentTest::test{NonJcx,Jcx}PastSeasonReturnsLegacyValuesRegardlessOfSimFlagHistory` | 回帰 | 2024-11-01・2025-11-01は従来表のまま（非JCX rank1=180, JCX rank1=200） | 一致 | ✅ |
| 13 | `ResultParamCalcComponentTest::testNonJcxPastSeasonDivisionBoundaryUnaffected` | 回帰（境界） | 過去シーズン分岐内部の19/20人・39/40人境界が無変更 | 一致 | ✅ |

---

## 実行結果サマリー

| スイート | 合計テスト | 合格 | 失敗 | スキップ |
|---|---|---|---|---|
| `Cyclox/Util/PointCalculatorTest`（task 2.1） | 6 | 6 | 0 | 0 |
| `Controller/Component/ResultParamCalcComponentTest`（task 3.1+3.2） | 12 | 12 | 0 | 0 |
| **合計** | **18テスト / 77アサーション** | **18** | **0** | **0** |

（各テストはimplementer実装直後・reviewer独立レビュー時・本タスク(5.1)最終実行時の計3回、独立に緑を確認済み）

---

## 失敗項目の詳細

なし（全件成功）。

---

## テスト出力（抜粋）

```
$ docker exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test app Cyclox/Util/PointCalculator"
PHPUnit 3.7.38 by Sebastian Bergmann.
......
Time: 109 ms, Memory: 12.00Mb
OK (6 tests, 21 assertions)

$ docker exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test app Controller/Component/ResultParamCalcComponent"
PHPUnit 3.7.38 by Sebastian Bergmann.
............
Time: 553 ms, Memory: 12.00Mb
OK (12 tests, 56 assertions)
```

---

## 備考

- Foundation（task 1.2）で公式AJOCCポイント表PDF（2026-2027、2026.7.7発行）と実装済み得点表を
  全9列・約500セル突き合わせ、差異なしを確認済み（数値正確性はテスト実行前の別経路で担保）。
- 命名・フラグ整理の残存確認（task 4.2）: `.php`ソース内に`_TEST`系識別子・`__simAjocc267`は
  0件。`app/tmp/logs/`（gitignore対象の実行ログ）にのみ過去の文言が残存するが、
  ソースコード外の生成物のため対象外。
- `app/Console/Command/PointSimShell.php`は task 4.1 で削除済み。他ファイルからのコード上の
  参照が無いことを削除前後で確認済み（コメント1件・自動生成キャッシュ1件のみ残存、
  いずれもコード依存なし）。
- 結合試験（DB上の実データ・画面表示・CSV出力等）は task 5.2 のチェックリストとして
  別途手動確認する。

---

## 結合試験の実施記録（2026-08-16 追記）

`integration-test-checklist.md` の全17項目を **2026-08-16 に実施し、全て確認済み（NG 0件）**。
`tohoku-series-2026-27` の結合試験と合同で実施した（先行リリース
`release/2026-27-season-rules` → `main` に両 spec の変更が含まれるため）。

実データ上で確認できた主な証跡:

| 確認内容 | 結果 |
|---|---|
| 2025-26 の `ajocc_pt` 非影響 | 東海25-26 ME3 全7戦を再計算し、合計値が再計算前と完全一致 |
| 境界日付（非JCX） | 2026-08-31=旧表(150/120/100)、2026-09-01=新8区分表(300/250/220) |
| 境界日付（JCX） | 2026-09-01 かつ `is_jcx=1` で新JCX列(1000/900/810) |
| `calc_rule=13` のシリーズ集計 | 1000/900/810/730/660/600 が付与され正常動作 |
| res-sys 表示 | 2026-09-01開催として 300pt/ME3 … を表示、崩れなし |
| CSV出力 | AJOCCランキングCSV(SJIS)・シリーズランキングCSV(UTF-8) とも形式不変 |
| `PointSimShell` 削除 | Console一覧に非表示、ファイルも不存在 |

境界日付の確認は、開発環境DBに2026-27の大会が0件のため既存大会の `at_date` / `is_jcx` を
一時変更する方式で実施し、確認後に原状復帰した（復帰後の値がベースラインと一致することを確認）。
