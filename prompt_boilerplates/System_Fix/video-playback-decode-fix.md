---
name: video-playback-decode-fix
version: 2.1.1
description: Fedora 视频播放/解码故障修复总集——A 无法解码（ffmpeg-free 禁专利解码器 → RPM Fusion dnf swap 换完整 ffmpeg）；B 能播放但雪花/花屏（iHD 驱动缺 Gen9 HEVC 硬解 → i965 驱动 + VAAPI 硬解 + 环境注入）；覆盖 VLC/mpv/ffplay/GStreamer 全链路与 Intel VAAPI 驱动层（iHD/i965），附两脚本与 MPRIS 位置恢复
triggers:
  - "VLC"
  - "vlc 无法播放"
  - "could not decode"
  - "无法解码"
  - "hevc"
  - "h265"
  - "x265"
  - "视频解码失败"
  - "ffmpeg-free"
  - "libavcodec"
  - "播放器黑屏"
  - "雪花"
  - "花屏"
  - "画面错乱"
  - "播放卡顿"
  - "硬解"
  - "vaapi"
  - "i965"
  - "iHD"
  - "mpv 播不了"
  - "gstreamer 解码"
  - "播放器花屏"
  - "显卡加速"
inputs:
  - name: symptom
    description: 报错原文或症状（能否播放、有无花屏、播放器名、文件编码）
    required: false
    default: "auto-detect"
  - name: fix_mode
    description: '修复模式: ask（先问后改）, auto（直接修复）, report（仅诊断不改）'
    required: false
    default: "ask"
  - name: file_path
    description: 待测视频文件路径（症状 B 基准测试用）
    required: false
    default: ""
tools:
  - read
  - bash
  - grep
  - edit
  - write
  - ask_user
---

# Fedora 视频播放/解码故障修复总集 Skill

本 skill 是 Fedora 视频播放与解码基础组件之故障总集：播放器（VLC/mpv/ffplay/GStreamer）、解码库（ffmpeg/libavcodec）、硬解驱动层（Intel VAAPI：iHD/i965）全覆盖。两类根因迥异，先分诊后修复：

| 症状 | 表现 | 根因 | 修复 |
|------|------|------|------|
| **A. 无法解码** | 报 `VLC could not decode the format "hevc"`、黑屏 | Fedora 官方 `ffmpeg-free` 编译时禁用 `h264,hevc,vc1,vvc` 解码器 | RPM Fusion + `dnf swap ffmpeg-free ffmpeg` |
| **B. 能播放但花屏** | 雪花、画面错乱、卡顿（尤暗场明显） | iHD 驱动移除 Kaby Lake 等 Gen9 平台 HEVC VAAPI → VLC 静默回退软解 → 弱 CPU 掉帧错乱 | i965 驱动 + `avcodec-hw=vaapi` + 环境注入 |

两症状之判据：**A 看 `rpm -qa` 有无 `ffmpeg-free`，B 看 `vainfo` 有无 HEVC profile + ffmpeg 基准速度**。本 skill 基于 2026-08-07（症状 A，Caligula 1979 x265 10bit）与 2026-08-10（症状 B，Prisoners 2013 x265 10bit）两实战。

## 任务目标

1. 分诊症状 A/B，确认根因非文件损坏
2. 症状 A：RPM Fusion 完整 ffmpeg 替换 ffmpeg-free（`dnf swap`）
3. 症状 B：i965 VAAPI 硬解链路（配置注入 + 干净环境重启 + 位置恢复）
4. 验证解码恢复且 CPU 负载达标

## 核心认知

### 基础组件全景（播放器 → 解码库 → 驱动层）

