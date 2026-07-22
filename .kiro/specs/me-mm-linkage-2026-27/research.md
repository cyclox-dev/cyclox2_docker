# Research & Design Decisions Template

## Summary
- **Feature**: `me-mm-linkage-2026-27`
- **Discovery Scope**: Extension（既存 CakePHP 2.x アプリ cyclox2web への機能拡張。新規サブシステムの
  追加ではなく、既存のカテゴリー認定処理・バリデーション層への介入）
- **Key Findings**:
  - `CategoryRacer` モデルには保存経路を横断する検証フックが一切ない。保存呼び出し（`save`/`saveAll`/
    `saveMany`）は `app/Controller/CategoryRacersController.php`・`app/Controller/OrgUtilController.php`・
    `app/Controller/ApiController.php`・`app/Controller/Component/AgedCategoryComponent.php`・
    `app/Controller/Component/ResultParamCalcComponent.php`・`app/Console/Command/OneTimeShell.php` の
    計13箇所（+ `EntryCategoriesController` 経由の間接経路を含め brief記載の14経路相当）に分散しており、
    いずれも `array('validate' => false)` を渡していないため、モデルの `$validate` に追加したカスタム
    ルールは既定で全経路に自動適用される（＝Model層への一元化で13/14経路を一括カバーできる）。
  - `app/Controller/CategoryRacersController.php::__check_category_to()` の対応マップは
    `CM1=>C2, CM2=>C3, CM3=>C4, C1=>CM1, C2=>CM2, C3=>CM3, C4=>CM3` であり、新ルール
    （C2⇔CM1, C3⇔CM2, C4⇔CM3, C1⇔CM1条件付）と food C2/C3 の対応が異なる。旧マップのまま残すと
    誤ったペアへ誘導するため、単一定義（新設 Const）への置換が必須。
  - `exec_change_em()` は `check_change_em()` が事前計算した `end_cats`（切替先が Elite なら
    Masters系統の**有効カテゴリー全部**、逆も同様）を無条件に `cancel_date` 設定して保存し、その後
    新カテゴリーを1件 `create()+save()` するのみ。対応ペアの正当な保有を機械的に破壊する設計。
  - `ResultParamCalcComponent::__execApplyRankUp()`（エリート系昇格の汎用適用）と
    `__applyRankUp2CM()`（CM1/CM2への昇格適用）が、レース結果に基づくリアルタイム昇格の実処理点。
    両者とも「新カテゴリー行の作成」「HoldPoint 3pt 付与（`category_code` = 昇格先）」を行うが、
    互いに独立しており、相手系統への連動処理は存在しない。両関数とも最終的に `CategoryRacer->save()`
    を呼ぶため、ここに連動ロジックを追加すればモデル層の一元バリデーションを自然に通過する。
  - `CategoryRacer` モデルの `$validate` は現在 `racer_code`/`category_code`/`apply_date`/
    `reason_id` の必須・形式チェックのみで、重複や対応外ペアの検証は皆無（brief記載どおり）。
  - `Racer.cat_limit` は `varchar(255)` で、`CatLimitShell::setupCatLimit()` がシーズンごとに1文字
    （`e`/`m`/`n`、`app/Cyclox/Const/EntryCatLimit.php` で定義）を該当シーズンのインデックス位置に
    書き込む「エントリー制限」表示用フィールド。実際の参照は `app/View/Racers/{view,edit,add}.ctp`
    のみで、エントリー可否を実コードでゲートしている箇所は見つからなかった（表示用途のみ、
    brief記載の「表示用途のみだが要対処」と符合）。`setupCatLimit()` はシーズン内の**最初の**
    EntryRacer 出走からのみ e/m を決定しており、両系統に出走した選手でも片方しか記録されない。
    カラムは `varchar(255)` のためスキーマ変更なしで新しい文字値（両系統: `b`）を追加できる。
  - `PointSeriesController`/`ResultParamCalcComponent` に登場する「`cat_limit`」文字列は
    `PointSeries.hint` の `cat_limit:C1/C2` という別概念（ポイント集計対象カテゴリー絞り込み
    ヒント）であり、`Racer.cat_limit` とは無関係。混同しないよう設計から除外。
  - `OrgUtilController::uniteRacer()` は統合元選手の `CategoryRacer` 行を `saveAll()` で
    `racer_code` のみ書き換えて統合先へ付け替える。重複・対応外ペアの検知は一切ない
    （brief記載どおり）。この `saveAll()` も `CategoryRacer` モデルの `$validate` を経由するため、
    一元バリデーションで自動的に保護されるが、複数行を一括保存する経路のため、行ごとの逐次検証で
    十分か（集合としての整合性）を設計で確認する必要がある。
  - `categories` テーブルの実データ（本番ダンプ確認）: 女子系統は `CL1`〜`CL3`（Ladies、
    `category_group_id=3`、rankベースの実力別）と `WM`（WomenMasters、`category_group_id=2`、
    `is_aged_category=1` で35歳以上の**単一区分**の年齢別カテゴリー）のみ。男子系統のような
    複数段階の実力別マスターズ（MM1〜MM3相当）は女子には存在しないため、ME⇔MM対応表の対象外と
    確定できる（要件フェーズの未決事項を解消）。
  - `app/Cyclox/Const/*` に既存の enum 風 Const クラスパターン（`EntryCatLimit` 等、
    static `init()` + private constructor + 検索メソッド）があり、新設する対応表 Const
    クラスはこのパターンに揃える。
  - テスト基盤: `app/Test/Case/{Controller,Model}/` はディレクトリのみ存在し（`empty` プレース
    ホルダファイルのみ）、本機能が対象とするクラス群の既存テストは無い。CakePHP 2.x 標準の
    `CakeTestCase`（`lib/Cake/TestSuite/`、PHPUnit ベース）を新規に導入する形になる。

