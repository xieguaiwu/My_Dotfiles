---
name: dotfiles-sync-and-audit
version: 1.4.1
description: 四合一维护：本地配置增量同步至 ~/My_Dotfiles/（惟更新已有项）、审计本地 Git 仓库提交推送状态、自动生成 commit 信息、新建项目默认 scaffold（git init + MIT LICENSE + .gitignore + README + 首 commit）。自有仓库可 push，有上游者惟本地 commit。执行前必先征得用户同意
triggers:
  - "同步配置"
  - "备份dotfiles"
  - "配置备份同步"
  - "dotfiles sync"
  - "同步点文件"
  - "配置审计"
  - "更新My_Dotfiles"
  - "git仓库审计"
  - "新建项目"
  - "项目初始化"
  - "scaffold"
  - "git init"
  - "LICENSE"
  - "初始化仓库"
  - "新项目"
  - "创建 repo"
  - "gh repo create"
  - "LLM provider 配置"
  - "API key 恢复"
inputs:
  - name: scope
    description: '执行范围: all（全部）, sync-only（仅同步配置）, audit-only（仅审计仓库）'
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
# 扫描全部 git 仓库（单起点 ~/ + maxdepth 4 + prune 黑名单防大目录卡死）
# ⚠️ 必须 -print0 + while read：路径含空格/中文（如 "Obsidian Vault"、"在深渊"）时，
#    `for dir in $(find ...)` 词分割会把路径拆断 → 仓库静默漏扫（2026-08-06 实测漏 18 个）
while IFS= read -r -d '' d; do
  echo "${d%/.git}"
done < <(find ~ -maxdepth 4 -type d \( -name node_modules -o -name .cache -o -name .local -o -name .venv \) -prune \
  -o -type d -name .git -print0 -prune 2>/dev/null | sort -zu)
# ⚠️ 两处 NUL 一致性：find 必须 -print0（非 -print），管道必须 sort -zu（非 sort -u）。
#    -print + sort -zu → 所有路径粘成一条记录；-print0 + sort -u → 整块并成一行 → read 循环失效。
```

每仓库：

```bash
cd "$dir"
git status --porcelain      # 未暂存/未跟踪变更（机器可解析格式）
# ⚠️ 无上游时 @{u}..HEAD 会静默失败 → 先探测 upstream 再数未推提交
if git rev-parse --verify @{u} >/dev/null 2>&1; then
    git rev-list --count @{u}..HEAD   # 未推送提交数
else
    echo "(no upstream)"              # 无上游 → 本地仓库
fi
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
# ⚠️ 同时匹配 https://github.com/xieguaiwu/ 与 git@github.com:xieguaiwu/（冒号分隔）
if echo "$remote" | grep -qE 'github\.com[:/]xieguaiwu/'; then
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
12. **路径含空格/中文** — 仓库路径如 `Documents/Obsidian Vault`、`Desktop/c++/在深渊`；扫描必须 `-print0` + `while read -d ''`，禁 `for dir in $(find ...)` 词分割（2026-08-06 实测漏 18 仓库）
13. **完整性自检** — 报告须含仓库总数；若已知存在的仓库未出现，先查 maxdepth/prune 是否过严，勿直接下"干净"结论
14. **key 空值先查真值源** — 活配置之 API key 若为空，勿望「从备份还原」（备份恒为占位符），依 [附录 B.1] 序查 `auth.json` → `secrets/` → 会话日志 → `rbw`；配 LLM provider 前必读 [附录 B]
15. **配置改动作用域 = 用户请求作用域** — 用户令「加一个 provider」，则惟增条目，勿翻默认值、勿顺手加第二三模型/端点（返工教训见 [附录 B.7]）

---

## 附录：新项目 Scaffold（git init + MIT LICENSE）

**核心原则：任何新项目的第一件事就是进入版本控制。** 没有 git 的项目等于没有历史（教训：go-projects 14 项目中 6 个曾无 git、8 个曾无 LICENSE，2026-08-18 才补齐）。hephaestus 等 builder agent 创建新项目时必须执行本流程。

### 标准流程（按顺序）

1. **检测现有状态**（已有则跳过，不覆写）：
   ```bash
   [ -d .git ] && echo "已有 git" || echo "无 git"
   [ -f LICENSE ] && echo "已有 LICENSE" || echo "无 LICENSE"
   [ -f .gitignore ] && echo "已有 .gitignore" || echo "无 .gitignore"
   ```
