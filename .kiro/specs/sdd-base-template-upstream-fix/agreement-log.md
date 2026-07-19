# 合意形成記録: sdd_base_template 上流改修（Part A/B/C）への移行とPR #20クローズ

| 項目 | 内容 |
|---|---|
| タスクID | `sdd-base-template-upstream-fix` |
| 作成日 | 2026-07-01 |
| 対象リポジトリ | `cyclox2_docker`（本記録）／実装対象は `sdd_base_template`（上流・別リポジトリ、`/Users/kyamady/workspace/sdd_base_template`、GitHub: `kyamady-dorokid/sdd_base_template`） |
| 関係者 | KYamada / Claude Code |
| 性質 | 非コーディング作業（調査・意思決定・引き継ぎ）。CLAUDE.mdルール9に基づき記録 |

---

## 壁打ち概要

cyclox2_docker で SDD 運用中に、独自ルール「非コーディング作業のドキュメント化（重要）」
（`docs/sdd/workflow.md`）が、上流テンプレート `sdd_base_template` の `init.sh` による
`docs/sdd/` 配下の無条件上書きで一度消失し、cyclox2_docker 側で場当たり的に復活させた
（PR #20, branch `chore/sdd-base-update`, commit `145ab68`）。

これを踏まえ、上流 `sdd_base_template` に対して以下3点の改修が前セッションで承認済みだった
（Part A: ルール反映 / Part B: 安全な更新機構 / Part C: agreement-log.md 必須化）。

本セッションでは、
1. Part Cの前提だった「成果物の置き場所規約（`.kiro/specs/` か `docs/specs/` か）」の未解決ブロッカーを
   ユーザーに再確認し、**上流の `.kiro/specs/<id>/` 一元化を採用**することで解消した。
2. 実装対象が `cyclox2_docker` とは無関係の別リポジトリであるにもかかわらず、本セッションが
   `cyclox2_docker` のgit worktreeに固定されていることが判明。`EnterWorktree` は同一リポジトリ内の
   worktree切替専用で、無関係な別リポジトリ（`sdd_base_template`）へは使用できないことを確認した。
3. ユーザーの判断により、**実装は本セッションでは行わず、`sdd_base_template` 直下で新しいセッションを
   開始して引き継ぐ**こととした。
4. `cyclox2_docker` の PR #20 は、内容を精査した結果「upstreamに実装されるべき内容」が
   Part A1 の範囲と完全に一致すると判断し、**クローズ**（内容は本記録で引き継ぎ済み）とした。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | agreement-log.md 等SDD成果物の置き場所規約は、上流の `.kiro/specs/<id>/` 一元化を採用する（`docs/specs/` は使わない） | 上流 `sdd_base_template` の `main`（2026-07-01時点 commit `75d12e0`）は既に `.kiro/specs/` 一元化方針が確定・運用中であり、これに逆らうより追随する方が長期的に整合性が高い。cyclox2_docker自身も `point-sim-2025-26` で `.kiro/specs/`（requirements/design/tasks）と `docs/specs/`（agreement-log等）に分裂している実例があり、一元化の必要性が裏付けられた | 2026-07-01 |
| 2 | Part A/B/C の実装は本セッション（cyclox2_docker worktree）では行わず、`sdd_base_template` 直下の新セッションへ引き継ぐ | 実装対象が別リポジトリであり、本セッションのgit worktree固定を解除する手段がない。絶対パス操作での続行も可能だが、ユーザーが新セッション開始を選択 | 2026-07-01 |
| 3 | cyclox2_docker PR #20（`chore/sdd-base-update`）はクローズする。ブランチは削除しない | 内容精査の結果、PRの実質的な新規価値は「非コーディング作業のドキュメント化」節の復活のみで、これは Part A1 として上流で恒久対応する。他の差分（Codex連携ファイル・SDD-BASEブロック・汎用化済みルール文言）は既に上流payloadに存在する内容の再取込みであり、上流修正後に改めて安全な形で取り込み直す方針とした | 2026-07-01 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| PR #20 の内容をそのまま維持し、上流改修を待たずマージする | 独自ルールの永続化にならず、次回の再init/updateで再度消失するリスクが残るため却下 |
| `.kiro/specs/` 一元化を採用せず `docs/specs/` を維持し上流に押し返す | 上流は既に一元化を確定運用しており、押し返すコストの方が大きいと判断し却下（前セッションで提示した3択のうち採用） |

