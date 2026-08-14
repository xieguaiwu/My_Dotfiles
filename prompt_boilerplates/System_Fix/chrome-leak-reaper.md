---
name: chrome-leak-reaper
version: 1.1.0
description: Chrome/chromium 内存泄漏排查与 chrome-reaper 看门狗维护——覆盖 chromedp 下载实例、opencli 桥实例、flatpak scope 拆树（zygote 误杀）、restart 残留、共享 profile 锁冲突、用户手动 kill vs systemd restart 拉锯战。基于 2026-08-02 三层根治 + 2026-08-10 v3 PPID 链修复 + 2026-08-11 手动杀循环实战
triggers:
  - "chrome 内存泄漏"
  - "chrome 内存泄露"
  - "chrome 吃内存"
  - "内存被吃光"
  - "chrome 进程多"
  - "headless chrome"
  - "chromedp"
  - "zlibrary-bridge"
  - "opencli 桥"
  - "DidStartWorkerFail"
  - "chrome 反复重启"
  - "reaper"
  - "chromium 泄漏"
tools:
  - read
  - bash
  - ps
  - journalctl
  - systemctl
  - pgrep
  - kill
  - free
---

# Chrome 内存泄漏排查与 chrome-reaper 维护 Skill

## 任务目标

本机 chrome 泄漏是**反复发作**的系统性问题（2026-07-31 ENOSPC → 2026-08-02 chromedp 泄漏 → 2026-08-10 zygote 误杀），已三度爆内存（160→797 进程、RAM+swap 全满、OOM/死机）。本 skill 用于：

1. 快速判断 chrome 泄漏是否在发生、属于哪种泄漏源
2. 定位泄漏根因（不是 chrome 本体，而是**谁在反复拉起/误杀**）
3. 正确维护 chrome-reaper 看门狗（本机唯一防线：systemd 管不到 flatpak 移出 cgroup 的 chrome）

## 核心认知（来自实战）

| 事实 | 说明 |
|------|------|
| **flatpak 把 chrome 移出调用方 cgroup** | flatpak run 的 chrome 进入独立 `app-flatpak-org.chromium.Chromium-XXX.scope` → systemd 的 KillMode/MemoryMax/TasksMax **全部失效** → 只能靠 reaper 按 PID/scope 特征回收 |
| **chromium 150 + flatpak 把 zygote/renderer 拆到独立 scope** | 主树（bwrap→bwrap→chrome 主→zygote）与 zygote 树（bwrap→zygote→renderer×N）**scope 不同但 PPID 链相连**（zygote bwrap 的父 = 主树内层 bwrap）。一次启动 = 两个 scope 是**正常现象**，不是双实例！ |
| **判断"孤儿 scope"必须走 PPID 链** | scope 内有无主进程不够——zygote 树全是 `--type=*` 子进程（无主进程特征），但它是 bridge 的合法子树。孤儿判定 = scope 内无主进程 **且** PPID 链断（追溯不到任何受管实例） |
| **看门狗误杀比不杀更危险** | 杀 bridge 附属树 → 带伤运行（worker 失败循环）→ CPU 100% + 内存缓涨 → 崩溃 → 重启 → 再误杀 → **恶性循环，表现为"反复出现的内存泄漏"** |
| **DidStartWorkerFail 错误码 3** | opencli-extension service worker 启动失败。根因：zygote 缺失（渲染能力没了）或共享 profile 锁冲突（多实例并存）→ 扩展 storage 读不了。**不是扩展本体坏了**（干净 profile 实测 `[opencli] OpenCLI extension initialized` 正常） |
| **bridge 死亡周期 3-6 分钟 = zygote 被杀特征** | 正常代际应 >30 分钟。每 ~6 分钟 137 死一次 + 每 3 分钟 reaper 杀一个 scope = 误杀循环的铁证 |
| **restart 杀不干净** | KillMode=control-group 对 flatpak 移出 cgroup 的 chrome 失效 → `systemctl restart` 后旧树残留 → 与共享 profile(~/.config/chromium) 锁冲突 → 更多 worker 失败。需 ExecStopPost 或 reaper 兜底清理 |
| **status=137 的四种可能** | ① TimeoutStopSec 超时 SIGKILL（Type=simple 主进程挂死时 `systemctl stop` 会触发）② cgroup OOM ③ zygote 被杀后主 chrome 崩溃 ④ **外部手动 SIGKILL**（用户/脚本 `kill -9`/`pkill`，2026-08-11 实测）。**137 + 无 Stopping 日志 = 意外死亡（failure）→ 触发 Restart=on-failure 循环**；先问用户是否手动杀过，再怀疑 reaper/泄漏 |
| **用户手动杀 vs systemd 拉锯战** | 用户 `pkill -9 -f chrom`（或 kill bwrap）→ systemd 10s 后（RestartSec）拉起新 chrome → 用户看到"不断冒出的 chrome"再杀 → 循环。**特征：journal 全是 137/9 且间隔 ≈ RestartSec 倍数、无 reaper KILLED、无 DidStartWorkerFail、用户确认动过手**。正确止血：先 `systemctl --user stop zlibrary-bridge` 再清理，绝不能边杀边让 systemd 拉起 |

