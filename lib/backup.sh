#!/bin/bash

# DBをバックアップ
# 引数: $1=SSH接続先, $2=SSHポート, $3=DBユーザー, $4=DBパスワード, $5=DBホスト, $6=DB名, $7=出力ファイルパス
backup_db() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local db_user="$3"
  local db_pass="$4"
  local db_host="$5"
  local db_name="$6"
  local output_path="$7"

  echo "【DBをバックアップ】"
  ssh "$ssh_dest" -p "$ssh_port" \
    mysqldump \
    -u"$db_user" \
    -p"$db_pass" \
    -h"$db_host" \
    "$db_name" \
    --no-tablespaces >"$output_path"
  printf "【完了】\n\n"
}

# ファイルをバックアップ
# 引数: $1=SSHポート, $2=コピー元パス, $3=コピー先パス, $4=除外パス(カンマ区切り)
backup_files() {
  local ssh_port="$1"
  local source_path="$2"
  local dest_path="$3"
  local excludes="$4"

  echo "【public_htmlをバックアップ】"

  # 除外オプションを構築
  exclude_opts=""
  IFS=','
  for exclude in $excludes; do
    exclude_opts="$exclude_opts --exclude $exclude"
  done
  unset IFS

  rsync --checksum -arv --delete \
    -e "ssh -p \"$ssh_port\"" \
    $exclude_opts \
    "$source_path"/ "$dest_path"/
  printf "【完了】\n\n"
}
