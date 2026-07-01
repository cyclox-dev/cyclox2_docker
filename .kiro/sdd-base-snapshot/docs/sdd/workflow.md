# SDD ワークフロー定義

このドキュメントはリポジトリ非依存のベースルールです。
cc-sdd（`/kiro-*` コマンド群）の上に本プロジェクト固有の運用を重ねたものです。

---

## 2つの進め方（同一パイプライン・2つの入口）

開発の始め方は2通りありますが、**どちらも同じ1本のSDDパイプラインを通り、適用ルール・成果物・
出力先は完全に同一**です。違うのは「人間がコマンドを打つか／エージェントに任せるか」だけです。

| 入口 | 始め方 | 向き |
|---|---|---|
| **軽量（自然言語SDD）** | 「〇〇を作りたい。簡単な要件定義とプランニングから始めて」と会話で指示。スラッシュコマンド不要 | 小〜中規模 |
| **フルフロー（kiroコマンドSDD）** | `/kiro-discovery "<やりたいこと>"` から `/kiro-spec-*` → `/kiro-impl` を明示実行 | 中〜大規模 |

- **軽量入口**でも、エージェントは下記「基本の流れ」と等価のフェーズを実行し、**同じ成果物を
  `.kiro/specs/<id>/` に残す**（task-id はエージェントが決める）。kiro-spec-* は自動発火可能なので
  内部的に利用してよい。
- **どちらの入口でも以下は必須**: 人間の承認ゲート / TDD / 自動コミット禁止 / `main` 直禁止・ブランチ→PR /
  記録の `.kiro/specs/<id>/` 集約。
- 入口で振る舞いは変えない。**変えてよいのは儀式の深さ（下記 Tier）だけ**で、Tier は規模で選ぶ。

### Tier（規模ダイヤル）

| Tier | 対象 | 要件/設計 | spec.json 承認 | steering | 実装ループ | 共通ガードレール |
|---|---|---|---|---|---|---|
| **S（小）** | バグ修正・小改修 | `.kiro/specs/<id>/` に簡潔版（EARS は任意） | 任意 | 任意 | main 文脈の TDD | 承認ゲート/TDD/コミット・ブランチ方針/記録 **必須** |
| **L（中〜大）** | 新機能・複数機能 | フル EARS / 設計 | **必須・機械強制** | 推奨 | `/kiro-impl`（独立レビュー編成） | 同上 **必須** |

Tier は入口に依存しない。軽量入口でも Tier L を選べるし、コマンド入口でも Tier S 相当に省略してよい。

---

## 人間が入力するもの（この順に進めればよい）

どちらの入口でも、人間は以下を上から順に入力していけば進む。`<...>` は自分の言葉に置き換える。

### 軽量（自然言語SDD）

1. **着手**: 「`<やりたいこと>`。簡単な要件定義とプランニングから始めて」
2. **要件/設計/タスクの確認**: 提示された内容を読み、合意できたら「この方針でOK。実装を進めて」
   （直したい点があればその場で指摘 → 反映を繰り返す。承認するまで実装に進ませない）
3. **実装・テストの確認**: TDD 実装とテスト結果が提示される。問題なければ「結合試験チェックリストを出して」→ 人間が手動確認
4. **コミット**: 区切りで提案される。確認して「この内容でコミットして」（`main` 直禁止・ブランチ→PR）

### フルフロー（kiroコマンドSDD）

1. `/kiro-discovery "<やりたいこと>"`
2. `/kiro-spec-requirements <id>` → レビュー → 「承認」
3. `/kiro-spec-design <id>` → レビュー → 「承認」
4. `/kiro-spec-tasks <id>` → レビュー → 「承認」（ここで実装可否を確認）
5. `/kiro-impl <id>`（独立レビュー付き。`main` 直禁止・コミットは提案）
6. `.kiro/specs/<id>/integration-test-checklist.md` を人間が確認（結合試験）
7. 提案されたコミットを確認して実行（ブランチ→PR）

> どちらも「承認ゲートで止まる → 人間が承認 → 次へ」が基本リズム。承認なしに実装・コミットへ進めない。

---

## 基本の流れ

