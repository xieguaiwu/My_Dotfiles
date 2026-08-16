#!/usr/bin/env bash
# ============================================================
# sparrow-backup-test.sh — Sparrow 钱包备份完整性测试（只读安全版 v1.0）
#
# 功能：
#   0) 自动定位真实钱包文件（config recentWalletFiles → wallets/ 扫描兜底）
#   1) 钱包文件存在性 + 明文种子启发式检查（只输出布尔结论）
#   2) 本地 sha256
#   3) rbw 备份条目存在性检查（仅名称级，绝不读内容）
#   4) bw 附件一致性检查（仅当 bw 已解锁；附件下载到临时目录比对后自动清理）
#   5) 打印 GUI 恢复演练指引 + 验收标准
#
# 安全设计：
#   - 对用户文件只读；临时文件仅放 mktemp 目录，trap 退出自动清理
#   - 绝不输出钱包文件内容 / 助记词 / 密码 / xpub / 指纹值
#   - 无任何删除、移动、改名操作；幂等；失败时退出码非零
#   - 所有可能失败的命令均带守卫，脚本不会因单个环节中断而误伤
# ============================================================
set -euo pipefail

SPARROW_HOME="${SPARROW_HOME:-$HOME/.sparrow}"
CONFIG_FILE="$SPARROW_HOME/config"
WALLETS_DIR="$SPARROW_HOME/wallets"
TMPDIR_SAFE="$(mktemp -d "/tmp/sparrow-backup-test.XXXXXX" 2>/dev/null || true)"
if [ -z "$TMPDIR_SAFE" ] || [ ! -d "$TMPDIR_SAFE" ]; then
  echo "FATAL: 无法创建临时目录（/tmp 不可写？）" >&2
  exit 1
fi
trap 'rm -rf "$TMPDIR_SAFE"' EXIT

