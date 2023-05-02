#!/bin/sh
source .env

echo "【本番のDBをバックアップ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BACKUP_PRD
#ファイルがない場合は終了
if [ ! -s $BACKUP_PRD ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【ローカルのDBをダンプ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BACKUP_LOCAL
#ファイルがない場合は終了
if [ ! -s $BACKUP_LOCAL ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【ローカルのpublic_htmlを本番にコピー】"
rsync --checksum -arv \
  -e "ssh -p ${PRD_SERVER_PORT}" \
  --exclude ${STG_DOMAIN} \
  $LOCAL_PUBLIC_DIR/ $PRD_PUBLIC_DIR/
echo "【完了】\n"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P $PRD_SERVER_PORT -r \
  wp-config-prd.php $PRD_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【本番のDBをローカルのDBで上書き】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysql -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME < $BACKUP_LOCAL
echo "【完了】\n"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  /usr/bin/php7.3 srdb.cli.php -h $PRD_DB_HOST -u $PRD_DB_USER -p $PRD_DB_PASSWORD -n $PRD_DB_NAME -s "http://${LOCAL_DOMAIN}" -r "https://${PRD_DOMAIN}"
echo "【完了】\n"
