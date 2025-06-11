#!/bin/bash

# ユーザーセットアップスクリプトを実行
/usr/local/bin/setup_users.sh

# ログディレクトリの権限を設定
mkdir -p /var/log
chmod 755 /var/log

# 空のログファイルを作成して適切な権限を設定
touch /var/log/ssh.log
chmod 666 /var/log/ssh.log
chown root:root /var/log/ssh.log

# rsyslogの設定を確認・追加
if ! grep -q "auth,authpriv.* /var/log/ssh.log" /etc/rsyslog.conf; then
    echo "Adding SSH log configuration to rsyslog.conf"
    echo "auth,authpriv.* /var/log/ssh.log" >> /etc/rsyslog.conf
fi

# カーネルログエラーを無視するように設定
if ! grep -q "imklog.IgnoreKernelTimestamp=\"on\"" /etc/rsyslog.conf; then
    echo '$ModLoad imklog' > /tmp/rsyslog.conf
    echo '$imklog.IgnoreKernelTimestamp="on"' >> /tmp/rsyslog.conf
    cat /etc/rsyslog.conf >> /tmp/rsyslog.conf
    mv /tmp/rsyslog.conf /etc/rsyslog.conf
fi

# rsyslogを起動（バックグラウンドで実行）
rsyslogd -n &

# 少し待ってからSSHサーバーを起動
sleep 2

# SSHサーバーを起動
/usr/sbin/sshd -D
