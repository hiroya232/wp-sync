#!/bin/sh
source .env

echo "【本番のDBをバックアップ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BAK_PRD
#ファイルがない場合は終了
if [ ! -s $BAK_PRD ]; then
  echo "dump failed: check $BAK_PRD"
  exit
fi
echo "【完了】\n"

echo "【ローカルのDBをダンプ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BAK_LOCAL
#ファイルがない場合は終了
if [ ! -s $BAK_LOCAL ]; then
  echo "dump failed: check $BAK_LOCAL"
  exit
fi
echo "【完了】\n"

echo "【ローカルのpublic_htmlを本番にコピー】"
rsync --checksum -rv -e "ssh -p ${PRD_SERVER_PORT}" $LOCAL_PUBLIC_DIR/* $PRD_PUBLIC_DIR/
scp -P $PRD_SERVER_PORT -r $LOCAL_PUBLIC_DIR/.htaccess $PRD_PUBLIC_DIR
scp -P $PRD_SERVER_PORT -r $LOCAL_PUBLIC_DIR/.user.ini $PRD_PUBLIC_DIR
echo "【完了】"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P $PRD_SERVER_PORT -r \
  wp-config-prd.php $PRD_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【本番のDBをローカルのDBで上書き】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysql -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME < $BAK_LOCAL
echo "【完了】\n"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  /usr/bin/php7.3 srdb.cli.php -h $PRD_DB_HOST -u $PRD_DB_USER -p $PRD_DB_PASSWORD -n $PRD_DB_NAME -s $LOCAL_DOMAIN -r $PRD_DOMAIN
echo "【完了】\n"
