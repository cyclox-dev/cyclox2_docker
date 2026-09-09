# Research & Design Decisions

## Summary
- **Feature**: `entry-auto-category-2026-27`
- **Discovery Scope**: Extension（既存システムへの機能追加。light discovery実施）
- **Key Findings**:
  - `EntryRacer`モデルの保存フックは、管理画面（個別登録・編集）・API（個別・一括登録）・
    リザルト取込によるエントリー再作成のすべての経路が必ず通過する単一のフックである
    （jcx-lineage-lock-2026-27が同じ場所で系統固定チェックを実装済み・実績あり）。
  - `categories.age_min`列が既にC1〜C4・CM1〜CM4すべてに正しい値（19/17/15/13, 35）を
    持っている。既存の`__isProperAgeForCat()`（`ResultParamCalcComponent`）は独自のハード
    コード配列（C1/C2/C3/CL1のみ）を使っており、マスターズ（35歳）はどこにもチェックが
    無い。本機能はDBの`age_min`列をそのまま参照すればよく、新たな年齢定義表は不要。
  - me-mm-linkage-2026-27が確立した「警告蓄積プロパティ＋afterSave検知＋3経路（画面Flash・
    API応答フィールド・サーバログ）への配信」というパターンが`CategoryRacer`モデルに
    既に実装済みであり、本機能はこのパターンをそのまま踏襲できる。

## Research Log

### 種目→カテゴリー解決（プール種目の判定）
- **Context**: Requirement 4（プール種目の対象外化）を機械的に判定する方法の確認。
- **Sources Consulted**: `app/Model/CategoryRacesCategory.php`、`.kiro/steering/db-category-entry-glossary.md`。
- **Findings**: `category_races_categories`テーブル（`CategoryRacesCategory`モデル）が
  `races_category_code`↔`categories.code`の多対多対応表。`races_category_code`ごとに
  紐づく`category_code`の件数を数えれば、単一対応（例: `C4`→`C4`の1件）かプール
  （例: `C3+4`→`C3`,`C4`の2件）かを機械的に判定できる。
- **Implications**: 新規の判定テーブル・設定は不要。既存テーブルへの問い合わせのみで
  Requirement 1.1（単一対応の判定）とRequirement 4.1（プール種目の除外）を実現できる。

### 管理画面側のエントリー登録経路
- **Context**: 判断ブリーフの調査では外部API一括登録（`ApiController::execAddEntry()`）のみ
  確認済みだったため、管理画面側の個別登録・編集経路を追加確認した。
- **Sources Consulted**: `app/Controller/EntryRacersController.php`。
- **Findings**: `EntryRacersController::add()`は`_isApiCall()`により`__addOnPage()`
  （管理画面）と`__addOnApi()`（個別API）に分岐するが、いずれも最終的に
  `$this->EntryRacer->save($this->request->data)`を呼ぶ。`edit()`も同様。
  jcx-lineage-lock-2026-27の警告配信パターン（`__setJcxLockWarningViewVars()` /
  `__errorWithJcxLockDetail()`）が既にこのコントローラに実装されており、本機能の警告配信も
  同じ場所に追加できる。
- **Implications**: `EntryRacer`モデルの保存フックに処理を集約すれば、管理画面個別登録・
  管理画面編集・個別API・一括API（`ApiController::execAddEntry()`経由の`saveAssociated()`
  カスケード）・リザルト取込再作成のすべてを1箇所でカバーできる（Requirement 5.1充足）。

### 年齢資格チェックの既存実装
- **Context**: Requirement 3（資格年齢要件の保護）の実現方法の確認。
- **Sources Consulted**: `app/Controller/Component/ResultParamCalcComponent.php`
  （`__isProperAgeForCat()`）、`categories`テーブルの`age_min`列。
- **Findings**: 既存の`__isProperAgeForCat()`は昇格時のみに使われるプライベートメソッドで、
  対象カテゴリーをハードコードした配列（C1=19, C2=17, C3=15, CL1=17）に限定している。
  マスターズ側（CM1〜CM4=35）は対象外であり、既存コードのどこにもマスターズ資格年齢の
  チェックが存在しない。一方`categories.age_min`列はC1〜C4・CM1〜CM4すべてに正しい値を
  持つ（DB確認済み）。
- **Implications**: 本機能の年齢ガードは`categories.age_min`列を直接参照する（build vs
  adopt: 既存のハードコード配列を再利用・拡張するのではなく、DBの列を単一の情報源として
  採用する）。年齢計算自体は既存の`Util::uciCXAgeAt()`をそのまま流用する。

### 警告蓄積・配信パターン
- **Context**: Requirement 6（処理継続性・見送り時の通知）の実現方法の確認。
- **Sources Consulted**: `app/Model/CategoryRacer.php`（`afterSave()`,
  `getLineageWarnings()`, `resetLineageWarnings()`）、
  `app/Controller/CategoryRacersController.php`（`__buildLineageWarningMessage()`）、
  `app/Controller/ApiController.php`（`__summarizeLineageWarnings()`）。
- **Findings**: me-mm-linkage-2026-27が「保存後の検知処理は例外を握りつぶしてログのみに
  留め、保存自体を失敗させない」「蓄積した警告を画面Flash・API応答フィールド・サーバログの
  3経路へ配信する」というパターンを`CategoryRacer`モデル・`CategoryRacersController`・
  `ApiController`に既に確立している。