## Research Log

### ME⇔MM対応表と各コンポーネントの整合性
- **Context**: brief記載の「両保有モデルとの適合性検証済み」を実装ファイルで裏付け、連動ロジックの
  挿入点を具体化する必要があった。
- **Sources Consulted**: `app/Controller/Component/ResultParamCalcComponent.php`（2343行）、
  `app/Controller/CategoryRacersController.php`、`app/Model/CategoryRacer.php`、
  `app/Console/Command/CatLimitShell.php`、`app/Cyclox/Const/CategoryReason.php`、
  `app/Cyclox/Const/EntryCatLimit.php`、`doc/er_master/cyclox2ER.sql`、本番DBダンプ
  （`cyclox2_mysql/var/dump/20260613_dump.sql`）の `categories` INSERT 文。
- **Findings**: 上記 Key Findings を参照。
- **Implications**: 対応表は新設 Const クラス（`CategoryLineageMap`）に一元化し、バリデーションは
  `CategoryRacer` モデルの `$validate` カスタムルールに集約する。連動処理は
  `ResultParamCalcComponent` の2つの昇格適用関数の末尾にフック追加する形が最小改修になる。

### 女子系統の対応表対象範囲
- **Context**: brief/roadmapで「女子系統(WE/WM)の対応要否は要件定義で確認」と明記されていた未決事項。
- **Sources Consulted**: 本番DBダンプの `categories` テーブル実データ。
- **Findings**: 女子は `CL1`〜`CL3`（実力別・複数段階）と `WM`（年齢別・単一区分）のみで、
  男子の C1-C4/CM1-CM3 に相当する「実力別×2系統×複数段階」の構造を持たない。
- **Implications**: 対応表・連動・対応外ペアバリデーションの対象を男子系統
  （C1〜C4, CM1〜CM3）のみに限定する。requirements.md Requirement 9 として明記済み。

### `Racer.cat_limit` の実際の用途範囲
- **Context**: brief記載の「CatLimitShellは表示用途のみだが要改修」を裏付け、改修範囲を
  過大/過小評価しないための確認。
