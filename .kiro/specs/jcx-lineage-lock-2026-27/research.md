# Research & Design Decisions: jcx-lineage-lock-2026-27

## Summary
- **Feature**: `jcx-lineage-lock-2026-27`
- **Discovery Scope**: Extension（既存システムへの統合型ディスカバリー / design-discovery-light 適用）
- **Key Findings**:
  - JCX戦の識別フラグ `meets.is_jcx` は実在し（大会登録画面のチェックボックス）、現在は
    ポイント計算（`ResultParamCalcComponent`）だけが参照している。エントリー経路では未使用
  - `entry_racers` への書込経路は6系統あり、モデル層のフックが存在しないため中央の関門がない。
    ただし全経路が `EntryRacer`/`EntryCategory` モデルの save 系メソッドを経由するため、
    モデルコールバック（beforeSave）が単一の関門として成立する
  - 既存の `CatLimitShell`（バッチ）に「シーズン初回エントリーで系統を確定」する先行パターンが
    あるが、JCX限定でない・非同期・独自シーズン指標のため、本機能には流用せず参考に留める

## Research Log

### JCX戦の識別方法
- **Context**: brief の「JCX 大会は大会属性（is_jcx 相当のフラグ）で識別できる」の実地確認
- **Sources Consulted**: `cyclox2_svr/cyclox2/app/Model/Meet.php`、`app/View/Meets/add.ctp:40`・
  `edit.ctp:36`（フォーム）、`app/Controller/Component/ResultParamCalcComponent.php:162-175, 2044-2182`、
  `app/Cyclox/Util/PointCalculator.php`、`doc/er_master/cyclox2ER.sql`
- **Findings**:
  - 実行時フラグは `meets.is_jcx`（tinyint(1)）。大会登録・編集画面のチェックボックス
    「JCX戦として登録する場合はチェック」で設定される
  - 唯一の実行時参照は `ResultParamCalcComponent`：`EntryCategory → EntryGroup → Meet` の
    アソシエーション経由で取得し、`calcAjoccPt(..., $isJcx)` / `__getAjoccPointMap()` の
    ポイント表選択分岐に使用
  - `MeetPointSeries` / `PointCalculator` / `PointSeriesSumUpRule` 側にJCXブールフラグはない
    （JCX「ポイント表」の数値IDがあるのみ）。checked-in の ERマスタ（`doc/er_master/cyclox2ER.sql`）
    には `is_jcx` 列が未反映（ドキュメントが古い）。`Meet.php` の `$validate` にも宣言なし
- **Implications**: `meets.is_jcx` を識別に流用する（新規識別手段は不要）。エントリー経路には
  現在JCX判定が一切ないため、チェックは全面的に新設となる

### エントリー書込経路の全数調査
- **Context**: チェックが全経路をカバーする必要がある（コンプライアンス上のクリティカル要件）
- **Sources Consulted**: `app/Controller/EntryRacersController.php`、`EntryCategoriesController.php`、
  `EntryGroupsController.php`、`ApiController.php`、`OrgUtilController.php`、
  `app/Model/EntryRacer.php`、`EntryCategory.php`（全文）、save/saveAll/saveMany の全文grep
