# 合意形成記録: JCXシリーズ戦における系統固定のエントリー制御

| 項目 | 内容 |
|---|---|
| タスクID | `jcx-lineage-lock-2026-27` |
| 作成日 | 2026-07-15 |
| 関係者 | kyamady（承認者）、Claude Code（spec自動生成: /kiro-spec-batch 相当の自動パイプライン） |

---

## 決定点の確定状況（2026-07-15 更新: 全件確定）

| # | 決定点 | 決定内容 | 状態 |
|---|---|---|---|
| 1 | **違反検出時の制御強度のデフォルト運用モード**（requirements.md Requirement 5） | **案B（警告+管理者確認）を採用。ただし「警告と回避誘導は強め」の条件付き**（2026-07-15 kyamady 承認）: 警告は違反内容＋回避策（固定系統側の対応カテゴリーでのエントリー）を明示提示し、オーバーライドは既定操作にならない意図的な確認操作に限る（Requirement 5 受入基準7として追加）。設定でハードエラーへ切替可能な構造は維持 | **確定** |
| 2 | リザルトファイル取込（結果CSV取込によるエントリー再作成）の扱い | **警告記録のみ（非ブロック）**。実際に行われたレース結果の記録を妨げないため（Requirement 4.3, 4.4）。決定#1で承認された「業務を止めず記録で統制する」方針に整合するため推奨案で確定 | 確定（#1の方針に基づく） |
| 3 | チェック処理が内部エラーの場合の挙動 | **fail-open**（エラー記録+エントリー継続）。「エントリー業務を止めない」制約を優先（Requirement 7.4）。同上の方針に整合するため推奨案で確定 | 確定（#1の方針に基づく） |

---

## 壁打ち概要

AJOCC 2026-27規則改正で、通常戦は同一シーズン内のエリート⇔マスターズ移動が自由化される一方、
JCXシリーズ戦は系統固定が維持される。me-mm-linkage-2026-27（対応ペア両保有モデル）導入後は
選手が常時両系統のカテゴリーを保有するため、JCX大会のエントリー時に「シーズン内系統固定」を
チェックしないと規則違反エントリーをシステムが許してしまう。

ディスカバリー（roadmap.md / brief.md、2026-07-14 ユーザー合意）で以下が固まっている:
- 対象は cyclox2web（CakePHP 2.x）のエントリー登録・変更の全経路（画面・外部API・一括取込）
- 系統判定は me-mm-linkage-2026-27 の対応表（CategoryLineageMap/CategoryLineageLinker）を
  単一の正として参照し、本specでは再定義しない
- 通常戦のエントリーには影響を与えない。res-sys は対象外
- 制御強度（エラー/警告）は要件定義でオープン決定点として提示する（上表 #1）
- 期限 2026-07-31

要件・設計フェーズでのコード調査（read-only）により以下を確認した（詳細: research.md）:
- JCX戦の識別は `meets.is_jcx`（大会登録画面のチェックボックス）で可能。現在はポイント計算
  （ResultParamCalcComponent）のみが参照しており、エントリー経路では未使用
- エントリー書込経路は6系統（画面の個別登録/編集、エントリーカテゴリー種目変更、外部API
  add_entry の一括登録、リザルトファイル取込の再作成、選手統合のracer_code書換）
