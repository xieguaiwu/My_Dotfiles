#!/bin/bash
# freeze-oom-protect.sh — 死机防护一键加固（earlyoom + oomd + 用户 session 内存压力监控）
# 用法:
#   sudo bash freeze-oom-protect.sh          # 执行加固
#   sudo bash freeze-oom-protect.sh --dry    # 预览（只打印，不写入任何文件）
#   sudo bash freeze-oom-protect.sh --undo   # 撤销 oomd 用户 session 加固（earlyoom 保留）
# 版本: 1.1.0（2026-08-10 批判性审查后修订）
set -euo pipefail

log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
run()  {
  if [ "$DRY" = "1" ]; then echo "    (dry) $*"; return 0; fi
  "$@"
}

# --- 参数解析：支持 --dry 与 --undo 任意组合 ---
ACTION="apply"; DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry)  DRY=1 ;;
    --undo) ACTION="undo" ;;
    -h|--help) grep '^#' "$0" | grep -v '^#!' | sed 's/^# \?//'; exit 0 ;;
    *) warn "未知参数: $arg（支持 --dry / --undo / -h）"; exit 2 ;;
  esac
done


# --- 权限检查：真实执行需要 root；--dry 只读预览无需 root ---
if [ "$(id -u)" != "0" ] && [ "$DRY" != "1" ]; then
  warn "需要 root 权限（sudo bash $0）"; exit 1
fi

# --- 目标 uid：定位真实登录用户，避免验证 user@0.service ---
# 优先级：sudo 环境变量 > loginctl 探测首个非 root 登录用户 > 极端兜底 1000
TARGET_UID="${SUDO_UID:-}"
if [ -z "$TARGET_UID" ] || [ "$TARGET_UID" = "0" ]; then
  TARGET_UID=$(loginctl list-users --no-legend 2>/dev/null | awk '$1 != 0 {print $1; exit}')
fi
[ -z "$TARGET_UID" ] && TARGET_UID=1000
OOMD_CONF="/etc/systemd/system/user@.service.d/oomd-protect.conf"

# ============ --undo：移除加固，恢复原状 ============
if [ "$ACTION" = "undo" ]; then
  log "撤销 systemd-oomd 用户 session 加固..."
  if [ "$DRY" = "1" ]; then
    echo "    (dry) rm -f $OOMD_CONF"
    echo "    (dry) systemctl daemon-reload"
  else
    if [ -f "$OOMD_CONF" ]; then
      rm -f "$OOMD_CONF"
      log "已删除 $OOMD_CONF"
    else
      warn "配置文件不存在，无需撤销"
    fi
    systemctl daemon-reload
  fi
  log "完成。earlyoom 保留运行（可用 sudo systemctl disable --now earlyoom 移除）"
  exit 0
fi

# ============ 1/3 earlyoom（第一道防线） ============
log "=== 1/3 earlyoom 安装（内存<10% 时杀最大进程，防止整机冻死） ==="
if command -v earlyoom >/dev/null 2>&1; then
  log "earlyoom 已安装，跳过"
else
  run dnf install -y earlyoom || { warn "dnf 安装 earlyoom 失败（检查网络/仓库）"; exit 1; }
fi
run systemctl enable --now earlyoom 2>/dev/null || warn "earlyoom 启动失败，查看 journalctl -u earlyoom"

# ============ 2/3 systemd-oomd 加固（第二道防线） ============
log "=== 2/3 systemd-oomd 用户 session 内存压力监控 ==="
# 配置值说明（针对 15.5GiB 内存 + 8G zram 的机器）：
#   MemoryHigh=10G  → 超过后开始回收压力（软限制）
#   MemoryMax=12G   → 硬上限，超出即 cgroup OOM 杀该 session 内进程
#   ⚠️ 必须给内核 + zram 压缩池留足余量（zram 高压时自身占 2-4G 内存），
#      否则 user session 占满会导致系统级 OOM——正是要避免的死机。
NEW_CONF='[Service]
MemoryHigh=10G
MemoryMax=12G
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=80%
'

if [ "$DRY" = "1" ]; then
  echo "    (dry) 写入 $OOMD_CONF:"
  echo "$NEW_CONF" | sed 's/^/    (dry)         /'
  echo "    (dry) systemctl daemon-reload"
else
  mkdir -p "$(dirname "$OOMD_CONF")"
  if [ -f "$OOMD_CONF" ]; then
    if diff -q <(printf '%s' "$NEW_CONF") "$OOMD_CONF" >/dev/null 2>&1; then
      log "配置已存在且一致，跳过写入（幂等）"
    else
      cp -a "$OOMD_CONF" "${OOMD_CONF}.bak.$(date +%Y%m%d%H%M%S)"
      warn "检测到已有配置，已备份到 ${OOMD_CONF}.bak.* 后覆盖"
      printf '%s' "$NEW_CONF" > "$OOMD_CONF"
    fi
  else
    printf '%s' "$NEW_CONF" > "$OOMD_CONF"
  fi
  chmod 644 "$OOMD_CONF"
  systemctl daemon-reload
  log "已写入 $OOMD_CONF（MemoryHigh=10G / MemoryMax=12G / ManagedOOMMemoryPressure=kill）"
  warn "当前已登录 session 的新限制在下次重新登录后生效（或重启后）"
fi

# ============ 3/3 验证 ============
log "=== 3/3 验证 ==="
if [ "$DRY" = "1" ]; then
  echo "    (dry) systemctl is-active earlyoom"
  echo "    (dry) systemctl is-active systemd-oomd"
  echo "    (dry) systemctl show user@${TARGET_UID}.service --property=MemoryHigh,MemoryMax,ManagedOOMMemoryPressure"
  echo "    (dry) cat /etc/systemd/oomd.conf.d/50-user-protection.conf"
else
  systemctl is-active earlyoom >/dev/null 2>&1 && log "earlyoom: active" || warn "earlyoom: 未运行"
  systemctl is-active systemd-oomd >/dev/null 2>&1 && log "systemd-oomd: active" || warn "systemd-oomd: 未运行"
  echo "--- oomd 全局配置 ---"
  cat /etc/systemd/oomd.conf.d/50-user-protection.conf 2>/dev/null || warn "（无全局 oomd 配置）"
  echo "--- 用户 session 生效状态（user@${TARGET_UID}.service）---"
  systemctl show "user@${TARGET_UID}.service" --property=MemoryHigh,MemoryMax,ManagedOOMMemoryPressure 2>/dev/null || \
    warn "目标 session 未运行或未加载新配置（重新登录后生效）"
fi

log "=== 完成 ==="
log "手动验证: journalctl -u earlyoom -f   （内存高压时应有 kill 记录）"
log "撤销: sudo bash $0 --undo"
log "建议定期: bash ~/prompt_boilerplates/System_Fix/system_fix.fish --dry"
