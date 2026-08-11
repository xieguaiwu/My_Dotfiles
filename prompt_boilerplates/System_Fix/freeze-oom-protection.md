---
name: freeze-oom-protection
version: 1.1.0
description: 死机/OOM thrash 冻结排查与一劳永逸防护——earlyoom 兜底 + systemd-oomd 加固 + 进程限流。基于 2026-08-10 20:09 死机实战（chrome 泄漏引爆内存 thrash；Kaby Lake i915 + sway + zram，15GB RAM）
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

## Phase 1：诊断（必查项）

```bash
journalctl --list-boots | head -5
journalctl -b -1 -n 100 --no-pager | tail -80          # 死前最后日志
journalctl -b -1 --no-pager | grep -E "oom-kill|Out of memory|Killed process" | tail
journalctl -b -1 --no-pager | grep "Purging GPU memory" | head
free -h && zramctl                                     # 内存与 zram 现状
systemctl status systemd-oomd --no-pager               # oomd 是否真的会响应
```

## Phase 2：一劳永逸防护（一键脚本 `freeze-oom-protect.sh`）

三层防线，全部要装：

1. **earlyoom（第一道，最关键）**：内存可用 <10% 杀最大进程，死机前 30 秒救回系统
   ```bash
   sudo dnf install -y earlyoom
   sudo systemctl enable --now earlyoom
   # 可选更激进：MemoryAvailableLimit=5% 时杀进程
   ```
2. **systemd-oomd 加固（第二道）**：给用户 session 开内存压力监控
   ```bash
   sudo mkdir -p /etc/systemd/system/user@.service.d
   sudo tee /etc/systemd/system/user@.service.d/oomd-protect.conf >/dev/null <<'EOT'
   [Service]
   MemoryHigh=10G
   MemoryMax=12G
   ManagedOOMMemoryPressure=kill
   ManagedOOMMemoryPressureLimit=80%
   EOT
   sudo systemctl daemon-reload
   ```
   效果：用户进程内存压力持续 80%+ 时，systemd-oomd 杀掉 session 里最大进程（保护整机）。
   ⚠️ 数值依据（15.5GiB 内存 + 8G zram）：MemoryMax 必须给内核 + zram 压缩池留余量，
   zram 高压时自身占 2-4G 内存，设 14G 会导致系统级 OOM；用 10G/12G 安全。
3. **单进程限流（第三道）**：已知内存失控进程套上限（qsearch 曾吃 9.5GB）
   ```bash
   # systemd-run 方式启动时限制；或给 .desktop 加 Exec=systemd-run --user --property=MemoryMax=4G ...
   ```

## Phase 3：验证

```bash
systemctl status earlyoom systemd-oomd --no-pager
systemctl show user@$(loginctl list-users --no-legend | awk '$1!=0{print $1;exit}') --property=MemoryHigh,MemoryMax,ManagedOOMMemoryPressure
# 重启后观察：earlyoom 日志（journalctl -u earlyoom -f）在内存高压时应有 kill 记录
```

## 预防（行为层）

- zram 是压缩内存，内存耗尽时自身也要内存——别把 zram 当无限 swap
- 多开 pi/bun + Chrome + Firefox + 钉钉时注意 15GB 总盘子
- 大任务（pi update --extensions、搜索、编译）前 `free -h` 看一眼
- 24 天不重启不是荣耀——长时间 uptime + 反复 suspend/resume 会放大内核状态腐化
- **chrome 是头号内存压力源**：chrome 进程数 >16、reaper 日志有 KILLED、bridge 频繁重启 = 泄漏进行时 → 先修泄漏（[chrome-leak-reaper.md](chrome-leak-reaper.md)）再谈防护

## 注意事项

- earlyoom 默认杀 oom_score 最高的进程，可能杀掉正在写的重要进程——但**冻死丢得更多**（整个 session 的未保存内容）
- 不要禁用 systemd-oomd 换 earlyoom，两者互补
- 改 user@.service.d 后必须 daemon-reload，当前已登录 session 的 MemoryMax 在下次登录生效