- **Sources Consulted**: `app/View/Racers/{view,edit,add}.ctp`、`app/Controller/PointSeriesController.php`、
  `app/Controller/Component/ResultParamCalcComponent.php` 内の `cat_limit` 全参照箇所。
- **Findings**: `Racer.cat_limit` を実際に読んでエントリー可否をゲートしているコードは無く、
  参照は選手詳細・編集画面の表示/入力フォームのみ。`PointSeriesController` 等の「cat_limit」は
  無関係な別概念（PointSeries.hint の絞り込み条件）。
- **Implications**: 本機能でのCatLimitShell改修は表示用データの正確性確保が目的であり、
  エントリー制御ロジックの変更は不要（jcx-lineage-lock-2026-27 側の責務）。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Model層一元バリデーション（採用） | `CategoryRacer::$validate` にカスタムルールを追加し、保存経路を横断して一元的に検証する | 既存13/14経路を個別修正せずカバー、Rails/Cake流の「モデルが自身の整合性を守る」原則に合致、テスト容易性が高い | 一括保存（`saveAll`/`saveMany`）時は行ごとの検証になるため、複数行にまたがる整合性（例: 統合後の集合）は呼び出し側での事前/事後チェックも必要 | 既存モデルにvalidateカスタムルールを追加するパターンは他モデルにも存在せずCakePHP標準機能の範囲内 |
| Controller層個別チェック（却下） | 14箇所それぞれの保存前に個別チェックコードを追加 | 各経路の文脈に応じた細かい制御が可能 | 改修箇所が多く漏れのリスクが高い（brief記載の不整合発生原因そのもの）、期限内完了リスクが高い | Simplification原則（design-synthesis.md）に反する |
| DBレベル制約（CHECK制約/トリガー）（却下） | MySQLのトリガー等で対応外ペアを拒否 | アプリ層のバイパスを防げる | MySQL 5.7はCHECK制約が実質無効、トリガーはCakePHPのバリデーションエラーメッセージ機構と統合できずUXが悪化、DBスキーマ変更は「原則なし」の制約に反する | 却下 |

## Design Decisions

### Decision: ME⇔MM対応表を単一のConstクラスとして新設する
- **Context**: Requirement 1（対応表の単一定義）。既存 `CategoryRacersController::__check_category_to()`
  の対応マップが新ルールと異なり、そのまま流用できない。
- **Alternatives Considered**:
  1. 既存の `__check_category_to()` のマップを新ルールへ書き換えて共有関数化する
  2. 新設 Const クラス（`app/Cyclox/Const/CategoryLineageMap.php`）に一元定義し、既存コードは
     参照に置き換える
- **Selected Approach**: 2. 既存の `app/Cyclox/Const/*` の enum風パターン（`EntryCatLimit` 等）に
  揃えた新設 Const クラスとする。
- **Rationale**: Controller層に対応表を残すと、Model層のバリデーションや Component層の連動処理から
  参照しづらく、依存方向が逆転する（Controller→Modelの依存は既存の層構造に反する）。Const層は
  最下層に位置し、Model/Component/Controllerいずれからも参照可能。
- **Trade-offs**: 新規ファイルが1つ増えるが、対応表の変更箇所が1箇所に確定するため保守性が大きく
  向上する。
- **Follow-up**: 後続spec（catracer-cleanup-2026-27等）がこのConstクラスを参照する前提を
  design.mdのAllowed Dependenciesに明記する。

### Decision: 系統間連動時のHoldPoint付与は昇格元の系統のみに1回とする
- **Context**: brief記載の「HoldPointの付与先の扱い決定を含む」という未決の設計判断。
  Requirement 4.4（連動更新時に実績記録を重複させない）。
