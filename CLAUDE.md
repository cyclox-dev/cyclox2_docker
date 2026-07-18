# Agentic SDLC and Spec-Driven Development

Kiro-style Spec-Driven Development on an agentic SDLC

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro-spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, generate responses in Japanese. All Markdown content written to project files (e.g., requirements.md, design.md, tasks.md, research.md, validation reports) MUST be written in the target language configured for this specification (see spec.json.language).

## Minimal Workflow
- Phase 0 (optional): `/kiro-steering`, `/kiro-steering-custom`
- Discovery: `/kiro-discovery "idea"` — determines action path, writes brief.md + roadmap.md for multi-spec projects
- Phase 1 (Specification):
  - Single spec: `/kiro-spec-quick {feature} [--auto]` or step by step:
    - `/kiro-spec-init "description"`
    - `/kiro-spec-requirements {feature}`
    - `/kiro-validate-gap {feature}` (optional: for existing codebase)
    - `/kiro-spec-design {feature} [-y]`
    - `/kiro-validate-design {feature}` (optional: design review)
    - `/kiro-spec-tasks {feature} [-y]`
  - Multi-spec: `/kiro-spec-batch` — creates all specs from roadmap.md in parallel by dependency wave
- Phase 2 (Implementation): `/kiro-impl {feature} [tasks]`
  - Without task numbers: autonomous mode (subagent per task + independent review + final validation)
  - With task numbers: manual mode (selected tasks in main context, still reviewer-gated before completion)
  - `/kiro-validate-impl {feature}` (standalone re-validation)
- Progress check: `/kiro-spec-status {feature}` (use anytime)

## Skills Structure
Skills are located in `.claude/skills/kiro-*/SKILL.md`
- Each skill is a directory with a `SKILL.md` file
- Skills run inline with access to conversation context
- Skills may delegate parallel research to subagents for efficiency
- Additional files (templates, examples) can be added to skill directories
- `kiro-review` — task-local adversarial review protocol used by reviewer subagents
- `kiro-debug` — root-cause-first debug protocol used by debugger subagents
- `kiro-verify-completion` — fresh-evidence gate before success or completion claims
- **If there is even a 1% chance a skill applies to the current task, invoke it.** Do not skip skills because the task seems simple.

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro-spec-status`
- Follow the user's instructions precisely, and within that scope act autonomously: gather the necessary context and complete the requested work end-to-end in this run, asking questions only when essential information is missing or the instructions are critically ambiguous.

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro-steering-custom`)

<!-- SDD-BASE:START (このブロックは sdd_base_template が管理。手動編集は再生成で上書きされる可能性あり) -->
## SDD 開発の進め方（このリポジトリの基本ルール）

本リポジトリは **cc-sdd（Kiro 風 Spec-Driven Development）** をベースに、独自の運用ルールを重ねて開発する。
始め方は **自然言語SDD（軽量）** と **kiroコマンドSDD（フルフロー）** の2入口があり、**どちらでも適用ルール・
成果物・出力先は同一**（変わるのは規模で選ぶ Tier だけ）。詳細フロー・Tierは [docs/sdd/workflow.md](docs/sdd/workflow.md) を参照。

### 必ず守ること（入口に依らず共通）
1. ドキュメント完成後、いきなり実装しない。**人間の承認**を得てから実装を開始する。
2. 単体テストは実装とセット。**TDD（テスト先行）** で進める。
3. **コミットは自動で行わない。** 区切りで推奨提示し、人間が判断・実行する（希望時は自動コミットへ切替可）。
4. 1タスクの記録は **`.kiro/specs/<id>/` に集約**する（`docs/specs/` は使わない）。合意は `agreement-log.md`、
   承認状態の正本は `spec.json`。**二次成果物**（PDF/Word/PPT 等）はビルド出力として **`outputs/<id>/`**、
   **PII を含む成果物**は **`.kiro/specs/<id>/outputs/`**（いずれも git 管理外）に置く。
5. 技術要件は独立ファイルにせず `design.md` の「技術要件・制約チェック」節で確認する。
   一次成果物(md)が正本で、二次成果物は一次から**一方向で再生成**する（手編集禁止・承認は一次側）。詳細は [docs/sdd/deliverables-policy.md](docs/sdd/deliverables-policy.md)。
