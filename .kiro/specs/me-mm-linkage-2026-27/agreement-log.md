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

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-14 | 初版作成（spec.json / requirements.md 初期化に伴う agreement-log 作成） | Claude |
| 2026-07-14 | requirements.md／design.md／research.md／tasks.md を自動承認モードで生成完了。spec.json の全承認を true に設定し `ready_for_implementation: true` へ更新 | Claude |