- **Findings**（`entry_racers`/`entry_categories` への書込サイト全数）:
  1. 画面・個別: `EntryRacersController` `__addOnPage()`（:72）/ `__addOnApi()`（:92）/
     `edit()`（:114）— いずれも `EntryRacer->save()`
  2. 画面・カテゴリー: `EntryCategoriesController` `__addOnPage()`（:172）/ `__addOnApi()`（:193）/
     `edit()`（:526）— `EntryCategory->save()`。`edit` は種目（races_category_code）変更が可能で、
     所属選手全員の系統が一括で変わり得る
  3. リザルトファイル取込: `EntryCategoriesController::write_results()`（:235→:286）—
     既存 `entry_racers` を全削除（:292）後、`EntryRacer->saveMany(..., atomic=false, deep=true)`
     （:322）で再作成。レース実施後の結果反映が主用途
  4. 外部API一括: `ApiController::add_entry()`（:263）→ `execAddEntry()`（:303）— 同名
     EntryGroup を削除（:364、カスケードで entry_categories/entry_racers も削除）後、
     `EntryCategory->saveAssociated($cat)`（:396）でネストした EntryRacer ごと再作成。
     **削除→再作成フローのため、「同一大会の旧エントリー」を固定判定の根拠から除外しないと
     再アップロードが自分自身と衝突する**
  5. 選手統合: `OrgUtilController`（:1208）— `EntryRacer->saveAll()` で `racer_code` の
     付替えのみ（entry_category_id は不変）。系統切替の経路ではない
  6. `EntryGroupsController`（:68,89,111）— `entry_groups` のみで選手行に触れない
  - `EntryRacer`/`EntryCategory` に `beforeSave`/`beforeValidate` は存在しない（delete の
    カスケード用オーバーライドのみ）。CakePHP 2 の `save`/`saveMany`/`saveAssociated` は
    いずれもモデルコールバックを通る
- **Implications**: モデル層（`EntryRacer::beforeSave` + `EntryCategory::beforeSave`）に
  チェックを一元化すれば経路1〜4を単一実装で覆える。経路5は系統変更を伴わないため対象外
  （事後検出はシェルで担保）。経路6は選手行に無関係

### EntryCatLimit と CatLimitShell（先行パターン）
- **Context**: brief の「EntryCatLimit 等の仕組みでカテゴリー制限しているが時系列制約はない」の確認
- **Sources Consulted**: `app/Cyclox/Const/EntryCatLimit.php`（全文）、
  `app/Console/Command/CatLimitShell.php`、`app/Cyclox/Util/Util.php:180-193`、
  `app/Controller/PointSeriesController.php:379`、`ResultParamCalcComponent.php:1450`
- **Findings**:
  - `EntryCatLimit` は `$ELITE`（catGroupId=1, 'e'）/ `$MASTERS`（catGroupId=2, 'm'）/
    `$NONE`（-1, 'n'）の enum風クラス。参照元は `CatLimitShell` のみで、リアルタイム制御には
    未使用
  - `CatLimitShell::setupCatLimit()`（cron想定バッチ）は「シーズン（4/1〜3/31、独自の
    cxSeasonIndex）最初のエリート/マスターズエントリー」から選手の系統を判定し
    `racers.cat_limit`（1シーズン=1文字の文字列）へ永続化。**is_jcx でのフィルタは無い**
    （通常戦も根拠に含む旧ルール実装）。用途はポイントシリーズ集計時の資格フィルタのみ
  - 系統→レースカテゴリーの解決は `category_races_categories` → `categories.category_group_id`
    （1=Elite, 2=Masters）のjoinで行っている
- **Implications**: 本機能の判定（リアルタイム・JCX限定・seasons テーブル基準）とは要件が
  異なるため流用しない。ただし「レースカテゴリー→系統」の解決経路（join構造）と
  `EntryCatLimit` の系統表現は再利用できる。系統の最終判定は me-mm-linkage の
  `CategoryLineageMap` を単一の正とする（category_group_id 直書きはしない）

### 上流spec（me-mm-linkage-2026-27）の公開API
- **Context**: 系統判定を単一ソースとして共有する指示（roadmap「対応表の重複定義禁止」）
- **Sources Consulted**: `.kiro/specs/me-mm-linkage-2026-27/design.md`
- **Findings**:
  - `CategoryLineageMap`（`app/Cyclox/Const/`）: `isEliteCategory($code)` /
    `isMastersCategory($code)` / `eliteCategories()` / `mastersCategories()` /
    `isLineageManagedCategory($code)` / `pairedCategory($code)` を提供。
    管理対象は `C1`〜`C4`・`CM1`〜`CM3` のみ（女子系統等は対象外＝null）
  - 後続specは「公開APIにのみ依存してよい（内部実装への直接依存は不可）」と明記
  - Revalidation Trigger: 対応表定義・公開APIシグネチャの変更時は本specの再確認が必要