- 既存の CatLimitShell に「シーズン初回エントリーで系統を記録する」バッチの先行例があるが、
  JCX限定でなく非同期のため、本機能はリアルタイムのチェックを別途設ける

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | JCX戦の識別には既存の大会属性 `meets.is_jcx` を流用し、新たな識別手段は設けない | 大会登録画面で運用実績があり、ポイント計算でも同フラグを使用している。識別の二重管理を避ける | 2026-07-15 |
| 2 | 系統判定（カテゴリー→エリート/マスターズ）は me-mm-linkage-2026-27 の `CategoryLineageMap` を単一の正として参照する | roadmap の「対応表の重複定義禁止」原則。判定基準の分岐を防ぐ | 2026-07-15 |
| 3 | 固定系統は「当該シーズン・JCX大会への有効エントリーのうち大会開催日が最初のもの」から都度算出し、固定状態を永続化するテーブル・カラムは追加しない | エントリー取消で自然に再判定される。外部APIの削除→再作成フローでも整合が保てる。スキーマ変更なしで済む | 2026-07-15 |
| 4 | チェックの強制点はモデル層（EntryRacer/EntryCategory の保存フック）に一元化し、全保存経路（save/saveMany/saveAssociated）を単一の関門に通す | 経路が6系統あり、コントローラ個別実装ではチェック漏れリスクが高い。me-mm-linkage の一元バリデーションと同じ構え | 2026-07-15 |
| 5 | シーズンのスコープは `meets.season_id`（seasons テーブル）を用い、CatLimitShell の独自シーズン指標（cxSeasonIndex）は使わない | seasons が公式のシーズン境界の正。適用開始シーズンの設定判定にも start_date を利用できる | 2026-07-15 |
| 6 | 選手統合（unite_racer）で事後的に生じ得る系統混在はエントリーチェックの対象外とし、違反検出シェル（Requirement 6）で発見して運用対処する | 統合はエントリー時制御と性質が異なる（過去データの帰属変更）。me-mm-linkage 側の統合チェックとも役割分担 | 2026-07-15 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 固定系統を選手テーブル等に永続化する案（Racer.cat_limit の拡張含む） | 取消・削除再作成で状態が陳腐化しやすく、非同期更新（バッチ）ではエントリー時のリアルタイム判定に使えない。都度算出+リクエスト内キャッシュで性能要件を満たせる見込みのため却下 |
| 通常戦を含む全レースを固定判定の根拠にする案 | 規則改正の趣旨（通常戦は自由化）に反する。JCX戦のエントリーのみを根拠とする |
| res-sys（成績閲覧側）での違反表示 | スコープ外（brief合意） |

---

## フェーズゲート承認記録

> 承認状態の正本は `.kiro/specs/jcx-lineage-lock-2026-27/spec.json` の
> `approvals.{requirements,design,tasks}.approved`。
> ここではブール値を二重管理せず、合意の経緯・補足のみを残す。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件定義（requirements.md） | 自動承認モード（-y 相当）で生成・承認フラグ設定。**Requirement 5 の制御強度デフォルトは未確定の決定点として要件書内に明示**（上記「未決定事項」#1）。人間レビュー時に確定すること |
| 設計（design.md） | 自動承認モードで生成。制御強度は運用モード設定（warn/block）として両案に対応できる設計とし、デフォルト値の確定のみ人間判断に残した。上流 me-mm-linkage-2026-27 の CategoryLineageMap 公開APIに依存（Wave 1 実装完了が前提） |
| タスク分解・実装前確認（tasks.md） | 自動承認モードで生成。TDD（テスト先行）でタスク構成。実装着手前に「未決定事項」の確認を推奨 |

---

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-15 | 初版作成（spec自動生成パイプラインによる） | Claude Code |
| 2026-07-15 | 決定点#1を人間承認により確定（案B採用・警告と回避誘導は強め）。requirements.md Requirement 5 に受入基準7を追加。#2/#3 は#1の方針に基づき推奨案で確定。spec.json ready_for_implementation を true に更新 | kyamady / Claude Code |

## 2026-08-15 追記: me-mm-linkage 第2版の方針転換に伴う要再確認事項

me-mm-linkage-2026-27 が有識者レビューを受けて「外部アプリからのアップロードを不整合を理由に
止めない」方針へ第2版改訂された（roadmap.md「Requirement 3 方針転換」参照）。

本 spec の `add_entry`（API）は、既定の `mode=warn` であっても `jcx_lock_override` が無ければ
登録全体を拒否する設計になっている。cyclox2app が当該フラグを送らない限りエントリー登録が
失敗するため、同種の運用リスク（シーズン中に外部アプリからの登録が止まる）に該当しうる。