2. **git init**：`git init -q -b main`（统一 main 分支；已有仓库分支为 master 不强制改名）
3. **.gitignore**（secrets 条目优先）：
   ```gitignore
   # Binary
   /{binary_name}
   # Secrets — never commit
   config.json
   servers.json
   *.env
   .env*
   # IDE / OS
   .idea/  .vscode/  *.swp  *.swo  .DS_Store
   # Agent 运行时产物（按需）
   .pi-subagents/  .omo/  node_modules/
   ```
4. **MIT LICENSE**：复制 `~/Desktop/go-projects/bl/LICENSE`（2026 xieguaiwu 版，全库统一模板）
5. **README.md 骨架**：`# 项目名` + 一句话描述 + 安装/使用/开发/许可证（中文为主，ASD-STE100 规范）
6. **首次 commit**：
   ```bash
   git add -A
   # 提交前敏感扫描：git diff --cached | grep -iE "sk-|nvapi-|token|password" 零命中才提交
   git -c user.name="xieguaiwu" -c user.email="xieguaiwu@163.com" commit -m "chore: initial scaffold (git init + MIT LICENSE)"
   ```
7. **可选发布**（用户要求时）：`gh repo create xieguaiwu/{repo} --public --source . --push --description "..."`；GitHub API 503 时退避重试（sleep 30-60，最多 5 次），git push/tag 不受 API 故障影响

### Scaffold 检查清单

- [ ] .git 存在（branch: main）
- [ ] LICENSE 存在（MIT, 2026 xieguaiwu）
- [ ] .gitignore 含 secrets 条目
- [ ] README.md 存在
- [ ] 首 commit 完成，工作区干净，`git diff --cached` 无敏感信息
- [ ] （如发布）GitHub repo 公开可见

### 常见陷阱

1. **并行竞态**：cp LICENSE 与 git add 并行执行 → pathspec 不匹配（cp 未完成）。顺序执行
2. **损坏代码也要 git init**：现状入库胜过无历史（mess_math 教训），修复后 diff 可见
3. **目录名大小写**：repo 名与目录名可不同（Essen → essen），以 GitHub repo 名为准
4. **私有项目**（含真实凭据/密码/服务器 IP）：git init + LICENSE 照做，但发布用 `--private` 或干脆不发布（vpn-check 教训）

---

## 附录 B：LLM API key 与 provider 配置实战（2026-08-29 实测）

**缘起**：为 `bl`（`~/.local/bin/bl`）接入 `qwen3.8-flash`，途中发现本机 `DEEPSEEK_API_KEY` 已空值。以下七条皆当日实测，含一条静默丢 key 之真凶。工具栈背景：key 明文存 `~/.config/fish/config.fish`（该文件非 dotfiles 符号链接、不入仓），`~/My_Dotfiles/` 为脱敏备份。

### B.1 备份非真值源——恢复 key 须按序查真值库

- **现象**：`~/.config/fish/config.fish` 之 `set -gx DEEPSEEK_API_KEY` 无值，欲按备份还原
- **定位**：`~/My_Dotfiles/fish/config.fish` 第 9 行
- **取证**：逐提交查真值是否曾入库——真值**从未入库**，三代占位符演进 `<your-deepseek-api-key>` → `<your-openai-key>` → `<your-key>`：

```bash
cd ~/My_Dotfiles && git log -S'<your-key>' --oneline -- fish/config.fish
for c in $(git log --format=%h -- fish/config.fish); do
  git show $c:fish/config.fish | grep -m1 'set -gx DEEPSEEK_API_KEY'
done
```

- **根因**：⑩ API Key 安全策略使备份单向（活 → 备、且脱敏）。故备份不可充当恢复源
- **真值源次序**（本次实测结果）：

| 序 | 真值源 | 本次结果 |
|:--|:---|:---|
| 1 | `~/.pi/agent/auth.json`（`{provider:{type,key}}`） | `sk-2a37…` → `/chat/completions` HTTP 200 ✅ |
| 2 | `~/.config/opencode/secrets/<provider>` | `sk-ba9e…e93a` → HTTP 401 已失效 ❌ |
| 3 | pi 会话日志原文（历史 read 结果里的 key） | 与序 1 同值，互为佐证 |
| 4 | `rbw get`（fish `k` 助手） | 本次未用 |

