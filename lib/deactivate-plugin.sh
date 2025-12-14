#!/bin/sh
# shellcheck source=/dev/null
# ステージング環境では無効化するプラグイン（本番→ステージング同期後にステージング環境で無効化）

. ./.wp-sync/.env

wp plugin deactivate $PLUGINS_TO_DEACTIVATE --ssh="$STG_SSH_DESTINATION:$STG_SSH_PORT$STG_PUBLIC_DIR_PATH" --allow-root
