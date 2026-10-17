#!/bin/bash

# タイムスタンプ付きバックアップZIPの中で最新のものを返す（DST_BACKUP_ZIP_PATH を参照）
_find_backup_zip() {
  local zip_prefix="${DST_BACKUP_ZIP_PATH%.zip}"
  local latest=""
  for f in "${zip_prefix}_"*.zip; do
    [ -f "$f" ] || continue
    if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then
      latest="$f"
    fi
  done
  echo "$latest"
}

# バックアップZIPから指定メンバーを展開し、出力をログに追記する
# 引数: $1=展開先ディレクトリ, $2=ZIPファイルのパス, $3=展開するメンバー
_extract_from_backup_zip() {
  local tmp_dir="$1" zip_file="$2" member="$3"
  if ! (cd "$tmp_dir" && unzip -o "${zip_file##*/}" "$member") >> "$(get_log_file)" 2>&1; then
    log_error "ZIP解凍に失敗しました: $zip_file"
    return 1
  fi
}

BACKUP_COMPLETED=false

# リストア時の同期方向（stg-to-prd または prd-to-stg）
RESTORE_DIRECTION=""

mark_backup_completed() {
  BACKUP_COMPLETED=true
  log_info "バックアップ完了をマークしました"
}

# リストア時の同期方向を設定
# 引数: $1=方向（stg-to-prd または prd-to-stg）
set_restore_direction() {
  RESTORE_DIRECTION="$1"
}

# DBをリストア（DST_* グローバル変数を参照）
restore_db() {
  log_info "【DBをリストア】"
  log_info "  ダンプファイル: $DST_DB_DUMP_FILE_PATH"
  log_info "  リストア先: $DST_DB_NAME@$DST_DB_HOST"

  if [ ! -f "$DST_DB_DUMP_FILE_PATH" ]; then
    local latest_zip
    latest_zip="$(_find_backup_zip)"
    if [ -n "$latest_zip" ]; then
      log_info "ZIPからダンプファイルを解凍中: $latest_zip"
      _extract_from_backup_zip "${DST_DB_DUMP_FILE_PATH%/*}" "$latest_zip" "${DST_DB_DUMP_FILE_PATH##*/}" || return 1
    else
      log_error "ダンプファイルが見つかりません: $DST_DB_DUMP_FILE_PATH"
      return 1
    fi
  fi

  if { printf '%s\n' "$DST_DB_PASSWORD" && cat "$DST_DB_DUMP_FILE_PATH"; } |
    ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
      "$(remote_mysql_cmd mysql "$DST_DB_USER" "$DST_DB_HOST" "$DST_DB_NAME")" 2>/dev/null; then
    log_success "【完了】DBリストア成功"
  else
    log_error "【失敗】DBリストアに失敗しました"
    return 1
  fi
}

# ファイルをリストア（DST_* / BACKUP_EXCLUDES グローバル変数を参照）
restore_files() {
  log_info "【ファイルをリストア】"
  log_info "  バックアップ: $DST_FILE_BACKUP_DIR_PATH"
  log_info "  リストア先: $DST_PUBLIC_DIR_SCP_PATH"

  if [ ! -d "$DST_FILE_BACKUP_DIR_PATH" ]; then
    local latest_zip
    latest_zip="$(_find_backup_zip)"
    if [ -n "$latest_zip" ]; then
      log_info "ZIPからファイルバックアップを解凍中: $latest_zip"
      local tmp_dir="${DST_FILE_BACKUP_DIR_PATH%/*}"
      _extract_from_backup_zip "$tmp_dir" "$latest_zip" "public_html/*" || return 1
      mv "${tmp_dir}/public_html" "$DST_FILE_BACKUP_DIR_PATH"
    else
      log_error "バックアップディレクトリが見つかりません: $DST_FILE_BACKUP_DIR_PATH"
      return 1
    fi
  fi

  local exclude_opts
  exclude_opts="$(build_exclude_opts "$BACKUP_EXCLUDES")"

  # shellcheck disable=SC2086
  if rsync --checksum -arv --delete \
    -e "ssh -p \"$DST_SSH_PORT\"" \
    $exclude_opts \
    "$DST_FILE_BACKUP_DIR_PATH"/ "$DST_PUBLIC_DIR_SCP_PATH"/ >> "$(get_log_file)" 2>&1; then
    log_success "【完了】ファイルリストア成功"
  else
    log_error "【失敗】ファイルリストアに失敗しました"
    return 1
  fi
}

# 環境をロールバック
# 引数: $1=方向（stg-to-prd または prd-to-stg）
rollback() {
  local direction="$1"

  # ロールバックは BACKUP_COMPLETED 後（run-sync.sh が .env 読込済み）にのみ到達する
  setup_sync_env "$direction"

  log_header "${DST_LABEL}環境ロールバック　開始"

  local rollback_failed=false

  if ! restore_db; then
    rollback_failed=true
  fi

  if ! restore_files; then
    rollback_failed=true
  fi

  if [ "$rollback_failed" = true ]; then
    log_header "${DST_LABEL}環境ロールバック　失敗"
    log_error "手動でリストアが必要です"
    log_error "バックアップファイル:"
    log_error "  DB: $DST_DB_DUMP_FILE_PATH"
    log_error "  ファイル: $DST_FILE_BACKUP_DIR_PATH"
    return 1
  fi

  log_header "${DST_LABEL}環境ロールバック　完了"
}

perform_rollback() {
  if [ "$BACKUP_COMPLETED" != true ]; then
    log_warn "バックアップが完了していないため、ロールバックをスキップします"
    return 0
  fi

  if [ -z "$RESTORE_DIRECTION" ]; then
    log_warn "リストア方向が設定されていないため、ロールバックをスキップします"
    return 0
  fi

  log_error "エラーが発生しました。ロールバックを開始します..."
  rollback "$RESTORE_DIRECTION"
}
