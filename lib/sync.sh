#!/bin/bash

# DBを同期（SRC_* / DST_* グローバル変数を参照）
sync_db() {
  log_info "【DBを同期】"
  log_info "  コピー元: $SRC_DB_NAME@$SRC_DB_HOST"
  log_info "  コピー先: $DST_DB_NAME@$DST_DB_HOST"

  if ssh "$SRC_SSH_DESTINATION" -p "$SRC_SSH_PORT" \
    "$(remote_mysql_cmd mysqldump "$SRC_DB_USER" "$SRC_DB_HOST" "$SRC_DB_NAME" --no-tablespaces)" \
    < <(printf '%s\n' "$SRC_DB_PASSWORD") 2>/dev/null |
    { printf '%s\n' "$DST_DB_PASSWORD" && cat; } |
    ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
      "$(remote_mysql_cmd mysql "$DST_DB_USER" "$DST_DB_HOST" "$DST_DB_NAME")" 2>/dev/null; then
    log_success "【完了】"
  else
    log_error "【失敗】DB同期に失敗しました"
    return 1
  fi
}

# ファイルを同期
# 引数: $1=除外パス(カンマ区切り)
# SRC_SSH_DESTINATION / SRC_SSH_PORT / SRC_PUBLIC_DIR_PATH / DST_PUBLIC_DIR_PATH を参照
sync_files() {
  local excludes="$1"

  log_info "【public_htmlを同期】"
  log_info "  コピー元: $SRC_PUBLIC_DIR_PATH"
  log_info "  コピー先: $DST_PUBLIC_DIR_PATH"

  # リモートで実行するコマンドを、値をクォートして構築
  local remote_cmd="rsync --checksum -arv --delete"
  IFS=','
  for exclude in $excludes; do
    remote_cmd="$remote_cmd --exclude $(shq "$exclude")"
  done
  unset IFS
  remote_cmd="$remote_cmd $(shq "$SRC_PUBLIC_DIR_PATH")/ $(shq "$DST_PUBLIC_DIR_PATH")"

  if ssh "$SRC_SSH_DESTINATION" -p "$SRC_SSH_PORT" \
    "$remote_cmd" >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】ファイル同期に失敗しました"
    return 1
  fi
}

# PHPスクリプトをリモートで実行する共通ヘルパー
# スクリプトは ssh の標準入力で渡し、リモートに一時ファイルを作らない
# 引数: $1=SSH接続先, $2=SSHポート, $3=ローカルPHPスクリプト, [追加引数...]
# 標準出力は呼び出し元に返す。標準エラーはログに追記。
_run_remote_php() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local local_script="$3"
  shift 3

  local quoted_args=""
  for arg in "$@"; do
    quoted_args="$quoted_args $(shq "$arg")"
  done

  ssh "$ssh_dest" -p "$ssh_port" \
    "php --$quoted_args" \
    <"$local_script" 2>>"$(get_log_file)"
}

# wp-config.phpの環境固有定数を復元
# DST_SSH_DESTINATION / DST_SSH_PORT / DST_PUBLIC_DIR_PATH / WP_CONFIG_TMP_FILE を参照
restore_wp_config_constants() {
  local preserve_constants="$1"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  log_info "【wp-config.phpの環境固有定数を復元】"
  log_info "  対象: $DST_PUBLIC_DIR_PATH/wp-config.php"

  if _run_remote_php "$DST_SSH_DESTINATION" "$DST_SSH_PORT" "$script_dir/restore-constants.php" \
    "$preserve_constants" "$DST_PUBLIC_DIR_PATH/$WP_CONFIG_TMP_FILE" "$DST_PUBLIC_DIR_PATH/wp-config.php" \
    >> "$(get_log_file)"; then
    log_success "【完了】"
  else
    log_error "【失敗】wp-config.php定数復元に失敗しました"
    return 1
  fi
}

# wp-config.phpの環境固有定数を動的検出
# DST_SSH_DESTINATION / DST_SSH_PORT / SRC_PUBLIC_DIR_PATH / DST_PUBLIC_DIR_PATH / WP_CONFIG_TMP_FILE を参照
detect_preserve_constants() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local result
  result=$(_run_remote_php "$DST_SSH_DESTINATION" "$DST_SSH_PORT" "$script_dir/diff-constants.php" \
    "$SRC_PUBLIC_DIR_PATH/wp-config.php" \
    "$DST_PUBLIC_DIR_PATH/$WP_CONFIG_TMP_FILE")
  local exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    log_error "【失敗】定数差分検出に失敗しました"
    return 1
  fi

  echo "$result"
}

# コピー先のwp-config.phpを退避
# DST_SSH_DESTINATION / DST_SSH_PORT / DST_PUBLIC_DIR_PATH / WP_CONFIG_TMP_FILE を参照
backup_wp_config() {
  log_info "【コピー先のwp-config.phpを退避】"
  if ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    "cp $(shq "$DST_PUBLIC_DIR_PATH/wp-config.php") $(shq "$DST_PUBLIC_DIR_PATH/$WP_CONFIG_TMP_FILE")" \
    >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】wp-config.php退避に失敗しました"
    return 1
  fi
}

# 退避したwp-config.phpを削除
# DST_SSH_DESTINATION / DST_SSH_PORT / DST_PUBLIC_DIR_PATH / WP_CONFIG_TMP_FILE を参照
remove_wp_config_backup() {
  ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    "rm -f $(shq "$DST_PUBLIC_DIR_PATH/$WP_CONFIG_TMP_FILE")" >> "$(get_log_file)" 2>&1
}

# ドメインを置換
# DST_SSH_DESTINATION / DST_SSH_PORT / DST_PUBLIC_DIR_PATH / SRC_DOMAIN / DST_DOMAIN / DST_DB_NAME を参照
replace_domain() {
  log_info "【ドメインを置換】"
  log_info "  置換前: https://$SRC_DOMAIN"
  log_info "  置換後: https://$DST_DOMAIN"

  # wp-config.php の DB接続先を検証（親ディレクトリへのフォールバック防止）
  local actual_db_name
  actual_db_name=$(ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    "cd $(shq "$DST_PUBLIC_DIR_PATH") && wp config get DB_NAME" 2>/dev/null)
  if [ "$actual_db_name" != "$DST_DB_NAME" ]; then
    log_error "【失敗】wp-config.php のDB接続先が不正です（期待: $DST_DB_NAME, 実際: $actual_db_name）"
    log_error "  wp-config.php の内容を確認してください"
    return 1
  fi

  if ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    "cd $(shq "$DST_PUBLIC_DIR_PATH") && \
     wp search-replace $(shq "https://${SRC_DOMAIN}") $(shq "https://${DST_DOMAIN}") --all-tables" \
    >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】ドメイン置換に失敗しました"
    return 1
  fi
}
