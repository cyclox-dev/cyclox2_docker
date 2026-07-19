# 合意形成記録: 残存 docs/specs/ の .kiro/specs/ への移行

| 項目 | 内容 |
|---|---|
| タスクID | `docs-spec-legacy-migration-2026-07` |
| 作成日 | 2026-07-19 |
| 関係者 | KYamada / Claude Code |

---

## 壁打ち概要

`.kiro/specs/` 統一（`sdd-base-sync-2026-07`, 2026-07-02）以降も `docs/specs/` 配下に旧レイアウトの
spec 6件が残置されていた。ユーザーから「あとからのトラッキングを可能とするため、現在有効な spec と
重複しないものを移動するプランを立てよ」と依頼を受け、内容を確認した上で移行を実施した。

調査の結果、以下が判明した:
- `sdd-base-sync-2026-07` の決定#2「既存 `docs/specs/<task-id>/` はレガシーとして残置し、移行・削除は
  しない」が既に存在し、本タスクはこれを覆す形になる。
- 一方 `docs/specs/sdd-base-template-upstream-fix/agreement-log.md`（2026-07-01・決定#2の前日）の
  「将来課題」節には「`docs/specs/`→`.kiro/specs/` 統一移行は別タスクとして改めて着手すること」と
  明記されており、本タスクはその積み残しに該当する。
- `point-sim-2025-26` と `rider-demotion-2025-26` は `.kiro/specs/` 側に同名ディレクトリが既に存在し、
  「重複」ではなく同一featureの成果物が新旧レイアウトに分裂していた（`.kiro/specs/` 側=
  requirements/design/tasks(/spec.json)、`docs/specs/` 側=agreement-log/tech-requirements/
  test-results/integration-test-checklist/runbook/sql等）。
- `framework-modernization-2026` は完了済み・廃止ではなく、正式spec化未決定のまま進行中の企画書だった。
- `entry-count-2025-26` / `team-count-2015-26` / `sdd-base-template-upstream-fix` は `.kiro/specs/`
  側に対応ディレクトリがなく、完了済みの独立成果物だった。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | `sdd-base-sync-2026-07` 決定#2（docs/specs不移行）を本タスクで上書きし、`docs/specs/` 配下の残存6件を全て `.kiro/specs/` へ移行する | ユーザーが本タスクで明示的に再指示。`sdd-base-template-upstream-fix` の「将来課題」で予告済みの積み残し作業でもある | 2026-07-19 |
| 2 | `entry-count-2025-26` / `team-count-2015-26` / `sdd-base-template-upstream-fix` / `framework-modernization-2026` はディレクトリ単位でそのまま `.kiro/specs/<id>/` へ `git mv` | `.kiro/specs/` 側に対応ディレクトリがなく単純移動で済むため | 2026-07-19 |
| 3 | `point-sim-2025-26` / `rider-demotion-2025-26` は `docs/specs/` 側ファイルを既存 `.kiro/specs/<id>/` ディレクトリへマージし、内部の相対パス参照（design.md/tasks.md/spec.json/runbook.md）と外部参照（`sdd-agent-tiering-2026-07/handover.md`, ルート `README.md`）を新パスへ追随修正 | 新旧分裂の解消。パスが壊れたままでは runbook 等の実運用に支障が出るため | 2026-07-19 |
| 4 | 各ディレクトリの `agreement-log.md` 内の過去決定文（例: point-sim決定#11, rider-demotion決定#12 に登場する旧 `docs/specs/*/outputs/` 表記）は当時の決定記録としてそのまま残し、書き換えない | agreement-log は決定時点の記録であり、事後の path 変更で過去の意思決定内容を書き換えるべきではないため | 2026-07-19 |
| 5 | `.gitignore` の「レガシー `docs/specs/*/outputs/`」パターン＋コメントを削除（`.kiro/specs/*/outputs/` パターンのみ残す） | `docs/specs/` 配下が完全に無くなるため不要 | 2026-07-19 |
| 6 | 空になった `docs/specs/` ディレクトリ（`.gitkeep` 含む）は削除する（残置しない） | ユーザー明示指示 | 2026-07-19 |

---

## 却下・保留事項

（本タスク開始時に確認した3論点はいずれも上記決定の通り採用。却下事項なし）

---

## フェーズゲート承認記録

| フェーズ | 承認日 | 承認者 | 備考 |
|---|---|---|---|
| 要件定義（requirements.md） | - | - | 非コーディング運用作業のためフェーズを踏まず、本ログのみで記録（`sdd-base-sync-2026-07` と同方針） |
| 設計（design.md） | - | - | 同上 |
| タスク分解・実装前確認（tasks.md） | - | - | 同上。実行前に移動方針をユーザーへ提示し3論点の確認を得た上で着手 |

---

## 移行マッピング（実行結果）

| 旧パス | 新パス | 種別 |
|---|---|---|
| `docs/specs/entry-count-2025-26/` | `.kiro/specs/entry-count-2025-26/` | ディレクトリ単位移動 |
| `docs/specs/team-count-2015-26/` | `.kiro/specs/team-count-2015-26/` | ディレクトリ単位移動 |
| `docs/specs/sdd-base-template-upstream-fix/` | `.kiro/specs/sdd-base-template-upstream-fix/` | ディレクトリ単位移動 |
| `docs/specs/framework-modernization-2026/` | `.kiro/specs/framework-modernization-2026/` | ディレクトリ単位移動（進行中企画のまま移動） |
| `docs/specs/point-sim-2025-26/*` | `.kiro/specs/point-sim-2025-26/`（既存ディレクトリへマージ） | ファイル単位マージ |
| `docs/specs/rider-demotion-2025-26/*` | `.kiro/specs/rider-demotion-2025-26/`（既存ディレクトリへマージ） | ファイル単位マージ |

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-19 | 初版作成。docs/specs/ 残存6件の .kiro/specs/ への移行を記録 | Claude Code |
