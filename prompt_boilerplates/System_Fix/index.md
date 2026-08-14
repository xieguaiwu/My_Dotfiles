---
name: system-fix-index
version: 1.9.0
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
  - "subagent 异常"
  - "记忆索引"
  - "关机慢"
  - "同步配置"
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
| **C. pi-agent 自身故障** | subagent/web_search/PDF/记忆 相关报错 | → 直接加载 pi-agent 层文档 |
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

对照下方 **「症状 → 文档决策树」** 加载对应修复文档。若一个症状匹配多个文档，按表格顺序执行。

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
| 1 | [system_diagnostics_and_repair.md](system_diagnostics_and_repair.md) | 1.0.0 | 全面系统诊断（硬件/内核/服务/日志），输出修复方案 | 无明确症状的故障、定期体检 |
| 2 | [system_fix.fish](system_fix.fish) | 1.0.0 | 可执行健康检查脚本（core dump/缓存/DNF/崩溃告警），`--dry`/`--auto` 模式 | 想自动跑一遍检查时 |

## 二、系统层（桌面/OS/资源）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 3 | [enospc-tmpfs-check.md](enospc-tmpfs-check.md) | 1.0.0 | ENOSPC/tmpfs 满排查：磁盘 vs 内存盘区分、换出页占配额、孤儿进程清理 | 任何 "no space left"、写入失败、tmpfs 满 |
| 3.5 | [freeze-oom-protection.md](freeze-oom-protection.md) | 1.1.0 | 死机/冻结/OOM thrash 排查（Purging GPU memory=内存压力信号）+ 泄漏源排查（chrome 元凶）+ 一键防护（earlyoom + oomd 加固 + 进程限流），脚本 [freeze-oom-protect.sh](freeze-oom-protect.sh) | 死机、冻结、卡死、没响应、内存不足 |
| 3.6 | [chrome-leak-reaper.md](chrome-leak-reaper.md) | 1.0.0 | Chrome 内存泄漏排查与 chrome-reaper 维护：chromedp/桥实例/zygote 误杀（PPID 链）/restart 残留/profile 锁冲突 | chrome 吃内存、chrome 进程多、DidStartWorkerFail、bridge 反复重启 |
| 4 | [clash-verge-diagnose-and-fix.md](clash-verge-diagnose-and-fix.md) | 2.2.0 | Clash Verge Rev 代理不工作（模式/Profile/Hysteria2 DNS/订阅） | 代理失效、无法上网、订阅失败 |
| 5 | [fcitx5_punctuation_fix.md](fcitx5_punctuation_fix.md) | 1.0.0 | fcitx5 中文标点问题（半角标点、顿号书名号打不出） | 输入法标点异常 |
| 6 | [cleanup_shutdown_issue.sh](cleanup_shutdown_issue.sh) | — (脚本) | 关机/重启清理脚本（systemd 守卫、ABRT 处理） | 关机慢、关机报错 |

## 三、pi-agent 层（pi 自身故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 7 | [subagent-temperature-fix.md](subagent-temperature-fix.md) | 2.6.1 | subagent temperature 配置链验证与重打补丁（21 检查点，双保险：传递链 + YAML 兜底） | subagent 输出温度异常 |
| 8 | [piagent-search-pipeline-fix.md](piagent-search-pipeline-fix.md) | 1.0.0 | web_search 配置/编码崩溃/provider 不可用/内容检索失败 | 搜索报错、provider 502 |
| 9 | [piagent-cmap-fix.md](piagent-cmap-fix.md) | 1.0.0 | 处理 PDF 时 CMap 字体警告（unpdf file:// 路径问题） | PDF 解析报 CMap 警告 |
| 10 | [memory-index-condense.md](memory-index-condense.md) | 1.3.0 | 记忆索引调查与浓缩（并行 reader 合成 MEMORY_INDEX.md） | 记忆膨胀、索引过时 |

## 四、维护类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 11 | [dotfiles-sync-and-audit.md](dotfiles-sync-and-audit.md) | 1.1.0 | 配置同步到 My_Dotfiles + Git 仓库审计（有上游不推送） | 定期备份、配置审计 |

