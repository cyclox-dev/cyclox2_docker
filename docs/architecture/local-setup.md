# ローカル開発環境構築手順

## 前提条件

- Docker Desktop インストール済み
- Git インストール済み、`git@github.com:cyclox-dev/` への SSH アクセス権あり
- Apple Silicon Mac の場合：Docker Desktop の Rosetta エミュレーション有効化を推奨

---

## 1. リポジトリのクローン

```bash
git clone git@github.com:kyamady-dorokid/cyclox2_docker.git
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

## 3. MySQL データ準備

```bash
# データ永続化・ダンプ投入用ディレクトリを作成（.gitignore 対象のため手動作成が必要）
mkdir -p cyclox2_mysql/var/mysql
mkdir -p cyclox2_mysql/var/dump
```

SQLダンプファイル（本番環境等からエクスポート）を `cyclox2_mysql/var/dump/` に配置する。

---

## 4. コンテナのビルドと起動

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

## 5. データベースのリストア

```bash
# cyclox2_mysql コンテナに接続
docker-compose exec cyclox2_mysql bash

# コンテナ内でリストア実行（ファイル名は適宜変更）
mysql -u root -pYamaken0 cyclox2 < /var/tmp/dump_file.sql
```

---

## 6. アクセス確認

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
| ホスト | 172.24.0.3 (固定IP) | env: DB_HOSTNAME (= cyclox2_mysql) |
| ユーザー | cyclox2 | env: DB_USERNAME (= root) |
| パスワード | mku95w6Fx | env: DB_PASSWORD (= Yamaken0) |
| DB名 | cyclox2 | env: DB_DATABASE (= cyclox2) |

> **注意**: cyclox2web の接続設定は `cyclox2_svr/cyclox2_conf/database.php` で管理。
> このファイルはコンテナ起動時にアプリの `app/Config/database.php` にマウントされる。
