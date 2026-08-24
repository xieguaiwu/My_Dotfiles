---
name: freeze-oom-protection
version: 1.3.0
description: 死机/OOM thrash 冻结排查与一劳永逸防护——earlyoom 兜底 + systemd-oomd 加固 + 进程限流 + i915 PSR 显示管线风暴修复。基于三次死机实战（2026-08-10 20:09 chrome 泄漏引爆 + 2026-08-18 17:48 zram 盲区 thrash + 2026-08-24 22:17 OOM 重启）：Kaby Lake i915 + sway + zram，15GB RAM
triggers:
  - "死机"
  - "冻结"
  - "卡死"
  - "freeze"
  - "Purging GPU memory"
  - "内存不足"
  - "OOM"
  - "系统没响应"
  - "内存被吃光"
  - "Atomic commit failed"
  - "Page-flip failed"
  - "显示管线"
  - "PSR"
tools:
  - read
  - bash
  - journalctl
  - systemctl
---

# 死机/冻结排查与防护（OOM thrash）

## 核心认知

**"死机"九成是内存耗尽 thrash 冻结，不是 GPU/硬件故障。** 判定方法：

```
journalctl --list-boots                    # 找上一个 boot（无正常关机日志 = 非正常死）
journalctl -b -1 --since "20分钟前" --no-pager | tail -50
    ├─ "Purging GPU memory" ×N + 无 oom-killer  → 内存 thrash 冻结（OOM 来不及执行）
    ├─ oom-killer + Killed process           → OOM 救了系统（幸存，但很危险）
    ├─ GPU HANG / i915 reset                 → GPU 问题
    └─ 大量 "Atomic commit failed"           → 显示管线问题（常为背景噪音，非死因）
```

**铁律**：`Purging GPU memory` = i915 shrinker 被内存压力触发。看到它 = 内存告急。

**死机元凶排查**：本机死机常由 chrome 内存泄漏引爆（2026-08-10 20:09 死机 = reaper 误杀 bridge zygote 树 → worker 失败循环 → CPU 100% + 内存缓涨 → thrash 冻结）。排查内存压力源时先看 chrome：

```bash
ps aux | grep -ciE "chrom(e|ium)"                                  # 进程数（正常稳态 14 左右，泄漏期 16+ 波动）
ps aux | grep -iE "chrom(e|ium)" | grep -v grep | awk '{s+=$6} END {printf "chrome RSS: %.1f GB\n", s/1024/1024}'
tail -50 ~/.local/state/chrome-reaper.log                          # KILLED/protected/WARN low memory 定位泄漏与告急时间
journalctl --user -u zlibrary-bridge --since "2小时前" --no-pager | grep -c "Scheduled restart"   # 频繁重启 = 误杀循环
```

chrome 泄漏排查全流程见 [chrome-leak-reaper.md](chrome-leak-reaper.md)（scope/PPID 链/zygote 误杀/restart 残留）。

**earlyoom zram 盲区（2026-08-18 实锤）**：Fedora 默认参数 `-m 4 -M 409600` 的
SIGTERM 条件是**内存可用 <4% 且 swap free <10%**（双条件 AND）。zram 是压缩内存，
8G zram 掩护下 swap free 几乎不紧张 → 条件永不满足 → **earlyoom 全程哑火**——
08-18 死机时它装了但没出手。修复：`-s 100`（swap 条件恒真）退化为纯内存阈值，
配合 `-m 8`（SIGKILL 自动为 8/2=4%）。

**⚠️ -M/-S 单位坑（2026-08-24 实锤，两次死机 earlyoom 都没出手的根因）**：
earlyoom 1.8.2 的 `-M`/`-S` 参数单位是 **KiB**（不是百分比），且 **-M/-S 覆盖 -m/-s**。
08-18 写的 `-m 8 -M 5 -s 100 -S 100` 实际被解析为 **5 KiB / 100 KiB ≈ 0% 阈值**——
启动日志显示 `SIGTERM when mem avail <= 0.00%` 即哑火。08-18 到 08-24 之间
earlyoom 一直用 0% 阈值跑（ps 看 cmdline 参数正确但实际不生效）。
判定方法：`journalctl -u earlyoom -b 0 | grep SIGTERM` 必须显示 **8.00%/100.00%**；
若显示 0.00% = 配置没生效（改完必须看日志验证，不能只看 ps）。

