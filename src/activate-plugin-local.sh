#!/bin/sh
# shellcheck source=/dev/null

docker exec -it コンテナ名 wp plugin activate プラグイン1 プラグイン2 ... --allow-root
