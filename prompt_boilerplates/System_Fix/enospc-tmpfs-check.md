---
name: enospc-tmpfs-check
version: 1.0.0
description: 诊断 ENOSPC (no space left on device) 报错是否来自 tmpfs/内存盘而非磁盘。覆盖根盘空闲但写入失败、/run/user/1000 等 tmpfs 满、swap 压力导致 tmpfs 配额耗尽、孤儿进程泄漏等场景，提供清理与预防方案
triggers:
  - "ENOSPC"
  - "no space left on device"
  - "磁盘满"
  - "空间不足"
  - "tmpfs 满"
  - "内存盘满"
  - "写入失败"
  - "cannot create file"
  - "write failed"
  - "nvim报错"
inputs:
  - name: error_source
    description: 报错的程序（nvim / vim / 编译器 / 下载工具 / 任意写入者）
    required: false
    default: "auto-detect"
tools:
  - bash
  - read
  - grep
  - lsof
  - pgrep
  - kill
  - df
---

# ENOSPC / tmpfs 空间检查 Skill

## 任务目标

**ENOSPC 不等于磁盘满。** 程序报 `no space left on device` 时，先定位是**哪个挂载点**满了，而不是只看根分区。本 skill 用于：

1. 快速区分：真磁盘满 / inode 满 / tmpfs（内存盘）满 / 内存压力导致的假性满
2. 定位占用者：可见大文件、已删除但被进程持有的文件、孤儿进程
3. 安全清理并验证恢复

## 核心认知（来自 2026-07-31 实战）

| 事实 | 说明 |
|------|------|
| **tmpfs 满 ≠ 磁盘满** | `df -h /` 有 100G 空闲也可能 ENOSPC——报错可能发生在 `/run/user/1000`、`/tmp`、`/dev/shm` 等内存盘 |
| **换出页仍占配额** | tmpfs 页被换出到 swap 后**不再计入** `/proc/meminfo` 的 `Shmem`，但**仍计入 tmpfs 挂载配额**（`used_blocks` 不减）。典型特征：`df` 显示 100% 满，`du` 只统计到一半 |
| **ENOSPC 链路（实战验证）** | 进程泄漏占内存 → 内存压力 → tmpfs 页被换出到 swap → 换出页仍占配额 → 配额满 → ENOSPC。**swap 接近满 + tmpfs 满 + du 小于 df = 换出页占配额**，先杀进程而非只删文件 |
| **tmpfs 可用空间双限制** | 内核 `shmem_available()`：可用 = min(配额 − 已用, totalram − totalreserve − 已用)。第一项是配额限制（换出页占满即触发）；第二项是物理内存余量限制（仅当 RAM 被其他东西吃光时才触发，与 swap 无关） |
| **swap 是最大线索** | `free -h` 中 Swap 接近满（>90%）→ 大概率 tmpfs 页被换出 → 先查内存占用者，别只清理文件 |
| **1GB 文件可能是稀疏的** | `lsof` SIZE 显示 1GB 的 memfd 可能只分配 4KB。用 `stat -L` 看真实分配，别被逻辑大小吓到 |

## 执行流程

### Phase 1: 并行采集（一次性发出）

```bash
# 1. 所有挂载点使用率（别只看根盘！）
df -h
df -i   # inode 情况

# 2. 内存与 swap 压力（关键线索）
free -h
cat /proc/meminfo | grep -E 'Shmem|MemTotal|SwapTotal'

# 3. 已删除但仍被打开的文件（占空间但 du 看不见）
lsof +L1 2>/dev/null | head -40

# 4. 孤儿进程画像（父进程已死、挂到 systemd 下。⚠️ ppid=1 不全是孤儿——
#    systemd --user 直接托管的正常服务也 ppid=1。按名称分组看**异常聚集**：
ps -ef | awk '$3 == 1 {print $8}' | sort | uniq -c | sort -rn | head -10
# 对聚集的可疑进程（如 chrome/bwrap/chromedp）确认用户数据目录是临时目录后清理
```

### Phase 2: 判断类型

| 症状 | 结论 |
|------|------|
| 某**磁盘**挂载点（`/`、`/home`、`/data` 等）Use% = 100% | 真磁盘满 → 清文件/扩容 |
| Use% 不高但 inode IUse% = 100% | inode 耗尽 → 删海量小文件 |
| **tmpfs 挂载点**（`/run/user/1000`、`/tmp`、`/dev/shm`）100% 满 | tmpfs 满 → 继续 Phase 3 |
| tmpfs 100% 满 + `du` 统计 < `df` 显示 + swap >90% | **换出页占配额** → 找内存压力源（孤儿进程/大进程），清理进程而非仅删文件 |
| tmpfs 100% 满 + `Shmem` << `df` 显示 | 同上，换出页在 swap 中 |
| tmpfs 未满但写入仍 ENOSPC | 物理内存被吃光触发 `shmem_available()` 第二项限制（totalram − totalreserve − used）→ 释放内存/杀大进程 |

### Phase 3: 定位占用者

