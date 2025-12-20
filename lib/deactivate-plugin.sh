#!/bin/bash
# shellcheck source=/dev/null
# ステージング環境では無効化するプラグイン（本番→ステージング同期後にステージング環境で無効化）

. ./.wp-sync/.env
. "$WP_SYNC_DIR/lib/log.sh"

SSH_TARGET="--ssh=$STG_SSH_DESTINATION:$STG_SSH_PORT$STG_PUBLIC_DIR_PATH"

# WordPress キャッシュをクリア（Redis含む全オブジェクトキャッシュ）
log_info "【WordPress キャッシュを削除】"
wp cache flush $SSH_TARGET --allow-root 2>/dev/null || true

# Redis Object Cache を無効化（redis-cache がリストに含まれている場合）
if echo "$PLUGINS_TO_DEACTIVATE" | grep -q "redis-cache"; then
    log_info "【Redis Object Cache を無効化】"
    wp redis disable $SSH_TARGET --allow-root 2>/dev/null || true
fi

# Autoptimize キャッシュを削除（autoptimize がリストに含まれている場合）
if echo "$PLUGINS_TO_DEACTIVATE" | grep -q "autoptimize"; then
    log_info "【Autoptimize キャッシュを削除】"
    wp autoptimize clear $SSH_TARGET --allow-root 2>/dev/null || true
fi

# WP-Optimize キャッシュを削除（wp-optimize がリストに含まれている場合）
if echo "$PLUGINS_TO_DEACTIVATE" | grep -q "wp-optimize"; then
    log_info "【WP-Optimize キャッシュを削除】"
    ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "rm -rf $STG_PUBLIC_DIR_PATH/wp-content/cache/wpo-cache/" 2>/dev/null || true
fi

wp plugin deactivate $PLUGINS_TO_DEACTIVATE $SSH_TARGET --allow-root
