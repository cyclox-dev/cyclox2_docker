# cyclox2_docker

自転車競技管理システム **Cyclox2** の Docker 開発環境リポジトリ。

このリポジトリは Docker 環境・各種設定ファイル・SDD（Spec-Driven Development）運用ルールを管理します。
**アプリ本体のコードは含まず**、2つの git submodule として参照します。

| サービス | 役割 | 技術 | submodule |
|---|---|---|---|
| `cyclox2_svr` | メイン管理アプリ（Cyclox2） | CakePHP 2.x + Apache/PHP | `cyclox2_svr/cyclox2/`（cyclox-dev/cyclox2web） |
| `cyclox2ressys_svr` | 成績閲覧アプリ（Result System） | CodeIgniter 3.1.x | `cyclox2ressys_svr/cyclox2res_sys/`（cyclox-dev/cyclox2res-sys） |
| `cyclox2_mysql` | データベース | MySQL 5.7 | － |
| `cyclox2_phpmyadmin` | DB 管理 UI | phpMyAdmin | － |

---

## セットアップ手順

> 詳細・トラブルシュートは [docs/architecture/local-setup.md](docs/architecture/local-setup.md) を参照。

### 1. リポジトリのクローン

```bash
git clone git@github.com:cyclox-dev/cyclox2_docker.git
cd cyclox2_docker
```

### 2. サブモジュール（アプリ本体）の取得 ※必須

```bash
git submodule update --init --recursive
```

> `cyclox-dev` org への SSH アクセス権が必要です。このステップを飛ばすと `cyclox2_svr/cyclox2/` が空のままコンテナが起動し、アプリが動作しません。

### 3. MySQL データ準備

```bash
# .gitignore 対象のため手動作成が必要
mkdir -p cyclox2_mysql/var/mysql cyclox2_mysql/var/dump
```

本番環境などからエクスポートした SQL ダンプを `cyclox2_mysql/var/dump/` に配置します。

### 4. コンテナのビルドと起動

```bash
docker-compose up -d --build

# 起動確認（4コンテナが Up になること）
docker-compose ps -a
```

### 5. データベースのリストア

`cyclox2_mysql/var/dump/` は コンテナ内 `/var/tmp` にマウントされます。

```bash
docker-compose exec cyclox2_mysql bash

# コンテナ内で実行（<DB_USER> / dump_file.sql は実際の値に置き換え）
mysql -u <DB_USER> -p cyclox2 < /var/tmp/dump_file.sql
```

> 接続ユーザー・パスワードは `docker-compose.yml` の `MYSQL_ROOT_PASSWORD` 等の環境変数を参照してください（README には記載しません）。`-p` のみ指定すると対話的にパスワード入力を求められます。

---

## アクセス先（開発環境）

| サービス | URL |
|---|---|
| Cyclox2（管理アプリ） | http://localhost/ |
| phpMyAdmin | http://localhost:4040/ |
| Cyclox2 Result System | http://localhost:8081/ |
| MySQL | localhost:3306 |

## コンテナ操作

```bash
docker-compose down                      # 停止
docker-compose logs -f cyclox2_svr       # ログ確認
docker-compose exec cyclox2_svr bash     # コンテナに入る
```

---

## このリポジトリでの開発の進め方（SDD / Claude Code）

このリポジトリは **Kiro スタイルの Spec-Driven Development（SDD）** を採用しており、AI エージェント（Claude Code / Codex）が**プロジェクト固有のルールに従って動作**します。ルールは [CLAUDE.md](CLAUDE.md)（Claude Code 用）と [AGENTS.md](AGENTS.md)（Codex 用）に定義され、両者は常に同期されます。

### Claude はどう動くか（SDD ルールの概要）

エージェントは思いつきで実装を始めず、以下の規律に従います:

- **3フェーズ承認ワークフロー**: `要件定義 → 設計 → タスク分解 → 実装` の順で進め、**各フェーズで人間の承認**を得てから次へ進みます（成果物は `.kiro/specs/<task-id>/` に蓄積）。
- **ドキュメント完成後、いきなり実装しない**。承認を得てから実装に着手します。
- **テストは実装とセット（TDD・テスト先行）**。
- **`main` への直接コミット禁止**。必ずブランチを切って作業し、push 後に PR を発行します。コミットは自動では行わず、区切りで人間に確認します。
- **合意内容・技術要件・テスト結果を文書化**して `docs/specs/<task-id>/` に記録します。
- 該当しそうなスキル（`kiro-*`）があれば必ず起動して規律を適用します。

### 典型的なワークフロー

```text
/kiro-discovery "やりたいこと"        # 着手方針の決定（任意）
/kiro-spec-quick <feature>            # 要件→設計→タスクを一括生成（段階実行も可）
  ├─ /kiro-spec-requirements <feature>  # 要件定義（EARS形式）
  ├─ /kiro-spec-design <feature>        # 技術設計
  └─ /kiro-spec-tasks <feature>         # タスク分解
/kiro-impl <feature>                  # 実装（レビュー・検証ゲート付き）
/kiro-spec-status <feature>           # 進捗確認（いつでも）
```

> ルールの全文は [docs/sdd/workflow.md](docs/sdd/workflow.md) と [docs/sdd/rules/](docs/sdd/rules/)（テスト方針・コミット方針・ブランチ/PRポリシー）を参照。
> `docs/sdd/` はリポジトリ非依存のベースルールで、他リポジトリへそのまま流用できます。

---

## ドキュメント構成

```
docs/
├── architecture/          # このリポジトリ固有の把握情報
│   ├── system-overview.md #   全体構成・サービス・ネットワーク・ポート
│   ├── tech-stack.md      #   技術スタック詳細・制約
│   └── local-setup.md     #   ローカル環境構築手順（正）
├── sdd/                   # SDD ベースルール（流用可能）
│   ├── workflow.md
│   ├── rules/             #   testing / commit / branching ポリシー
│   └── templates/         #   agreement-log 他テンプレート
└── specs/<task-id>/       # タスクごとの成果物（合意ログ・技術要件・テスト結果 等）
```

仕様・設計・タスクは `.kiro/specs/<task-id>/` で管理されます。
