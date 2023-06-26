#!/bin/sh
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

. ./.env

echo "【本番のDBをダンプ】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  mysqldump -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" --no-tablespaces >"$PRD_DB_DUMP_FILE_PATH"
#ファイルがない場合は終了
if [ ! -s "$PRD_DB_DUMP_FILE_PATH" ]; then
  echo "dump failed!"
  exit
fi
printf "【完了】\n\n"

echo "【本番のpublic_htmlをステージングにコピー】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  rsync --checksum -arv --delete \
  --exclude "$STG_DOMAIN" --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  "$PRD_PUBLIC_DIR_PATH"/ "$STG_PUBLIC_DIR_PATH"
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

echo "【ステージングのDBを本番のDBで上書き】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  mysql -u"$STG_DB_USER" -p"$STG_DB_PASSWORD" -h"$STG_DB_HOST" "$STG_DB_NAME" <"$PRD_DB_DUMP_FILE_PATH"
printf "【完了】\n\n"

echo "【ステージングのDB内のドメイン部分を書き換え】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php -h "$STG_DB_HOST" -u "$STG_DB_USER" -p "$STG_DB_PASSWORD" -n "$STG_DB_NAME" -s "https://${PRD_DOMAIN}" -r "https://${STG_DOMAIN}"
printf "【完了】\n\n"
