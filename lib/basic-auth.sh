#!/bin/bash

# Basic認証を設定
# 引数: $1=SSH接続先, $2=SSHポート, $3=public_htmlパス, $4=htaccess-basic-authファイルパス, $5=htpasswdファイルパス, $6=htpasswd配置先パス(SSH接続先込み)
setup_basic_auth() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local public_dir="$3"
  local htaccess_auth_path="$4"
  local htpasswd_path="$5"
  local htpasswd_dest="$6"

  echo "【Basic認証の設定】"
  ssh "$ssh_dest" -p "$ssh_port" "sed -i '/^\n*$/d' \"$public_dir/.htaccess\""
  ssh "$ssh_dest" -p "$ssh_port" "echo -e \"\n\" >> \"$public_dir/.htaccess\""
  ssh <"$htaccess_auth_path" "$ssh_dest" -p "$ssh_port" "cat >> \"$public_dir\"/.htaccess"
  scp -P "$ssh_port" \
    "$htpasswd_path" "$htpasswd_dest"/.htpasswd
  printf "【完了】\n\n"
}

# Basic認証を削除
# 引数: $1=SSH接続先, $2=SSHポート, $3=public_htmlパス, $4=htaccess-basic-authファイルパス, $5=envファイルパス, $6=リモートのパス(SSH接続先込み)
remove_basic_auth() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local public_dir="$3"
  local htaccess_auth_path="$4"
  local env_path="$5"
  local remote_dest="$6"

  echo "【Basic認証の設定削除】"
  scp -P "$ssh_port" "$htaccess_auth_path" "$env_path" "$remote_dest" &&
    ssh "$ssh_dest" -p "$ssh_port" \
      " \
        grep -vFf \"$public_dir\"/.htaccess-basic-auth \"$public_dir\"/.htaccess >\"$public_dir\"/.htaccess.tmp &&
          mv \"$public_dir\"/.htaccess.tmp \"$public_dir\"/.htaccess ;
          rm \"$public_dir\"/.htaccess-basic-auth \"$public_dir\"/.env \
      "
  ssh "$ssh_dest" -p "$ssh_port" "sed -i '/^\n*$/d' \"$public_dir/.htaccess\""
  printf "【完了】\n\n"
}

