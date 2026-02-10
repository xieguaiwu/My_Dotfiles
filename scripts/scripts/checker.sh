#!/bin/bash
echo "=== Fedora SSH 诊断工具 ==="

# 1. 检查 sshd 服务
echo "[1] 检查 sshd 服务状态..."
systemctl is-active sshd >/dev/null 2>&1 && echo "✅ sshd 已运行" || echo "❌ sshd 未运行"

# 2. 检查防火墙
echo "[2] 检查防火墙是否放行 SSH..."
firewall-cmd --list-services | grep -qw ssh && echo "✅ 防火墙已放行 ssh" || echo "❌ 防火墙未放行 ssh (运行: sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload)"

# 3. 检查 SELinux
echo "[3] 检查 SELinux 状态..."
getenforce

# 4. 检查 root 登录设置
echo "[4] 检查是否允许 root 登录..."
grep -i "^PermitRootLogin" /etc/ssh/sshd_config

# 5. 显示主机 IP
echo "[5] 主机 IP 地址:"
ip -4 addr show | grep inet | awk '{print $2}' | grep -v "127.0.0.1"

echo "=== 检查完成 ==="
echo "提示：WinSCP 请使用 SFTP 协议 + Fedora 用户 + 密码"