```bash
# 1. 可见大文件
du -sh /run/user/1000/* 2>/dev/null | sort -rh | head -10   # 换成目标挂载点

# 2. 已删除但被打开的"隐形"文件（lsof +L1 已列出）——按真实分配排序：
#    stat 必须加 -L，否则返回的是链接自身大小（64B），不是文件大小！
stat -L -c '%s %b' /proc/<PID>/fd/<N>    # %b = 实际分配的 512B 块数

# 3. 全进程统计已删除 fd 的真实分配（找出持有者）
for f in /proc/[0-9]*/fd/*; do
  [ -L "$f" ] || continue
  tgt=$(readlink "$f" 2>/dev/null) || continue
  case "$tgt" in *"(deleted)"*)
    out=$(stat -L -c '%s %b' "$f" 2>/dev/null) || continue
    [ -n "$out" ] || continue
    echo "${out##* } $f → $tgt"
  ;; esac
done | sort -rn | head -15

# 4. mmap 后删除的文件（fd 已关闭，lsof 看不到，/proc/*/maps 看得到）
grep deleted /proc/[0-9]*/maps 2>/dev/null | grep -v '/memfd' | head -10

# 5. 孤儿进程画像（泄漏源头）
ps -ef | awk '$3 == 1' | awk '{print $8}' | sort | uniq -c | sort -rn | head -10
```

### Phase 4: 修复（按安全顺序）

#### 4.1 杀孤儿进程（最大收益，先做）

```bash
# 找出泄漏进程组（示例：chromedp headless chrome 孤儿）
pgrep -f 'chromedp-runn[e]r' | wc -l
# 确认它们的父进程是 1（孤儿）且用户数据目录在 /tmp（临时、可安全丢弃）
ps -p $(pgrep -f 'chromedp-runn[e]r' | head -3) -o pid,ppid,cmd

# 杀掉（⚠️ 见注意事项 1：pkill -f 会匹配自身）
pids=$(pgrep -f 'chromedp-runn[e]r' | grep -v $$)
for p in $pids; do kill -9 $p 2>/dev/null; done
```

杀完立即看 `free -h` 和 `df -h <tmpfs>` —— swap 和 tmpfs 可用空间应显著回升（换出页回收是异步的，等几秒）。

#### 4.2 清理大日志（tmpfs 上可见的大头）

```bash
# 有进程持有 fd 的日志：先重启服务，再删除/截断
systemctl --user restart <service> 2>/dev/null   # 失败则手动杀进程
pkill -9 -f 'speech-dispatche[r]'
rm -rf /run/user/1000/<app>/log
# 或保留服务只截断：
: > /run/user/1000/<app>/log/xxx.log   # 注意：进程仍持有 fd，截断后不再增长
```

#### 4.3 清理历史临时文件

```bash
find /run/user/1000 -maxdepth 1 -name '*.log' -mtime +1 -delete
```

### Phase 5: 验证

```bash
# 对**报错时正在写的那个挂载点**验证（先确认它，别只测根盘）：
df -h /run/user/1000            # 报错挂载点应降到 <90%
free -h                          # swap 使用率下降
# 写入实测（最关键，直接对报错挂载点写）：
dd if=/dev/zero of=/run/user/1000/.wtest bs=1M count=50
rm -f /run/user/1000/.wtest
# 复现原报错场景（如重新打开 nvim / 重跑失败命令）
```

## 预防

1. **进程生命周期管理**：headless 浏览器（chromedp/chrome 等）泄漏是 tmpfs+内存压力的头号来源。给 bridge/daemon 加超时回收；定期 `ps -ef | awk '$3==1'` 检查孤儿。
2. **日志轮转**：`/run/user/1000` 上的日志（coc-nvim-*.log、speech-dispatcher 等）会无限增长。给日志加 logrotate 或按日清理。
3. **监控阈值**：`df -h /run/user/1000` 超过 85% 时告警；swap 使用率 >90% 时告警。
4. **快速自检命令**（写进 shell alias）：
   ```fish
   alias enospc-check 'df -h; and free -h; and lsof +L1 | head -20'
   ```

## 注意事项（踩过的坑）

1. **`pkill -f 'pattern'` 会自杀**：pkill 匹配完整命令行，执行 `pkill -f 'chromedp-runner'` 的 bash 自身命令行也含该字符串 → 把自己杀了，命令无输出。用 `[r]` 技巧（`chromedp-runn[e]r`）或 `pgrep -f 'xxx' | grep -v $$` 再 kill。
2. **`stat` 已删除 fd 必须加 `-L`**：`/proc/PID/fd/N` 是符号链接，不加 `-L` 返回的是链接自身大小（64B），不是目标文件大小。
3. **memfd 稀疏假象**：`lsof +L1` 显示 1GB 的 memfd（`lp_dma_buf`、`state table` 等）可能是稀疏的，实际分配 4KB。判断前先 `stat -L -c '%b'` 看真实块数，别误杀无辜进程。
4. **Shmem ≠ tmpfs 总用量**：`/proc/meminfo` 的 Shmem 只统计 RAM 中的 tmpfs 页，换出到 swap 的不算。用 `df` + `free -h` 结合判断。
5. **tmpfs 恢复是异步的**：杀完进程后 swap 中的换出页不会立即释放，等几秒到几十秒再验证。
6. **删日志前先处理持有者**：直接 `rm` 进程正在写的日志文件不会释放空间（fd 仍指向 inode）。先杀进程/重启服务，再删。
7. **btrfs 挂载点 inode 显示 0**：btrfs 无固定 inode 上限，`df -i` 显示 0/0 是正常现象，不代表 inode 耗尽。
8. **容器内 `/dev/shm` 默认只有 64M**：Docker/Podman 容器里 ENOSPC 常因 /dev/shm 太小，`docker run --shm-size=2g` 解决；先 `df -h /dev/shm` 确认。
9. **本文档属于 System_Fix 技能集**：入口与症状决策树见 [index.md](index.md)；opencli/chromedp 泄漏与搜索管道的关联见 [piagent-search-pipeline-fix.md](piagent-search-pipeline-fix.md)。
