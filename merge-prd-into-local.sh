#!/bin/sh
source $1/.env

echo "【ローカルのDBをバックアップ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces >$1/$BACKUP_LOCAL
#ファイルがない場合は終了
if [ ! -s $1/$BACKUP_LOCAL ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のDBをダンプ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces >$1/$BACKUP_PRD
#ファイルがない場合は終了
if [ ! -s $1/$BACKUP_PRD ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のpublic_htmlをローカルにコピー】"
rsync --checksum -arv --delete \
  -e "ssh -p ${PRD_SERVER_PORT}" \
  --exclude $STG_DOMAIN --exclude $BACKWPUP_DIR --exclude "${BACKWPUP_DIR}*" --exclude $CACHE_DIR \
  $PRD_PUBLIC_DIR/ $1/$LOCAL_PUBLIC_DIR/
echo "【完了】\n"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
cp -f $1/wp-config-local.php $1/$LOCAL_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【ローカルのDBを本番のDBで上書き】"
mysql -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME <$1/$BACKUP_PRD
echo "【完了】\n"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php ${WP_SYNC_PATH}/srdb.cli.php -h $LOCAL_DB_HOST -P $LOCAL_DB_PORT -u $LOCAL_DB_USER -p $LOCAL_DB_PASSWORD -n $LOCAL_DB_NAME -s "https://${PRD_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
echo "【完了】\n"
