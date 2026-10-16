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

# バックアップ完了フラグ
BACKUP_COMPLETED=false

# リストア時の同期方向（stg-to-prd または prd-to-stg）
RESTORE_DIRECTION=""

# バックアップ完了をマーク
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
      local tmp_dir="${DST_DB_DUMP_FILE_PATH%/*}"
      local dump_base="${DST_DB_DUMP_FILE_PATH##*/}"
      local log_file unzip_output
      log_file="$(get_log_file)"
      if ! unzip_output=$(cd "$tmp_dir" && unzip -o "${latest_zip##*/}" "$dump_base" 2>&1); then
        [ -n "$log_file" ] && echo "$unzip_output" >> "$log_file"
        log_error "ZIP解凍に失敗しました: $latest_zip"
        return 1
      fi
      [ -n "$log_file" ] && echo "$unzip_output" >> "$log_file"
    else
      log_error "ダンプファイルが見つかりません: $DST_DB_DUMP_FILE_PATH"
      return 1
    fi
  fi

  if ssh "$DST_SSH_DESTINATION" -p "$DST_SSH_PORT" \
    mysql \
    -u"$DST_DB_USER" \
    -p"$DST_DB_PASSWORD" \
    -h"$DST_DB_HOST" \
    "$DST_DB_NAME" < "$DST_DB_DUMP_FILE_PATH" 2>>"$(get_log_file)"; then
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
      local log_file unzip_output
      log_file="$(get_log_file)"
      if ! unzip_output=$(cd "$tmp_dir" && unzip -o "${latest_zip##*/}" "public_html/*" 2>&1); then
        [ -n "$log_file" ] && echo "$unzip_output" >> "$log_file"
        log_error "ZIP解凍に失敗しました: $latest_zip"
        return 1
      fi
      [ -n "$log_file" ] && echo "$unzip_output" >> "$log_file"
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
  local env_name
  if [ "$direction" = "stg-to-prd" ]; then
    env_name="本番"
  else
    env_name="ステージング"
  fi

  log_header "${env_name}環境ロールバック　開始"

  # ロールバックは BACKUP_COMPLETED 後（run-sync.sh が .env 読込済み）にのみ到達する
  setup_sync_env "$direction"

  local rollback_failed=false

  if ! restore_db; then
    rollback_failed=true
  fi

  if ! restore_files; then
    rollback_failed=true
  fi

  if [ "$rollback_failed" = true ]; then
    log_header "${env_name}環境ロールバック　失敗"
    log_error "手動でリストアが必要です"
    log_error "バックアップファイル:"
    log_error "  DB: $DST_DB_DUMP_FILE_PATH"
    log_error "  ファイル: $DST_FILE_BACKUP_DIR_PATH"
    return 1
  fi

  log_header "${env_name}環境ロールバック　完了"
}

# エラー時のロールバック処理
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
