---
name: memory-index-condense
version: 1.3.1
description: 调查 ~/.pi/agent/memory/，使用多个 reader agent 并行分析 MEMORY.md、SCRATCHPAD.md 和每日日志，合成浓缩的 MEMORY_INDEX.md 快速索引，并添加偏好指引 agents 自动使用。平衡内容压缩与精准关键词提炼
triggers:
  - "整理记忆"
  - "清理memory"
  - "记忆索引"
  - "内存整理"
  - "浓缩记忆"
  - "memory index"
  - "整理每日日志"
  - "condense memory"
  - "查找skill"
  - "搜索skill"
  - "查询session"
  - "查找会话"
  - "搜索技能"
  - "find skill"
  - "search skill"
  - "query sessions"
inputs:
  - name: max_daily_files
    description: 一次分析的最大每日日志文件数（超过则分批）
    required: false
    default: "12"
  - name: parallel_agents
    description: 并行 reader agent 数量（取决于 pi-resmon 建议）
    required: false
    default: "auto"
  - name: memory_dir
    description: pi-agent 内存目录路径
    required: false
    default: "~/.pi/agent/memory/"
  - name: search_query
    description: 在 skill / session 文件中搜索的内容（关键词、函数名、配置项等）
    required: false
    default: ""
  - name: search_scope
    description: 搜索范围：skills（仅 skill 文件）、sessions（仅 session 日志）、agents（agent 定义）、all（全部）
    required: false
    default: "all"
  - name: search_dirs
    description: 额外搜索目录（逗号分隔）
    required: false
    default: "~/.pi/agent/skills/,~/.pi/agent/agents/,~/prompt_boilerplates/"
tools:
  - bash
  - read
  - write
  - edit
  - glob
  - subagent
  - memory_write
  - memory_read
  - memory_search
---

# 内存索引浓缩 Skill

## 任务目标

将 `~/.pi/agent/memory/` 中的 MEMORY.md（偏好/决策/课程）、SCRATCHPAD.md（活跃任务）和每日日志（累计可能达数 MB）浓缩为一到两个紧凑的快速参考文件，使任何 agent 在 session 启动时能迅速定位关键信息，无需翻阅大量日志。

**核心原则**：
- **压缩优先**：最终索引控制在 7KB 以内，只保留当前活跃信息 + 关键词映射
- **关键词提炼**：每个项目/事件提取 3-5 个可搜索标签，链接到具体日期
- **过期 vs 活跃分离**：已下线服务器/已完成任务明确标记，防止误用
- **搜索指南嵌入**：告诉后续 agents 按什么顺序查找信息

---

## 执行流程

### 0. 资源检查

```bash
pi-resmon --recommend --class medium
```

根据 `ACTION` 决定并行度：
- `free_parallel` → 可启动 3-4 个 reader agent 并行
- `restricted_parallel` → 减少到 2 个，加大每 agent 的 turnBudget
- `serialize_only` / `defer_or_direct` → 只启动 1 个 agent 或直接读取

### 1. 调查现状

```bash
# 查看内存目录结构
ls -la ~/.pi/agent/memory/
ls -la ~/.pi/agent/memory/daily/ | tail -30

# 统计各文件大小
du -sh ~/.pi/agent/memory/*.md
du -sh ~/.pi/agent/memory/daily/

# 查看日志数量
ls ~/.pi/agent/memory/daily/*.md | wc -l

# 读取现有索引（如果已存在）
cat ~/.pi/agent/memory/MEMORY_INDEX.md 2>/dev/null || echo "不存在"
```

### 2. 分派 reader agent（并行）

根据 log 数量和资源情况，将每日日志拆分给多个 `explore` agent，同时另一个 `deep` agent 分析 MEMORY.md + SCRATCHPAD.md。

**切分策略**（以 31 个日志、4 个 agent 为例）：

