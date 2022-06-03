#!/bin/sh
NOW=`date +"%Y%m%d_%H%M"`
SEARCH="http://localhost:ポート番号"
REPLACE="https://ドメイン名"

#dumpファイルの保存先
BAK_REMOTE="/tmp/prd.bk.$NOW.sql"
BAK_LOCAL="/tmp/local.bk.$NOW.sql"

PRD_SERVER_HOST="リモートサーバーホスト"
PRD_SERVER_PORT="リモートサーバーポート"

SSH_KEY_FILE="sshキーファイルのパス"

LOCAL_PUBLIC_DIR="public_html"
PRD_PUBLIC_DIR="${PRD_SERVER_HOST}:public_htmlの絶対パス"

LOCAL_DB_HOST="127.0.0.1"
LOCAL_DB_PORT="DBのホスト側ポート"
LOCAL_DB_NAME="ローカルのDB名"
LOCAL_DB_USER="ローカルのユーザ名"
LOCAL_DB_PASSWORD="ローカルのパスワード"

PRD_DB_HOST="リモートのDBホスト名"
PRD_DB_NAME="リモートのDB名"
PRD_DB_USER="リモートのユーザ名"
PRD_DB_PASSWORD="リモートのパスワード"


echo "【本番のDBをバックアップ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT -i $SSH_KEY_FILE mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BAK_REMOTE
#ファイルがない場合は終了
if [ ! -s $BAK_REMOTE ]; then
  echo "dump failed: check $BAK_REMOTE"
  exit
fi
echo "【完了】"

echo "【ローカルのDBをダンプ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BAK_LOCAL
#ファイルがない場合は終了
if [ ! -s $BAK_LOCAL ]; then
  echo "dump failed: check $BAK_LOCAL"
  exit
fi
echo "【完了】"

echo "【ローカルのpublic_htmlを本番にコピー】"
rsync --checksum -rv -e "ssh -p ${PRD_SERVER_PORT}" $LOCAL_PUBLIC_DIR/* $PRD_PUBLIC_DIR/
scp -P $PRD_SERVER_PORT -r $LOCAL_PUBLIC_DIR/.htaccess $PRD_PUBLIC_DIR
scp -P $PRD_SERVER_PORT -r $LOCAL_PUBLIC_DIR/.user.ini $PRD_PUBLIC_DIR
echo "【完了】"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P $PRD_SERVER_PORT -r wp-config-prd.php $PRD_PUBLIC_DIR/wp-config.php
echo "【完了】"

echo "【本番のDBをローカルのDBで上書き】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT mysql -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME < $BAK_LOCAL
echo "【完了】"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT /usr/bin/php7.3 srdb.cli.php -h $PRD_DB_HOST -u $PRD_DB_USER -p $PRD_DB_PASSWORD -n $PRD_DB_NAME -s $SEARCH -r $REPLACE
echo "【完了】"
