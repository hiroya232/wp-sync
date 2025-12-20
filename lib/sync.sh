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

  log_info "【DBを同期】"
  log_info "  コピー元: $from_db_name@$from_db_host"
  log_info "  コピー先: $to_db_name@$to_db_host"

  if ssh "$from_ssh_dest" -p "$from_ssh_port" \
    mysqldump \
    -u"$from_db_user" \
    -p"$from_db_pass" \
    -h"$from_db_host" \
    "$from_db_name" \
    --no-tablespaces 2>/dev/null |
    ssh "$to_ssh_dest" -p "$to_ssh_port" \
      mysql \
      -u"$to_db_user" \
      -p"$to_db_pass" \
      -h"$to_db_host" \
      "$to_db_name" 2>/dev/null; then
    log_success "【完了】"
  else
    log_error "【失敗】DB同期に失敗しました"
    return 1
  fi
}

# ファイルを同期
# 引数: $1=SSH接続先, $2=SSHポート, $3=コピー元パス, $4=コピー先パス, $5=除外パス(カンマ区切り)
sync_files() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local source_path="$3"
  local dest_path="$4"
  local excludes="$5"

  log_info "【public_htmlを同期】"
  log_info "  コピー元: $source_path"
  log_info "  コピー先: $dest_path"

  # 除外オプションを構築
  local exclude_opts=""
  IFS=','
  for exclude in $excludes; do
    exclude_opts="$exclude_opts --exclude $exclude"
  done
  unset IFS

  if ssh "$ssh_dest" -p "$ssh_port" \
    rsync \
        --checksum \
        -arv \
        --delete \
        $exclude_opts \
        "$source_path"/ \
        "$dest_path" >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】ファイル同期に失敗しました"
    return 1
  fi
}

# wp-config.phpを置換
# 引数: $1=SSHポート, $2=ローカルのwp-configパス, $3=リモートのパス(SSH接続先込み)
replace_wp_config() {
  local ssh_port="$1"
  local local_path="$2"
  local remote_path="$3"

  log_info "【wp-config.phpを置換】"
  log_info "  ローカル: $local_path"
  log_info "  リモート: $remote_path/wp-config.php"

  if scp -P "$ssh_port" \
    "$local_path" "$remote_path"/wp-config.php >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】wp-config.php置換に失敗しました"
    return 1
  fi
}

# ドメインを置換
# 引数: $1=SSH接続先, $2=SSHポート, $3=public_htmlパス, $4=置換前ドメイン, $5=置換後ドメイン
replace_domain() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local public_dir="$3"
  local from_domain="$4"
  local to_domain="$5"

  log_info "【ドメインを置換】"
  log_info "  置換前: https://$from_domain"
  log_info "  置換後: https://$to_domain"

  if ssh "$ssh_dest" -p "$ssh_port" \
    "cd \"$public_dir\" && \
     wp search-replace \"https://${from_domain}\" \"https://${to_domain}\" --all-tables" \
    >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】ドメイン置換に失敗しました"
    return 1
  fi
}
