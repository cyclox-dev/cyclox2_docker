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
- When updating any `kiro-*` skill, update the corresponding files in both `.claude/skills/` and `.agents/skills/` in the same change so Claude Code and Codex remain aligned.
- When changing project development rules, update both `CLAUDE.md` and `AGENTS.md` in the same change so both agents follow the same operating rules.
- After changing agent rules or Kiro skills, verify alignment with `diff -qr .claude/skills .agents/skills` and `rg -n '\.Codex|\.claude|\.agents' CLAUDE.md AGENTS.md .claude/skills .agents/skills`; review any output and allow only intentional agent-specific path or handoff wording differences.
- Follow the user's instructions precisely, and within that scope act autonomously: gather the necessary context and complete the requested work end-to-end in this run, asking questions only when essential information is missing or the instructions are critically ambiguous.

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro-steering-custom`)

---

# プロジェクト概要: cyclox2_docker

## このリポジトリについて

**自転車競技管理システム Cyclox2 の Docker 開発環境リポジトリ。**
アプリ本体コードは含まず、docker-compose・各種設定ファイル・SDD運用ルールを管理する。

アプリ本体は2つの git submodule として存在:
- `cyclox2_svr/cyclox2/` … CakePHP 2.x 製メイン管理アプリ (`cyclox-dev/cyclox2web`)
- `cyclox2ressys_svr/cyclox2res_sys/` … CodeIgniter 3.1.x 製成績閲覧アプリ (`cyclox-dev/cyclox2res-sys`)

## 初回セットアップ（別環境の Claude Code への引き継ぎ手順）

```bash
# 1. リポジトリ取得
git clone git@github.com:cyclox-dev/cyclox2_docker.git
cd cyclox2_docker

# 2. アプリ本体取得（SSH アクセス権が必要）
git submodule update --init --recursive

# 3. Docker 起動用ディレクトリ準備（.gitignore 対象のため手動作成）
mkdir -p cyclox2_mysql/var/mysql cyclox2_mysql/var/dump

# 4. SQLダンプを cyclox2_mysql/var/dump/ に配置してからコンテナ起動
docker-compose up -d --build
```

詳細: [docs/architecture/local-setup.md](docs/architecture/local-setup.md)

## ドキュメント構成

```
docs/
├── architecture/          # このリポジトリ固有の把握情報
│   ├── system-overview.md #   全体構成・サービス・ネットワーク・ポート
│   ├── tech-stack.md      #   技術スタック詳細・制約
│   └── local-setup.md     #   ローカル環境構築手順
├── sdd/                   # SDD ベースルール（他リポジトリへ流用可能）
│   ├── workflow.md        #   開発フロー全体像
│   ├── rules/
│   │   ├── testing-policy.md    # テスト方針・TDD ルール
│   │   ├── commit-policy.md     # コミット方針
│   │   └── branching-policy.md  # ブランチ・PR ポリシー
│   └── templates/               # 各種ドキュメントテンプレート
│       ├── agreement-log.md
│       ├── tech-requirements.md
│       ├── test-results.md
│       └── integration-test-checklist.md
└── specs/                 # タスクごとの成果物
    └── <task-id>/
        ├── agreement-log.md
        ├── tech-requirements.md
        ├── test-results.md
        └── integration-test-checklist.md
```

仕様・設計・タスクは `.kiro/specs/<task-id>/` に cc-sdd が管理。

## SDD 運用ルール（重要）

詳細: [docs/sdd/workflow.md](docs/sdd/workflow.md)

**必ず守ること:**
1. ドキュメント完成後、いきなり実装しない。人間の承認を得てから実装開始。
2. 単体テストは実装とセット。TDD（テスト先行）で進める。
3. コミットは自動で行わない。区切りで推奨提示し、人間が判断・実行する。
   （希望があれば自動コミットへの切替も可能。その旨を依頼すること）
4. 合意内容は `docs/specs/<task-id>/agreement-log.md` に必ず記録する。
5. 初回実装時は `docs/specs/<task-id>/tech-requirements.md` で技術要件を確認する。
6. 実行テスト結果は `docs/specs/<task-id>/test-results.md` に記録する。
7. 結合試験項目は `docs/specs/<task-id>/integration-test-checklist.md` に残す。
8. **`main` への直接コミット禁止。** 必ずブランチを切ってから作業し、push 後に PR を発行する。
   コミットのたびに「全コミットが完了したか」を人間に確認してから push・PR に進む。
   詳細: [docs/sdd/rules/branching-policy.md](docs/sdd/rules/branching-policy.md)
9. **コード改修を主体としない作業（運用・データ処理・DB操作・調査等）で「壁打ち→設計→コーディング」フェーズを踏まない場合でも、作業の進捗・合意・判定根拠・実行結果は既存SDDルールと同様に `docs/specs/<task-id>/`（必要に応じ `.kiro/specs/<task-id>/`）へ常時記録・更新する。** 省略してよいのは「コーディングを前提とした承認ゲート」であって、ドキュメント化の義務ではない。最低限 `agreement-log.md`（合意・決定）と実行結果（`test-results.md` 等）を残し、繰り返す作業は再現用の手順（runbook）と成果物の所在も記録する。

## サービスアクセス先（開発環境）

| サービス | URL |
|---|---|
| Cyclox2（管理アプリ） | http://localhost/ |
| phpMyAdmin | http://localhost:4040/ |
| Cyclox2 Result System | http://localhost:8081/ |
| MySQL | localhost:3306 |

## SDD ベースルールの流用について

`docs/sdd/` はリポジトリ非依存のベースルールです。
他リポジトリへは `docs/sdd/` ディレクトリごとコピーして再利用してください。
将来的には `npx cyclox-sdd-base init` による自動展開を予定しています。
