# Research & Design Decisions: catracer-cleanup-2026-27

## Summary
- **Feature**: `catracer-cleanup-2026-27`
- **Discovery Scope**: Extension（既存 CakePHP 2.x アプリへの是正バッチ追加。light discovery 実施）
- **Key Findings**:
  - 上流 spec（me-mm-linkage-2026-27）が `CategoryLineageMap`（Const）と `CategoryLineageLinker`
    （Util）を新設し、後続 spec は公開 API にのみ依存してよいと契約している。本 spec の判定は
    すべてこの API 参照で成立し、対応表の重複定義は不要
  - 「系統」判定の材料は (a) `racer_results.as_category`（出走時の成績対象カテゴリー、
    カテゴリーコード）、(b) `entry_categories.races_category_code` →
    `category_races_categories` → `categories` の対応。(a) が第一材料として最も直接的
  - 既存バッチの先例: `OneTimeShell::execCategoryDown1718()` が「TRANSACTION + logonly
    （rollback for test）+ cancel→create + CSV風ログ」のパターンを持ち、本設計の雛形になる
  - rider-demotion-2025-26 runbook の更新パターン（UPDATE cancel_date + INSERT reason_id/
    reason_note、物理削除なし、カテゴリー単位検証）を踏襲する

## Research Log

### 系統（Elite / Masters）はどこから判定できるか
- **Context**: 是正基準「直近の出走実態」の実装方法を確定するため
- **Sources Consulted**:
  - `app/Model/EntryCategory.php`（`races_category_code` 必須、belongsTo `RacesCategory`）
  - `app/Model/RacerResult.php`（`as_category` が `Category` へ belongsTo）
  - `app/Controller/Component/ResultParamCalcComponent.php:1658-`（`asCategory()`:
    出走時に「どのカテゴリーの選手として出走したか」を返す既存ロジック）
  - `OneTimeShell::setupAsCategory()`（過去データへの `as_category` 一括設定バッチが既に実施済み）
  - ローカルダンプ `category_races_categories`（C1↔C1/UCIME/UCIME+U、C3↔C3/C3+4、
    CM1↔CM1/CM1+2+3、CM2↔CM2/CM2+3/CM1+2+3 等の対応を実データで確認）
- **Findings**:
  - `racer_results.as_category` はカテゴリーコード（C1〜C4 / CM1〜CM3 等）を直接保持しており、
    `CategoryLineageMap::isEliteCategory()/isMastersCategory()` にそのまま渡せる
  - `as_category` が空の古いデータでは、`entry_categories.races_category_code` から
    `category_races_categories` を介して対応 `categories.code` 群を引き、その系統が単一なら
    系統確定できる（混走 `CM1+2+3` 等もすべて Masters 側に閉じている）
  - `racer_results.status`: 0=DNS（出走せず）。出走実績は `status <> 0` で判定
    （rider-demotion-2025-26 runbook の判定と同一）
  - 「lineage」相当の専用カラムは存在しない。系統は上記の組合せで導出する
- **Implications**: 系統判定は「as_category 優先、フォールバックで races_category_code 経由」
  の2段階とし、判定ロジックは DB 非依存の純粋関数に切り出す（フォールバック用の対応データは
  呼び出し側が渡す）

### 既存バッチパターン（OneTimeShell）の精査
- **Context**: 是正バッチの実行制御（トランザクション・logonly・レポート）の既存作法確認
- **Sources Consulted**: `app/Console/Command/OneTimeShell.php`
  - `execCategoryDown1718()`（L449-661）: 第3引数 `logonly` で `$commits=false` →
    処理は全実行し最後に `rollback`。`TransactionManager->begin()/commit()/rollback()`。
    cancel_date 設定（UPDATE）→ 新カテゴリー行 create+save（INSERT、
    `CategoryReason::$SEASON_DOWN->ID()` + reason_note）。1行1選手の CSV 風ログを
    `$this->log(..., LOG_DEBUG)` に出力し、末尾にカテゴリー別集計を出す
  - `setupDuplicatedCatRacerDeleted()`（L128-210）: 完全重複行（racer/category/apply_date が
    同一）の SoftDelete。**本 spec の対象外**（重複保有の検出時はこちらを案内）
