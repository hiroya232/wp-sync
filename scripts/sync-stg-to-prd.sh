#!/bin/sh
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

# 設定ファイルの読み込み
. ./.wp-sync/.env

echo "------------------------------前処理　開始------------------------------"
echo "【本番環境で必要なプラグインの有効化】"
sh activate-plugin.sh
printf "【完了】\n\n"
echo "------------------------------前処理　完了------------------------------"

echo "------------------------------本番環境バックアップ　開始------------------------------"
echo "【DBをバックアップ】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  mysqldump \
  -u"$PRD_DB_USER" \
  -p"$PRD_DB_PASSWORD" \
  -h"$PRD_DB_HOST" \
  "$PRD_DB_NAME" --no-tablespaces >"$PRD_DB_DUMP_FILE_PATH"
printf "【完了】\n\n"

echo "【public_htmlをバックアップ】"
rsync --checksum -arv --delete \
  -e "ssh -p \"$PRD_SSH_PORT\"" \
  --exclude "$STG_DOMAIN" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/ "$PRD_FILE_BACKUP_DIR_PATH"/
printf "【完了】\n\n"
echo "------------------------------本番環境バックアップ　完了------------------------------"

echo "------------------------------ステージング→本番環境同期　開始------------------------------"
echo "【DBを同期】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
  mysqldump \
  -u"$STG_DB_USER" \
  -p"$STG_DB_PASSWORD" \
  -h"$STG_DB_HOST" \
  "$STG_DB_NAME" \
  --no-tablespaces |
  ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
    mysql \
    -u"$PRD_DB_USER" \
    -p"$PRD_DB_PASSWORD" \
    -h"$PRD_DB_HOST" \
    "$PRD_DB_NAME"
printf "【完了】\n\n"

echo "【public_htmlを同期】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  rsync --checksum -arv --delete \
  --exclude "$STG_DOMAIN" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$STG_PUBLIC_DIR_PATH"/ "$PRD_PUBLIC_DIR_PATH"/
printf "【完了】\n\n"

echo "【wp-config.phpを置換】"
scp -P "$PRD_SSH_PORT" \
  ./.wp-sync/wp-config-prd.php "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"

echo "【ドメインを置換】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  "cd \"$PRD_PUBLIC_DIR_PATH\" && wp search-replace \"https://${STG_DOMAIN}\" \"https://${PRD_DOMAIN}\" --all-tables"
printf "【完了】\n\n"
echo "------------------------------ステージング→本番環境同期　完了------------------------------"

echo "------------------------------後処理　開始------------------------------"
echo "【Basic認証の設定削除】"
scp -P "$PRD_SSH_PORT" ./.wp-sync/.htaccess-basic-auth ./.wp-sync/.env "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION" &&
  ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
    " \
      grep -vFf \"$PRD_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$PRD_PUBLIC_DIR_PATH\"/.htaccess >\"$PRD_PUBLIC_DIR_PATH\"/.htaccess.tmp &&
        mv \"$PRD_PUBLIC_DIR_PATH\"/.htaccess.tmp \"$PRD_PUBLIC_DIR_PATH\"/.htaccess ;
        rm \"$PRD_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$PRD_PUBLIC_DIR_PATH\"/.env \
    "
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" "sed -i '/^\n*$/d' \"$PRD_PUBLIC_DIR_PATH/.htaccess\""
printf "【完了】\n\n"

echo "【ステージング環境では不要なプラグインの無効化】"
sh deactivate-plugin.sh
printf "【完了】\n\n"
echo "------------------------------後処理　完了------------------------------"
