---
name: dotfiles-sync-and-audit
version: 1.1.0
description: 三合一维护：本地配置增量同步至 ~/My_Dotfiles/（惟更新已有项）、审计本地 Git 仓库提交推送状态、自动生成 commit 信息。自有仓库可 push，有上游者惟本地 commit。执行前必先征得用户同意
triggers:
  - "同步配置"
  - "备份dotfiles"
  - "配置备份同步"
  - "dotfiles sync"
  - "同步点文件"
  - "配置审计"
  - "更新My_Dotfiles"
  - "git仓库审计"
inputs:
  - name: scope
    description: 执行范围: all（全部）, sync-only（仅同步配置）, audit-only（仅审计仓库）
    required: false
    default: "all"
  - name: dotfiles_dir
    description: My_Dotfiles 目录路径
    required: false
    default: "~/My_Dotfiles"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
  - subagent
  - ask_user
---

# Dotfiles 同步与审计 Skill

## 任务目标

三合一维护，**执行前必先征得用户同意**：

1. **配置同步** — 本地活配置增量同步至 `~/My_Dotfiles/` 备份副本（**惟更新已有项**，禁新增多余配置）
2. **Git 仓库审计** — 调查本地仓库提交/推送状态
   - 自有仓库（remote 含 `github.com/xieguaiwu/*`）→ 可 commit + push
   - 有上游者（fork/克隆他人项目）→ 惟本地 commit 备份，**禁推远程**

## 遵守的偏好（长期记忆编号）

- **⑧ 永不覆写**：禁 `write` 覆写已有文件。先 `read` 察差异，再 `edit` 精确改或追加。新文件方可 `write`，且先确认目标不存在。`.gitignore` 所列敏感文件（`pi-agent/auth.json`、`.env` 等）**绝不备份入仓**
- **⑩ API Key 安全**：涉 `pi-agent/auth.json`、`url.txt`、`codewhale/config.toml` 等含 token 之文件：
  - 备份前先查明文 key（`sk-`、`nvapi-`、`ms-[a-z0-9]{20,}`）
  - 有 key 者跳过备份，仅提醒用户手治
  - **若活配置与备份之唯一差异乃 key 占位符**（活为真 key、备份已脱敏）→ **直接跳过，不询问**
  - 绝不以含 key 文件入 git
- **⑪ 数字信息搜索事实核查**：审计仓库数、未推提交数等具体数字，调 Momus/oracle 核查
- **git 安全网**：凡 `write`/`edit` 之前，确保 `~/My_Dotfiles/` 在 git 仓库可回滚；事毕建议 commit
- **ask_user 高优先级**：**凡写操作之前**，必用 `ask_user` 征求明确同意，示结构化选项（变更摘要、风险等级），收用户选择后行

## 执行流程

### Phase 0: 征求初始同意

操作之先，以 ask_user 示整体计划：

```
## 🔍 计划执行以下操作
1. 同步配置  — 更新 ~/My_Dotfiles/ 中 N 个文件备份（惟更新已有项）
2. 仓库审计  — 扫描 ~/*/ ~/works/ ~/Desktop/ ~/Documents/ 等，检查 K 个仓库提交推送状态
   - 自有仓库 → commit + push
   - 有上游 fork → 惟本地 commit
```

用户允则入 Phase 1，否则止。

---

### Phase 1: 并行收集信息（无写操作）

#### 1.1 分析 My_Dotfiles 与活配置差异

```bash
# 列出 My_Dotfiles 所有配置文件（排除 .git/ 和 git 忽略的文件）
find ~/My_Dotfiles -not -path '*/.git/*' -not -name '.gitignore' -not -path '*/npm/*' -not -path '*/sessions/*' -type f | sort
```

对每配置文件，判其活配置位置：

