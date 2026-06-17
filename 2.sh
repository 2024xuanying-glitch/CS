#!/bin/bash

echo "============================================================"
echo " 🚨 恶意软件应急止血与强力清理脚本 🚨"
echo " 警告: 此脚本会清空 crontab，清理临时目录，并尝试强制结束异常进程！"
echo "============================================================"

# 1. 解除常见被锁定的文件限制 (chattr -i / -a)
echo "[*] 正在解除关键目录和文件的隐藏/锁定属性..."
chattr -i -a /etc/crontab /var/spool/cron/root /var/spool/cron/crontabs/root 2>/dev/null
chattr -i -a /root/.ssh/authorized_keys 2>/dev/null
chattr -R -i -a /tmp /var/tmp /dev/shm 2>/dev/null

# 2. 阻断网络：封堵常见挖矿矿池 (如 c3pool)
echo "[*] 正在写入 /etc/hosts 以屏蔽已知恶意域名..."
echo "127.0.0.1 mine.c3pool.com" >> /etc/hosts
echo "127.0.0.1 xmr.crypto-pool.fr" >> /etc/hosts

# 3. 猎杀内存驻留 (memfd) 和伪装进程 (kworker, deleted exe)
echo "[*] 正在强制结束 memfd, systemlog, 伪装 kworker 及高 CPU 进程..."
# 杀掉运行在内存中的无文件恶意程序
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
    if ls -l /proc/$pid/exe 2>/dev/null | grep -q "memfd"; then
        echo "  [+] 击杀 memfd 进程 PID: $pid"
        kill -9 $pid 2>/dev/null
    fi
    if ls -l /proc/$pid/exe 2>/dev/null | grep -q "(deleted)"; then
        # 排除正常的已删除但仍在运行的系统组件
        cmdline=$(cat /proc/$pid/cmdline 2>/dev/null)
        if [[ "$cmdline" != *"kworker"* ]] && [[ "$cmdline" != *"systemd"* ]]; then
             echo "  [+] 击杀 deleted 异常进程 PID: $pid"
             kill -9 $pid 2>/dev/null
        fi
    fi
done

# 杀掉常见的挖矿/木马进程名
pkill -9 -f c3pool
pkill -9 -f systemlog
pkill -9 -f kdevtmpfsi
pkill -9 -f kinsing
pkill -9 -f nezha-agent

# 4. 清理定时任务 (Crontab) - 木马最爱的复活点
echo "[*] 正在强制清空所有用户的定时任务..."
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -r -u $user 2>/dev/null
done
rm -rf /var/spool/cron/*
rm -rf /var/spool/cron/crontabs/*
rm -rf /etc/cron.d/* # 重置 /etc/crontab 为默认空状态
echo "# /etc/crontab: system-wide crontab" > /etc/crontab

# 5. 清除 SSH 后门密钥
echo "[*] 正在清理 /root/.ssh/authorized_keys 中的可疑密钥..."
# 如果你自己的机器是用密码登录的，建议直接清空：
# > /root/.ssh/authorized_keys 
# 如果你用密钥登录，请手动检查 /root/.ssh/authorized_keys 并删除不认识的公钥。

# 6. 核爆级清理临时目录 (木马下载和执行的重灾区)
echo "[*] 正在彻底清理 /tmp, /var/tmp, /dev/shm..."
rm -rf /tmp/* /tmp/.* 2>/dev/null
rm -rf /var/tmp/* /var/tmp/.* 2>/dev/null
rm -rf /dev/shm/* /dev/shm/.* 2>/dev/null

echo "============================================================"
echo " ✅ 应急止血完成！"
echo " ⚠️ 下一步行动指南："
echo " 1. 使用 'top' 或 'htop' 观察是否还有异常占用 CPU 的进程重新出现。"
echo " 2. 如果木马在 1-2 分钟内再次复活，说明存在 Rootkit 或内核后门。"
echo " 3. 无论如何，请立刻备份您的业务数据，然后【重装系统】！"
echo "============================================================"
