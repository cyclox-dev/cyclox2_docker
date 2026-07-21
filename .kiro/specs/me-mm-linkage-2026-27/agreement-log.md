# 合意形成記録: me-mm-linkage-2026-27

| 項目 | 内容 |
|---|---|
| タスクID | `me-mm-linkage-2026-27` |
| 作成日 | 2026-07-14 |
| 関係者 | kyamady |

---

## 壁打ち概要

AJOCC 2026-27シーズン規則改正に伴い、実力別エリート（ME1〜ME4）と実力別マスターズ（MM1〜MM3）を
対応ペア両保有モデルで連動させる仕組みを構築する。roadmap.md 記載の5spec中の spec 1（他specの
依存基盤）。2026-07-14 の壁打ちで以下を決定・確認済み（詳細は brief.md/roadmap.md 参照）:

- 案A「対応ペア両保有モデル」を採用（案B「単一実力レベルモデル」は影響範囲・期限リスクで却下）
- 対応ペア: C2+CM1 (ME2⇔MM1) / C3+CM2 (ME3⇔MM2) / C4+CM3 (ME4⇔MM3)、C1⇔CM1 は条件付き
  （MM1→ME1 昇格は「元ME1」の選手に限る）
- 二重付与防止は「エラーで弾く」方式（自動整合はしない）
- 事前のコードレベル調査（viability review）で、CatLimitShell の e/m 排他前提、change_em の
  反対系統丸ごと cancel、CategoryRacer モデルの重複禁止バリデーション欠如、unite_racer の
  重複チェック欠如を要改修点として特定済み（brief.md の Current State 節に記録）

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | ME⇔MM 対応ペア両保有モデル（案A）を採用 | 既存 category_racers 構造を維持したまま局所改修で実現可能。期限内完了リスクが低い | 2026-07-14 |
| 2 | 対応外ペアの同時有効保有はバリデーションエラーで拒否（自動整合はしない） | 意図しないデータ書き換えを避け、原因（操作ミス・旧仕様前提の操作）を利用者に気づかせるため | 2026-07-14 |
| 3 | ME⇔MM 対応表を単一ソース（Const/Util 層）として定義し、他4 spec から参照する | 対応表の重複定義・不整合を防ぐため（roadmap.md の Shared seams） | 2026-07-14 |
| 4 | 既存不整合データの是正は本 spec の範囲外（catracer-cleanup-2026-27 に分離） | コード改修（恒久対応）とデータ是正（一時対応）は独立に実行できるべきため | 2026-07-14 |
| 5 | 女子系統（WE/WM）の対応要否は requirements フェーズで categories データを調査し明示決定する | brief.md 記載の未決事項。カテゴリーコード体系の実態確認が必要なため | 2026-07-14 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 案B「単一実力レベルモデル」（認定を1レベルに正規化しME/MMは表示のみ読み替え） | category_code 参照箇所全域とres-sys側への影響が大きく、期限（2026-07-31）内完了のリスクが高いため却下 |
| 既存不整合データの本 spec 内での是正 | catracer-cleanup-2026-27 に分離済み（Out of Scope） |

---

## フェーズゲート承認記録

> 承認状態の正本は `.kiro/specs/<id>/spec.json` の `approvals.{requirements,design,tasks}.approved`。
> ここではブール値を二重管理せず、合意の経緯・補足のみを残す。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件定義（requirements.md） | brief.md・roadmap.md の合意事項を EARS 形式要件（Requirement 1〜9）へ落とし込み。女子系統（CL1〜CL3, WM）は本番DBダンプの`categories`実データ調査により複数段階のME⇔MM相当構造を持たないと確認し、対応表対象外と確定（Requirement 9）。自動承認モードで生成・承認。 |
| 設計（design.md） | 対応表を`CategoryLineageMap`（Const層）、判定・連動ロジックを`CategoryLineageLinker`（Util層）に集約し、`CategoryRacer`モデルの一元バリデーションで13/14の既存保存経路を横断的にカバーする方針とした。HoldPoint連動時の付与先（昇格元系統のみ1回）、`Racer.cat_limit`への両系統出走用の値追加（スキーマ変更なし）を設計判断として`research.md`に記録。自動承認モードで生成・承認。 |
| タスク分解・実装前確認（tasks.md） | TDD前提でテスト・実装をペアにした8メジャータスク（サブタスク含め計15実行タスク）へ分解。ResultParamCalcComponent連動フック・change_em改修・CatLimitShell改修・uniteRacer統合は独立ファイルのため並行実施可能（(P)マーク）とし、期限 2026-07-31（実装Wave1: 07/16-07/23）を踏まえた粒度で構成。自動承認モードで生成・承認。 |

