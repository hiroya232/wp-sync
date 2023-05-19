#!/bin/sh
# shellcheck source=/dev/null

. "$1"/.env

echo "【ローカルのDBをバックアップ】"
mysqldump -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" --column-statistics=0 --no-tablespaces >"$1"/"$BACKUP_LOCAL"
#ファイルがない場合は終了
if [ ! -s "$1"/"$BACKUP_LOCAL" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【ステージングのDBをダンプ】"
ssh "$STG_SERVER_HOST" -p "$STG_SERVER_PORT" \
  mysqldump -u"$STG_DB_USER" -p"$STG_DB_PASSWORD" -h"$STG_DB_HOST" "$STG_DB_NAME" --no-tablespaces >"$1"/"$BACKUP_STG"
#ファイルがない場合は終了
if [ ! -s "$1"/"$BACKUP_STG" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【ステージングのpublic_htmlをローカルにコピー】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$STG_SERVER_PORT\"" \
  --exclude "$BACKWPUP_DIR" --exclude "${BACKWPUP_DIR}*" --exclude "$CACHE_DIR" \
  "$STG_PUBLIC_DIR"/ "$1"/"$LOCAL_PUBLIC_DIR"/
printf "【完了】\n\n"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
cp -f "$1"/wp-config-local.php "$1"/"$LOCAL_PUBLIC_DIR"/wp-config.php
printf "【完了】\n\n"

echo "【Basic認証の設定削除】"
grep -vFf "$1"/.htaccess-basic-auth "$LOCAL_PUBLIC_DIR"/.htaccess >"$LOCAL_PUBLIC_DIR"/.htaccess.tmp &&
  mv "$LOCAL_PUBLIC_DIR"/.htaccess.tmp "$LOCAL_PUBLIC_DIR"/.htaccess
printf "【完了】\n\n"

echo "【ローカルのDBを本番のDBで上書き】"
mysql -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" <"$1"/"$BACKUP_STG"
printf "【完了】\n\n"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php "$WP_SYNC_PATH"/srdb.cli.php -h "$LOCAL_DB_HOST" -P "$LOCAL_DB_PORT" -u "$LOCAL_DB_USER" -p "$LOCAL_DB_PASSWORD" -n "$LOCAL_DB_NAME" -s "https://${STG_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
printf "【完了】\n\n"
