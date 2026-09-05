# 合意形成記録: 既存二重付与（対応外ペア）データの是正バッチ

| 項目 | 内容 |
|---|---|
| タスクID | `catracer-cleanup-2026-27` |
| 作成日 | 2026-07-15 |
| 関係者 | kyamady（プロダクトオーナー）、Claude Code |

---

## 壁打ち概要

AJOCC 2026-27 規則改正対応プロジェクト（roadmap.md）の spec 2。主催者が E⇔M 切替画面を
使わず相当カテゴリーを新規付与するだけの運用が常態化した結果、旧系統の所属が有効なまま残り、
シーズン毎の降格処理で独立に降格し続けて「MM1 と ME4 の同時保有」のような対応外ペア保持選手が
多数存在する。me-mm-linkage-2026-27 が導入する「対応ペア両保有モデル」の前提として、既存データを
正しい対応ペアに是正するバッチを CakePHP Console シェルとして実装する。

検討した選択肢と経緯は `.kiro/specs/catracer-cleanup-2026-27/brief.md`（discovery 成果）および
`.kiro/steering/roadmap.md` を参照。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | 是正基準は「直近の出走実態」（racer_results / entry_racers の直近出走系統）とする | 選手の実力・活動実態を最も正確に反映する客観的基準であるため | 2026-07-14 |
| 2 | バッチは任意タイミングで繰り返し実行可能（冪等）とし、logonly（dry-run）モードを持つ | 本番適用は人間が判断・実行する運用（A案）のため、安全な事前検証手段が必須 | 2026-07-14 |
| 3 | 対応表・違法ペア判定は me-mm-linkage-2026-27 の `CategoryLineageMap` / `CategoryLineageLinker` を唯一の正として参照し、本 spec で対応表を重複定義しない | roadmap の Shared seams 方針（対応表の単一ソース） | 2026-07-14 |
| 4 | 履歴は物理削除せず cancel_date + reason_id/reason_note で終了記録を残す（rider-demotion-2025-26 の更新パターン踏襲） | 履歴保全の既存運用ルール | 2026-07-14 |
| 5 | 出走実績が無い等のエッジケースは自動是正せず「手動確認対象」として報告する | 判定根拠のない自動変更はデータ破壊リスクが高い | 2026-07-15 |
| 6 | 是正時の新規付与で C1（ME1）は付与対象としない（MM1 の対応先は既定の C2） | ME1 特例（元ME1のみ）の自動判定による付与はリスクが高く、必要なら手動対応とする | 2026-07-15 |
| 7 | 判定ロジック（純粋関数）と DB 更新（シェル）を分離する | テスト容易性（brief の Boundary Candidates を採用） | 2026-07-15 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 完全重複レコード（同一内容の CategoryRacer 多重行）の是正を本バッチに含める | 既存 `OneTimeShell::setupDuplicatedCatRacerDeleted()` の守備範囲。検出・報告のみ行い是正は対象外（brief の Out of Boundary） |
| 是正時に選手へ ME1（C1）を自動付与する | 元ME1判定を伴う自動付与は誤付与リスクが高い。C1 は正系統として保持される場合のみ維持 |

---

## フェーズゲート承認記録

> 承認状態の正本は `.kiro/specs/catracer-cleanup-2026-27/spec.json` の
> `approvals.{requirements,design,tasks}.approved`。
> ここではブール値を二重管理せず、合意の経緯・補足のみを残す。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件定義（requirements.md） | /kiro-spec-batch による auto-approve（-y 相当）。brief.md（discovery で人間合意済み）の Scope / Constraints を忠実に反映 |
| 設計（design.md） | 同上。me-mm-linkage-2026-27 design の公開 API 契約（CategoryLineageMap / CategoryLineageLinker）にのみ依存。実コード（OneTimeShell / CategoryRacer / RacerResult / EntryRacer / CatLimitShell）と rider-demotion-2025-26 runbook を精査のうえ作成 |
| タスク分解・実装前確認（tasks.md） | 同上。TDD（テスト先行）を各実装タスクに組み込み |

---

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-15 | 初版作成（spec 一括生成時） | Claude Code |

## 2026-09 タスク2.2（系統判定フォールバックと違法種別の分類）実装・独立レビュー反映

**DUP_ONLY は「完全重複起因の重複」以外の違法状態が併存していても、選手全体を DUP_ONLY として
報告する（設計判断、design.md記述との差異を記録）**: `CatRacerCleanupJudge::judge()` は
完全重複レコード起因の重複（同一 category_code + 同一 apply_date）を検出した場合、他に対応外
ペア等の違法状態が併存していても（例: `{CM1,C4,C2,C2}` の CM1/C4 対応外ペア）、選手全体を
DUP_ONLY として報告し、併存する他の違法種別は報告しない。design.md「是正判定フロー」は
`Dup{完全重複レコード起因の重複か}` を FIX 判定より手前に置く形で暗にこの優先順位を示しているが、
design.md本文の文言「完全重複起因**のみ**」は文字通り読むと「重複だけが原因の場合に限る」とも
読め、本実装の「重複が1件でもあれば他の併存する違法状態を問わずDUP_ONLYを優先する」という
挙動と字面上ずれがある。この優先順位は task 2.1 独立レビュー（round-2 MAJOR-2, round-3訂正）が
発見した「重複が対応外ペアと併存すると no-op FIX や是正後も違法が残る FIX になる」問題を回避
するための意図的な設計判断であり、設計変更ではなく記述の精緻化として記録する（再承認は不要）。

