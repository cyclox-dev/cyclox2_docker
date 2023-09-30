# Cyclox2_svr & Cyclox2_mysql Docker版　

## Software Version
- Docker 20.10.14
- Apache 2.4.53
- PHP 5.6.40
- CakePHP 2.10.0
- MySQL 5.7.39
- phpMyAdmin 5.2.0

## 構築手順

### 0. 事前準備
- このリポジトリをcloneする
- dockerをインストールしておく
- (MacOSの場合はHomebrew経由) brew install docker
- source-to-image(s2i)　コマンドをインストールしておく
- (MacOSの場合はHomebrew経由) brew install source-to-image

### 1. cyclox2_svr(PHP5.6-centos7) dockerイメージ作成]
```
s2i build https://github.com/sclorg/s2i-php-container.git --context-dir=/5.6/test/test-app/ centos/php-56-centos7 img_cyclox2_svr
```
### 2. cyclox2_svr向け設定ファイル配置
```
cd ~cyclox2_docker/docker/cyclox2_svr
cp cyclox2_conf/htaccess_cyclox2 cyclox2/.htaccess
cp cyclox2_conf/htaccess_app cyclox2/app/.htaccess
cp cyclox2_conf/htaccess_webroot cyclox2/app/webroot/.htaccess
cp cyclox2_conf/database.php cyclox2/app/Config/database.php
```
### 3. cyclox2_svr / cyclox2_mysql コンテナビルド＆起動
```
cd ~cyclox2_docker/docker　
docker-compose down ; docker-compose up -d
docker-compose ps -a
```

### 4. MySQL 初期設定
#### cyclox2_mysqlにログイン
```
docker exec -it cyclox2_mysql bash
```
#### mysqlにroot権限でログイン
```
mysql -uroot -p
```
- rootの初期パスワードはここで設定しているので、適宜変更してコンテナ起動すること
> https://github.com/kyamady/cyclox2_docker/blob/dev/docker/docker-compose.yml#L46
#### database作成
```
CREATE DATABASE cyclox2;
SHOW DATABASES;
```
#### user作成
```
USE  mysql;
CREATE USER cyclox2 IDENTIFIED BY 'mku95w6Fx';
SELECT user,host FROM user;
```
#### user権限追加
```
GRANT ALL PRIVILEGES ON cyclox2.* TO 'cyclox2'@'%' IDENTIFIED BY 'mku95w6Fx' WITH GRANT OPTION;
SELECT user,host FROM user;
GRANT ALL PRIVILEGES ON *.* TO root@'%' IDENTIFIED BY 'Yamaken0' WITH GRANT OPTION;
SELECT user,host FROM user;
```
### 5. Databaseレストア用ダンプファイル配置
- リポジトリをcloneしたあと、下記のディレクトリにダンプファイルを置いてください。(dumpファイル本体はgit上にはありません)
> ~/github/kyamady/cyclox2_docker/docker/cyclox2_mysql/dump
### 6. Databaseレストア
#### cyclox2_mysqlにログイン
```
docker exec -it cyclox2_mysql bash
```
#### 以下はコンテナ内でのコマンド実行
```
cd /var/tmp/
mysql -uroot -p cyclox2 < 20220715_after_dump.sql
```

## アクセス
- cyclox2
> http://localhost/
- phpmyadmin
> http://localhost:4040/

## 参考
### オレオレ系ssl設定
> https://www.server-world.info/query?os=CentOS_7&p=ssl&fbclid=IwAR0iDQgnvIRrD2t63uOBiUsXWqxUqhaZkZ4gQSndpMClvHB5O4tyQBLeKd0
### MySQL日本語化のチェック
> https://server-recipe.com/1867/#toc2
