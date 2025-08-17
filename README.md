# Cyclox2 Docker環境

## 概要

このリポジトリは、Cyclox2アプリケーションをDockerコンテナで実行するための環境を提供します。

以下のコンテナが含まれています:
- `cyclox2_svr`: Cyclox2アプリケーション (CakePHP) を実行するWebサーバー (Apache + PHP)
- `cyclox2_mysql`: MySQLデータベースサーバー
- `cyclox2_phpmyadmin`: phpMyAdmin
- `cyclox2ressys_svr`: Cyclox2 Result Systemアプリケーションを実行するWebサーバー

## 起動手順

### 1. リポジトリのクローン

```bash
git clone git@github.com:kyamady-dorokid/cyclox2_docker.git
cd cyclox2_docker
```

### 2. MySQLのデータ準備

`cyclox2_mysql`コンテナを初回起動する前に、データベースのリストア準備が必要です。

1.  `cyclox2_mysql/var/mysql` ディレクトリと `cyclox2_mysql/var/dump` ディレクトリを作成します。これらのディレクトリは`.gitignore`に含まれているため、手動で作成する必要があります。

    ```bash
    mkdir -p cyclox2_mysql/var/mysql
    mkdir -p cyclox2_mysql/var/dump
    ```

2.  本番環境などからエクスポートしたSQLダンプファイルを、作成した `cyclox2_mysql/var/dump` ディレクトリに配置します。

### 3. コンテナのビルドと起動

以下のコマンドを実行して、すべてのコンテナをビルドし、バックグラウンドで起動します。

```bash
docker-compose up -d --build
```

コンテナの起動状態は、以下のコマンドで確認できます。

```bash
docker-compose ps -a
```

### 4. データベースのリストア

コンテナが起動したら、`cyclox2_mysql`コンテナに入り、SQLダンプをインポートしてデータベースをリストアします。

```bash
# cyclox2_mysqlコンテナに接続
docker-compose exec cyclox2_mysql bash

# コンテナ内でリストアコマンドを実行 (dump_file.sqlは配置したファイル名に置き換えてください)
mysql -u root -p${MYSQL_ROOT_PASSWORD} cyclox2 < /var/tmp/dump_file.sql
```
`docker-compose.yml`で設定されている`MYSQL_ROOT_PASSWORD`（デフォルト: `Yamaken0`）のパスワード入力を求められます。

## アクセス

- **Cyclox2**: [http://localhost/](http://localhost/)
- **phpMyAdmin**: [http://localhost:4040/](http://localhost:4040/)
- **Cyclox2 Result System**: [http://localhost:8081/](http://localhost:8081/)

## コンテナの停止

```bash
docker-compose down