- **修复**：脚本内取真值、绝不打印明文，锚点须为**整行**并断言命中数：

```python
import json, re, os
p = '.config/fish/config.fish'
key = json.load(open(os.path.expanduser('.pi/agent/auth.json')))['deepseek']['key']
s = open(p, encoding='utf-8').read()
new, n = re.subn(r'(?m)^set -gx DEEPSEEK_API_KEY$', f'set -gx DEEPSEEK_API_KEY "{key}"', s)
assert n == 1, f'anchor matched {n} — 未写回'
open(p, 'w', encoding='utf-8').write(new)
```

- **防复发**：①验效只报 `len` + 前 7 字 ②「文件里有值」≠「key 可用」，必以真实 completion 请求判定 ③旁证：`pi auth check --provider deepseek` 在**无** `DEEPSEEK_API_KEY` 环境下仍报 `ready`（2026-08-29 实测），知 pi 自取 `auth.json`，故 key 空值三日 pi 全无感，受害的是读 env 的外部工具（bl 报错原文见 B.6）

### B.2 前缀锚点插入吞行——key 静默丢失之真凶

- **现象**：`set -gx DEEPSEEK_API_KEY` 空值。肇事脚本当时打印「QWEN_API_KEY 已添加」，退出码 0，全无异常
- **定位**：2026-08-29 01:0x 会话 `01a0493c` 的 python 片段：

```python
anchor = 'set -gx DEEPSEEK_API_KEY'          # ❌ 行前缀，非整行
s = s.replace(anchor, anchor + '\n' + add, 1)
```

- **根因**：原行为 `set -gx DEEPSEEK_API_KEY "sk-…"`，在**行中间**劈开插入，值被挤入下一行，成 `set -gx QWEN_API_KEY "新key" "旧deepseek值"`。二次破坏：同会话稍后又以整行替换清理该 QWEN 行——

```python
re.sub(r'^set -gx QWEN_API_KEY .*$', f'set -gx QWEN_API_KEY "{NEW_KEY}"', s, count=1, flags=re.M)
```

  孤儿值随整行一并销毁，key 自此不可恢复（幸 `auth.json` 另有真值）
- **修复**：见 B.1 脚本（整行锚点 + `assert`）
- **防复发**：①改配置文件优先用 `edit` 工具（精确匹配、不重叠），次选 python ②python 手术之锚点一律 `(?m)^…$` 整行或含值，禁裸前缀 ③每步 `assert n == 1`，禁裸 `replace` ④改完必 `grep -n` 回读**整行**（脱敏后），禁以脚本自报成功为凭（参 `Coding/verification-before-completion.md`）

### B.3 配置文件改动取证法（谁改的、哪一步改坏的）

- **场景**：配置莫名损坏、无报错、无人认账
- **命令**（`grep -rl` 只给文件不给上下文，须二次解析）：

```bash
cd ~/.pi/agent/sessions && find . -name "*.jsonl" -newermt "2026-08-28 20:00" \
  | while read f; do grep -q 'config\.fish' "$f" && echo "$(stat -c %y "$f"|cut -c1-16) $(grep -c 'config\.fish' "$f") hits  $f"; done | sort
```

  再逐会话用 python 取 `message.content[]` 内 `name`/`arguments`，正则切上下文并脱敏：`re.sub(r'(sk-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]{5,}', r'\1…', s)`
- **两条判读**：①目录 mtime 新于文件 mtime ⇒ 期间有编辑器 swap 介入（人工改动，不入会话日志，须问用户）②同 key 前缀在多处出现 ⇒ 以 `len` + 端点响应区分真值与注释残留
- **限制**：仅 pi 会话可查；纯人工 `nvim` 改动无痕迹

### B.4 key ↔ 端点配对矩阵——401 勿轻判 key 失效

阿里云一套两家门户，key 前缀与端点**强配对**，且订阅 key **按区域绑定**。2026-08-29 最终实测矩阵（同一天内）：

| key | 类型 | 端点 | 结果 |
|:--|:---|:---|:---|
| `sk-sp-` | Token Plan 订阅 | `https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1` | **200 ✅**（chat + `GET /models` 双验，proxy/直连皆通） |
| `sk-sp-` | Token Plan 订阅 | `https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1` | 401 `invalid_api_key`（同一把 key！区域不认） |
| `sk-ws-` | 按量 PAYG | `https://dashscope.aliyuncs.com/compatible-mode/v1` | **200 ✅** |
| 交叉 | 任一 key 打对方门户 | — | 401 `invalid_api_key` |

