#!/bin/sh
# shellcheck source=/dev/null

. ./.env

echo "【ローカルのDBをダンプ】"
mysqldump -u"$LOCAL_DB_USER" -p"$LOCAL_DB_PASSWORD" -h"$LOCAL_DB_HOST" -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME" --column-statistics=0 --no-tablespaces >"$LOCAL_DB_BACKUP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$LOCAL_DB_BACKUP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【ローカルのpublic_htmlをステージングにコピー】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$STG_SSH_PORT\"" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  "$LOCAL_PUBLIC_DIR_PATH"/ "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/
printf "【完了】\n\n"

echo "【wp-config.phpの内容をステージング環境のものに書き換え】"
scp -P "$STG_SSH_PORT" \
  ./wp-config-stg.php "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"

echo "【Basic認証の設定追加】"
< ./.htaccess-basic-auth ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "cat >> \"$STG_PUBLIC_DIR_PATH\"/.htaccess"
scp -P "$STG_SSH_PORT" \
  ./.htpasswd "$HTPASSWD_PATH_WITH_DESTINATION"/.htpasswd
printf "【完了】\n\n"

echo "【ステージングのDBをローカルのDBで上書き】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  mysql -u"$STG_DB_USER" -p"$STG_DB_PASSWORD" -h"$STG_DB_HOST" "$STG_DB_NAME" <"$LOCAL_DB_BACKUP_FILE_PATH"
printf "【完了】\n\n"

echo "【ステージングのDB内のドメイン部分を書き換え】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php -h "$STG_DB_HOST" -u "$STG_DB_USER" -p "$STG_DB_PASSWORD" -n "$STG_DB_NAME" -s "http://${LOCAL_DOMAIN}" -r "https://${STG_DOMAIN}"
printf "【完了】\n\n"
