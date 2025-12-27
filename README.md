# wp-sync

WordPressサイトのステージング環境と本番環境間で、DB・ファイルの同期をコマンド1つで行うツール。

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
| PHP(サーバ) | 8.0.30 |
| MariaDB | 10.5.27 |
| WP-CLI | 2.8.1 |

> **Note**: `mysqldump` / `mysql` / `wp-cli` はリモートサーバー上で実行されます。インストールされていない場合は別途インストールが必要です。

### WordPress配置

ステージング環境が本番環境のサブディレクトリに配置されていること。

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

本ツールのディレクトリ構成は以下の通り。

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
├── template/                   # 作業ディレクトリにコピーする設定
│   ├── .env.example            # 環境変数テンプレート
│   ├── .gitignore
│   ├── .htaccess-basic-auth    # Basic認証用.htaccess
│   ├── .htpasswd               # Basic認証用パスワード
│   ├── wp-config-prd.php       # 本番用wp-config.php
│   ├── wp-config-stg.php       # ステージング用wp-config.php
│   ├── logs/.gitkeep
│   └── tmp/.gitkeep
└── README.md
```

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/hiroya232/wp-sync.git
```

### 2. PATHに追加

`~/.zshrc`（または`~/.bashrc`）に以下を追加：

```bash
export PATH="/path/to/wp-sync/bin:$PATH"
```

設定を反映：

```bash
source ~/.zshrc
```

### 3. 作業ディレクトリを作成

wp-syncはローカルの作業ディレクトリから実行します。同期対象のWordPressサイトごとに作業ディレクトリを用意してください。

```bash
mkdir ~/path/to/workdir
cd ~/path/to/workdir
```

> **Note**: 作業ディレクトリの場所・名前は任意です。管理しやすい場所に作成してください。

### 4. 設定ファイルをコピー

`template`ディレクトリの中身を、作業ディレクトリに`.wp-sync`という名前でコピーします。

```bash
cp -r /path/to/wp-sync/template ./.wp-sync
```

コピー後のディレクトリ構成：

```text
workdir/                     ← 作成した作業ディレクトリ
└── .wp-sync/                ← WordPress固有設定ファイル用ディレクトリ
    ├── .env.example
    ├── .gitignore
    ├── .htaccess-basic-auth
    ├── .htpasswd
    ├── wp-config-prd.php
    ├── wp-config-stg.php
    ├── logs/
    └── tmp/
```

## WordPress固有値の設定

### 環境変数（.env）

`.env.example`を`.env`にコピーして編集します。

```bash
cd .wp-sync
cp .env.example .env
```

| 環境変数名 | 設定内容 | 設定例 |
| --- | --- | --- |
| PRD_DOMAIN | 本番環境のドメイン名 | example.com |
| STG_DOMAIN | ステージング環境のドメイン名 | stg.example.com |
| PRD_SSH_DESTINATION | 本番環境のSSH接続先（ユーザ名@ホスト名） | xs◯◯◯◯◯◯@xs◯◯◯◯◯◯.xsrv.jp |
| STG_SSH_DESTINATION | ステージング環境のSSH接続先 | xs◯◯◯◯◯◯@xs◯◯◯◯◯◯.xsrv.jp |
| PRD_SSH_PORT | 本番環境のSSHポート番号 | 10022 |
| STG_SSH_PORT | ステージング環境のSSHポート番号 | 10022 |
| PRD_PUBLIC_DIR_PATH | 本番環境の公開ディレクトリパス | /home/xs◯◯◯◯◯◯/example.com/public_html |
| STG_PUBLIC_DIR_PATH | ステージング環境の公開ディレクトリパス | /home/xs◯◯◯◯◯◯/example.com/public_html/stg.example.com |
| PRD_DB_HOST | 本番環境のDBホスト名 | localhost, mysql12016.xserver.jp |
| STG_DB_HOST | ステージング環境のDBホスト名 | localhost, mysql12016.xserver.jp |
| PRD_DB_NAME | 本番環境のDB名 | xs◯◯◯◯◯◯_wp◯ |
| STG_DB_NAME | ステージング環境のDB名 | xs◯◯◯◯◯◯_wp◯ |
| PRD_DB_USER | 本番環境のDBユーザ名 | xs◯◯◯◯◯◯_wp◯ |
| STG_DB_USER | ステージング環境のDBユーザ名 | xs◯◯◯◯◯◯_wp◯ |
| PRD_DB_PASSWORD | 本番環境のDBパスワード | （パスワード） |
| STG_DB_PASSWORD | ステージング環境のDBパスワード | （パスワード） |
| EXCLUDES | 同期対象外のパス（カンマ区切り） | wp-content/cache,wp-content/uploads/backwpup-*-logs |
| PLUGINS | ステージング環境で無効化するプラグイン（カンマ区切り） | wordfence,redis-cache,wp-optimize,autoptimize |

