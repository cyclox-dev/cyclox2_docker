# 調査ログ・設計判断: ajocc-point-267-prod

## Summary
- **Feature**: `ajocc-point-267-prod`
- **Discovery Scope**: Extension（既存システム `cyclox2web` の `ResultParamCalcComponent` /
  `PointCalculator` / `PointSimShell` を対象とした Light Discovery）
- **Key Findings**:
  - `feat/point-table-ajocc-267-sim`（`point-sim-2025-26` の成果）は **既に `origin/main` へ
    マージ済み**（PR #12, マージコミット `2c3fd3a`）。ローカルの `main` 参照は古いだけで、
    実際の `origin/main` には新得点表・シミュレーション専用フラグ・`PointSimShell` が
    既に存在する。
  - 本番未適用の原因は「未マージ」ではなく、**シミュレーション専用フラグ
    （`__simAjocc267`、既定 `false`）による条件分岐でガードされているため**。
  - 変更対象は3ファイルに閉じている（他ファイルからの参照なし）: `PointCalculator.php`,
    `ResultParamCalcComponent.php`, `PointSimShell.php`。
  - JCF/JCXシリーズの配点ルール（`point_series.calc_rule`）は大会日付による自動判定ではなく、
    シーズンごとに運用担当者が管理画面（`PointSeries/add.ctp` 等）で手動選択する既存の
    運用フローで決まる。したがって System②（シリーズ点）の「本番化」は、正式名称の
    計算器を選択肢として提供すること（命名整理）が主作業であり、日付分岐の追加は不要。

## Research Log

### 1. submodule ブランチのマージ状況（必須調査項目）
- **Context**: brief に「submodule cyclox2web の作業ブランチ
  `feat/point-table-ajocc-267-sim` に関連コードがある（main へのマージ状況は要確認）」と
  明記されており、設計前に必ず確認するよう指示されている。
- **手順**（読み取り専用 git コマンドのみ）:
  ```
  cd cyclox2_svr/cyclox2
  git fetch origin --quiet
  git log --oneline -1 main            # 33c3aed（ローカル参照、古い）
  git log --oneline -1 origin/main     # 2c3fd3a（最新）
  git merge-base --is-ancestor feat/point-table-ajocc-267-sim origin/main  # → true
  git log --oneline feat/point-table-ajocc-267-sim..origin/main
  # 2c3fd3a Merge pull request #12 from cyclox-dev/feat/point-table-ajocc-267-sim
  # e637f42 Merge pull request #11 from cyclox-dev:for256_cl2+3littleWin2rankup
  # 17dd696 CL2+3 でも少人数昇格およびそのフラグがつくように
  ```
- **Findings**:
  - `feat/point-table-ajocc-267-sim`（コミット `144e75b` 機能追加, `9787064` フラグガード
    追加）は `origin/main` の祖先であり、**PR #12 として完全にマージ済み**。
  - `origin/main` はさらに PR #11（無関係な CL2+3 昇格ロジック変更）を含む、`main` 上の
    最新状態。
  - ローカルにチェックアウトされていた `main` 参照（`33c3aed`）は `origin/main` の
    祖先であり、単に fetch 前の古い参照だった（作業に影響なし、読み取り専用調査のため
    ローカル `main` の更新は行っていない）。
  - `origin/main:app/Cyclox/Util/PointCalculator.php` および
    `app/Controller/Component/ResultParamCalcComponent.php` に `AJOCC_267_TEST` /
    `__simAjocc267` の実装が存在することを直接確認した。
- **Implications**: 本番化のための追加マージ作業は不要。実装ブランチは最新の `main`
  （＝ `origin/main`）から新規に作成し、既存の `AJOCC_267_TEST` 実装をそのまま土台として
  改修する。表データの再入力・再検証は不要（`point-sim-2025-26` で検証済みの値をそのまま
  正式化する）。

### 2. シミュレーション専用フラグの実装範囲
- **Context**: 本番化の対象範囲を正確に把握するため、フラグ導入コミット
  （`9787064 fix: AJOCC_267_TEST をシミュレーション専用フラグでガード`）の差分を確認した。
