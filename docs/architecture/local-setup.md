# ローカル開発環境構築手順

## 前提条件

- Docker Desktop インストール済み
- Git インストール済み、`git@github.com:cyclox-dev/` への SSH アクセス権あり
- Apple Silicon Mac の場合：Docker Desktop の Rosetta エミュレーション有効化を推奨

---

## 1. リポジトリのクローン

```bash
git clone git@github.com:cyclox-dev/cyclox2_docker.git
cd cyclox2_docker
```

---

## 2. サブモジュールの初期化（アプリ本体取得）

```bash
git submodule update --init --recursive
```

取得されるサブモジュール:
- `cyclox2_svr/cyclox2/` … cyclox2web (CakePHP メイン管理アプリ)
- `cyclox2ressys_svr/cyclox2res_sys/` … cyclox2res-sys (CodeIgniter 成績閲覧アプリ)

---

## 3. シークレット設定（.env / database.php）

認証情報は git 管理外。雛形をコピーして実値を設定する（実値は管理者から受領）。

```bash
cp .env.example .env
cp cyclox2_svr/cyclox2_conf/database.php.example cyclox2_svr/cyclox2_conf/database.php
```

- `.env` … `docker-compose.yml` が参照する環境変数（`MYSQL_ROOT_PASSWORD` / `RESSYS_DB_*`）。
- `cyclox2_svr/cyclox2_conf/database.php` … cyclox2web の DB 接続設定。

> `.env` 未作成のまま `docker-compose up` するとパスワードが空になり MySQL 認証に失敗する。

---

## 4. MySQL データ準備

```bash
# データ永続化・ダンプ投入用ディレクトリを作成（.gitignore 対象のため手動作成が必要）
mkdir -p cyclox2_mysql/var/mysql
mkdir -p cyclox2_mysql/var/dump
```

SQLダンプファイル（本番環境等からエクスポート）を `cyclox2_mysql/var/dump/` に配置する。

---

## 5. コンテナのビルドと起動

```bash
docker-compose up -d --build
```

起動確認:
```bash
docker-compose ps -a
```

4つのコンテナが `Up` 状態になっていることを確認:
- `cyclox2_svr`
- `cyclox2_mysql`
- `cyclox2_phpmyadmin`
- `cyclox2ressys_svr`

---

## 6. データベースのリストア

```bash
# cyclox2_mysql コンテナに接続
docker-compose exec cyclox2_mysql bash

# コンテナ内でリストア実行（<DB_USER> / ファイル名は実際の値に置き換え。-p のみ指定で対話入力）
mysql -u <DB_USER> -p cyclox2 < /var/tmp/dump_file.sql
```

> ユーザー名・パスワードは `.env` / `database.php` の値を参照。本ドキュメントには記載しません。

---

## 7. アクセス確認

| サービス | URL |
|---|---|
| Cyclox2（メイン管理） | http://localhost/ |
| phpMyAdmin | http://localhost:4040/ |
| Cyclox2 Result System | http://localhost:8081/ |

---

## コンテナ操作

```bash
# 停止
docker-compose down

# ログ確認
docker-compose logs -f cyclox2_svr

# コンテナに入る
docker-compose exec cyclox2_svr bash
docker-compose exec cyclox2_mysql bash
```

---

## ディレクトリ構成（.gitignore 対象）

以下は git 管理外のため、手動作成または別途用意が必要:

| パス | 用途 |
|---|---|
| `cyclox2_mysql/var/mysql/` | MySQL データファイル（永続化） |
| `cyclox2_mysql/var/dump/` | SQL ダンプ投入用 |
| `phpmyadmin/sessions/` | phpMyAdmin セッション |

---

## DB 接続情報（開発環境）

| 項目 | cyclox2web | cyclox2res-sys |
|---|---|---|
| ホスト | 172.24.0.3 (固定IP) | env: DB_HOSTNAME |
| ユーザー | `<DB_USER>` | env: DB_USERNAME |
| パスワード | `<DB_PASSWORD>` | env: DB_PASSWORD |
| DB名 | cyclox2 | env: DB_DATABASE |

> **注意**: 実際のユーザー名・パスワードは本ドキュメントに記載しません。
> - cyclox2web の接続設定は `cyclox2_svr/cyclox2_conf/database.php` で管理（コンテナ起動時に `app/Config/database.php` へマウント）。
> - cyclox2res-sys は `docker-compose.yml` の環境変数（`DB_USERNAME` / `DB_PASSWORD` 等）で設定。
