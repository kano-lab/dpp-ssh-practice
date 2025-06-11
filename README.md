# DPP SSH 演習環境

このリポジトリはSSH認証の演習を行うためのDocker環境です。パスワード認証と公開鍵認証の両方を学習することができます。

## 概要

この演習環境では、各学生に以下の2つのユーザーアカウントが提供されます：

- **パスワード認証用ユーザー** (`[学籍番号]pass`): パスワード認証でSSH接続可能
- **公開鍵認証用ユーザー** (`[学籍番号]key`): 公開鍵認証のみでSSH接続可能

## 必要なもの

- Docker
- Docker Compose

## セットアップ手順

1. リポジトリをクローンします：
   ```bash
   git clone https://github.com/kano-lab/dpp-ssh-practice.git
   cd dpp-ssh-practice
   ```

2. `./ssh-server/data/students.csv` ファイルを作成し、以下のように学籍番号を追加します：
   ```
   70112001
   70112002
   ...
   ```

3. 環境を起動します：
   ```bash
   ./run.sh
   ```

## 環境構成

- `run.sh`: 環境起動スクリプト
- `compose.yaml`: Docker Compose設定ファイル
- `Dockerfile`: SSHサーバーのDockerイメージ定義
- `setup_users.sh`: ユーザー設定スクリプト
- `start.sh`: コンテナ起動スクリプト
- `students.csv`: 学籍番号リスト
- `ssh_config_match.conf`: SSHサーバー設定ファイル(keyユーザーが公開鍵認証できるようにするためのconfig)

## 使用方法

### 1. パスワード認証ユーザーとしてログイン

```bash
ssh -p 2222 [学籍番号]pass@[ホストIP]
```

例：
```bash
ssh -p 2222 70112001pass@XXX.YYY.ZZZ.AAA
```

パスワードは学籍番号と同じです。

### 2. 公開鍵認証ユーザーとしてログイン

まず、クライアント側で公開鍵と秘密鍵のペアを生成します（まだ持っていない場合）：

```bash
# id_ed25519_practiceというファイル名で鍵を生成
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_practice
```

次に、パスワード認証ユーザーとしてログインし、公開鍵認証ユーザーのauthorized_keysファイルに公開鍵を設定します：

```bash
# パスワード認証でログイン
ssh -p 2222 70112001pass@[ホストIP]

# パスワードを使ってkeyユーザーに切り替え
su 70112001key

# .sshディレクトリの権限を確認
ls -la ~/.ssh
# 権限が700でない場合は修正
chmod 700 ~/.ssh

# 公開鍵を追加
echo "ssh-ed25519 AAAA..." > ~/.ssh/authorized_keys
# または viエディタで編集
vi ~/.ssh/authorized_keys

# authorized_keysファイルの権限を確認
chmod 600 ~/.ssh/authorized_keys
```

最後に、公開鍵認証でログインを試みます：

```bash
ssh -i ~/.ssh/id_ed25519_practice -p 2222 70112001key@[ホストIP]
```

## セキュリティ設定

- passユーザー: パスワード認証のみ有効
- keyユーザー: 公開鍵認証のみ有効（パスワード認証は無効）
- 各ユーザーは別々のグループに所属
- .sshディレクトリは700、authorized_keysファイルは600の権限に設定
- ホームディレクトリは750の権限に設定

## ローカルマシンでのテスト
ローカルでコンテナを起動したのちに、
```bash
# コンテナの起動
./run.sh
```
別のセッションを起動し、ホストIPに`localhost`を指定してログインを試みます。(公開鍵認証ユーザーも同じです)
```
ssh -p 2222 70112001pass@localhost
```

## ログ

SSHの認証ログは以下のファイルで確認できます：

```bash
cat /var/log/ssh.log
```

## トラブルシューティング

公開鍵認証でログインできない場合：

1. 権限を確認：
   ```bash
   ls -la ~/.ssh # 700
   ls -la ~/.ssh/authorized_keys # 600
   ```

2. SSHサーバーのデバッグログを確認：
   ```bash
   # Dockerコンテナ内で実行
   cat /var/log/ssh.log
   ```

3. 詳細なデバッグ情報を含めてSSH接続を試す：
   ```bash
   ssh -vvv -i ~/.ssh/id_ed25519_practice -p 2222 [学籍番号]key@[ホストIP]
   ```

## ライセンス
このプロジェクトはMITライセンスの下で公開されています。 

## 開発
Mizuki Baba 
mbaba@kanolab.net

