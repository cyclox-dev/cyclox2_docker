# 技術スタック

## 全体

| 分類 | 技術 | バージョン | 備考 |
|---|---|---|---|
| コンテナ基盤 | Docker Compose | 3.7 | `docker-compose.yml` |
| データベース | MySQL | 5.7.42 | `mysql:5.7.42`（`--platform=linux/x86_64`） |
| Web/APサーバー | Apache httpd | centos7ベース | `centos/php-73-centos7:latest` |
| PHP | PHP | 7.3 | 両アプリ共通 |

---

## cyclox2web（メイン管理アプリ）

| 分類 | 技術 | 詳細 |
|---|---|---|
| フレームワーク | CakePHP 2.x | MVCフレームワーク（2.x系/Active Record ORM） |
| 言語 | PHP 7.3 | |
| DB接続 | CakePHP ORM (`Database/Mysql`) | 直接ホストIP固定（172.24.0.3） |
| 認証 | CakePHP Auth（`UsersController`） | |
| SSL | 自己署名証明書 | `cyclox2_svr/pki/tls/certs/` |
| ドキュメントルート | `/var/www/html/app/webroot` | |
| ログ | `/var/www/html/logs` → `cyclox2_svr/cyclox2/app/tmp/logs/`（bindmount） | |

### 主要コンポーネント
- `app/Controller/` - コントローラ群（35ファイル）
- `app/Model/` - モデル群（32ファイル）
- `app/View/` - ビュー
- `app/Cyclox/` - Cyclox独自ライブラリ（Util・Const含む）
- `app/Plugin/` - CakePHPプラグイン
- `lib/Cake/` - CakePHPコアライブラリ

---

## cyclox2 Result System（成績閲覧アプリ）

| 分類 | 技術 | 詳細 |
|---|---|---|
| フレームワーク | CodeIgniter 3.1.x | `codeigniter/framework: 3.1.*` |
| 言語 | PHP 7.3 | PHP ≥ 5.3.2 要件 |
| 依存管理 | Composer 2 | Dockerビルド時 `composer install --no-dev` |
| DB接続 | CodeIgniter DB / mysqli | 環境変数経由（`DB_HOSTNAME`等） |
| ドキュメントルート | `/var/www/html/ajocc_xsys/public` | |
| スタイリング | SCSS (`scss/main.scss`) | |
| テスト | mikey179/vfsstream 1.1.x | require-dev |

### 主要コンポーネント
- `application/controllers/` - コントローラ（6ファイル）
- `application/models/` - モデル（9ファイル）
- `application/views/` - ビュー
- `application/libraries/` - 独自ライブラリ
- `public/` - 公開ディレクトリ

---

## Docker構成詳細

### cyclox2_svr（メインアプリコンテナ）
- **ベースイメージ**: `centos/php-73-centos7:latest`
- **起動コマンド**: `httpd -D FOREGROUND`
- **ボリュームマウント**: httpd設定 / php.ini / SSL証明書 / アプリコード（submodule）/ conf（DB設定・.htaccess）

### cyclox2_mysql（DBコンテナ）
- **ベースイメージ**: `mysql:5.7.42`（linux/x86_64固定）
- **環境変数**: `MYSQL_ROOT_PASSWORD=Yamaken0`
- **ボリューム**: `cyclox2_mysql/var/mysql` → `/var/lib/mysql`（データ永続化）、`cyclox2_mysql/var/dump` → `/var/tmp`（ダンプ投入用）

### cyclox2ressys_svr（成績閲覧コンテナ）
- **ベースイメージ**: `centos/php-73-centos7:latest`
- **マルチステージビルド**: Composerで依存解決後、アプリをコピー
- **環境変数**: `DB_HOSTNAME / DB_USERNAME / DB_PASSWORD / DB_DATABASE`

---

## 既知の制約・注意点

| 項目 | 内容 |
|---|---|
| PHP バージョン | PHP 7.3（EOL）。アップグレードには互換性確認が必要 |
| MySQL バージョン | 5.7（EOL予定）。8.0への移行は文字コード・SQL_MODE変更を要する |
| CakePHP バージョン | 2.x系（最新はCakePHP 5.x）。3.x以降への移行は大規模改修 |
| DB接続（cyclox2web） | ホストIPが `172.24.0.3` にハードコード。`database.php` はgit管理（`cyclox2_conf/`配下） |
| アーキテクチャ固定 | cyclox2_mysql は `linux/x86_64` 固定（Apple Silicon Macでは Rosetta 経由） |
| submodule | 2つのアプリ本体がsubmodule。取得には `git@github.com:cyclox-dev/` への SSHアクセスが必要 |
