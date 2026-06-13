# SDD ワークフロー定義

このドキュメントはリポジトリ非依存のベースルールです。
cc-sdd（`/kiro-*` コマンド群）の上に本プロジェクト固有の運用を重ねたものです。

---

## 基本の流れ

```
開発タスク依頼
    │
    ▼
【フェーズ0: 把握・プランニング】
  /kiro-discovery <idea>
  → brief.md + roadmap.md 生成
  → 内容を人間と壁打ち（合意形成）
    │
    ▼
【フェーズ1: 仕様化】 ← 承認ゲート①（要件）
  /kiro-spec-init
  /kiro-spec-requirements → requirements.md
  ★ 人間レビュー・合意 → agreement-log.md に記録
    │
    ▼
【フェーズ1続き: 設計】 ← 承認ゲート②（設計）
  /kiro-spec-design → design.md
  ★ 人間レビュー・合意 → agreement-log.md に追記
    │
    ▼
【フェーズ1続き: タスク分解】← 承認ゲート③（実装前確認）
  /kiro-spec-tasks → tasks.md
  tech-requirements.md（初回実装時）
  ★ ドキュメント完成 → 人間に確認を求める（いきなり実装しない）
  ★ 人間から「進めて」の承認を得る
    │
    ▼
【フェーズ2: 実装（TDD）】
  テスト項目をドキュメントに起こす（仕様ベース）
  テストコードを先に実装（RED）
  実装コードで GREEN にする
  /kiro-impl（独立レビュー付き）
  → test-results.md に記録
  → integration-test-checklist.md を作成
    │
    ▼
【フェーズ2後: 人間による結合試験】
  integration-test-checklist.md を人間が確認・実施
    │
    ▼
【コミット推奨】
  実装完了後、コミットを人間に提案する
  （自動コミットはしない。希望があれば自動運用も可）
```

---

## 承認ゲートの原則

- **各フェーズゲートは省略しない。** `-y` オプションによる fast-track は意図的な場合のみ。
- **ドキュメント完成 ≠ 実装開始の許可。** 必ず人間の「進めてよい」を確認する。
- **合意内容は必ず `agreement-log.md` に残す。** 決定事項・決定理由・日付を記録。

---

## タスクディレクトリ構成

```
.kiro/specs/<task-id>/
  ├── spec.json              … cc-sdd管理ファイル（自動生成）
  ├── requirements.md        … 要件（EARS形式）
  ├── design.md              … 設計（アーキ・Mermaid・ファイル構成）
  └── tasks.md               … タスク一覧

docs/specs/<task-id>/
  ├── agreement-log.md       … 合意形成記録（壁打ち結果・決定事項）
  ├── tech-requirements.md   … 技術要件確認（初回実装時）
  ├── test-results.md        … 実行テスト記録
  └── integration-test-checklist.md … 結合試験項目（人間確認用）
```

---

## フェーズ対応コマンド早見表

| フェーズ | コマンド | 出力先 |
|---|---|---|
| 把握・振り分け | `/kiro-discovery <idea>` | `.kiro/specs/<task>/brief.md`, `roadmap.md` |
| 仕様初期化 | `/kiro-spec-init <description>` | `.kiro/specs/<task>/` |
| 要件定義 | `/kiro-spec-requirements <task>` | `requirements.md` |
| 設計 | `/kiro-spec-design <task>` | `design.md` |
| タスク分解 | `/kiro-spec-tasks <task>` | `tasks.md` |
| 実装（TDD） | `/kiro-impl <task>` | コード + `test-results.md` |
| 進捗確認 | `/kiro-spec-status <task>` | - |

---

## ベースルール管理

このドキュメントおよび `docs/sdd/` 配下は **リポジトリ非依存のベースルール** です。
他のリポジトリへ流用する際は `docs/sdd/` ディレクトリごとコピー（または将来的に `npx cyclox-sdd-base init` 経由で展開）してください。

リポジトリ固有情報は `docs/architecture/` に分離されています。