---

## 実装フェーズ補足（承認スコープ内の実装詳細）

| # | 内容 | 判断 |
|---|---|---|
| 1 | テスト実行環境の整備: submodule `cyclox2_svr/cyclox2` の `vendors/phpunit.phar`（PHPUnit 3.7.38）を配置し、`app/Config/database.php`（gitignore対象・outer repo側）の `$test` 接続先を実DBコンテナ上の `cyclox2_test` に設定。いずれもコード非変更・gitignore対象のローカル環境整備 | 設計・要件のスコープ外（環境構築のpreflight）。再承認不要 |
| 2 | 環境バグ修正: 上記 phpunit.phar に、PHP 7.3下で`assertEquals()`系アサーションが必ずFatal Errorになる既知の互換性バグ（`PHPUnit_Framework_Comparator_DOMDocument::assertEquals`のシグネチャが親クラスと不一致）を発見。phar内の対象ファイルにshim的な引数追加パッチを適用し再パッケージして解消（アップストリームの公式修正を反映しただけで独自ロジック追加はなし）。パッチ後は`assertEquals`等が正常動作することを確認済み | 設計判断ではなくツール不具合の是正。以後の全タスクのテスト作成に影響するため記録 |
| 3 | タスク1.1実装時の発見: `CategoryRacer`/`Racer`モデルが利用する`Utils.SoftDelete`ビヘイビアが`setup()`時に全belongsTo関連モデル（`Meet`/`RacerResult`等、さらにその先の`Season`/`MeetGroup`/`EntryRacer`/`EntryCategory`/`EntryGroup`/`RacesCategory`）を連鎖的にインスタンス化するため、これらのテーブルに対応するフィクスチャ（レコードなしのスキーマのみ）8本が無いと`CategoryRacer`モデルの生成自体が`MissingTableException`で失敗することが判明。design.mdのFile Structure Planが列挙する4フィクスチャに加え、この8本を`app/Test/Fixture/`に追加した | design.mdの公開インターフェース（Const/Util層のAPI契約等）には影響しない実装詳細・技術的必然。以後のモデル・コンポーネント系タスク（3, 4.1, 4.2等）は同じ8フィクスチャを`$fixtures`に含める必要があるとして`tasks.md`のImplementation Notesに記録 |

## 実装フェーズでの前提崩れ検出（タスク3・要人間判断）

タスク3（`CategoryRacer`保存時バリデーション追加）の実装完了後、独立レビュー（reviewer）で以下2件の
HIGH指摘が上がり、いずれも承認済みdesign.md/research.mdの前提そのものに関わるため、実装を一時停止し
人間の判断を仰ぐ。

| # | 内容 | 影響 | 選択肢（例） |
|---|---|---|---|
| 1 | `ResultParamCalcComponent::__execApplyRankUp()`の実コード順序は「新カテゴリー保存→旧カテゴリー
    cancel」（create→cancel）。research.md:179は「cancel→create」と明記しており、design.mdの
    連動フロー図もこの前提。タスク3の`checkLineagePair`をこのまま有効化すると、通常のレース結果昇格
    （例:C2→C1）の新カテゴリー保存時点で旧カテゴリーがまだ有効なため「同系統内複数保有」で拒否され、
    既存の正当な昇格処理そのものが壊れる。 | タスク3のObservable違反（既存正当保存が壊れる）。
    タスク4.1/4.2が着手不能 | (a) `ResultParamCalcComponent`側をcancel→create順に改修（設計変更・
    要再承認）／(b) `checkLineagePair`側で昇格処理の遷移的な状態を許容する仕組みを追加（設計変更）／
    (c) 他の対策 |
| 2 | ME1特例ゲート（{C1,CM1}が結果集合になる場合、元ME1でなければ拒否）を字面通り厳格に実装（タスク3
    実装時にdesign.mdの文言から選んだ解釈）。しかしRequirement 5 AC2・AC3、Requirement 4 AC3の文言は
    いずれも「マスターズ側の連動更新または新規付与により」C1が付与される場合に限定しており、レビューは
    エリート系統自体の昇格（ME2→ME1）を対象外とする解釈がより文言に整合すると指摘。厳格解釈のままだと
    CM1保有選手の初回ME2→ME1昇格が常に拒否される。 | Requirement 5 AC2（"マスターズ側は変更せず維持"、
    昇格成功が前提）と矛盾する可能性 | (a) ゲートをマスターズ駆動の連動・change_em経路限定に狭める（設計
    明確化・軽微な再承認）／(b) 厳格解釈を維持し要件側を修正／(c) 他の対策 |