### Basic認証設定

本番→ステージング同期時にBasic認証を自動設定、ステージング→本番同期時に自動解除する際に使用する情報を設定します。

#### .htaccess-basic-auth

`AuthUserFile`にサーバ上での`.htpasswd`の絶対パスを設定します。

```apache
AuthUserFile "/home/xxxxxxx/example.com/.htpasswd/stg.example.com"
AuthName "Member Site"
AuthType BASIC
require valid-user
```

#### .htpasswd

ステージング環境で使用するBasic認証のユーザ名・パスワードを設定します。
サーバ上の`.htpasswd`を参照して同様の値を設定してください。

```text
{ユーザ名}:{暗号化されたパスワード}
```

### wp-config.php設定

各環境のwp-config.phpの内容をそれぞれ以下のファイルにコピーします。

- `wp-config-prd.php` - 本番環境のwp-config.php
- `wp-config-stg.php` - ステージング環境のwp-config.php

## 使用方法

実行前にSSHの秘密鍵を登録しておく必要があります：

```bash
ssh-add ~/.ssh/id_rsa  # 秘密鍵のパスを指定
```

作業ディレクトリで実行：

```bash
wp-sync prd-to-stg    # 本番 → ステージング同期
wp-sync stg-to-prd    # ステージング → 本番同期
wp-sync help          # ヘルプ表示
```

### 実行例

```bash
$ wp-sync prd-to-stg
[2025-12-27 16:58:00] [INFO] 本番 → ステージング同期を開始します...
[2025-12-27 16:58:00] [INFO] ログファイル: .wp-sync/logs/2025-12-27_165800_prd-to-stg.log


------------------------------ステージング環境バックアップ　開始------------------------------
[2025-12-27 16:58:00] [INFO] 【DBをバックアップ】
[2025-12-27 16:58:00] [INFO]   出力先: ./.wp-sync/tmp/stg_dump.sql
[2025-12-27 16:58:00] [SUCCESS] 【完了】
[2025-12-27 16:58:00] [INFO] 【public_htmlをバックアップ】
[2025-12-27 16:58:00] [INFO]   コピー元: xxxxxxx@xxxxxxx.xsrv.jp:/home/xxxxxxx/example.com/public_html/stg.example.com
[2025-12-27 16:58:00] [INFO]   コピー先: ./.wp-sync/tmp/stg_public_html

　・
　・
　・

------------------------------後処理　完了------------------------------
[2025-12-27 16:58:56] [SUCCESS] 本番 → ステージング同期が完了しました
```

## 免責事項

- 本ツールは無保証で提供されます。使用によって生じたいかなる損害についても、作者は責任を負いません。
- 本番環境への同期を行う前に、必ずバックアップを取得し、リストア手順を事前に確認しておいてください。
- 重要なデータを扱う場合は、事前にテスト環境で動作確認を行うことを強く推奨します。

## 関連リンク

- [【WordPress】本番環境とステージング環境をコマンド1つで簡単に同期する - エンジニアビギナー](https://hiro8blog.com/sync-wp-between-local-and-production/)