## 本机架构（防线的正确形态）

> **⚠️ 2026-08-11 状态变更：zlibrary-bridge 已永久禁用**（用户决策：机器性能差，bridge 常驻 1.1GB RSS 是累赘）。
> service 文件已改名 `~/.config/systemd/user/zlibrary-bridge.service.bak-disabled`，unit 不存在 → 任何 `systemctl --user start` 都会失败，bookfetch 的 zlibrary 功能随之不可用。
> **恢复**：`mv` 回原名 → `systemctl --user daemon-reload` → `systemctl --user enable --now zlibrary-bridge`。
> **reaper 行为变化**：无 bridge → 没有 protected 树 → 所有 `--headless` + `~/.config/chromium` 实例一律按非受管清理（这是预期行为，不是误杀）。

```
泄漏源                                 防线
─────────────────────────────────────────────
chromedp（bookdl 下载，/tmp/chromedp-  → reaper 必杀整树（bookdl 运行时跳过）
runner* 特征）                           + bookdl wrapper systemd-run（KillMode + MemoryMax）
opencli 桥（systemd zlibrary-bridge）   → 【已永久禁用 2026-08-11】
GUI 浏览器（用户在用）                   → reaper 永不碰（无 --headless）
```

**chrome-reaper（v3，`~/.local/bin/chrome-reaper`）判定顺序**：
1. **bridge 附属 scope（PPID 链 ∈ BRIDGE_TREE）→ 保护**（v3 核心修复，含 zygote 树）
2. chromedp 特征（`/tmp/chromedp-runner`）→ 必杀（bookdl 运行时跳过）
3. 桥特征实例（`--headless` + `~/.config/chromium`）非受管 → 全杀（systemd 是唯一桥管理者，残留即异常）
4. 无主实例（全 `--type=*` 且 PPID 链断）→ 真孤儿 → 整树杀
5. GUI（无 --headless）→ 永不碰

由 systemd user timer 每 3 分钟调用；bridge service 的 `ExecStopPost` 调 `chrome-reaper after-stop`（stop/restart 后立即清残留）。

## 执行流程

### Phase 1: 并行采集（一次性发出）

```bash
# 1. chrome 进程画像（进程数 + 总 RSS + 实例特征）
ps aux | grep -iE "chrom(e|ium)" | grep -v grep | wc -l
ps aux | grep -iE "chrom(e|ium)" | grep -v grep | awk '{sum+=$6} END {printf "RSS 总计: %.1f GB\n", sum/1024/1024}'
ps aux | grep -iE "chrom(e|ium)" | grep -v grep | grep -oE "user-data-dir=[^ ]+" | sort | uniq -c

# 2. flatpak scope 列表（看有几个"实例"；bridge 正常 = 2 个 scope：主树+zygote 树）
systemctl --user list-units 'app-flatpak-org.chromium.Chromium-*' --all --no-pager | grep Chromium

# 3. reaper 日志（KILLED/protected/WARN low memory 定位时间点）
tail -50 ~/.local/state/chrome-reaper.log

# 4. bridge 服务状态（MainPID、重启次数、上次死因）
systemctl --user show zlibrary-bridge -p MainPID,NRestarts,ActiveState --value
journalctl --user -u zlibrary-bridge --since "1小时前" --no-pager | grep -E "status=|Scheduled restart|Stopping" | tail

# 5. 扩展 worker 失败循环（DidStartWorkerFail = zygote 缺失/锁冲突信号）
journalctl --user --since "1小时前" --no-pager | grep -c "DidStartWorkerFail"

# 6. 内存总览
free -h
```

### Phase 2: 判断泄漏模式

