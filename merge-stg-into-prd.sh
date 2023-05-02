#!/bin/sh
# 本番とステージングが同じサーバーにあることが前提
source .env

echo "【本番のDBをバックアップ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BAK_PRD
#ファイルがない場合は終了
if [ ! -s $BAK_PRD ]; then
  echo "dump failed: check $BAK_PRD"
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

echo "【ステージングのpublic_htmlを本番にコピー】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  rsync --checksum -arv \
  $STG_PUBLIC_DIR_PATH/ $PRD_PUBLIC_DIR_PATH/
echo "【完了】\n"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P $PRD_SERVER_PORT -r \
  wp-config-prd.php $PRD_PUBLIC_DIR/wp-config.php
echo "【完了】\n"

echo "【本番のDBをステージングのDBで上書き】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  mysql -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME < $BAK_STG
echo "【完了】\n"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT \
  /usr/bin/php7.3 srdb.cli.php -h $PRD_DB_HOST -u $PRD_DB_USER -p $PRD_DB_PASSWORD -n $PRD_DB_NAME -s "https://${STG_DOMAIN}" -r "https://${PRD_DOMAIN}"
echo "【完了】\n"
