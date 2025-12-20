#!/bin/bash
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

# 設定ファイルの読み込み
. ./.wp-sync/.env

# ライブラリの読み込み
. "$WP_SYNC_DIR/lib/backup.sh"
. "$WP_SYNC_DIR/lib/sync.sh"
. "$WP_SYNC_DIR/lib/basic-auth.sh"
# restore.sh は bin/wp-sync で読み込み済み

log_header "前処理　開始"
log_info "【本番環境で必要なプラグインの有効化】"
sh "$WP_SYNC_DIR/lib/activate-plugin.sh"
log_success "【完了】"
log_header "前処理　完了"

log_header "本番環境バックアップ　開始"
backup_db \
	"$PRD_SSH_DESTINATION" \
	"$PRD_SSH_PORT" \
	"$PRD_DB_USER" \
	"$PRD_DB_PASSWORD" \
	"$PRD_DB_HOST" \
	"$PRD_DB_NAME" \
	"$PRD_DB_DUMP_FILE_PATH"
backup_files \
	"$PRD_SSH_PORT" \
	"$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION" \
	"$PRD_FILE_BACKUP_DIR_PATH" \
	"$STG_DOMAIN,$EXCLUDES"
mark_backup_completed
log_header "本番環境バックアップ　完了"

log_header "ステージング→本番環境同期　開始"
sync_db \
	"$STG_SSH_DESTINATION" \
	"$STG_SSH_PORT" \
	"$STG_DB_USER" \
	"$STG_DB_PASSWORD" \
	"$STG_DB_HOST" \
	"$STG_DB_NAME" \
	"$PRD_SSH_DESTINATION" \
	"$PRD_SSH_PORT" \
	"$PRD_DB_USER" \
	"$PRD_DB_PASSWORD" \
	"$PRD_DB_HOST" \
	"$PRD_DB_NAME"
sync_files \
	"$PRD_SSH_DESTINATION" \
	"$PRD_SSH_PORT" \
	"$STG_PUBLIC_DIR_PATH" \
	"$PRD_PUBLIC_DIR_PATH" \
	"$STG_DOMAIN,$EXCLUDES"
replace_wp_config \
	"$PRD_SSH_PORT" \
	"./.wp-sync/wp-config-prd.php" \
	"$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"
replace_domain \
	"$PRD_SSH_DESTINATION" \
	"$PRD_SSH_PORT" \
	"$PRD_PUBLIC_DIR_PATH" \
	"$STG_DOMAIN" \
	"$PRD_DOMAIN"
log_header "ステージング→本番環境同期　完了"

log_header "後処理　開始"
remove_basic_auth \
	"$PRD_SSH_DESTINATION" \
	"$PRD_SSH_PORT" \
	"$PRD_PUBLIC_DIR_PATH" \
	"./.wp-sync/.htaccess-basic-auth" \
	"./.wp-sync/.env" \
	"$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION"

log_info "【ステージング環境では不要なプラグインの無効化】"
sh "$WP_SYNC_DIR/lib/deactivate-plugin.sh"
log_success "【完了】"
log_header "後処理　完了"
