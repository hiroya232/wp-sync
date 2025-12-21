#!/bin/bash
# shellcheck source=/dev/null
# ステージング環境では無効化するプラグイン（本番→ステージング同期後にステージング環境で無効化）

. ./.wp-sync/.env
. "$WP_SYNC_DIR/lib/log.sh"

# カンマ区切りをスペース区切りに変換
plugins=$(echo "$PLUGINS" | tr ',' ' ')

# WordPress キャッシュをクリア（Redis含む全オブジェクトキャッシュ）
log_info "【WordPress キャッシュを削除】"
ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $STG_PUBLIC_DIR_PATH && wp cache flush --allow-root" 2>/dev/null || true

# Redis Object Cache を無効化（redis-cache がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "redis-cache"; then
    log_info "【Redis Object Cache を無効化】"
    ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $STG_PUBLIC_DIR_PATH && wp redis disable --allow-root" 2>/dev/null || true
fi

# Autoptimize キャッシュを削除（autoptimize がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "autoptimize"; then
    log_info "【Autoptimize キャッシュを削除】"
    ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $STG_PUBLIC_DIR_PATH && wp autoptimize clear --allow-root" 2>/dev/null || true
fi

# WP-Optimize キャッシュを削除（wp-optimize がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "wp-optimize"; then
    log_info "【WP-Optimize キャッシュを削除】"
    ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "rm -rf $STG_PUBLIC_DIR_PATH/wp-content/cache/wpo-cache/" 2>/dev/null || true
fi

ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $STG_PUBLIC_DIR_PATH && wp plugin deactivate $plugins --allow-root"
