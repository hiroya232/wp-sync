#!/bin/bash
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

# 方向の取得（prd-to-stg または stg-to-prd）
DIRECTION="$1"

if [ "$DIRECTION" != "prd-to-stg" ] && [ "$DIRECTION" != "stg-to-prd" ]; then
  echo "エラー: 無効な方向です。prd-to-stg または stg-to-prd を指定してください。" >&2
  exit 1
fi

# 設定ファイルの読み込み
. ./.wp-sync/.env

# ライブラリの読み込み
. "$WP_SYNC_DIR/lib/backup.sh"
. "$WP_SYNC_DIR/lib/sync.sh"
. "$WP_SYNC_DIR/lib/basic-auth.sh"

# 方向に応じてプレフィックスを設定
if [ "$DIRECTION" = "stg-to-prd" ]; then
  SRC_PREFIX="STG"
  DST_PREFIX="PRD"
  DST_WP_CONFIG="./.wp-sync/wp-config-prd.php"
  BACKUP_EXCLUDES="$STG_DOMAIN,$EXCLUDES"
else
  SRC_PREFIX="PRD"
  DST_PREFIX="STG"
  DST_WP_CONFIG="./.wp-sync/wp-config-stg.php"
  BACKUP_EXCLUDES="$EXCLUDES"
fi

# 同期元の接続情報
SRC_SSH_DESTINATION="${SRC_PREFIX}_SSH_DESTINATION"
SRC_SSH_PORT="${SRC_PREFIX}_SSH_PORT"
SRC_DB_USER="${SRC_PREFIX}_DB_USER"
SRC_DB_PASSWORD="${SRC_PREFIX}_DB_PASSWORD"
SRC_DB_HOST="${SRC_PREFIX}_DB_HOST"
SRC_DB_NAME="${SRC_PREFIX}_DB_NAME"
SRC_PUBLIC_DIR_PATH="${SRC_PREFIX}_PUBLIC_DIR_PATH"
SRC_DOMAIN="${SRC_PREFIX}_DOMAIN"

# 同期先の接続情報
DST_SSH_DESTINATION="${DST_PREFIX}_SSH_DESTINATION"
DST_SSH_PORT="${DST_PREFIX}_SSH_PORT"
DST_DB_USER="${DST_PREFIX}_DB_USER"
DST_DB_PASSWORD="${DST_PREFIX}_DB_PASSWORD"
DST_DB_HOST="${DST_PREFIX}_DB_HOST"
DST_DB_NAME="${DST_PREFIX}_DB_NAME"
DST_DB_DUMP_FILE_PATH="${DST_PREFIX}_DB_DUMP_FILE_PATH"
DST_PUBLIC_DIR_PATH="${DST_PREFIX}_PUBLIC_DIR_PATH"
DST_PUBLIC_DIR_PATH_WITH_DESTINATION="${DST_PREFIX}_PUBLIC_DIR_PATH_WITH_DESTINATION"
DST_FILE_BACKUP_DIR_PATH="${DST_PREFIX}_FILE_BACKUP_DIR_PATH"
DST_DOMAIN="${DST_PREFIX}_DOMAIN"

# 前処理（stg-to-prd の場合のみ）
if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "前処理　開始"
  log_info "【本番環境で必要なプラグインの有効化】"
  bash "$WP_SYNC_DIR/lib/activate-plugin.sh"
  log_success "【完了】"
  log_header "前処理　完了"
fi

# バックアップ（同期先環境をバックアップ）
if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "本番環境バックアップ　開始"
else
  log_header "ステージング環境バックアップ　開始"
fi
backup_db \
  "${!DST_SSH_DESTINATION}" \
  "${!DST_SSH_PORT}" \
  "${!DST_DB_USER}" \
  "${!DST_DB_PASSWORD}" \
  "${!DST_DB_HOST}" \
  "${!DST_DB_NAME}" \
  "${!DST_DB_DUMP_FILE_PATH}"
backup_files \
  "${!DST_SSH_PORT}" \
  "${!DST_PUBLIC_DIR_PATH_WITH_DESTINATION}" \
  "${!DST_FILE_BACKUP_DIR_PATH}" \
  "$BACKUP_EXCLUDES"
mark_backup_completed
if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "本番環境バックアップ　完了"
else
  log_header "ステージング環境バックアップ　完了"
fi

# 同期処理
if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "ステージング→本番環境同期　開始"
else
  log_header "本番→ステージング環境同期　開始"
fi
sync_db \
  "${!SRC_SSH_DESTINATION}" \
  "${!SRC_SSH_PORT}" \
  "${!SRC_DB_USER}" \
  "${!SRC_DB_PASSWORD}" \
  "${!SRC_DB_HOST}" \
  "${!SRC_DB_NAME}" \
  "${!DST_SSH_DESTINATION}" \
  "${!DST_SSH_PORT}" \
  "${!DST_DB_USER}" \
  "${!DST_DB_PASSWORD}" \
  "${!DST_DB_HOST}" \
  "${!DST_DB_NAME}"
sync_files \
  "${!SRC_SSH_DESTINATION}" \
  "${!SRC_SSH_PORT}" \
  "${!SRC_PUBLIC_DIR_PATH}" \
  "${!DST_PUBLIC_DIR_PATH}" \
  "$STG_DOMAIN,$EXCLUDES"
replace_wp_config \
  "${!DST_SSH_PORT}" \
  "$DST_WP_CONFIG" \
  "${!DST_PUBLIC_DIR_PATH_WITH_DESTINATION}"
replace_domain \
  "${!DST_SSH_DESTINATION}" \
  "${!DST_SSH_PORT}" \
  "${!DST_PUBLIC_DIR_PATH}" \
  "${!SRC_DOMAIN}" \
  "${!DST_DOMAIN}"
if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "ステージング→本番環境同期　完了"
else
  log_header "本番→ステージング環境同期　完了"
fi

# 後処理
log_header "後処理　開始"

# Basic認証の処理（方向によって異なる）
if [ "$DIRECTION" = "stg-to-prd" ]; then
  # 本番環境からBasic認証を削除
  remove_basic_auth \
    "${!DST_SSH_DESTINATION}" \
    "${!DST_SSH_PORT}" \
    "${!DST_PUBLIC_DIR_PATH}" \
    "./.wp-sync/.htaccess-basic-auth" \
    "./.wp-sync/.env" \
    "${!DST_PUBLIC_DIR_PATH_WITH_DESTINATION}"
else
  # ステージング環境にBasic認証を設定
  setup_basic_auth \
    "${!DST_SSH_DESTINATION}" \
    "${!DST_SSH_PORT}" \
    "${!DST_PUBLIC_DIR_PATH}" \
    "./.wp-sync/.htaccess-basic-auth" \
    "./.wp-sync/.htpasswd" \
    "$HTPASSWD_PATH_WITH_DESTINATION"
fi

# プラグイン無効化（両方向で共通）
log_info "【ステージング環境では不要なプラグインの無効化】"
bash "$WP_SYNC_DIR/lib/deactivate-plugin.sh"
log_success "【完了】"
log_header "後処理　完了"