**oomd 迟钝（2026-08-18 实测）**：默认 `ManagedOOMMemoryPressureLimit=80%` + 15s
采样在快速 thrash（几分钟内从 1GB 可用跌到 0）下来不及出手。降到 60% + 缩短
MemoryHigh 到 9G（更早进入回收压力），MemoryMax 12G 保持（zram 余量纪律）。

## Phase 1：诊断（必查项）

```bash
journalctl --list-boots | head -5
journalctl -b -1 -n 100 --no-pager | tail -80          # 死前最后日志
journalctl -b -1 --no-pager | grep -E "oom-kill|Out of memory|Killed process" | tail
journalctl -b -1 --no-pager | grep "Purging GPU memory" | head   # ⚠️ 看 pages left available 数值：
    # 08-18 死机剩 2053 页 ≈ 8MB（i915 池深度触发 = 系统内存临界枯竭）
    # 08-10 死机剩 565266 页 ≈ 2.1GB（chrome 泄漏缓涨期，i915 池未枯竭）
journalctl -b -1 --no-pager | grep -c "Atomic commit failed"     # 显示管线风暴计数（正常 0，日均 1.2-3.5 万 = PSR bug 嫌疑，见下节）
free -h && zramctl                                     # 内存与 zram 现状
systemctl status systemd-oomd --no-pager               # oomd 是否真的会响应
ps aux | grep earlyoom | grep -v grep                  # cmdline 须有 -m 8 -s 100 且无 -M/-S（有 -M/-S = 单位坑哑火）
journalctl -u earlyoom -b 0 | grep SIGTERM              # ⚠️ 必须显示 8.00%/100.00%（0.00% = 配置未生效）
```

## Phase 2：一劳永逸防护（一键脚本 `freeze-oom-protect.sh`）

三层防线，全部要装：

1. **earlyoom（第一道，最关键）**：内存可用 <10% 杀最大进程，死机前 30 秒救回系统
   ```bash
   sudo dnf install -y earlyoom
   # 2026-08-24 修正（⚠️ 勿再加 -M/-S——单位是 KiB 且覆盖 -m/-s，08-18 配置因此哑火两次死机）
   # 正确：-m 8 -s 100 = SIGTERM 8% / SIGKILL 4%，swap 100% 恒真 = 纯内存阈值
   sudo tee /etc/default/earlyoom >/dev/null <<'EOT'
   EARLYOOM_ARGS="-r 0 -m 8 -s 100 --prefer '^(Web Content|Isolated Web Co)$' --avoid '^(dnf|packagekitd|gnome-shell|gnome-session-c|gnome-session-b|lightdm|sddm|sddm-helper|gdm|gdm-wayland-ses|gdm-session-wor|gdm-x-session|Xorg|Xwayland|systemd|systemd-logind|dbus-daemon|dbus-broker|cinnamon|cinnamon-sessio|kwin_x11|kwin_wayland|plasmashell|ksmserver|plasma_session|startplasma-way|sway|i3|xfce4-session|mate-session|marco|lxqt-session|openbox|cryptsetup)$'"
   EOT
   sudo systemctl restart earlyoom
   # ⚠️ 改完必须验证：journalctl -u earlyoom -b 0 | grep SIGTERM → 显示 8.00%/100.00%
   # 参数依据（15GB 内存）：-m 8 ≈ 1.27GB 出手（08-18 12:47 avail=923MB 时正好会救）；
   # -m 10 过激（编译/大任务时误杀多），-m 8 平衡。重启失败=回滚配置，勿留无保护状态
   ```