```text
Agent A (explore): 最早的 ~10 个日志 (06-05 至 06-19)
Agent B (explore): 中间的 ~11 个日志 (06-20 至 07-07)
Agent C (explore): 最近的 ~10 个日志 (07-08 至 07-24)
Agent D (deep):    MEMORY.md + SCRATCHPAD.md
```

**每个 reader agent 的任务**：

对每个日期提取：
1. 当天发生的**关键事件**（项目进展、决策、新发现）
2. 出现的**服务器信息**（IP、端口、密码、GPU）— **不写入最终索引，仅用于过期标记**
3. **关键词/标签**（用于后续 `memory_search`）
4. 重要的**文件路径**和命令

**输出格式要求**（每日期一条）：

```text
YYYY-MM-DD | 关键词标签 | 关键事件摘要 | 服务器信息 | 重要文件路径
```

最后汇总：所有服务器信息（去重）+ 项目关键词频次 Top 10。

**Agent D (deep) 任务**：

从 MEMORY.md 提取：
1. 所有偏好规则（每条 1 行摘要 + 标签）
2. 所有 lessons/decisions（核心教训 + 标签）
3. 项目历史里程碑（关键数字）
4. 服务器配置列表（去重，标记最新 vs 过期）
5. 关键文件路径索引

从 SCRATCHPAD.md 提取：
6. 当前活跃任务清单（状态/服务器/检查命令）
7. 过期/失效任务标记

**参数设置**：
- `explore` agents: `turnBudget: { maxTurns: 15, graceTurns: 3 }`, `timeoutMs: 300000`
- `deep` agent: `turnBudget: { maxTurns: 15, graceTurns: 3 }`, `timeoutMs: 300000`

### 3. 合成 MEMORY_INDEX.md

将 4 个 agent 的返回结果合成为一个紧凑文件（目标 ≤7KB）。

**结构模板**：

```markdown
# 🗺️ Memory Index — Quick Reference
> Last updated: {YYYY-MM-DD} | Compact lookup for agents: read this FIRST.
> For deep detail → `memory_search({{ query: "KEYWORD", mode: "keyword" }})`

## 🟢 Active Servers (Current)
| ID | Host:Port | Password | GPU | Projects | Last Verified |

## 🔴 Expired Servers (Do NOT use)
| Host:Port | Password | Reason |

## ⚡ Currently Running Tasks
| Task | Server | PID/Status | Check Command |

## 📋 Preferences ①-⑭ (Quick Reference)
| # | Tag | One-Line Rule |

## 🏷️ Project Keyword → Daily Log Lookup
| Project | Keywords | Key Files | Recent Daily |

## 📁 Key Local File Paths
| Path | What |

## 🔍 Quick Search Guide
For agents: 1) MEMORY_INDEX.md → 2) memory_read(long_term) → 3) daily log → 4) memory_search

## ⌨️ Quick Command Reference

    # common commands
    ssh ...
    tail ...
```

**合成要点**：
- **过期 vs 活跃严格分离**：已下线服务器的密码不写入索引，只注明原因
- **密码仅存于 MEMORY_INDEX.md**：不扩散到 SCRATCHPAD 或其他文件
- **项目关键词表 ≈ 目录**：每行包含项目名、3-5 个搜索关键词、关键文件路径、最近活动日期
- **偏好仅保留 1 行摘要**：详细规则指向 MEMORY.md 原文
- **检查命令直接可执行**：`sshpass -p 'xxx' ssh root@IP -p PORT "command"`

### 4. 添加记忆偏好

在 `MEMORY.md` 中添加偏好 ⑭（或下一个编号），指引 agents 自动使用索引：

```markdown
### ⑭ 内存索引优先

- **当需要快速了解项目状态/服务器/历史时，先读 `MEMORY_INDEX.md`**（~7KB 浓缩索引），再按需搜索每日日志
- 索引结构：活跃服务器 → 运行中任务 → 偏好速查 → 项目关键词→日志映射 → 文件路径 → 搜索指南 → 命令参考
- 使用顺序：`MEMORY_INDEX.md` → `memory_read({{ target: "long_term" }})` → `memory_read({{ target: "daily", date: "YYYY-MM-DD" }})` → `memory_search`
- 项目关键词表可快速定位到相关 daily log：搜索对应关键词，读对应日期的日志
#preference #memory-index #quick-ref
```

