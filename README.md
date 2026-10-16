# wp-sync

WordPressサイトのステージング環境と本番環境間で、DB・ファイルの同期をコマンド1つで行うツール。

## 機能

- **DB同期**: `mysqldump/mysql`経由でデータベースを同期
- **ファイル同期**: `rsync`経由でファイルを同期
- **ドメイン置換**: WP-CLIの`search-replace`でURLを自動置換
- **wp-config.php同期**: ソースの変更をコピー先に反映しつつ、環境固有の定数（DB接続情報・Auth keysなど）を両環境の `wp-config.php` を比較して自動検出し、コピー先の値に復元
- **Basic認証**: ステージング環境へのBasic認証を自動設定/解除
- **プラグイン管理**: 環境に応じたプラグインの自動有効化/無効化
- **キャッシュ削除**: Redis, Autoptimize, WP-Optimizeのキャッシュを自動削除
- **ログ出力**: `sites/<domain>/logs/`に保存（30日間保持）
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
│   ├── run-sync.sh             # 同期処理（方向を引数で受け取る）
│   ├── activate-plugin.sh      # プラグイン有効化
│   └── deactivate-plugin.sh    # プラグイン無効化
├── lib/
│   ├── backup.sh               # バックアップ処理
│   ├── basic-auth.sh           # Basic認証設定
│   ├── env.sh                  # 同期方向に応じた変数のセットアップ
│   ├── log.sh                  # ログ出力
│   ├── diff-constants.php      # wp-config.php差分定数検出
│   ├── restore-constants.php   # wp-config.php環境固有定数復元
│   ├── restore.sh              # ロールバック処理
│   └── sync.sh                 # 同期処理
├── template/                   # `wp-sync init`が sites/<domain>/ にコピーする設定
│   ├── .env.example            # 環境変数テンプレート
│   ├── .htaccess-basic-auth    # Basic認証用.htaccess
│   ├── .htpasswd               # Basic認証用パスワード
│   ├── logs/.gitkeep
│   └── tmp/.gitkeep
├── sites/                      # サイト別設定（`wp-sync init`で作成。git管理外）
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

### 3. サイト設定を初期化

同期対象のドメインごとに、`wp-sync init <domain>`でサイト設定を作成します。  
`template`ディレクトリの中身が`sites/<domain>/`にコピーされ、`.env.example`は`.env`にリネームされます。

```bash
wp-sync init example.com
```

作成されるディレクトリ構成：

```text
wp-sync/
└── sites/
    └── example.com/             ← WordPress固有設定ファイル用ディレクトリ
        ├── .env
        ├── .htaccess-basic-auth
        ├── .htpasswd
        ├── logs/
        └── tmp/
```

## WordPress固有値の設定

### 環境変数（.env）

`sites/<domain>/.env`を編集します。

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
| PRD_PUBLIC_DIR_SCP_PATH | 本番環境の公開ディレクトリのSCP形式パス（ユーザ名@ホスト名:パス）で、バックアップ・リストア時のrsyncに使用 | xs◯◯◯◯◯◯@xs◯◯◯◯◯◯.xsrv.jp:/home/xs◯◯◯◯◯◯/example.com/public_html |
| STG_PUBLIC_DIR_SCP_PATH | ステージング環境の公開ディレクトリのSCP形式パス | xs◯◯◯◯◯◯@xs◯◯◯◯◯◯.xsrv.jp:/home/xs◯◯◯◯◯◯/example.com/public_html/stg.example.com |
| PLUGINS | ステージング環境で無効化するプラグイン（カンマ区切り） | wordfence,redis-cache,wp-optimize,autoptimize |

### Basic認証設定

本番→ステージング同期時にBasic認証を自動設定、ステージング→本番同期時に自動解除する際に使用する情報を設定します。

#### .htaccess-basic-auth

`.htpasswd`はステージング環境のSSHユーザのホームディレクトリ直下（`~/.htpasswd`）にアップロードされます。  
`AuthUserFile`にはその絶対パスを設定します。  

```apache
AuthUserFile "/home/xxxxxxx/.htpasswd"
AuthName "Member Site"
AuthType BASIC
require valid-user
```

#### .htpasswd

ステージング環境で使用するBasic認証のユーザ名・パスワードを設定します。  
本番→ステージング同期のたびに、サーバ上の`~/.htpasswd`がこのファイルの内容で上書きされます。  

```text
{ユーザ名}:{暗号化されたパスワード}
```

## 使用方法

実行前にSSHの秘密鍵を登録しておく必要があります：

```bash
ssh-add ~/.ssh/id_rsa  # 秘密鍵のパスを指定
```

```bash
wp-sync init <domain>         # サイト設定を初期化
wp-sync prd-to-stg <domain>   # 本番 → ステージング同期
wp-sync stg-to-prd <domain>   # ステージング → 本番同期
wp-sync help                  # ヘルプ表示
```

### 実行例

```bash
$ wp-sync prd-to-stg example.com
[2025-12-27 16:58:00] [INFO] 本番 → ステージング同期を開始します...
[2025-12-27 16:58:00] [INFO] ログファイル: /path/to/wp-sync/sites/example.com/logs/20251227_165800_prd-to-stg.log


------------------------------ステージング環境バックアップ　開始------------------------------
[2025-12-27 16:58:00] [INFO] 【DBをバックアップ】
[2025-12-27 16:58:00] [INFO]   出力先: /path/to/wp-sync/sites/example.com/tmp/stg_dump.sql
[2025-12-27 16:58:00] [SUCCESS] 【完了】
[2025-12-27 16:58:00] [INFO] 【public_htmlをバックアップ】
[2025-12-27 16:58:00] [INFO]   コピー元: xxxxxxx@xxxxxxx.xsrv.jp:/home/xxxxxxx/example.com/public_html/stg.example.com
[2025-12-27 16:58:00] [INFO]   コピー先: /path/to/wp-sync/sites/example.com/tmp/stg_public_html

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
