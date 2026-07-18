# 実装計画: ajocc-point-267-prod

タスクID: `ajocc-point-267-prod`
作成日: 2026-07-14

対象リポジトリ: submodule `cyclox2_svr/cyclox2`（CakePHP 2.x）。実装ブランチは
`git fetch origin` 後の `origin/main`（PR #12 マージ済み）から作成すること（research.md 参照）。

- [ ] 1. Foundation: 前提確認・PDF照合・テスト基盤確認
- [ ] 1.1 実装ブランチ作成と適用開始日の前提確認
  - `cyclox2web` の `origin/main` を最新化し、そこから作業ブランチ（例: `feat/ajocc-267-prod`）
    を作成する。
  - `seasons` テーブルの2026-27シーズンレコードの `start_date` が `2026-08-01` であることを
    確認する（design.md の `$divDate2026` 前提。値が異なる場合は後続タスクの日付定数を
    実際の値に合わせて修正する）。
  - 観測可能な完了状態: 作業ブランチが `origin/main` を起点に作成されており、
    `seasons.start_date`（2026-27シーズン）の確認結果（日付・確認方法）が記録されている。
  - _Requirements: 4.1_

- [ ] 1.2 公式ポイント表PDFとの数値照合
  - 公式PDF（`https://www.cyclocross.jp/2026/2026-2027ajoccpointtable.pdf`）を取得し、
    既存実装済みの新8区分表（非JCX）・新JCX列（`app/Cyclox/Util/PointCalculator.php` の
    `$TABLE_AJOCC267TEST`、`app/Controller/Component/ResultParamCalcComponent.php` の
    `__getAjoccPointMap()` 内の新表定義）のすべての値を突き合わせる。
  - 差異が見つかった場合は、区分・順位・実装値・公式値を記録し、後続のCoreタスク（2.x, 3.x）
    着手前にテーブル定義の修正方針を確定する。差異の修正自体は独立タスクを起こさず、
    2.1（PointCalculator の GREEN 手順）・3.1（ResultParamCalcComponent の GREEN 手順）の
    実装に織り込む（テーブル値もリネームと同じコミットで揃える）。
  - 観測可能な完了状態: 照合結果（対象範囲・差異有無・確認日）が記録され、差異があれば
    修正方針（2.1/3.1への織り込み内容）が明記されている。差異が無ければ「差異なし」と
    明記する。
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 1.3 テスト実行基盤の動作確認
  - `docker-compose exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test"` 等で
    CakePHP 2.x 組込みテストランナーが実行可能であることを確認する（`app/Test/Case/` 配下は
    現状 `empty` プレースホルダのみで実テストが無いため、本タスクで実行環境そのものの疎通を
    確認する）。後続タスク（2.1, 3.1, 3.2, 5.1）で追加する単体テストが実行できる状態に
    することが目的の前提整備タスクである。
  - 観測可能な完了状態: テストランナーの実行コマンドと、エラーなく起動・終了することを
    示す実行結果（0件成功などの出力）が記録されている。
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 2. Core: PointCalculator（System②）の命名整理
- [ ] 2.1 (P) AJOCC_267 計算器の命名整理と単体テスト
  - RED: `app/Test/Case/Cyclox/Util/PointCalculatorTest.php` を新規作成し、
    `PointCalculator::getCalculator(13)` の順位1位=1000点／109位=1点／110位=`null`、
    グレード1/2で同一結果（グレード非依存）、`name()`/`description()` に
    `TEST`／テスト／シミュレーションという文言が含まれないこと、を検証するテストを書き、
    現状の `_TEST` 命名のままテストが失敗する（RED）ことを確認する。
  - GREEN: `app/Cyclox/Util/PointCalculator.php` 内の `$AJOCC_267_TEST` →
    `$AJOCC_267`、`$TABLE_AJOCC267TEST` → `$TABLE_AJOCC267`、
    `__calcAJOCC267Test()` → `__calcAJOCC267()`、`RUN_PT_AJOCC267TEST` →
    `RUN_PT_AJOCC267` にリネームし、コンストラクタの `name`/`description` 文字列を
    本番用（シミュレーション・テストを示唆しない）表現へ更新する。`val=13` は変更しない。
  - `calc()` メソッドの `switch` 文の `case` 条件をリネーム後の識別子に追随させる。
  - 既存の配点ルール（例: `calc_rule=11` の `JCX_245`）の計算結果が本改修前と変わらないことも
    同テストファイル内で確認する（Requirement 3.3 の回帰）。
  - 観測可能な完了状態: `Console/cake test Cyclox/Util/PointCalculatorTest` が全件成功
    （GREEN）し、`PointCalculator.php` 内に `AJOCC_267_TEST` 等の `_TEST` を含む識別子・
    文言が存在しない（grep で確認可能）。
  - _Requirements: 3.1, 3.2, 3.3, 4.2, 5.5_
  - _Boundary: PointCalculator_