- **Implications**: 本specの系統判定は `CategoryLineageMap::isEliteCategory/isMastersCategory`
  （+ `eliteCategories()/mastersCategories()` の一覧取得）のみを用いる。実装Wave上、
  me-mm-linkage（Wave 1）の完了が本spec（Wave 2）の前提

### シーズンのスコープ
- **Context**: 「同一シーズン内」の判定基準の確定
- **Sources Consulted**: `app/Model/Season.php`、`app/Model/Meet.php`（`meets.season_id`）、
  `app/Cyclox/Util/Util.php`（cxSeasonIndex）
- **Findings**: 公式のシーズンは `seasons` テーブル（`start_date`/`end_date` 保持、
  `meets.season_id` が FK）。`cxSeasonIndex` は CatLimitShell 専用の独自指標（4/1固定・
  index 0 = 2015-16）で、seasons と乖離し得る
- **Implications**: 本機能は `meets.season_id` で「同一シーズン」を判定する。適用開始
  （2026-27以降）は対象シーズンの `start_date` と設定値の比較で判定する

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| A: モデル層フック一元化（採用） | `EntryRacer::beforeSave` / `EntryCategory::beforeSave` に判定を集約し、判定ロジックは Util クラスへ委譲 | 全save経路（save/saveMany/saveAssociated）を単一の関門でカバー。将来の新経路も自動的に対象。me-mm-linkage の一元バリデーションと同型 | 一括保存時に行単位で発火するため、事前一括判定（バルクプリチェック+リクエスト内キャッシュ）を併用しないとN+1になる | 採用。バルク経路はコントローラでプリチェックしキャッシュを温める |
| B: コントローラ個別実装 | 6書込サイトそれぞれにチェック呼出しを追加 | 各経路のUX（確認画面等）に自然に密着 | チェック漏れリスク（サイト追加時に忘れる）。同じ判定の重複実装 | 却下（関門はモデル層、UXのみコントローラ担当に分離） |
| C: DBトリガー/制約 | MySQL側で強制 | アプリ改修最小 | 系統判定がjoin+対応表参照でトリガーに不向き。警告+オーバーライドが表現不能。運用可視性が低い | 却下 |

## Design Decisions

### Decision: 固定系統は永続化せず都度算出する
- **Context**: 「シーズン初回JCXエントリーの系統で固定」の状態管理方法
- **Alternatives Considered**:
  1. 都度算出 — 判定時に当該シーズンの有効JCXエントリーを検索して最古を採る
  2. 永続化 — `racers` へのカラム追加や新テーブルで固定系統を保持（CatLimitShell 方式の拡張）
- **Selected Approach**: 都度算出。判定クエリは racer_code + season_id + is_jcx=1 +
  deleted=0 で絞り、開催日昇順の先頭を採る。リクエスト内でメモ化する
- **Rationale**: エントリー取消・外部APIの削除→再作成で状態が変わるため、永続値は陳腐化が
  避けられない（Requirement 2.4 / 4.2 を自然に満たす）。スキーマ変更も不要
- **Trade-offs**: 保存のたびに読み取りクエリが走る（indexed で軽量、バルクは一括判定で緩和）
- **Follow-up**: `entry_racers.racer_code` 起点の検索計画（EXPLAIN）を実装時に確認。
  必要な場合に限りインデックス追加を人間に提案する（本specの唯一のDDL候補）

### Decision: 制御強度は運用モード設定とし、デフォルトは案B（警告+管理者確認）を推奨
- **Context**: brief/指示で明示されたオープン決定点（ハードエラー vs 警告+オーバーライド）
- **Alternatives Considered**: requirements.md Requirement 5 冒頭の決定点ブロックに詳述
- **Selected Approach**: `warn`（警告+確認+記録）/ `block`（ハードエラー）を設定で切替可能に
  実装し、デフォルト値の確定は人間承認に委ねる（agreement-log「未決定事項」#1）
- **Rationale**: どちらに決まっても設計・実装をやり直さない。推奨（warn）の根拠は
  requirements.md 参照
- **Trade-offs**: モード分岐のテストケースが倍増する（両モードをTDDで担保）
- **Follow-up**: 人間承認後、デフォルト値を設定ファイルに確定して agreement-log を更新

