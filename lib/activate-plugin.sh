#!/bin/bash
# shellcheck source=/dev/null
# 本番環境でのみ有効化するプラグイン（ステージング→本番同期前にステージング環境で有効化）

. ./.wp-sync/.env
. "$WP_SYNC_DIR/lib/log.sh"

SSH_TARGET="--ssh=$STG_SSH_DESTINATION:$STG_SSH_PORT$STG_PUBLIC_DIR_PATH"

wp plugin activate $PLUGINS_TO_ACTIVATE $SSH_TARGET --allow-root

# Redis Object Cache を有効化（redis-cache がリストに含まれている場合）
if echo "$PLUGINS_TO_ACTIVATE" | grep -q "redis-cache"; then
    log_info "【Redis Object Cache を有効化】"
    wp redis enable $SSH_TARGET --allow-root
fi
