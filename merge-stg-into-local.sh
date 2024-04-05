#!/bin/sh
# shellcheck source=/dev/null

. ./.env

echo "------------------------------ローカル環境バックアップ　開始------------------------------"
echo "【DBをバックアップ】"
mysqldump \
  -u"$LOCAL_DB_USER" \
  -p"$LOCAL_DB_PASSWORD" \
  -h"$LOCAL_DB_HOST" \
  -P"$LOCAL_DB_PORT" \
  "$LOCAL_DB_NAME" \
  --column-statistics=0 --no-tablespaces >"$LOCAL_DB_DUMP_FILE_PATH"
printf "【完了】\n\n"

echo "【public_htmlをバックアップ】"
rsync --checksum -arv --delete \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$LOCAL_PUBLIC_DIR_PATH"/ "$LOCAL_FILE_BACKUP_DIR_PATH"/
printf "【完了】\n"
echo "------------------------------ローカル環境バックアップ　完了------------------------------"

echo "------------------------------ステージング→ローカル環境同期　開始------------------------------"
echo "【DBを同期】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  mysqldump \
  -u"$STG_DB_USER" \
  -p"$STG_DB_PASSWORD" \
  -h"$STG_DB_HOST" "$STG_DB_NAME" \
  --no-tablespaces |
  mysql \
    -u"$LOCAL_DB_USER" \
    -p"$LOCAL_DB_PASSWORD" \
    -h"$LOCAL_DB_HOST" \
    -P"$LOCAL_DB_PORT" "$LOCAL_DB_NAME"
printf "【完了】\n\n"

echo "【ドメインを置換】"
php "$WP_SYNC_REPOSITORY_PATH"/srdb.cli.php \
  -h "$LOCAL_DB_HOST" \
  -P "$LOCAL_DB_PORT" \
  -u "$LOCAL_DB_USER" \
  -p "$LOCAL_DB_PASSWORD" \
  -n "$LOCAL_DB_NAME" \
  -s "https://${STG_DOMAIN}" -r "http://${LOCAL_DOMAIN}"
printf "【完了】\n\n"

echo "【public_htmlを同期】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$STG_SSH_PORT\"" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/ "$LOCAL_PUBLIC_DIR_PATH"/
printf "【完了】\n\n"

echo "【wp-config.phpを置換】"
cp -f ./wp-config-local.php "$LOCAL_PUBLIC_DIR_PATH"/wp-config.php
printf "【完了】\n\n"
echo "------------------------------ステージング→ローカル環境同期　完了------------------------------"

echo "------------------------------後処理　開始------------------------------"
echo "【Basic認証の設定削除】"
grep -vFf ./.htaccess-basic-auth "$LOCAL_PUBLIC_DIR_PATH"/.htaccess >"$LOCAL_PUBLIC_DIR_PATH"/.htaccess.tmp &&
  mv "$LOCAL_PUBLIC_DIR_PATH"/.htaccess.tmp "$LOCAL_PUBLIC_DIR_PATH"/.htaccess
sed -i '' '/^\n*$/d' "$LOCAL_PUBLIC_DIR_PATH/.htaccess"
printf "【完了】\n\n"

echo "【ローカル環境では不要なプラグインの無効化】"
sh deactivate-plugin-local.sh
printf "【完了】\n\n"
echo "------------------------------後処理　完了------------------------------"