| 现象 | 结论 |
|------|------|
| `/tmp/chromedp-runner*` 目录 + chromedp 特征进程聚集 | chromedp 泄漏（bookdl 下载残留）→ reaper 必杀应已兜底；检查 bookdl wrapper 是否失效 |
| **reaper 日志每 3 分钟 KILLED 一个 8 进程 scope + bridge 每 6 分钟 137 死** | **zygote 误杀循环**（v2 老逻辑特征）→ 升级/检查 v3 PPID 链保护 |
| bridge 活着但 `DidStartWorkerFail` 每 24 秒一次 + CPU 高 | 多实例共享 profile 锁冲突 或 zygote 已被杀 → 查 scope 数量 + 残留树 |
| 多个 `--headless` + `~/.config/chromium` 实例并存 | restart 残留（KillMode 失效）→ ExecStopPost/手动清 |
| **journal 间隔 ≈ RestartSec(10s) 的连环 137/9 + 用户/外部可能动过手** | 手动杀 vs restart 拉锯战 → **先 `systemctl --user stop zlibrary-bridge` 止血**，问用户是否杀过，确认后再 start（start 前先跑一次 `chrome-reaper` 清残留） |
| reaper 日志 `WARN low memory: <2GB` | 内存告急时间点 → 反查该时刻泄漏源（配合 journal） |

### Phase 3: 定位根因（误杀循环的确认方法）

```bash
# 1. 确认 bridge 的 zygote 树是否被误杀（journal 时间线交叉验证）
journalctl --user --since "1小时前" --no-pager | grep -E "KILLED|Started app-flatpak|status=137" | head -20
# 模式：KILLED(zygote scope) → DidStartWorkerFail 循环 → status=137 → Scheduled restart → 重复

# 2. 当前 bridge 的树结构（确认 PPID 链：zygote bwrap 的父 = 主树内层 bwrap）
pstree -p $(systemctl --user show zlibrary-bridge -p MainPID --value) | head -20
# 或逐行看（含 bwrap 包装层）:
ps -eo pid,ppid,args | grep -E "/app/chromium/chrome|/usr/bin/bwrap" | grep -v grep | cut -c1-160

# 3. 扩展本体健康验证（干净 profile 实验——排除扩展/浏览器版本问题）
rm -rf /tmp/test-chrome-profile
timeout 30 flatpak run --command=chromium \
  --filesystem=/tmp/test-chrome-profile:rw --filesystem=$HOME/opencli-extension:ro \
  org.chromium.Chromium --user-data-dir=/tmp/test-chrome-profile --headless=new \
  --load-extension=$HOME/opencli-extension --disable-features=DisableLoadExtensionCommandLineSwitch \
  --enable-logging=stderr "chrome://newtab" 2>&1 | grep -iE "worker|extension|initialized"
# 出现 "[opencli] OpenCLI extension initialized" = 扩展正常，问题在 profile/进程管理
rm -rf /tmp/test-chrome-profile
```

### Phase 4: 修复（按优先级）

#### 4.1 升级/检查 reaper 保护逻辑（v3 必须项）

```bash
# v3 已在 ~/.local/bin/chrome-reaper（v2 备份 .v2.bak）。检查当前版本关键逻辑：
grep -n "scope_is_bridge\|BRIDGE_TREE" ~/.local/bin/chrome-reaper | head
# 手动运行验证（不重启任何东西）：
~/.local/bin/chrome-reaper && tail -5 ~/.local/state/chrome-reaper.log
# 期望输出：bridge scope=...（protected, tree）×2（主树+zygote 树），无 KILLED
```

#### 4.2 清理现场（残留树 + 孤儿）

```bash
# reaper 会自动清理残留；等一个周期或手动跑一次。
# 若 reaper 停着：手动杀残留树（按 scope 整树，⚠️ 见注意事项 1）
# 误杀 flatpak-portal 后需手动拉起（static service 无 Restart）：
systemctl --user start flatpak-portal
```

#### 4.3 bridge service 防 restart 残留

```bash
# zlibrary-bridge.service 应含（2026-08-10 已加）：
#   ExecStopPost=/home/xieguiawu/.local/bin/chrome-reaper after-stop
# 修改后：
systemctl --user daemon-reload
```

#### 4.4 确认 timer 在跑

```bash
systemctl --user list-timers chrome-reaper.timer --no-pager | head -3
# 停了就恢复：
systemctl --user start chrome-reaper.timer
```

### Phase 5: 验证（关键指标）

