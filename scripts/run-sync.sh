#!/bin/bash
# shellcheck source=/dev/null
# 本番とステージングが同じサーバーにあることが前提

DIRECTION="$1"

if [ "$DIRECTION" != "prd-to-stg" ] && [ "$DIRECTION" != "stg-to-prd" ]; then
  echo "エラー: 無効な方向です。prd-to-stg または stg-to-prd を指定してください。" >&2
  exit 1
fi

. "$SITE_DIR/.env"

. "$WP_SYNC_DIR/lib/backup.sh"
. "$WP_SYNC_DIR/lib/sync.sh"
. "$WP_SYNC_DIR/lib/basic-auth.sh"

setup_sync_env "$DIRECTION"

if [ "$DIRECTION" = "stg-to-prd" ]; then
  log_header "前処理　開始"
  log_info "【本番環境で必要なプラグインの有効化】"
  bash "$WP_SYNC_DIR/scripts/activate-plugin.sh"
  log_success "【完了】"
  log_header "前処理　完了"
fi

log_header "${DST_LABEL}環境バックアップ　開始"
backup_db
backup_files
mark_backup_completed
log_header "${DST_LABEL}環境バックアップ　完了"

log_header "${SRC_LABEL}→${DST_LABEL}環境同期　開始"
sync_db
WP_CONFIG_TMP_FILE="wp-config-tmp.php"
backup_wp_config || exit 1
sync_files "$WP_CONFIG_TMP_FILE,$STG_DOMAIN,$EXCLUDES"
# 本番の .htaccess で上書きされたステージングを、同期直後に保護する
if [ "$DIRECTION" = "prd-to-stg" ]; then
  setup_basic_auth
fi
log_info "【wp-config.phpの環境固有定数を自動検出】"
PRESERVE_CONSTANTS=$(detect_preserve_constants) || exit 1
log_info "  保持する定数: ${PRESERVE_CONSTANTS:-（なし）}"
log_success "【完了】"
if [ -n "$PRESERVE_CONSTANTS" ]; then
  restore_wp_config_constants "$PRESERVE_CONSTANTS" || exit 1
else
  remove_wp_config_backup
fi
replace_domain
log_header "${SRC_LABEL}→${DST_LABEL}環境同期　完了"

# バックアップのアーカイブ
archive_backup

# 後処理
log_header "後処理　開始"

# 本番環境からBasic認証を削除（ステージングへの設定は同期直後に実施済み）
if [ "$DIRECTION" = "stg-to-prd" ]; then
  remove_basic_auth
fi

# プラグイン無効化（両方向で共通）
log_info "【ステージング環境では不要なプラグインの無効化】"
bash "$WP_SYNC_DIR/scripts/deactivate-plugin.sh"
log_success "【完了】"
log_header "後処理　完了"