错误原文（区域不对与 key 未激活同文，极易误判为 key 已死）：

```text
{"error":{"message":"Invalid API-key provided. For details, see: https://www.alibabacloud.com/help/en/model-studio/error-code#apikey-error","code":"invalid_api_key"}}
```

- **铁律一**：**401 ≠ key 失效**。401 至少有两种良性质因：①端点/区域错（同 key 换区域即 200）②订阅激活延迟。先做 key × 端点二因子矩阵（`curl /chat/completions` 打一遍，30 秒内可全测），再判死活
- **铁律二（本次血泪）**：**凭据结论带时间戳，且要与用户对表**。本次 01:13 与 01:30 两轮测试，`sk-sp-` × 北京/新加坡四格全 401，遂判「订阅未激活」；用户 02:0x 告知「一直在用，key 绝对无误」——复测北京端点已 200（同 key、同端点、中间无任何配置改动）。真相：订阅在 01:30 之后才生效（激活延迟），当时判「未激活」没错，错在把**时效性结论当成永久结论**。用户声称可用时，先复测再反驳，勿用旧结果顶撞
- **判活宜两事并行**：`GET /models`（本次北京端点得 `qwen3.8-flash`、`qwen3.8-max`、`deepseek-v4-flash-0731`、`glm-5.2`、`qwen-audio-3.0-*` 等）+ 一次最小 completion
- **pi 认证源链**：`models.json` 的 `apiKey: "$QWEN_API_KEY"` 取自**进程 env**；GUI/桌面启动的 pi 不 source `config.fish` → env 无 key、`auth.json` 亦无该 provider → 请求带空 key，网关回 401，pi 落 fallback（本次会话实证：session 头 `model_change: qwen/qwen3.8-flash`，随后落 `deepseek-v4-pro`）。修法：把 key 写入 `auth.json`（该 provider）或从 fish 终端启动。见 B.1 真值源表
- **代理**：两个门户经 7897 与直连**皆通**（200 或 401 均为认证层响应，非链路问题），不必加 `no_proxy`

### B.5 验 env 变量生效之假阴性坑

- **现象**：`fish -c 'source ~/.config/fish/config.fish; echo (string length $DEEPSEEK_API_KEY)'` 得 0，误判「配置未生效」
- **根因**：`config.fish` 首行即下列守卫——`fish -c` 非交互，整个文件在设 key 之前便已返回：

```fish
if not status is-interactive
    return
end
```
- **修复**：取值直接用 python 正则读文件再 `export`；或 `fish -i -c`（需 tty）。本机 key 明文皆在 `config.fish` 内，直读文件最稳

### B.6 bl 的 provider 配置语义与失效 flag

配置文件 `~/.config/bl/config.json`（`llm.provider` 为默认项，`llm.providers[]` 为名录）：

- `api_key` 认 `env:VAR_NAME` 或字面量两种；缺值时报错原文：`error: LLM provider "deepseek-official": API key not resolved (check config: api_key="env:DEEPSEEK_API_KEY" or set the referenced env var)`
- `base_url` 只写到 `/v1`，bl 自动追加 `/chat/completions`（写全路径会 404）
- **`--llm-provider <name>` 是空壳 flag**（本 build 2026-07-21）：名字**会**校验，却**不**切换。实测三条：

```text
bl --llm --llm-provider qwen "pear"        → 头行 [deepseek-official / deepseek-v4-flash]   # 未切换
bl --llm --llm-provider nosuch "pear"      → error: LLM provider "nosuch" not found in config
                                              Available providers: openrouter, deepseek-official, qwen, …
bl --llm --llm-provider openrouter "pear"  → 头行 [deepseek-official / …]                    # 仍未切换
```

- `--llm-model <id>` 与 `--llm-key <k>` 只覆盖**发给默认 provider** 的对应字段，不换端点——故 `--llm-model qwen3.8-max` 得 DeepSeek 400 `The supported API model names are deepseek-v4-pro, deepseek-v4-flash, and deepseek-v4-flash-vision-exp, but you passed qwen3.8-max.`；`--llm-key <qwen key>` 得 DeepSeek 401
- **结论**：换 provider **只能改 `llm.provider` 字段**（或 `-C` 配置 UI）。推论：只加条目而不改默认，则该条目不可达——须向用户点明并请其定夺，勿自行翻转
- **判读铁则**：输出首行 `[provider / model]` 头才是实际生效者，命令行参数不作数