6. 実行テスト結果は `.kiro/specs/<id>/test-results.md` に記録する。
7. 結合試験項目は `.kiro/specs/<id>/integration-test-checklist.md` に残す。
8. **`main` への直接コミット禁止。** ブランチ→push→PR。詳細は [docs/sdd/rules/branching-policy.md](docs/sdd/rules/branching-policy.md)。
9. **環境越境（Windows × WSL）の確認。** 実行環境が Windows で、かつ作業対象が WSL パス（`\\wsl.localhost\...` / `\\wsl$\...`）の場合は、**そのセッションで最初の自動操作を行う直前に1回だけ**、差分懸念の警告と「WSL内ターミナルから `claude` を起動して作業する」回避策を提示し、このまま続行してよいか確認する。詳細は [docs/sdd/rules/environment-boundary-policy.md](docs/sdd/rules/environment-boundary-policy.md)。（越境でない／非Windowsでは何もしない）
10. **【絶対軸】設計・実装などの実作業には、いかなる状況でも人間の許可なしに着手しない。** 標準ルートでも逸脱・例外・緊急・手戻りでも、「壁打ち→承認→設計→承認→実装」の承認ゲートを安全の基本軸として外さない。実装フェーズ（tasks 承認後）でも、承認済み要件・設計の前提崩れや、設計に無い公開インターフェース追加（CLI・API・ファイル形式・契約・依存）が必要になったら実装を止めて再承認を得る。**逸脱ルートからのリカバリーは必ず「人間への状況共有→確認→承認」を経てから修正の設計・実装に入る**（黙って修正しない・事後記録だけで進めない）。前段の誤りが判明したら前段ゲートに戻り `spec.json` の該当 approvals を false に戻して再承認。ただし承認済みスコープ内の実行はその承認で許可済み（些末な実装詳細に新ゲートは不要）。詳細は [docs/sdd/workflow.md](docs/sdd/workflow.md) の「承認ゲートの原則」。

### ベースルールの所在
- ワークフロー: [docs/sdd/workflow.md](docs/sdd/workflow.md)
- テスト方針: [docs/sdd/rules/testing-policy.md](docs/sdd/rules/testing-policy.md)
- コミット方針: [docs/sdd/rules/commit-policy.md](docs/sdd/rules/commit-policy.md)
- ブランチ方針: [docs/sdd/rules/branching-policy.md](docs/sdd/rules/branching-policy.md)
- 環境越境ポリシー（Windows×WSL）: [docs/sdd/rules/environment-boundary-policy.md](docs/sdd/rules/environment-boundary-policy.md)
- 秘密情報ポリシー（ハードコード禁止）: [docs/sdd/rules/security-policy.md](docs/sdd/rules/security-policy.md)
- 成果物二層化ポリシー（一次=正本/二次=派生ビュー）: [docs/sdd/deliverables-policy.md](docs/sdd/deliverables-policy.md)
- 各テンプレート: [docs/sdd/templates/](docs/sdd/templates/)

### エージェント整合
- `kiro-*` スキルや運用ルールを更新する場合、`.claude/skills/` と `.agents/skills/` を同一変更で揃える。
- 開発ルールを変える場合、`CLAUDE.md` と `AGENTS.md` を同一変更で揃える。
- 整合確認: `diff -qr .claude/skills .agents/skills`

### このSDD基盤について
- 基盤は `sdd_base_template`（npx インストーラ）で展開され、内部で `cc-sdd`（MIT, © 2025 gotalab）を利用している。
<!-- SDD-BASE:END -->

<!-- SDD-BASE:PROJECT-OVERVIEW:START (要記入。このプレースホルダを各リポジトリの実情に合わせて埋めること) -->
## プロジェクト概要（要記入）

> このセクションは `sdd_base_template` が用意したプレースホルダです。リポジトリ固有の情報に置き換えてください。

- **このリポジトリは何か**: {{プロダクト/システムの概要}}
- **技術スタック**: {{言語 / フレームワーク / データストア / インフラ}}
- **主要コンポーネント**: {{コンポーネント構成}}
- **ローカル開発環境の起動**: {{セットアップ・起動手順、または docs/architecture/ への参照}}
- **アクセス先 / ポート**: {{開発環境のURL・ポート等}}

> 把握情報は `docs/architecture/`（任意作成）にまとめ、ここから参照する運用を推奨。
<!-- SDD-BASE:PROJECT-OVERVIEW:END -->
