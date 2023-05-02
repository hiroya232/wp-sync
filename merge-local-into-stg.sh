#!/bin/sh
source .env

echo "【ステージングのDBをバックアップ】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysqldump -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME --no-tablespaces > $BACKUP_STG
#ファイルがない場合は終了
if [ ! -s $BACKUP_STG ]; then
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

echo "【ローカルのpublic_htmlをステージングにコピー】"
rsync --checksum -arv \
  -e "ssh -p ${STG_SERVER_PORT}" \
  --exclude $STG_DOMAIN \
  $LOCAL_PUBLIC_DIR/ $STG_PUBLIC_DIR/
echo "【完了】\n"

echo "【wp-config.phpの内容をステージング環境のものに書き換え】"
scp -P $STG_SERVER_PORT -r \
  wp-config-stg.php $STG_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【ステージングのDBをローカルのDBで上書き】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysql -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME < $BACKUP_LOCAL
echo "【完了】\n"

echo "【ステージングのDB内のドメイン部分を書き換え】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  /usr/bin/php7.3 srdb.cli.php -h $STG_DB_HOST -u $STG_DB_USER -p $STG_DB_PASSWORD -n $STG_DB_NAME -s "http://${LOCAL_DOMAIN}" -r "https://${STG_DOMAIN}"
echo "【完了】\n"
