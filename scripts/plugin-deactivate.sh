#!/bin/sh
# shellcheck source=/dev/null

. ./.env

wp plugin deactivate --ssh=ユーザ名@ホスト名:ポート番号/WordPressインストールパス プラグイン1 プラグイン2 ... --allow-root