PASS=0; FAIL=0; WARN=0
ok()   { echo "  [OK] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "=== Sparrow 钱包备份完整性测试 ==="
echo "时间: $(date '+%F %T')"

# ---------- 0. 定位钱包文件 ----------
echo ""
echo "[0] 定位钱包文件"
WALLET=""
if [ -f "$CONFIG_FILE" ]; then
  # F1 修复：路径经 sys.argv 传入，杜绝字符串注入
  WALLET="$(python3 -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1], encoding='utf-8'))
    rwf = cfg.get("recentWalletFiles")
    if isinstance(rwf, list) and rwf:
        print(rwf[0])
except Exception:
    pass
' "$CONFIG_FILE" 2>/dev/null || true)"
fi
if [ -z "$WALLET" ] || [ ! -f "$WALLET" ]; then
  WALLET="$(ls -t -- "$WALLETS_DIR"/*.mv.db "$WALLETS_DIR"/*.json 2>/dev/null | head -1 || true)"
fi
if [ -z "$WALLET" ] || [ ! -f "$WALLET" ]; then
  bad "未找到钱包文件（已检查 $WALLETS_DIR 与 $CONFIG_FILE）"
  echo "   -> 请确认 Sparrow 钱包已保存；如使用自定义目录，请设置 SPARROW_HOME 后重跑"
  exit 1
fi
echo "  钱包文件: $WALLET ($(stat -c%s "$WALLET") 字节, 修改于 $(stat -c%y "$WALLET" | cut -d. -f1))"
ok "钱包文件定位成功"

# ---------- 1. 明文种子启发式检查（布尔，不出内容） ----------
echo ""
echo "[1] 明文种子特征检查（启发式布尔判断，不输出任何匹配内容）"
# S2 说明：H2 MVStore 分块压缩存储，strings 只能做启发式检测，存在假阴性；
# 加密状态的最终确认 = 打开钱包需要输入密码
PLAIN="$(strings "$WALLET" 2>/dev/null | grep -cE '"(seed|seedType|mnemonic)"' || true)"
if [ "$PLAIN" -gt 0 ]; then
  bad "检测到明文种子特征（$PLAIN 处）——钱包文件可能未加密！请立即在 Sparrow 中设置文件密码"
else
  ok "未检测到明文种子特征"
  warn "注意：H2 数据库可能压缩存储，此为启发式判断；最终确认方式=打开钱包需要输密码"
fi

# ---------- 2. 本地 sha256 ----------
echo ""
echo "[2] 本地钱包文件 sha256"
LOCAL_HASH="$(sha256sum "$WALLET" | awk '{print $1}')"
echo "  sha256: ${LOCAL_HASH:0:32}... (完整值见报告末尾)"
printf '%s  %s\n' "$LOCAL_HASH" "$(basename "$WALLET")" > "$TMPDIR_SAFE/local.sha256"
ok "本地哈希计算完成"

# ---------- 3. rbw 备份条目检查（仅名称级） ----------
echo ""
echo "[3] rbw 备份条目存在性检查（只查名称，绝不读取内容）"
# L2 修复：不再硬编码命名约定；未显式指定时自动探测 wallet/ 前缀
if [ -n "${RBW_PREFIX:-}" ]; then
  :
else
  RBW_PREFIX="$(rbw list 2>/dev/null | grep -oE '^wallet/[^/]+' | sort -u | head -1 || true)"
fi
if command -v rbw >/dev/null 2>&1; then
  if rbw unlocked >/dev/null 2>&1; then
    if [ -n "$RBW_PREFIX" ]; then
      RBW_LIST="$(rbw list 2>/dev/null || true)"
      for item in "$RBW_PREFIX" "$RBW_PREFIX-fingerprint" "$RBW_PREFIX-pwd" "$RBW_PREFIX-xpub"; do
        if printf '%s\n' "$RBW_LIST" | grep -qxF -e "$item"; then
          ok "rbw 条目存在: $item"
        else
          warn "rbw 条目缺失: $item (若命名不同可忽略；用 rbw list 查看实际名称)"
        fi
      done
    else
      warn "无法自动探测 RBW_PREFIX（rbw list 为空或无 wallet/ 前缀），请设置 RBW_PREFIX 环境变量后重跑"
    fi
  else
    warn "rbw 未解锁——请先运行 rbw unlock，再重跑本脚本"
  fi
else
  warn "未安装 rbw"
fi

# ---------- 4. bw 附件一致性检查（仅当已解锁） ----------
echo ""
echo "[4] bw 附件一致性检查"
if command -v bw >/dev/null 2>&1; then
  # H1 修复：bw status --quiet 会抑制全部 stdout 导致永远判为 locked；改用完整输出解析
  BW_STATUS="$(bw status 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("status","locked"))' 2>/dev/null || echo locked)"
  if [ "$BW_STATUS" = "unlocked" ]; then
    FN="$(basename "$WALLET")"
    # F2 修复：文件名经 sys.argv 传入，杜绝字符串注入
    ITEM_ID="$(bw list items --search "Sparrow Wallet" 2>/dev/null | python3 -c '
import json, sys
try:
    target = sys.argv[1]
    items = json.load(sys.stdin)
    for it in items:
        for a in (it.get("attachments") or []):
            if a.get("fileName") == target:
                print(it["id"])
                sys.exit(0)   # N1 修复：找到第一个匹配即退出，避免多匹配时 ITEM_ID 多行污染
except Exception:
    pass
' "$FN" 2>/dev/null || true)"
    if [ -n "$ITEM_ID" ]; then
      if bw get attachment "$FN" --itemid "$ITEM_ID" --output "$TMPDIR_SAFE/dl" >/dev/null 2>&1; then
        chmod 600 "$TMPDIR_SAFE/dl" 2>/dev/null || true   # L1 修复：收紧临时文件权限
        REMOTE_HASH="$(sha256sum "$TMPDIR_SAFE/dl" | awk '{print $1}')"
        if [ "$REMOTE_HASH" = "$LOCAL_HASH" ]; then
          ok "bw 附件与本地文件哈希一致"
        else
          bad "bw 附件与本地哈希不一致（本地 ${LOCAL_HASH:0:16}... vs 远端 ${REMOTE_HASH:0:16}...）——备份已过期，请重新上传"
        fi
      else
        bad "bw 附件取回失败——请在 Bitwarden 中确认附件存在且完整"
      fi
    else
      warn "Bitwarden 附件中未找到 $FN（若尚未上传附件，先完成上传；若已用其他文件名，忽略本警告）"
    fi
  else
    warn "bw 未解锁（status=$BW_STATUS）——跳过附件检查；需要时: export BW_SESSION=\$(bw unlock --raw) 后重跑"
  fi
else
  warn "未安装 bw CLI"
fi

# ---------- 5. GUI 恢复演练指引 ----------
echo ""
echo "[5] GUI 恢复演练指引（需人工完成的验收步骤）"
cat <<'GUIDE'
  ① 启动独立沙箱（不污染真实钱包）:
       ~/.local/opt/Sparrow/bin/Sparrow -d /tmp/recovery-test
  ② 输入前确认环境安全：无录屏/键盘记录、无旁人窥视、建议断网
     File -> New Wallet -> New or Imported Software Wallet
     -> 输入 rbw 中保存的 24 词 + passphrase -> 导入
  ③ 验收 A: Master fingerprint 与 rbw 条目 wallet/new1-fingerprint 记录一致
  ④ 验收 B: 第一个收款地址 == 真实钱包 Receive 页第一个地址
  ⑤ 文件恢复: 将 <钱包>.mv.db 拷入 /tmp/recovery-test/wallets/ 打开，输入密码，同样验收
  ⑥ 清理: rm -rf /tmp/recovery-test
GUIDE
ok "恢复演练指引已输出"

# ---------- 6. 汇总报告 ----------
echo ""
echo "=================================================="
echo "测试结果: 通过=$PASS 失败=$FAIL 警告=$WARN"
echo "钱包文件: $WALLET"
echo "本地 sha256: $LOCAL_HASH"
echo "=================================================="
[ "$FAIL" -eq 0 ]
