#!/bin/sh
# shellcheck source=/dev/null

. ./.env

echo "------------------------------ステージング環境バックアップ　開始------------------------------"
echo "【DBをバックアップ】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  mysqldump \
  -u"$STG_DB_USER" \
  -p"$STG_DB_PASSWORD" \
  -h"$STG_DB_HOST" \
  "$STG_DB_NAME" \
  --no-tablespaces >"$STG_DB_DUMP_FILE_PATH"
printf "【完了】\n\n"

echo "【public_htmlをバックアップ】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$STG_SSH_PORT\"" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/ "$STG_FILE_BACKUP_DIR_PATH"/
printf "【完了】\n\n"
echo "------------------------------ステージング環境バックアップ　完了------------------------------"

echo "------------------------------ローカル→ステージング環境同期　開始------------------------------"
echo "【DBを同期】"
mysqldump \
  -u"$LOCAL_DB_USER" \
  -p"$LOCAL_DB_PASSWORD" \
  -h"$LOCAL_DB_HOST" \
  -P"$LOCAL_DB_PORT" \
  "$LOCAL_DB_NAME" \
  --column-statistics=0 --no-tablespaces |
  ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    mysql \
    -u"$STG_DB_USER" \
    -p"$STG_DB_PASSWORD" \
    -h"$STG_DB_HOST" \
    "$STG_DB_NAME"
printf "【完了】\n\n"

echo "【ドメインを置換】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php \
  -h "$STG_DB_HOST" \
  -u "$STG_DB_USER" \
  -p "$STG_DB_PASSWORD" \
  -n "$STG_DB_NAME" \
  -s "http://${LOCAL_DOMAIN}" -r "https://${STG_DOMAIN}"
printf "【完了】\n\n"

echo "【public_htmlを同期】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$STG_SSH_PORT\"" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$LOCAL_PUBLIC_DIR_PATH"/ "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/
printf "【完了】\n\n"

echo "【wp-config.phpを置換】"
scp -P "$STG_SSH_PORT" \
  ./wp-config-stg.php "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"
echo "------------------------------ローカル→ステージング環境同期　完了------------------------------"

echo "------------------------------後処理　開始------------------------------"
echo "【Basic認証の設定】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "sed -i '/^\n*$/d' \"$STG_PUBLIC_DIR_PATH/.htaccess\""
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "echo -e \"\n\" >> \"$STG_PUBLIC_DIR_PATH/.htaccess\""
ssh <./.htaccess-basic-auth "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "cat >> \"$STG_PUBLIC_DIR_PATH\"/.htaccess"
scp -P "$STG_SSH_PORT" \
  ./.htpasswd "$HTPASSWD_PATH_WITH_DESTINATION"/.htpasswd
printf "【完了】\n\n"
echo "------------------------------後処理　完了------------------------------"