| 层 | 组件 | 与故障关系 |
|----|------|-----------|
| 播放器 | VLC 3.0（`libavcodec_plugin.so`） | 解码/硬解全走 avcodec；VLC 4.0 将改走 libplacebo/自研管线，届时重新评估 |
| 播放器 | mpv（libmpv + ffmpeg） | 依赖系统 `libavcodec.so`，症状 A 下同样缺解码器 |
| 播放器 | ffplay（ffmpeg 自带） | 最直接的解码通路测试器，`ffplay 文件` 报 `Could not find codec parameters` = 症状 A |
| 播放器 | GStreamer（`decodebin` → `avdec_h265`） | 依赖 `gstreamer1-plugins-bad-freeworld` + 完整 ffmpeg-libs |
| 解码库 | `libavcodec.so.61`（FFmpeg 7.x） | free 版禁 h264/hevc/vc1/vvc；full 版全支持。SONAME 相同，swap 需 `--allowerasing` |
| 驱动层 | Intel VAAPI：**iHD**（`intel-media-driver`） | 新平台 Gen11+ 完整支持 HEVC/AV1；**Gen9/Gen9.5 已移除 HEVC**（仅剩 MPEG2/JPEG/VP8/VP9） |
| 驱动层 | Intel VAAPI：**i965**（`libva-intel-driver`，legacy EOL） | Gen8-Gen9.5 全支持 HEVC Main8/Main10 VLD；`LIBVA_DRIVER_NAME=i965` 强制启用 |
| 驱动层 | NVIDIA VDPAU / AMD VAAPI | 各自驱动支持；故障排查同理（先 `vainfo`/`vdpauinfo` 查 profile，再对播放器开硬解） |

驱动安装（GPU 无硬件加速时）：`sudo dnf install intel-media-driver`（iHD，新平台）或 `sudo dnf install libva-intel-driver`（i965，老平台，RPM Fusion）；检测当前驱动：`vainfo 2>&1 | head` 看 `Driver version` 行。

### 症状 A（无法解码）

| 事实 | 说明 |
|------|------|
| **ffmpeg-free 禁解码器** | Fedora 官方构建 `ffmpeg` 配置含 `--disable-decoder='h264,hevc,libxevd,vc1,vvc'`。HEVC 与 H.264 皆放不了——报 HEVC 时其 x264 文件同样播不了 |
| **VLC 解码链路** | VLC 3.0 的 HEVC/H.264 解码全走 `libavcodec_plugin.so` → `libavcodec.so.61`。若该库为 free 版 → 报 `could not decode the format "hevc"` |
| **vlc-plugins-freeworld ≠ 完整 ffmpeg** | RPM Fusion 的 `vlc-plugins-freeworld` 已装亦可能报错——其依赖完整版 `ffmpeg-libs`，而系统装 `libavcodec-free`，插件链接无解码能力之库 |
| **版本不匹配是烟雾弹** | 实测 `vlc-plugins-freeworld-3.0.22` + `vlc-libs-3.0.23` 共存不会导致此报错，勿折腾插件版本 |
| **硬解亦走 avcodec** | VLC 的 VAAPI/VDPAU 硬解同样经 avcodec 分发，ffmpeg-free 下硬解路径一样缺 HEVC，无捷径 |
| **ffprobe "profile=unknown" 是线索** | ffprobe 显示 `profile=unknown`/`pix_fmt=unknown` 且能读容器 → 多半缺解码支持（正常应显示 `Main 10`/`yuv420p10le`） |

### 症状 B（花屏/错乱）

