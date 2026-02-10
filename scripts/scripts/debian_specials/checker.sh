#!/bin/bash
echo "=== Debian Linux SSH 诊断工具 ==="

# 1. 检查 ssh 服务
echo "[1] 检查 ssh 服务状态..."
systemctl is-active ssh >/dev/null 2>&1 && echo "✅ ssh 已运行" || echo "❌ ssh 未运行"

# 2. 检查防火墙
echo "[2] 检查防火墙是否放行 SSH..."
if command -v ufw &> /dev/null; then
    ufw status | grep -qw "22/tcp" && echo "✅ 防火墙已放行 ssh" || echo "❌ 防火墙未放行 ssh (运行: sudo ufw allow ssh && sudo ufw reload)"
else
    echo "⚠️  未检测到 ufw 防火墙，请检查 iptables 或其他防火墙配置"
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
echo "提示：WinSCP 请使用 SFTP 协议 + Debian 用户 + 密码"
