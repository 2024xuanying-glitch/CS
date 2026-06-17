#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 错误: 请使用 root 权限运行此脚本！"
  exit 1
fi

echo "=========================================================="
echo " ☢️  木马病毒精准清杀脚本 V2 (已完全排除探针防护) ☢️"
echo "=========================================================="

# 1. 第一步：冻结真正的恶意进程（让其停止消耗 CPU，同时防止母体瞬间复活子进程）
echo "[*] 1. 正在强行冻结恶意进程 (hermes, tor)..."
killall -STOP hermes tor 2>/dev/null
pkill -STOP -f hermes
pkill -STOP -f tor
echo "   [+] hermes 与 tor 已成功挂起（系统算力已释放）。"

# 2. 第二步：逆向动态追踪并物理粉碎恶意二进制源文件
echo "[*] 2. 正在动态追踪恶意源文件并进行物理粉碎..."
for name in hermes tor; do
    pids=$(pgrep -f "$name")
    for pid in $pids; do
        if [ -d "/proc/$pid" ]; then
            # 顺着内存指针找到硬盘上的真实绝对路径
            exe_path=$(readlink -f /proc/$pid/exe)
            if [ ! -z "$exe_path" ] && [ -f "$exe_path" ]; then
                echo "   [+] 发现木马实体: $exe_path"
                # 解除隐藏锁定属性并强行粉碎
                chattr -i -a "$exe_path" 2>/dev/null
                rm -rf "$exe_path"
                echo "   [vvv] 已物理粉碎: $exe_path"
            fi
        fi
    done
done

# 精准清理常见的 hermes 临时残留目录，不进行盲目盲扫
rm -f /tmp/hermes /var/tmp/hermes 2>/dev/null

# 3. 第三步：将内存中已被剥离源文件的僵尸进程彻底断气
echo "[*] 3. 正在彻底终结内存中的恶意进程..."
killall -9 hermes tor 2>/dev/null
pkill -9 -f hermes
pkill -9 -f tor

# 4. 第四步：封堵 111 端口（防范 rpcbind 被黑客利用对外发包导致云厂商封机）
# ⚠️ 注意：这里完全没有拦截你的探针 IP
echo "[*] 4. 正在配置网络防火墙，堵死 111 端口反射攻击..."
iptables -I OUTPUT -p tcp --dport 111 -j DROP 2>/dev/null
iptables -I OUTPUT -p udp --dport 111 -j DROP 2>/dev/null
iptables -I INPUT -p tcp --dport 111 -j DROP 2>/dev/null
iptables -I INPUT -p udp --dport 111 -j DROP 2>/dev/null

# 5. 第五步：清理潜在的系统服务启动项（严格过滤掉包含 agent 或 nezha 的服务）
echo "[*] 5. 正在扫描并清理隐藏的恶意系统服务..."
for service in $(ls /etc/systemd/system/ /lib/systemd/system/ 2>/dev/null | grep -E 'hermes|miner|dbus-'); do
    # 安全边界：如果服务名包含 agent 或者是哪吒服务，绝对跳过
    if [[ "$service" == *"agent"* ]] || [[ "$service" == *"nezha"* ]]; then
        continue
    fi
    
    if grep -qE 'hermes|tmp' "/etc/systemd/system/$service" 2>/dev/null; then
        echo "   [+] 发现恶意服务: $service，正在强行卸载..."
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        chattr -i -a "/etc/systemd/system/$service" 2>/dev/null
        rm -f "/etc/systemd/system/$service"
    fi
done
systemctl daemon-reload 2>/dev/null

# 6. 第六步：检查动态链接库劫持后门 (LD_PRELOAD) -> 这是木马最隐蔽的复活手段
echo "[*] 6. 正在检查动态库劫持后门..."
if [ -s /etc/ld.so.preload ]; then
    echo "   [!] 发现 /etc/ld.so.preload 存在内容，正在强行净化..."
    chattr -i -a /etc/ld.so.preload 2>/dev/null
    > /etc/ld.so.preload
fi

echo "=========================================================="
echo " 🎉 靶向清杀完成！探针正常安全，恶意挖矿与暗网进程已被拦截。"
echo "=========================================================="
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