| 事实 | 说明 |
|------|------|
| **iHD 驱动弃 Gen9 HEVC** | 现代 intel-media-driver（如 25.4.6）已移除 Kaby Lake(Gen9.5) 之 HEVC VAAPI profile，`vainfo` 仅剩 MPEG2/JPEG/VP8/VP9。此为**驱动层面**移除，非配置问题 |
| **VLC 静默回退软解** | `--avcodec-hw any` 硬解尝试失败后 VLC **不报错**直接软件解码——日志无提示，CPU 150-200% 是唯一线索 |
| **弱 CPU 软解 10bit 不足** | 1080p10 HEVC 软解需约 2 满核现代桌面 CPU；i5-7300U(2C/4T) 实测仅 18fps=**0.73x**，且热降频持续恶化（31→18fps） |
| **掉帧即错乱** | 解码跟不上 → VLC 掉帧 + HEVC 帧线程引用错乱 → 雪花/花屏。暗场电影（如 Prisoners）最明显 |
| **i965 驱动是解药** | legacy `libva-intel-driver`（i965 2.4.0.pre1，RPM Fusion 已装于多数系统）完整支持 KBL `VAProfileHEVCMain10: VLD`；`LIBVA_DRIVER_NAME=i965` 强制启用 |
| **硬解收益量级** | 实测同机：软解 18fps(0.73x)/CPU 185% → 硬解 151fps(6.28x)/CPU 11-15%，快 8.4 倍，零解码错误 |
| **文件未坏** | 症状 B 之文件 ffprobe 正常、ffmpeg CLI 全片解码 0 错误——排除源文件损坏 |

## 执行流程

### Phase 0: 症状分诊（30 秒）

```bash
# 1. 文件流信息（正常 = 能读出 codec/profile/pix_fmt）
ffprobe -v error -show_entries stream=index,codec_name,profile,pix_fmt,width,height -of compact "文件路径"

# 2. 系统 ffmpeg 版本（判 A）
rpm -qa | grep -iE "^ffmpeg|libavcodec"        # 见 ffmpeg-free / libavcodec-free → 症状 A
ffmpeg -version 2>&1 | grep -o 'disable-decoder[^ ]*'

# 3. VAAPI 能力（判 B）
vainfo 2>&1 | grep -E "VAProfileHEVC"          # 无 HEVC 且 CPU 高 → 症状 B
```

| 判据 | 结论 |
|------|------|
| `rpm -qa` 有 `ffmpeg-free` / `libavcodec-free`；ffmpeg 配置含 `--disable-decoder='h264,hevc,...'` | **症状 A** → Phase A |
| ffprobe 能读流但 profile/pix_fmt = unknown | 疑 A → 先确认 rpm 再入 Phase A |
| ffprobe 正常（Main 10 / yuv420p10le）+ 播放花屏 + VLC CPU 150%+ | **症状 B** → Phase B |
| ffprobe 报 `moov atom not found` / 直接失败 | 文件损坏，与本文档无关 → 重新下载/转码 |
| ffmpeg 完整版且 vainfo 有 HEVC 但仍异常 | 非本文档范围 → 查 VLC 插件加载（`vlc -vvv` 日志）、显卡驱动 |

### 症状 A 流程 — 无法解码

#### A1. 修复（需 sudo，交给用户执行）

```bash
# 一键脚本：
sudo bash ~/prompt_boilerplates/System_Fix/video-decode-ffmpeg-swap.sh

# 手动三步等价命令：
# 1) 启用 RPM Fusion（free + nonfree）
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
# 2) 换掉 ffmpeg-free（--allowerasing 必要：同 SONAME 库替换）
sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
# 3) 刷新 vlc 全家桶到匹配版本
sudo dnf install vlc --refresh -y
```

#### A2. 验证（复现原场景）

```bash
# 1. free 版已被替换
rpm -qa | grep -iE "^ffmpeg"                   # 应只有 ffmpeg（无 -free 后缀）
ffmpeg -version 2>&1 | grep -c 'disable-decoder'  # 应为 0 或不再含 h264/hevc
# 2. 解码实测（前 60 秒，不播放画面）
ffmpeg -v error -i "文件路径" -f null - -t 60 && echo "DECODE OK"
# 3. 复现原场景
vlc "文件路径"
```

### 症状 B 流程 — 能播放但花屏

#### B1. 确认播放器与 CPU 负载

```bash
ps aux | grep -i vlc | grep -v grep          # 找目标实例；--started-from-file 为 GUI 实例
ps -p <PID> -o pid,%cpu,etime --no-headers   # CPU 150%+ → 软解；<20% → 硬解（排除故障）
```

#### B2. 软解基准测试（核心判据：speed < 1.0x = CPU 物理不足）

