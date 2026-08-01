---
name: system-fix-index
version: 1.1.0
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
| 4 | [clash-verge-diagnose-and-fix.md](clash-verge-diagnose-and-fix.md) | 2.2.0 | Clash Verge Rev 代理不工作（模式/Profile/Hysteria2 DNS/订阅） | 代理失效、无法上网、订阅失败 |
| 5 | [fcitx5_punctuation_fix.md](fcitx5_punctuation_fix.md) | 1.0.0 | fcitx5 中文标点问题（半角标点、顿号书名号打不出） | 输入法标点异常 |
| 6 | [cleanup_shutdown_issue.sh](cleanup_shutdown_issue.sh) | — (脚本) | 关机/重启清理脚本（systemd 守卫、ABRT 处理） | 关机慢、关机报错 |

## 三、pi-agent 层（pi 自身故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 7 | [subagent-temperature-fix.md](subagent-temperature-fix.md) | 2.3.0 | subagent temperature 配置链验证与重打补丁（17 检查点） | subagent 输出温度异常 |
| 8 | [piagent-search-pipeline-fix.md](piagent-search-pipeline-fix.md) | 1.0.0 | web_search 配置/编码崩溃/provider 不可用/内容检索失败 | 搜索报错、provider 502 |
| 9 | [piagent-cmap-fix.md](piagent-cmap-fix.md) | 1.0.0 | 处理 PDF 时 CMap 字体警告（unpdf file:// 路径问题） | PDF 解析报 CMap 警告 |
| 10 | [memory-index-condense.md](memory-index-condense.md) | 1.3.0 | 记忆索引调查与浓缩（并行 reader 合成 MEMORY_INDEX.md） | 记忆膨胀、索引过时 |

## 四、维护类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 11 | [dotfiles-sync-and-audit.md](dotfiles-sync-and-audit.md) | 1.0.0 | 配置同步到 My_Dotfiles + Git 仓库审计（有上游不推送） | 定期备份、配置审计 |

## 五、应用层（桌面应用故障）

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 12 | [ghostwriter-math-check-and-fix.md](ghostwriter-math-check-and-fix.md) | 1.1.0 | ghostwriter 预览数学公式不渲染三层自愈（pandoc wrapper / flatpak override / 导出器配置）+ 全链验证 | ghostwriter 公式不渲染、数学显示源码 |

---

## 症状 → 文档决策树

```
「no space left / ENOSPC / 磁盘满」
  └─ enospc-tmpfs-check.md ← 先看 df -h 全部挂载点，别只看根盘

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

「以上都不是 / 综合症状 / 说不清楚」
  └─ system_diagnostics_and_repair.md（全面诊断）
       └─ 发现具体问题 → 回到上方对应文档
```

## 文档间交叉引用速查

| 当前文档 | 应参阅 | 原因 |
|:---|:---|:---|
| `system_diagnostics_and_repair.md` Phase 1.2 硬件资源 | `enospc-tmpfs-check.md` | 发现内存/swap 压力或 tmpfs 问题时用 ENOSPC 流程深挖 |
| `enospc-tmpfs-check.md` Phase 4.2 | `cleanup_shutdown_issue.sh` | 清理任务可复用其 systemd 守卫模式 |
| `enospc-tmpfs-check.md` 预防 | `piagent-search-pipeline-fix.md` | opencli/chromedp 泄漏是搜索管道与 tmpfs 满的共同隐患 |
| `ghostwriter-math-check-and-fix.md` 第三层 | `dotfiles-sync-and-audit.md` | 配置修正后需同步 My_Dotfiles 备份副本 |
| `clash-verge-diagnose-and-fix.md` | `system_diagnostics_and_repair.md` Phase 1.5 网络 | 网络层诊断先跑通用检查再深入 Clash |
| `dotfiles-sync-and-audit.md` | `memory-index-condense.md` | 两者都涉及 pi-agent 配置文件的备份/维护 |
| 任何 pi-agent 层文档修复后 | `memory-index-condense.md` | 修复后如记忆/索引涉及，需重新浓缩 |

## 维护约定

- 新增文档后**必须更新本文件**：在对应分类下添加条目 + 更新决策树 + 更新交叉引用表
- 文档版本升级（front matter `version` 字段）时同步更新目录表版本号
- 文档退役时：保留条目但标注 `~~deprecated~~` 与替代者，不直接删除
- 沉淀新故障经验的模板：参照 `enospc-tmpfs-check.md`（front matter + 核心认知 + Phase 1-5 + 预防 + 注意事项）

---

## 变更日志

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

*最后更新: 2026-07-31（1.1.0 收录 ghostwriter-math-check-and-fix）*
