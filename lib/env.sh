#!/bin/bash

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

  for v in SSH_DESTINATION SSH_PORT DB_USER DB_PASSWORD DB_HOST DB_NAME \
            PUBLIC_DIR_PATH DOMAIN; do
    eval "SRC_${v}=\"\${${src}_${v}}\""
  done

  for v in SSH_DESTINATION SSH_PORT DB_USER DB_PASSWORD DB_HOST DB_NAME \
            PUBLIC_DIR_PATH DOMAIN DB_DUMP_FILE_PATH \
            PUBLIC_DIR_SCP_PATH FILE_BACKUP_DIR_PATH; do
    eval "DST_${v}=\"\${${dst}_${v}}\""
  done

  # shellcheck disable=SC2034
  if [ "$direction" = "stg-to-prd" ]; then
    BACKUP_EXCLUDES="$STG_DOMAIN,$EXCLUDES"
  else
    BACKUP_EXCLUDES="$EXCLUDES"
  fi
}