```bash
# 1. bridge 存活时长（修复后应 >30 分钟，之前误杀期 3-6 分钟就死）
ps -o etime= -p $(systemctl --user show zlibrary-bridge -p MainPID --value)

# 2. worker 失败停止（修复前每 24 秒一次）
journalctl --user --since "修复时间点" --no-pager | grep -c "DidStartWorkerFail"   # 应为 0（或仅修复前的残留）

# 3. CPU 正常（修复前 42-91%，正常 <5%）：bridge 树总 CPU
ps aux | grep -iE "chrom(e|ium)" | grep -v grep | awk '{s+=$3} END {printf "chrome 总 CPU: %.1f%%\n", s}'

# 4. reaper 每 3 分钟巡检无误杀（连续 2-3 个周期无 KILLED）
tail -10 ~/.local/state/chrome-reaper.log

# 5. 内存恢复（可用应 >10GB）
free -h | head -2
```

## 预防

1. **reaper 是最后防线，不是第一防线**：根本防线是"谁在拉起 chrome"（bookdl wrapper systemd-run、bridge service、禁用无关调用方）。reaper 只负责兜底清理，不负责修复拉起逻辑。
2. **bridge 死亡周期是健康指标**：`journalctl --user -u zlibrary-bridge` 里 `Scheduled restart` 间隔 >30 分钟 = 健康；3-6 分钟 = zygote 误杀或更深层问题，立即查 reaper 日志。
3. **大改动后跑一轮干净重启实验**：`systemctl --user restart zlibrary-bridge` + 高频记录新进程 ppid（1 秒间隔 30 轮），确认只有主树+zygote 树两个 scope。
4. **定期检查孤儿**：`ps -ef | awk '$3==1' | grep -c chrome`（bwrap/chrome 聚集 = 泄漏）。
5. **不要手动 kill flatpak-portal**：它是 static service 无 Restart，杀了要手动拉起；且它下面的 bwrap 进程可能是桥的合法组成部分（zygote 包装），先查 PPID 链再动手。

## 注意事项（踩过的坑）

0. **先 stop 再手动清，别和 systemd 拔河**：`systemctl --user stop zlibrary-bridge` 会触发 ExecStopPost 自动清残留；直接 `kill`/`pkill` chrome 只会让 Restart=on-failure 在 RestartSec 后拉起新实例——你杀一个它冒一个，看起来像"杀不完的泄漏"（2026-08-11 实例：用户手动杀 6 次、systemd 拉 6 次、restart counter 到 9）。
0b. **连环 137 先问用户**：看到 137/9 连环死亡且无 reaper KILLED 时，第一件事是问用户是否手动 kill 过 chrome，再排查 reaper/泄漏——误判会把人引向错误的修复方向。

1. **scope 是实例单位，但"实例"判定必须看 PPID 链**：flatpak 拆 scope 的粒度是进程树（zygote 树独立 scope），不是实例。scope 内无主进程 ≠ 孤儿——先追 PPID 链到受管实例（bridge MainPID 树），链通 = 合法附属，链断 = 孤儿。
2. **`kill -9 /proc/PID` 无效**：kill 不接受路径（静默失败）。必须用纯数字 PID。
3. **`pkill -f 'pattern'` 会自杀**：bash 命令行含 pattern → 用 `[r]` 技巧或 `pgrep | grep -v $$`。
4. **`for x in $(pgrep ...)` 按空格拆分**：含空格 cmdline 会拆碎 → 用 `while IFS= read -r` + 进程替换。
5. **timeout 杀 flatpak run 不干净**：`timeout N flatpak run ...` 杀父进程后 bwrap 变孤儿继续跑（实测残留 xdg-dbus-proxy/zygote 包装）→ 实验后手动查残留。
6. **systemctl stop 挂死服务的 137 陷阱**：Type=simple 主进程（bwrap）不响应 SIGTERM → TimeoutStopSec 超时 SIGKILL(137) → 若同时满足 on-failure 条件会意外触发 Restart 循环。用户手动 stop 前先确认服务状态。
7. **MemoryHigh/MemoryMax/TasksMax 对 bridge 形同虚设**：chrome 在 flatpak scope 里不在 bridge cgroup（Tasks: 0）→ 限制只作用于 bwrap 本体。别指望 cgroup 限流管住 chrome。
8. **profile 锁冲突的判定**：多个实例共用 `~/.config/chromium` → 后者报 `IO error: .../LOCK` + `DidStartWorkerFail`（扩展 storage 读不了）。单实例化后错误消失 = 锁冲突确认。
10. **本文档属于 System_Fix 技能集**：入口与症状决策树见 [index.md](index.md)；chrome 泄漏导致死机时配合 [freeze-oom-protection.md](freeze-oom-protection.md)；tmpfs/ENOSPC 场景配合 [enospc-tmpfs-check.md](enospc-tmpfs-check.md)。