```bash
# 跑足 120 秒（热降频会恶化：31→18fps，短测会误判）
timeout 180 ffmpeg -i "文件路径" -t 120 -f null -benchmark -stats_period 30 - 2>&1 | grep -E "speed"
# 预期：speed=0.73x 左右且逐段下降 → 软解瓶颈坐实
```

#### B3. VAAPI 能力对照（iHD vs i965）

```bash
vainfo 2>&1 | grep -E "VAProfile"                 # 默认 iHD：无 HEVC → 驱动弃硬解
LIBVA_DRIVER_NAME=i965 vainfo 2>&1 | grep -E "VAProfileHEVC"
# 预期：VAProfileHEVCMain10: VAEntrypointVLD → i965 可硬解
# i965 无输出 → dnf install libva-intel-driver（RPM Fusion）
```

#### B4. ffmpeg VAAPI 硬解实测（验证通路 + 量化收益）

```bash
ls -l /dev/dri/renderD128                        # render 设备须存在
LIBVA_DRIVER_NAME=i965 ffmpeg -v error -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
  -i "文件路径" -t 60 -f null - 2>&1 | head      # 0 错误 = 硬解通路正常
LIBVA_DRIVER_NAME=i965 ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
  -i "文件路径" -t 30 -f null -benchmark - 2>&1 | grep speed
# 预期：speed=6x+（vs 软解 0.73x）→ 修复后收益基准
```

#### B5. 配置注入（幂等，可反复执行；一键脚本：`bash ~/prompt_boilerplates/System_Fix/video-playback-vaapi-fix.sh`）

```bash
# 1. vlcrc 强制 VAAPI 硬解
sed -i 's/^#avcodec-hw=any/avcodec-hw=vaapi/' ~/.config/vlc/vlcrc

# 2. 桌面启动器注入 i965 驱动（用户级覆盖，应用菜单启动即生效）
mkdir -p ~/.local/share/applications
cp /usr/share/applications/vlc.desktop ~/.local/share/applications/vlc.desktop
sed -i 's|^Exec=/usr/bin/vlc --started-from-file %U|Exec=env LIBVA_DRIVER_NAME=i965 /usr/bin/vlc --started-from-file %U|' \
  ~/.local/share/applications/vlc.desktop

# 3. 全会话环境注入（下次登录生效；Chromium 等亦受益）
mkdir -p ~/.config/environment.d
printf '# Force legacy i965 VAAPI driver (iHD lacks HEVC on Gen9)\nLIBVA_DRIVER_NAME=i965\n' \
  > ~/.config/environment.d/50-vaapi-i965.conf
```

#### B6. 重启 VLC 并恢复位置（关键：pi 环境 DBUS 变量污染，必须干净环境）

```bash
# 1. MPRIS 读取当前位置（微秒）与状态
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc /org/mpris/MediaPlayer2 \
  org.freedesktop.DBus.Properties.Get string:org.mpris.MediaPlayer2.Player string:Position
dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc /org/mpris/MediaPlayer2 \
  org.freedesktop.DBus.Properties.Get string:org.mpris.MediaPlayer2.Player string:PlaybackStatus
# 2. 优雅退出（Quit 在根对象接口，Player 接口无此方法）
dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc /org/mpris/MediaPlayer2 \
  org.mpris.MediaPlayer2.Quit
# 3. systemd-run 干净环境重启（禁 setsid nohup——污染环境致 VLC 静默自退）
systemd-run --user --unit=vlc-prisoners \
  --setenv=HOME=$HOME --setenv=PATH=/usr/bin:/bin \
  --setenv=DISPLAY=:0 --setenv=WAYLAND_DISPLAY=wayland-1 \
  --setenv=XDG_RUNTIME_DIR=/run/user/1000 \
  --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  --setenv=LIBVA_DRIVER_NAME=i965 \
  /usr/bin/vlc --started-from-file --start-time=<秒> "文件路径"
```

#### B7. 验证硬解生效