- [ ] 3. Core: ResultParamCalcComponent（System①）のシーズン起点恒久適用
- [ ] 3.1 (P) 新得点表の恒久適用ロジックへの置き換えと単体テスト
  - RED: `app/Test/Case/Controller/Component/ResultParamCalcComponentTest.php` を新規作成し、
    以下を検証するテストを先に書き、現状（シミュレーション専用フラグ既定 `false`）では
    失敗する（RED）ことを確認する。
    - 大会開催日 `2026-08-01` 以降・非JCXで、出走人数区分境界
      （4/5, 9/10, 19/20, 39/40, 59/60, 79/80, 99/100人）ごとの正しいポイント、および
      各区分の表範囲外（最終順位より下位）でポイント0が返ること（Requirement 1.4）。
    - 大会開催日 `2026-08-01` 以降・JCXで、順位1位=1000点／109位=1点／110位=0点
      （Requirement 1.4）。
    - 大会開催日境界（`2026-07-31` は旧表、`2026-08-01` は新表）で正しく切り替わること。
    - フラグを一切呼び出さない素の `ResultParamCalcComponent` インスタンスでも
      `2026-08-01` 以降は新表が適用されること（恒久適用の確認）。
    - 出走人数が0人以下の場合にエラー値（`-1`）を返す既存の異常系挙動が、大会開催日に
      関わらず変わらないこと（Requirement 1.5）。
  - GREEN: `app/Controller/Component/ResultParamCalcComponent.php` の
    `__getAjoccPointMap()` 内の `if ($this->__simAjocc267 && $mtDate >= $divDate2025)` を、
    新規定数 `$divDate2026 = new DateTime('2026-08-01')` を用いた
    `if ($mtDate >= $divDate2026)`（フラグ非依存の無条件分岐）へ置き換える。
    `2026-08-01` より前の既存 `if/else if` チェーン（`$divDate2017`, `$divDate2022`,
    `$divDate2024` を用いた分岐）には変更を加えない。
  - 同一コミット内で `private $__simAjocc267 = false;` フィールド、
    `enableSimAjocc267()`、`disableSimAjocc267()` メソッドを削除する
    （`PointSimShell.php` からの参照は task 4.1 で解消するまで一時的に壊れた状態になる
    ことを許容する）。
  - 観測可能な完了状態: `Console/cake test Controller/Component/ResultParamCalcComponentTest`
    のうち本タスクで追加した境界・JCX・恒久適用のテストが全件成功（GREEN）し、
    `ResultParamCalcComponent.php` 内に `__simAjocc267` が存在しない。
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 4.1, 5.1, 5.2, 5.3_
  - _Boundary: ResultParamCalcComponent_