**完全重複（同一 apply_date）ではない、同一カテゴリーの重複保有（apply_date違い）への対応**:
独立レビュー（2026-09、実DBデータで確認: 重複保有グループの21%が該当）により、
`__hasExactDuplicateRecord()`（apply_date一致のみを完全重複とみなす）が捕捉できない
「同一カテゴリーだが apply_date が異なる重複保有」が、反対系統の保有と併存すると
破壊的FIX（重複行を2件ともまとめて終了し、終了対象に C1 が含まれると Requirement 4.5により
再付与不能）や no-op FIX（是正後も重複が残ったまま「是正済み」と誤報告、Requirement 7.1違反）
になる欠陥が発見された。製品オーナー確認済みの是正方針として、「より広い DUP_ONLY 分類」では
なく「FIX を返す直前の汎用安全ガード」（`__fixResultIsSafe()`: (1) 同一カテゴリーを2件以上
まとめて終了対象にしない、(2) 適用後の実際の有効集合が `isValidActiveSet()` で合法である
ことを検証）を採用した。理由は汎用性（重複起因に限らず、将来同種の構造的欠落が別経路で
生じても機械的に検知できる）。ガードに抵触した場合は専用の理由コード
`DUPLICATE_HOLDING_UNSAFE_FIX`（他の MANUAL 理由 `NO_LINEAGE_DETERMINABLE` /
`KEEP_LINEAGE_HOLDING_COUNT_INVALID` と区別可能）を持つ MANUAL 決定を返す。

**Requirement 1.4「3件以上の同時保有」の分離**: `CategoryLineageLinker::isValidActiveSet()`
（me-mm-linkage-2026-27 が単一所有、本specの変更対象外）は「同一系統内でちょうど2件」と
「管理対象カテゴリーが3件以上」を区別せず両方 `SAME_LINEAGE_MULTIPLE` として返す。design.md・
Requirement 1.4 が求める独立した「3件以上」分類を、Linker を変更せずに `CatRacerCleanupJudge`
層で事後的に分離するラベル `CatRacerCleanupJudge::VIOLATION_TYPE_THREE_OR_MORE_HOLDINGS` を
新設して対応した（Linker の判定結果そのものは変更しない）。

## 2026-09 タスク2.2 独立レビューround-2でAPPROVED・MINOR4件の是正

round-1 REJECTED（上記「完全重複ではない同一カテゴリー重複保有への対応」参照）を受け、
製品オーナー確認済みの事後安全ガード方式で修正した round-2 で APPROVED。round-2レビューは
round-1の4つの再現形状を自作ハーネスで独立再現・修正確認したほか、管理対象カテゴリー多重集合
329種×出走系統2種×管理対象外有無の全列挙に対しDecisionフィールドから適用後状態を独立再計算し、
不変条件違反0件（FIX決定124件）であることを確認した。

非ブロッキングのMINOR4件を承認と同時に是正した:
1. `testNonExactDuplicateWithoutOppositeLineageHoldingFallsToManualNotDupOnly`に、このケースが
   安全ガードを経由せず既存の`KEEP_LINEAGE_HOLDING_COUNT_INVALID`経路のみでMANUALに落ちる
   ことを固定するアサーションを追加（docblockの主張が将来の分岐順変更で密かに嘘になることを防ぐ）
2. MANUAL理由コード3種（`NO_LINEAGE_DETERMINABLE`/`KEEP_LINEAGE_HOLDING_COUNT_INVALID`/
   `DUPLICATE_HOLDING_UNSAFE_FIX`）を文字列リテラルから`CatRacerCleanupJudge`のクラス定数へ
   （task 6.xのレポート実装が参照する契約値のため）
3. tasks.md task 3.1に「detectの違法種別ラベルはDecision.violationTypeから採ること
   （isValidActiveSet()の理由を直接ラベルにしない）」を申し送り
4. tasks.md task 2.3に「既存のDUPLICATE_HOLDING_UNSAFE_FIXガードを取りこぼさないこと」を
   申し送り、design.md「4種のMANUAL理由」の記述を実態（5種）に合わせて訂正

## 2026-09 タスク2.3（エッジケースの手動確認判定）実装完了・独立レビュー1巡でAPPROVED

Requirement 3.1〜3.5の4種のMANUAL理由（出走実績ゼロ／系統判定不能／同日両系統タイ／正系統
保有0件or複数）を実装。`__determineLineage()`を「1件ずつ順に判定」から「開催日でグルーピング
し、系統判定可能な最も新しい開催日内で系統が一意か」判定する方式に再構成（Requirement 3.3の
同日タイ検知を新規実装）。

