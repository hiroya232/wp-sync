#!/bin/sh
source .env

echo "【ローカルのDBをバックアップ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BAK_LOCAL
#ファイルがない場合は終了
if [ ! -s $BAK_LOCAL ]; then
  echo "dump failed: check $BAK_LOCAL"
  exit
fi
echo "【完了】\n"

echo "【ステージングのDBをダンプ】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysqldump -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME --no-tablespaces > $BAK_STG
#ファイルがない場合は終了
if [ ! -s $BAK_STG ]; then
  echo "dump failed: check $BAK_STG"
  exit
fi
echo "【完了】\n"

echo "【ステージングのpublic_htmlをローカルにコピー】"
rsync --checksum -arv \
  -e "ssh -p ${STG_SERVER_PORT}" \
  --exclude ${STG_DOMAIN} \
  $STG_PUBLIC_DIR/ $LOCAL_PUBLIC_DIR/
echo "【完了】\n"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
cp -f wp-config-local.php $LOCAL_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【ステージングのDBをローカルのDBで上書き】"
ssh $STG_SERVER_HOST -p $STG_SERVER_PORT \
  mysql -u$STG_DB_USER -p$STG_DB_PASSWORD -h$STG_DB_HOST $STG_DB_NAME < $BAK_LOCAL
echo "【完了】\n"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php srdb.cli.php -h $LOCAL_DB_HOST -P $LOCAL_DB_PORT -u $LOCAL_DB_USER -p $LOCAL_DB_PASSWORD -n $LOCAL_DB_NAME -s "https://${STG_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
echo "【完了】\n"
