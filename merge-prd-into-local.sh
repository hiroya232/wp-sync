#!/bin/sh
# shellcheck source=/dev/null

. "$1"/.env

echo "【ローカルのDBをバックアップ】"
mysqldump -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" --column-statistics=0 --no-tablespaces >"$1"/"$LOCAL_DB_BACKUP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$1"/"$LOCAL_DB_BACKUP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【本番のDBをダンプ】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  mysqldump -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" --no-tablespaces >"$1"/"$PRD_DB_BACKUP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$1"/"$PRD_DB_BACKUP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【本番のpublic_htmlをローカルにコピー】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$PRD_SSH_PORT\"" \
  --exclude "$STG_DOMAIN" --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/ "$1"/"$LOCAL_PUBLIC_DIR_PATH"/
printf "【完了】\n\n"

echo "【wp-config.phpの内容をローカル環境のものに書き換え】"
cp -f "$1"/wp-config-local.php "$1"/"$LOCAL_PUBLIC_DIR_PATH"/wp-config.php
printf "【完了】\n\n"

echo "【ローカルのDBを本番のDBで上書き】"
mysql -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" <"$1"/"$PRD_DB_BACKUP_FILE_PATH"
printf "【完了】\n\n"

echo "【ローカルのDB内のドメイン部分を書き換え】"
php "$WP_SYNC_REPOSITORY_PATH"/srdb.cli.php -h "$LOCAL_DB_HOST" -P "$LOCAL_DB_PORT" -u "$LOCAL_DB_USER" -p "$LOCAL_DB_PASSWORD" -n "$LOCAL_DB_NAME" -s "https://${PRD_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
printf "【完了】\n\n"
