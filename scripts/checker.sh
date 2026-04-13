#!/bin/bash
# Fedora / Kali Linux / Debian SSH 诊断工具

# 检测系统类型
detect_distro() {
    if [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/kali-release ] || grep -qi "kali" /etc/os-release 2>/dev/null; then
        echo "kali"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

case "$DISTRO" in
    fedora)
        echo "=== Fedora SSH 诊断工具 ==="
        ;;
    kali)
        echo "=== Kali Linux SSH 诊断工具 ==="
        ;;
    debian)
        echo "=== Debian Linux SSH 诊断工具 ==="
        ;;
    *)
        echo "错误: 不支持的发行版"
        exit 1
        ;;
esac

# 1. 检查 ssh/sshd 服务
echo "[1] 检查 ssh 服务状态..."
if [ "$DISTRO" = "fedora" ]; then
    systemctl is-active sshd >/dev/null 2>&1 && echo "✅ sshd 已运行" || echo "❌ sshd 未运行"
else
    # Kali 和 Debian 使用 ssh 服务名
    systemctl is-active ssh >/dev/null 2>&1 && echo "✅ ssh 已运行" || echo "❌ ssh 未运行"
fi

# 2. 检查防火墙
echo "[2] 检查防火墙是否放行 SSH..."
if [ "$DISTRO" = "fedora" ]; then
    firewall-cmd --list-services | grep -qw ssh && echo "✅ 防火墙已放行 ssh" || echo "❌ 防火墙未放行 ssh (运行: sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload)"
else
    # Kali 和 Debian 使用 ufw 或 iptables
    if command -v ufw &> /dev/null; then
        ufw status | grep -qw "22/tcp" && echo "✅ 防火墙已放行 ssh" || echo "❌ 防火墙未放行 ssh (运行: sudo ufw allow ssh && sudo ufw reload)"
    else
        echo "⚠️  未检测到 ufw 防火墙，请检查 iptables 或其他防火墙配置"
    fi
fi

# 3. 检查 SELinux
echo "[3] 检查 SELinux 状态..."
if command -v getenforce &> /dev/null; then
    getenforce
else
    echo "⚠️  SELinux 未安装"
fi

# 4. 检查 root 登录设置
echo "[4] 检查是否允许 root 登录..."
grep -i "^PermitRootLogin" /etc/ssh/sshd_config || echo "未找到 PermitRootLogin 配置"

# 5. 显示主机 IP
echo "[5] 主机 IP 地址:"
ip -4 addr show | grep inet | awk '{print $2}' | grep -v "127.0.0.1"

echo "=== 检查完成 ==="
echo "提示：WinSCP 请使用 SFTP 协议 + $DISTRO 用户 + 密码"
