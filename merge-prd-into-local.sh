#!/bin/sh
NOW=`date +"%Y%m%d_%H%M"`
SEARCH="https://ドメイン名"
REPLACE="http://localhost:ポート番号"

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


echo "【ローカルのDBをバックアップ】"
mysqldump -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME --column-statistics=0 --no-tablespaces > $BAK_LOCAL
#ファイルがない場合は終了
if [ ! -s $BAK_LOCAL ]; then
  echo "dump failed: check $BAK_LOCAL"
  exit
fi
echo "【完了】"

echo "【本番のDBをダンプ】"
ssh $PRD_SERVER_HOST -p $PRD_SERVER_PORT -i $SSH_KEY_FILE mysqldump -u$PRD_DB_USER -p$PRD_DB_PASSWORD -h$PRD_DB_HOST $PRD_DB_NAME --no-tablespaces > $BAK_REMOTE
#ファイルがない場合は終了
if [ ! -s $BAK_REMOTE ]; then
  echo "dump failed: check $BAK_REMOTE"
  exit
fi
echo "【完了】"

echo "【本番のpublic_htmlをローカルにコピー】"
rsync --checksum -rv -e "ssh -p ${PRD_SERVER_PORT}" --exclude 'wp-content/uploads/file-backup' --exclude 'wp-content/uploads/database-backup' $PRD_PUBLIC_DIR/\* $LOCAL_PUBLIC_DIR/
scp -P $PRD_SERVER_PORT -r $PRD_PUBLIC_DIR/.htaccess $LOCAL_PUBLIC_DIR
scp -P $PRD_SERVER_PORT -r $PRD_PUBLIC_DIR/.user.ini $LOCAL_PUBLIC_DIR
echo "【完了】"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
\cp -f  wp-config-local.php $LOCAL_PUBLIC_DIR/wp-config.php
echo "【完了】"

echo "【ローカルのDBを本番のDBで上書き】"
mysql -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD -h$LOCAL_DB_HOST -P$LOCAL_DB_PORT $LOCAL_DB_NAME < $BAK_REMOTE
echo "【完了】"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php srdb.cli.php -h $LOCAL_DB_HOST -P $LOCAL_DB_PORT -u $LOCAL_DB_USER -p $LOCAL_DB_PASSWORD -n $LOCAL_DB_NAME -s $SEARCH -r $REPLACE
echo "【完了】"