- **Findings**（`git diff 33c3aed 9787064 -- app/Controller/Component/ResultParamCalcComponent.php`）:
  - 追加されたのは次の4点のみ: private フィールド `$__simAjocc267`（既定 `false`）、
    `enableSimAjocc267()`、`disableSimAjocc267()`、`resetAjoccPtCache()`。
  - `__getAjoccPointMap()` 内の分岐条件が
    `if ($this->__simAjocc267 && $mtDate >= $divDate2025)` という形でフラグガードされている。
  - 既存の `$ajoccPtMap` / `$defaultPt`（キャッシュ用フィールド）自体は本フラグ追加前から
    存在する既存機構であり、本仕様のクリーンアップ対象ではない（Web経由の利用では
    リクエストごとに新規インスタンス化されるため、そもそもキャッシュ汚染は起きない）。
- **Implications**: クリーンアップで除去すべきは `__simAjocc267` フィールドと
  `enableSimAjocc267()` / `disableSimAjocc267()` のみ。`resetAjoccPtCache()` は
  `PointSimShell` 廃止後に呼び出し元が無くなるため、あわせて除去する
  （Design Synthesis: Simplification — 呼び出し元のない speculative API を残さない）。

### 3. System②（シリーズ点）の配点ルール決定経路
- **Context**: System①（AJOCCポイント）は大会開催日による自動分岐だが、System②
  （シリーズ点）も同様の自動分岐が必要か、あるいは既存の運用フローで足りるかを確認した。
- **Sources Consulted**: `app/Controller/PointSeriesController.php`
  （`add()` / `edit()` アクション）, `app/View/PointSeries/add.ctp`,
  `app/Model/PointSeries.php`（`calc_rule` バリデーション定義）。
- **Findings**:
  - `PointSeriesController::add()` / `edit()` は `PointCalculator::calculators()` を
    そのままビューへ渡し、`calc_rule` はフォームのプルダウンから運用担当者が選択する
    （大会日付やシーズンによる自動決定ロジックは存在しない）。
  - 過去の全シーズン（`JCX_245`, `TCX_245` 等）も同じ仕組みで、シーズンが切り替わる
    たびに運用担当者が新しい `PointSeries` レコードを作成し、該当する配点ルールを
    手動選択している。
- **Implications**: System②について本仕様が実装すべきことは「新得点表の計算器
  （`PointCalculator::$AJOCC_267`）を、シミュレーションであることを示さない正式名称・説明で
  選択肢に提供する」ことに限定される。日付による自動切替ロジックの追加は不要であり、
  範囲外（Out of Boundary）とする。

### 4. `PointSimShell` の依存関係と処遇
- **Context**: フラグ除去後、`PointSimShell.php` が未定義メソッド
  （`enableSimAjocc267()` 等）を呼び出し続けるとビルド・実行時エラーになるため、
  取り扱いを決定する必要があった。
- **Sources Consulted**: `grep -rln "PointSimShell|enableSimAjocc267|disableSimAjocc267|
  __simAjocc267|AJOCC_267_TEST" app/`
- **Findings**:
  - 上記識別子を参照するソースファイルは `PointCalculator.php` /
    `ResultParamCalcComponent.php` / `PointSimShell.php` の3ファイルのみ（他コントローラ・
    モデル・ビューからの参照なし）。
  - `PointSimShell` の役割（2025-26シーズンへ新表を適用した場合の what-if 比較）は
    `point-sim-2025-26` で完了済み・記録済み（`.kiro/specs/point-sim-2025-26/
    comparison-summary.md` 等）であり、本番化後は同シェルを維持する運用上の必要性がない。
- **Implications**: `PointSimShell.php` は本仕様のスコープで削除する
  （Design Decision 参照）。検証・回帰確認の役割は、本仕様で新規に追加する CakePHP
  ユニットテスト（`app/Test/Case/...`）に引き継ぐ。

### 5. 新得点表の適用開始日（2026-08-01）
- **Context**: brief にて「適用開始日の決定（2026-27シーズン開始日）は要件定義で確定する」
  と指示されている。
