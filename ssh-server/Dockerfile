FROM ubuntu:latest

# 環境変数を設定してインタラクティブなプロンプトを無効化
ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    vim \
    nano \
    python3 \
    python3-pip \
    rsyslog \
    && rm -rf /var/lib/apt/lists/*

# SSHサーバーの設定
RUN mkdir -p /var/run/sshd
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# keyユーザーのパスワード認証を無効化する設定を追加
COPY config/ssh_config_match.conf /etc/ssh/sshd_config.d/
RUN chmod 644 /etc/ssh/sshd_config.d/ssh_config_match.conf
RUN echo 'Include /etc/ssh/sshd_config.d/*.conf' >> /etc/ssh/sshd_config

# SSHログの詳細設定を有効化
RUN sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config

# rsyslogの設定を変更してSSHログを専用ファイルに出力
RUN echo 'auth,authpriv.* /var/log/ssh.log' >> /etc/rsyslog.conf

# カーネルログの警告を抑制するための設定
RUN sed -i 's/^\$ModLoad imklog/#\$ModLoad imklog/' /etc/rsyslog.conf || echo "imklog not found in config"

# 空のログファイルを作成し、適切な権限を設定
RUN touch /var/log/ssh.log && chmod 666 /var/log/ssh.log

# kanolabユーザーを作成してsudo権限を付与
RUN useradd -m -s /bin/bash kanolab && \
    echo 'kanolab:kano2333' | chpasswd && \
    usermod -aG sudo kanolab

# ユーザー作成スクリプトを追加
COPY scripts/setup_users.sh /usr/local/bin/
COPY data/students.csv /tmp/students.csv
RUN chmod +x /usr/local/bin/setup_users.sh

# ユーザー用の.bashrcを用意
COPY config/.bashrc_pass_user /usr/local/share/.bashrc_pass_user
COPY config/.bashrc_key_user /usr/local/share/.bashrc_key_user

# 起動スクリプトを追加
COPY scripts/start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

# SSHのポートを公開
EXPOSE 22

# コンテナ起動時にstart.shを実行
CMD ["/usr/local/bin/start.sh"]
