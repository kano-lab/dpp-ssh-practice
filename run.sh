#!/bin/bash

# ホストのIPアドレスを自動検出
# Linuxの場合
if [ "$(uname)" == "Linux" ]; then
    HOST_IP=$(hostname -I | awk '{print $1}')
# macOSの場合
elif [ "$(uname)" == "Darwin" ]; then
    HOST_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
# その他のOS（WindowsのWSL等）
else
    # デフォルトゲートウェイに接続されているインターフェースのIPを取得
    HOST_IP=$(ip route get 1 | awk '{print $7}')
fi

# IPアドレスが見つからない場合はlocalhostをデフォルトに
if [ -z "$HOST_IP" ]; then
    HOST_IP="localhost"
    echo "ホストIPアドレスを自動検出できませんでした。デフォルト値 'localhost' を使用します。"
else
    echo "ホストIPアドレス: $HOST_IP を検出しました。"
fi

# 環境変数にセット
export HOST_IP

# Docker Composeを起動
docker compose up --build -d

# コンテナが正常に起動したかチェック
if docker compose ps | grep -q "Up"; then
    # 情報表示
    echo "============================================="
    echo "SSH演習環境が起動しました"
    echo "ホストIPアドレス: $HOST_IP"
    echo "============================================="
    echo "接続方法:"
    echo "パスワード認証: ssh -p 2222 [学籍番号]pass@$HOST_IP"
    echo "公開鍵認証: ssh -p 2222 [学籍番号]key@$HOST_IP"
    echo "============================================="
else
    echo "エラー: コンテナの起動に失敗しました"
    docker compose ps
fi