**現在の状態**: タスク3の実装自体（`CategoryRacer.php`の2ルール＋テスト）は完了・全テストGREEN。
ただしtasks.mdでは`_Blocked:_`注記を付け、`[x]`は付けていない。上記の判断が出るまでタスク4以降には
着手しない。

### 人間の判断・解決方針（2026-07-20）

| # | 決定内容 | 反映先 |
|---|---|---|
| 1 | Finding 1: `__execApplyRankUp()`（エリート側昇格、4呼び出し箇所）を「create→cancel」から
    「cancel→create」に是正する。cancel対象はcreateの結果に依存しない事前確定リストのため、
    最終DB状態を変えずに安全に入れ替え可能と確認済み。タスク4.1（`ResultParamCalcComponent`を
    既に触る予定）のスコープに含めて実施する。 | design.md「Component層 >
    ResultParamCalcComponent（拡張）」に追記済み。research.md:179の誤記載も訂正済み |
| 2 | Finding 2: `checkLineagePair`の元ME1特例ゲートは、保存理由（`reason_id`）が
    `CategoryChangeFlag::$LANKUP`（昇格: RESULT_UP/SEASON_UP/OTHER_UP/TO_SUPER_RACER/BY_RULE）に
    分類される場合はスキップし、それ以外（change_emのREQUEST_CHANGE、選手統合、その他手動付与等）
    にのみ厳格に適用する。 | design.md「Model層 > CategoryRacer（拡張）」に追記済み |

**再承認**: 上記2件の設計改訂について人間に提示し、承認を得た（2026-07-20）。`spec.json`の
`approvals.design`に`amended_at`/`amendment_note`を追記。この後、タスク3の実装（`checkLineagePair`の
元ME1ゲート部分）を上記方針2に合わせて修正し、再レビューで承認された。

## 実装フェーズでの前提崩れ検出（その2・タスク4.1・要人間判断）

タスク4.1（`ResultParamCalcComponent`へのエリート→マスターズ連動統合）の実装中、上記Finding 1
（保存順序）の是正を織り込んだ上でなお、**より根本的な設計前提の崩れ**が実装者自身によって発見された。

**症状**: design.md記載の順序（cancel旧エリート→create新エリート→HoldPoint→
`propagateLinkedPromotion`呼び出し）のまま実装すると、両系統保有選手（例: C3+CM2を有効保有）が
エリート側で昇格（例: C3→C2）した瞬間、**新エリートカテゴリーのcreate自体**がタスク3の
`checkLineagePair`に拒否される。理由: create時点ではマスターズ側はまだ古い値（CM2）のままであり
（`propagateLinkedPromotion`はこのcreateの"後"に呼ばれる設計のため）、`checkLineagePair`が見る
保存後集合は`{CM2, C2}`となり、これは対応表上の正当なペアではない（C2の対応先はCM1）ため
「対応外ペア」として拒否される。

**重要度**: Finding 1/2よりも影響範囲が広い。両系統保有選手の昇格はRequirement 4が想定する
中核シナリオそのものであり、このままでは連動機能の主要ケースが機能しない。

**実装者の対応**: 該当テスト（`testEliteC3ToC2PropagatesMastersCm2ToCm1`）を、期待する正しい挙動
（昇格が成功しマスターズ側がCM1に更新される）を主張したままRED状態で残し、無理に緩和・修正せず
人間の判断を仰ぐ形でSTATUS: BLOCKEDとして報告。他の4件のテスト（保存順序是正・単独保有時の
非付与・元ME1特例との整合・既存CL昇格の非破壊）はGREENで、連動フック自体・保存順序の是正
（Finding 1相当）は正しく実装済みで副作用もない。

