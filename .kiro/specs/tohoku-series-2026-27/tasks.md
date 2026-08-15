# 実装計画: tohoku-series-2026-27

タスクID: `tohoku-series-2026-27`
作成日: 2026-08-15

前提: TDD（テスト先行）。実装ブランチは `feat/tohoku-series-2026-27`
（`release/2026-27-season-rules` から分岐）。対象は submodule `cyclox2_svr/cyclox2`。

---

- [ ] 1. 準備: ブランチ作成と前提確認

- [ ] 1.1 実装ブランチを作成し、前提の採番・数値を確認する
  - submodule `cyclox2_svr/cyclox2` で `git fetch origin` を実行し、
    **`origin/release/2026-27-season-rules`（`0635466`）** から `feat/tohoku-series-2026-27` を
    作成する。ローカルの同名ブランチ（`2c3fd3a` = `origin/main` 相当）は古いので使用しない
  - 分岐後、`PointCalculator` に `val=13` が **`AJOCC_267`**（`AJOCC_267_TEST` ではない）として
    存在し、`val=14` が未使用であることを確認する。`AJOCC_267_TEST` が見えた場合は起点ブランチを
    誤っているので分岐からやり直す
  - `app/Test/Case/Cyclox/Util/PointCalculatorTest.php` と
    `app/Test/Case/Controller/Component/ResultParamCalcComponentTest.php` が存在することを確認する
    （267prod が追加済み。無ければ起点ブランチが誤っている）
  - `ResultParamCalcComponent::__getAjoccPointMap()` の `$mtDate >= $divDate2026` 非JCX分岐から
    8区分の配点列を抽出し、design.md の要素数表（119/99/79/59/39/19/9/4、1位配点
    400/400/400/350/300/250/200/200）と一致することを確認する
  - 完了条件: ブランチが作成され、採番と8区分の数値が design.md の記載どおりであることを確認できている
  - _Requirements: 4.3, 6.1_

- [ ] 2. RED: `TCX_267` の単体テストを先行実装する

- [ ] 2.1 `PointCalculatorTest` に `TCX_267` の基本テストを追加する
  - 各テストの冒頭で `$calc = PointCalculator::getCalculator(14); $this->assertNotNull($calc, ...);`
    を行う（既存 `testAjocc267Rank1ReturnsMaxPoint` と同じパターン）。未実装時に
    `getCalculator(14)` は `null` を返すため、これを省くと `Call to a member function name() on null`
    の Fatal でスイート全体が中断し、RED が「失敗」ではなく「中断」になる
  - `getCalculator(14)` が計算器を返し `name()` が `'TCX_267'` であること
  - `description()` に「東北」が含まれること、`text()` に「JCX」「ボーナス」「グレード」が
    含まれること（description と text で要求する文言を分けて書く）
  - `text()` が全8区分の見出し（`100人以上`〜`1人以上`）を含むこと
  - 返却値に `bonus` キーが含まれないこと
  - グレード 1 / 2 / null で結果が同一であること
  - `rank` が空の場合に `calc()` が `null` を返すこと
  - 完了条件: 追加したテストが未実装により失敗する（RED）ことを実行して確認する。Fatal による
    中断ではなく assertion failure として失敗していることを確認する
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 2.5, 2.6, 3.1_

- [ ] 2.2 区分境界・順位境界のテストを追加する
  - 出走人数境界: 4/5、9/10、19/20、39/40、59/60、79/80、99/100 で適用区分が切り替わること
  - 順位境界: 各区分の1位・最終要素の順位（値は `1`）・その次の順位
  - **範囲外の期待値は `calc()` が `null` を返すこと**（`array('point' => 0)` ではない）。
    `calc()` 末尾の `if (empty($pt['point']) && empty($pt['bonus'])) return null;` による。
    既存 `testAjocc267Rank110ReturnsNull` と同じ期待値の立て方にする
  - 完了条件: 追加したテストが RED であることを実行して確認する
  - _Requirements: 2.1, 2.3, 3.2, 3.3, 3.4_

- [ ] 2.3 `ResultParamCalcComponent` との等価性テストを追加する
  - 出走人数 1, 4, 5, 9, 10, 19, 20, 39, 40, 59, 60, 79, 80, 99, 100, 150 × 順位 1〜125 を総当たり
  - 期待値は `ResultParamCalcComponent::calcAjoccPt($rank, $startedCount, '2026-09-01', false)`
    から取得し、`TCX_267` の `point` と一致することを検証する
  - `PointCalculatorTest` から利用するため
    `App::uses('ResultParamCalcComponent', 'Controller/Component')` と
    `App::uses('ComponentCollection', 'Controller')` を追加し、
    `new ResultParamCalcComponent(new ComponentCollection())` で生成する
    （`calcAjoccPt` は public。既存 `ResultParamCalcComponentTest` と同じ生成方法）
  - **出走人数ごとに新規インスタンスを生成する（16インスタンス）。順位ループは同一インスタンス
    内で回す。** `calcAjoccPt()` は `$this->ajoccPtMap` に初回の表を永続キャッシュし、
    起点ブランチではキャッシュ破棄メソッド `resetAjoccPtCache()` が 267prod により削除済みの
    ため、インスタンス分離以外に回避手段がない。1インスタンスで回すと初回（出走1人＝4件表）の
    表が全ペアに適用され、テストが全滅する
  - **戻り値を正規化して比較する**: `calc()` はポイント0を `null` で返すのに対し
    `calcAjoccPt()` は `0` を返すため、`$actual = ($pt === null) ? 0 : $pt['point'];` とする
  - 出走人数 0 以下は `calcAjoccPt` が `-1`（エラー値）を返す仕様のため、等価性テストの対象外とする
  - 期待値ソースは参照のみ。`ResultParamCalcComponent` には変更を加えない
  - 完了条件: 追加したテストが RED であることを実行して確認する
  - _Requirements: 2.2, 2.4, 4.4_

