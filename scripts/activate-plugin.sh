#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
# 本番環境でのみ有効化するプラグイン（ステージング→本番同期前にステージング環境で有効化）

. "$SITE_DIR/.env"
. "$WP_SYNC_DIR/lib/log.sh"
. "$WP_SYNC_DIR/lib/env.sh"

# shellcheck disable=SC2153
plugins="$(quote_plugin_list "$PLUGINS")"
stg_dir=$(shq "$STG_PUBLIC_DIR_PATH")

log_info "【プラグインを有効化】"
if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $stg_dir && wp plugin activate$plugins --allow-root" >/dev/null 2>&1; then
  log_success "【完了】"
else
  log_error "【失敗】プラグインの有効化に失敗しました"
fi

# Redis Object Cache を有効化（redis-cache がリストに含まれている場合）
if [[ "$PLUGINS" == *"redis-cache"* ]]; then
    log_info "【Redis Object Cache を有効化】"
    if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $stg_dir && wp redis enable --allow-root" >/dev/null 2>&1; then
      log_success "【完了】"
    else
      log_error "【失敗】Redis Object Cache の有効化に失敗しました"
    fi
fi