## 五、应用层（桌面应用故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 12 | [ghostwriter-math-check-and-fix.md](ghostwriter-math-check-and-fix.md) | 1.1.0 | ghostwriter 预览数学公式不渲染三层自愈（pandoc wrapper / flatpak override / 导出器配置）+ 全链验证 | ghostwriter 公式不渲染、数学显示源码 |
| 13 | [tor-browser-check-and-fix.md](tor-browser-check-and-fix.md) | 1.0.0 | Tor 浏览器 bootstrap 失败检查+修复（IPv6 bridge / Socks5Proxy 禁，HTTPSProxy + IPv4 bridge 实测可用）+ tor 内核验证 | tor 无法连接、bootstrap 卡 0% |
| 14 | [video-playback-decode-fix.md](video-playback-decode-fix.md) | 2.1.0 | 视频播放/解码故障修复总集：A 无法解码（ffmpeg-free 禁解码器 → `dnf swap` 换完整 ffmpeg，脚本 [video-decode-ffmpeg-swap.sh](video-decode-ffmpeg-swap.sh)）；B 能播放但雪花/花屏（iHD 弃 Gen9 HEVC → i965 驱动 + VAAPI 硬解 + 环境注入，脚本 [video-playback-vaapi-fix.sh](video-playback-vaapi-fix.sh)）；覆盖 VLC/mpv/ffplay/GStreamer + iHD/i965 驱动层 | VLC/mpv 报 could not decode、播不了、雪花、花屏、画面错乱、播放卡顿、显卡加速异常 |

## 六、资产/数据备份类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 15 | [sparrow-wallet-backup-test.md](sparrow-wallet-backup-test.md) | 1.0.0 | Sparrow 钱包备份完整性体检：自动定位钱包文件、明文种子检查、rbw 条目存在性 + bw 附件哈希比对、GUI 恢复演练指引（脚本 [sparrow-wallet-backup-test.sh](sparrow-wallet-backup-test.sh)） | 钱包备份验证、恢复演练、备份完整性检查 |

---

## 症状 → 文档决策树

```
「no space left / ENOSPC / 磁盘满」
  └─ enospc-tmpfs-check.md ← 先看 df -h 全部挂载点，别只看根盘

「死机 / 冻结 / 卡死 / 没响应 / 内存不足」
  └─ freeze-oom-protection.md ← 先看 journalctl -b -1 尾部：Purging GPU memory = 内存 thrash；装 earlyoom + oomd 加固；泄漏源先查 chrome

「chrome 内存泄漏 / chrome 吃内存 / chrome 进程多 / DidStartWorkerFail / bridge 反复重启」
  └─ chrome-leak-reaper.md ← 进程画像 + reaper 日志 + scope/PPID 链判定 + v3 修复；致死机/ENOSPC 时配合 freeze-oom-protection / enospc-tmpfs-check

「代理不工作 / 无法上网 / 订阅失败」
  └─ clash-verge-diagnose-and-fix.md

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

「关机慢 / 关机报错 / ABRT」
  └─ cleanup_shutdown_issue.sh

「同步配置 / 备份 dotfiles / git 仓库审计」
  └─ dotfiles-sync-and-audit.md

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
| `enospc-tmpfs-check.md` Phase 4.2 | `cleanup_shutdown_issue.sh` | 清理任务可复用其 systemd 守卫模式 |
| `enospc-tmpfs-check.md` 预防 | `piagent-search-pipeline-fix.md` | opencli/chromedp 泄漏是搜索管道与 tmpfs 满的共同隐患 |
| `ghostwriter-math-check-and-fix.md` 第三层 | `dotfiles-sync-and-audit.md` | 配置修正后需同步 My_Dotfiles 备份副本 |
| `clash-verge-diagnose-and-fix.md` | `system_diagnostics_and_repair.md` Phase 1.5 网络 | 网络层诊断先跑通用检查再深入 Clash |
| `tor-browser-check-and-fix.md` 前置 | `clash-verge-diagnose-and-fix.md` | Tor 经本地代理引导，代理失效时先修 Clash 再修 Tor |
| `video-playback-decode-fix.md` | `system_diagnostics_and_repair.md` | 播放类故障先查系统 ffmpeg 解码能力，再深入播放器自身；GPU 无硬件加速时驱动安装/VAAPI 能力对照收拢于 video skill |
| `dotfiles-sync-and-audit.md` | `memory-index-condense.md` | 两者都涉及 pi-agent 配置文件的备份/维护 |
| 任何 pi-agent 层文档修复后 | `memory-index-condense.md` | 修复后如记忆/索引涉及，需重新浓缩 |

## 维护约定

- 新增文档后**必须更新本文件**：在对应分类下添加条目 + 更新决策树 + 更新交叉引用表
- 文档版本升级（front matter `version` 字段）时同步更新目录表版本号
- 文档退役时：保留条目但标注 `~~deprecated~~` 与替代者，不直接删除
- 沉淀新故障经验的模板：参照 `enospc-tmpfs-check.md`（front matter + 核心认知 + Phase 1-5 + 预防 + 注意事项）

---

## 变更日志

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

*最后更新: 2026-08-10（1.8.0 新增 chrome-leak-reaper.md；freeze-oom-protection 1.1.0 加泄漏源排查）*
