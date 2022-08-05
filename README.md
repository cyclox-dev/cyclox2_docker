[Version]
PHP 5.6.40
MySQL 5.7.23
httpd 2.4

構築手順

[1. cyclox2_svr(PHP5.6-centos7) dockerイメージ作成]
s2i build https://github.com/sclorg/s2i-php-container.git --context-dir=/5.6/test/test-app/ centos/php-56-centos7 docker_cyclox2_svr

[2. cyclox2_svr向け設定ファイル配置]
cd ~/github/kyamady/cyclox2_docker/docker/cyclox2_svr
cp cyclox2_conf/htaccess_cyclox2 cyclox2/.htaccess
cp cyclox2_conf/htaccess_app cyclox2/app/.htaccess
cp cyclox2_conf/htaccess_webroot cyclox2/app/webroot/.htaccess
cp cyclox2_conf/database.php cyclox2/app/Config/database.php

[3. MySQL resutore用ダンプファイル配置]
cd ~/github/kyamady/cyclox2_docker/docker/cyclox2_mysql
cp dump/20220715_after_dump.sql mysql/20220715_after_dump.sql

[4. cyclox2_svr / cyclox2_mysql コンテナビルド＆起動]
cd ~/github/kyamady/cyclox2_docker/docker
docker-compose down ; docker-compose up -d
docker-compose ps -a

[5. MySQL 初期設定]
・cyclox2_mysqlにログイン
docker exec -it cyclox2_mysql bash
・mysqlにユーザー権限でログイン
mysql -uroot -p
・database作成
CREATE DATABASE cyclox2;
SHOW DATABASES;
・user作成
USE  mysql;
CREATE USER cyclox2 IDENTIFIED BY 'mku95w6Fx';
SELECT user,host FROM user;
・user権限追加
GRANT ALL PRIVILEGES ON *.* TO cyclox2@'172.24.0.2' IDENTIFIED BY 'mku95w6Fx' WITH GRANT OPTION;
SELECT user,host FROM user;

[6. MySQL レストア]
cd /var/tmp/
mysql -uroot -p cyclox2 < 20220715_after_dump.sql


[参考]
オレオレ系ssl設定
https://www.server-world.info/query?os=CentOS_7&p=ssl&fbclid=IwAR0iDQgnvIRrD2t63uOBiUsXWqxUqhaZkZ4gQSndpMClvHB5O4tyQBLeKd0

MySQL日本語化のチェック
https://server-recipe.com/1867/#toc2