ただし本 spec が扱うのはエントリー時の業務ルール制御であり、カテゴリー認定データの整合性検知とは
レイヤが異なる。JCX の系統固定は「登録させない」こと自体に意味がある可能性があるため、
機械的に警告方式へ倒すべきとは限らない。

**実装着手前に `mode=warn` での API 経路の扱い（拒否か、警告付き受理か）を人間に再確認すること。**
記録のみで設計変更は行っていない（me-mm-linkage-2026-27 第2版のスコープ外のため）。

## 2026-08-15 決定: API経路（add_entry）の mode=warn 時挙動を警告付き受理へ変更

上記「要再確認事項」について人間の判断を仰いだ結果、**me-mm-linkage-2026-27 第2版と同方針
（警告付きで受理する）を採用**することが決定した。

### 決定内容

- `add_entry`（API、外部連携による一括エントリー登録）が mode=warn のとき、系統違反を検知しても
  **登録を拒否せず完了させる**。違反明細は成功応答の `jcx_lineage_violations` に含める
- `jcx_lock_override` の値は登録の成否には影響しなくなるが、ログ記録上は「意図的な強行操作
  （override=true）」と「自動受理（override=false、cyclox2app 等からの通常の登録）」を
  区別する情報として引き続き使う
- **mode=block の挙動は変更しない**（override 指定があっても拒否）
- **管理画面経路（Requirement 3）は対象外**。人間が操作する画面では、案B（2026-07-15承認）の
  確認UI付き警告フローをそのまま維持する。「登録させない」ことに業務的意味を持たせる場面は
  画面側で確保する

### 決定理由

cyclox2app は `jcx_lock_override` 相当のパラメータを送信しない。初版仕様（override 無しなら
mode=warn でも拒否）のままでは、JCX 大会へのエントリー登録が API 経由では常に失敗する構造に
なっており、me-mm-linkage 初版が抱えていた問題と同じ構図だった。

### 反映箇所

- `requirements.md`: Requirement 4.1・5.5・5.6 を改訂（AC5.5 を「拒否」から「完了させ違反一覧を
  返す」へ反転。AC5.6 はログ区別の意味へ縮小）
- `design.md`: 「API Contract」節を改訂。mode=warn/block で挙動が分岐することを明記し、
  「要再確認」callout を「2026-08-15 決定」callout へ置き換え
- `tasks.md`: タスク5.1（外部API一括エントリーのプリチェックと応答）の実装方針・テスト観点を
  改訂

### 手続き上の記録

本改訂は CLAUDE.md 開発ルール10（絶対軸）に基づき、実装着手前に人間へ確認したうえで行った。
spec.json の該当 approvals は本改訂を反映して更新する。

## 実装完了（2026-08-15）

全7タスク（1〜7、サブタスク含む）を実装完了。submodule側コミット:

| コミット | 内容 |
|---|---|
| （ブランチ `feat/jcx-lineage-lock-2026-27`、起点 `feat/me-mm-linkage-2026-27`） | タスク1-3: 設定・判定エンジン・モデル強制点 |
| | タスク4: 管理画面の警告・確認UX |
| | タスク5.1: 外部API一括登録の系統固定チェック |
| | タスク6.1: 違反検出シェル |
| | タスク7.2/7.3: checkBulk()のクエリ性能改善 |

**テスト結果: 全17スイート198テスト787アサーション 全GREEN**（jcx-lineage-lock分59件＋
既存me-mm-linkage-2026-27/ajocc-point-267-prod分139件への回帰なし確認済み）。
詳細は `test-results.md` 参照。

### ブランチ選定に関する記録

