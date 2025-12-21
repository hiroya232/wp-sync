# WP-Sync

## 概要

WordPressサイトのステージング環境と本番環境間で、DB・ファイルの同期を行うためのツール。

## 機能

- **DB同期**: `mysqldump/mysql`経由でデータベースを同期
- **ファイル同期**: `rsync`経由でファイルを同期
- **ドメイン置換**: WP-CLIの`search-replace`でURLを自動置換
- **wp-config.php置換**: 環境に応じた設定ファイルを自動適用
- **Basic認証**: ステージング環境へのBasic認証を自動設定/解除
- **プラグイン管理**: 環境に応じたプラグインの自動有効化/無効化
- **キャッシュ削除**: Redis, Autoptimize, WP-Optimizeのキャッシュを自動削除
- **ログ出力**: `.wp-sync/logs/`に保存（30日間保持）
- **トランザクション処理**: エラー発生時に自動ロールバック

## 前提条件

### 実行環境

| ツール | バージョン |
|--------|------------|
| macOS | 26.1 (Tahoe) |
| Bash | 3.2.57 |
| rsync | openrsync (protocol 29) |
| OpenSSH | 10.0p2 |
| MariaDB | 10.5.27 |
| WP-CLI | 2.8.1 |

> **Note**: `mysqldump` / `mysql` / `wp-cli` はリモートサーバー上で実行されます。インストールされていない場合は別途インストールが必要です。

### WordPressディレクトリ配置

ステージング環境が本番環境のサブディレクトリに配置されていること

```text
public_html/            ← 本番環境のWordPressルートディレクトリ
├── wp-admin/
├── wp-content/
├── wp-includes/
├── ...
└── stg.example.com/    ← ステージング環境のルートディレクトリ（サブディレクトリ）
    ├── wp-admin/
    ├── wp-content/
    ├── wp-includes/
    └── ...
```

## ディレクトリ構成

```text
wp-sync/
├── bin/
│   └── wp-sync                 # ラッパースクリプト（エントリーポイント）
├── scripts/
│   └── sync.sh                 # 同期処理（方向を引数で受け取る）
├── lib/
│   ├── activate-plugin.sh      # プラグイン有効化
│   ├── backup.sh               # バックアップ処理
│   ├── basic-auth.sh           # Basic認証設定
│   ├── deactivate-plugin.sh    # プラグイン無効化
│   ├── log.sh                  # ログ出力
│   ├── restore.sh              # ロールバック処理
│   └── sync.sh                 # 同期処理
├── template/                   # WordPressプロジェクトにコピーする設定
│   ├── .env.example            # 環境変数テンプレート（※.envにコピーして編集）
│   ├── .gitignore
│   ├── .htaccess-basic-auth    # Basic認証用.htaccess
│   ├── .htpasswd               # Basic認証用パスワード（※要編集）
│   ├── wp-config-prd.php       # 本番用wp-config.php（※要編集）
│   ├── wp-config-stg.php       # ステージング用wp-config.php（※要編集）
│   ├── logs/.gitkeep
│   └── tmp/.gitkeep
└── README.md
```

## セットアップ

### 1. PATHに追加

```bash
# ~/.zshrc または ~/.bashrc に追加
export PATH="/path/to/wp-sync/bin:$PATH"
```

### 2. WordPressプロジェクトに設定をコピー

```bash
cp -r /path/to/wp-sync/template /your/wordpress/project/.wp-sync
```

### 3. 設定ファイルを編集

- `.wp-sync/.env.example` → SSH接続情報、DB情報などの環境変数(`.env`にコピーして編集)
- `.wp-sync/wp-config-prd.php` - 本番用`wp-config.php`
- `.wp-sync/wp-config-stg.php` - ステージング用`wp-config.php`
- `.wp-sync/.htpasswd` - Basic認証用の暗号化されたパスワード

## 使用方法

WordPressプロジェクトのルートで実行:

```bash
wp-sync prd-to-stg    # 本番 → ステージング同期
wp-sync stg-to-prd    # ステージング → 本番同期
wp-sync help          # ヘルプ表示
```

詳しい使い方は、以下のブログ記事を参照してください。

[【WordPress】環境間をコマンド1つで簡単に同期する](https://hiro8blog.com/sync-wp-between-local-and-production/)

## 免責事項

- 本ツールは無保証で提供されます。使用によって生じたいかなる損害についても、作者は責任を負いません。
- 本番環境への同期を行う前に、必ずバックアップを取得し、リストア手順を事前に確認しておいてください。
- 重要なデータを扱う場合は、事前にテスト環境で動作確認を行うことを強く推奨します。
