#!/bin/bash
# 清理导致 2026-06-05 意外关机的根本问题
# 以 root 权限运行: sudo bash cleanup_shutdown_issue.sh

set -e

echo "=== 1/4 清理 journal（当前 3.9GB → 500MB）==="
journalctl --vacuum-size=500M
echo ""

echo "=== 2/4 限制 journal 大小防止再次膨胀 ==="
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/limit.conf << 'EOF'
[Journal]
SystemMaxUse=500M
RuntimeMaxUse=200M
EOF
echo "已写入 /etc/systemd/journald.conf.d/limit.conf"
echo ""

echo "=== 3/4 清理旧 core dump（释放 441MB）==="
BEFORE=$(du -sh /var/lib/systemd/coredump/ 2>/dev/null | cut -f1)
rm -f /var/lib/systemd/coredump/core.python3*
rm -f /var/lib/systemd/coredump/core.localsearch-ext*
rm -f /var/lib/systemd/coredump/core.obsidian*
rm -f /var/lib/systemd/coredump/core.btop*
rm -f /var/lib/systemd/coredump/core.ex11*
rm -f /var/lib/systemd/coredump/core.fcitx5*
rm -f /var/lib/systemd/coredump/core.test_*
rm -f /var/lib/systemd/coredump/core.sway*
AFTER=$(du -sh /var/lib/systemd/coredump/ 2>/dev/null | cut -f1)
echo "core dump 目录: ${BEFORE} → ${AFTER}"
echo ""

echo "=== 4/4 禁用 ABRT 自动处理（防止再次内存爆炸）==="
systemctl disable --now abrt-journal-core abrt-oops abrt-xorg 2>/dev/null || true
echo "ABRT 组件已禁用"
echo ""

echo "=== 重新加载配置 ==="
systemctl restart systemd-journald
echo "journald 已重启，新限制生效"

echo ""
echo "=== 清理完成 ==="
echo "当前 journal 占用:"
journalctl --disk-usage 2>/dev/null