### B.7 最小改动纪律（本次返工）

- **事故**：用户仅要求「给 bl 配置 qwen3.8-flash」，实际操作却 ①新增三条 provider（flash/max/token-plan）②翻转默认 `llm.provider` ③用户遂疑「删了 deepseek provider」
- **纠正三步**：①`cp` 原始文件至 `/tmp` 为对照基线 ②删多余条目、默认改回 ③以 diff 证明「唯一差异即所求」：

```bash
diff <(python3 -m json.tool /tmp/bl.config.json.bak) <(python3 -m json.tool ~/.config/bl/config.json)
```

- **守则**：①改默认值属行为变更，须先问 ②「顺手多加几个备用」即越权 ③含注释性说明的新增，写进 skill 或问用户，不塞进配置文件

### B.8 思想型经验（可迁移检验）

1. **脱敏体系下备份单向**：凡入库前脱敏之仓库，只可用于「新机器铺底」，不可用于「活配置回滚」；回滚源必为真值库（凭据管理器 / `auth.json` / `secrets/`）。本案佐证：备份 11 个提交全为占位符
2. **静默损坏重于报错损坏**：脚本自报成功而文件已坏，是配置事故中最贵的一种——防它唯靠「改后回读 + 断言命中数」，不靠看退出码
3. **认证层错误先配对再判死**：401/403 在多渠道供应商处常为「端点选错」而非「凭据失效」，测矩阵的成本（数十秒）远低于误删可用凭据的成本
4. **GUI/守护进程的 env 不来自 shell rc**：桌面启动的进程不 source `config.fish`，其凭据只能指望程序自身之 keyring/auth 文件（本案 pi 即靠 `auth.json` 兜住）
5. **凭据结论必须带时间戳**：「当时 401」与「现在可用」可以同时为真（订阅激活延迟）。凡涉订阅/计费/激活状态之结论，写清测量时刻；用户说可用时先复测再回应，勿以旧结果顶撞

## 变更日志

### 1.4.1 (2026-08-29)
- 修正：B.4 矩阵重写——`sk-sp-` Token Plan key 已激活（2026-08-29 02:0x 实测），北京端点 chat+`GET /models` 双验 200；同 key 新加坡端点仍 401，钉死「订阅 key 按区域绑定」；01:13/01:30 两轮 401 系订阅未生效（激活延迟），非 key 错误——原「两端点均 401/订阅未激活」结论仅在当时成立
- 新增：B.4「铁律二」——凭据结论带时间戳、与用户对表；`/models` 列模型实测清单（含 `deepseek-v4-flash-0731`、`glm-5.2` 等跨厂商模型）；pi 认证源链（env → auth.json，GUI 启动无 env 则 401 + fallback，本次会话 `model_change` 实证）
- 新增：B.8 第 5 条思想经验「凭据结论必须带时间戳」
- 同步：config.fish QWEN Token Plan 注释改为已激活 + 区域绑定提示


### 1.4.0 (2026-08-29)
- 新增：附录 B「LLM API key 与 provider 配置实战（2026-08-29 实测）」八节——B.1 备份非真值源（真值源四序 + 整行锚点恢复脚本）、B.2 前缀锚点插入吞行致 key 静默丢失（真凶命令 + 二次整行替换销毁）、B.3 会话日志取证法（`~/.pi/agent/sessions/**.jsonl`）、B.4 阿里云 `sk-sp-`/`sk-ws-` key ↔ 端点配对矩阵（401 勿判死）、B.5 `fish -c source config.fish` 因 `status is-interactive` 守卫之假阴性、B.6 bl provider 语义（`env:VAR`、base_url 自动追加 `/chat/completions`、`--llm-provider` 空壳 flag、换 provider 须改 `llm.provider`）、B.7 最小改动纪律与 diff 自证、B.8 四条思想经验
- 新增：注意事项 14（key 空值先查真值源）、15（配置改动作用域 = 用户请求作用域）
- 新增：triggers「LLM provider 配置」「API key 恢复」
- 背景：2026-08-29 为 bl 接 `qwen3.8-flash`，牵出 `DEEPSEEK_API_KEY` 空值三日的取证与恢复全程