- **Findings**: logonly・TRANSACTION・cancel→create・件数レポートのすべてに社内前例があり、
  同じ流儀で実装すれば運用者の学習コストが低い
- **Implications**: 新設シェルは `execCategoryDown1718` の実行制御パターンを踏襲する。
  ただし「1回だけの処理」用の OneTimeShell には追加せず、繰り返し実行を前提とする専用シェル
  （`CatRacerCleanupShell`）を新設する

### rider-demotion-2025-26 資産（runbook / SQL）の精査
- **Context**: category_racers 更新の作法・検証フローの踏襲元
- **Sources Consulted**: `.kiro/specs/rider-demotion-2025-26/runbook.md`、`sql/`
  （01_build_demote_set.sql / 02_gen_koukaku.sh / 03_verify.sql）
- **Findings**:
  - 更新パターン: 旧所属行に `cancel_date` を UPDATE、降格先を `reason_id=4` +
    `reason_note='2025-26シーズン成績の降格処理による'` + `apply_date=翌日` で INSERT。
    物理削除なし
  - 検証: カテゴリー単位 TRANSACTION 内で INSERT 件数を期待値と照合してから COMMIT。
    最終検証 SQL（件数・二重残存ゼロ・旧カテゴリー残存ゼロ）を独立に持つ
  - 落とし穴: 年齢別カテゴリー自動付与（reason_id=1、未来日 apply_date）が「有効保有」集計の
    ノイズになる → `apply_date <= 基準日` で除外が必要
  - WM は categories 上 Masters グループ（category_group_id=2）に分類されているが、
    me-mm-linkage-2026-27 の対応表対象外（`isLineageManagedCategory()` が false を返す）。
    系統判定・違法判定とも Map の管理対象判定を使えばこの罠を踏まない
- **Implications**: 是正の cancel_date / apply_date / reason_note の運用は demotion 踏襲。
  有効保有の判定条件に `apply_date <= 実行日` を必ず含める。カテゴリー集合の対象判定は
  必ず `CategoryLineageMap` の API を使う（コード接頭辞の自前判定をしない）

### 上流 spec（me-mm-linkage-2026-27）の公開契約確認
- **Context**: 本 spec が依存してよい API の確定
- **Sources Consulted**: `.kiro/specs/me-mm-linkage-2026-27/design.md`
- **Findings**:
  - `CategoryLineageMap`（Const）: `pairedCategory(code): ?string`（CM1→C2 が既定。C1→CM1 は
    一方向）、`isEliteCategory()` / `isMastersCategory()` / `eliteCategories()` /
    `mastersCategories()` / `isLineageManagedCategory()`
  - `CategoryLineageLinker`（Util）: `isValidActiveSet(racerCode, prospectiveActiveCodes)`、
    `isFormerElite1()`、`validateActiveSet(racerCode)` ほか。判定系メソッドは DB を変更しない
  - 「後続spec は本specが定義する公開APIにのみ依存してよい（内部実装への直接依存は不可）」
    「大量一括処理での本バリデーションの性能は catracer-cleanup-2026-27 側の設計で個別に検討」
    と明記
  - CategoryRacer モデルに保存時バリデーション（checkLineagePair / checkNoDuplicateCategory）が
    追加される。是正バッチの INSERT もこのバリデーションを通過する（`validate => false` 禁止）
