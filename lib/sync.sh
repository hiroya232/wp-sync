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

# PHPスクリプトをリモートに転送して実行する共通ヘルパー
# 引数: $1=SSH接続先, $2=SSHポート, $3=ローカルPHPスクリプト, [追加引数...]
# 標準出力は呼び出し元に返す。標準エラーはログに追記。
_run_remote_php() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local local_script="$3"
  shift 3
  local remote_script="/tmp/wp_php_$$.php"

  if ! scp -P "$ssh_port" "$local_script" "$ssh_dest:$remote_script" >> "$(get_log_file)" 2>&1; then
    return 1
  fi

  local quoted_args=""
  for arg in "$@"; do
    quoted_args="$quoted_args '$arg'"
  done

  ssh "$ssh_dest" -p "$ssh_port" \
    "php '$remote_script'$quoted_args; ec=\$?; rm -f '$remote_script'; exit \$ec" \
    2>>"$(get_log_file)"
}

# wp-config.phpの環境固有定数を復元
# 引数: $1=SSH接続先, $2=SSHポート, $3=wp-config.phpのあるディレクトリ, $4=保持する定数(カンマ区切り), $5=退避ファイルパス
restore_wp_config_constants() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local wp_config_dir="$3"
  local preserve_constants="$4"
  local tmp_file="$5"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  log_info "【wp-config.phpの環境固有定数を復元】"
  log_info "  対象: $wp_config_dir/wp-config.php"

  if _run_remote_php "$ssh_dest" "$ssh_port" "$script_dir/restore-constants.php" \
    "$preserve_constants" "$tmp_file" "$wp_config_dir/wp-config.php" \
    >> "$(get_log_file)"; then
    log_success "【完了】"
  else
    log_error "【失敗】wp-config.php定数復元に失敗しました"
    return 1
  fi
}

# wp-config.phpの環境固有定数を動的検出
# 引数: $1=SSH接続先, $2=SSHポート, $3=同期元wp-config.phpパス, $4=同期先wp-config.phpパス(退避済み)
detect_preserve_constants() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local src_wp_config="$3"
  local dst_wp_config="$4"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local result
  result=$(_run_remote_php "$ssh_dest" "$ssh_port" "$script_dir/diff-constants.php" \
    "$src_wp_config" "$dst_wp_config")
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "【失敗】定数差分検出に失敗しました"
    return 1
  fi

  echo "$result"
}

# コピー先のwp-config.phpを退避
# 引数: $1=SSH接続先, $2=SSHポート, $3=wp-config.phpのフルパス, $4=退避先フルパス
backup_wp_config() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local wp_config_file="$3"
  local tmp_file="$4"

  log_info "【コピー先のwp-config.phpを退避】"
  if ssh "$ssh_dest" -p "$ssh_port" \
    "cp '$wp_config_file' '$tmp_file'" \
    >> "$(get_log_file)" 2>&1; then
    log_success "【完了】"
  else
    log_error "【失敗】wp-config.php退避に失敗しました"
    return 1
  fi
}

# 退避したwp-config.phpを削除
# 引数: $1=SSH接続先, $2=SSHポート, $3=退避ファイルのフルパス
remove_wp_config_backup() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local tmp_file="$3"

  ssh "$ssh_dest" -p "$ssh_port" \
    "rm -f '$tmp_file'" >> "$(get_log_file)" 2>&1
}

# ドメインを置換
# 引数: $1=SSH接続先, $2=SSHポート, $3=public_htmlパス, $4=置換前ドメイン, $5=置換後ドメイン, $6=期待するDB名
replace_domain() {
  local ssh_dest="$1"
  local ssh_port="$2"
  local public_dir="$3"
  local from_domain="$4"
  local to_domain="$5"
  local expected_db_name="$6"

  log_info "【ドメインを置換】"
  log_info "  置換前: https://$from_domain"
  log_info "  置換後: https://$to_domain"

  # wp-config.php の DB接続先を検証（親ディレクトリへのフォールバック防止）
  local actual_db_name
  actual_db_name=$(ssh "$ssh_dest" -p "$ssh_port" \
    "cd \"$public_dir\" && wp config get DB_NAME" 2>/dev/null)
  if [ "$actual_db_name" != "$expected_db_name" ]; then
    log_error "【失敗】wp-config.php のDB接続先が不正です（期待: $expected_db_name, 実際: $actual_db_name）"
    log_error "  wp-config.php の内容を確認してください"
    return 1
  fi

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
