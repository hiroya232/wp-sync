#!/bin/sh
# 本番とステージングが同じサーバーにあることが前提
source $1/.env

echo "【ステージングのDBをバックアップ】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysqldump -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME --no-tablespaces > $1/$BACKUP_STG
#ファイルがない場合は終了
if [ ! -s $1/$BACKUP_STG ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のDBをダンプ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $1/$BACKUP_PRD
#ファイルがない場合は終了
if [ ! -s $1/$BACKUP_PRD ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のpublic_htmlをステージングにコピー】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  rsync --checksum -arv --delete \
  --exclude $STG_DOMAIN --exclude $BACKWPUP_DIR --exclude "${BACKWPUP_DIR}*" --exclude $CACHE_DIR \
  $PRD_PUBLIC_DIR_PATH/ $STG_PUBLIC_DIR_PATH
echo "【完了】\n"

echo "【wp-config.phpの内容をステージング環境のものに書き換え】"
scp -P $STG_SERVER_PORT -r \
  $1/wp-config-stg.php $STG_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【ステージングのDBを本番のDBで上書き】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysql -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME < $1/$BACKUP_PRD
echo "【完了】\n"

echo "【ステージングのDB内のドメイン部分を書き換え】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  /usr/bin/php7.3 srdb.cli.php -h $STG_DB_HOST -u $STG_DB_USER -p $STG_DB_PASSWORD -n $STG_DB_NAME -s "https://${PRD_DOMAIN}" -r "https://${STG_DOMAIN}"
echo "【完了】\n"