```bash
ps -C vlc -o pid,%cpu --no-headers              # <20% = 硬解；150%+ = 仍软解（回查配置）
journalctl --user -u vlc-prisoners --no-pager | grep -E "hardware decoding"
# 预期输出: Using Intel i965 driver ... for hardware decoding
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc /org/mpris/MediaPlayer2 \
  org.freedesktop.DBus.Properties.Get string:org.mpris.MediaPlayer2.Player string:Position
# 位置应持续推进；画面临场察之，雪花/错乱消失即愈
```

## 输出格式

修复报告：

```text
━━━━━ VLC HEVC 解码故障报告 ━━━━━
分诊：症状 A（无法解码）/ 症状 B（花屏错乱）/ 非本文档范围
[症状 A] ffmpeg-free → 已 swap 完整 ffmpeg / 待 sudo 执行
[症状 B] 软解基准 speed=0.73x（不足）→ 硬解基准 6.28x ✅
  vlcrc avcodec-hw=vaapi      ✅/❌
  vlc.desktop i965 注入       ✅/❌
  environment.d i965          ✅/❌（下次登录生效）
  VLC 重启（位置 677s 恢复）  ✅ Playing 且位置推进
  CPU 负载：185% → 15%       ✅
验证：journalctl ... hardware decoding / 画面无雪花
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 预防

1. **装完 Fedora 先换 ffmpeg**：新装机/重装后第一步 `dnf install https://mirrors.rpmfusion.org/...` + `dnf swap ffmpeg-free ffmpeg`，从源头避免症状 A。
2. **老 Intel 平台防症状 B**：Kaby Lake 及更早（Gen9.5/Gen9）若见花屏，先查 `vainfo | grep HEVC`；无 HEVC 即 iHD 弃之，`LIBVA_DRIVER_NAME=i965` 强制 legacy 驱动。新平台（Gen11+）iHD 完整支持 HEVC/AV1，勿套用 i965。
3. **自查命令**（shell alias）：
   ```fish
   alias codec-check 'rpm -qa | grep -iE "ffmpeg|libavcodec"; and ffmpeg -version | grep -o "disable-decoder[^ ]*"; and vainfo | grep -E "VAProfileHEVC"'
   ```
4. **升级 vlc 版本不齐时**：`sudo dnf install vlc --refresh` 一次拉齐 vlc/vlc-libs/vlc-plugins-freeworld。
5. **症状 B 修复后**：重开播放器即硬解；environment.d 配置在下次登录前对非桌面启动（CLI）应用无效，须手动带 `LIBVA_DRIVER_NAME=i965`。

## 注意事项（踩过的坑）

1. **`dnf swap ffmpeg-free ffmpeg` 必须加 `--allowerasing`**：libavcodec-free 与 libavcodec 同 SONAME（.so.61），不加会报文件冲突。
2. **勿手动 `dnf install ffmpeg` 硬装**：与 ffmpeg-free 冲突报错，正确姿势是 `swap`。
3. **`vlc --list-codecs` 不存在**：VLC 3.0 无此 CLI 选项，查插件用 `ls /usr/lib64/vlc/plugins/codec/` + `ldd`。
4. **报错格式名可能是 "hevc" 或 "MPEG-H Part2/HEVC (H.265)"**：同一错误不同显示，判据是 rpm 包名而非格式名。
5. **只报 HEVC 不报 H.264 不代表 H.264 能放**：free 版两解码器皆禁，修完一并验证 x264 文件。
6. **sudo 需要密码时勿假装能修**：非交互无法执行时写脚本交用户 `sudo bash`，并给验证命令。
7. **硬解不能绕过症状 A**：VAAPI 分发亦经 avcodec，ffmpeg-free 下硬解一样缺 HEVC（先修 A 再谈 B）。
8. **pi 环境 DBUS 变量污染**：pi/bash 之 `DBUS_SESSION_BUS_ADDRESS` 可能为坏值，VLC 后台启动会报 `Could not parse server address: Unknown address type` 后**静默自退**。凡从 agent 环境启 VLC，须 `systemd-run --user --setenv=...` 显式传 `DISPLAY`/`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`/`LIBVA_DRIVER_NAME`；`setsid nohup` 不可靠。
9. **VLC 花屏时勿先疑文件损坏**：先跑 ffmpeg CLI 全片解码（0 错误 = 文件无恙），再查解码链路。
10. **软解基准勿短测**：热降频致速度随播放时间衰减（31→18fps），须测满 60-120 秒方得真值。
11. **MPRIS Quit 在根接口**：`org.mpris.MediaPlayer2.Player` 无 Quit 方法，须调 `org.mpris.MediaPlayer2.Quit`；Position 单位为微秒，`--start-time` 为秒。
12. **environment.d 仅下次登录生效**：立即生效路径是 desktop 文件注入 + systemd-run 重启；勿指望环境变量当日全会话生效。
13. **i965 驱动已 EOL**（2.4.0.pre1）：对 KBL 硬解稳定够用；换 VLC 4.0 或新显卡时重新评估。
14. **本文档属于 System_Fix 技能集**：入口与症状决策树见 [index.md](index.md)；系统级诊断流程见 [system_diagnostics_and_repair.md](system_diagnostics_and_repair.md)。

