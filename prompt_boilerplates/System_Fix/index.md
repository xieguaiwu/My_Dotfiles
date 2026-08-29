---
name: system-fix-index
version: 2.12.0
description: System_Fix 技能集入口——系统故障响应时先诊断再按症状加载对应修复文档，保证各检查 skill 之间的内联引用与加载顺序
triggers:
  - "系统故障"
  - "系统出问题"
  - "修电脑"
  - "检查系统"
  - "修复问题"
  - "报错排查"
  - "系统维护"
  - "System_Fix"
  - "ENOSPC"
  - "no space left"
  - "磁盘满"
  - "代理不工作"
  - "无法上网"
  - "输入法标点"
  - "PDF 报错"
  - "CMap"
  - "unpdf"
  - "subagent 异常"
  - "ENAMETOOLONG"
  - "subagent_wait 挂起"
  - "async 结果丢失"
  - "记忆索引"
  - "关机慢"
  - "同步配置"
  - "API key 恢复"
  - "401 invalid_api_key"
  - "tor浏览器"
  - "tor连不上"
  - "VLC"
  - "vlc 无法播放"
  - "hevc"
  - "h265"
  - "x265"
  - "无法解码"
  - "could not decode"
  - "雪花"
  - "花屏"
  - "画面错乱"
  - "硬解"
  - "mpv 播不了"
  - "播放器花屏"
  - "chrome 内存泄漏"
  - "chrome 内存泄露"
  - "chrome 吃内存"
  - "chrome 进程多"
  - "DidStartWorkerFail"
  - "chromedp"
  - "钱包备份"
  - "sparrow"
  - "备份验证"
  - "恢复演练"
  - "助记词备份"
  - "同步电子书"
  - "BOOKS 备份"
  - "电子书同步"
  - "死机"
  - "冻结"
  - "卡死"
  - "内存不足"
  - "OOM"
  - "out of memory"
  - "Purging GPU memory"
  - "Atomic commit failed"
  - "Page-flip failed"
  - "显示管线"
  - "PSR"
  - "subagent 温度异常"
  - "web_search 报错"
  - "provider 不可用"
  - "搜索无结果"
  - "记忆混乱"
  - "MEMORY_INDEX 过时"
  - "找不到历史上下文"
  - "ABRT"
  - "sway 崩溃"
  - "桌面回到登录界面"
  - "被踢回登录"
  - "合成器挂了"
  - "终端全没了"
  - "pi session 丢失"
  - "Device or resource busy"
  - "constrain_popup"
  - "输入法崩溃"
  - "fcitx5 崩溃"
  - "唤醒后花屏"
  - "合盖"
  - "屏幕不刷新"
  - "备份 dotfiles"
  - "git 仓库审计"
  - "ghostwriter 公式"
  - "Connection error"
  - "连接错误"
  - "pi 无法调用模型"
  - "web-search.json"
  - "pi 报错 Connection"
  - "数学显示源码"
  - "订阅失败"
  - "半角标点"
  - "bootstrap 卡 0%"
  - "中文路径 session"
  - "播放卡顿"
  - "显卡加速"
  - "SSH 连不上 Windows"
  - "KEXINIT"
  - "Connection reset"
  - "Windows OpenSSH"
  - "火绒拦截 SSH"
  - "Windows 脚本"
  - "没响应"
  - "bridge 反复重启"
  - "输出千篇一律"
  - "PDF 解析警告"
  - "关机报错"
  - "markdown 公式不显示"
  - "tor 浏览器用不了"
  - "tor 连不上"
  - "系统健康检查"
  - "蓝牙耳机连不上"
  - "蓝牙扫描不到"
  - "蓝牙配对失败"
  - "机场wifi"
  - "公共wifi"
  - "验证页弹不出"
  - "captive portal"
  - "公共网络加固"
inputs:
  - name: symptom
    description: 用户描述的症状/报错信息
    required: false
    default: "auto-detect"
tools:
  - read
  - bash
  - grep
  - find
  - subagent
---

# System_Fix 技能集入口

> 先诊断，再修复。本文件是 System_Fix 技能集的入口——被触发时立即执行故障响应流程，流程结束后下方目录供浏览参考。

---

## 立即执行

**当本 skill 被加载时，不要只是浏览——立即按以下步骤执行：**

### 步骤 1：确认症状并归类（必须）

将用户描述的症状归入以下五类之一，决定入口路径：

| 类别 | 症状特征 | 入口 |
|:---|:---|:---|
| **A. 未知/综合性问题** | "电脑卡"、"出问题了"、无明显报错 | → 步骤 2 全面诊断 |
| **B. 明确报错** | 有具体错误信息（ENOSPC、Segfault、报错弹窗等） | → 步骤 3 按症状匹配 |
| **C. pi-agent 自身故障** | subagent/web_search/PDF/记忆 相关报错 | → 按步骤 3 决策树匹配 pi-agent 层文档 |
| **D. 应用级故障** | 代理/输入法/特定应用不工作 | → 直接加载应用层文档 |
| **E. 维护任务** | 同步配置、清理、健康检查 | → 直接加载维护类文档 |

### 步骤 2：无明确症状 → 执行全面诊断

加载 `system_diagnostics_and_repair.md`，按 Phase 1-5 执行：并行采集 → 分析 → 修复 → 打包脚本 → 验证。

```bash
# 快速健康快照（30 秒内完成）
df -h && df -i && free -h
systemctl --failed && systemctl --user --failed 2>/dev/null
journalctl -p err -b --no-pager | tail -20
```

诊断中发现具体问题后，按下方决策树加载对应文档深入处理。

### 步骤 3：明确报错 → 按症状匹配文档

**匹配算法（自动路由的核心）**：

1. 将用户描述与 front matter triggers + 决策树关键词做**子串匹配**（大小写不敏感，
   中英文均可，如 "enametoolong" 命中 "ENAMETOOLONG"）
2. 同义词扩展：报错码原文（`name too long`、`no space left`、`out of memory`）、
   常见缩写（ABRT）、应用名（VLC、tor、sparrow）、空格变体（「tor连不上」vs
   「tor 连不上」）
3. **短串须语境确认**：长度 ≤4 的 trigger（如 tor、VLC、OOM）子串匹配会误命中
   （zoom/room 含 oom、history 含 tor）——须结合整句语境（内存报错/浏览器报错）
   才路由，纯子串命中但语境不符时不触发
4. 多命中时按决策树**从上到下顺序**执行；同一症状多文档命中（如死机↔chrome
   泄漏↔ENOSPC）按决策树注释的前置依赖顺序加载
5. 无命中 → 走 catch-all：`system_diagnostics_and_repair.md` 全面诊断
6. 命中后**必须 read 该 skill 全文并按其实质「执行流程」执行**——目录表只是索引，
   不是执行内容

### 步骤 4：修复完成后验证 + 沉淀

1. 验证修复（对应文档的验证章节）
2. **若无现成文档覆盖该故障**：将本次诊断→修复→验证过程沉淀为新文档（参照 `enospc-tmpfs-check.md` 的结构），并更新本 index 的目录、决策树与变更日志

---

## 工作流速查