```
開発タスク依頼（軽量入口=会話 / フルフロー入口=/kiro-discovery）
    │
    ▼
【フェーズ0: 把握・プランニング】
  軽量: 会話で課題・方針・スコープを壁打ち
  フル: /kiro-discovery <idea> → brief.md + roadmap.md 生成
  → 内容を人間と合意形成（agreement-log.md に記録）
    │
    ▼
【フェーズ1: 仕様化】 ← 承認ゲート①（要件）
  軽量: エージェントが要件を .kiro/specs/<id>/requirements.md に起こす
  フル: /kiro-spec-init → /kiro-spec-requirements → requirements.md
  ★ 人間レビュー・合意 → agreement-log.md に記録（承認状態は spec.json が正）
    │
    ▼
【フェーズ1続き: 設計】 ← 承認ゲート②（設計）
  → .kiro/specs/<id>/design.md（技術要件・制約チェック節を含む）
  ★ 人間レビュー・合意 → agreement-log.md に追記
    │
    ▼
【フェーズ1続き: タスク分解】← 承認ゲート③（実装前確認）
  → .kiro/specs/<id>/tasks.md
  ★ ドキュメント完成 → 人間に確認を求める（いきなり実装しない）
  ★ 人間から「進めて」の承認を得る
    │
    ▼
【フェーズ2: 実装（TDD）】
  テスト項目を test-results.md に先行記載（仕様ベース・RED）
  テストコードを先に実装（RED）→ 実装コードで GREEN
  軽量: main 文脈の TDD / フル: /kiro-impl（独立レビュー付き）
  → .kiro/specs/<id>/test-results.md に記録
  → .kiro/specs/<id>/integration-test-checklist.md を作成
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
- **承認状態の正は `spec.json`**（`approvals.{requirements,design,tasks}.approved`）。agreement-log には
  「なぜそう決めたか」の経緯を残し、承認ブール値を二重管理しない。

---

## タスクディレクトリ構成（単一レイアウト）

入口に関わらず、1タスクの成果物・記録はすべて `.kiro/specs/<id>/` に集約する。
`docs/specs/` は使わない（廃止）。

```
.kiro/specs/<id>/
  ├── spec.json              … cc-sdd管理。承認状態の唯一の正
  ├── brief.md               … discovery（課題/方針/スコープ）※フルフロー
  ├── requirements.md        … 要件（EARS形式 / Tier S は簡潔版）
  ├── design.md              … 設計（アーキ・Mermaid・ファイル構成 ＋ 技術要件・制約チェック節）
  ├── tasks.md               … タスク一覧（+ Implementation Notes）
  ├── research.md            … gap分析（任意 / /kiro-validate-gap）
  ├── agreement-log.md       … 合意形成記録（決定理由・却下/保留の経緯）
  ├── test-results.md        … 実行テスト記録
  └── integration-test-checklist.md … 結合試験項目（人間確認用）

.kiro/steering/              … 永続プロジェクトメモリ（product/tech/structure ほか）
```

- 記録テンプレートは `docs/sdd/templates/` を参照（雛形ライブラリ）。実体は上記 `.kiro/specs/<id>/` に作る。
- 技術要件は独立ファイルにせず `design.md` の各節（Technology Stack / Testing Strategy /
  Existing Architecture / Modified Files ＋ 技術要件・制約チェック）に一本化する。

---

## 非コーディング作業のドキュメント化（重要）

コード改修を主体としない作業（運用・データ処理・DB操作・調査・移行など）は、
「壁打ち→設計→コーディング」という開発フェーズを踏まないことがある。
**フェーズを踏まない作業であっても、進捗・合意・判定根拠・実行結果のドキュメント化は省略しない。**

- 省略してよいのは「コーディングを前提とした承認ゲート（requirements/design/tasks の段階承認や TDD）」
  であり、**記録義務ではない**。
- 記録先は他の作業と同一の `.kiro/specs/<id>/`。少なくとも次を常時更新する:
  - `agreement-log.md` … 依頼内容・合意・決定（理由・日付）・却下/保留事項・承認記録
  - 実行結果（`test-results.md` 等）… 何をどう検証し、どういう結果だったか
- 非コーディング作業では `design.md` を「判定ロジック・データ構造・手順」の記述に充ててよい。
- **繰り返す運用作業は、再現用の手順書（`runbook.md`）と成果物の所在を必ず残す。**
  個人情報を含む成果物は `.kiro/specs/<id>/outputs/`（git 管理外）に置く。
- 「ドキュメント更新は作業の都度・常時行う」ことを原則とし、作業完了後にまとめて書く運用にしない。
- **`agreement-log.md` はファイルとして実在させる。** 会話内での合意だけで済ませず、必ず
  `.kiro/specs/<id>/agreement-log.md` を作成・更新する（雛形は `docs/sdd/templates/agreement-log.md`）。

---

## フェーズ対応コマンド早見表（フルフロー入口）

| フェーズ | コマンド | 出力先 |
|---|---|---|
| 把握・振り分け | `/kiro-discovery <idea>` | `.kiro/specs/<id>/brief.md`, `roadmap.md` |
| 仕様初期化 | `/kiro-spec-init <description>` | `.kiro/specs/<id>/` |
| 要件定義 | `/kiro-spec-requirements <id>` | `requirements.md` |
| 設計 | `/kiro-spec-design <id>` | `design.md` |
| タスク分解 | `/kiro-spec-tasks <id>` | `tasks.md` |
| 実装（TDD） | `/kiro-impl <id>` | コード + `test-results.md` |
| 進捗確認 | `/kiro-spec-status <id>` | - |

> 軽量入口では上記コマンドを明示的に打たなくても、エージェントが等価の処理を行い同じ成果物を残す。

---

## ベースルール管理

このドキュメントおよび `docs/sdd/` 配下は **リポジトリ非依存のベースルール** です。
他のリポジトリへ流用する際は `npx github:<org>/sdd_base_template install`（または `init`）で展開してください。`docs/sdd/` 配下はリポジトリ非依存です。

リポジトリ固有情報は `docs/architecture/` に分離されています。