- [ ] 3. GREEN: `TCX_267` を実装する

- [ ] 3.1 `PointCalculator` に `TCX_267` を追加する
  - `public static $TCX_267;` と `private static $TABLE_TCX267;` を宣言する
  - `init()` 内に8区分の `$TABLE_TCX267` を定義する（`__KEY_STARTED_OVER` = 99/79/59/39/19/9/4/0）。
    配点値は `ResultParamCalcComponent` の該当分岐から機械的に転記する
  - `$text` は **`KNT_178` のループ書式**（`if (($j + 1) % 10 == 0 || $j == $n - 1)`）で生成する。
    `TCX_245` の書式（`% 10 == 0` のみ）だと、8区分の要素数がいずれも10の倍数でないため区分末尾で
    改行されず、次区分の `---` が同一行に連結して表示が崩れる
  - `new PointCalculator(14, 'TCX_267', '2026-27 東北クロスのポイントテーブル。26-27 AJOCC ポイントと同じ（JCX テーブル無し）。', $text)`
    を生成して `calculators` 配列へ追加する
  - `calc()` に `case self::$TCX_267->val(): ... __calcTCX267(...)` を追加する
  - `__calcTCX267()` を `__calcTCX245()` と同一ロジック（`rank` 空→`null`、既定 `$point = 0`、
    区分ヒット時に `break`）で実装する
  - 完了条件: タスク2で追加した全テストが GREEN になる
  - _Requirements: 1.1, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3_
  - _Depends: 2.1, 2.2, 2.3_

- [ ] 4. 回帰確認と全体テスト

- [ ] 4.1 既存計算器の非回帰を確認し、不足分のテストを追加してスイート全体を実行する
  - **既存テストと重複させない**。起点ブランチの `PointCalculatorTest` には既に
    `testAjocc267Rank1ReturnsMaxPoint` / `testAjocc267Rank109ReturnsMinPoint` /
    `testAjocc267Rank110ReturnsNull` / `testAjocc267IsGradeIndependent` /
    `testAjocc267NameAndDescriptionDoNotSuggestTestOrSimulation` /
    `testJcx245RegressionUnaffectedByAjocc267Rename` が存在する。同名メソッドの追加は Fatal に
    なるため、これらは「引き続き GREEN であること」の確認に留める
  - 新規に追加するのは以下2点のみ:
    - `TCX_245`（`val=12`）の回帰（既存テストがカバーしているのは `JCX_245`=`val=11` であり、
      `TCX_245` の回帰は未カバー）
    - `calculators()` の要素数が 14 で、`val=1`〜`13` の `val` / `name` が不変であること
  - `PointCalculatorTest` および `ResultParamCalcComponentTest` を実行し、既存テストが全て通ること
  - 結果を `.kiro/specs/tohoku-series-2026-27/test-results.md` に記録する
  - 完了条件: 追加・既存テストが全て GREEN で、test-results.md に実行コマンドと結果が記録されている
  - _Requirements: 4.1, 4.2, 4.3, 4.5_
  - _Depends: 3.1_

- [ ] 4.2 管理画面での表示を確認する
  - `PointSeries/add`・`PointSeries/edit` の配点ルール選択肢に `TCX_267` が表示されることを
    ローカル環境（Docker）で確認する
  - 選択肢の生成が `PointCalculator::calculators()` 由来であり、ビュー側の変更が不要であることを
    確認する
  - 完了条件: 選択肢に `TCX_267` が出ることを画面で確認し、結果を記録している
  - _Requirements: 1.6_
  - _Depends: 3.1_

- [ ] 5. ドキュメントとリリース準備