---

## フェーズゲート承認記録

本タスクはコーディングを主体としないため、requirements/design/tasksの段階承認は対象外。
上記「決定事項」がゲートに相当する。

---

## 引き継ぎブリーフ（`sdd_base_template` 直下の新セッション向け）

> 新セッションはこの節を読めば、cyclox2_docker側での調査・decisionをやり直さずに
> `sdd_base_template` でのPart A/B/C実装に直接着手できることを意図している。

### 0. 実装対象・遵守事項

- 実装は必ず `/Users/kyamady/workspace/sdd_base_template`（独立クローン、リモート
  `git@github.com:kyamady-dorokid/sdd_base_template.git`、デフォルトブランチ `main`）で行う。
- **`main` への直接コミット禁止。** 必ずブランチを切ってpush→PR作成（このリポジトリ自身の
  `docs/sdd/rules/branching-policy.md` と同じ運用）。
- 本タスク自体もSDDドッグフーディング対象。記録は `sdd_base_template` 自身が採用した規約
  （`.kiro/specs/<task-id>/`、例: `part-abc-agreement-log-and-safe-update` 等）に残すこと。
- `kiro-*` スキルや運用ルールを更新する場合、`.claude/skills/` と `.agents/skills/` を同一変更で揃える。
  開発ルールを変える場合、`CLAUDE.md` と `AGENTS.md`（このリポジトリ自身の、`payload/` 配下ではなく
  ルート直下にあるものも含め要確認）を同一変更で揃える。整合確認: `diff -qr .claude/skills .agents/skills`。

### 1. PR #20（cyclox2_docker、クローズ済み）の内容精査結果

コミット `145ab68`「chore(sdd): SDDベースを更新しCodex連携を追加（独自ルールは保持）」、27ファイル変更。

1. **Codex連携ファイル一式**（`.agents/skills/*/agents/openai.yaml`×17、`.codex/agents/spec-reviewer.toml`）、
   **CLAUDE.md/AGENTS.md の SDD-BASE ブロック更新**、**ルール文言の汎用化**
   （`docs/sdd/rules/commit-policy.md` の `scope例: docker,cyclox2web,cyclox2res-sys,sdd,architecture`
   → `core,api,ui,db,sdd,docs`、`docs/sdd/templates/tech-requirements.md` の `PHPバージョン制約`
   → `言語ランタイムのバージョン制約` 等）
   → **これらは既に `sdd_base_template` 現行payloadに存在する内容の再取込みであり、移行対象なし**。
2. **`docs/sdd/workflow.md` の「非コーディング作業のドキュメント化（重要）」節の復活**
   （コミットメッセージ: 「上書きで消えたため復活（※恒久化には上流 sdd_base_template への反映が必要）」）
   → **これが Part A1 の対象そのもの。** 原文は次のとおり（cyclox2_docker
   `docs/sdd/workflow.md` より、`.kiro/specs/` 一元化前提で読み替えて上流へ反映すること）:

   ```markdown
   ## 非コーディング作業のドキュメント化（重要）

   コード改修を主体としない作業（運用・データ処理・DB操作・調査・移行など）は、
   「壁打ち→設計→コーディング」という開発フェーズを踏まないことがある。
   **フェーズを踏まない作業であっても、進捗・合意・判定根拠・実行結果のドキュメント化は省略しない。**

   - 省略してよいのは「コーディングを前提とした承認ゲート（requirements/design/tasksの段階承認やTDD）」
     であり、**記録義務ではない**。
   - `docs/specs/<task-id>/` を作成し、少なくとも次を常時更新する:
     - `agreement-log.md` … 依頼内容・合意・決定（理由・日付）・却下/保留事項・承認記録
     - 実行結果（`test-results.md` 等）… 何をどう検証し、どういう結果だったか
   - 必要に応じて `.kiro/specs/<task-id>/`（requirements/design/tasks）も併せて残す。
     非コーディング作業では design を「判定ロジック・データ構造・手順」の記述に充ててよい。
   - **繰り返す運用作業は、再現用の手順書（`runbook.md`）と成果物の所在を必ず残す。**
     個人情報を含む成果物は `docs/specs/<task-id>/outputs/`（git管理外）に置く。
   - 「ドキュメント更新は作業の都度・常時行う」ことを原則とし、作業完了後にまとめて書く運用にしない。
   ```

   → 上流への反映時は `docs/specs/<task-id>/` を `.kiro/specs/<task-id>/` に読み替え、
   既に上流が単一レイアウトへ統合済みのため「必要に応じて `.kiro/specs/` も併せて残す」という
   二重レイアウト前提の文言は不要（`.kiro/specs/<id>/` に一本化されている上流の記述と統合すること）。