2. **systemd-oomd 加固（第二道）**：给用户 session 开内存压力监控
   ```bash
   sudo mkdir -p /etc/systemd/system/user@.service.d
   sudo tee /etc/systemd/system/user@.service.d/oomd-protect.conf >/dev/null <<'EOT'
   [Service]
   MemoryHigh=9G
   MemoryMax=12G
   ManagedOOMMemoryPressure=kill
   ManagedOOMMemoryPressureLimit=60%
   EOT
   sudo systemctl daemon-reload
   ```
   效果：用户进程内存压力持续 60%+ 时，systemd-oomd 杀掉 session 里最大进程（保护整机）。
   ⚠️ 数值依据（15.5GiB 内存 + 8G zram）：MemoryMax 必须给内核 + zram 压缩池留余量，
   zram 高压时自身占 2-4G 内存，设 14G 会导致系统级 OOM；用 9G/12G 安全。
   08-18 教训：80% 阈值 + 15s 采样在快速 thrash 下来不及出手 → 降到 60%。
   MemoryHigh 从 10G 降到 9G（chrome+pi+微信正常占 6-9G，8G 会持续施压卡顿，9G 平衡）。
3. **单进程限流（第三道）**：已知内存失控进程套上限（qsearch 曾吃 9.5GB）
   ```bash
   # systemd-run 方式启动时限制；或给 .desktop 加 Exec=systemd-run --user --property=MemoryMax=4G ...
   ```

## PSR 显示管线风暴（2026-08-18 新认知）

**症状**：sway/wlroots 日志（journalctl 中 gdm-wayland-session 进程的 sway 输出）
**每天 1.2-3.5 万次** `Atomic commit failed: Device or resource busy` + `Page-flip
failed on output eDP-1`（08-10 至 08-18 八天累计 17 万次）。

**定性**：i915 PSR（Panel Self Refresh）在 Kaby Lake 上的已知 bug——eDP 面板自刷新
与 wlroots atomic commit 冲突。08-10 死机排查时就查过 `i915_edp_psr_status`（PSR 状态），
当时未定论，08-18 日量统计实锤。PSR bug 可能加重死机观感（屏幕冻结）。

**修复**：内核参数 `i915.enable_psr=0`（/etc/default/grub 的 GRUB_CMDLINE_LINUX 追加
+ grub2-mkconfig + 重启）。副作用仅 eDP 省电略降。撤销：去掉参数重跑 mkconfig。

**注意事项（BLS 引导）**：Fedora UEFI 用 Boot Loader Spec，内核参数实际存于
`/boot/loader/entries/*.conf` 的 options 行。mkconfig 后必须检查最新条目是否含新参数，
否则重启不生效（grub2-mkconfig 会重新生成 BLS 条目，但须验证）。

**判定命令**：
```bash
journalctl -b -1 --no-pager | grep -c "Atomic commit failed"     # 日均过万 = 确诊
journalctl -b -1 --no-pager | grep "Atomic commit failed" | awk '{print $1, $2}' | cut -c1-16 | uniq -c | tail  # 按天分布
cat /sys/kernel/debug/dri/0/i915_edp_psr_status 2>/dev/null      # PSR 当前状态（需 root）
```

## Phase 3：验证

```bash
systemctl status earlyoom systemd-oomd --no-pager
systemctl show user@$(loginctl list-users --no-legend | awk '$1!=0{print $1;exit}') --property=MemoryHigh,MemoryMax,ManagedOOMMemoryPressure
# 重启后观察：earlyoom 日志（journalctl -u earlyoom -f）在内存高压时应有 kill 记录
```

## 预防（行为层）

- zram 是压缩内存，内存耗尽时自身也要内存——别把 zram 当无限 swap
- **定期重启（2026-08-18 教训）**：8 天 uptime + 46 次 suspend/resume 后死机——
  建议每周重启一次，长 uptime + 反复 suspend/resume 放大内核状态腐化