- **Sources Consulted**: `__getAjoccPointMap()` 内の既存の年度境界定数
  （`$divDate2017`, `$divDate2022`, `$divDate2024`, `$divDate2025`）、`app/Model/Season.php`
  （`start_date` フィールドを持つが、`__getAjoccPointMap()` はシーズンレコードを参照せず
  大会開催日のリテラル比較のみで年度境界を判定している）。
- **Findings**:
  - 直近3回のシーズン境界追加（2022, 2024, 2025）はいずれも `8月1日` を採用しており、
    `Season` テーブルを参照しないリテラル `DateTime` 比較という既存パターンが一貫している。
  - `point-sim-2025-26` で使われた `$divDate2025 = '2025-08-01'` はシミュレーション対象の
    2025-26シーズンの開始日であり、本番の2026-27シーズン開始日とは異なる
    （本番では再利用不可、流用すると2025-26シーズンにも新表が適用され回帰要件に違反する）。
- **Implications**: 本番の適用開始日は `2026-08-01`（新しい `$divDate2026` 定数）とし、
  既存パターンに倣ってリテラル比較で実装する。`Season` テーブルへの依存を新規追加しない
  （既存アーキテクチャとの一貫性を優先。Design Synthesis: Build vs. Adopt — 既存パターンの
  採用）。実装着手前に、運用中の `seasons` テーブルに実在する2026-27シーズン
  レコードの `start_date` が `2026-08-01` であることを人間が確認する
  （設計判断の前提確認、実装タスクの事前条件とする）。

### 6. 公式ポイント表PDFとの照合
- **Context**: brief の指示により、実装済みの新得点表の数値を公式PDF
  （`https://www.cyclocross.jp/2026/2026-2027ajoccpointtable.pdf`）と照合するタスクを
  `tasks.md` に含める。
- **Findings**: 本調査時点ではPDFの内容取得・自動照合は行っていない
  （`point-sim-2025-26` で2025-26シーズン向けの値は既に検証済みとの前提が brief に
  明記されているため、本仕様では実装時に人間確認込みで再照合するタスクとして計画する）。
- **Implications**: `tasks.md` に独立した検証タスクとして計上し、`test-results.md` へ
  照合結果を記録する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| A. リテラル日付分岐の恒久化（既存パターン踏襲） | `$divDate2026` を追加し、フラグ条件を外して無条件の日付分岐にする | 既存5世代分の年度境界実装と完全に同じパターン。レビュー・保守が容易 | 将来また新しい年度表が出た場合、同様の分岐追加が必要（既存と同じトレードオフ） | 採用 |
| B. `Season` テーブル参照による動的境界判定 | `season_id`/`Season.start_date` を引数に追加し、DBの値で判定 | 将来の境界変更がコード変更不要になる | 呼び出し元（Web結果保存、`OneTimeShell` 等）の引数追加が必要になり影響範囲が拡大。既存5世代の実装パターンと不整合 | 不採用（スコープ外の大規模変更になるため） |
| C. フラグを恒久的にtrueへ | `__simAjocc267` の既定値を `true` に変更するのみ | 変更差分が最小 | フラグ名・意味が「シミュレーション専用」のまま残り、命名整理（R4）を満たさない。将来の誤解を招く | 不採用 |

## Design Decisions

### Decision: 適用判定はリテラル日付分岐（`$divDate2026 = '2026-08-01'`）で恒久化する
- **Context**: 新得点表の本番適用条件をどう実装するか。
- **Alternatives Considered**:
  1. `Season` テーブル参照による動的判定（オプションB）
  2. シミュレーションフラグを恒久的に有効化（オプションC）
- **Selected Approach**: 既存の年度境界パターン（オプションA）を踏襲し、
  `$__simAjocc267 &&` の条件を除去したうえで `$divDate2026 = new DateTime('2026-08-01')` を
  無条件の分岐条件として追加する。
- **Rationale**: 既存コードの5世代の年度境界追加と完全に同じ実装パターンであり、
  レビュアー・将来の保守担当者にとって一貫性が高い。brief の「分岐・テーブルの配置は
  他年度テーブルと同様」という制約とも一致する。
- **Trade-offs**: 将来境界日が変わった場合はコード修正が必要（既存パターンと同じ制約であり
  許容する）。