3. `.kiro/specs/.gitkeep` / `docs/specs/.gitkeep` 新規作成 → 現行cyclox2_dockerの分裂レイアウトの副産物。
   上流の `.kiro/specs/` 一元化完了後、cyclox2_docker側の追随移行時に解消される想定（下記「将来課題」）。

### 2. Part A: ルール反映（承認済みスコープ）

- **A1**: 上記1-2の「非コーディング作業のドキュメント化（重要）」節を
  `payload/overlay/docs/sdd/workflow.md` に反映（`.kiro/specs/<id>/` 一元化前提で統合。
  上流の現行 `workflow.md` には存在しないことを確認済み＝非衝突）。
- **A2**: cyclox2_docker独自の `docs/sdd/rules/security-policy.md`（秘密情報のgit非ハードコード方針、
  全文は下記4節に転記）を汎用化して4本目のルールファイルとして
  `payload/overlay/docs/sdd/rules/security-policy.md` に追加（branching/commit/testing-policyと並列）。
  汎用化例: `MYSQL_ROOT_PASSWORD` → `DB_PASSWORD` 的な一般名、`cyclox2_mysql` コンテナ名 → プレースホルダ、
  Docker固有IP例 → 「開発用固定プライベートIP」的な一般表現に置換（原文は既にある程度汎用化されているため
  差分は小さい見込み）。
- **A3**: `KNOWN_GOOD_CCSDD_VERSION` は現状 (3.0.2) のまま変更しない
  （2026-07-01時点で `sdd_base_template/payload/KNOWN_GOOD_CCSDD_VERSION` の値は `3.0.2` であることを確認済み）。

### 3. Part B: 安全な更新機構（承認済みスコープ＋設計ドラフト）

**要件（承認済み）**: 既に運用中（テンプレート適用済み）のリポジトリに対し、上流テンプレートの更新を
安全に反映する仕組み。方式は「3-wayマージ+lock」ハイブリッド。

**設計ドラフト（本セッションで検討・未実装。新セッションで妥当性を再確認の上、詳細設計として確定させること）**:

- **lockファイル**: `.kiro/sdd-base.lock`（対象リポジトリ側に作成・コミット）。
  JSONではなくフラットな行指向形式を推奨（bashで完結する既存実装スタイル
  `payload/scripts/init.sh` / `validate.sh` との一貫性のため）。例:
  ```
  template_commit=<sdd_base_template実行時のgit commit SHA>
  template_repo=<git remote url>
  file:docs/sdd/workflow.md:<sha256>
  file:docs/sdd/rules/branching-policy.md:<sha256>
  block:CLAUDE.md:SDD-BASE:<sha256-of-block-content>
  block:AGENTS.md:SDD-BASE:<sha256-of-block-content>
  ```
  `template_commit` は `bin/cli.js` から呼び出す `payload/scripts/init.sh`（および新設 `update.sh`）内で
  `git -C "$PKG_ROOT" rev-parse HEAD` により取得可能（`npx github:org/repo` 経由でも `.git` が
  保持されるかは要検証。取得不可の場合のフォールバックとして固定リポジトリURL定数を用意すること）。
- **スナップショット**: `.kiro/sdd-base-snapshot/`（対象リポジトリ側にコミットして保持）。
  適用時点の `payload/overlay/` 相当の内容を複製し、将来の3-wayマージの「base」として使う。
  ネットワーク経由でテンプレートの過去コミットを都度re-cloneする代替案も検討したが、
  ネットワーク依存・履歴改変リスクを避けるため**ローカル永続スナップショット案を採用**（リポジトリが
  ある程度肥大化するトレードオフは許容）。
