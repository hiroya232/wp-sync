# WP-Sync

## 概要

WordPressサイトのローカル、ステージング、本番環境間で、DB・ファイルの同期を行うためのツール。

## 技術スタック

- Docker 20.10.7
- Docker Compose 2.24.6
- WordPress 6.2.2
- PHP 8.0
- MySQL 5.7
- Redis 7.0.5
- Xdebug 3.2.1

## 環境変数

下記記事を参照。

[【WordPress】環境間をコマンド1つで簡単に同期する](https://hiro8blog.com/sync-wp-between-local-and-production/)

## ディレクトリ構成

```tree
.
├── Dockerfile
├── README.md
├── merge-local-into-prd.sh
├── merge-local-into-stg.sh
├── merge-prd-into-local.sh
├── merge-prd-into-stg.sh
├── merge-stg-into-local.sh
├── merge-stg-into-prd.sh
├── src
│   ├── .env
│   ├── .gitignore
│   ├── .htaccess-basic-auth
│   ├── .htpasswd
│   ├── .vscode
│   ├── docker-compose.yml
│   ├── php.ini
│   ├── temp/
│   ├── wp-config-local.php
│   ├── wp-config-prd.php
│   └── wp-config-stg.php
├── srdb.class.php
└── srdb.cli.php
```

## 開発環境構築&実行方法

下記記事を参照。

[【WordPress】環境間をコマンド1つで簡単に同期する](https://hiro8blog.com/sync-wp-between-local-and-production/)