```
系统故障/报错
  │
  ├─ 有明确报错？
  │    ├─ 是 → 症状匹配决策树 → 加载对应文档修复
  │    └─ 否 → system_diagnostics_and_repair 全面诊断
  │              └─ 发现具体问题 → 决策树深入
  │
  ├─ 修复（按文档 Phase 顺序）
  │    ├─ 系统层问题 → 杀进程/清日志/改配置
  │    └─ pi-agent 层问题 → 打补丁/重装/重启 daemon
  │
  ├─ 验证（文档验证章节 + 复现原场景）
  │
  └─ 沉淀（新故障 → 新文档 → 更新本 index）
```

---

## 以下为 System_Fix 技能集完整目录

> 中央注册表：每个文档均可独立加载；本目录说明分类、加载优先级和触发场景。

## 一、诊断入口（所有故障先过这里）

| # | Skill | 版本 | 用途 | 何时生效 |
|:--|:---|:---:|---|---|
| 1 | [system_diagnostics_and_repair.md](system_diagnostics_and_repair.md) | 1.1.0 | 全面系统诊断（硬件/内核/服务/日志），输出修复方案 | 无明确症状的故障、定期体检 |
| 2 | [system_fix.fish](system_fix.fish) | 1.0.0 | 可执行健康检查脚本（core dump/缓存/DNF/崩溃告警），`--dry`/`--auto` 模式 | 想自动跑一遍检查时 |

## 二、系统层（桌面/OS/资源）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 3 | [enospc-tmpfs-check.md](enospc-tmpfs-check.md) | 1.1.0 | ENOSPC/tmpfs 满排查：磁盘 vs 内存盘区分、换出页占配额、孤儿进程清理；先判别 ENOSPC ≠ ENAMETOOLONG | 任何 "no space left"、写入失败、tmpfs 满、ENAMETOOLONG 判别 |
| 3.5 | [freeze-oom-protection.md](freeze-oom-protection.md) | 1.4.0 | 死机/冻结/OOM thrash 排查（Purging GPU memory=内存压力信号）+ 泄漏源排查（chrome 元凶）+ 一键防护（earlyoom + oomd 加固 + 进程限流）+ PSR 显示管线风暴修复（Atomic commit failed 日均过万 → i915.enable_psr=0），脚本 [freeze-oom-protect.sh](freeze-oom-protect.sh) | 死机、冻结、卡死、没响应、内存不足、显示管线报错 |
| 3.6 | [chrome-leak-reaper.md](chrome-leak-reaper.md) | 1.1.0 | Chrome 内存泄漏排查与 chrome-reaper 维护：chromedp/桥实例/zygote 误杀（PPID 链）/restart 残留/profile 锁冲突 | chrome 吃内存、chrome 进程多、DidStartWorkerFail、bridge 反复重启 |
| 3.7 | [bluetooth-pairing-troubleshoot.md](bluetooth-pairing-troubleshoot.md) | 1.2.0 | 蓝牙设备连接排查：适配器判活、USB autosuspend（-16）修复、长扫描捕获配对窗口、非 tty 配对坑、默认输出切换、日常使用维护 | 蓝牙耳机连不上、扫描不到、配对失败、连上无声音 |
| 3.8 | [sway-resume-ebusy-ime-crash.md](sway-resume-ebusy-ime-crash.md) | 1.0.2 | sway 桌面两级故障链：①S3（合盖深睡）唤醒后 i915/KMS 卡死 → `Atomic commit failed: Device or resource busy` + Page-flip 风暴（重启 sway 无效，卡内核态；断根=改 HandleLidSwitch）②sway 1.10 IME 候选窗空指针 SIGSEGV（`constrain_popup`，上游 #8541 至今未修）→ 整会话连坐拆除；用本地 fork `~/sway` 补丁分支编译根治（PR #9206 仍 OPEN）；附桌面崩溃后的 pi 会话损失清点法。脚本 [sway-crash-diag.sh](sway-crash-diag.sh)（只读诊断）+ [sway-ime-fix-build.sh](sway-ime-fix-build.sh)（编译安装） | sway 崩溃、桌面回登录界面、终端全没了、合盖唤醒后屏幕不刷新、Device or resource busy、输入法候选窗崩溃 |
| 4 | [clash-verge-diagnose-and-fix.md](clash-verge-diagnose-and-fix.md) | 2.2.0 | Clash Verge Rev 代理不工作（模式/Profile/Hysteria2 DNS/订阅） | 代理失效、无法上网、订阅失败 |
| 4.5 | [public-wifi-security.md](public-wifi-security.md) | 1.0.0 | 公共 WiFi 三合一：验证页弹不出（Clash 代理劫持根因）、网络安全调查（加密/DNS/暴露面/证书/evil twin）、加固/恢复双脚本 [airport-harden.sh](airport-harden.sh) + [airport-restore.sh](airport-restore.sh)（入站 SSH/Samba/LLMNR） | 机场wifi、公共wifi、验证页弹不出、captive portal、公共网络加固 |
| 4.6 | [intranet-api-proxy-coexist.md](intranet-api-proxy-coexist.md) | 1.0.0 | 店内/局域网 API 与本地代理共存：内网域名被代理劫持、no_proxy 小写坑、clash Merge dns.hosts+prepend-rules 成对修复、LiteLLM 400 UnsupportedParamsError 参数剥离网关（含 Python 网关脚本） | 店内 API 连不上、内网 API 走代理、token.agi.bar、reasoning_effort 不支持、UnsupportedParamsError、LiteLLM 400 |
| 5 | [fcitx5_punctuation_fix.md](fcitx5_punctuation_fix.md) | 1.0.0 | fcitx5 中文标点问题（半角标点、顿号书名号打不出） | 输入法标点异常 |
| 6 | [cleanup_shutdown_issue.sh](cleanup_shutdown_issue.sh) | — (脚本) | 关机/重启清理脚本（systemd 守卫、ABRT 处理） | 关机慢、关机报错 |

## 三、pi-agent 层（pi 自身故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 7 | [subagent-temperature-fix.md](subagent-temperature-fix.md) | 2.15.0 | subagent temperature 配置链验证与重打补丁（21 检查点，双保险：传递链 + YAML 兜底） | subagent 输出温度异常 |
| 8 | [piagent-search-pipeline-fix.md](piagent-search-pipeline-fix.md) | 1.0.0 | web_search 配置/编码崩溃/provider 不可用/内容检索失败 | 搜索报错、provider 502 |
| 9 | [piagent-cmap-fix.md](piagent-cmap-fix.md) | 1.0.0 | 处理 PDF 时 CMap 字体警告（unpdf file:// 路径问题） | PDF 解析报 CMap 警告 |
| 10 | [memory-index-condense.md](memory-index-condense.md) | 1.3.1 | 记忆索引调查与浓缩（并行 reader 合成 MEMORY_INDEX.md） | 记忆膨胀、索引过时 |
| 10.5 | [pi-subagents-ENAMETOOLONG-fix.md](pi-subagents-ENAMETOOLONG-fix.md) | 3.1.0 | pi-subagents 结果索引 ENAMETOOLONG 独立修复 skill：判别路由、四层补丁 verify/apply（含完整重打代码）、死索引与空目录清扫、验证闭环 | subagent 报 ENAMETOOLONG、subagent_wait 挂起、async 结果丢失、中文路径 session、pi-subagents 升级后补丁重打 |
| 10.6 | [piagent-connection-error-fix.md](piagent-connection-error-fix.md) | 1.0.0 | pi-agent 模型调用 Connection error：首查 ~/.pi/web-search.json 完整性（fetch 包装器坏文件致全量抛错），次查代理重启后连接池失效，附快速网络排除与验证闭环 | pi 报 Connection error、连接错误、模型调用秒失败、web-search.json 损坏、pi 无法调用模型 |