- **Follow-up**: 実装前に `seasons` テーブルの2026-27シーズン `start_date` が
  `2026-08-01` であることを人間が確認する。

### Decision: `PointSimShell.php` を削除する
- **Context**: フラグ除去に伴い、`PointSimShell` の `enableSimAjocc267()` 等への依存が
  解消不能になる。
- **Alternatives Considered**:
  1. `PointSimShell` を汎用の回帰確認シェルとして書き換えて存続させる
  2. `PointSimShell` を削除し、役割をCakePHPユニットテストへ引き継ぐ
- **Selected Approach**: 削除する（オプション2）。
- **Rationale**: `PointSimShell` の目的（2025-26シーズンへの what-if 適用比較）は
  `point-sim-2025-26` で完了・記録済みであり、本番化後に再利用する運用上の必然性がない。
  検証観点（区分境界・JCX代表順位・回帰）は本仕様で追加する自動テストが正式にカバーする。
  他ファイルからの参照が無いため削除の副作用はない（本調査の4番参照）。
- **Trade-offs**: 将来別シーズンの新表を再度シミュレーションしたくなった場合、同種の
  シェルを新規に作る必要がある（許容する。UI化・汎用シミュレーション基盤化は明示的に
  スコープ外）。
- **Follow-up**: なし。

### Decision: System②（シリーズ点）は日付分岐を追加せず、命名整理のみ行う
- **Context**: System①と同様の自動判定をSystem②にも入れるべきか。
- **Selected Approach**: 入れない。`PointCalculator::$AJOCC_267`（旧 `$AJOCC_267_TEST`）を
  正式名称・説明文で提供し、`point_series.calc_rule` の選択は既存の運用フロー
  （管理画面での手動選択）に委ねる。
- **Rationale**: 本調査3番のとおり、全シーズンで配点ルールは運用担当者の手動選択で
  決定されており、自動化された前例がない。日付分岐を新設すると既存アーキテクチャに
  存在しないSystem②固有の自動判定ロジックを追加することになり、Design Synthesis の
  Simplification 原則（不要な抽象化を追加しない）に反する。
- **Trade-offs**: 2026-27シーズンのJCF/JCXシリーズ作成時、運用担当者が新得点表を選択し
  忘れるリスクが残る（運用手順書での注意喚起で軽減。コードでの強制は brief のスコープ外
  「ポイント表管理のUI化・DB化」に該当するため対象外とする）。
- **Follow-up**: 運用担当者向けに、2026-27シーズンのJCF/JCXシリーズ設定時は
  `AJOCC_267` を選択する旨を統合試験チェックリストに明記する。

## Risks & Mitigations
- 適用開始日リテラル（`2026-08-01`）と `seasons` テーブルの実際の2026-27シーズン
  `start_date` が食い違うと、意図しない大会が新旧どちらかの表で計算される —
  実装前に人間が `seasons` テーブルを確認するタスクをFoundationフェーズに設置して軽減。
- `PointSimShell` 削除により、将来別の年度改定が来た際の参考実装が失われる —
  本仕様のPRおよび `point-sim-2025-26` の設計書・実装差分が git 履歴に残るため、
  必要時は履歴を参照可能。
- 実装値と公式PDFの数値に差異が見つかった場合、実装修正が必要になり期限
  （2026-07-31）に影響しうる — 検証タスクをFoundation直後の早い段階に配置し、
  差異発覚時の手戻りを最小化する。
- System②の配点ルール選択が運用者の手動操作に依存するため、選び忘れリスクが残る —
  統合試験チェックリストに確認項目として明記する。

## References
- [AJOCC 2026-27シーズン規則改正](https://www.cyclocross.jp/news/2026/07/20262027amendment.html) — 規則改正の一次情報
- [2026-2027 AJOCCポイント表PDF](https://www.cyclocross.jp/2026/2026-2027ajoccpointtable.pdf) — 数値照合の正本
- `.kiro/specs/point-sim-2025-26/requirements.md` / `design.md` — 新得点表の検証済み実装・データの出所
- submodule `cyclox2_svr/cyclox2`, PR #12（`feat/point-table-ajocc-267-sim` → `main`）— マージ済みコード