### 5. 清理过期 SCRATCHPAD 条目

对于 reader agent 标记为过期/失效的 SCRATCHPAD 条目：
- 已勾选的任务 → 确认后保留（已完成记录）
- 未勾选但服务器已下线/凭证已失效 → 标记为 `[x]`（已完成）并添加注释说明原因
- 任务已完成但未更新的 → 标记为 `[x]`（已完成）

### 6. 记录到每日日志

```markdown
## MEMORY_INDEX.md 更新 ({YYYY-MM-DD})

- 索引重建：活跃/过期服务器更新、新任务添加、旧任务归档
- {变更摘要}
```

---

## 额外功能：Session & Skill 内容搜索

当用户需要**查找包含特定内容的 skill / session / agent 定义**时，使用此功能。典型场景：
- "帮我找一个能做 X 的 skill"
- "哪个 skill 里有 regression 相关的内容？"
- "查一下之前的 session 里有没有用过 Y 方法"
- "找 agent 定义中包含 Z 配置的"

### 搜索范围

| 范围 | 路径 | 说明 |
|------|------|------|
| `skills` | `~/.pi/agent/skills/` + `~/.pi/agent/npm/node_modules/*/skills/` | pi-agent 已安装的 skill 文件（SKILL.md） |
| `agents` | `~/.pi/agent/agents/` | 自定义 agent 定义文件（.md） |
| `sessions` | `~/.pi/agent/sessions/` | ⚡ **独立搜索模式** — 只查 session，不搜 skills/agents/boilerplates/其他本地文件 |
| `boilerplates` | `~/prompt_boilerplates/` + 所有子目录 | 用户自建 skill 模板 |
| `all` | 上述全部 | 全量搜索 |

### 执行流程

#### 7a. 定位搜索目标

```bash
# 列出所有 skill 目录
ls -d ~/.pi/agent/skills/*/
ls -d ~/.pi/agent/npm/node_modules/*/skills/*/ 2>/dev/null

# 列出所有 agent 定义
ls ~/.pi/agent/agents/*.md

# 列出所有 session（按日期倒序）
ls -lt ~/.pi/agent/sessions/ 2>/dev/null | head -20

# 列出用户 prompt 模板
find ~/prompt_boilerplates/ -name "*.md" -type f | sort
```

#### 7b. 根据 search_scope 和 search_query 执行搜索

**场景 A：搜索 skill 文件**

```bash
# 精确搜索：grep 查找特定内容
SEARCH_QUERY="{search_query}"

# 在 pi-agent 内置 skills 中搜索
find ~/.pi/agent/skills/ -name "SKILL.md" -type f 2>/dev/null | xargs grep -il "$SEARCH_QUERY" 2>/dev/null

# 在 npm 包 skills 中搜索
find ~/.pi/agent/npm/node_modules/ -path "*/skills/*/SKILL.md" -type f 2>/dev/null | xargs grep -il "$SEARCH_QUERY" 2>/dev/null

# 在用户 prompt 模板中搜索
find ~/prompt_boilerplates/ -name "*.md" -type f | xargs grep -il "$SEARCH_QUERY" 2>/dev/null

# 对每个匹配的文件，提取匹配行上下文
for f in $(find ~/.pi/agent/skills/ -name "SKILL.md" -type f 2>/dev/null | xargs grep -il "$SEARCH_QUERY" 2>/dev/null); do
    skill_name=$(basename $(dirname "$f"))
    matches=$(grep -n "$SEARCH_QUERY" "$f" | head -5)
    desc=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//;s/^"//;s/"$//')
    echo "📄 $skill_name ($f): $desc"
    echo "   → 匹配: $matches"
    echo ""
done
```

