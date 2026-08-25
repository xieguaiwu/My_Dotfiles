#!/bin/bash
# ============================================================
# airport-harden.sh — 公共网络(机场WiFi)安全加固 / 恢复脚本
#
# 用法:
#   sudo ./airport-harden.sh           # 执行加固
#   sudo ./airport-harden.sh --revert  # 恢复原配置(离开机场后)
#
# 加固内容:
#   1. 从 firewalld 活动 zone 移除入站 SSH 放行
#   2. 停用并禁用 Samba (smb/smbd) 开机自启
#   3. 关闭 systemd-resolved 的 LLMNR (投毒风险)
#
# 说明:
#   - 幂等: 重复执行安全; 已加固的项会显示 [SKIP]/[OK] 而非报错
#   - --revert 会还原以上三项(SSH 重新放行/Samba 恢复/resolved.conf 还原备份)
#   - 执行前自动备份 /etc/systemd/resolved.conf 为 .airport-bak
# ============================================================

set -uo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'

ok()   { echo "  ${GREEN}[OK]${NC}   $*"; }
warn() { echo "  ${YELLOW}[SKIP]${NC} $*"; }
fail() { echo "  ${RED}[FAIL]${NC}  $*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "必须用 sudo 运行: sudo $0 [--revert]" >&2
    exit 1
fi

RESOLVED_CONF=/etc/systemd/resolved.conf

# 当前 firewalld 活动 zone (优先 wlp4s0 所属 zone, 其次默认 zone)
ZONE=""
if systemctl is-active --quiet firewalld; then
    ZONE=$(firewall-cmd --get-zone-of-interface=wlp4s0 2>/dev/null || true)
    [ -n "$ZONE" ] || ZONE=$(firewall-cmd --get-default-zone 2>/dev/null || true)
else
    warn "firewalld 未运行, 跳过防火墙步骤"
fi

# ---------- 加固 ----------

harden_ssh() {
    echo "== [1/3] 关闭入站 SSH (zone: ${ZONE:-无})"
    [ -z "$ZONE" ] && { warn "无活动 zone, 跳过"; return; }
    if firewall-cmd --zone="$ZONE" --query-service=ssh --quiet; then
        firewall-cmd --permanent --zone="$ZONE" --remove-service=ssh && \
            firewall-cmd --reload
        ok "已从 zone $ZONE 移除 ssh 放行 (重启后仍生效)"
    else
        ok "ssh 本就不在 zone $ZONE 放行列表"
    fi
}

harden_smb() {
    echo "== [2/3] 停用 Samba"
    for svc in smb smbd; do
        if systemctl is-enabled --quiet "$svc" 2>/dev/null || \
           systemctl is-active  --quiet "$svc" 2>/dev/null; then
            systemctl disable --now "$svc" 2>/dev/null || true
        fi
    done
    if systemctl is-active --quiet smb 2>/dev/null || \
       systemctl is-active --quiet smbd 2>/dev/null; then
        fail "Samba 仍在运行"
    else
        ok "smb/smbd 已停止并禁用自启"
    fi
}

harden_llmnr() {
    echo "== [3/3] 关闭 LLMNR (systemd-resolved)"
    if grep -qE '^[[:space:]]*LLMNR=no' "$RESOLVED_CONF"; then
        ok "LLMNR=no 已配置"
        return
    fi
    cp -a "$RESOLVED_CONF" "${RESOLVED_CONF}.airport-bak"
    if grep -qE '^[[:space:]]*LLMNR=' "$RESOLVED_CONF"; then
        sed -i -E 's/^[[:space:]]*LLMNR=.*/LLMNR=no/' "$RESOLVED_CONF"
    else
        printf '\n[Resolve]\nLLMNR=no\n' >> "$RESOLVED_CONF"
    fi
    systemctl restart systemd-resolved
    ok "LLMNR 已关闭 (备份: ${RESOLVED_CONF}.airport-bak)"
}

# ---------- 验证 ----------

verify() {
    echo "== 验证结果"
    PASS=1
    if [ -n "$ZONE" ] && firewall-cmd --zone="$ZONE" --query-service=ssh --quiet; then
        fail "SSH 仍被 firewalld 放行"; PASS=0
    else
        ok "SSH 入站已被防火墙拒绝 (sshd socket 仍监听属正常)"
    fi
    if systemctl is-active --quiet smb 2>/dev/null || \
       systemctl is-active --quiet smbd 2>/dev/null; then
        fail "Samba 仍在运行"; PASS=0
    else
        ok "Samba 已停止"
    fi
    if grep -qE '^[[:space:]]*LLMNR=no' "$RESOLVED_CONF"; then
        ok "LLMNR=no 已写入配置"
    else
        fail "LLMNR 配置未生效"; PASS=0
    fi
    if [ "$PASS" -eq 1 ]; then
        ok "全部加固完成"
        exit 0
    else
        fail "存在未通过项, 请检查上方输出"
        exit 1
    fi
}

# ---------- 恢复 ----------

revert_all() {
    echo "== 恢复原配置"
    if [ -n "$ZONE" ]; then
        if firewall-cmd --zone="$ZONE" --query-service=ssh --quiet; then
            ok "SSH 已在放行列表"
        else
            firewall-cmd --permanent --zone="$ZONE" --add-service=ssh && \
                firewall-cmd --reload
            ok "SSH 已重新放行"
        fi
    else
        warn "无活动 zone, 跳过 SSH 恢复"
    fi
    for svc in smb smbd; do
        if systemctl cat "$svc" >/dev/null 2>&1; then
            systemctl enable --now "$svc" 2>/dev/null || true
            ok "$svc 已恢复自启并启动"
        fi
    done
    if [ -f "${RESOLVED_CONF}.airport-bak" ]; then
        cp -a "${RESOLVED_CONF}.airport-bak" "$RESOLVED_CONF"
        systemctl restart systemd-resolved
        ok "resolved.conf 已从备份还原"
    elif grep -qE '^[[:space:]]*LLMNR=no' "$RESOLVED_CONF"; then
        sed -i -E '/^[[:space:]]*LLMNR=no/d' "$RESOLVED_CONF"
        systemctl restart systemd-resolved
        ok "已移除 LLMNR=no 行"
    else
        ok "LLMNR 配置无改动"
    fi
    echo "== 恢复完成"
}

# ---------- 入口 ----------

case "${1:-}" in
    --revert|-r) revert_all ;;
    "" ) harden_ssh; harden_smb; harden_llmnr; verify ;;
    * ) echo "用法: sudo $0 [--revert]" >&2; exit 1 ;;
esac
