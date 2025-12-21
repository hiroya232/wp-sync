#!/bin/bash
# shellcheck source=/dev/null
# 本番環境でのみ有効化するプラグイン（ステージング→本番同期前にステージング環境で有効化）

. ./.wp-sync/.env
. "$WP_SYNC_DIR/lib/log.sh"

# カンマ区切りをスペース区切りに変換
plugins=$(echo "$PLUGINS" | tr ',' ' ')

ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $STG_PUBLIC_DIR_PATH && wp plugin activate $plugins --allow-root"

# Redis Object Cache を有効化（redis-cache がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "redis-cache"; then
    log_info "【Redis Object Cache を有効化】"
    ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $STG_PUBLIC_DIR_PATH && wp redis enable --allow-root" 2>/dev/null || true
fi
