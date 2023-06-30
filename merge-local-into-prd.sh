#!/bin/sh
# shellcheck source=/dev/null

. ./.env

echo "【本番のDBをバックアップ】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" mysqldump -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" --no-tablespaces >"$PRD_DB_DUMP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$PRD_DB_DUMP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【ローカルのDBをダンプ】"
mysqldump -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" --column-statistics=0 --no-tablespaces >"$LOCAL_DB_DUMP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$LOCAL_DB_DUMP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【本番のpublic_htmlをバックアップ】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$PRD_SSH_PORT\"" \
  --exclude "$STG_DOMAIN" --exclude "$WORDPRESS_CACHE_DIR_PATH" --exclude "$BACKWPUP_LOG_DIR_PATH" --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/ "$PRD_FILE_BACKUP_DIR_PATH"/
printf "【完了】\n\n"

echo "【ローカルのpublic_htmlを本番にコピー】"
rsync --checksum -arv --delete \
  -e "ssh -p ${PRD_SSH_PORT}" \
  --exclude "$STG_DOMAIN" --exclude "$WORDPRESS_CACHE_DIR_PATH" --exclude "$BACKWPUP_LOG_DIR_PATH" --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$LOCAL_PUBLIC_DIR_PATH"/ "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/
printf "【完了】\n\n"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P "$PRD_SSH_PORT" \
  ./wp-config-prd.php "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"

echo "【本番のDBをローカルのDBで上書き】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  mysql -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" <"$LOCAL_DB_DUMP_FILE_PATH"
printf "【完了】\n\n"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php -h "$PRD_DB_HOST" -u "$PRD_DB_USER" -p "$PRD_DB_PASSWORD" -n "$PRD_DB_NAME" -s "http://${LOCAL_DOMAIN}" -r "https://${PRD_DOMAIN}"
printf "【完了】\n\n"

echo "【本番のDB内の相互リンク関連のドメイン部分を書き換え】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php -h "$PRD_DB_HOST" -u "$PRD_DB_USER" -p "$PRD_DB_PASSWORD" -n "$PRD_DB_NAME" -s "http://${MUTUAL_LINK_BLOG_LOCAL_DOMAIN}" -r "https://${MUTUAL_LINK_BLOG_PRD_DOMAIN}"
printf "【完了】\n\n"
