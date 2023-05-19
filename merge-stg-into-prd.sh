#!/bin/sh
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

. "$1"/.env

echo "【本番のDBをバックアップ】"
ssh "$PRD_SERVER_HOST" -p "$PRD_SERVER_PORT" \
  mysqldump -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" --no-tablespaces >"$1"/"$BACKUP_PRD"
#ファイルがない場合は終了
if [ ! -s "$1"/"$BACKUP_PRD" ]; then
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

echo "【ステージングのpublic_htmlを本番にコピー】"
ssh "$PRD_SERVER_HOST" -p "$PRD_SERVER_PORT" \
  rsync --checksum -arv --delete \
  --exclude "$STG_DOMAIN" --exclude "$BACKWPUP_DIR" --exclude "${BACKWPUP_DIR}*" --exclude "$CACHE_DIR" \
  "$STG_PUBLIC_DIR_PATH"/ "$PRD_PUBLIC_DIR_PATH"/
printf "【完了】\n\n"

echo "【wp-config.phpの内容を本番環境のものに書き換え】"
scp -P "$PRD_SERVER_PORT" \
  "$1"/wp-config-prd.php "$PRD_PUBLIC_DIR"/wp-config.php
printf "【完了】\n\n"

echo "【Basic認証の設定削除】"
scp -P "$PRD_SERVER_PORT" "$1"/.htaccess-basic-auth "$1"/.env "$PRD_PUBLIC_DIR" &&
  ssh "$PRD_SERVER_HOST" -p "$PRD_SERVER_PORT" \
    " \
      grep -vFf \"$PRD_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$PRD_PUBLIC_DIR_PATH\"/.htaccess >\"$PRD_PUBLIC_DIR_PATH\"/.htaccess.tmp &&
        mv \"$PRD_PUBLIC_DIR_PATH\"/.htaccess.tmp \"$PRD_PUBLIC_DIR_PATH\"/.htaccess ;
        rm \"$PRD_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$PRD_PUBLIC_DIR_PATH\"/.env \
    "
printf "【完了】\n\n"

echo "【本番のDBをステージングのDBで上書き】"
ssh "$PRD_SERVER_HOST" -p "$PRD_SERVER_PORT" \
  mysql -u"$PRD_DB_USER" -p"$PRD_DB_PASSWORD" -h"$PRD_DB_HOST" "$PRD_DB_NAME" <"$1"/"$BACKUP_STG"
printf "【完了】\n\n"

echo "【本番のDB内のドメイン部分を書き換え】"
ssh "$PRD_SERVER_HOST" -p "$PRD_SERVER_PORT" \
  /usr/bin/php7.3 srdb.cli.php -h "$PRD_DB_HOST" -u "$PRD_DB_USER" -p "$PRD_DB_PASSWORD" -n "$PRD_DB_NAME" -s "https://${STG_DOMAIN}" -r "https://${PRD_DOMAIN}"
printf "【完了】\n\n"