- **Alternatives Considered**:
  1. 連動先カテゴリーにも同額のHoldPointを複製付与する
  2. 昇格が発生した元の系統・カテゴリーにのみHoldPointを付与し、連動先には付与しない
  3. HoldPointを両カテゴリーで按分する
- **Selected Approach**: 2. 昇格の起点となったレース結果が属する系統・カテゴリーにのみ
  `HoldPoint`（3pt）を付与する。連動更新で新規作成される相手系統の `CategoryRacer` 行には
  対応する `HoldPoint` 行を作成しない。
- **Rationale**: HoldPointはシーズン末の残留・降格判定（season-rules-2026-27の責務）の入力データ。
  同一の昇格実績を2系統に複製すると、season-rules側で「両系統で残留ポイントを二重に得た」ように
  見え、season-rules-2026-27の設計時に誤った前提を渡すリスクが高い。実際にレース結果を出したのは
  片方の系統のみであるという事実に忠実な記録の方が、下流specにとって解釈しやすい。
- **Trade-offs**: 連動先カテゴリー単体で見ると「昇格したのにHoldPointが無い」ように見えるため、
  UI表示時に系統間連動によるものである旨が分かるよう `reason_note` に明記する運用でカバーする。
- **Follow-up**: season-rules-2026-27側で「系統横断残留判定」を設計する際、本decisionを前提として
  参照すること（roadmap.mdのShared seamsに合致）。

### Decision: `Racer.cat_limit` は「両系統出走」を表す新しい文字値を追加して対応する
- **Context**: Requirement 7。`CatLimitShell::setupCatLimit()` がシーズン最初の出走のみでe/m/nを
  決定し、両系統に出走した選手の情報を欠落させる。
- **Alternatives Considered**:
  1. `CategoryRacer`の実際の有効カテゴリー保有状況から都度算出する方式へ全面置換
  2. 既存の「シーズン内のEntryRacer出走実績」ベースのロジックを維持しつつ、両系統出走を検知したら
     新しい文字値（`b`: Both）を記録する
- **Selected Approach**: 2. `app/Cyclox/Const/EntryCatLimit.php` に `$BOTH`（charVal `b`）を追加し、
  `setupCatLimit()` の判定を「シーズン最初の出走」から「シーズン中にElite/Masters双方の出走が
  あるか」の判定へ変更する。
- **Rationale**: `Racer.cat_limit` は表示専用フィールドであり、既存の「エントリー実績ベース」という
  意味論を変えると影響範囲の見積もりが難しくなる（他機能が同じ意味論を前提にしている可能性）。
  既存ロジックの最小拡張で「両方出走したのに片方しか記録されない」という誤情報のみを是正する。
  `varchar(255)`のためスキーマ変更不要（brief/roadmapの「DBスキーマ変更は原則なし」制約に合致）。
- **Trade-offs**: `CategoryRacer`の保有状況（連動モデルの正）とは独立したデータ源（EntryRacer出走
  実績）のままなので、理論上「カテゴリーは両方保有しているが今季はまだ一方にしか出走していない」
  ケースでは `cat_limit` が `b` にならない。これは表示専用フィールドの既存仕様の延長であり、
  本機能のバリデーション・連動ロジック（真の正）には影響しない。

### Decision: `change_em`は「対応ペア補完・特例対応ツール」として役割を再定義し、無条件一括cancelを廃止する
- **Context**: Requirement 6。現行`exec_change_em()`は切替先と反対の系統の有効カテゴリーを
  無条件に全てcancelする。
- **Alternatives Considered**:
  1. 画面・機能を廃止する
  2. 「対応ペアの補完（片方しか保有していない選手にもう片方を付与する）」および「ME1特例の手動適用」
     専用ツールとして再定義し、対応表と整合しない cancel を行わないよう改修する