## 四、维护类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 11 | [dotfiles-sync-and-audit.md](dotfiles-sync-and-audit.md) | 1.4.1 | 配置同步到 My_Dotfiles + Git 仓库审计（有上游不推送）；附录 B 专记 LLM API key 与 provider 配置实战（备份非真值源、key ↔ 端点配对矩阵含订阅 key 按区域绑定、配置文件安全编辑与取证） | 定期备份、配置审计、API key 空值恢复、401 判 key 死活、bl/pi/opencode provider 配置 |

## 五、应用层（桌面应用故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 12 | [ghostwriter-math-check-and-fix.md](ghostwriter-math-check-and-fix.md) | 1.1.0 | ghostwriter 预览数学公式不渲染三层自愈（pandoc wrapper / flatpak override / 导出器配置）+ 全链验证 | ghostwriter 公式不渲染、数学显示源码 |
| 13 | [tor-browser-check-and-fix.md](tor-browser-check-and-fix.md) | 1.2.1 | Tor 浏览器 bootstrap 失败检查+修复（IPv6 bridge / Socks5Proxy 禁，HTTPSProxy + IPv4 bridge 实测可用）+ tor 内核验证 | tor 无法连接、bootstrap 卡 0% |
| 14 | [video-playback-decode-fix.md](video-playback-decode-fix.md) | 2.1.1 | 视频播放/解码故障修复总集：A 无法解码（ffmpeg-free 禁解码器 → `dnf swap` 换完整 ffmpeg，脚本 [video-decode-ffmpeg-swap.sh](video-decode-ffmpeg-swap.sh)）；B 能播放但雪花/花屏（iHD 弃 Gen9 HEVC → i965 驱动 + VAAPI 硬解 + 环境注入，脚本 [video-playback-vaapi-fix.sh](video-playback-vaapi-fix.sh)）；覆盖 VLC/mpv/ffplay/GStreamer + iHD/i965 驱动层 | VLC/mpv 报 could not decode、播不了、雪花、花屏、画面错乱、播放卡顿、显卡加速异常 |

## 六、资产/数据备份类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 15 | [sparrow-wallet-backup-test.md](sparrow-wallet-backup-test.md) | 1.1.0 | Sparrow 钱包备份完整性体检：自动定位钱包文件、明文种子检查、rbw 条目存在性 + bw 附件哈希比对、GUI 恢复演练指引（脚本 [sparrow-wallet-backup-test.sh](sparrow-wallet-backup-test.sh)） | 钱包备份验证、恢复演练、备份完整性检查 |

## 七、Windows 远程排障

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 16 | [windows-scripting-and-ssh-debug.md](windows-scripting-and-ssh-debug.md) | 1.5.0 | Windows 端 .bat/.ps1 脚本编写规范自查（ASCII+CRLF/提权/内嵌 ps1 单文件交付/PS5.1 语法陷阱/BOM/bsdtar+xz/盘符/exe 取退出码/Transcript/依赖内容门禁/输出规范）+ OpenSSH 远程排障（黑盒三测试、排除链 0-10 步、TEMP 隔离判别器、ACL 拒绝访问定性、Defender 归责证据化、身份鉴定三件套、SYSTEM 任务兑底、周期看门狗自愈）；实战补充 34 条（含 books-sync 双机同步：sftp mkdir 已存在 Failure 无害、NTFS 大小写别名、mv 已存在目录=移入内部、冒号映射全角/%3A 共存、规则化排除；电子书备份日常运维指南：四步同步流程、差异分类语义、排除规则、快照策略、断连处理） | SSH 连不上 Windows、KEXINIT、Connection reset、Windows OpenSSH、火绒拦截 SSH、OpenSSH 拒绝访问、sshd 无法运行、Windows 脚本编写、同步电子书、BOOKS 备份、电子书同步 |

---

## 症状 → 文档决策树