- [ ] 5.1 シリーズ登録 runbook を作成する (P)
  - `.kiro/specs/tohoku-series-2026-27/runbook.md` を新規作成する
  - `point_series` の設定値（`calc_rule=14` / `sum_up_rule=2` / `point_term_rule=1` /
    `point_to=1` / `season_id=17` / `point_series_group_id=2`）を明記する
  - 命名規則（`東北シクロクロス26-27{カテゴリー}` / `TCX26-27{カテゴリー}`）を明記する
  - シリーズ本数・カテゴリー構成は主催者判断で決まるため固定せず、25-26 実績（12本:
    ME1/WE1/MM1/CK1/CK2/CK3 + ME2/ME3/ME4/WE2/MM2/MM3）を参考情報として併記する
  - `publishes_on_ressys` / `publishes_newest_asap` の 25-26 実績（上位6本=1、他=0）を併記する
  - シリーズ登録後に `meet_point_series` で大会・エントリーカテゴリーを紐付ける必要がある旨、
    およびその前提として 2026-27 の大会（`meets`）登録が必要である旨を記載する
    （開発環境DBでは `season_id=17` の `meets` は0件）
  - `meet_point_series` の必須項目（`express_in_series`（NOT NULL、25-26 実績は `#1亘理` 形式）、
    `meet_code`、`entry_category_name`）を明記する
  - **作業順序の制約**を明記する: 紐付けはリザルト登録前（開幕前）に完了させる。既にリザルトが
    ある大会へ後から紐付けた場合、`reCalcResults`（対象エントリーカテゴリーのリザルト再計算）を
    実行しないと `point_series_racers` が生成されず、シリーズランキングが空のままになる
    （`PointCalculator` は `__resetSeriesPoints()` からのみ呼ばれ、`calcUpSeries` は
    既存の `point_series_racers` を集計するだけであるため）
  - 本番DBに `calc_rule=13`（`AJOCC_267`）を使う既存 `point_series` 行が無いことの確認手順を含める
  - `public_psrset_group_id` は公開処理が自動採番するため通常は手入力不要である旨を補足する
  - 記載値が開発環境DB調査に基づくものであり、実施時に本番環境で確認するよう注意喚起する
  - 完了条件: runbook.md が Requirement 5 の全受け入れ基準を満たす形で存在する
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9_
  - _Boundary: docs only_

- [ ] 5.2 結合試験チェックリストを作成する (P)
  - `.kiro/specs/tohoku-series-2026-27/integration-test-checklist.md` を新規作成する
  - `TCX_267` を選択したシリーズでの集計完走・ランキング妥当性、シリーズランキングCSV出力、
    res-sys 側のシリーズランキング表示の各確認項目を記載する
  - `ajocc-point-267-prod` の未消化17項目と合わせて先行リリース前に実施する旨を明記する
  - 完了条件: チェックリストが作成され、267prod 分との合同実施方針が記載されている
  - _Requirements: 6.3_
  - _Boundary: docs only_

- [ ] 5.3 結合試験を実施し、結果を記録する
  - 親リポジトリの submodule を **リリース対象コミット**（`origin/release/2026-27-season-rules`
    + 本仕様のマージ結果）へチェックアウトしてから実施する。親リポジトリ `main` の submodule
    ポインタは `feat/jcx-lineage-lock-2026-27` の未マージコミット（`2479bcd`）を指しているため、
    そのままではリリース対象でないビルドを検証してしまう
  - 本仕様の `integration-test-checklist.md` の全項目を実施する
  - `ajocc-point-267-prod` の `integration-test-checklist.md` の未消化17項目を実施する
  - 両チェックリストにチェックと確認者・確認日を記入し、本仕様の `test-results.md` に総括を追記する
  - 完了条件: 両チェックリストが全項目チェック済みで、確認者・確認日が埋まっている
  - _Requirements: 6.3, 6.4_
  - _Depends: 4.1, 4.2, 5.2_

- [ ] 5.4 PR を作成しリリース手順を申し送る
  - submodule 側で `feat/tohoku-series-2026-27` → `release/2026-27-season-rules` の PR を作成する
  - 親リポジトリ側で spec 一式をコミットし PR を作成する
  - 先行リリース（`release/2026-27-season-rules` → `main`）は **`--no-ff`** で行うこと、
    実施は結合試験完了後に人間が判断することを PR 本文に明記する
  - ロールバック時の注意（`calc_rule=14` の `point_series` 行が残ったまま `main` へ戻すと
    シリーズ詳細画面が Fatal error になるため、先に該当行を削除する）を PR 本文に明記する
  - 親リポジトリの submodule ポインタを先行リリースに合わせるかは人間判断である旨を申し送る
  - 完了条件: 両リポジトリの PR が作成され、リリース条件・マージ方式・ロールバック手順が
    明記されている
  - _Requirements: 6.1, 6.2, 6.5, 6.6_
  - _Depends: 5.3_

---

## 実行順序

```
1.1 → 2.1 → 2.2 → 2.3 → 3.1 → 4.1 / 4.2 → 5.3 → 5.4
                                 5.1 (P) / 5.2 (P) ↗
```

## スコープ外（実装しない）

- `point_series` / `meet_point_series` の実登録（リリース後に運用担当者が runbook に従って実施）
- `ResultParamCalcComponent`（System①）の変更
- 得点表の共通定数化リファクタリング（4 spec 完了後の候補として design.md に申し送り済み）
