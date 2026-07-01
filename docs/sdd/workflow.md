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
  技術要件は design.md の「技術要件・制約チェック」節で確認（初回実装時）
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

## 非コーディング作業のドキュメント化（重要）

コード改修を主体としない作業（運用・データ処理・DB操作・調査・移行など）は、
「壁打ち→設計→コーディング」という開発フェーズを踏まないことがある。
**フェーズを踏まない作業であっても、進捗・合意・判定根拠・実行結果のドキュメント化は省略しない。**

- 省略してよいのは「コーディングを前提とした承認ゲート（requirements/design/tasksの段階承認やTDD）」であり、**記録義務ではない**。
- `.kiro/specs/<task-id>/` を作成し、少なくとも次を常時更新する:
  - `agreement-log.md` … 依頼内容・合意・決定（理由・日付）・却下/保留事項・承認記録
  - 実行結果（`test-results.md` 等）… 何をどう検証し、どういう結果だったか
  - フェーズを踏まない場合は `design.md` を「判定ロジック・データ構造・手順」の記述に充ててよい。
- **繰り返す運用作業は、再現用の手順書（`runbook.md`）と成果物の所在を必ず残す。**
  個人情報を含む成果物は `.kiro/specs/<task-id>/outputs/`（git管理外）に置く。
- 「ドキュメント更新は作業の都度・常時行う」ことを原則とし、作業完了後にまとめて書く運用にしない。

---

## タスクディレクトリ構成

```
.kiro/specs/<task-id>/
  ├── spec.json                       … cc-sdd管理ファイル（自動生成、承認状態の正本）
  ├── requirements.md                 … 要件（EARS形式）
  ├── design.md                       … 設計（アーキ・Mermaid・ファイル構成・技術要件/制約チェック節）
  ├── tasks.md                        … タスク一覧
  ├── agreement-log.md                … 合意形成記録（壁打ち結果・決定事項）
  ├── test-results.md                 … 実行テスト記録
  └── integration-test-checklist.md   … 結合試験項目（人間確認用）
```

> `docs/specs/<task-id>/` は `.kiro/specs/` 統一（2026-07〜）前の既存タスクのみに残る。
> 新規タスクは作らず、必ず `.kiro/specs/<task-id>/` を使う。

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
他のリポジトリへ流用する際は `npx github:<org>/sdd_base_template install`（または `init`）で展開してください。`docs/sdd/` 配下はリポジトリ非依存です。

リポジトリ固有情報は `docs/architecture/` に分離されています。
