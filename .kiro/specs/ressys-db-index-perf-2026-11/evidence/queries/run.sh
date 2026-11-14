#!/bin/bash
# usage: run.sh <label>  -> EXPLAIN(要約)と実行時間を出力
D=$(dirname $0); set -a; . /Users/kyamady/workspace/cyclox2_docker/.env; set +a
for f in $D/q*.sql; do n=$(basename $f .sql)
  echo "## $n"
  docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" cyclox2_mysql mysql -uroot cyclox2 -t -e "EXPLAIN $(cat $f)" 2>&1 | grep -v "^+" | awk -F'|' 'NR>1{gsub(/ +/," ");print $3,$4,$6,$7,$8,$10,$11}' | sed 's/^/   /'
  s=$(python3 -c 'import time;print(time.time())')
  docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" cyclox2_mysql mysql -uroot cyclox2 -N -e "$(cat $f)" >/dev/null 2>&1
  e=$(python3 -c 'import time;print(time.time())'); python3 -c "print('   time: %.2fs'%($e-$s))"
done