- **Implications**: 是正の適用順序を「反対系統の終了 → 対応カテゴリー付与」に固定すれば、
  付与時点の prospective set は必ず合法になり、モデルバリデーションが安全網として機能する

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| OneTimeShell にメソッド追加 | 既存の1回きりバッチ置き場に追加 | ファイル追加なし | 「1回だけの処理」という契約に反する（本バッチは任意タイミング反復実行）。テスト前例なし・巨大化 | 却下 |
| 専用シェル + 純粋判定 Util（採用） | `CatRacerCleanupShell`（実行制御・DB）と `CatRacerCleanupJudge`（純粋判定）を新設 | brief の Boundary Candidates（検出/是正分離・判定/DB分離）に合致。TDD 容易 | ファイル3枚新設 | me-mm-linkage の層構造（Const→Util→Model→Console）を踏襲 |
| SQL スクリプト方式（rider-demotion 流） | 検出 SQL + 生成 SQL + 手動適用 | 実績あり | 「任意タイミング・冪等・logonly」の要件（バッチ化合意 2026-07-14）に合わない。単体テスト不可 | 検証フロー思想のみ踏襲 |

## Design Decisions

### Decision: 判定ロジックを DB 非依存の純粋クラスに分離する
- **Context**: brief の Boundary Candidates「判定ロジック（純粋関数）と DB 更新の分離
  （テスト容易性）」
- **Alternatives Considered**:
  1. シェル内 private メソッドに判定を書く — テストがフィクスチャ依存になり重い
  2. 判定専用 Util クラス（採用）
- **Selected Approach**: `CatRacerCleanupJudge`（Cyclox/Util）。入力は「有効保有一覧」
  「直近出走履歴（整形済み配列）」のみで、出力は是正決定（`CatRacerCleanupDecision`）。
  DB アクセスは行わない（元ME1判定等が必要な範囲は `CategoryLineageLinker` に委譲）
- **Rationale**: エッジケース（Requirement 3）の全分岐をフィクスチャなしの純粋単体テストで
  網羅できる
- **Trade-offs**: シェル側にデータ取得・整形の責務が残る（統合テストでカバー）
- **Follow-up**: Judge へ渡す出走履歴配列の形（キー名）を実装初期に固定しテストで契約化する

### Decision: 是正時の新規付与で C1（ME1）を付与対象としない
- **Context**: 対応表上 CM1 の対応先は既定 C2（C1 は元ME1のみの一方向対応）。是正バッチが
  元ME1判定に基づき C1 を自動付与すべきか
- **Alternatives Considered**:
  1. `isFormerElite1()` が true なら C1 を付与する
  2. 付与は常に `pairedCategory()` の既定値（CM1→C2）とし、C1 は付与しない（採用）
- **Selected Approach**: 案2。C1 は選手が正系統として現に保有している場合のみ維持される
- **Rationale**: 元ME1でも現在の実力が ME1 相当とは限らない。誤って最上位を自動付与する
  リスク > 手動での個別対応コスト。ME1 特例の運用は me-mm-linkage の change_em（対応ペア補完・
  特例対応）が担う
- **Trade-offs**: 元ME1 の MM1 保持者は是正後 C2+CM1 となり、必要なら手動で C1 へ
- **Follow-up**: 該当し得る選手（元ME1かつ是正対象）をレポートの注記に出すことを検討（設計では
  reason_note と明細で追跡可能とした）

### Decision: 日付運用は「cancel_date=実行日の前日、付与 apply_date=実行日」
- **Context**: 任意タイミング実行のため、demotion のようなシーズン末固定日は使えない
- **Alternatives Considered**:
  1. cancel_date=実行日、apply_date=実行日 — 既存の有効判定（`cancel_date >= atDate` を有効と
    みなす箇所）で同日重複が生じる
  2. cancel_date=実行日の前日、apply_date=実行日（採用）
- **Selected Approach**: 案2。同日時点で「旧保有は終了済み・新保有は有効」が一意に定まる
- **Rationale**: `ResultParamCalcComponent::asCategory()` 等の既存有効判定
  （`cancel_date >= atDate` を有効扱い）と整合し、実行日当日のレース処理と競合しない
