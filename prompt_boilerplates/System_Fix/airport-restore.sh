#!/bin/bash
# ============================================================
# airport-restore.sh — 公共网络加固恢复脚本 (与 airport-harden.sh 配套)
#
# 用法:
#   sudo ./airport-restore.sh          # 恢复: SSH放行 / Samba自启 / LLMNR还原
#
# 恢复内容:
#   1. 将 ssh 服务重新加入 firewalld 活动 zone 放行列表
#   2. 重新启用并启动 Samba (smb/smbd)
#   3. 从 .airport-bak 备份还原 /etc/systemd/resolved.conf
#      (无备份时仅移除 harden 脚本写入的 LLMNR=no 行)
#   4. 顺带清理机场临时白名单 rich rule
#      (source 223.109.239.11 + service ssh, 若存在)
#
# 说明:
#   - 幂等: 重复执行安全
#   - 仅撤销 airport-harden.sh 所做的改动, 不触碰其他防火墙配置
#   - 其他来源的 ssh rich rule 不会被删除, 只会提示
# ============================================================

set -uo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'

ok()   { echo "  ${GREEN}[OK]${NC}   $*"; }
warn() { echo "  ${YELLOW}[SKIP]${NC} $*"; }
fail() { echo "  ${RED}[FAIL]${NC}  $*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "必须用 sudo 运行: sudo $0" >&2
    exit 1
fi

RESOLVED_CONF=/etc/systemd/resolved.conf

# 与 harden 脚本一致的 zone 探测
ZONE=""
if systemctl is-active --quiet firewalld; then
    ZONE=$(firewall-cmd --get-zone-of-interface=wlp4s0 2>/dev/null || true)
    [ -n "$ZONE" ] || ZONE=$(firewall-cmd --get-default-zone 2>/dev/null || true)
else
    warn "firewalld 未运行, 跳过防火墙步骤"
fi

# 机场临时白名单 (harden 讨论中给出过的示例规则)
TMP_RICH='rule family=ipv4 source address=223.109.239.11/32 service name=ssh accept'

restore_ssh() {
    echo "== [1/4] 恢复入站 SSH (zone: ${ZONE:-无})"
    [ -z "$ZONE" ] && { warn "无活动 zone, 跳过"; return; }
    if firewall-cmd --zone="$ZONE" --query-service=ssh --quiet; then
        ok "ssh 已在 zone $ZONE 放行列表"
    else
        firewall-cmd --permanent --zone="$ZONE" --add-service=ssh && \
            firewall-cmd --reload
        ok "ssh 已重新加入 zone $ZONE 放行 (重启后仍生效)"
    fi
}

cleanup_rich_rule() {
    echo "== [2/4] 清理机场临时 ssh 白名单"
    [ -z "$ZONE" ] && { warn "无活动 zone, 跳过"; return; }
    if firewall-cmd --zone="$ZONE" --query-rich-rule="$TMP_RICH" --quiet; then
        firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule="$TMP_RICH" && \
            firewall-cmd --reload
        ok "已移除临时白名单 (223.109.239.11 → ssh)"
    else
        ok "未发现该临时白名单"
    fi
    # 报告其他含 ssh 的 rich rule (不删除, 由用户决定)
    REMAIN=$(firewall-cmd --zone="$ZONE" --list-rich-rules 2>/dev/null | grep -i 'service name="ssh"' || true)
    if [ -n "$REMAIN" ]; then
        warn "以下其他 ssh rich rule 仍存在(未动):"
        echo "$REMAIN" | sed 's/^/    /'
    fi
}

restore_smb() {
    echo "== [3/4] 恢复 Samba"
    FOUND=0
    for svc in smb smbd; do
        if systemctl cat "$svc" >/dev/null 2>&1; then
            systemctl enable --now "$svc" 2>/dev/null || true
            ok "$svc 已恢复自启并启动"
            FOUND=1
        fi
    done
    [ "$FOUND" -eq 0 ] && warn "未找到 smb/smbd 服务单元"
}

restore_llmnr() {
    echo "== [4/4] 还原 LLMNR 配置"
    if [ -f "${RESOLVED_CONF}.airport-bak" ]; then
        cp -a "${RESOLVED_CONF}.airport-bak" "$RESOLVED_CONF"
        systemctl restart systemd-resolved
        ok "resolved.conf 已从备份还原"
    elif grep -qE '^[[:space:]]*LLMNR=no' "$RESOLVED_CONF"; then
        sed -i -E '/^[[:space:]]*LLMNR=no/d' "$RESOLVED_CONF"
        systemctl restart systemd-resolved
        ok "已移除 LLMNR=no 行 (无备份可用)"
    else
        ok "LLMNR 配置无改动"
    fi
}

verify() {
    echo "== 验证结果"
    PASS=1
    if [ -n "$ZONE" ] && firewall-cmd --zone="$ZONE" --query-service=ssh --quiet; then
        ok "SSH 已重新放行"
    else
        [ -n "$ZONE" ] && { fail "SSH 未放行"; PASS=0; }
    fi
    if systemctl cat smb >/dev/null 2>&1 || systemctl cat smbd >/dev/null 2>&1; then
        if systemctl is-active --quiet smb 2>/dev/null || \
           systemctl is-active --quiet smbd 2>/dev/null; then
            ok "Samba 已运行"
        else
            fail "Samba 未运行"; PASS=0
        fi
    else
        warn "无 Samba 服务单元, 跳过"
    fi
    if [ -f "${RESOLVED_CONF}.airport-bak" ]; then
        if cmp -s "${RESOLVED_CONF}.airport-bak" "$RESOLVED_CONF"; then
            ok "resolved.conf 已与备份一致"
        else
            fail "resolved.conf 与备份不一致"; PASS=0
        fi
    elif ! grep -qE '^[[:space:]]*LLMNR=no' "$RESOLVED_CONF"; then
        ok "resolved.conf 无 LLMNR=no 残留"
    else
        fail "resolved.conf 仍含 LLMNR=no"; PASS=0
    fi
    if [ "$PASS" -eq 1 ]; then
        ok "全部恢复完成"
        exit 0
    else
        fail "存在未通过项, 请检查上方输出"
        exit 1
    fi
}

restore_ssh
cleanup_rich_rule
restore_smb
restore_llmnr
verify