```
「no space left / ENOSPC / 磁盘满」
  └─ enospc-tmpfs-check.md ← 先看 df -h 全部挂载点，别只看根盘

「死机 / 冻结 / 卡死 / 没响应 / 内存不足」
  └─ freeze-oom-protection.md ← 先看 journalctl -b -1 尾部：Purging GPU memory = 内存 thrash；装 earlyoom + oomd 加固（⚠️ earlyoom 须 `-m 8 -s 100` 纯内存阈值消除 zram 盲区，**严禁加 -M/-S（单位是 KiB 且覆盖 -m/-s，曾致 0% 阈值哑火两次死机）**，改完必须 journalctl -u earlyoom 验证 8.00%）；泄漏源先查 chrome；Atomic commit failed 日均过万 → i915.enable_psr=0；OOM Mem-Info 见 shmem 数 GB + Free swap 0 = shmem 尖峰（memfd/tmpfs 瞬时爆量，earlyoom 1s 轮询可被绕过，进程 rss_shmem 全 0 无法归因），日常监控 Shmem>4G 告警

「sway 崩溃 / 桌面回到登录界面 / 终端和 GUI 应用全没了 / 合盖唤醒后屏幕不刷新」
  └─ sway-resume-ebusy-ime-crash.md ← 先 `bash sway-crash-diag.sh` 一把出报告。判据顺序：
     ①崩溃窗口内 oom/Purging 关键字 = 0（否则转 freeze-oom-protection.md）
     ②coredumpctl 里 sway 与一批 GUI 客户端同秒 core = 合成器之死，客户端属连坐（勿计入各自 bug）
     ③回溯帧 #0 = constrain_popup → 上游 #8541 IME 空指针，用 ~/sway fork 的 fix/constrain-popup-null-container
       打补丁编译（`sway-ime-fix-build.sh --check` 已实测补丁在 upstream/v1.10 上干净应用；
       ⚠️ wlroots 硬绑定：v1.10→0.18 / v1.11→0.19 / v1.12→0.20 / master→0.21，Fedora 42 只到 0.19，勿照抄 master）
     ④「Atomic commit failed: Device or resource busy」与每次 Lid opened/suspend exit 1:1 对齐 = S3 唤醒后遗症，
       与 freeze-oom-protection 里的老 PSR 风暴（`-16`/日均数十万、已由 i915.enable_psr=0 压到 3 万）是两种变体：
       **先看 /proc/cmdline 是否已含 enable_psr=0，已含就不要再走 PSR 分支**
     ⑤恢复三档：DPMS 循环 → 重绑 i915（stop gdm + unbind/bind）→ 重启；断根 = HandleLidSwitch=lock（合盖不睡）
     ⑥事后必做：`sway-crash-diag.sh --sessions` 清点被砍的 pi 会话（pi jsonl 无正常退出标记，分「确证被杀/待回忆/已恢复」三档）；
       长活 pi 会话改放 tmux + systemd-run --user，否则合成器一死全灭

「chrome 内存泄漏 / chrome 吃内存 / chrome 进程多 / DidStartWorkerFail / bridge 反复重启」
  └─ chrome-leak-reaper.md ← 进程画像 + reaper 日志 + scope/PPID 链判定 + v3 修复；致死机/ENOSPC 时配合 freeze-oom-protection / enospc-tmpfs-check

「代理不工作 / 无法上网 / 订阅失败」
  └─ clash-verge-diagnose-and-fix.md

「店内 API 连不上 / 内网 API 走代理 / token.agi.bar / UnsupportedParamsError / LiteLLM 400」
  └─ intranet-api-proxy-coexist.md ← 先测直连 vs 代理（对比即知劫持）→ DNS 定位内网 IP → no_proxy 小写+大写同步设 → Merge dns.hosts+prepend-rules 成对加 → 401 查 key（sk- 前缀）→ 400 起本地剥离网关（SSE chunked 转发）

「机场wifi / 公共wifi / 验证页弹不出 / captive portal / 公共网络加固」
  └─ public-wifi-security.md ← 先查 Clash 代理（7897）是否劫持浏览器流量；调查四步法；加固/恢复脚本 airport-harden.sh / airport-restore.sh（出站训练 SSH 不受影响）

「输入法标点打不出 / 半角标点」
  └─ fcitx5_punctuation_fix.md

「subagent 温度异常 / 输出千篇一律」
  └─ subagent-temperature-fix.md

「web_search 报错 / provider 不可用 / 搜索无结果」
  └─ piagent-search-pipeline-fix.md

「PDF 解析警告 / CMap / unpdf」
  └─ piagent-cmap-fix.md

「记忆混乱 / MEMORY_INDEX 过时 / 找不到历史上下文」
  └─ memory-index-condense.md

「subagent 报 ENAMETOOLONG / subagent_wait 挂起 / async 结果丢失 / 中文路径 session」
  └─ pi-subagents-ENAMETOOLONG-fix.md ← 独立 skill：判别→核查补丁→清扫→验证；补丁在 ~/.pi/agent/npm，升级覆盖后需重打；修复后须重启 pi 主进程

「pi 报 Connection error / 连接错误 / 模型调用秒失败 / web-search.json 损坏」
  └─ piagent-connection-error-fix.md ← 先验 web-search.json（python3 json.load），勿先重启代理；坏文件修好即时生效，无需重启 pi；代理刚重启过且 JSON 正常则重启 pi；errorMessage 含 "undici dispatcher" 系版本不匹配亦重启 pi

「关机慢 / 关机报错 / ABRT」
  └─ cleanup_shutdown_issue.sh

「同步配置 / 备份 dotfiles / git 仓库审计」
  └─ dotfiles-sync-and-audit.md

「key 不见了 / API key 空值 / 401 invalid_api_key / 给工具配 LLM provider」
  └─ dotfiles-sync-and-audit.md 附录 B ← 先查真值源（auth.json/secrets，备份是占位符）→ curl 实测 key ↔ 端点矩阵（401 勿判死）→ 改配置用整行锚点 + 回读；取证罪命令用 ~/.pi/agent/sessions

「ghostwriter 公式不渲染 / 数学显示源码 / markdown 公式不显示」
  └─ ghostwriter-math-check-and-fix.md

「tor 连不上 / tor 浏览器用不了 / bootstrap 卡 0%」
  └─ tor-browser-check-and-fix.md ← 须先确认 clash-verge 代理正常

「VLC 无法播放 / could not decode / hevc / h265 / x265 播不了」
  └─ video-playback-decode-fix.md ← 症状 A：rpm -qa 有 ffmpeg-free → dnf swap 换完整 ffmpeg

「VLC 能播但雪花 / 花屏 / 画面错乱 / 播放卡顿」
  └─ video-playback-decode-fix.md ← 症状 B：vainfo 无 HEVC + VLC CPU 150%+ → i965 驱动 + VAAPI 硬解（先排除文件损坏：ffmpeg CLI 全片解码 0 错误）

「钱包备份 / 备份验证 / sparrow / 恢复演练 / 助记词备份」
  └─ sparrow-wallet-backup-test.md ← 先解锁 rbw；bw 附件比对需解锁 bw 后重跑；哈希不一致=备份过期需重新上传

「SSH 连不上 Windows / KEXINIT / Connection reset / Windows OpenSSH / 火绒拦截 SSH」
  └─ windows-scripting-and-ssh-debug.md ← 黑盒三测试定位 → 排除链 0-10 步（存在性 1060→杀软→防火墙→密钥权限→密钥内容→重建→算法→前台 vs 服务→重启→重注册→内置）；拒绝访问用 TEMP 隔离判别器分路径拦截/内容拦截；/inheritance:r 只用于密钥类；身份鉴定用大小+SHA256+试运行三件套

「同步电子书 / BOOKS 备份 / 电子书同步」
  └─ windows-scripting-and-ssh-debug.md ← 先 win-check.sh 体检链路；断连等看门狗 5 分钟（-w 最长 6 分钟），不恢复则 Windows 侧双击 install-keepalive.bat；通后 books-sync.py scan → all → 复扫归零；快照语义=被推覆盖的 Windows 旧版在 backup/linux-YYYYMMDD；拉方向无自动快照

「想自动跑系统健康检查」
  └─ system_fix.fish ← 只读检查，先 --dry

「蓝牙耳机连不上 / 蓝牙扫描不到 / 蓝牙配对失败 / 连上无声音」
  └─ bluetooth-pairing-troubleshoot.md ← 先适配器判活（服务/rfkill/控制器）→ USB autosuspend（-16 元凶，Intel 高发，修复后须重启彻底生效）→ 长扫描 60-100s 捕获配对窗口（短扫描必漏）→ 配对连接（非 tty 事件刷屏坑）→ 默认输出切换（连接成功 ≠ 声音从耳机出）

「以上都不是 / 综合症状 / 说不清楚」
  └─ system_diagnostics_and_repair.md（全面诊断）
       └─ 发现具体问题 → 回到上方对应文档
```

## 文档间交叉引用速查

