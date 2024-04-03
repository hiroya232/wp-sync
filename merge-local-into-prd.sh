#!/bin/sh
# shellcheck source=/dev/null

. ./.env

echo "------------------------------前処理　開始------------------------------"
echo "【本番環境で必要なプラグインの有効化】"
sh activate-plugin-local.sh
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

echo "------------------------------ローカル→本番環境同期　開始------------------------------"
echo "【DBを同期】"
mysqldump \
  -u"$LOCAL_DB_USER" \
  -p"$LOCAL_DB_PASSWORD" \
  -h"$LOCAL_DB_HOST" \
  -P"$LOCAL_DB_PORT" \
  "$LOCAL_DB_NAME" \
  --column-statistics=0 --no-tablespaces |
  ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
    mysql \
    -u"$PRD_DB_USER" \
    -p"$PRD_DB_PASSWORD" \
    -h"$PRD_DB_HOST" \
    "$PRD_DB_NAME"
printf "【完了】\n\n"

echo "【ドメインを置換】"
ssh "$PRD_SSH_DESTINATION" -p "$PRD_SSH_PORT" \
  /usr/bin/php7.3 srdb.cli.php \
  -h "$PRD_DB_HOST" \
  -u "$PRD_DB_USER" \
  -p "$PRD_DB_PASSWORD" \
  -n "$PRD_DB_NAME" \
  -s "http://${LOCAL_DOMAIN}" -r "https://${PRD_DOMAIN}"
printf "【完了】\n\n"

echo "【public_htmlを同期】"
rsync --checksum -arv --delete \
  -e "ssh -p ${PRD_SSH_PORT}" \
  --exclude "$STG_DOMAIN" \
  --exclude "$WORDPRESS_CACHE_DIR_PATH" \
  --exclude "$BACKWPUP_LOG_DIR_PATH" \
  --exclude "$BACKWPUP_TEMP_DIR_PATH" \
  "$LOCAL_PUBLIC_DIR_PATH"/ "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/
printf "【完了】\n\n"

echo "【wp-config.phpを置換】"
scp -P "$PRD_SSH_PORT" \
  ./wp-config-prd.php "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"/wp-config.php
printf "【完了】\n\n"
echo "------------------------------ローカル→本番環境同期　開始------------------------------"

echo "------------------------------後処理　開始------------------------------"
echo "【ローカル環境では不要なプラグインの無効化】"
sh deactivate-plugin-local.sh
printf "【完了】\n\n"
echo "------------------------------後処理　完了------------------------------"