**提案する解決方針（未承認・要検討）**: `propagateLinkedPromotion`（タスク2.4、既承認）自体の内部
実装は変更せず、**呼び出しのタイミングのみ**を変更する。具体的には、`__execApplyRankUp()`内で
新エリートカテゴリーをcreateする"前"に、まだ未保存の新エリートカテゴリーコードを引数として
`propagateLinkedPromotion`を先に呼び出し、マスターズ側を先に解決・cancel・create済みの状態に
してから、最後に新エリートカテゴリーをcreateする（`resolveLinkedTarget`/`propagateLinkedPromotion`は
渡された`$appliedCategoryCode`がまだDBに保存されているかどうかに依存しないロジックのため、
先行呼び出しは技術的に成立する）。これによりcreate時点で`checkLineagePair`が見る保存後集合は
既に`{新マスターズ値, 新エリート値}`となり、正当なペアとして通過する。design.mdの連動フロー図
（シーケンス図の呼び出し順序）の改訂が必要（`propagateLinkedPromotion`の内部実装・契約自体は不変）。

**現在の状態**: タスク4.1はtasks.mdに`_Blocked:_`注記。実装済みのコード（保存順序是正＋連動フック＋
テスト）は`ResultParamCalcComponent.php`に存在するが、人間の承認を得るまでこのまま維持し、
再レビューには進めない。

## ブランチ戦略の決定（2026-07-20・人間指示）

AJOCC 2026-27ルール改正5spec（me-mm-linkage-2026-27・catracer-cleanup-2026-27・
season-rules-2026-27・jcx-lineage-lock-2026-27・ajocc-point-267-prod）の実装は、各specが
個別にmainへ直接PRするのではなく、専用の統合ブランチを経由する構成に変更する。

```
main
 └─ release/2026-27-season-rules（新設・統合ブランチ、submodule cyclox2_svr/cyclox2側のみ）
     ├─ feat/me-mm-linkage-2026-27（本spec、既存）
     ├─ （catracer-cleanup-2026-27 用ブランチ、未作成）
     ├─ （season-rules-2026-27 用ブランチ、未作成）
     ├─ （jcx-lineage-lock-2026-27 用ブランチ、未作成）
     └─ （ajocc-point-267-prod 用ブランチ、未作成）
```

- 適用範囲: submodule（`cyclox2_svr/cyclox2`、実装コードの場所）のみ。outer repo
  （`cyclox2_docker`、spec文書の場所）は従来通りmain直接PRのまま変更しない。
- 統合ブランチ名: `release/2026-27-season-rules`（origin/mainから作成・push済み）。
- `feat/me-mm-linkage-2026-27`は現時点でmainから0コミット差分（未コミット作業のみ）だったため、
  実質的なrebaseは不要。upstream追跡先を`origin/release/2026-27-season-rules`に変更済み
  （将来のPRは`release/2026-27-season-rules`宛てに発行する）。
- 効果: 5spec全ての実装が揃った状態のブランチ（`release/2026-27-season-rules`）で結合テストが
  可能になる。各specのPRはこの統合ブランチへ向け、最終的に統合ブランチ→mainのPRで本番反映する。
- 今後の作業への影響: 他4specの実装に着手する際は、それぞれのfeatureブランチを
  `release/2026-27-season-rules`から切ること（mainから直接切らない）。PR先も同様に
  `release/2026-27-season-rules`とする。

### 敵対的検証の結果と最終方針（2026-07-20）

上記「先行呼び出し」提案について、人間の指示によりreviewerサブエージェントで敵対的に再検証した。
結果は **SOUND WITH CAVEATS**（機構自体は健全、ただし1件の重大な見落としあり）。

**見落とし**: `__execApplyRankUp()`への到達経路は当初把握していた4箇所（直接呼び出し）だけでなく、
`__applyRankUp()`という薄いラッパー経由の**5箇所目**（`ResultParamCalcComponent.php`行844/864、
通常規模のレース・通常のランクアップという最も一般的な昇格パス）が存在し、この経路は保存順序の
是正対象から漏れていた。この5箇所目を含めて是正しない限り、通常規模のエリート昇格そのものが
（連動の有無に関わらず、単独保有選手でも）`checkLineagePair`の「同系統内複数保有」判定で拒否され
続ける。

**検証で問題なしと確認された点**: `resolveLinkedTarget`/`propagateLinkedPromotion`は昇格先カテゴリー
コードを不透明な文字列としてのみ使用しDB保存済みかに依存しないこと、トランザクション安全性、
元ME1判定のタイミング、単独保有時の非付与、既に整合済みの場合のno-op、いずれも先行呼び出しにより
壊れないことを個別に確認済み。

