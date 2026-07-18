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