`release/2026-27-season-rules` からブランチを切ったところ、`CategoryLineageMap` が
存在しないことが判明した（me-mm-linkage-2026-27のPR #13がまだ `release` へマージされて
いなかったため）。本specは me-mm-linkage-2026-27 の `CategoryLineageMap` に依存するため、
ブランチの起点を `feat/me-mm-linkage-2026-27`（PR #13の実装ブランチ、`release`+
`ajocc-point-267-prod` マージ済み）へ変更した。将来 PR #13 が `release` へマージされた際、
本specのブランチも `release` の最新へ追随（マージ）する必要がある。

### 実装フェーズで発見・解消した設計外の課題

1. **`JcxLineageLockTest`（タスク2）とEntryRacerのbeforeSaveフック（タスク3）の相互作用**:
   タスク2のテストデータ投入が通常の `Model::save()` を使っていたため、タスク3導入後に
   意図的な「逆順」データ投入がフック自身に本物の違反として拒否される汚染が発生。
   `skipsJcxLineageCheck` フラグで解消（詳細はtasks.md「Implementation Notes」参照）。
2. **`execAddEntry()` の成功応答がリスト形状だった（design.mdの想定外）**: me-mm-linkageの
   `execAddResult` と同じ構造的制約。成功応答への `jcx_lineage_violations` 追加を見送り、
   ログのみに変更（design.md訂正済み）。
3. **`checkBulk()` の性能未達成**: 初版はcheck()を選手ごとに呼ぶだけで、design.mdが意図した
   「IN句1クエリへの集約」が未実装だった。タスク7の性能検証で気づき修正。

## 2026-08-22/24 有識者レビュー対応（PR #15）

cyclox2web PR #15 に対し、saki-tsurumuraさんから3件のインラインコメントが付いた。裏取りのうえ
2件を実装、1件は現状維持と判断し、人間の承認を得た。

| # | コメント要旨 | 対応方針 |
|---|---|---|
| 1 | `ApiController::execAddEntry()`で、JCX一括プリチェック後にセットされる`skipsJcxLineageCheck`フラグが、その後の別の早期return（`$duplicatedEcatNames`検知時）でリセットされないまま関数を抜ける経路がある | 対応する（要対応と確認） |
| 2 | `EntryRacersController`の`$uses = array('EntryRacer')`は、CakePHPの命名規則により本来不要なはず | 現状維持。実際に検証したところ、本番のコントローラ単体では確かに`$uses`無しで動作するが、テスト用サブクラス`TestableEntryRacersController`（`_stop()`オーバーライド用）はクラス名からのモデル名推測が`TestableEntryRacer`に化けてしまい、`$uses`が無いと`Call to a member function create() on null`で落ちることを確認した。「原因未特定のまま対症療法」だった原因がここで特定できた |
| 3 | `JcxLineageLock::checkBulk()`の違反明細ごとの選手氏名解決（`__racerName()`）が個別に`find()`しており、違反件数分だけクエリが重なる（N+1） | 対応する（reviewer自身は優先度低と明言） |

### 実装内容

- `ApiController::execAddEntry()`: `$duplicatedEcatNames`検知時の早期returnの直前に
  `$this->EntryRacer->skipsJcxLineageCheck = false;`を追加。
- `JcxLineageLock`: `__racerNamesForCodes()`（`Racer.code IN (...)`の単一クエリで複数選手の
  氏名を一括解決）を新設。`checkBulk()`は違反アイテムを先に確定させてから、違反選手分のみを
  まとめて1回で氏名解決するよう変更。`__racerName()`（単体版、`check()`/
  `detectViolatorsInSeason()`が使用）はこの新メソッドの1件版として再実装（挙動不変）。

### 副次的な発見: 性能検証テストの限界