**最終方針（人間承認・2026-07-20）**: 5箇所全てで「cancel→propagateLinkedPromotion（相手系統を
先に整合）→create→HoldPoint」の順序に統一する。`__reCalcResults`経由で通常規模（`__started>=10`）の
昇格を実際に駆動するE2Eテストを追加し、この主要パスが動作することを検証する。design.mdの
「Component層 > ResultParamCalcComponent（拡張）」および「リアルタイム昇格の系統間連動フロー」
シーケンス図をこの最終方針に合わせて改訂済み。

**実装完了・独立レビュー承認（2026-07-20）**: 上記方針に沿って`ResultParamCalcComponent.php`を修正。
独立レビューで`__execApplyRankUp()`への到達経路を再列挙し（grep + 個別トレース）、5経路で過不足ない
ことを確認。E2Eテストが実際に5番目の経路（`__applyRankUp()`経由）を駆動していることも実行ログで
確認済み。トランザクション安全性（cancel後にcreateが失敗した場合の巻き戻し）も確認済み。
`__applyRankUp2CM()`（タスク4.2のスコープ）は無変更であることを確認済み。タスク4.1は承認・完了。

## 実装フェーズでの前提崩れ検出（その3・タスク5・人間承認済み）

タスク5（change_em改修）の実装中、`exec_change_em()`に既存バグ（本specと無関係に元から存在）を
発見。`end_ids_json`の空判定が`!empty(JSON文字列)`のため、cancel対象0件時に送信される`"[]"`が
「空でない」と判定され、`CategoryRacer->saveMany(array(), ...)`が実行されCakePHPの`saveMany()`が
`$this->data`にフォールバックして必須フィールド欠落のSQLエラーで保存全体がロールバックする。
タスク5の修正により「解除対象0件」（ペア補完・既に正しいペアの維持）がRequirement 6の主要
シナリオになるため、このバグを踏む頻度が大幅に増え、機能のObservableが実UIで動作しなくなる。

**人間承認（2026-07-20）**: タスク5のスコープを最小限拡張し、`json_decode`後の配列が空でない
場合にのみ`saveMany()`を呼ぶガードを追加する（保存判定ロジック自体は変更しない）。design.md
「Controller層 > CategoryRacersController（change_em系, 拡張）」に追記済み。

**実装完了・独立レビュー承認（2026-07-20）**: 上記バグ修正を含めてタスク5は独立レビューでAPPROVED。
レビューでC1/CM1非対称ペア（OR判定の第1項）がcheck_change_em()側で未検証という中重度の指摘があり、
対応として`testCheckChangeEmPreservesCm1ForFormerElite1SwitchingToC1`（R0017使用）を追加、GREEN確認
（10 tests, 44 assertions）。他4スイート（CategoryLineageLinker/CategoryRacer/
CategoryRacerFixtureData/ResultParamCalcComponent）も回帰なし。タスク5は承認・完了。

---

## タスク7のスコープ拡張決定（2026-07-20・人間承認済み）

タスク7（選手統合の整合性チェック）実装中、タスク2.5レビューで既に指摘されていた懸念
（`validateActiveSet()`はME1-4/CM1-3のみを検証対象とするため、対応表対象外カテゴリー〔例: WM〕の
統合後重複は検出できない）が実際に確認された。`CategoryRacer`モデル自体の重複チェックも
`saveAll()`がid+racer_codeのみを送信するため発火しないことも確認済み。

**人間承認（2026-07-20）**: `CategoryLineageLinker`に新規静的メソッド
`validateNoDuplicateAnyCategory($racerCode)`を追加する（既存の`isValidActiveSet()`・
`validateActiveSet()`は変更しない）。判定基準は「対応表管理対象か否かを問わず、同一
category_codeの有効保有が2件以上か」という単純な件数チェックのみ（ペア妥当性・同系統内
複数保有の判定は`validateActiveSet()`の責務のまま）。Requirement 3 AC2・8 AC2・9 AC2の
文言はいずれも単純な件数基準で定義されているため、この単純なチェックで要件を満たすと判断。
`uniteRacer()`から`validateActiveSet($uniteTo)`と並行してこの新メソッドも呼び出す。
design.md「Util層 > CategoryLineageLinker」「Controller層 >
OrgUtilController.uniteRacer（拡張）」に追記済み。

## 実装フェーズでの前提崩れ検出（その4・タスク8・人間承認済み）