| My_Dotfiles 路径 | 活配置路径 |
|---|---|
| `~/My_Dotfiles/.bashrc` | `~/.bashrc` |
| `~/My_Dotfiles/fish/config.fish` | `~/.config/fish/config.fish` |
| `~/My_Dotfiles/sway/config` | `~/.config/sway/config` |
| `~/My_Dotfiles/kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |
| ...（类推） | ... |

**规则**：
- 惟存纯配置（`.conf` `.toml` `.json` `.lua` `.rasi` `.cfg` `.ini` 等文本）
- **跳过**：数据库（`.db`）、缓存（`history.dat` `pyindex.dat` `crash.log`）、二进制（`.png` `.jpg`）、运行时临时（`dbus/` `bus/` `session`）
- **跳过**：`.gitignore` 所列敏感文件

对每个待更文件：
1. `diff ~/My_Dotfiles/path ~/.config/actual/path` 算差异
2. 活配置新而备份旧 → 标「待同步」

#### 1.2 Git 仓库审计

```bash
# 扫描常见位置 git 仓库（含 ~/ 根层级和 ~/Documents/）
# 限深度防大目录卡死
for dir in $(find ~/ ~/works/ ~/Desktop/ ~/Documents/ ~/My_Dotfiles/ -maxdepth 2 -type d -name '.git' 2>/dev/null | sed 's|/.git||' | sort -u | head -50); do
  [ -d "$dir" ] && echo "$dir"
done
```

每仓库：

```bash
cd "$dir"
git status --porcelain      # 未暂存/未跟踪变更（机器可解析格式）
git log --oneline @{u}..HEAD 2>/dev/null || echo "(no upstream)"  # 未推送提交
git remote -v           # 远程仓库 URL
```

判归属：
- **自有**：remote 含 `github.com/xieguaiwu/` → 可 commit + push
- **有上游 fork/克隆**：remote 为他人仓库 → **惟本地 commit，不推送**
- **无远程**：本地仓库 → 惟 commit

标记：
- 🟢 干净 → 跳过
- 🟡 有未提交变更 → 建议 commit
- 🔴 有未推送提交 + 自有 → 建议 push
- 🔵 有未推送提交 + 上游 fork → 惟本地 commit

---

### Phase 2: 生成报告（仅展示，不批量征求）

汇总 Phase 1 为报告输出，**仅展示**。不在此 ask_user 批量确认——逐项确认移至 Phase 3。

#### 报告模板

```
━━━━━ Dotfiles 同步与审计报告 ━━━━━
📋 一、配置同步 — N 个文件待更新
  • path ← live  差异: +3 / -1
📋 二、Git 仓库审计 — K 个仓库
  🟢 干净 / 🟡 未提交 / 🔴 未推+自有 / 🔵 未推+fork
⚠️ 安全过滤：跳过 N 个含 key 文件、M 个缓存文件
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

报告后告用户：「以上乃变更概况，以下逐项确认是否执行。」

---

### Phase 3: 逐项确认并执行

对所有待同步文件与待操作仓库，**逐个 ask_user 询问**，禁批量合并。默认 Yes/No，可自定义选项。每条目先示变更摘要（diff stat / git status）再问。

#### 3.1 同步配置（逐文件确认）

对每个「待同步」配置：

1. 示 diff 摘要（行数变化）
2. **先查差异是否仅 key 占位符**：若活配置与备份唯一差异乃真 key vs 占位符 → **直接跳过，不询问**，报告中记「已跳过（key 占位符）」。否则继续：
3. ask_user 询问是否同步，若选**同步**：
   a. **先读**活配置与备份：
      ```
      read ~/My_Dotfiles/fish/config.fish
      read ~/.config/fish/config.fish
      ```
   b. **用 `edit` 增量修改**备份，非 `write` 覆写
   c. 若差异 >50% 内容，疑结构性变化，可用 `write` 但**必再 ask_user 确认**
   d. 排除一切含 key/token 敏感行
4. 若选**跳过**：记原因，续下一文件

#### 3.2 Git 提交推送（逐仓库确认）

