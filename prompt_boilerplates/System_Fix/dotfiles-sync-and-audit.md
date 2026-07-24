---
name: dotfiles-sync-and-audit
version: 1.0.0
description: 将电脑中的本地配置文档同步到 ~/My_Dotfiles/（仅更新已有项），审计所有 GitHub 仓库的提交推送状态，自动生成 commit 信息，有上游的仓库仅本地备份不推送远程，执行前征求用户同意
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

对本机进行三合一维护操作，**执行前必先征求用户同意**：

1. **配置同步** — 将电脑中的实时本地配置文档，增量同步到 `~/My_Dotfiles/` 的备份副本中（**仅更新已有项**，不新增多余的配置文件）
2. **Git 仓库审计** — 调查所有本地 Git 仓库，建议可提交（commit）/ 可推送（push）的变更
   - **用户自己的仓库**（remote 为 github.com/xieguaiwu/*）：可 commit + push
   - **有上游的仓库**（fork/clone 他人项目）：仅本地 commit 备份，**不推送远程**

## 遵守的偏好（来自长期记忆）

本 skill 须严格遵守以下规则：

### ⑧ 永不覆写
- 禁止 `write` 覆写已有文件。先 `read` 了解差异，再用 `edit` 精确修改或追加。
- 新增文件才用 `write`，且确认目标不存在。
- 备份目录 `.gitignore` 中列出的敏感文件（`pi-agent/auth.json`、`.env` 等）**绝不**备份到仓库。

### ⑩ API Key 安全
- 涉及 `pi-agent/auth.json`、`url.txt`、`codewhale/config.toml` 等含 token 的文件时：
  - 备份前检查内容是否有明文 key（`sk-`、`nvapi-`、`ms-[a-z0-9]{20,}`）
  - 有 key 的文件跳过大备份，仅提醒用户手动处理
  - **若活配置与备份的唯一差异是 API key 是否为占位符**（活配置为真实 key、备份已脱敏为占位符），**直接跳过该文件，不询问用户**
- 绝不将含 key 的文件提交到 git 仓库

### ⑭ Git 安全网
- 每次 `write`/`edit` 操作前，确保 `~/My_Dotfiles/` 在 git 仓库中且可以回滚
- 操作完成后建议用户做一次 `git commit`

### ⑪ 数字信息搜索事实核查
- 审计仓库数量、未推提交数等具体数字时，调用 Momus 或 oracle 子代理核查

### ⑬ Subagent 调用安全规范
- 调用子代理时设定 `turnBudget` 和 `timeoutMs`
- 内联关键上下文，不让子代理自行读大文件

### ⑮ ask_user 高优先级
- **所有写操作前**，用 `ask_user` 征求明确同意
- 呈现结构化选项（变更摘要、风险等级），收集用户选择后再执行

## 执行流程

### Phase 0: 征求初始同意

执行任何操作前，先用 `ask_user` 展示整体计划：

```
## 🔍 计划执行以下操作
1. 同步配置  — 更新 ~/My_Dotfiles/ 中 N 个文件的备份（仅更新已有项）
2. 仓库审计  — 检查 K 个本地仓库的提交推送状态
   - 自有仓库 → commit + push
   - 有上游的 fork → 仅本地 commit
```

用户确认后进入 Phase 1，否则终止。

---

### Phase 1: 并行收集信息（无写操作）

#### 1.1 分析 My_Dotfiles 与 Live Config 的差异

```bash
# 列出 My_Dotfiles 所有配置文件（排除 .git/ 和 git 忽略的文件）
find ~/My_Dotfiles -not -path '*/.git/*' -not -name '.gitignore' -not -path '*/npm/*' -not -path '*/sessions/*' -type f | sort
```

对每个配置文件，判断其对应的"活配置"位置：

| My_Dotfiles 路径 | 活配置路径 |
|---|---|
| `~/My_Dotfiles/.bashrc` | `~/.bashrc` |
| `~/My_Dotfiles/fish/config.fish` | `~/.config/fish/config.fish` |
| `~/My_Dotfiles/sway/config` | `~/.config/sway/config` |
| `~/My_Dotfiles/kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |
| ...（类推） | ... |

**规则**：
- 只保留纯配置（`.conf` `.toml` `.json` `.lua` `.rasi` `.cfg` `.ini` 等文本文件）
- **跳过**：数据库文件（`.db`）、缓存（`history.dat` `pyindex.dat` `crash.log`）、二进制（`.png` `.jpg`）、运行时临时文件（`dbus/` `bus/` `session`）
- **跳过**：`.gitignore` 中列出的敏感文件

对每个需更新的文件：
1. `diff ~/My_Dotfiles/path ~/.config/actual/path` 算出差异
2. 若活配置有更新而备份未同步 → 标记为"待同步"

#### 1.2 Git 仓库审计

```bash
# 扫描常见位置的所有 git 仓库
for dir in ~/works/*/ ~/Desktop/*/ ~/My_Dotfiles/; do
  [ -d "$dir/.git" ] && echo "$dir"
done
```

对每个仓库：
```bash
cd "$dir"
git status --short      # 未暂存/未跟踪变更
git log --oneline @{u}..HEAD 2>/dev/null || echo "(no upstream)"  # 未推送提交
git remote -v           # 远程仓库 URL
```

判断归属：
- **自有仓库**：remote URL 含 `github.com/xieguaiwu/` → 可 commit + push
- **有上游的 fork/克隆**：remote URL 为他人仓库 → **仅本地 commit，不推送**
- **无远程**：本地仓库 → 仅 commit

标记：
- 🟢 干净的仓库 → 跳过
- 🟡 有未提交变更 → 建议 commit
- 🔴 有未推送提交 + 自有仓库 → 建议 push
- 🔵 有未推送提交 + 上游 fork → 仅本地 commit，不 push

---

### Phase 2: 生成报告（仅展示，不征求批量同意）

将 Phase 1 收集的信息汇总为清晰报告并输出，**仅用于展示**。
不在此处调用 `ask_user` 做批量确认——逐项确认移至 Phase 3 逐个执行。

#### 报告模板

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Dotfiles 同步与审计报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 一、配置同步 — N 个文件待更新
  • ~/My_Dotfiles/fish/config.fish ← ~/.config/fish/config.fish
    └ 差异: +3 行 / -1 行
  • ...

📋 二、Git 仓库审计 — K 个仓库
  🟢 My_Dotfiles — 干净
  🟡 workspace/project — 2 个未提交文件
  🔴 Desktop/project — 3 个未推送 commit

⚠️ 安全过滤：
  • 已跳过 N 个含敏感 key 的文件
  • 已跳过 M 个数据库/缓存文件

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

报告输出后告知用户："以上是收集到的变更概况，接下来逐项确认是否执行。"

---

### Phase 3: 逐项确认并执行

对所有待同步文件和待操作仓库，**逐个调用 `ask_user` 询问是否执行**，
不做批量选择。默认提供 `Yes / No` 选项，可使用自定义选项增加灵活性。

对每个条目，先展示变更摘要（diff stat / git status）再做询问：

```
## 文件: fish/config.fish
差异: +3 行 / -1 行（见下方diff摘要）
→ 是否同步此文件？
```

#### 3.1 同步配置（逐文件确认）

对每个标记为"待同步"的配置：

1. 展示 diff 摘要（行数变化）
2. **先检查差异是否仅为 API key 占位符**：若活配置与备份的唯一差异只是 API key 为真实值 vs 占位符，**直接跳过，不询问用户**，在报告中记为「已跳过（key 占位符）」。否则继续：
3. 调用 `ask_user` 询问是否同步此文件，若用户选**同步**：
   a. **先读**活配置文件和备份文件：
      ```
      read ~/My_Dotfiles/fish/config.fish
      read ~/.config/fish/config.fish
      ```
   b. **用 `edit` 增量修改**备份文件，而不是 `write` 覆写整个文件
   c. 如果差异过多（>50% 文件内容不同），考虑活配置有结构性变化，此时可用 `write` 但**必须再次用 `ask_user` 确认**
   d. 排除所有含 key/token 的敏感行
4. 若用户选**跳过**：记录跳过原因，继续下一文件



#### 3.3 Git 提交推送（逐仓库确认）

对 Phase 1 中标记为 🟡/🔴/🔵 的仓库（🟢 干净的仓库自动跳过），**逐个确认**：

**判断仓库类型：**
```bash
cd "$dir"
remote=$(git remote -v 2>/dev/null | grep -E '^origin' | head -1)
if echo "$remote" | grep -q 'github.com/xieguaiwu/'; then
    type="own"       # 自有仓库 → 可 push
elif [ -n "$remote" ]; then
    type="upstream"  # 有上游仓库 → 仅本地 commit
else
    type="local"     # 无远程 → 仅本地 commit
fi
```

**对每个仓库（循环处理）：**

1. 展示变更摘要：
   ```bash
   cd repo && git diff --stat && git status --short
   ```
2. 判断可执行的操作，构造 `ask_user` 选项：
   - **自有仓库**（🟡/🔴）：选项 = ["commit + push", "仅 commit", "跳过"]
   - **上游/本地仓库**（🟡/🔵）：选项 = ["仅 commit", "跳过"]
   - 🟢 干净的仓库：自动跳过，不询问
3. 调用 `ask_user`：
   - 标题："处理仓库: xxx？"
   - 上下文：git status 摘要 + 仓库类型
   - 选项：按上一步判断传入
4. 按用户选择执行：
   - **commit + push**：`git add -A && git commit -m "{自动生成commit信息}" && git push`
   - **仅 commit**：`git add -A && git commit -m "{自动生成commit信息}"`
   - **跳过**：记录跳过原因，继续下一仓库
5. **commit 信息自动生成**（不询问自定义）：总结变更内容，如 `chore: update xx, fix yy`
6. 若 commit 时无变更（空 commit），跳过即可

---

### Phase 4: 写入总结

执行完成后，输出最终总结：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ 执行完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 配置同步: X/Y 个文件已更新
  • fish/config.fish → 同步完成 ✓
  • ...

📋 仓库操作:
  • 自有仓库 — N 个 commit, M 个 push
  • 上游/本地仓库 — K 个本地 commit（未推送）
  • GK-Paper-Working → 已推送 ✓
  • ...
```



---

## 安全过滤清单

同步/备份前逐项检查：

### 绝不同步/备份的文件类型
- [ ] `.db` / `.sqlite` / `.sqlite3` — 数据库，非纯文本配置
- [ ] `history.dat` / `pyindex.dat` / `*.mb` — 索引/二进制缓存
- [ ] `crash.log` / `*.log` — 运行时日志
- [ ] `dbus/` / `bus/` — IPC 临时文件
- [ ] `sessions/` / `npm/` — pi-agent 运行时目录
- [ ] `url.txt` — 代理 token
- [ ] `auth.json` — 明文 API key
- [ ] `.env` / `.env.*` — 环境变量密钥

### 含 key 模式扫描（grep 检查后再备份）
- [ ] `sk-` — OpenAI/兼容 API key
- [ ] `nvapi-` — NVIDIA API key
- [ ] `ms-[a-z0-9]{20,}` — 微软 token
- [ ] `token` / `api_key` / `apikey` — 通用 key 模式
- [ ] `password` / `passwd` — 密码

### 提交前安全扫描（git 仓库审计时）
- [ ] `git diff --cached` grep `sk-\|nvapi-\|ms-[a-z0-9]\{20,\}`
- [ ] 确认 `.gitignore` 已包含敏感路径
- [ ] 已泄露的 key 先用 BFG/git filter-branch 清理历史

---

## 注意事项

1. **征求同意分两层** — Phase 0 用 `ask_user` 询问是否开始扫描（"开始扫描配置差异与仓库状态？"），Phase 3 对每个文件和仓库再次逐个 ask_user 确认是否执行；Phase 2 不做批量同意
2. **commit 信息自动生成** — 不询问自定义 commit message，根据变更内容自动生成（如 `chore: update xx, fix yy`）
3. **差异过大时预警** — 如果活配置与备份差异 >50%，提示用户可能发生了结构性变化
4. **不碰未跟踪的敏感文件** — `.gitignore` 中已有的敏感路径跳过备份
5. **符号链接处理** — 如果活配置是符号链接，追踪其真实目标文件再备份
6. **子代理调用** — 复杂分析（如扫描大量仓库的 commit 历史统计）可委托给 `explore` 或 `hephaestus`
7. **My_Dotfiles 本身也是 git 仓库** — 操作完后自动执行 `git commit + git push`（自有仓库规则）
8. **git 安全网** — 所有文件修改操作前，确保在 git 仓库中执行，以便回滚
9. **自身上游检测** — `github.com/xieguaiwu/` 作为自有仓库判定标准；若用户名变更新
    在 `inputs` 中添加 `github_user` 参数覆盖
10. **不上传 fork 改动** — 所有非自有远程的仓库，仅本地 commit 保留修改，绝不 push 到上游
11. **逐项确认不批量** — 绝不将多个文件或多个仓库合并到一个 ask_user 调用中做全选/全跳。每 ask_user 调用只问一个条目。用户可在同一会话中依次回答 Yes/No 完成逐个确认。
