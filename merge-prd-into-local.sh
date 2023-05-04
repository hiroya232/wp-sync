#!/bin/sh
source .env

echo "【ローカルのDBをバックアップ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BACKUP_LOCAL
#ファイルがない場合は終了
if [ ! -s $BACKUP_LOCAL ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のDBをダンプ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BACKUP_PRD
#ファイルがない場合は終了
if [ ! -s $BACKUP_PRD ]; then
  echo "dump failed!"
  exit
fi
echo "【完了】\n"

echo "【本番のpublic_htmlをローカルにコピー】"
rsync --checksum -arv \
  -e "ssh -p ${PRD_SERVER_PORT}" \
  --exclude $STG_DOMAIN --exclude $BACKWPUP_DIR --exclude "${BACKWPUP_DIR}*" --exclude $CACHE_DIR \
  $PRD_PUBLIC_DIR/ $LOCAL_PUBLIC_DIR/
echo "【完了】\n"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
cp -f  wp-config-local.php $LOCAL_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【ローカルのDBを本番のDBで上書き】"
mysql -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME < $BACKUP_PRD
echo "【完了】\n"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php srdb.cli.php -h $LOCAL_DB_HOST -P $LOCAL_DB_PORT -u $LOCAL_DB_USER -p $LOCAL_DB_PASSWORD -n $LOCAL_DB_NAME -s "https://${PRD_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
echo "【完了】\n"