- **マージ方式**:
  - `docs/sdd/**` のような単独管理ファイルは全体を `git merge-file` で3-wayマージ
    （current=ローカルファイル, base=スナップショット, other=新テンプレート版）。
  - `CLAUDE.md`/`AGENTS.md` の `SDD-BASE:START`〜`END` 等マーカーブロック、および
    `payload/validation/patches/*.sh` が注入するマーカーブロック（`kiro-impl/SKILL.md` の
    `SDD-OVERLAY:IMPL-POLICY` 等）は、ブロック部分だけを抽出して3-wayマージし、結果を
    マーカー間に差し戻す（周囲のプロジェクト固有内容には触れない）。
  - `.gitignore` スニペットは追記専用（欠けている行だけ追加、コンフリクト概念なし）。
  - ローカル未変更ファイル（lockのhashと現在のhashが一致）は新版でそのまま更新。
  - ローカルで変更されているファイルは3-wayマージを試行。**クリーンマージは適用**（ただし人間へのレポートには
    必ず記載）。**コンフリクトは `<file>.new` ＋ コンフリクトレポートを出力し、既存ローカルファイルには
    一切手を加えない（サイレント上書き厳禁）**。
  - テンプレートに存在しないローカル専用ファイル（`.kiro/specs/`, `.kiro/steering/`, プロジェクト固有の
    `docs/architecture/` 等）は管理対象外として完全不可侵。
  - 上流で削除されたファイルは自動削除せず、レポートで「上流で削除された」旨のみ報告（削除は破壊的操作）。
- **実行後**: 必ず人間に差分・変更サマリを提示する（`.kiro/sdd-base-update-report.md` 等）。自動コミットはしない。
- **CLIコマンド名**: 既存の `bin/cli.js` には `update`（テンプレ開発者が自分のclone環境で
  `git pull --ff-only` する、全く別の意味のコマンド）が既に存在するため、**名称衝突を避けること**。
  新設コマンドは `sync` 等の別名を推奨（例: `npx github:.../sdd_base_template sync [--yes]`）。
  スクリプトファイル自体は `payload/scripts/update.sh`（または `sync.sh`）として新設。
- **検証**: `payload/validation/checks.md` にlock整合性・ローカル変更保持のチェック項目を追加。
  READMEの「その他の使い方」節にも新コマンドの説明を追加。
- 上流マージ後、ローカルスキルミラー（`~/.claude/skills/sdd-init`）を再同期する
  （`bin/cli.js` の `install` を参照）。

### 4. Part C: agreement-log.md 必須化（承認済みスコープ）

`/kiro-*` フルフロー使用時に `agreement-log.md` が自動生成されない問題を解消する（新セッションで
`.claude/skills/kiro-spec-init/SKILL.md` を確認したところ、`spec.json` と `requirements.md` のみを
生成し `agreement-log.md` は生成しないことを実際に確認済み＝バグは実在）。

- **Layer 1**: `payload/overlay/snippets/CLAUDE.sdd.md` / `AGENTS.sdd.md` / `docs/sdd/workflow.md` は
  既に「合意は `agreement-log.md` に記録」と明記済みだが、「ファイルとして実在させる」ことを
  より明示的に補強する一文を追加する程度で足りる見込み（過剰な書き換えは不要）。
- **Layer 2**: 新規の冪等パッチスクリプト `payload/validation/patches/ensure-agreement-log.sh` を作成し、
  `kiro-spec-init` の SKILL.md（`.claude/skills/kiro-spec-init/SKILL.md` と
  `.agents/skills/kiro-spec-init/SKILL.md` の両方）に、agreement-logファイルが無ければ
  `docs/sdd/templates/agreement-log.md` からテンプレート生成するステップをマーカー注入する。
  既存の類似パッチ `payload/validation/patches/fix-impl-team-policy.sh`
  （`SDD-OVERLAY:IMPL-POLICY` マーカーで冪等追記する方式）をそのまま踏襲すればよい。