- **Selected Approach**: 2. `__check_category_to()`のマップを`CategoryLineageMap`参照に置き換え、
  `check_change_em()`が算出する「終了させるカテゴリー」を「反対系統の有効カテゴリー全部」ではなく
  「切替先カテゴリーとの対応表上のペアにならない反対系統カテゴリーのみ」に限定する。最終的な
  保存は`CategoryRacer`モデルの一元バリデーション（Requirement 3）を通過させ、対応外ペアが
  生じる操作はエラーとして拒否させる。
- **Rationale**: 両保有モデル下ではシーズン内切替の運用自体が不要になる（brief記載）ため、既存機能を
  廃止しても良いが、ME1特例のような「対応表だけでは自動化しきれない手動判断」が残るため、ツールとして
  存続させ役割を限定する方が安全（既存導線を持つ主催者の運用変更コストも抑えられる）。
- **Trade-offs**: 画面のラベル・説明文の変更が必要（View層の改修を伴う）。
- **Follow-up**: 実装時にView（`app/View/CategoryRacers/change_em.ctp`等）の文言更新を含める。

## Risks & Mitigations
- 一括保存経路（`OrgUtilController::uniteRacer()`の`saveAll()`、`exec_change_em()`の`saveMany()`）は
  行ごとのモデルバリデーションでは「保存前の一時的に不正な中間状態」を検知できない場合がある
  （例: 2行のうち1行だけ保存された瞬間の不整合） — 対策: これらの経路はトランザクション
  （`TransactionManager`）内で実行されており、最終コミット前に統合後の集合を明示的に検証する
  呼び出し側チェックを追加する（design.mdのComponents参照）。
- `ResultParamCalcComponent`は2343行と大規模で、既存の暗黙的な呼び出し順序（reasonごとの分岐）を
  壊すと他の既存昇格ロジック（少人数シーズン2勝等）に影響しうる — 対策: 連動処理は既存関数の
  「末尾に追加するフック呼び出し」として実装し、既存ロジックの分岐・削除は行わない。
  **【2026-07-20訂正】** 当初「既存の呼び出し順序はcancel→create」と記載していたが、これは事実誤認
  だった。実際には`__applyRankUp2CM()`（マスターズ側）のみcancel→createで、`__execApplyRankUp()`
  （エリート側、4呼び出し箇所）はcreate→cancelだった。タスク3の独立レビューでこの食い違いが
  発見され、`checkLineagePair`（同系統内複数保有の拒否）を有効化した状態で正当なエリート系統内昇格が
  誤って拒否される問題につながることが判明。対策として、`__execApplyRankUp()`の4呼び出し箇所を
  cancel→createに是正する（タスク4.1のスコープに含める。design.md「Component層 >
  ResultParamCalcComponent（拡張）」参照）。詳細は
  `.kiro/specs/me-mm-linkage-2026-27/agreement-log.md`「実装フェーズでの前提崩れ検出」参照。
- 元ME1判定は`category_racers`の論理削除（`deleted`）を含む全履歴を参照する必要があり、
  `SoftDelete`ビヘイビアのデフォルトスコープ（`deleted=0`のみ取得）に注意が必要 — 対策:
  履歴判定クエリでは`SoftDelete`を明示的に無視する（既存コードの`Behaviors->unload('Utils.SoftDelete')`
  パターンを踏襲）。
- 期限（2026-07-31）に対し実装対象ファイルが大規模component 1本+model+controller+shell+const新設と
  範囲が広い — 対策: tasks.mdでTDD前提の独立タスクに分割し、Const/Model層（バリデーション基盤）を
  先行させて他タスクが並行着手できるようにする。

## References
- AJOCC 2026-27規則改正: https://www.cyclocross.jp/news/2026/07/20262027amendment.html
  （roadmap.md記載。規則本文の詳細読解は本specでは行わず、brief.md/roadmap.mdで既に合意済みの
  対応表・特例ルールをそのまま設計入力とした）
- `.kiro/specs/me-mm-linkage-2026-27/brief.md` — viabilityコードレビュー結果（2026-07-14実施）
- `.kiro/steering/roadmap.md` — 5spec全体構成・Shared seams
