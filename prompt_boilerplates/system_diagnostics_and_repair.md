---
name: system-diagnostics-and-repair
version: 1.0.0
description: 排查 Linux 桌面系统问题（Fedora/Arch/Debian），收集硬件、内核、服务、日志信息，诊断常见缺陷并给出无需重启的修复方案
triggers:
  - "系统问题排查"
  - "电脑问题检测"
  - "系统诊断"
  - "修复系统错误"
  - "检查系统bug"
  - "machine check"
  - "system health check"
  - "检查系统缺陷"
inputs:
  - name: os_hint
    description: 已知的 OS 类型，如 fedora/arch/ubuntu
    required: false
    default: "auto-detect"
tools:
  - bash
  - read
  - write
  - edit
  - grep
  - glob
  - todowrite
  - task
---

# Linux 系统诊断与修复 Skill

## 任务目标

对当前 Linux 桌面系统进行全面诊断，识别缺陷、错误配置、硬件问题和服务异常，提供无需重启/无需进入 BIOS 的修复方案，并将修复打包为可执行脚本。

## 执行流程

### Phase 1: 并行采集系统信息

使用 `bash` 并行采集以下全部信息（一次性发出所有命令，不串行等待）：

#### 1.1 基本信息
```bash
uname -a
cat /etc/os-release
uptime
cat /proc/loadavg
```

#### 1.2 硬件与资源
```bash
lscpu | head -20
free -h
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
df -h | grep -v tmpfs | grep -v loop
swapon --show
zramctl
cat /proc/sys/vm/swappiness
```

#### 1.3 内核与驱动日志
```bash
journalctl -p err -b --no-pager | tail -50
journalctl -k -p crit -b --no-pager | tail -20
dmesg --level=err,warn 2>/dev/null | tail -50 || journalctl -k -b --no-pager 2>/dev/null | grep -iE 'error|fail|critical|bug|block|oom|hung|iowait' | tail -30
```

#### 1.4 系统服务
```bash
systemctl --failed
systemctl is-system-running
systemctl --user --failed 2>/dev/null
systemctl list-timers --all 2>/dev/null | head -15
```

#### 1.5 安全与网络
```bash
sestatus 2>/dev/null
ausearch -m avc -ts recent 2>/dev/null | tail -20 || echo "(no AVC)"
firewall-cmd --state 2>/dev/null
ip addr show | grep -E '^[0-9]|inet '
ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo "CONNECT: OK" || echo "CONNECT: FAIL"
```

#### 1.6 图形与显示
```bash
echo $XDG_SESSION_TYPE
lspci | grep -iE 'vga|3d|display'
glxinfo -B 2>/dev/null | grep -E 'Device|Vendor|Version|Accelerated'
```

#### 1.7 CPU 漏洞缓解
```bash
cat /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null
```

#### 1.8 蓝牙
```bash
systemctl status bluetooth 2>/dev/null | head -10
rfkill list
journalctl -k --grep='bluetooth|hci' -b --no-pager 2>/dev/null | grep -i 'fail\|error' | tail -10
```

#### 1.9 包管理器状态
```bash
# Fedora
dnf check 2>/dev/null | head -10
dnf check-update --quiet 2>/dev/null | head -10
# Debian
apt list --upgradable 2>/dev/null | head -10
# Arch
checkupdates 2>/dev/null | head -10
```

### Phase 2: 分析并识别问题

按以下检查清单逐一比对采集到的信息，标记严重程度。

#### 🔴 严重问题

| 问题 | 检查方式 | 典型症状 |
|------|----------|----------|
| **VMX/虚拟化禁用** | `journalctl -k --grep=VMX` | `VMX (outside TXT) disabled by BIOS`、`/dev/kvm` 不存在 |
| **OOM / 内存压力** | `journalctl -k --grep=oom` | `Out of memory: Killed process` |
| **文件系统错误** | `journalctl -k --grep='btrfs\|ext4\|xfs.*error'` | `btrfs: error`, `critical (device ...)` |
| **内核 panic/hung** | `journalctl -k -p crit` | `kernel BUG`, `Watchdog detected`, `hung_task` |
| **IO 故障** | `journalctl -k --grep='ata\|iowait\|I/O error'` | `I/O error`, `failed command`, `DRDY` |

#### 🟡 中等问题

| 问题 | 检查方式 | 典型症状 |
|------|----------|----------|
| **Portal 服务故障** | `systemctl --user --failed` 及 journal 中 xdg-desktop-portal | `Failed to start xdg-desktop-portal-gtk.service`（重复失败） |
| **蓝牙 HCI 错误** | `journalctl --grep='bluetooth.*hci.*fail'` | `Reading supported features failed (-16)` |
| **SELinux 策略缺口** | `ausearch -m avc` 或 journalctl --grep=selinux | `Permission ... not defined in policy` |
| **GPU 驱动问题** | `glxinfo` 中 `Accelerated: no` 或 `Direct Rendering: no` | 无硬件加速，软件渲染 |
| **包依赖损坏** | `dnf check` 或 `apt check` | 有 unsatisfied dependencies 输出 |
| **swappiness 不合理** | `cat /proc/sys/vm/swappiness` | 使用 zram 时 swappiness=60（应 10 左右） |
| **ZRAM 未启用** | `zramctl` 无输出，且系统只有磁盘 swap | 应启用 zram-generator |

#### 🟢 低/信息性问题