| 当前文档 | 应参阅 | 原因 |
|:---|:---|:---|
| `system_diagnostics_and_repair.md` Phase 1.2 硬件资源 | `enospc-tmpfs-check.md` | 发现内存/swap 压力或 tmpfs 问题时用 ENOSPC 流程深挖 |
| `system_diagnostics_and_repair.md` Phase 1.2 硬件资源 | `freeze-oom-protection.md` | 发现内存压力/死机/冻结时用 OOM thrash 流程深挖并加固 |
| `freeze-oom-protection.md` 死机元凶排查 | `chrome-leak-reaper.md` | chrome 泄漏是死机/OOM 头号元凶，先修泄漏再谈防护 |
| `enospc-tmpfs-check.md` 预防/注意事项 | `chrome-leak-reaper.md` | headless 浏览器泄漏同源（chromedp/桥/scope 误杀），实例归属判定看 PPID 链 |
| `chrome-leak-reaper.md` | `freeze-oom-protection.md` / `enospc-tmpfs-check.md` | chrome 泄漏引爆死机或 tmpfs/swap 压力时互相配合 |
| `sway-resume-ebusy-ime-crash.md` | `freeze-oom-protection.md` | 「Atomic commit failed」有两种病因：PSR 变体走该文档，`Device or resource busy` 变体走 sway 文档；先查 `/proc/cmdline` 是否已含 `i915.enable_psr=0` 分流 |
| `freeze-oom-protection.md` | `sway-resume-ebusy-ime-crash.md` | 死机/掉登录先分流：崩溃窗口 0 条 oom 关键字且 coredumpctl 里 sway 与 GUI 客户端同秒 core = 合成器崩溃而非 OOM |
| `sway-resume-ebusy-ime-crash.md` Phase 5 | `pi-subagents-ENAMETOOLONG-fix.md` | 桌面崩溃后 async 子代理 run 会被腰斩（run-0/session.jsonl 末条非 final）；结果索引与丢失判定参见该文档 |
| `sway-resume-ebusy-ime-crash.md` 坑#7 | `enospc-tmpfs-check.md` | 合成器崩后旧 session scope 变 abandoned 挂孤儿 daemon，占内存/可能撑爆 tmpfs 配额 |
| `sway-resume-ebusy-ime-crash.md` Phase 4 | `dotfiles-sync-and-audit.md` | sway 配置（kill 绑定加 `fcitx5-remote -c`、`exec` 行的 `;` 需引号）改完需同步 My_Dotfiles 副本 |
| `enospc-tmpfs-check.md` Phase 4.2 | `cleanup_shutdown_issue.sh` | 清理任务可复用其 systemd 守卫模式 |
| `enospc-tmpfs-check.md` 预防 | `piagent-search-pipeline-fix.md` | opencli/chromedp 泄漏是搜索管道与 tmpfs 满的共同隐患 |
| `enospc-tmpfs-check.md` 先判别 | `pi-subagents-ENAMETOOLONG-fix.md` | /tmp 下 `name too long`（路径组件 >255B）不是 ENOSPC，路由到该文档 |
| `ghostwriter-math-check-and-fix.md` 第三层 | `dotfiles-sync-and-audit.md` | 配置修正后需同步 My_Dotfiles 备份副本 |
| `clash-verge-diagnose-and-fix.md` | `system_diagnostics_and_repair.md` Phase 1.5 网络 | 网络层诊断先跑通用检查再深入 Clash |
| `clash-verge-diagnose-and-fix.md` | `public-wifi-security.md` | 验证页弹不出/公共网络场景同源——代理劫持浏览器流量时先查 Clash 再查门户 |
| `intranet-api-proxy-coexist.md` 前置 | `clash-verge-diagnose-and-fix.md` | 内网 API 被代理劫持属 Clash 规则/DNS 行为，代理整体故障时先修 Clash 再谈共存 |
| `intranet-api-proxy-coexist.md` 公共场景 | `public-wifi-security.md` | 店内/机场公共 Wi-Fi 对 UDP QoS 会影响 Hysteria2 节点稳定性（症状：间歇性 context deadline exceeded） |
| `piagent-connection-error-fix.md` 网络排除 | `clash-verge-diagnose-and-fix.md` | Connection error 排查中代理整体失效/Profile 漂移时先修 Clash 再谈 pi |
| `piagent-connection-error-fix.md` NO_PROXY 加固 | `intranet-api-proxy-coexist.md` | no_proxy 大小写双设、LLM 域名直连与内网 API 共存同源 |
| `system_diagnostics_and_repair.md` Phase 1.5 网络 | `public-wifi-security.md` | 公共网络场景安全调查深入（加密/DNS/暴露面/证书） |
| `tor-browser-check-and-fix.md` 前置 | `clash-verge-diagnose-and-fix.md` | Tor 经本地代理引导，代理失效时先修 Clash 再修 Tor |
| `video-playback-decode-fix.md` | `system_diagnostics_and_repair.md` | 播放类故障先查系统 ffmpeg 解码能力，再深入播放器自身；GPU 无硬件加速时驱动安装/VAAPI 能力对照收拢于 video skill |
| `dotfiles-sync-and-audit.md` | `memory-index-condense.md` | 两者都涉及 pi-agent 配置文件的备份/维护 |
| `dotfiles-sync-and-audit.md` 附录 B.6 | `intranet-api-proxy-coexist.md` | 同属 LLM API 链路：附录 B 管 key/端点/provider 配置与恢复，该 skill 管代理劫持与 no_proxy 大小写 |
| `dotfiles-sync-and-audit.md` 附录 B.2 | `piagent-connection-error-fix.md` | 两者根因皆为「配置文件被并发改坏且无报错」，前者防于写时（整行锚点 + 回读），后者防于读时（JSON 完整性先验） |
| `dotfiles-sync-and-audit.md` 附录 B.1 | `sparrow-wallet-backup-test.md` | 同为「备份不等于可恢复」主题：备份需验证、真值需另库 |
| `bluetooth-pairing-troubleshoot.md` | `system_diagnostics_and_repair.md` 1.8 节 | 适配器判活失败时回到全面诊断的蓝牙节；HCI -16 修复命令两处一致 |
| 任何 pi-agent 层文档修复后 | `memory-index-condense.md` | 修复后如记忆/索引涉及，需重新浓缩 |
| `windows-scripting-and-ssh-debug.md` 排障产出 | `win-ssh-setup` 工具包（~/Downloads/win-ssh-setup） | Windows 端脚本均按该 skill 规范编写：fix-sshd-service.bat（阶梯修复）/ diag-sshd3.bat（前台调试）/ install-rsync.bat（MSYS2+rsync） |

## 维护约定

- 新增文档后**必须更新本文件**：在对应分类下添加条目 + 更新决策树 + 更新交叉引用表
- 文档版本升级（front matter `version` 字段）时同步更新目录表版本号
- 文档退役时：保留条目但标注 `~~deprecated~~` 与替代者，不直接删除
- 沉淀新故障经验的模板：参照 `enospc-tmpfs-check.md`（front matter + 核心认知 + Phase 1-5 + 预防 + 注意事项）

### 路由完整性自检（每次新增/更新文档后必须执行）

自动路由依赖「triggers → 决策树 → 目录表」三者一致，逐项核对：

- [ ] 每个文档在目录表有行（编号/版本/用途/触发场景）
- [ ] 每个可修复文档在决策树有分支（含加载顺序/前置依赖注释）
- [ ] 每个决策树分支的关键症状词都在 front matter triggers 中（用户说得出的话
      必须能触发本入口）
- [ ] 目录表版本与文档 front matter version 一致
- [ ] 变更日志已追加、末尾「最后更新」已同步
- [ ] 全部文档 front matter 严格 YAML 解析通过（命令见 skill_creator.md 步骤 4：python3 yaml.safe_load）

---

## 变更日志