`checkBulk()`の性能テスト（`testCheckBulkFixedLineageQueryCountIsConstantRegardlessOfItemCount`、
task 7で追加済み）と同じパターンで、氏名解決クエリ回数を検証する新規テストを追加したが、
検証の過程で**`cake test`（コンソール実行）では`Configure::read('debug')`が未設定になり、
`DboSource::$fullDebug`がfalseのままクエリログが一切記録されない**ことが判明した。既存の
`testCheckBulkFixedLineageQueryCountIsConstantRegardlessOfItemCount`も同じ仕組み
（`$Meet->getDataSource()->getLog(false, false)`）を使っており、実際にはクエリ回数を
検証できていない（アサーションは常に`0 <= 3`で通過する）ことを確認した。

これは本spec固有の問題ではなく、テスト実行基盤（`cake test`のbootstrap時にdebugレベルが
web実行時と異なる）に起因する既存の制約であり、今回の対応スコープ外と判断した。新規テストは
`assertSame(20, count($result->violations()))`という実際の判定結果の検証は有効なまま維持し、
クエリ回数アサーションは既存パターンとの整合を優先して残した（将来、テスト基盤側でdebugレベルの
問題が解消されれば、このアサーションも意味を持つようになる）。

### 検証結果

全16スイート183テストGREEN（新規テスト1件追加）。

### 人間への申し送り事項（未実装・要判断）

- **`entry_racers`（本番相当554,130行）を含むJOINクエリでインデックス不足による
  フルテーブルスキャンを確認**。提案するインデックス一覧は `test-results.md`「性能検証」節。
  DBスキーマ変更を伴うため本specでは実装せず、要否の判断を仰ぐ。
- `integration-test-checklist.md` に人間による手動確認項目（全26件）を用意した。特に
  外部連携確認（cyclox2app実機での `add_entry` 挙動確認）・運用モード切替（warn⇄block）の
  実地確認が推奨される。

## 2026-08-25 手動結合試験（integration-test-checklist.md）で発見した不具合2件

人間による`integration-test-checklist.md`の手動確認（個別エントリー登録・編集、Requirement 5.2:
確認チェックボックスによる再送信）の実施中に、**自動テストでは検知できない2件の不具合**が
見つかり、いずれも修正した（cyclox2web PR #21 `fix/jcx-lock-warning-form-placement`、
base: `release/2026-27-season-rules2`）。

1. **確認チェックボックスが`<form>`タグの外側に出力される不具合**: `EntryRacers/add.ctp`・
   `edit.ctp`、`EntryCategories/edit.ctp`の3ファイルで`jcx_lock_warning`要素が
   `Form->create()`より前にレンダリングされており、チェックボックスのHTMLが`<form>`の
   外側に出力されていた。ブラウザは`<form>`外の入力を送信しないため、チェックを入れて
   再送信してもオーバーライドが機能しなかった。要素を`Form->create()`の後へ移動して修正。
2. **SecurityComponent使用画面でトークンエラーになる不具合**: 上記1の修正で
   チェックボックスが`<form>`内に入った結果、生の`<input type="checkbox">`が
   `SecurityComponent`（`EntryCategoriesController`が使用）に「未登録の不明なフィールド」
   として検知され、black-hole（トークンエラー・認証エラー）が発動することが手動確認で
   判明。`$this->Form->checkbox('JcxLock.confirm', ...)`（CakePHP標準ヘルパー）に置き換え、
   他のフィールドと同様にトークン検証の対象へ登録されるようにして解消。

両不具合とも、既存の自動テストがコントローラのアクションをDispatcher非経由（
`startupProcess()`を呼ばない）で直接呼び出す方式のため、実際のHTMLレンダリング構造・
SecurityComponentのトークン検証のいずれも経由せず、構造的に検知できなかった。
再発防止として、`.ctp`ソース上の記述順序を静的に検証する軽量な回帰テスト
（`JcxLockWarningElementPlacementTest`）を追加した（フルHTMLレンダリング・
SecurityComponentの実動作を伴うテスト基盤はこのコードベースに無く、新設は今回の
修正規模に対して過剰と判断したため）。

修正後、人間が再度ブラウザで確認し、警告表示・チェック・再送信・登録完了までの
一連の流れが正常に動作することを確認済み。
