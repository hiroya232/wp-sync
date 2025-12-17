#!/bin/bash
# shellcheck source=/dev/null
# 本番環境でのみ有効化するプラグイン（ステージング→本番同期前にステージング環境で有効化）

. ./.wp-sync/.env

wp plugin activate $PLUGINS_TO_ACTIVATE --ssh="$STG_SSH_DESTINATION:$STG_SSH_PORT$STG_PUBLIC_DIR_PATH" --allow-root
