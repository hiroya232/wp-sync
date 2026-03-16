#!/bin/bash

# DBをバックアップ（DST_* グローバル変数を参照）
backup_db() {
  log_info "【DBをバックアップ】"
  log_info "  出力先: $DST_DB_DUMP_FILE_PATH"

  if ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    mysqldump \
    -u"$DST_DB_USER" \
    -p"$DST_DB_PASSWORD" \
    -h"$DST_DB_HOST" \
    "$DST_DB_NAME" \
    --no-tablespaces >"$DST_DB_DUMP_FILE_PATH" 2>&1; then
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
