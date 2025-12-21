#!/bin/bash
# shellcheck source=/dev/null
# ステージング環境では無効化するプラグイン（本番→ステージング同期後にステージング環境で無効化）

. ./.wp-sync/.env
. "$WP_SYNC_DIR/lib/log.sh"

# カンマ区切りをスペース区切りに変換
plugins=$(echo "$PLUGINS" | tr ',' ' ')

# WordPress キャッシュをクリア（Redis含む全オブジェクトキャッシュ）
log_info "【WordPress キャッシュを削除】"
if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $STG_PUBLIC_DIR_PATH && wp cache flush --allow-root" >/dev/null 2>&1; then
  log_success "【完了】"
else
  log_error "【失敗】WordPress キャッシュの削除に失敗しました"
fi

# Redis Object Cache を無効化（redis-cache がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "redis-cache"; then
    log_info "【Redis Object Cache を無効化】"
    if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $STG_PUBLIC_DIR_PATH && wp redis disable --allow-root" >/dev/null 2>&1; then
      log_success "【完了】"
    else
      log_error "【失敗】Redis Object Cache の無効化に失敗しました"
    fi
fi

# Autoptimize キャッシュを削除（autoptimize がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "autoptimize"; then
    log_info "【Autoptimize キャッシュを削除】"
    if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "cd $STG_PUBLIC_DIR_PATH && wp autoptimize clear --allow-root" >/dev/null 2>&1; then
      log_success "【完了】"
    else
      log_error "【失敗】Autoptimize キャッシュの削除に失敗しました"
    fi
fi

# WP-Optimize キャッシュを削除（wp-optimize がリストに含まれている場合）
if echo "$PLUGINS" | grep -q "wp-optimize"; then
    log_info "【WP-Optimize キャッシュを削除】"
    if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
        "rm -rf $STG_PUBLIC_DIR_PATH/wp-content/cache/wpo-cache/" >/dev/null 2>&1; then
      log_success "【完了】"
    else
      log_error "【失敗】WP-Optimize キャッシュの削除に失敗しました"
    fi
fi

log_info "【プラグインを無効化】"
if ssh "$STG_SSH_DESTINATION" -p "$STG_SSH_PORT" \
    "cd $STG_PUBLIC_DIR_PATH && wp plugin deactivate $plugins --allow-root" >/dev/null 2>&1; then
  log_success "【完了】"
else
  log_error "【失敗】プラグインの無効化に失敗しました"
fi
