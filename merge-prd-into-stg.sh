#!/bin/sh
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

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

echo "------------------------------本番→ステージング環境同期　開始------------------------------"
echo "【DBを同期】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  mysqldump \
  -u"$PRD_DB_USER" \
  -p"$PRD_DB_PASSWORD" \
  -h"$PRD_DB_HOST" \
  "$PRD_DB_NAME" \
  --no-tablespaces |
  ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    mysql \
    -u"$STG_DB_USER" \
    -p"$STG_DB_PASSWORD" \
    -h"$STG_DB_HOST" \
    "$STG_DB_NAME"
printf "【完了】\n\n"

echo "【public_htmlを同期】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  rsync --checksum -arv --delete \
  --exclude "$STG_DOMAIN" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$PRD_PUBLIC_DIR_PATH"/ "$STG_PUBLIC_DIR_PATH"
printf "【完了】\n\n"

echo "【wp-config.phpを置換】"
scp -P "$STG_SSH_PORT" \
  ./wp-config-stg.php "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"

echo "【ドメインを置換】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  "cd \"$STG_PUBLIC_DIR_PATH\" && wp search-replace \"https://${PRD_DOMAIN}\" \"https://${STG_DOMAIN}\" --all-tables"
printf "【完了】\n\n"
echo "------------------------------本番→ステージング環境同期　完了------------------------------"

echo "------------------------------後処理　開始------------------------------"
echo "【Basic認証の設定】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "sed -i '/^\n*$/d' \"$STG_PUBLIC_DIR_PATH/.htaccess\""
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "echo -e \"\n\" >> \"$STG_PUBLIC_DIR_PATH/.htaccess\""
ssh <./.htaccess-basic-auth "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" "cat >> \"$STG_PUBLIC_DIR_PATH\"/.htaccess"
scp -P "$STG_SSH_PORT" \
  ./.htpasswd "$HTPASSWD_PATH_WITH_DESTINATION"/.htpasswd
printf "【完了】\n\n"

echo "【ステージング環境では不要なプラグインの無効化】"
sh deactivate-plugin-stg.sh
printf "【完了】\n\n"
echo "------------------------------後処理　完了------------------------------"