Phase 1 标记 🟡/🔴/🔵 者（🟢 自动跳过），**逐个确认**：

**判类型：**

```bash
cd "$dir"
remote=$(git remote -v 2>/dev/null | grep -E '^origin' | head -1)
if echo "$remote" | grep -q 'github.com/xieguaiwu/'; then
    type="own"       # 自有仓库 → 可 push
elif [ -n "$remote" ]; then
    type="upstream"  # 有上游仓库 → 惟本地 commit
else
    type="local"     # 无远程 → 惟本地 commit
fi
```

**每仓库（循环）：**

1. 示变更摘要：
   ```bash
   cd repo && git diff --stat && git status --short
   ```
2. 构 ask_user 选项：
   - **自有**（🟡/🔴）：["commit + push", "仅 commit", "跳过"]
   - **上游/本地**（🟡/🔵）：["仅 commit", "跳过"]
   - 🟢 干净：自动跳过，不询问
3. ask_user：标题「处理仓库: xxx？」，上下文 = git status 摘要 + 仓库类型
4. 按选择执行：
   - **commit + push**：`git add -A && git commit -m "{自动生成commit信息}" && git push`
   - **仅 commit**：`git add -A && git commit -m "{自动生成commit信息}"`
   - **跳过**：记原因，续下一仓库
5. **commit 信息自动生成**（不询问自定义）：如 `chore: update xx, fix yy`
6. 无变更（空 commit）则跳过

---

### Phase 4: 写入总结

事毕，输出最终总结：

```
━━━━━ ✅ 执行完成 ━━━━━
📋 配置同步: X/Y 已更新（逐文件✓）
📋 仓库操作: 自有 N commit/M push；上游/本地 K 本地 commit
━━━━━━━━━━━━━━━━━━━━━
```

---

## 安全过滤清单

同步/备份前逐项检查：

### 绝不同步/备份之文件
- [ ] `.db`/`.sqlite*` — 数据库 ｜ `history.dat`/`pyindex.dat`/`*.mb` — 缓存 ｜ `*.log` — 日志
- [ ] `dbus/`/`bus/` — IPC 临时 ｜ `sessions/`/`npm/` — pi-agent 运行时目录
- [ ] `url.txt` — 代理 token ｜ `auth.json` — 明文 key ｜ `.env*` — 环境密钥

### 含 key 模式扫描（grep 查后再备份）
- [ ] `sk-` ｜ `nvapi-` ｜ `ms-[a-z0-9]{20,}` ｜ `token`/`api_key`/`apikey` ｜ `password`/`passwd`

### 提交前安全扫描（git 审计时）
- [ ] `git diff --cached` grep `sk-\|nvapi-\|ms-[a-z0-9]\{20,\}`
- [ ] `.gitignore` 已含敏感路径；已泄露 key 用 BFG/filter-branch 清历史

## 注意事项

1. **同意分两层** — Phase 0 问是否扫描；Phase 3 逐条再问；Phase 2 不批量
2. **commit 信息自动生成** — 不询问自定义，按变更生成（`chore: update xx, fix yy`）
3. **差异 >50% 预警** — 疑结构性变化，`write` 前必再确认
4. **不碰未跟踪敏感文件** — `.gitignore` 已有路径跳过备份
5. **符号链接** — 活配置为链接时，追真实目标再备份
6. **子代理** — 复杂分析（大量仓库统计）可委 explore/hephaestus
7. **My_Dotfiles 亦 git 仓库** — 事毕自动 commit + push（自有规则）
8. **git 安全网** — 文件修改前确保在 git 仓库中，以便回滚
9. **自身上游检测** — `github.com/xieguaiwu/` 为自有标准；用户名变则在 inputs 加 `github_user`
10. **不上传 fork 改动** — 非自有远程，惟本地 commit，绝不 push 上游
11. **逐项确认不批量** — 每 ask_user 只问一条，禁全选/全跳
