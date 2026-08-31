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
| 2026-08-29 | タスク1.1実装完了（下記参照） | Claude Code |
| 2026-08-30 | タスク2.1実装完了・design.md記述の事実訂正（下記参照） | Claude Code |

## 2026-08-29 タスク1.1（出走実態系フィクスチャの作成）実装完了

`app/Test/Fixture/`配下6件のスキーマのみの空フィクスチャ（Meet/EntryGroup/EntryCategory/
EntryRacer/RacerResult/CategoryRacesCategory、me-mm-linkage-2026-27がモデル生成要件のために
新設したもの）へ、本specのテストシナリオ（DNS/DNF区別・as_category有無・削除済みデータ・
系統判定不能な出走・対応外ペア・同系統内複数保有・重複保有・未来日apply_date）を表現する
実データを追加し、フィクスチャ一式のロードを確認するスモークテスト
（`app/Test/Case/Console/Command/CatRacerCleanupShellTest.php`）を新設した。

**独立レビュー4巡**（tester→reviewerの順次実行方針に基づき、reviewer subagentで実施）:
1巡目REJECTED（未来日apply_date行が判定に無関係・削除済み行が判定結果を左右しない・DNS以外の
非完走ステータスが存在しない・違法保有選手と出走実績のある選手が分離）。2巡目REJECTED（1巡目の
指摘への対応中に別の既修正シナリオを壊す副作用が発生）。3巡目REJECTED（DNS除外・
category_racers.deleted=0除外の2フィルタが依然として判定結果を左右しない状態）。3回連続REJECTED
のため、本リポジトリのkiro-impl運用ルールに従いデバッグサブエージェント（新規コンテキストでの
根本原因分析）へ委譲し、根本原因（各修正が指摘項目のみを直し、影響範囲全体を再検証していな
かったこと）を特定・修正・自己検証。4巡目レビューでAPPROVED。

最終検証では、要求された9種類のフィルタ（DNS除外・DNF非除外・meet/entry_racer/racer_result各
deleted・Racer.deleted・category_racers.deleted・cancel_date・apply_date）それぞれについて、
「そのフィルタを1つだけ外すと判定結果が反転するか」を、出走チェーン全体とcategory_racersの
複合条件行列という2つの統合表から機械的に再導出して確認した（9/9成立）。この「個別指摘だけを
見ず統合表で確認する」手法は、tasks.mdのImplementation Notesにも申し送りとして記録した。

本タスクはテストフィクスチャ・テストファイルのみの変更で、本番コード（app/Cyclox, 
app/Console/Command）への変更は一切なし。

## 2026-08-30 タスク2.1（判定結果オブジェクトと正常系の是正決定）実装完了・design.md記述の事実訂正

`app/Cyclox/Util/CatRacerCleanupDecision.php`・`CatRacerCleanupJudge.php`・
`app/Test/Case/Cyclox/Util/CatRacerCleanupJudgeTest.php`を新規実装。独立レビューで1巡目
REJECTED（①合法な保有集合に対してもFIXを返し正当な保有を誤終了・不要な付与をしてしまう分岐
漏れ、②CL1等の対応表管理対象外カテゴリーがcancelTargetIdsに混入する、③task 2.2の守備範囲で
あるisValidActiveSet()由来の違法種別分類を先行実装していたがどのテストもgetViolationType()の
値を検証していなかった）。3件とも修正し、2巡目で解消（judge()冒頭でviolationType===nullなら
即座にOK決定を返す分岐を追加、cancelTargetIds構築ループにCategoryLineageMap::
isLineageManagedCategory()フィルタを追加、mismatched_pairケースのgetViolationType()を
アサートするテストとOK分岐・管理対象外カテゴリー除外の専用テストを追加）。

**design.md記述の事実訂正（設計変更ではなく記述の誤り）**: design.md「Util層 >
CatRacerCleanupJudge」Implementation Notesは「Linkerはコンストラクタで受け取る」と記述して
いるが、`CategoryLineageLinker`はprivateコンストラクタを持つ全static実装のクラスであり、
コンストラクタ注入は物理的に不可能。実装はstatic呼び出し（`CategoryLineageLinker::
isValidActiveSet()`）で対応しており、これはdesign.mdの記述誤りの訂正であって設計変更ではない
ため、再承認は不要（レビュー指摘FINDING 7）。

**2巡目レビューでもREJECTED（MAJOR-1）**: 1巡目Finding 2の修正がcancelTargetIds構築ループ
のみに`isLineageManagedCategory()`フィルタを適用しており、`__deriveViolationType()`が
`isValidActiveSet()`へ渡す集合には同フィルタが未適用のままだった。`isValidActiveSet()`は
管理対象外カテゴリーも含めた重複チェックを最優先で行うため、CL1/WM等の管理対象外カテゴリーが
重複保有されているだけで（管理対象カテゴリーとしては完全に合法な集合でも）violationTypeが
非nullになり、Finding 1で追加したOK分岐を経由できずFIXへ落ちてしまう不具合が再発していた。
`__deriveViolationType()`内でも`isLineageManagedCategory()`フィルタを適用し解消（回帰テスト
2件追加）。あわせてMINOR-1（`isValidActiveSet()`単体では付与カテゴリーがnullに縮退する
リグレッションを検出できない盲点）を`assertNotNull()`追加で解消。MAJOR-2（完全重複起因の
管理対象カテゴリー保有がDUP_ONLY未実装のためFIXに落ち、Requirement 4.5によりC1が復旧不能に
降格されうる懸念）はtask 2.2のスコープであり本タスクの不具合ではないため、tasks.md task 2.2の
受け入れ条件に「本タスク完了前にCatRacerCleanupShellを配線しないこと」を明記して申し送った。

**3巡目レビューでAPPROVED**: 2巡目の修正（`__deriveViolationType()`へのフィルタ追加）が
データフロー上正しいことを、コード精読・round-2再現ケースの再実行・実装者未テストの新規
5パターン（管理対象外重複＋真の違法ペア併存等）・ミューテーションテスト2種（意図的にバグを
仕込んでテストが実際に検出するか確認）の4手段で独立に確認したうえでの承認。管理対象カテゴリー
の真の重複検出（duplicate_category/same_lineage_multiple）が弱まっていないことも確認済み。
非ブロッキングの指摘として、2巡目に申し送ったMAJOR-2の再現例（「`{C1,C1}`のみで破壊的FIX」）
が実際には誤り（この入力はMANUALに落ちる。破壊的FIXが起きるのは重複が正系統と反対側にある
場合、例: `{C1,C1,CM1}`＋Masters出走）であることが判明し、tasks.md task 2.2の受け入れ条件を
正確な再現例に訂正した。また「重複と対応外ペアが併存する混在ケース」（no-op FIXや是正後も
違法が残るFIX）という別の未記録ケースも同時に申し送った。いずれもtask 2.1のコード修正ではなく
task 2.2向け申し送り文の正確性の問題として対応（コード変更ゼロ）。