## 变更日志

### 2.1.1 (2026-08-16)
- 修复：inputs description 含裸半角冒号致严格 YAML 解析失败，已加引号（规则见 skill_creator.md 检查清单 G 组）

### 2.1.0 (2026-08-10)
- 改名：`vlc-hevc-decode-fix.md` → **`video-playback-decode-fix.md`**（universal 化，覆盖播放器/解码库/驱动层全链路）；脚本随之改名 `video-decode-ffmpeg-swap.sh`、`video-playback-vaapi-fix.sh`
- 新增：「基础组件全景」表（VLC/mpv/ffplay/GStreamer 播放器矩阵 + libavcodec 解码库 + Intel VAAPI iHD/i965 驱动层），收拢 system_diagnostics_and_repair.md 之 `intel-media-driver` 安装知识
- 新增：triggers「mpv 播不了」「gstreamer 解码」「播放器花屏」「显卡加速」

### 2.0.0 (2026-08-10)
- 新增：症状 B 分支「能播放但雪花/画面错乱」——基于 2026-08-10 实战（Prisoners 2013 x265 10bit + VLC 3.0.23 + i5-7300U/HD620）
- 新增：核心认知 B 表（iHD 弃 Gen9 HEVC / VLC 静默回退软解 / 0.73x 基准 / i965 解药 / 8.4 倍收益）
- 新增：Phase B1-B7 流程（CPU 确认 → 软解基准 → vainfo 对照 → ffmpeg VAAPI 实测 → 三处配置注入 → systemd-run 干净环境重启 → 硬解验证）
- 新增：脚本 `vlc-hevc-vaapi-fix.sh`（幂等配置注入 + MPRIS 位置恢复 + 一键重启）
- 新增：注意事项 8-13（DBUS 污染 / 文件勿疑 / 短测勿判 / MPRIS 接口 / environment.d 生效时机 / i965 EOL）
- 修改：front matter triggers 扩充（雪花/花屏/画面错乱/硬解/vaapi/i965/iHD）；tools 修正为 pi-agent 工具名；inputs 增 file_path
- 修改：正文转浅文言风格（skill_creator 1.7 规范）

### 1.0.0 (2026-08-07)
- 初始发布：基于 2026-08-07 实战（Fedora 42 + VLC 3.0.23 + ffmpeg-free 7.1.4 + 罗马帝国艳情史 Caligula 1979 x265 10bit）
- 关键实证：ffmpeg-free 编译配置 `--disable-decoder='h264,hevc,libxevd,vc1,vvc'`；vlc-plugins-freeworld 已装仍报错（依赖完整 ffmpeg-libs）；ffprobe `profile=unknown` 为缺解码器线索
