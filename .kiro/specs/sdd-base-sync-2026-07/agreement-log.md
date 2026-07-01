# 合意形成記録: SDDベース sync 適用と .kiro/specs 統一

| 項目 | 内容 |
|---|---|
| タスクID | `sdd-base-sync-2026-07` |
| 作成日 | 2026-07-02 |
| 関係者 | ユーザー、Claude Code |

---

## 壁打ち概要

上流 `sdd_base_template` に対する改修（Part A: 非コーディング作業ルール恒久化・security-policy追加、
Part B: 安全な更新機構 `sync` コマンド、Part C: agreement-log.md 必須化）が別セッションで実装・マージ済み
（upstream PR #8〜#11）となったことを受け、cyclox2_docker 本体へ `npx github:kyamady-dorokid/sdd_base_template
sync --yes` を適用した。

適用の過程で、upstream の `sync` が CLAUDE.md/AGENTS.md の SDD-BASE ブロックを「`.kiro/specs/<id>/` に
一元化・`docs/specs/` は使わない」という新方針に書き換える一方、`docs/sdd/workflow.md` や本リポジトリの
既存spec（`docs/specs/point-sim-2025-26/` 等）は旧方針（`docs/specs/<task-id>/`）のままとなり、
運用ルールが自己矛盾する状態になることが判明したため、方針統一についてユーザーに確認した。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | `.kiro/specs/<task-id>/` へ記録場所を統一する（upstream方針を本採用） | upstream `sdd_base_template` が既にこの方針へ移行済みであり、今後も上流に追従する運用コストを下げるため | 2026-07-02 |
| 2 | 既存の `docs/specs/<task-id>/`（point-sim-2025-26 等）はレガシーとして残置し、移行・削除はしない | 履歴として参照価値があり、移行コストに見合わないため | 2026-07-02 |
| 3 | Part C の3パッチ（kiro-impl team policy / ensure-agreement-log / design tech-req節）を手動で追加適用 | `sync` は既存マーカーの更新のみ行い、まだマーカーの無いファイルへの新規注入は行わない設計のため、`sync`だけでは適用されなかった | 2026-07-02 |
| 4 | `CLAUDE.md`/`AGENTS.md` の非管理部分（ドキュメント構成図・SDD運用ルール（重要）節）も `.kiro/specs/<task-id>/` 表記へ手動で追随修正 | managed block（SDD-BASE）とそれ以外の手書き部分が矛盾しないようにするため | 2026-07-02 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 既存 `docs/specs/*` の `.kiro/specs/*` への移行 | 決定事項#2により不要と判断 |

---

## フェーズゲート承認記録

| フェーズ | 承認日 | 承認者 | 備考 |
|---|---|---|---|
| 要件定義（requirements.md） | - | - | 非コーディング運用作業のためフェーズを踏まず、本ログのみで記録 |
| 設計（design.md） | - | - | 同上 |
| タスク分解・実装前確認（tasks.md） | - | - | 同上 |

---

## 実行結果・検証

- `sync --yes` を2回実行（1回目: lock/snapshot初期化のみ、実ファイル変更なし。2回目: 実差分適用）。
- 適用後の `git diff` を全て目視確認し、意図しない上書き（特に既存カスタム内容の消失）が無いことを確認。
- `.kiro/sdd-base-update-report.md` の「新規適用したファイル」欄は初回実行時、実際には何もファイルへ
  書き込んでいないにもかかわらず全管理対象ファイルを列挙するという、レポート文言が実態と乖離する挙動を確認
  （upstream側の軽微な不具合。害はないが誤解を招くため、upstreamへの改善提案候補として記録）。
- `diff .claude/skills/kiro-impl/SKILL.md .agents/skills/kiro-impl/SKILL.md` および
  `kiro-spec-init/SKILL.md` の同名比較で差分なし（Claude/Codex両対応の整合を確認）。
- `.gitignore` に `.kiro/sdd-base-update-report.md`（sync実行毎に上書きされるため）を追加漏れとして手動補完。

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-02 | 初版作成。sync適用・.kiro/specs統一の決定を記録 | Claude Code |
