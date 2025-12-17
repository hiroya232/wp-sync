#!/bin/bash

# DBを同期
# 引数: $1=コピー元SSH接続先, $2=コピー元SSHポート, $3=コピー元DBユーザー, $4=コピー元DBパスワード, $5=コピー元DBホスト, $6=コピー元DB名
#       $7=コピー先SSH接続先, $8=コピー先SSHポート, $9=コピー先DBユーザー, $10=コピー先DBパスワード, $11=コピー先DBホスト, $12=コピー先DB名
sync_db() {
  local from_ssh_dest="$1"
  local from_ssh_port="$2"
  local from_db_user="$3"
  local from_db_pass="$4"
  local from_db_host="$5"
  local from_db_name="$6"
  local to_ssh_dest="$7"
  local to_ssh_port="$8"
  local to_db_user="$9"
  local to_db_pass="${10}"
  local to_db_host="${11}"
  local to_db_name="${12}"

  echo "【DBを同期】"
  ssh "$from_ssh_dest" -p "$from_ssh_port" \
    mysqldump \
    -u"$from_db_user" \
    -p"$from_db_pass" \
    -h"$from_db_host" \
    "$from_db_name" \
    --no-tablespaces |
    ssh "$to_ssh_dest" -p "$to_ssh_port" \
      mysql \
      -u"$to_db_user" \
      -p"$to_db_pass" \
      -h"$to_db_host" \
      "$to_db_name"
  printf "【完了】\n\n"
}

# ファイルを同期
# 引数: $1=SSH接続先, $2=SSHポート, $3=コピー元パス, $4=コピー先パス, $5=除外パス(カンマ区切り)
sync_files() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local source_path="$3"
  local dest_path="$4"
  local excludes="$5"

  echo "【public_htmlを同期】"

  # 除外オプションを構築
  exclude_opts=""
  IFS=','
  for exclude in $excludes; do
    exclude_opts="$exclude_opts --exclude $exclude"
  done
  unset IFS

  ssh "$ssh_dest" -p "$ssh_port" \
    rsync --checksum -arv --delete \
    $exclude_opts \
    "$source_path"/ "$dest_path"
  printf "【完了】\n\n"
}

# wp-config.phpを置換
# 引数: $1=SSHポート, $2=ローカルのwp-configパス, $3=リモートのパス(SSH接続先込み)
replace_wp_config() {
  local ssh_port="$1"
  local local_path="$2"
  local remote_path="$3"

  echo "【wp-config.phpを置換】"
  scp -P "$ssh_port" \
    "$local_path" "$remote_path"/wp-config.php
  printf "【完了】\n\n"
}

# ドメインを置換
# 引数: $1=SSH接続先, $2=SSHポート, $3=public_htmlパス, $4=置換前ドメイン, $5=置換後ドメイン
replace_domain() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local public_dir="$3"
  local from_domain="$4"
  local to_domain="$5"

  echo "【ドメインを置換】"
  ssh "$ssh_dest" -p "$ssh_port" \
    "cd \"$public_dir\" && wp search-replace \"https://${from_domain}\" \"https://${to_domain}\" --all-tables"
  printf "【完了】\n\n"
}
