#!/bin/bash

# バックアップをZIPにまとめ、元ファイルを削除（DST_* グローバル変数を参照）
archive_backup() {
  local tmp_dir="${DST_DB_DUMP_FILE_PATH%/*}"
  local dump_base="${DST_DB_DUMP_FILE_PATH##*/}"
  local timestamp zip_base log_file zip_output
  timestamp=$(date '+%Y%m%d_%H%M%S')
  zip_base="${DST_BACKUP_ZIP_PATH##*/}"           # prd_backup.zip
  zip_base="${zip_base%.zip}_${timestamp}.zip"    # prd_backup_20260318_140627.zip

  log_info "【バックアップをZIP化】"
  log_info "  保存先: ${tmp_dir}/${zip_base}"

  # ZIP内のディレクトリ名を public_html に統一
  mv "$DST_FILE_BACKUP_DIR_PATH" "${tmp_dir}/public_html"

  log_file="$(get_log_file)"
  if zip_output=$(cd "$tmp_dir" && zip -r "$zip_base" "$dump_base" "public_html" 2>&1); then
    [ -n "$log_file" ] && echo "$zip_output" >> "$log_file"
    log_success "【完了】ZIP化成功"
    rm -f "$DST_DB_DUMP_FILE_PATH"
    rm -rf "${tmp_dir}/public_html"
  else
    [ -n "$log_file" ] && echo "$zip_output" >> "$log_file"
    mv "${tmp_dir}/public_html" "$DST_FILE_BACKUP_DIR_PATH"
    log_error "【失敗】ZIP化に失敗しました"
    return 1
  fi
}

# DBをバックアップ（DST_* グローバル変数を参照）
backup_db() {
  log_info "【DBをバックアップ】"
  log_info "  出力先: $DST_DB_DUMP_FILE_PATH"

  # 標準出力だけをダンプに書き、警告やエラーはログに残す
  if ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    "$(remote_mysql_cmd mysqldump "$DST_DB_USER" "$DST_DB_HOST" "$DST_DB_NAME" --no-tablespaces)" \
    < <(printf '%s\n' "$DST_DB_PASSWORD") \
    >"$DST_DB_DUMP_FILE_PATH" 2>>"$(get_log_file)"; then
    log_success "【完了】"
  else
    log_error "【失敗】DBバックアップに失敗しました"
    return 1
  fi
}

# ファイルをバックアップ（DST_* / BACKUP_EXCLUDES グローバル変数を参照）
backup_files() {
  log_info "【public_htmlをバックアップ】"
  log_info "  コピー元: $DST_PUBLIC_DIR_SCP_PATH"
  log_info "  コピー先: $DST_FILE_BACKUP_DIR_PATH"

  # 除外オプションを構築
  local exclude_opts=""
  IFS=','
  for exclude in $BACKUP_EXCLUDES; do
    exclude_opts="$exclude_opts --exclude $exclude"
  done
  unset IFS

  # shellcheck disable=SC2086
  if rsync \
    --checksum \
    -arv \
    --delete \
    -e "ssh -p \"$DST_SSH_PORT\"" \
    $exclude_opts \
    "$DST_PUBLIC_DIR_SCP_PATH"/ \
    "$DST_FILE_BACKUP_DIR_PATH"/ >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】ファイルバックアップに失敗しました"
    return 1
  fi
}