- **Implications**: 本機能は同一パターンを`EntryRacer`モデル・`EntryRacersController`・
  `ApiController::execAddEntry()`に適用する（generalization: 既存パターンを新しいモデルへ
  展開する形で再利用し、新しい設計パターンを発明しない）。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| `EntryRacer::afterSave()`に補完ロジックを追加（採用） | 保存成功後のフックとして、対応ペア補完を副作用的に実行 | 全経路を1箇所でカバー済み。保存の成否に影響しない設計にしやすい | フックが肥大化しないよう既存のJCXチェック（`beforeSave`）と責務を分離する必要がある | `CategoryRacer::afterSave()`と同型のパターン |
| エントリー登録の各コントローラ個別に補完ロジックを追加 | 各コントローラのアクションから直接呼び出す | フックの暗黙的な副作用を避けられる | 経路が増えるたびに呼び出し漏れのリスクがある（Requirement 5.1と相性が悪い） | 不採用 |
| `CategoryLineageLinker::propagateLinkedPromotion()`を流用・拡張 | 既存の連動保存メソッドをそのまま使う | 実装量が最小 | 既存カテゴリーのcancelを前提としており、エントリー時の「補完のみ・cancelしない」要件（Requirement 1.3, 1.4）と矛盾する | 不採用。新規メソッドとして分離 |

## Design Decisions

### Decision: 補完ロジックの実行位置は`EntryRacer::afterSave()`
- **Context**: Requirement 5.1（全経路への同一基準適用）をどの層で保証するか。
- **Alternatives Considered**:
  1. 各コントローラのアクションから個別に呼び出す
  2. `EntryRacer`モデルの保存フック（`afterSave()`）に集約
- **Selected Approach**: モデルの`afterSave()`に集約する。
- **Rationale**: CakePHPの規約上、`save()`/`saveMany()`/`saveAssociated()`のいずれの経路も
  モデルの保存フックを必ず通過する。jcx-lineage-lock-2026-27が同じ場所で系統固定チェックを
  実装し実績があるほか、`CategoryRacer::afterSave()`が同型の「保存後検知・警告蓄積」パターンを
  既に確立している。
- **Trade-offs**: モデル層の責務がやや増えるが、コントローラごとの呼び出し漏れリスクを構造的に
  排除できる利点の方が大きい。
- **Follow-up**: `EntryRacer::beforeSave()`（JCX系統固定チェック）と`afterSave()`（本機能）の
  責務分離をコードコメントで明示する。

### Decision: 対応ペア補完は既存の`propagateLinkedPromotion()`と別メソッドとする
- **Context**: エントリー時の補完は「相手系統に何も無い場合のみ新規付与し、既存カテゴリーは
  一切cancelしない」という、昇格連動（`propagateLinkedPromotion()`）とは異なる意味論を持つ
  （Requirement 1.3, 1.4）。
- **Alternatives Considered**:
  1. `propagateLinkedPromotion()`にフラグを追加してcancel有無を切り替える
  2. 新規メソッドとして分離する
- **Selected Approach**: 新規メソッド（`CategoryLineageLinker`に追加）として分離する。
- **Rationale**: cancelの有無はメソッドの意味論そのものを変える分岐であり、フラグ化すると
  呼び出し元の意図が読み取りにくくなる（design-principles.mdの「明確な境界」原則）。
  既存の`resolveLinkedTarget()`・`__findActiveCategoryRacerOnSide()`は意味論を変えずに
  そのまま再利用できる。
- **Trade-offs**: `CategoryLineageLinker`にメソッドが1つ増えるが、既存メソッドの契約
  （design.mdで既に承認済みの`propagateLinkedPromotion()`の振る舞い）を変更するリスクを
  避けられる。

### Decision: 年齢ガードは`categories.age_min`列を単一の情報源とする
- **Context**: Requirement 3の実現方法。
- **Alternatives Considered**:
  1. 既存の`__isProperAgeForCat()`のハードコード配列にCM1〜CM4を追加する
  2. `categories.age_min`列を直接参照する
- **Selected Approach**: `categories.age_min`列を参照する。
- **Rationale**: 列は既にC1〜C4・CM1〜CM4すべてに正しい値を持っており、ハードコード配列を
  拡張するより単一の情報源（DB）を参照する方が二重管理を避けられる（simplification）。
- **Trade-offs**: 既存の`__isProperAgeForCat()`とは参照元が異なる状態が一時的に残るが、
  既存メソッドの改修は本specのスコープ外（昇格ロジック自体は変更しない）。

## Risks & Mitigations
- 既存の`EntryRacer::beforeSave()`（JCX系統固定チェック）と新規`afterSave()`の実行順序・
  責務が曖昧になるリスク — コードコメントで両者の役割（beforeSave=登録可否のゲート、
  afterSave=登録後の補完）を明記して緩和する。
- `category_races_categories`の多対多解決を毎エントリー保存時に問い合わせるコストが積み重なる
  リスク — 1エントリー保存あたり1クエリ程度であり、既存の`asCategory()`等と同等の負荷であるため
  許容範囲と判断。

## References
- 判断ブリーフ: https://claude.ai/code/artifact/1f6a3a64-e59d-4a67-ae43-837b96e544c4
- `.kiro/steering/db-category-entry-glossary.md`
- `.kiro/specs/me-mm-linkage-2026-27/design.md`（`CategoryLineageMap`/`CategoryLineageLinker`/`CategoryRacer::afterSave()`の既存契約）
- `.kiro/specs/jcx-lineage-lock-2026-27/design.md`（`EntryRacer::beforeSave()`フックの既存パターン）