タスク8（結合シナリオの検証）の実装・独立レビューで、タスク4.2レビュー時に低優先度懸念として
指摘・タスク8での検討を申し送りされていた問題が実際に到達可能な不具合であることが確認された。

**症状**: `ResultParamCalcComponent`のマスターズ側ランクアップ呼び出し元（`CM1+2+3`分岐、
行700/702）が`__applyRankUp2CM()`の戻り値を一切受け取っていない。エリート側の対応する
呼び出し元（`__applyRankUp()`、行864）は正しく戻り値を見て`RET_FAILED`時に`return false`する一方、
マスターズ側だけこの処理が欠落しているため、`__applyRankUp2CM()`内部で連動保存や新カテゴリー
createが失敗しても外側の`__reCalcResults()`は成功したものとして処理を継続し、トランザクションが
コミットされてしまう（旧カテゴリーはcancel済み、新カテゴリーは未付与、または連動更新が
中途半端な状態のまま確定するおそれがある）。Requirement 4.6・タスク8自身のObservable
（「対応外ペア・重複が発生しうる操作は必ずエラーで止まる」）に反する。

**人間承認（2026-07-21）**: エリート側と同じパターン（戻り値を受け取りRET_FAILED/RET_ERRORなら
return false）を行700/702に適用して修正する。タスク8の結合試験にこのロールバックを確認する
テストを追加する。design.md「Component層 > ResultParamCalcComponent（拡張）」に追記済み。

**実装完了・独立レビュー承認（2026-07-21）**: 上記修正を適用し、`__reCalcResults`経由で実際に
`CM1+2+3`分岐・マスターズ側連動失敗を発生させ、トランザクション全体がロールバックされることを
DB再取得で検証するテスト（7件目の結合テスト）を追加。独立レビューでAPPROVED（9スイート全て
期待件数でGREEN）。**これによりme-mm-linkage-2026-27 spec の全15タスクが完了。**

## 最終結合検証（/kiro-validate-impl）での指摘・是正（2026-07-21・人間承認済み）

全15タスク完了後の`/kiro-validate-impl`実行時、要件カバレッジ監査（独立サブエージェント3方向並列）で
Requirement 3 AC3（「拒否理由が分かるメッセージを提示する」）の未充足が判明した。個別タスク
（5・7）はいずれも「保存処理・エラーハンドリング自体は変更しない」という明示的スコープ限定を
していたため、タスク単位のレビューでは検出されず、タスクを横断した本結合検証で初めて可視化された。

**症状**: `exec_change_em()`・`do_unite_racer()`の2画面で、拒否理由（対応外ペア・重複・ME1特例）を
保持する`validationErrors`／`CategoryLineageValidationError::getMessage()`が、実際にFlash表示
される汎用メッセージまで届いていない。データ整合性への影響はない（拒否ロジック自体は完全に
機能）が、操作者が画面上で拒否理由を判別できない。

**人間承認（2026-07-21）**: 修正してからGOとする方針を承認。design.md「Error Handling」に
追記済み。

**実装完了・独立レビュー承認（2026-07-21）**: `exec_change_em()`は`validationErrors`を
フラット化してメッセージに含め、`uniteRacer()`は公開シグネチャ（bool）を変えずに
`$uniteRacerFailureMessage`プロパティ経由で具体的理由を`do_unite_racer()`へ伝達するよう修正。
独立レビューでAPPROVED（9スイート・117テスト全てGREEN、判定ロジックの変更なしを確認）。

**`/kiro-validate-impl me-mm-linkage-2026-27` 最終判定: GO（2026-07-21）**。
全15タスク完了・全結合検証項目クリア。spec完了。

**コミット・PR発行（2026-07-21）**: submodule `cyclox2_svr/cyclox2`側で8コミットに整理して
`feat/me-mm-linkage-2026-27`ブランチへコミット・push、`release/2026-27-season-rules`
統合ブランチへPR発行済み: https://github.com/cyclox-dev/cyclox2web/pull/13

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-14 | 初版作成（spec.json / requirements.md 初期化に伴う agreement-log 作成） | Claude |
| 2026-07-14 | requirements.md／design.md／research.md／tasks.md を自動承認モードで生成完了。spec.json の全承認を true に設定し `ready_for_implementation: true` へ更新 | Claude |
| 2026-07-19 | 実装フェーズ着手。タスク1.1実施に伴うテスト環境整備・phpunit.pharバグ修正・フィクスチャ追加スコープの補足を記録（上表参照） | Claude |
