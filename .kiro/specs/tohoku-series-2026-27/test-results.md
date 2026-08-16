# テスト結果記録: tohoku-series-2026-27

| 項目 | 内容 |
|---|---|
| タスクID | `tohoku-series-2026-27` |
| 実行日 | 2026-08-16 |
| 実行者 | Claude（オーケストレーター直接実装） |
| テストフレームワーク | PHPUnit 3.7.38（CakePHP 2.10.24 組込みテストランナー経由） |
| 実行コマンド | `docker exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test app <対象パス>"` |
| 実行環境 | Docker（`cyclox2_svr` コンテナ、`cyclox2_mysql` 接続） |
| 対象ブランチ | `feat/tohoku-series-2026-27`（`origin/release/2026-27-season-rules` = `0635466` から分岐） |

---

## サマリ

| スイート | 結果 | テスト数 | アサーション数 |
|---|---|---|---|
| `app/Test/Case/Cyclox/Util/PointCalculatorTest.php` | ✅ OK | 18 | 2182 |
| `app/Test/Case/Controller/Component/ResultParamCalcComponentTest.php` | ✅ OK | 12 | 56 |

> 独立レビューの指摘（B-1/B-2/B-5）を受けたテスト補強後の値。補強前は 17 テスト / 2173 アサーション。

TDD の RED フェーズでは、実装前に 15テスト中9件が **assertion failure** で失敗することを確認した
（fatal error による中断ではないこと＝タスク2.1 の完了条件を満たすこと、を実行して確認）。

---

## テスト項目一覧（新規追加分）

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 1 | `testTcx267IsRegisteredWithExpectedName` | 正常系 | `getCalculator(14)` が `name()='TCX_267'` / `val()=14` を返す | 一致 | ✅ |
| 2 | `testTcx267DescriptionAndTextContainRequiredTerms` | 正常系 | `description()` に「東北」、`text()` に「JCX」「ボーナス」「グレード」 | 一致 | ✅ |
| 3 | `testTcx267TextContainsAllEightDivisionHeadings` | 正常系 | `text()` が8区分の見出し（`100人以上`〜`1人以上`）を全て含む | 一致 | ✅ |
| 4 | `testTcx267ReturnsNoBonus` | 正常系 | 返却値に `bonus` キーを含まない | 一致 | ✅ |
| 5 | `testTcx267IsGradeIndependent` | 正常系 | グレード 1 / 2 / null で同一結果 | 一致 | ✅ |
| 6 | `testTcx267EmptyRankReturnsNull` | 異常系 | `rank` が null / キー無しで `null` | 一致 | ✅ |
| 7 | `testTcx267DivisionBoundaries` | 境界値 | 出走人数 4/5、9/10、19/20、39/40、59/60、79/80、99/100 で適用区分が切替 | 一致 | ✅ |
| 8 | `testTcx267RankBoundariesPerDivision` | 境界値 | 全8区分で 1位=規定点、最終要素=1点、範囲外=`null` | 一致 | ✅ |
| 9 | `testTcx267EquivalenceWithAjoccPointTable` | 等価性 | 出走人数16通り×順位1〜125（2000ペア）が System① の `calcAjoccPt()` と一致 | 全ペア一致 | ✅ |
| 10 | `testTcx245RegressionUnaffectedByTcx267Addition` | 回帰 | `TCX_245`(val=12) の3区分の代表値・範囲外が不変 | 一致 | ✅ |
| 11 | `testCalculatorRegistryIsExtendedWithoutChangingExistingEntries` | 回帰 | 登録件数14、`val=1`〜`13` の `val()`/`name()` が不変 | 一致 | ✅ |
| 12 | `testTcx267ZeroOrNegativeStartedCountReturnsNull` | 異常系 | 出走人数 0 / -1 で `null` | 一致 | ✅ |

### 独立レビュー後に補強したアサーション

| 観点 | 追加内容 | ミューテーション検証 |
|---|---|---|
| `$text` の改行補正 | `,---` が出現しないこと（区分末尾が改行され次区分と連結しない） | ループ条件から `\|\| $j == $n - 1` を一時的に外すとテストが失敗することを実行して確認（確認後に復元） |
| 年度表記のコピペミス | `description()`/`text()` に `2026-27` / `26-27 AJOCC` を含み、`2024-25` / `24-25 AJOCC` を含まないこと | — |
| 出走人数0以下 | `calc()` が `null` を返すこと | — |

## 既存テスト（非回帰確認）

`ajocc-point-267-prod` が追加した既存6テスト（`testAjocc267Rank1ReturnsMaxPoint` /
`testAjocc267Rank109ReturnsMinPoint` / `testAjocc267Rank110ReturnsNull` /
`testAjocc267IsGradeIndependent` / `testAjocc267NameAndDescriptionDoNotSuggestTestOrSimulation` /
`testJcx245RegressionUnaffectedByAjocc267Rename`）および `ResultParamCalcComponentTest` の
12テストは、いずれも本改修後も GREEN であることを確認した（重複するテストは新規追加していない）。

---

## 実装値の由来（転記ミス防止の措置）

`$TABLE_TCX267` の427個の配点値は、手入力ではなく
`ResultParamCalcComponent::__getAjoccPointMap()` の「`$mtDate >= $divDate2026` かつ非JCX」分岐から
**正規表現で機械抽出し、PHP スクリプトでリテラルを自動生成**して埋め込んだ。

抽出結果（design.md の記載と一致することを確認済み）:

| `started_over` | 要素数 | 1位配点 | 最終要素 | `defaultPoint` |
|---|---|---|---|---|
| 99 | 119 | 400 | 1 | 0 |
| 79 | 99 | 400 | 1 | 0 |
| 59 | 79 | 400 | 1 | 0 |
| 39 | 59 | 350 | 1 | 0 |
| 19 | 39 | 300 | 1 | 0 |
| 9 | 19 | 250 | 1 | 0 |
| 4 | 9 | 200 | 1 | 0 |
| 0 | 4 | 200 | 1 | 0 |

合計427要素。表中に値 `0` は存在しない（`isset` と `!empty` の差が顕在化しないことの確認）。

加えて、テスト項目9（等価性テスト）が2000ペア全てで System① と一致することを実行して確認済みの
ため、転記の正確性は二重に担保されている。

---

## 管理画面の選択肢表示について（タスク4.2）

`PointSeriesController::add()` / `edit()` は `PointCalculator::calculators()` を
`$pointCalculators` としてビューへ渡し、`PointSeries/add.ctp` / `edit.ctp` が
`$calcRules[$calc->val()] = $calc->name();` でループして選択肢を生成している。
ビュー側の変更が不要であることをコードで確認した。

選択肢に `TCX_267` が現れることは、テスト項目11（レジストリ検証、`val()`/`name()` の対応を
43アサーションで検証）がビューと同一のロジックを検証する形で担保している。

> **未実施**: ブラウザ上での目視確認は、管理画面へのログインを要するため本タスクでは実施して
> いない。`integration-test-checklist.md` の人手確認項目として残し、結合試験フェーズ（タスク5.3）で
> 実施する。