**场景 B：搜索 agent 定义**

```bash
# 在 agent 定义中搜索
cd ~/.pi/agent/agents/
for f in *.md; do
    if grep -q "$SEARCH_QUERY" "$f" 2>/dev/null; then
        name=$(head -1 "$f" | sed 's/# //')
        matches=$(grep -n "$SEARCH_QUERY" "$f" | head -3)
        echo "🤖 $f — $name"
        echo "   → 匹配: $matches"
        echo ""
    fi
done
```

**场景 C：搜索 session 日志（专注模式 — 只做这一件事）**

> ⚠️ **规则**：搜索 session 时，禁止搜索 skills/agents/boilerplates 或电脑上任何其他本地文件。只专注在 `~/.pi/agent/sessions/` 下找。找到后直接返回 session code，不做额外分析。

```bash
# 专注模式：只在 session 日志中搜索，不碰其他文件
cd ~/.pi/agent/sessions/
# ⚠️ 不要用 `ls -td */`：本机目录名以 `--` 开头（如 --home-xieguiawu-works-记录--），
# ls 会把它当成命令行选项解析 → 报错且循环恒为空（假阴性）。
# 用 find 列出目录（结果以 ./ 开头，无选项冲突）：
# 只搜索最近 10 个活跃 session（防止大目录卡死；如有需要可加大 head 行数）
find . -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -10 | cut -d' ' -f2- | while read d; do
    # ⚠️ 不要用 -maxdepth 2：子目录深层有 run-N/session.jsonl（subagent 运行），
    # 实测 maxdepth 2 只覆盖 230/1920 个文件，会漏掉真实命中（假阴性）。
    # 正确做法：直接搜全部 *.jsonl（全深度），逐文件 timeout 防卡死。
    # 实测全量 192 会话 / ~2000 文件扫描 <5 分钟。
    find "$d" -name "*.jsonl" -type f 2>/dev/null | while read f; do
        if timeout 30 grep -q "$SEARCH_QUERY" "$f" 2>/dev/null; then
            # ⚠️ session code 从匹配的 jsonl 文件名提取（目录名是 cwd 分组，无 UUID）
            session_code=$(basename "$f" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' || echo "$f")
            echo "$session_code"
        fi
    done
done
```

#### 7c. 结果汇总

> ⚠️ **session 搜索模式**：搜索范围为 `sessions` 时，直接返回 session code（每行一个），不加任何分析、描述或格式化报告。

**session 模式输出格式**：

```text
# 每行一个 session code，直接可复制给 pi --session
019f4f4d-8512-706f-beef-bb4443168646
019f8e60-b937-73f5-85d5-a7ac382721c3
```

**非 session 模式（skills/agents/all）输出格式**：

```markdown
## 🔎 Skill/Session 搜索报告

搜索词: "{search_query}"
搜索范围: {search_scope}
扫描文件数: {total}
匹配文件数: {matches}

### Skills 匹配
📄 skill-name (路径): 描述
   → 行 N: 匹配行内容

### Agent 定义匹配
🤖 agent-name.md — agent 标题
   → 行 N: 匹配行内容

### 未命中（推荐方向）
如果搜索结果为空，建议：
- 换同义词/英文再搜
- 使用 `memory_search({ query: "...", mode: "semantic" })` 语义搜索
- 到 https://github.com/ 搜索相关项目
```

#### 7d. 结果注入 MEMORY_INDEX.md（可选）

如果找到的 skill 对日常工作有长期参考价值，可以在 MEMORY_INDEX.md 的 `🏷️ Project Keyword → Daily Log Lookup` 表中新增一行：

```markdown
| **New Skill** | {关键词} | {文件路径} | {日期} |
```

这样后续 agents 通过索引就能直接看到新 skill 的位置。

---

## 输出格式

