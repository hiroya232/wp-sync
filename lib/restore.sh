#!/bin/bash

# リストア対象の環境（prd または stg）
RESTORE_TARGET=""

# バックアップ完了フラグ
BACKUP_COMPLETED=false

# リストア対象を設定
# 引数: $1=対象環境（prd または stg）
set_restore_target() {
  RESTORE_TARGET="$1"
}

# バックアップ完了をマーク
mark_backup_completed() {
  BACKUP_COMPLETED=true
  log_info "バックアップ完了をマークしました"
}

# DBをリストア
# 引数: $1=SSH接続先, $2=SSHポート, $3=DBユーザー, $4=DBパスワード, $5=DBホスト, $6=DB名, $7=ダンプファイルパス
restore_db() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local db_user="$3"
  local db_pass="$4"
  local db_host="$5"
  local db_name="$6"
  local dump_path="$7"

  log_info "【DBをリストア】"
  log_info "  ダンプファイル: $dump_path"
  log_info "  リストア先: $db_name@$db_host"

  if [ ! -f "$dump_path" ]; then
    log_error "ダンプファイルが見つかりません: $dump_path"
    return 1
  fi

  if ssh "$ssh_dest" -p "$ssh_port" \
    mysql \
    -u"$db_user" \
    -p"$db_pass" \
    -h"$db_host" \
    "$db_name" < "$dump_path" 2>/dev/null; then
    log_success "【完了】DBリストア成功"
  else
    log_error "【失敗】DBリストアに失敗しました"
    return 1
  fi
}

# ファイルをリストア
# 引数: $1=SSHポート, $2=バックアップ元パス, $3=リストア先パス(SSH接続先込み), $4=除外パス(カンマ区切り)
restore_files() {
  local ssh_port="$1"
  local backup_path="$2"
  local dest_path="$3"
  local excludes="$4"

  log_info "【ファイルをリストア】"
  log_info "  バックアップ: $backup_path"
  log_info "  リストア先: $dest_path"

  if [ ! -d "$backup_path" ]; then
    log_error "バックアップディレクトリが見つかりません: $backup_path"
    return 1
  fi

  # 除外オプションを構築
  local exclude_opts=""
  IFS=','
  for exclude in $excludes; do
    exclude_opts="$exclude_opts --exclude $exclude"
  done
  unset IFS

  if rsync --checksum -arv --delete \
    -e "ssh -p \"$ssh_port\"" \
    $exclude_opts \
    "$backup_path"/ "$dest_path"/ >> "$(get_log_file)" 2>&1; then
    log_success "【完了】ファイルリストア成功"
  else
    log_error "【失敗】ファイルリストアに失敗しました"
    return 1
  fi
}

# 本番環境をリストア
rollback_prd() {
  log_header "本番環境ロールバック　開始"

  # .envの読み込み（まだ読み込まれていない場合）
  if [ -z "$PRD_SSH_DESTINATION" ]; then
    # shellcheck source=/dev/null
    . ./.wp-sync/.env
  fi

  local rollback_failed=false

  # DBリストア
  if ! restore_db \
    "$PRD_SSH_DESTINATION" \
    "$PRD_SSH_PORT" \
    "$PRD_DB_USER" \
    "$PRD_DB_PASSWORD" \
    "$PRD_DB_HOST" \
    "$PRD_DB_NAME" \
    "$PRD_DB_DUMP_FILE_PATH"; then
    rollback_failed=true
  fi

  # ファイルリストア
  if ! restore_files \
    "$PRD_SSH_PORT" \
    "$PRD_FILE_BACKUP_DIR_PATH" \
    "$PRD_PUBLIC_DIR_PATH_WITH_DESTINATION" \
    "$STG_DOMAIN,$EXCLUDES"; then
    rollback_failed=true
  fi

  if [ "$rollback_failed" = true ]; then
    log_header "本番環境ロールバック　失敗"
    log_error "手動でリストアが必要です"
    log_error "バックアップファイル:"
    log_error "  DB: $PRD_DB_DUMP_FILE_PATH"
    log_error "  ファイル: $PRD_FILE_BACKUP_DIR_PATH"
    return 1
  fi

  log_header "本番環境ロールバック　完了"
}

# ステージング環境をリストア
rollback_stg() {
  log_header "ステージング環境ロールバック　開始"

  # .envの読み込み（まだ読み込まれていない場合）
  if [ -z "$STG_SSH_DESTINATION" ]; then
    # shellcheck source=/dev/null
    . ./.wp-sync/.env
  fi

  local rollback_failed=false

  # DBリストア
  if ! restore_db \
    "$STG_SSH_DESTINATION" \
    "$STG_SSH_PORT" \
    "$STG_DB_USER" \
    "$STG_DB_PASSWORD" \
    "$STG_DB_HOST" \
    "$STG_DB_NAME" \
    "$STG_DB_DUMP_FILE_PATH"; then
    rollback_failed=true
  fi

  # ファイルリストア
  if ! restore_files \
    "$STG_SSH_PORT" \
    "$STG_FILE_BACKUP_DIR_PATH" \
    "$STG_PUBLIC_DIR_PATH_WITH_DESTINATION" \
    "$EXCLUDES"; then
    rollback_failed=true
  fi

  if [ "$rollback_failed" = true ]; then
    log_header "ステージング環境ロールバック　失敗"
    log_error "手動でリストアが必要です"
    log_error "バックアップファイル:"
    log_error "  DB: $STG_DB_DUMP_FILE_PATH"
    log_error "  ファイル: $STG_FILE_BACKUP_DIR_PATH"
    return 1
  fi

  log_header "ステージング環境ロールバック　完了"
}

# エラー時のロールバック処理
perform_rollback() {
  if [ "$BACKUP_COMPLETED" != true ]; then
    log_warn "バックアップが完了していないため、ロールバックをスキップします"
    return 0
  fi

  if [ -z "$RESTORE_TARGET" ]; then
    log_warn "リストア対象が設定されていないため、ロールバックをスキップします"
    return 0
  fi

  log_error "エラーが発生しました。ロールバックを開始します..."

  case "$RESTORE_TARGET" in
    prd)
      rollback_prd
      ;;
    stg)
      rollback_stg
      ;;
    *)
      log_error "不明なリストア対象: $RESTORE_TARGET"
      return 1
      ;;
  esac
}