- **Trade-offs**: 実行日前日に当該カテゴリーで出走していた場合、その日の保有解釈が変わるが、
  違法保有側の話であり実害なし（レース結果側の as_category は不変）
- **Follow-up**: logonly レポートで日付を明示し、運用者が確認できるようにする

### Decision: 付与理由は CategoryReason::$BY_RULE（ID 7）+ 定型 reason_note
- **Context**: 是正 INSERT 行の reason_id / reason_note の選定
- **Alternatives Considered**: `$OTHER_CHANGE`（10）、`$BY_RULE`（7）
- **Selected Approach**: `$BY_RULE`（7、「ルール変更に伴う付与」＝カテゴリー決定ルールの変更に
  ともなうカテゴリー付与）。reason_note は
  `2026-27対応ペア是正バッチによる（正系統=<code> 根拠=<meet>/<date>）` の定型とする
- **Rationale**: 本是正は AJOCC 2026-27 ルール改正（対応ペア両保有モデル導入）を起因とする付与
  であり語義が一致。定型 note により事後の SQL 検証（demotion 流の件数照合）が可能
- **Trade-offs**: なし
- **Follow-up**: note の書式は tasks の実装時にテストで固定する

### Decision: 冪等性は「状態収束」で担保する（実行済みマーカーを持たない）
- **Context**: Requirement 5.2（再実行で変更なし）
- **Selected Approach**: 是正後の選手は違法状態でなくなるため検出に掛からず、再実行は自然に
  no-op となる。実行済みフラグ・マーカーテーブル等は導入しない
- **Rationale**: 検出条件（現在の有効保有集合の違法性）自体が収束条件であり、追加の状態管理は
  不整合の温床になる
- **Trade-offs**: 「同じ選手が再び違法になった場合」は再度是正対象になるが、これは意図した挙動
  （任意タイミング反復実行の目的そのもの）
- **Follow-up**: 統合テストで「cleanup 2回目実行 → 変更0件」を検証する

## Risks & Mitigations
- me-mm-linkage-2026-27 の実装（Map/Linker/モデルバリデーション）未完了だと本バッチが動かない —
  roadmap の Wave 制御どおり実装 Wave 2 で着手し、依存 API はテストでも契約どおりに使う
- モデルバリデーション（checkLineagePair）が1保存ごとに有効集合を DB 参照するため、大量是正時に
  性能低下の可能性 — 対象は違法保有選手のみ（数百〜千件想定）で1選手あたり数保存。件数を検出
  フェーズで先に把握でき、logonly で実測できる。チャンク実行（offset/limit 引数）も設ける
- `as_category` 未設定の古い結果データで系統フォールバック判定が必要 — races_category_code →
  categories 対応（category_races_categories）で判定。判定不能は手動確認対象へ落とす（安全側）
- 未来日 apply_date の行（年齢別自動付与等）による有効保有の誤集計 — 有効判定に
  `apply_date <= 実行日` を含める（runbook の既知の落とし穴）
- 本番適用時のデータ差分（ローカルダンプとの乖離） — バッチは実行時点のデータで判定するため
  再検出から実行される。本番でもまず detect / logonly を実行してから確定する手順を runbook 化

## References
- `.kiro/specs/me-mm-linkage-2026-27/design.md` — 依存する公開 API 契約（単一の対応表）
- `.kiro/specs/rider-demotion-2025-26/runbook.md` — category_racers 更新パターン・検証フロー
- `cyclox2_svr/cyclox2/app/Console/Command/OneTimeShell.php` — logonly/TRANSACTION の既存作法
- `cyclox2_svr/cyclox2/app/Controller/Component/ResultParamCalcComponent.php` — asCategory() 既存実装
- `.kiro/steering/roadmap.md` — Shared seams（対応表の単一ソース、是正結果がバリデーションを通ること）