- `payload/validation/checks.md` の C2 節（既知パッチ一覧）に本パッチを追加。

### 5. `sdd_base_template` の現状構造（2026-07-01時点、`main` commit `75d12e0`）

主要ファイルと内容の要点（新セッションでの再調査を省略できるよう記録）:

- `payload/overlay/docs/sdd/workflow.md`（167行）: 「2つの進め方」「Tier（S/L）」
  「タスクディレクトリ構成（単一レイアウト・`.kiro/specs/<id>/`）」を既に規定済み。
  「非コーディング作業のドキュメント化」節は**存在しない**（A1で新規追加）。
- `payload/overlay/snippets/CLAUDE.sdd.md` / `AGENTS.sdd.md`: 内容は同一（Claude/Codexパリティ）。
  「必ず守ること」9項目、「ベースルールの所在」リンク一覧（ここに security-policy.md へのリンクを
  A2で追加）、「エージェント整合」節あり。
- `payload/validation/checks.md`: A〜Fのチェックリスト。C2節が「独自ポリシーパッチの注入」
  （`fix-impl-team-policy.sh`, `fix-design-template.sh` の2つが登録済み。Part Cで3つ目を追加）。
  E2節が「記録レイアウト統一」（`.kiro/specs/<id>/` 集約、`docs/specs/` 残存禁止）を規定済み。
- `payload/scripts/init.sh`（186行）: cc-sdd取得→検証(pre)→パッチ適用→overlay適用→検証(post) の6ステップ。
  overlay適用ステップ（[5/6]）で `docs/sdd/` 全体コピー、`.kiro/specs/.gitkeep` 作成、
  CLAUDE.md/AGENTS.mdへのマーカー注入、`.gitignore` 追記を行う。**Part Bの `template_commit` 記録・
  lock/snapshot書き込みはこのステップに追加することになる見込み**。
- `payload/validation/patches/`: `fix-impl-team-policy.sh`（`kiro-impl/SKILL.md` にマーカー追記）、
  `fix-design-template.sh`（`.kiro/settings/templates/specs/design.md` にマーカー追記）が既存。
  いずれも「引数=repo_root、冪等（マーカー検出でスキップ）、末尾追記のみ」という共通パターン。
  Part Cの新規パッチもこのパターンを踏襲する。
- `bin/cli.js`: サブコマンド `install`（個人スキル設置）/ `init`（テンプレ展開）/
  `validate`（検証のみ）/ `update`（**テンプレ開発者のclone環境でのgit pull。Part Bの新機能とは別物**）。
- `payload/overlay/docs/sdd/templates/agreement-log.md`: cyclox2_dockerのものとほぼ同一構成
  （タスクID/作成日/関係者 → 壁打ち概要 → 決定事項 → 却下・保留事項 →
  フェーズゲート承認記録[`spec.json`が正、との注記あり] → 変更履歴）。
- リポジトリ直下に `docs/specs/env-boundary-policy/`（旧レイアウトのメタ記録、`.kiro/specs/` 統合前の
  遺構）と `.kiro/specs/{existing-guard-default-overwrite,license-and-readme-interactive,
  quickstart-existing-guard,readme-agents-and-dedup}/`（新レイアウト）が混在している。
  **これは `sdd_base_template` 自身の開発記録であり、今回のPart A/B/C対応スコープ外**
  （触れる場合は別途要相談）。

### 6. security-policy.md 原文（A2の汎用化元）

`cyclox2_docker/docs/sdd/rules/security-policy.md` の全文（汎用化してA2として追加する）:

```markdown
# 秘密情報の取り扱いポリシー（ハードコード禁止）

> **git 管理対象となる全てのファイルに、秘密情報を平文でハードコードしない。**
> ドキュメント・スクリプト・設定・コメント・コミットメッセージ・SDD成果物すべてに適用する。

## 1. ハードコード禁止の対象（これに限らない）

以下は代表例。**列挙にない情報でも「漏れると不正利用・追跡・侵入につながるもの」は秘密情報として扱う。**

- **認証情報**: アカウント名とパスワードの組、DBクレデンシャル（user/password）、管理者パスワード。
- **APIキー・トークン**: APIキー、アクセストークン、リフレッシュトークン、OAuth client secret、Webhook URL（トークン入り）、署名シークレット。
- **鍵・証明書**: SSH秘密鍵、TLS/SSL秘密鍵、GPG秘密鍵、証明書のパスフレーズ、暗号化キー・ソルト、セッションシークレット。
- **クラウド資格情報**: AWSアクセスキー/シークレット、GCPサービスアカウントJSON、Azure接続文字列等。
- **接続情報（実値）**: 本番・内部の実IPアドレス、実ホスト名/FQDN、非公開ポート、内部URL/エンドポイント、資格情報を含む接続文字列（DSN/JDBC URL等）。
- **メール・通知系**: SMTP認証情報、Slack/Webhookトークン。
- **個人情報（PII）**: 氏名・メール・電話・住所・会員ID等、個人を特定できる情報（※PIIは本ポリシーに加え、再生成可能な成果物として `docs/specs/<task-id>/outputs/`（git管理外）に隔離する）。
- **ライセンス・課金**: ライセンスキー、決済関連シークレット。

## 2. 守るべきルール

1. 上記を **git 追跡ファイルに平文で書かない**（本番・開発・テストを問わない）。
2. 値は **`.env` / 環境変数 / シークレットマネージャ** から注入する。`.env` 等の実値ファイルは `.gitignore` で除外する。
3. ドキュメント・サンプルでは **プレースホルダ**（`<YOUR_PASSWORD>`, `${MYSQL_ROOT_PASSWORD}`）か **参照元のキー名のみ**を記載する。
   - 例（OK）: 「パスワードは `.env` の `MYSQL_ROOT_PASSWORD` を使用」
   - 例（NG）: `mysql -u root -p<実際のパスワード>`（平文パスワードを直書きしない）
4. コマンド例は **環境変数経由**にする。
   - 例: `export MYSQL_PWD="<.env の値>"; docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root ...'`
5. 実IP/ホストは、ドキュメント上は役割名・変数（`DB_HOSTNAME` 等）で示し、実値は環境設定に置く。
   - 開発用の固定プライベートIP（例: docker内部ネットワーク `172.x`）の記載可否はプロジェクト判断とするが、**本番の実IP/FQDNは記載しない**。
6. コミット前に秘密情報が含まれていないか確認する（`git grep` 等での自己点検を推奨）。
7. 誤ってコミットした場合は、**履歴からの除去（amend/rebase/force-push 等）と、可能なら当該シークレットのローテーション**を行う。

## 3. 自己点検の例

```bash
# 既知パターンの混入チェック（コミット前）
git grep -nE 'password|passwd|-p[A-Za-z0-9]|secret|api[_-]?key|token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY'
```
```

A2でのリポジトリ非依存化の指針: `MYSQL_ROOT_PASSWORD`/`MYSQL_PWD`/`cyclox2_mysql` はコマンド例2箇所
（2節-3, 2節-4）のみに登場。汎用名（例: `DB_PASSWORD`, `<db_container>`）に置換すること。
「開発用の固定プライベートIP」の記述は既に汎用表現になっているため変更不要。

### 7. 遵守事項の再掲（Part Bのみ特記）

Part Bの3-wayマージ機構は破壊的操作（ローカルファイルの上書き）を伴いうるため、設計・実装とも
「サイレント上書き厳禁」を徹底し、必ず差分提示→人間確認のステップを挟むこと。

### 8. 将来課題（今回スコープ外・メモのみ）

上流マージ後、`cyclox2_docker` 自体を `docs/specs/` → `.kiro/specs/` 一元化へ追随移行する必要がある。
`point-sim-2025-26` が現在 `.kiro/specs/point-sim-2025-26/`（requirements/design/tasks）と
`docs/specs/point-sim-2025-26/`（agreement-log/tech-requirements/test-results等）に分裂している実例が
既に存在する（2026-07-01時点で確認済み）。この移行は本タスクのスコープ外であり、別タスクとして
改めて着手すること。

---

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-01 | 初版作成。`.kiro/specs/` 一元化採用の決定、PR #20クローズの決定、`sdd_base_template` 新セッションへの引き継ぎブリーフを記録 | Claude Code |
