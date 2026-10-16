#!/bin/bash

# カンマ区切りの除外パスを rsync の --exclude オプション列に変換して出力
# 引数: $1=除外パス(カンマ区切り)
# 呼び出し側は未クォートで展開する（bash 3.2 の set -u 下で空配列が使えないため文字列で返す）
build_exclude_opts() {
  local IFS=','
  local opts="" exclude
  # shellcheck disable=SC2086
  for exclude in $1; do
    opts="$opts --exclude $exclude"
  done
  echo "$opts"
}

# 同期方向に応じて SRC_* / DST_* 中間変数を一括セット
# 引数: $1=方向（stg-to-prd または prd-to-stg）
setup_sync_env() {
  local direction="$1"
  local src dst
  if [ "$direction" = "stg-to-prd" ]; then
    src="STG"; dst="PRD"
  else
    src="PRD"; dst="STG"
  fi

  # バックアップパスのデフォルト設定（eval ループで DST_* に展開される）
  # shellcheck disable=SC2034
  PRD_DB_DUMP_FILE_PATH="${SITE_DIR}/tmp/prd_dump.sql"
  # shellcheck disable=SC2034
  PRD_FILE_BACKUP_DIR_PATH="${SITE_DIR}/tmp/prd_public_html"
  # shellcheck disable=SC2034
  STG_DB_DUMP_FILE_PATH="${SITE_DIR}/tmp/stg_dump.sql"
  # shellcheck disable=SC2034
  STG_FILE_BACKUP_DIR_PATH="${SITE_DIR}/tmp/stg_public_html"

  for v in SSH_DESTINATION SSH_PORT DB_USER DB_PASSWORD DB_HOST DB_NAME \
            PUBLIC_DIR_PATH DOMAIN; do
    eval "SRC_${v}=\"\${${src}_${v}:-}\""
  done

  for v in SSH_DESTINATION SSH_PORT DB_USER DB_PASSWORD DB_HOST DB_NAME \
            PUBLIC_DIR_PATH DOMAIN DB_DUMP_FILE_PATH \
            PUBLIC_DIR_SCP_PATH FILE_BACKUP_DIR_PATH; do
    eval "DST_${v}=\"\${${dst}_${v}:-}\""
  done

  # shellcheck disable=SC2034,SC2153
  DST_BACKUP_ZIP_PATH="${DST_DB_DUMP_FILE_PATH%%_dump.sql}_backup.zip"

  # shellcheck disable=SC2034
  if [ "$direction" = "stg-to-prd" ]; then
    BACKUP_EXCLUDES="$STG_DOMAIN,$EXCLUDES"
  else
    BACKUP_EXCLUDES="$EXCLUDES"
  fi
}