### 2.12.0 (2026-08-29)
- 更新：sway-resume-ebusy-ime-crash.md **1.0.0 → 1.0.2**（1.0.1：坑 #11 meson 双版本；1.0.2：新增附录「配套脚本编程问题自审」——A 诊断脚本 7 条 / B 构建脚本 5 条（含用户实测踩中的 sudo $HOME、meson 版本不匹配）/ C 流程 3 条，全部已修复；`sway-ime-fix-build.sh` 同步升级为 sudo 安全版：REAL_HOME 解析 + root 自动降权 + PYTHONPATH 注入重放同一 meson + EUID==0 直装）
- 新增：系统层 3.8 — `sway-resume-ebusy-ime-crash.md` 1.0.0（2026-08-29 13:15:49 实战：sway `constrain_popup` SIGSEGV + 12:26 唤醒后 EBUSY 风暴）：
  - 一级「S3 合盖唤醒后 i915/KMS 卡死」：`Atomic commit failed: Device or resource busy` 与每次 Lid opened/suspend exit **1:1 对齐**（近 7 天 15.3 万条全同变体）；重启 sway 无效（实测新 sway 首帧即继续风暴）→ 三档恢复（DPMS 循环 / 重绑 i915 / 重启）+ 断根 `HandleLidSwitch=lock`（本机 /etc/systemd/logind.conf 不存在全默认，合盖即深睡）
  - 二级「IME 候选窗空指针」：帧 `#0 constrain_popup`（sway/input/text_input.c:139，`view->container` 未判 NULL），上游 [swaywm/sway#8541](https://github.com/swaywm/sway/issues/8541) 仍 OPEN、v1.10/1.11/1.12/master 全部未修；**本地 fork `~/sway` 补丁分支 `fix/constrain-popup-null-container`（3024142f，+3/−0）在 upstream/v1.10 上实测干净应用**，已提 PR [swaywm/sway#9206](https://github.com/swaywm/sway/pull/9206)（仍 OPEN）；wlroots 硬绑定 v1.10→0.18 / v1.11→0.19 / v1.12→0.20 / master→0.21，Fedora 42 无 0.20/0.21 包 → 目标选 v1.10；编译安装脚本 `sway-ime-fix-build.sh`（check/deps/build/install/verify/revert）
  - 级联清点：崩溃后 pi session 损失判定法（jsonl 无正常退出标记 → 分「确证被杀=崩前 6s 内写盘 / 待回忆=崩前停笔且 cwd 无活进程 / 已恢复=崩后仍在写」三档）+ 子代理 run 腰斩判定（末条非 final 即丢）；本次确证 1 个（LLM-api-check 01a04bf0）、腰斩 4 个（属 01a04bdc，ultrabrain×3+hephaestus×1，已重放）
  - 脚本 `sway-crash-diag.sh`：只读六段诊断（崩溃定位/排除 OOM/回溯签名分类/风暴-唤醒对齐/遗物/会话清点），已实测全流程跑通
- 新增：决策树分支「sway 崩溃 / 桌面回到登录界面 / 终端和 GUI 应用全没了 / 合盖唤醒后屏幕不刷新」+ 与 freeze-oom-protection 的「Atomic commit failed」两病因分流注释（PSR 变体 vs EBUSY 变体，先查 /proc/cmdline）
- 新增：交叉引用 5 条（sway↔freeze-oom 双向分流、Phase 5↔pi-subagents-ENAMETOOLONG、坑#7↔enospc-tmpfs、Phase 4↔dotfiles-sync）
- 新增：triggers 13 个（sway 崩溃、桌面回到登录界面、被踢回登录、合成器挂了、终端全没了、pi session 丢失、Device or resource busy、constrain_popup、输入法崩溃、fcitx5 崩溃、唤醒后花屏、合盖、屏幕不刷新）

### 2.11.1 (2026-08-29)
- 更新：dotfiles-sync-and-audit.md 1.4.0 → **1.4.1**（修正 B.4：`sk-sp-` Token Plan key 实测已激活，北京端点 200（chat+models 双验）、同 key 新加坡端点仍 401 → 钉死「订阅 key 按区域绑定」；01:13/01:30 两轮全 401 系订阅激活延迟，非 key 错误；新增铁律二「凭据结论带时间戳、与用户对表」+ pi 认证源链 env→auth.json + B.8 第 5 条）
- 背景：2026-08-29 02:0x 用户纠正「Token Plan 一直在用、key 绝对无误」，复测证实同一 key 同端点由 401 转 200——激活延迟与区域绑定两种 401 良性质因同时现身

### 2.11.0 (2026-08-29)
- 更新：dotfiles-sync-and-audit.md 1.3.0 → **1.4.0**（新增附录 B「LLM API key 与 provider 配置实战」8 节：备份非真值源与真值库四序、前缀锚点插入吞行致 key 静默丢失、会话日志取证法、阿里云 `sk-sp-`/`sk-ws-` key ↔ 端点配对矩阵、`fish -c` 非交互守卫假阴性、bl `--llm-provider` 空壳 flag、最小改动纪律与 diff 自证、四条思想经验）
- 新增：决策树分支「key 不见了 / API key 空值 / 401 invalid_api_key / 给工具配 LLM provider」→ 附录 B
- 新增：交叉引用 3 条（附录 B.6 ↔ intranet-api-proxy-coexist、B.2 ↔ piagent-connection-error-fix、B.1 ↔ sparrow-wallet-backup-test）
- 新增：triggers「API key 恢复」「401 invalid_api_key」
- 背景：2026-08-29 为 bl 接 qwen3.8-flash 时发现本机 DEEPSEEK_API_KEY 已被另一会话的 python 前锚点插入静默清空，全程取证 + 恢复，兼得 key/端点矩阵与 bl provider 配置语义

### 2.10.0 (2026-08-27)
- 新增：pi-agent 层「Connection error」修复 skill — [piagent-connection-error-fix.md](piagent-connection-error-fix.md)（web-search.json 并发写坏根因 + fetch 包装器机制 + 快速网络排除 + 连接池排查 + 验证闭环）
- 新增：决策树分支「pi 报 Connection error / 连接错误 / 模型调用秒失败」+ 交叉引用「Connection error → clash-verge 诊断 / intranet-api-proxy NO_PROXY 加固」
- 新增：triggers「Connection error」「连接错误」「pi 无法调用模型」「web-search.json」「pi 报错 Connection」

### 2.9.1 (2026-08-26)
- 更新：freeze-oom-protection.md 1.3.0 → **1.4.0**（08-26 23:42 全局 OOM 实战：shmem 11.5GB
  瞬时尖峰 + zram 8G 填满（Free swap 0）→ 连杀 wezterm/wireplumber/portal/tor；earlyoom
  8%/100% 配置正确但被 <1s 尖峰绕过全程未出手；元凶进程 rss_shmem 全 0 事后无法归因；
  新增 shmem 尖峰判定法 + 防护要点（Shmem>4G 告警、pi -r 防叠加、大操作前后查 Shmem））
- 验证：coredump.conf 128M 上限已生效（08-17 遗留完成）；i915.enable_psr=0 持久化生效
  （Atomic commit failed 日均 50 万 → 3.1 万，部分生效未归零）；earlyoom 阈值 8.00% ✓

### 2.9.0 (2026-08-25)
- 新增：系统层 4.6 — `intranet-api-proxy-coexist.md` 1.0.0（2026-08-25 AGI Bar 店内实测沉淀：内网 API 与本地代理共存四层冲突——路由劫持/DNS 盲区（Merge dns.hosts+prepend-rules 成对修复）/no_proxy 小写优先坑/LiteLLM 400 参数剥离网关（含 Python 网关脚本，SSE chunked 转发））
- 新增：决策树分支「店内 API 连不上 / 内网 API 走代理 / UnsupportedParamsError」+ triggers 7 个
- 新增：交叉引用 2 条（intranet-api-proxy-coexist ↔ clash-verge-diagnose-and-fix、public-wifi-security）

- 更新：windows-scripting-and-ssh-debug.md 1.4.1 → 1.5.0（新增实战补充 5「BOOKS 电子书双机同步日常运维指南」：四步同步流程/差异分类语义/排除规则/快照策略/断连处理；triggers 新增 同步电子书、BOOKS 备份、电子书同步）
- 新增：决策树分支「同步电子书 / BOOKS 备份 / 电子书同步」+ triggers 3 个

### 2.8.0 (2026-08-24)
- 更新：freeze-oom-protection.md 1.2.0 → **1.3.0**（08-24 22:17 OOM 重启实战：earlyoom
  -M/-S 单位 KiB 坑实锤——08-18 配置 `-m 8 -M 5 -s 100 -S 100` 实际 0% 阈值全程哑火，
  两次死机都没出手；修正为 `-m 8 -s 100`；新增强制验证命令
  `journalctl -u earlyoom -b 0 | grep SIGTERM` 必须 8.00%/100.00%）
- 新增：决策树死机分支注释（严禁 -M/-S + 验证命令）
- 案例：08-24 OOM（6 天 uptime 渐进泄漏：白天 3 次低压 1.7G→663MB→1.25G → 22:17:30
  全局 OOM 连杀 8 进程 → 22:18:40 电源键自救 → 22:20 重启；oomd 出手太晚；PSR 本次重启才生效）

### 2.7.1 (2026-08-22)
- 更新：bluetooth-pairing-troubleshoot.md 1.1.0 → **1.2.0**（新增「日常使用与维护」章节：自动重连、电量查看 bluetoothctl info Battery Percentage、A2DP AAC 音质/通话降质、多设备切换、blueman GUI）

### 2.7.0 (2026-08-22)
- 新增：系统层 3.7 — `bluetooth-pairing-troubleshoot.md` 1.0.0 → **1.1.0**（2026-08-22 华为 FreeArc 配对实战：适配器正常但 12-20 秒短扫描 4 次全空、100 秒长扫描捕获；Intel 蓝牙 USB autosuspend（-16 EBUSY）修复；随机 MAC 设备以名字为线索；非 tty 下 bluetoothctl 事件刷屏对策；步骤 7 补默认输出切换——连接成功 ≠ 声音从耳机出，set-default-sink + move-sink-input）
- 更新：system_diagnostics_and_repair.md 1.1.0 → **1.2.0**（1.8 蓝牙节扩充 USB autosuspend 检查 + 交叉引用新 skill；Phase 3/5 蓝牙注释补充）
- 新增：triggers「蓝牙耳机连不上」「蓝牙扫描不到」「蓝牙配对失败」+ 决策树蓝牙分支 + 交叉引用 1 条

### 2.6.0 (2026-08-22)
- 新增：系统层 — `public-wifi-security.md` 1.0.0 + 脚本 `airport-harden.sh` / `airport-restore.sh`（2026-08-22 香港机场实战：验证页弹不出根因=Clash 代理劫持浏览器流量；安全调查四步法；加固=入站 SSH/Samba/LLMNR，出站训练 SSH 不受影响；恢复脚本含白名单 rich rule 清理）
- 新增：triggers「机场wifi」「公共wifi」「验证页弹不出」「captive portal」「公共网络加固」
- 新增：决策树分支 + 交叉引用 2 条（clash-verge ↔ public-wifi-security 同源；system_diagnostics 网络层 → 公共网络调查）

### 2.5.0 (2026-08-18)
- 更新：freeze-oom-protection.md 1.1.0 → **1.2.0**（基于 08-18 17:48 第二次死机实战：earlyoom zram 盲区——Fedora 默认内存+swap 双条件在 zram 掩护下永不触发，须 -s 100 -S 100 退化为纯内存阈值；oomd 阈值 80%→60%；新增 PSR 显示管线风暴节——Atomic commit failed 日均 1.2-3.5 万次 = Kaby Lake i915 PSR bug，i915.enable_psr=0 修复 + BLS 条目验证；Phase 1 加 Purging GPU memory 页数对比判读）
- 新增：triggers「Atomic commit failed」「Page-flip failed」「显示管线」「PSR」
- 新增：决策树死机分支注释（earlyoom zram 盲区 + PSR 修复）
- 新增：目录表 3.5 行用途更新（PSR 修复 + 显示管线触发场景）

### 2.4.0 (2026-08-17)
- 更新：windows-scripting-and-ssh-debug.md 1.2.0 → 1.3.0（win-ssh-setup 第 11-13 轮：diag v2 定位服务未注册真相、v5 误诊复盘、v6 ACL 判别）
- 新增：编写规范 M/N/O（exe 试运行取退出码、修复脚本 Start-Transcript、依赖搜索路径∪用户指令路径+SHA256 内容门禁）；排除链 step 0 存在性 + TEMP 隔离试跑判别器；实战补充 2（9-16 条：吞错组合、空 FileVersion 误诊、A/B 试跑救援源、/inheritance:r 适用边界、Defender 归责证据化、版本门禁 fail-closed、自带 scp 通道、审计自己脚本 bug）

### 2.3.1 (2026-08-16)
- 修复：YAML 解析失败 3 文件（dotfiles-sync-and-audit 1.2.1 / tor-browser-check-and-fix 1.2.1 / video-playback-decode-fix 2.1.1，inputs description 裸半角冒号加引号）；tor-browser front matter 版本补齐（1.0.0→1.2.1，与变更日志顶条脱节）
- 新增：维护检查清单「front matter 严格 YAML 解析」条目（防复发，规范见 skill_creator.md 检查清单 G 组）

### 2.3.0 (2026-08-16)
- 新增：第七类「Windows 远程排障」— `windows-scripting-and-ssh-debug.md` 1.0.0（win-ssh-setup 实战沉淀：.bat/.ps1 编写规范 11 项、黑盒三测试、KEXINIT reset 排除链 10 步、前台 vs 服务差异定位、脚本化协作闭环）
- 新增：决策树分支「SSH 连不上 Windows / KEXINIT / Connection reset」+ 交叉引用 1 条 + triggers 5 个
- 新增：决策树注释——前台 -ddd 正常 + 服务 reset = 服务上下文问题，重启优先，勿反复重试触发火绒拉黑
- 更新：windows-scripting-and-ssh-debug.md 1.1.0 → 1.2.0（新增输出消息规范，ASD-STE100 脚本输出文本，见根目录 technical-writing-standard.md 第 7 节）
- 更新：system_diagnostics_and_repair.md 1.0.0 → 1.1.0（新增脚本输出文本规范，ASD-STE100）
- 修复：目录表 5 行版本漂移同步（chrome-leak-reaper 1.1.0、dotfiles-sync-and-audit 1.2.0、memory-index-condense 1.3.1、sparrow-wallet-backup-test 1.1.0、subagent-temperature-fix 2.15.0）

### 2.2.0 (2026-08-16)
- 修复：裸词 "OOM" trigger 子串误命中风险（zoom/room 等常见英文词均含 oom）→ 保留 "OOM"（内核 OOM 报错原文）并新增 "out of memory" 短语，匹配算法新增短串语境确认规则
- 新增：决策树 9 个缺失分支词 triggers（没响应/bridge 反复重启/输出千篇一律/PDF 解析警告/关机报错/markdown 公式不显示/tor 浏览器用不了/tor 连不上空格变体/系统健康检查）
- 精进：步骤 1 C 类「直接加载」→「按步骤 3 决策树匹配」
- 修正：2.0.0 变更日志条目时代错乱（2026-08-15 条目误述 08-16 的 2.1.0 三波+第 4 层内容）
- 更新：`pi-subagents-ENAMETOOLONG-fix.md` 3.0.0 → **3.1.0**（第 3/4 层补丁完整代码、清扫命令去 npx 依赖与硬编码 uid）

### 2.1.0 (2026-08-16)
- 重构：`pi-subagents-ENAMETOOLONG-fix.md` 2.1.0 → **3.0.0**（独立可执行 skill：任务目标/执行流程 6 步/输出格式/注意事项，聚合散落修复知识）
- 更新：`enospc-tmpfs-check.md` 1.0.0 → **1.1.0**（先判别 ENOSPC ≠ ENAMETOOLONG 交叉路由）
- 修复：triggers 与决策树不一致——补全缺失症状词（死机/冻结/OOM、web_search 报错、记忆混乱、ghostwriter、ABRT、半角标点、订阅失败、bootstrap 卡 0%、中文路径 session、播放卡顿/显卡加速等 25 个）
- 新增：步骤 3 匹配算法（子串/同义词/多命中顺序/未命中 catch-all/命中后须读全文执行）
- 新增：路由完整性自检清单（triggers ↔ 决策树 ↔ 目录表三者一致）
- 新增：决策树分支「想自动跑系统健康检查」→ system_fix.fish

### 2.0.0 (2026-08-15)
- 新增：pi-agent 层文档 `pi-subagents-ENAMETOOLONG-fix.md` **2.0.0**（encodeSegment 截断+稳定哈希、existingResultFile ENAMETOOLONG 静默容错、migrateLegacyResultSegments 启动期自愈迁移 + 直接目录扫描兜底；中文路径 session 触发）
- 新增：triggers「ENAMETOOLONG」「subagent_wait 挂起」「async 结果丢失」
- 新增：决策树分支「subagent 报 ENAMETOOLONG / subagent_wait 挂起」

### 1.8.0 (2026-08-10)
- 新增：系统层 — `chrome-leak-reaper.md`（Chrome 内存泄漏排查 + chrome-reaper v3 维护：chromedp/桥实例/zygote 误杀 PPID 链修复/restart 残留/profile 锁冲突，基于 2026-08-10 第三次泄漏实战）
- 更新：`freeze-oom-protection.md` 1.0.0 → **1.1.0**（新增死机元凶排查：chrome 泄漏排查命令 + 交叉引用；front matter triggers「内存被吃光」）
- 更新：`enospc-tmpfs-check.md` 预防/注意事项（补充 chrome-leak-reaper 交叉引用 + PPID 链判定注意事项）
- 新增：决策树分支「chrome 内存泄漏 / chrome 吃内存 / DidStartWorkerFail」+ 交叉引用 3 条 + triggers 6 个
- 修正：front matter version 滞后（1.4.0 → 1.8.0 对齐变更日志）

### 1.7.0 (2026-08-10)
- 新增：系统层 — `freeze-oom-protection.md` + 脚本 `freeze-oom-protect.sh`（2026-08-10 20:09 死机实战：内存 thrash 冻结，Purging GPU memory 判定 + earlyoom/oomd 三层防线）
- 新增：决策树分支「死机 / 冻结 / 卡死 / 内存不足」+ 交叉引用「诊断发现内存压力 → freeze-oom-protection」
- 新增：triggers「死机」「冻结」「卡死」「freeze」「内存不足」「OOM」「Purging GPU memory」

### 1.6.0 (2026-08-10)
- 改名：`vlc-hevc-decode-fix.md` → **`video-playback-decode-fix.md`**（2.0.0 → **2.1.0**，universal 化）；脚本改名 `video-decode-ffmpeg-swap.sh`、`video-playback-vaapi-fix.sh`
- 更新：目录条目描述（覆盖 VLC/mpv/ffplay/GStreamer + iHD/i965 驱动层）+ 决策树/交叉引用文件名
- 新增：triggers「mpv 播不了」「播放器花屏」「显卡加速」

### 1.5.0 (2026-08-10)
- 更新：`vlc-hevc-decode-fix.md` 1.0.0 → **2.0.0**（新增症状 B「能播放但雪花/画面错乱」分支 + 脚本 `vlc-hevc-vaapi-fix.sh`，基于 Prisoners 2013 x265 10bit 实战）
- 新增：决策树分支「VLC 能播但雪花 / 花屏 / 画面错乱」+ triggers「雪花」「花屏」「画面错乱」「硬解」

### 1.4.0 (2026-08-07)
- 新增：第五类「应用层」— `vlc-hevc-decode-fix.md` + 脚本 `vlc-hevc-fix.sh`（Fedora ffmpeg-free 禁用 h264/hevc 解码器 → RPM Fusion `dnf swap` 修复，实测 Caligula 1979 x265 10bit）
- 新增：决策树分支「VLC 无法播放 / could not decode / hevc / h265」+ 交叉引用「播放类故障 → system_diagnostics」
- 新增：triggers「VLC」「vlc 无法播放」「hevc」「h265」「x265」「无法解码」「could not decode」

### 1.3.0 (2026-08-05)
- 新增：第五类「应用层」— `tor-browser-check-and-fix.md`（Tor 浏览器检查+修复，IPv4 bridge + HTTPSProxy 实测组合）
- 新增：决策树分支「tor 连不上 / bootstrap 卡 0%」+ 交叉引用「Tor 前置依赖 Clash 代理」
- 新增：triggers「tor浏览器」「tor连不上」

### 1.2.0 (2026-08-05)
- 修正：`subagent-temperature-fix.md` 目录条目版本 2.3.0 → **2.6.1**、检查点数 17 → **21**（v2.6.0 适配 pi-subagents v0.40.0 第 4 次删除 + spawnRunner 6-tab 专用检查点 + YAML 兜底；v2.6.1 记录 2026-08-05 `pi update --extensions` 后复验 21/21 通过 + git 停滞超时防挂起）

### 1.1.0 (2026-07-31)
- 新增：第五类「应用层」— `ghostwriter-math-check-and-fix.md`（ghostwriter 数学渲染三层自愈）
- 新增：决策树分支「ghostwriter 公式不渲染 / 数学显示源码」
- 新增：交叉引用「配置修正 → dotfiles-sync-and-audit」

### 1.0.0 (2026-07-31)
- 初始发布：System_Fix 目录从被动文件集升级为可触发入口技能
- 新增：YAML front matter + 触发词 +「立即执行」故障响应流程
- 新增：症状→文档决策树 + 交叉引用表，保证各检查文档内联性
- 收录 `enospc-tmpfs-check.md`（新成员）

### 1.0.0 (同日修订)
- 修复：步骤 1 分类表「六类」→「五类」（实际只有 A-E 五类）
- 精进：triggers 扩充具体故障词（ENOSPC/代理/输入法/PDF/subagent 等），保证具体报错也能触发本入口
- 精进：cleanup_shutdown_issue.sh 版本列标注「脚本」

*最后更新: 2026-08-29（index 2.12.0：新增系统层 3.8 sway-resume-ebusy-ime-crash 1.0.0——S3 唤醒 EBUSY 风暴 + IME constrain_popup 空指针两级故障链，fork 补丁编译根治，pi 会话损失清点法）*
