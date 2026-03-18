#!/bin/bash

# Basic認証を設定（DST_* グローバル変数を参照）
setup_basic_auth() {
  log_info "【Basic認証の設定】"
  log_info "  対象: $DST_PUBLIC_DIR_PATH"

  if {
    ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
        "sed -i '/^[[:space:]]*$/d' \"$DST_PUBLIC_DIR_PATH/.htaccess\""
    ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
        "echo -e \"\n\" >> \"$DST_PUBLIC_DIR_PATH/.htaccess\""
    ssh <"$SITE_DIR/.htaccess-basic-auth" "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
        "cat >> \"$DST_PUBLIC_DIR_PATH\"/.htaccess"
    scp -P "$DST_SSH_PORT" \
        "$SITE_DIR/.htpasswd" \
        "${DST_SSH_DESTINATION}:.htpasswd"
  } >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】Basic認証設定に失敗しました"
    return 1
  fi
}

# Basic認証を削除（DST_* グローバル変数を参照）
remove_basic_auth() {
  log_info "【Basic認証の設定削除】"
  log_info "  対象: $DST_PUBLIC_DIR_PATH"

  if {
    scp -P "$DST_SSH_PORT" \
        "$SITE_DIR/.htaccess-basic-auth" \
        "$SITE_DIR/.env" \
        "$DST_PUBLIC_DIR_SCP_PATH" &&
      ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
        " \
          grep -vFf \"$DST_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$DST_PUBLIC_DIR_PATH\"/.htaccess >\"$DST_PUBLIC_DIR_PATH\"/.htaccess.tmp && \
          mv \"$DST_PUBLIC_DIR_PATH\"/.htaccess.tmp \"$DST_PUBLIC_DIR_PATH\"/.htaccess ; \
          rm \"$DST_PUBLIC_DIR_PATH\"/.htaccess-basic-auth \"$DST_PUBLIC_DIR_PATH\"/.env \
        "
    ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
        "sed -i '/^[[:space:]]*$/d' \"$DST_PUBLIC_DIR_PATH/.htaccess\""
  } >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】Basic認証削除に失敗しました"
    return 1
  fi
}