独立レビューは、requirements.md 3.1-3.3からコードを見ずに独立の参照実装を書き起こし、ランダム
40,000ケースで`judge()`と突合（不一致0件）、旧アルゴリズムとの1,000形状網羅比較でタイでない
全ケースの系統判定が完全一致（回帰なし）することを確認したうえでAPPROVED。

非ブロッキングの指摘のうち、以下を承認と同時に是正した:
1. `judge()`の`$recentRaces`に関する新しい暗黙の事前条件（空配列＝出走実績0件を意味する、
   `at_date`の書式統一が必要、同日内の判定根拠は入力順に依存する）をdocblock・design.md
   Preconditionsへ明記し、tasks.md task 4.1へ申し送り
2. 同日内のレース順を入れ替えても判定結果（keep/cancel/grant/系統）が不変であることを固定する
   テストを追加（`testFixResultIsInvariantToSameDayRaceOrdering`）
3. `MANUAL_REASON_LINEAGE_TIE`の定数値を他4定数と同じ命名規則（`'LINEAGE_TIE'`）に統一

なお、実装者サブエージェントが権限外である`tasks.md`のタスク2.3チェックボックスを先に
更新していたことが判明したが（本来はレビュー承認後にオーケストレーターが行う運用）、内容自体
（チェックボックス以外の申し送り文の改変なし）に誤りは無かったため、そのまま採用した。
以後の委譲プロンプトでは「spec配下のファイルは編集しない」ことを明記する。

## 2026-09 タスク3.1（違法保有選手の抽出とdetectサブコマンド）実装完了・独立レビュー2巡でAPPROVED

初めて`CatRacerCleanupShell`（Console/Command）を新設。有効（deleted=0/cancel_date IS NULL/
apply_date<=実行日）な対応表管理対象カテゴリーを2件以上保有する選手を抽出し、
`CategoryLineageLinker::isValidActiveSet()`で違法性を直接判定するdetectサブコマンドを実装
（違法種別ラベル付けはtask 3.2の責務と判断——design.mdの「違法候補の抽出」記述がisValidActiveSet()
のみに言及していることを根拠に確認済み）。

round-1 REJECTED: (1) 「書き込みなし」保証テストが`category_racers`の6カラム射影のみを比較
しており、`reason_note`列や結合先の`racers`テーブルへの書き込みを検知できなかった（実際の
本番コードは読み取り専用であることは独立に確認済みで、テストの弱さが問題）。(2)
offset/limit引数に`abc`等の不正値を渡すと`(int)`キャストにより静かに0件として報告され、
design.mdが明記する「不正引数は使用方法を表示して終了」に反していた。

round-2で両方修正・APPROVED。レビュアーは「書き込みなし」テストへの7件のミューテーション注入
（round-1の2件＋新規5件）で全て捕捉されること、不正引数が実CLI・開発DB（実違反406件）で
exit 1になることをそれぞれ独立に確認した。

非ブロッキングの申し送り事項をtasks.md/design.mdへ記録した:
1. `Racer.deleted=0`による除外（開発DBで52選手が対象外）をdesign.mdの「違法候補の抽出」に明記
2. task 3.2へ「detectの違法種別ラベルはDecision.violationTypeから採ること」「limit=0明示指定時の
   見た目上の偽陰性」「書き込みなしテストの監視対象テーブルを、task 3.2でのJudge連携により
   出走実績系テーブルを読むようになったタイミングで拡張すること」を申し送り
3. task 4.2へ「detectのoffset/limitは検証済み違法選手リストに適用されるため、cleanupで
   リストが縮小する運用ではチャンクをずらして掃引すると選手を取りこぼす。毎回offset=0から
   掃引する運用をrunbook.mdに明記すること」を申し送り

## 2026-09 タスク3.2（検出レポートとverifyサブコマンド）実装完了・Tier 1（テスターのみ）で検証

【運用変更】以降、task 4.x（是正実行・DB書き込みを伴う部分）はTier 2（実装者→独立レビュアー、
Opusモデル）を維持するが、それ以外のタスクはコスト意識（グローバルCLAUDE.md）に基づきTier 1
（実装者→テスターのみ）へ切り替えることを人間の指示により決定した。

detectのレポート出力（件数・選手明細・violationType・判定根拠・専用ログ出力）とverify
サブコマンド（全件検査・違法ペアゼロの明示報告）を実装。task 2.2申し送りどおり違法種別ラベルは
`CatRacerCleanupJudge::judge()`の`Decision.violationType`から取得（`judge($racerCode,
$activeHoldings, array())`という空の出走履歴での呼び出しでも、violationTypeがrecentRacesに
依存せず算出されることを利用）。

テスター（Tier 1）による検証: 実CLI・実開発DB（267,917行）でdetect/verifyを実際に実行し、
406選手・858件の違法保有検出、R0019(three_or_more_holdings)・R0020(mismatched_pair)の
正しい分類、読み取り専用性（実行前後のDB行数・ハッシュ一致）を実データで確認。テスト29/29・
122 assertions green。文言上の軽微な不正確さ1件（「verifyがoffset/limitを構造的に拒否する」
という記述が実際は「宣言・参照しないため無視される」が正確な表現だった）を発見・修正した。