| 问题 | 说明 |
|------|------|
| **gkr-pam 警告** | `unable to locate daemon control file` — 启动竞态，通常自愈 |
| **Audio codec vmaster 警告** | `vmaster hook already present before cdev` — 内核 cosmetic 信息 |
| **polkitd JS 错误** | `Error converting subject to JS object: Process N terminated` — 瞬态，无影响 |
| **CPU 漏洞缓解缺失** | 如 Retbleed、Meltdown 等缓解状态不是 `Mitigation: ...` 或 `Not affected` |
| **待更新包** | `dnf check-update` 有输出 — 标准维护 |

### Phase 3: 给出修复方案

#### 3.1 修复类型分类

| 类型 | 是否需要 | 示例 |
|------|----------|------|
| **A - 无需 root** | 用户直接执行 | systemd user drop-in、配置修改 |
| **B - 需 root（无重启）** | 需 sudo | modprobe、sysctl、文件写入 `/etc` |
| **C - 需重启/进 BIOS** | 需用户手动操作 | 启用 VT-x、更新固件 |

#### 3.2 常见修复命令

**VMX 禁用**（类型 C）：
→ 进入 BIOS → Security → Virtualization → 启用 Intel VT-x / AMD SVM

**Portal 启动竞态**（类型 A）：
```fish
mkdir -p ~/.config/systemd/user/xdg-desktop-portal-gtk.service.d/
echo -e '[Service]\nRestartSec=5s' > ~/.config/systemd/user/xdg-desktop-portal-gtk.service.d/10-delay.conf
systemctl --user daemon-reload
```

**蓝牙 HCI 错误**（类型 B）：
```fish
echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
sudo modprobe -r btusb; and sudo modprobe btusb
```

**ZRAM swappiness 优化**（类型 B）：
```fish
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/90-swappiness.conf
sudo sysctl -w vm.swappiness=10
```

**SELinux 策略更新**（类型 B）：
```fish
# 通用策略更新
sudo dnf update selinux-policy-targeted
# 或针对某条 AVC 创建本地模块
sudo grep <特定模式> /var/log/audit/audit.log | sudo audit2allow -M fix
sudo semodule -i fix.pp
```

**GPU 无硬件加速**（类型 B）：
```fish
# 检查是否缺少固件
sudo dnf install mesa-dri-drivers mesa-libGL  # Fedora
# 或安装对应 Intel/AMD/NVIDIA 驱动
sudo dnf install intel-media-driver  # Intel VAAPI
```

**包依赖修复**（类型 B）：
```fish
# Fedora
sudo dnf check && sudo dnf distro-sync
# Debian
sudo apt --fix-broken install
```

### Phase 4: 打包为可执行修复脚本（可选）

如果有多项类型 B 修复，建议打包为单文件脚本供用户用 root 执行：

```fish
#!/usr/bin/env fish
# 生成示例
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/90-swappiness.conf
and sudo sysctl -w vm.swappiness=10
echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
sudo modprobe -r btusb; and sudo modprobe btusb
# ... 其他修复
```

- 脚本保存到用户 `~/Downloads/` 目录
- 使用 `fish` 语法（如果用户默认 shell 是 fish）
- 包含执行状态输出（`[✓]` / `[✗]`）
- 包含验证步骤

### Phase 5: 验证修复

逐项验证：

| 修复项 | 验证方式 |
|--------|----------|
| swappiness | `cat /proc/sys/vm/swappiness` 应为 10 |
| btusb 驱动 | `lsmod \| grep btusb` 存在 |
| USB autosuspend | `cat /etc/modprobe.d/disable-usb-autosuspend.conf` 存在 |
| Portal drop-in | `test -f ~/.config/systemd/user/xdg-desktop-portal-gtk.service.d/10-delay.conf` |
| SELinux 策略 | 修复后 `ausearch -m avc -ts recent` 不再有相关条目 |
| 蓝牙 | 重载后 `rfkill list` 无阻塞，`systemctl status bluetooth` active |
| 硬件加速 | `glxinfo -B \| grep Accelerated` → yes |
| 网络连通 | `ping -c1 8.8.8.8` → 成功 |

## 输出格式

```
## 系统诊断报告

### 严重问题（需重启/进 BIOS）
- [问题描述] → [修复方案]

### 中等问题（无需重启）
- [问题描述] → [修复方案]

### 低/信息性问题
- [问题描述]

### 修复脚本
[如适用，附上 fix.fish 脚本路径]

### Auto-Fix 摘要
| 修复项 | 状态 |
|--------|------|
| xxx | ✅/⏳/❌ |
```

## 注意事项

1. **sudo 权限**：本 skill 涉及读取系统日志和配置，部分命令需要 sudo。首次执行 `journalctl` 可能不需要 sudo，但 `dmesg` 需要 root。
2. **root 命令无法直接通过 AI 代理执行**：如果环境没有 passwordless sudo，将 root 命令整理为脚本让用户手动执行。
3. **fish shell 兼容**：本 skill 默认使用 fish 语法。用户在 bash/zsh 环境时，需将 `and`/`or` 替换为 `&&`/`||`，将 `echo ... | sudo tee ...` 替换为 `sudo sh -c 'echo ... > ...'`。
4. **VMX 问题无法纯软件修复**：必须进 BIOS，脚本/命令无法解决。明确告知用户。
5. **首次启动日志噪音**：刚刚启动的系统日志中会有大量 transient 错误（服务竞态、设备初始化）。区分"真实问题"和"启动瞬态"的关键：
   - 服务是否最终变为 active
   - 错误是否持续重试（restart_count >> 3）
   - 设备是否最终可用
6. **不要过度诊断**：`snd_hda_codec_conexant: vmaster hook`、`polkitd JS error` 等 warning 是 cosmetic，无功能影响，标记为 info 即可。
7. **btrfs 用户**：对 btrfs 环境检查 `sudo btrfs device stats /` 和 `sudo btrfs filesystem usage /`。