- [ ] 3.2 過去シーズン回帰テスト（2025-26以前の非影響）
  - 3.1 で作成した `ResultParamCalcComponentTest.php` に、2025-26以前の代表的な大会日付
    （例: `2025-11-01`, `2024-11-01`）・出走人数・順位・JCX有無の組み合わせについて、
    本改修前と同一のポイントを返すことを検証するテストを追加する。期待値は
    `point-sim-2025-26` の `PointSimShell::testTables()` に記載された回帰値
    （例: 非JCX started=50 rank1 → 180、JCX rank1 → 200、2025-08-01以降でも
    フラグ無効時は従来表のまま）を引き継ぐ。
  - テストを実行し、3.1 の変更後も本タスクで追加したテストが全件成功することを確認する
    （2025-26以前の経路に変更が無いことのコード上の証跡とする）。
  - 観測可能な完了状態: 2025-26以前を対象とした回帰テストが `ResultParamCalcComponentTest`
    内に追加され、全件成功する。
  - _Depends: 3.1_
  - _Requirements: 2.1, 2.2, 2.3, 5.4_
  - _Boundary: ResultParamCalcComponent_

- [ ] 4. Integration: シミュレーション専用実行手段の削除と整合確認
- [ ] 4.1 PointSimShell.php の削除
  - `app/Console/Command/PointSimShell.php` を削除する（`enableSimAjocc267()` 等、3.1で
    削除したメソッドへの参照が唯一の使用元であり、他ファイルからの参照が無いことを
    research.md の調査で確認済み）。
  - 削除前に改めて `grep -rln "PointSimShell" app/` を実行し、他ファイルからの参照が
    無いことを最終確認する。
  - 観測可能な完了状態: `app/Console/Command/PointSimShell.php` が存在せず、
    `grep -rln "PointSimShell" app/` の結果が空であることを確認できる。
  - _Depends: 2.1, 3.1_
  - _Requirements: 4.3, 4.4_

- [ ] 4.2 命名・フラグ整理の全体整合確認
  - `grep -rn "simAjocc267\|AJOCC_267_TEST\|TABLE_AJOCC267TEST\|calcAJOCC267Test" app/` を
    実行し、削除・リネーム対象の識別子が `app/` 配下に一切残っていないことを確認する。
  - `app/tmp/logs/debug.log` 等の生成物以外のソースファイルに旧識別子が残っていないことを
    目視で最終確認する。
  - 観測可能な完了状態: 上記 grep の結果が0件（またはソースコード外の生成物のみ）であり、
    確認結果が記録されている。
  - _Depends: 4.1_
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 5. Validation: 全体テスト実行と結合試験の記録
- [ ] 5.1 単体テスト全件実行と結果記録
  - `docker-compose exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake test
    Cyclox/Util/PointCalculatorTest"` および
    `Console/cake test Controller/Component/ResultParamCalcComponentTest` を実行し、
    全テストが成功することを確認する。
  - 実行結果（テスト項目・期待結果・実際結果・合否、実行コマンド・環境）を
    `.kiro/specs/ajocc-point-267-prod/test-results.md` に記録する。
  - 観測可能な完了状態: `test-results.md` に全テストのPASS結果と実行ログ（または要約）が
    記録されている。
  - _Depends: 4.2_
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 5.2 結合試験チェックリストの作成
  - 以下を含む手動確認項目を `.kiro/specs/ajocc-point-267-prod/integration-test-checklist.md`
    に記載する（テンプレート: `docs/sdd/templates/integration-test-checklist.md`）。
    - 開発環境で2025-26シーズンの既存カテゴリーを再計算し `ajocc_pt` が変化しないことの
      目視確認。
    - `PointSeries/add.ctp` の配点ルール選択肢に「AJOCC_267」がテスト文言なしで表示される
      ことの確認。
    - 2026-27シーズンのJCF/JCXシリーズ作成時に運用担当者が `AJOCC_267` を選択する必要が
      ある旨の運用上の注意点。
    - 既存のAJOCCランキングCSV・シリーズランキングCSV出力（`download_ajocc_pt_csv` /
      `PointSeriesController::calcUpSeries` 経由のダウンロード）の操作方法・出力形式が
      本改修前と変わらないことの確認（Requirement 4.4）。
    - 成績閲覧アプリ（`cyclox2ressys_svr`）でのランキング表示に崩れがないことの確認。
  - 観測可能な完了状態: `integration-test-checklist.md` に確認項目一覧（未チェック状態）と
    確認日・確認者の記入欄が存在する。
  - _Depends: 5.1_
  - _Requirements: 3.1, 3.3, 4.4_