| 文件 | 大小目标 | 更新频率 | 内容 |
|------|---------|---------|------|
| `MEMORY_INDEX.md` | ≤7KB | 每周或重大项目变更后 | 活跃服务器、运行任务、偏好速查、项目→日志映射、搜索指南、命令参考 |
| `MEMORY.md` 偏好 ⑭ | ~10 行 | 仅首次添加 | 告知 agents 先读索引再搜日志 |

成功标准：
- [ ] 索引 ≤7KB
- [ ] 各项目至少 3 个搜索关键词
- [ ] 过期服务器明确标记原因
- [ ] 检查命令可直接复制执行
- [ ] 搜索指南清晰、可操作

---

## 注意事项

### 信息过期防范
- **服务器密码定期核对**：如果超过 7 天未验证，标记为 `⚠️ 未验证`，不要假设仍然有效
- **运行中任务**：如果 3 天以上无进展日志，标记为 `⚠️ 状态未知`
- **SCRATCHPAD 同步**：索引更新后检查 SCRATCHPAD 中对应的任务是否需同步更新

### Session & Skill 搜索注意事项

#### 搜索性能
- session 目录可能极大（GB 级），**不要全量 grep**。按以下策略限制：
  - `head -10` 限制最新 session 目录数（用 find+sort，勿用 `ls -td */`——目录名以 `--` 开头会被 ls 当选项）
  - 每个 session 搜全部 `*.jsonl`（**必须全深度**，subagent 运行在深层 `run-N/session.jsonl`；`-maxdepth 2` 会漏 ~90% 文件）
  - 用 `timeout 30` 防止 grep 卡死
  - 优先搜索 `skills/` 和 `agents/`（小文件，快），session 作为最后手段
- session JSONL 文件含大量 token，grep 匹配行时应只输出前 200 字符：`grep -o "$SEARCH_QUERY\|.\{0,100\}$SEARCH_QUERY.\{0,100\}"` 或 `head -c 200`

#### 搜索词技巧
- 对中文搜索词，同时尝试英文关键词（中英文混合命名常见）
- yaml front matter 中的 `name` 和 `description` 字段比正文命中更精确
- 使用 `grep -i` 忽略大小写
- 如果无结果，用 `grep -r "关键词"` 不加 `-l` 先确认文件格式（编码、换行符）
### 资源约束
- 不要一次读取所有 daily 日志（可能 500KB+），用多个 reader agent 并行拆分
- 每个 reader agent 的 `turnBudget.maxTurns` 不低于 12（需读完 10 个文件）
- 如果 `pi-resmon` 建议 `serialize_only`，改用单个 agent + 分批读取 + 累加输出

### 名称约定
- 索引文件必须为 `MEMORY_INDEX.md`（agents 通过偏好 ⑭ 自动查找此文件名）
- 不要创建多个索引文件，维护单一事实来源

### 安全
- **密码仅存于 MEMORY_INDEX.md**，不写入 SCRATCHPAD（SCRATCHPAD 会随 session 输出传播）
- 过期服务器的密码在索引中应移除（而非保留并标记过期），防误用
- `memory_write` 写入偏好时，使用 `target: "long_term", mode: "append"` 追加而非覆写

---

## 变更日志

### 1.3.1 (2026-08-11)
- 修复：session 目录列举 `ls -td */` 在 `--` 前缀目录名下被解析为命令行选项 → 假阴性；改 find+sort 列举（head 20→10）
- 修复：session 搜索 `-maxdepth 2` 漏掉深层 `run-N/session.jsonl`（实测仅覆盖 230/1920 文件，假阴性）→ 全深度 `*.jsonl` + timeout 30
- 修复：session code 从匹配的 jsonl 文件名提取 UUID（目录名是 cwd 分组，无 UUID）
- 修改：MEMORY.md 偏好编号 ⑮ → ⑭（对齐实际编号）

### 1.3.0 (2026-08-01)
- 初始版本（git 可追溯起点）：并行 reader 分析 MEMORY.md / SCRATCHPAD.md / 每日日志 → 合成 ≤7KB MEMORY_INDEX.md；附加 skill / session / agent 内容搜索