- 多开 pi/bun + Chrome + Firefox + 钉钉时注意 15GB 总盘子
- 大任务（pi update --extensions、搜索、编译）前 `free -h` 看一眼
- **chrome 是头号内存压力源**：chrome 进程数 >16、reaper 日志有 KILLED、bridge 频繁重启 = 泄漏进行时 → 先修泄漏（[chrome-leak-reaper.md](chrome-leak-reaper.md)）再谈防护
- **anki 剪贴板风暴（2026-08-18 新嫌疑）**：anki 出现同秒上百条 `use clipboard` +
  JS error 循环（`saveNow is not defined`）= 泄漏循环信号，会吃 CPU/内存——留意

## 注意事项

- earlyoom 默认杀 oom_score 最高的进程，可能杀掉正在写的重要进程——但**冻死丢得更多**（整个 session 的未保存内容）
- 不要禁用 systemd-oomd 换 earlyoom，两者互补
- 改 user@.service.d 后必须 daemon-reload，当前已登录 session 的 MemoryMax 在下次登录生效
- `-m 8` 激进阈值会误杀场景：编译/大任务时内存短暂 <8% 可能 SIGTERM 最大进程
  （--prefer 优先杀 Web Content，pi/bun 不在 avoid 列表）——设计权衡：宁杀进程不冻死整机

## 变更记录

### 1.3.0 (2026-08-24)
- **修复：earlyoom -M/-S 单位坑**——1.8.2 的 -M/-S 是 KiB 且覆盖 -m/-s；08-18 配置
  `-m 8 -M 5 -s 100 -S 100` = 5 KiB/100 KiB ≈ 0% 阈值，全程哑火（两次死机都没出手）。
  修正为 `-m 8 -s 100`（8%/4% + swap 恒真），并新增强制验证命令
  `journalctl -u earlyoom -b 0 | grep SIGTERM`（必须 8.00%/100.00%，0.00%=哑火）
- 新增：判定方法升级——不能只看 ps cmdline（参数正确≠生效），必须看启动日志阈值
- 案例：2026-08-24 22:17 OOM 重启（6 天 uptime；08-24 白天 3 次低压 1.7G→663MB→1.25G；
  22:17:30 全局 OOM 连杀 8 进程含 QtWebEngine/gnome-software/wsdd/portal；Purging GPU
  memory 剩 2053 页=8MB 临界枯竭；session-3 peak 14.1G+7.8G swap；oomd 22:17:47 出手
  杀 localsearch 但太晚；earlyoom 0% 阈值全程哑火；22:18:40 用户按电源键自救关机；
  PSR 参数本次重启才生效——boot -1 期间 Atomic commit failed 27.3 万次）

### 1.2.0 (2026-08-18)
- 新增：earlyoom zram 盲区认知（Fedora 默认双条件 AND：内存 <4% 且 swap free <10%，
  zram 8G 掩护下 swap 条件永不满足 → 全程哑火；`-s 100 -S 100` 退化为纯内存阈值）
- 新增：PSR 显示管线风暴节（Atomic commit failed 日均 1.2-3.5 万次 = Kaby Lake i915
  PSR bug，`i915.enable_psr=0` 修复 + BLS 条目验证注意事项）
- 更新：earlyoom 参数 `-m 4 -M 409600` → `-m 8 -M 5 -s 100 -S 100`（08-18 死机实战精进）
- 更新：oomd 阈值 80%→60%、MemoryHigh 10G→9G（80%+15s 采样在快速 thrash 下来不及）
- 更新：Phase 1 诊断加 Purging GPU memory 页数对比判读（2053 页=临界枯竭 vs 565266 页=缓涨期）
- 更新：预防加每周重启建议 + anki 剪贴板风暴泄漏嫌疑
- 案例：2026-08-18 17:48 死机（8 天 uptime + 46 次 suspend/resume；内存耗尽→zram thrash
  冻结；无 oom-kill；最后日志 Purging GPU memory 剩 8MB GPU 池；earlyoom/oomd 均未触发）

### 1.1.0 (2026-08-10)
- 新增：死机元凶排查（chrome 泄漏命令 + 交叉引用 chrome-leak-reaper.md）
- 新增：front matter triggers「内存被吃光」
- 案例：2026-08-10 20:09 死机（reaper 误杀 bridge zygote → worker 循环 → thrash 冻结）
