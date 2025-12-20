#!/bin/bash

# ログ設定
LOG_DIR=".wp-sync/logs"
LOG_FILE=""
LOG_RETENTION_DAYS=30

# カラー定義（画面出力用）
COLOR_RESET="\033[0m"
COLOR_INFO="\033[0;36m"    # シアン
COLOR_WARN="\033[0;33m"    # 黄色
COLOR_ERROR="\033[0;31m"   # 赤
COLOR_SUCCESS="\033[0;32m" # 緑
COLOR_HEADER="\033[1;35m"  # マゼンタ（太字）

# ログを初期化
# 引数: $1=処理名（例: prd-to-stg）
init_log() {
  local process_name="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d_%H%M%S')

  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${timestamp}_${process_name}.log"

  # ログファイルにヘッダーを出力
  {
    echo "========================================"
    echo "wp-sync ログ"
    echo "処理: $process_name"
    echo "開始: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""
  } > "$LOG_FILE"

  # 古いログを削除
  rotate_logs
}

# ログをローテーション（古いログを削除）
rotate_logs() {
  if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null
  fi
}

# ログ出力（内部関数）
# 引数: $1=レベル, $2=カラー, $3=メッセージ
_log() {
  local level="$1"
  local color="$2"
  local message="$3"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # ファイルに出力（カラーなし）
  if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  fi

  # 画面に出力（カラーあり）
  echo -e "${color}[$timestamp] [$level]${COLOR_RESET} $message"
}

# INFOログ
log_info() {
  _log "INFO" "$COLOR_INFO" "$1"
}

# WARNログ
log_warn() {
  _log "WARN" "$COLOR_WARN" "$1"
}

# ERRORログ
log_error() {
  _log "ERROR" "$COLOR_ERROR" "$1"
}

# SUCCESSログ
log_success() {
  _log "SUCCESS" "$COLOR_SUCCESS" "$1"
}

# ヘッダー出力（セクション区切り用）
log_header() {
  local message="$1"
  local separator="------------------------------"
  local full_message="${separator}${message}${separator}"

  # ファイルに出力
  if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    echo "" >> "$LOG_FILE"
    echo "$full_message" >> "$LOG_FILE"
  fi

  # 画面に出力（カラーあり）
  echo ""
  echo -e "${COLOR_HEADER}${full_message}${COLOR_RESET}"
}

# コマンド実行結果をログ出力
# 引数: $1=コマンド説明, $2...=実行するコマンド
log_exec() {
  local description="$1"
  shift

  log_info "【${description}】"

  # コマンドを実行し、出力をキャプチャ
  local output
  local exit_code
  output=$("$@" 2>&1)
  exit_code=$?

  # 出力があればログに記録
  if [ -n "$output" ]; then
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
      echo "$output" >> "$LOG_FILE"
    fi
    # 画面には出力しない（冗長になるため）
  fi

  if [ $exit_code -eq 0 ]; then
    log_success "【完了】"
  else
    log_error "【失敗】 終了コード: $exit_code"
  fi

  return $exit_code
}

# ログファイルのパスを取得
get_log_file() {
  echo "$LOG_FILE"
}

# ログ終了処理
finalize_log() {
  if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    {
      echo ""
      echo "========================================"
      echo "終了: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "========================================"
    } >> "$LOG_FILE"
  fi
}



