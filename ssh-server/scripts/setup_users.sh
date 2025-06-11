#!/bin/bash
# CSVファイルのパス
CSV_FILE="/tmp/students.csv"
# CSVファイルが存在するか確認
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: $CSV_FILE not found."
    exit 1
fi
# CSVファイルを読み込んでユーザーとグループを作成
while IFS=, read -r student_id || [ -n "$student_id" ]; do
    # 空行や空白行をスキップ
    if [ -z "$(echo "$student_id" | tr -d '[:space:]')" ]; then
        continue
    fi
    
    # 学籍番号を整形（空白を削除）
    student_id=$(echo "$student_id" | tr -d '[:space:]')
    
    echo "Processing student ID: $student_id"
    
    # passユーザー用とkeyユーザー用に別々のグループを作成
    pass_group="pass_${student_id}"
    key_group="key_${student_id}"
    
    # passユーザー用グループの作成
    if ! getent group "$pass_group" > /dev/null; then
        groupadd "$pass_group" || echo "Failed to create group: $pass_group"
    else
        echo "Group $pass_group already exists."
    fi
    
    # keyユーザー用グループの作成
    if ! getent group "$key_group" > /dev/null; then
        groupadd "$key_group" || echo "Failed to create group: $key_group"
    else
        echo "Group $key_group already exists."
    fi
    
    # パスワード認証用ユーザーの作成
    pass_user="${student_id}pass"
    if ! id "$pass_user" &>/dev/null; then
        useradd -m -g "$pass_group" -s /bin/bash "$pass_user" || echo "Failed to create user: $pass_user"
        echo "$pass_user:$student_id" | chpasswd || echo "Failed to set password for user: $pass_user"
        echo "Created password user: $pass_user with password: $student_id"
    else
        echo "User $pass_user already exists."
    fi
    
    # 鍵認証用ユーザーの作成
    key_user="${student_id}key"
    if ! id "$key_user" &>/dev/null; then
        useradd -m -g "$key_group" -s /bin/bash "$key_user" || echo "Failed to create user: $key_user"
        # keyユーザーにもパスワードを設定
        echo "$key_user:$student_id" | chpasswd || echo "Failed to set password for user: $key_user"
        echo "Created key user: $key_user with password: $student_id"
        
        # ホームディレクトリが作成されたか確認
        if [ -d "/home/$key_user" ]; then
            # .sshディレクトリとauthorized_keysファイルを作成
            mkdir -p "/home/$key_user/.ssh"
            touch "/home/$key_user/.ssh/authorized_keys"
            # 所有者とグループを適切に設定
            chown -R "$key_user:$key_group" "/home/$key_user"
            chown -R "$key_user:$key_group" "/home/$key_user/.ssh"
            chown "$key_user:$key_group" "/home/$key_user/.ssh/authorized_keys"
            # ホームディレクトリの権限
            chmod 750 "/home/$key_user"
            # .sshディレクトリの権限
            chmod 700 "/home/$key_user/.ssh"
            # authorized_keysファイルの権限
            chmod 600 "/home/$key_user/.ssh/authorized_keys"
            echo "Created key user: $key_user with .ssh directory and authorized_keys file"
        else
            echo "Home directory for $key_user was not created properly"
        fi
    else
        echo "User $key_user already exists."
        # 既存ユーザーの場合も.sshディレクトリがあれば権限を再設定
        if [ -d "/home/$key_user/.ssh" ]; then
            chown -R "$key_user:$key_group" "/home/$key_user/.ssh"
            chmod 700 "/home/$key_user/.ssh"
            if [ -f "/home/$key_user/.ssh/authorized_keys" ]; then
                chown "$key_user:$key_group" "/home/$key_user/.ssh/authorized_keys"
                chmod 600 "/home/$key_user/.ssh/authorized_keys"
            fi
            echo "Reset permissions for existing .ssh directory"
        fi
    fi
    
    # passユーザーのホームディレクトリの権限設定
    if [ -d "/home/$pass_user" ]; then
        chmod 750 "/home/$pass_user"
        chown -R "$pass_user:$pass_group" "/home/$pass_user"
        echo "Set permissions for /home/$pass_user"
    else
        echo "Directory /home/$pass_user does not exist, skipping permission setting"
    fi
    
    # .bashrc_pass_userをコピー
    if [ -f "/usr/local/share/.bashrc_pass_user" ]; then
        cp "/usr/local/share/.bashrc_pass_user" "/home/$pass_user/.bashrc"
        chown "$pass_user:$pass_group" "/home/$pass_user/.bashrc"
        chmod 644 "/home/$pass_user/.bashrc"
        echo "Copied .bashrc_pass_user to /home/$pass_user/.bashrc"
    else
        echo "Warning: .bashrc_pass_user template not found"
    fi

    # .bashrc_key_userをコピー
    if [ -f "/usr/local/share/.bashrc_key_user" ]; then
        cp "/usr/local/share/.bashrc_key_user" "/home/$key_user/.bashrc"
        chown "$key_user:$key_group" "/home/$key_user/.bashrc"
        chmod 644 "/home/$key_user/.bashrc"
        echo "Copied .bashrc_key_user to /home/$key_user/.bashrc"
    else
        echo "Warning: .bashrc_key_user template not found"
    fi

    
done < "$CSV_FILE"

echo "User setup completed."