### Decision: リザルトファイル取込は警告記録のみで非ブロック
- **Context**: `write_results` はレース実施後の結果反映が主用途で、削除→再作成を伴う
- **Selected Approach**: 取込前に一括判定し、違反はログ+取込結果画面への警告表示に留めて
  取込は完了させる（オーバーライド相当として記録）
- **Rationale**: 実走事実の記録を妨げると成績管理が破綻する。違反は Requirement 6 の
  検出シェルでも捕捉できる
- **Trade-offs**: この経路では違反データが残り得る（記録により追跡可能）
- **Follow-up**: 人間レビューで妥当性確認（agreement-log「未決定事項」#2）

### Decision: 判定不能時は fail-open（記録して通す）
- **Context**: 判定処理の内部エラー（対応表未初期化・データ不整合等）時の挙動
- **Selected Approach**: エラーログを記録し、チェックはスキップしてエントリー処理を継続する
- **Rationale**: brief制約「エントリー業務（繁忙期処理）を止めない」を優先。違反の取りこぼしは
  検出シェルで補完
- **Trade-offs**: チェック不能期間の違反は事後検出になる
- **Follow-up**: 人間レビューで妥当性確認（agreement-log「未決定事項」#3）

### Decision: レースカテゴリー→系統の解決規則
- **Context**: エントリーは `races_category_code`（種目）単位であり、系統は `categories` 側の概念
- **Selected Approach**: `category_races_categories` で当該種目に紐づくカテゴリーコード群を取得し、
  `CategoryLineageMap::isEliteCategory/isMastersCategory` で系統へ写像する。紐づくカテゴリーが
  片系統のみに解決される場合にその系統とし、対象外のみ・両系統混在・紐づけ無しの場合は
  「系統判定不能＝チェック対象外」（Requirement 2.5）とする
- **Rationale**: 対応表を単一の正とする指示に従い、`category_group_id` の直書き（CatLimitShell
  方式）を避ける。混在種目（もしあれば）を誤ってブロックしない安全側の倒し方
- **Trade-offs**: 対応表の管理対象外カテゴリー（女子等）はJCX固定の対象にならない
  （2026-27規則の対象がME/MM系統である前提と整合）
- **Follow-up**: 実データで両系統混在の種目が存在しないか実装時に確認しログで可視化

## Risks & Mitigations
- **上流依存**: `CategoryLineageMap` が未実装の期間は本specを実装開始できない —
  Wave 1（me-mm-linkage）完了後に着手する実装順序で吸収（roadmap どおり）
- **性能**: `entry_racers.racer_code` 起点の検索にインデックスが無い場合、繁忙期の一括登録で
  遅延 — 一括判定（IN句1クエリ）+リクエスト内メモ化で緩和し、EXPLAIN確認の上で必要なら
  インデックス追加を提案
- **ERドキュメント陳腐化**: `is_jcx` がERマスタ・Model定義に未反映 — 本specでは実DBを正とし、
  フィクスチャに `is_jcx` を含めてテストで実在を担保
- **外部API互換性**: オーバーライド指定パラメータの追加は外部エントリー管理ツール側の追随が
  必要 — 未指定時は「拒否+違反一覧応答」でフェイルセーフに倒し、応答仕様を結合試験
  チェックリストに記載
- **運用モードの未確定**: デフォルト値が人間未承認 — 両モードをTDDで実装し、確定後は設定値
  1行の変更で済む構造にする

## References
- `.kiro/specs/jcx-lineage-lock-2026-27/brief.md` — ディスカバリー成果（問題・スコープ・制約）
- `.kiro/steering/roadmap.md` — プロジェクト全体方針・spec分割・依存関係
- `.kiro/specs/me-mm-linkage-2026-27/design.md` — 上流spec。CategoryLineageMap /
  CategoryLineageLinker の公開API定義と依存ルール
- AJOCC 2026-27規則改正告知: https://www.cyclocross.jp/news/2026/07/20262027amendment.html
- 調査対象コード: `cyclox2_svr/cyclox2/app/`（本文中の各ファイル:行 参照）
