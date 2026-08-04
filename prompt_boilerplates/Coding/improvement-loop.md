---
name: iterative-improvement-loop
version: 1.4.0
description: 对代码库执行"修改→审查→修复→审查"的迭代改进循环，直至审查通过。基于 pi-agent 工具系统，使用 subagent 进行审查和修复。
triggers:
  - "改进循环"
  - "迭代优化"
  - "持续重构"
  - "improvement loop"
  - "refactoring loop"
  - "修复循环"
  - "迭代改进"
inputs:
  - name: target_path
    description: 要改进的目标代码库路径（目录或文件）
    required: true
  - name: max_iterations
    description: 最大循环次数，防止无限循环
    required: false
    default: 5
  - name: review_focus
    description: 审查重点，如 "architecture, code quality, and extensibility"
    required: false
    default: "code architecture, code quality, potential issues, and extensibility"
  - name: improvement_goal
    description: 改进目标描述，为空则由审查自主发现
    required: false
    default: ""
tools:
  - read
  - bash
  - write
  - edit
  - grep
  - find
  - subagent
  - todo_create
  - todo_update
  - todo_list
---

# 迭代改进循环 (Iterative Improvement Loop)

## 任务目标

对目标代码库执行一个自动化的闭循环：**修改 → 审查 → 修复 → 再审查**，直到审查判断无问题后退出。适用于以下场景：

- 对一段代码做完一轮修改后，希望检查是否存在疏漏或架构问题
- 希望持续打磨代码质量，直到满足架构标准
- 对大型重构进行分轮验证，逐步逼近理想状态
- 在实现新功能后，系统性检查可扩展性和边界情况

## 核心设计

```
┌──────────────────────────────────────────┐
│  1. 执行一轮修改（由用户主导或自主完成）      │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  2. 启动审查 subagent                     │
│     检查：架构、质量、问题、可扩展性          │
│     发现 → 输出问题列表                    │
│     无问题 → 标记 review_passed=true       │
└─────────────┬────────────────────────────┘
              ▼               ┌───────────┐
        有问题? ──────是────▶ 3. 启动修改  │
              │               subagent    │
              │               └─────┬─────┘
              │                     ▼
             否              回到步骤 2
              │
              ▼
┌──────────────────────────────────────────┐
│  4. 循环结束                              │
│     输出：审查报告 + 修改摘要              │
└──────────────────────────────────────────┘
```

## 执行流程

### 阶段 0：初始化

1. 读取 `target_path` 了解项目结构
2. 记录当前 git commit hash（如有 git 仓库），用于后续对比
3. 获取 `max_iterations` 和 `review_focus` 参数
4. 设置迭代计数器 `iteration = 0`
5. 通过 `todo_create` 创建可视化进度追踪

### 阶段 1：执行修改（由用户触发或自主完成）

在本阶段完成一轮代码修改。修改范围可以是：

- 用户直接提出的修改请求
- 前一轮审查发现的问题修复
- 基于 `improvement_goal` 的自主改进

每次修改后，使用 git 记录变更：
```bash
git add -A && git commit -m "iter-improve-loop: iteration {n} modifications"
```

本轮修改若产出可执行文件（Go/Rust/C++ 等），**构建并部署最新二进制到本地**（见 §3.4 与 `development-quality-gates.md` §关卡 11）——未部署 = 用户运行的仍是旧版。

### 阶段 2：审查（Review Subagent）

#### 2.1 启动审查 subagent

使用 `subagent` 工具启动同步审查（pi-agent 的 subagent 是同步的，返回结果直接可用）。推荐使用 Momus（批判性审查 agent）。

```python
review_result = subagent({
  agent: 'momus',
  task: '''
对 {target_path} 下的代码进行审查。

审查重点（{review_focus}）：

1. 代码架构层面：
   - 模块划分是否合理？
   - 有无循环依赖或职责不清？
   - 接口是否稳定、易于扩展？

2. 代码质量层面：
   - 有无潜在 bug 或逻辑错误？
   - 有无重复代码、死代码、过度工程？
   - 命名是否清晰、注释是否有价值？

3. 边界情况：
   - 有无遗漏的输入验证？
   - 错误处理是否完善？
   - 有无空指针、越界、并发问题？

4. 可扩展性：
   - 是否方便添加新功能？
   - 依赖关系是否可控？
   - 是否过度耦合？

输出格式：
- 如果无问题：输出 "REVIEW_PASSED: true"
- 如果有问题：输出问题列表，每个问题包含：
  - [严重程度: critical/major/minor]
  - [文件路径:行号]
  - [问题描述]
  - [建议修改方向]

请使用 read、bash、grep、find 等工具阅读代码。
  ''',
  timeoutMs: 120000
})
```

#### 2.2 获取审查结果

pi-agent 的 `subagent` 是同步的——调用后直接返回结果，无需 `agent_wait` / `agent_result`（这些工具在 pi-agent 中不存在）。

#### 2.3 判断是否通过

- 如果 subagent 输出包含 `REVIEW_PASSED: true` → **循环结束**
- 如果 subagent 输出问题列表 → 进入阶段 3

#### 2.4 处理特殊情形

| 情形 | 处理 |
|------|------|
| subagent 超时或失败 | 增加 `timeoutMs` 重试一次（如 `timeoutMs: 180000`），仍失败则标记结果不可靠并询问用户 |
| 问题过多（>20 条） | 仅选取 critical + major 级别的处理，剩下的留到下一轮 |
| `iteration >= max_iterations` | 强制退出循环，输出已完成内容和剩余问题 |

### 阶段 3：修复（Fix Subagent）

#### 3.1 拆分问题

将审查发现的问题按严重程度排序：

1. **critical**：直接 bug、空指针、安全漏洞、数据丢失风险
2. **major**：架构缺陷、接口设计问题、复杂度过高、异常处理缺失
3. **minor**：命名不当、注释缺失、代码风格、轻微冗余

**分批策略**：每轮修复一批问题，批次上限按问题数量灵活决定：
- 1-5 个问题 → 全部修复
- 6-15 个问题 → 先修 critical + major
- 16+ 个问题 → 每轮修最多 10 个问题

#### 3.2 启动修复 subagent

对每个批次，使用 `subagent` 启动修复（推荐使用 Hephaestus，专注于实现和修复）：

```python
subagent({
  agent: 'hephaestus',
  task: '''
请根据以下问题列表修复 {target_path} 的代码。

问题列表：
[{问题1}]
[{问题2}]
...

要求：
1. 每个修改请使用 read 先确认代码上下文，再用 edit 修改
2. 修改前用 git 快照：git add -A && git commit -m "..."
3. 修改后用 git commit 记录变更
4. 不要修改与问题无关的代码
5. 如果一个问题需要多个文件联动修改，请一次性完成
  ''',
  timeoutMs: 180000
})
```

#### 3.3 验证修复

修复完成后，快速验证：
- 修改的文件是否存在语法错误（通过 `bash` 运行编译器/检查工具）
- 问题文件中描述的变更是否确实被执行（抽查 `read`）

如有语法错误，在同一 subagent 内修复。

#### 3.4 部署最新二进制（本 skill 强制要求）

修复验证通过后，若项目产出可执行文件，**必须构建并安装最新二进制到本地**（`~/.local/bin` 或项目约定位置），并运行 smoke 验证：

```bash
# Go 示例
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o ~/.local/bin/<name> .
<name> --version   # 或 smoke 命令，确认新版已生效
```

- **未部署 = 改动未生效**——用户运行的是 `PATH` 中的旧二进制
- 多二进制项目（如 bl 的 telegram/dingtalk 子命令）逐个全部部署，不只装主命令
- 服务类项目部署后重启对应 systemd user 单元（`systemctl --user restart <service>`）
- 详见 `development-quality-gates.md` §关卡 11「本地二进制部署」

### 阶段 4：循环

`iteration += 1`，回到阶段 2。注意：pi-agent 的 `subagent` 是同步的，循环由编排器（orchestrator）代码驱动——每次调用返回后检查结果，决定是继续修复还是结束。

### 阶段 5：完成

循环结束后，输出：

```
=== 迭代改进循环完成 ===
循环次数: {n}
目标路径: {target_path}

=== 修改摘要 ===
{列出主要变更}

=== 审查结论 ===
{审查 subagent 的最终评价}

=== 部署状态 ===
最新二进制已构建并安装到本机: {~/.local/bin/<name>}（版本 {v}，smoke 验证 ✅/❌）

=== 剩余问题（如有） ===
{被标记为 "留待后续" 的问题列表}
```

## 输出格式

### 每轮迭代摘要（循环进行中）

```
━━━ 迭代 {n}/{max_iterations} ━━━
发现 {m} 个问题：
  [critical] file.rs:42 — ...
  [major]    mod.rs:15 — ...
  [minor]    file.rs:88 — ...
已修复 {k} 个问题，进入下一轮审查
```

### 循环结束报告

```
=== 迭代改进循环完成 ===
循环次数: 3
目标路径: /path/to/project

=== 修改摘要 ===
- 重构了模块 A 的接口，消除了循环依赖
- 为所有 API 端点添加了输入校验
- 提取了重复的逻辑为公共工具函数
- 补充了 12 处错误处理和 3 处并发保护

=== 审查结论 ===
REVIEW_PASSED: true — 架构合理、无关键问题、代码质量达标

=== 变更文件 ===
- src/module_a.rs (6 处修改)
- src/module_b.rs (3 处修改)
- src/utils.rs (新建)
```

## 注意事项

### 防止无限循环

1. **`max_iterations` 硬上限**：达到后强制退出，无论审查是否通过
2. **问题数量递减检查**：如果连续两轮发现的问题数量不减反增，说明修改方向不对，应退出循环并报告
3. **相同问题重复出现**：如果同一问题在连续两轮审查中都出现且未被有效修复，标记为 "顽固问题"，跳出循环让用户决策
4. **空循环保护**：如果没有做任何修改却通过了审查的第一轮，这算通过（不做无谓循环）

### Subagent 管理

1. **超时处理**：通过 `subagent({ timeoutMs: ... })` 设置超时。审查用 `timeoutMs: 120000`（2 分钟），修复用 `timeoutMs: 180000`（3 分钟）。超时后增加超时时间重试一次
2. **上下文隔离**：pi-agent 使用 `context` 参数控制上下文。`context: 'fork'` 继承当前会话上下文，`context: 'fresh'` 使用干净上下文。审查 subagent 建议用 `context: 'fork'`
3. **结果验证**：修复 subagent 返回后，抽查 1-2 个修改点确认变更真正落地
4. **不要并行**：审查和修复是串行的——下一轮必须等上一轮审查结果出来后再决定。pi-agent 的 subagent 默认同步执行，天然满足这一约束

### Git 安全网

本 skill 遵守 [Git 安全网规范](git_safety_net.md)。每次修改前执行 git 快照，每次修改后提交。确保所有变更都可追溯、可回滚。

### 适用边界

| 场景 | 适用性 |
|------|--------|
| 代码重构 | ✅ 核心场景 |
| 功能实现后质量检查 | ✅ 高度适用 |
| 修复 bug 后验证 | ✅ 适用 |
| 新增 API 端点 | ✅ 可用 |
| 纯文档修改 | ⚠️ 只检查结构和链接 |
| 二进制/配置文件 | ❌ 不适用 |
| 首次代码编写 | ❌ 不是从零生成，而是改进已有代码 |

### 与用户互动

1. **首次启动时**：输出当前代码状态的摘要（文件数、行数、复杂度粗略评估）
2. **发现问题时**：列出问题并简要说明每个问题的风险，让用户了解循环在做什么
3. **强制退出时**：解释为什么退出（达到迭代上限 / 问题不减反增 / 顽固问题），给用户后续建议
4. **用户可随时中断**：一旦用户介入给出新指令，停止当前循环按新指令执行

---

## §5：编排实践经验

> 以下经验来自 `news-report` 项目的实际 subagent 编排过程。每条经验包含问题描述、教训提炼、反例与正例。

### 5.1 Chain 调用必须传 `clarify: false`

**问题**：在 `subagent({ chain: [...] })` 中未传 `clarify: false` 时，系统会弹出交互式 TUI 等待用户确认每一步，导致本应全自动执行的编排流程完全阻塞，直到人工介入。

**教训**：任何 chain 调用都必须显式传递 `clarify: false`。这不是可选优化，而是编排器能否无人值守运行的前提条件。

**反例**：
```javascript
// ❌ 缺少 clarify — 每一步都会弹出 TUI 等待确认
subagent({
  chain: [
    { agent: 'explore', task: '检查项目结构' },
    { agent: 'momus', task: '审查代码' }
  ]
})
```

**正例**：
```javascript
// ✅ 显式 clarify: false — 全自动串行执行
subagent({
  chain: [
    { agent: 'explore', task: '检查项目结构' },
    { agent: 'momus', task: '审查代码' }
  ],
  clarify: false
})
```

### 5.2 `timeoutMs` 必须显式设置

**问题**：subagent 调用未传 `timeoutMs` 时，单个慢 agent 可能无限挂起，阻塞整个编排流程。实际遇到过某 agent 因文件 I/O 或网络等待静默卡住数十分钟的情况。

**教训**：每一次 subagent 调用都必须根据任务复杂度显式设置 `timeoutMs`。超时后编排器可以继续推进（重试、跳过、或降级），而不是无限等待。

**推荐值**：

| 任务级别 | 适用 agent | timeoutMs |
|----------|-----------|-----------|
| 轻量 | explore, quick, librarian | 300,000 (5 min) |
| 中等 | deep, momus, oracle, prometheus, metis | 600,000 (10 min) |
| 重量 | hephaestus, ultrabrain | 900,000 (15 min) |
| Chain | 多步串行 | 各步推荐值之和，最低 600,000 |

**反例**：
```javascript
// ❌ 无超时 — 可能永久挂起
subagent({ agent: 'momus', task: '审查全部代码' })
```

**正例**：
```javascript
// ✅ 显式超时 — 600s 后编排器可恢复控制
subagent({ agent: 'momus', task: '审查全部代码', timeoutMs: 600000 })
```

### 5.3 资源感知调度

**问题**：未检查系统资源就批量发起 subagent，在高负载时导致 OOM、CPU 颠簸、或 subagent 自身因资源不足而失败，造成级联重试。

**教训**：在发起任何 `subagent({ tasks: [...] })`、`subagent({ chain: [...] })` 或重量级 agent（hephaestus/ultrabrain/deep）之前，必须先执行 `pi-resmon --recommend` 并根据 `ACTION` 字段调整策略：

| ACTION | 含义 | 应对 |
|--------|------|------|
| `free_parallel` | 资源充裕，自由并行 | 正常 fan-out |
| `restricted_parallel` | 部分受限 | 并行数 ≤ `MAX_PARALLEL`，仅用 `WEIGHT_AGENTS` 允许的 agent |
| `serialize_only` | 资源紧张 | 改为串行执行 |
| `defer_or_direct` | 资源不足 | 不启动 subagent，直接自行处理 |

同时应用 `SUGGESTED_MAXTURNS_FACTOR` 缩放 `turnBudget.maxTurns`，`SUGGESTED_TIMEOUTMS_FACTOR` 缩放 `timeoutMs`。若 `WARNINGS` 含 `disk_usage>90%`，避免写入大文件。

详见 `resource-aware-delegation.md`。

**反例**：
```bash
# ❌ 不检查资源，直接并行启动 6 个重量 agent
subagent({ tasks: [
  { agent: 'hephaestus', ... },
  { agent: 'hephaestus', ... },
  { agent: 'deep', ... },
  ...
]})
```

**正例**：
```bash
# ✅ 先评估资源，再决定调度策略
pi-resmon --recommend --class heavy
# → ACTION: restricted_parallel, MAX_PARALLEL: 2
# → 调整为最多并行 2 个，其余串行
```

### 5.4 Edit 批量操作全有或全无

**问题**：调用 `edit` 工具时传入多个 `edits`，若其中某一项的 `oldText` 匹配失败（文本不存在或已被前一批次修改），整个批次的**所有**编辑都不会应用。这容易导致"明明只差一处匹配失败，其他正常修改也一起丢失"的惊讶行为。

**教训**：`edit` 的 `edits` 数组具有原子性——全成功或全回滚。分批操作时，确保每批的 `oldText` 都能在当前文件内容中唯一定位。**不要将多个不相关的修改放在同一个 `edit` 调用中**，一个匹配失败会连累其他。

**反例**：
```javascript
// ❌ 两处修改打包在一个 edit 调用 — 一处失败则全部回滚
edit({
  path: 'main.go',
  edits: [
    { oldText: 'line A old', newText: 'line A new' },  // 若这一行已被前次改过 → 匹配失败
    { oldText: 'line B old', newText: 'line B new' }   // → 这一行也不会被应用
  ]
})
```

**正例**：
```javascript
// ✅ 独立修改分开调用 — 每个 edit 自我完整
edit({ path: 'main.go', edits: [{ oldText: 'line A old', newText: 'line A new' }] })
// 确认成功后再改另一处
edit({ path: 'main.go', edits: [{ oldText: 'line B old', newText: 'line B new' }] })
```

### 5.5 视图级按键处理完整性（TUI 专项）

**问题**：在 TUI 中新增功能键（如 `o` 打开浏览器、`c` 复制链接）时，只在列表视图的 `handleListKey` 中添加了处理，漏掉了阅读器视图的 `handleReaderKey` 和过滤视图的处理函数。结果：用户在阅读器中按 `o` 无反应，行为不一致。

**教训**：TUI 中每个用户可见的功能键，必须在**所有**视图级按键处理函数中实现——列表视图、阅读器视图、过滤视图、帮助视图等。新增按键后，用 `grep` 搜索现有的 `case 'x':` 模式，确认每个 `handle*Key` 函数中都有对应分支。

**反例**：
```go
// ❌ 只在列表视图加了 'o' 键处理，阅读器视图遗漏
func (m Model) handleListKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
    switch msg.String() {
    case "o":
        return m, openBrowserCmd(m.selectedURL)  // ✅ 列表视图有
    // ...
    }
}

func (m Model) handleReaderKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
    switch msg.String() {
    case "q":
        return m, backToListCmd
    // ❌ 遗漏 'o' — 阅读器中按 o 无反应
    }
}
```

**正例**：
```go
// ✅ 新增按键后，用 grep 搜索所有 handle*Key 函数确认覆盖
// $ grep -n "handle.*Key" internal/ui/*.go
// → 列表: handleListKey (line 312)
// → 阅读器: handleReaderKey (line 478)
// → 过滤视图: handleFilterKey (line 601)
// → 每个函数中都有 case "o": 分支
```

### 5.6 字符串存储类型的选择（Go 专项）

**问题**：在 TUI 文本输入框中用 `string` 存储光标位置，通过 byte 索引来移动光标。当输入包含多字节 UTF-8 字符（中文、emoji）时，byte 索引越界或光标定位错误，出现"光标走到字符中间"的显示异常。多次尝试在 byte 和 rune 之间转换修复，代码越来越复杂且容易出错。

**教训**：对于需要光标编辑的输入文本，直接用 `[]rune` 存储比用 `string` + byte 索引更安全、代码更简洁。这从根本上消除了所有与 UTF-8 多字节编码相关的边界错误。仅在最终渲染（传给 bubbletea View）时才转为 `string`。

**反例**：
```go
// ❌ string + byte 索引 — 中文/emoji 导致光标错位
type InputModel struct {
    text   string
    cursor int  // byte 位置，多字节字符前 = 灾难
}

func (m *InputModel) cursorLeft() {
    if m.cursor > 0 {
        m.cursor--  // ❌ 可能移动到某个 rune 的中间字节
    }
}
```

**正例**：
```go
// ✅ []rune — 光标始终在字符边界上
type InputModel struct {
    text   []rune
    cursor int  // rune 位置，天然安全
}

func (m *InputModel) cursorLeft() {
    if m.cursor > 0 {
        m.cursor--  // ✅ 始终移动一个完整字符
    }
}

// 仅在渲染时转 string
func (m InputModel) View() string {
    return string(m.text)
}
```

---


### 5.7 Turn 预算保护 — 防止实现 agent 输出丢失

**问题**：在 `chain` 中，hephaestus 完成全部代码实现（读取文件、编辑、编译、测试）后，耗尽了所有 turns，没有剩余 turns 用来生成输出摘要。结果输出 artifact 为 0 字节，后续步骤（如 momus 审查）看不到实现总结。

**根因**：未设置 `turnBudget`，agent 的 turns 预算无限但实际受系统默认限制。实现类 agent 需要大量 tool calls，若不预留 turns 给最后的输出总结，最终消息不会被写入 artifact。

**教训**：
1. **实现 agent 必须设 `turnBudget`**，且 `maxTurns` 需大于预期 tool calls 数 + 至少 3 turns 留给输出
2. **`graceTurns` 是安全网**：当 `maxTurns` 耗尽时，agent 得到额外机会"收尾"
3. **chain 中每步 agent 都应独立设置 `turnBudget`**

**推荐值**：

| Agent 类型 | maxTurns | graceTurns | 理由 |
|------------|----------|------------|------|
| explore / quick | 15 | 2 | 读文件 + 少量编辑 |
| prometheus / metis | 20 | 3 | 读文件 + 输出计划 |
| momus / oracle | 25 | 3 | 读文件 + 输出报告 |
| hephaestus | 35 | 5 | 读 + 多文件编辑 + 编译 + 测试 + 输出 |
| ultrabrain | 40 | 5 | 复杂推理链 |

**反例**：
```javascript
// ❌ 无 turnBudget — hephaestus 用完默认限额后输出丢失
subagent({ chain: [
  { agent: 'hephaestus', task: 'Implement feature' },
  { agent: 'momus', task: 'Review' }
]})
```

**正例**：
```javascript
// ✅ 显式 turnBudget + graceTurns
subagent({ chain: [
  { agent: 'hephaestus', task: 'Implement feature',
    turnBudget: { maxTurns: 35, graceTurns: 5 } },
  { agent: 'momus', task: 'Review',
    turnBudget: { maxTurns: 25, graceTurns: 3 } }
]})
```

### 5.8 Edit 预验证模式 — 批量编辑前检查匹配

**问题**：`edit` 工具批量处理多个 `edits`，若任一 `oldText` 不匹配（文件已被修改、缩进差异），整个批次全部回滚。在连续多次 edit 调用时尤其容易触发：前一次修改改变了后续 edit 的匹配目标。

**根因**：edit 原子性（全有或全无）+ 无前置验证。一条 oldText 的匹配失败导致所有修改丢失。

**教训**：执行多步修改时，在每次 `edit` 调用前先用 `grep` 确认每条 `oldText` 存在于文件中且唯一。分小批执行（2-3 条/批），每批后验证。

**预验证模式**：
```bash
# 步骤 1：验证所有 oldText 存在且唯一
grep -n 'exact old text 1' target.go
grep -n 'exact old text 2' target.go
# 步骤 2：分小批执行
edit({ path: 'target.go', edits: [
  { oldText: 'line 1 old', newText: 'line 1 new' },
  { oldText: 'line 2 old', newText: 'line 2 new' }
]})
# 步骤 3：验证结果
grep -n 'line 1 new' target.go
# 步骤 4：继续下一批
```

**注意**：Python `str.replace()` 对批量替换更可靠——即使部分匹配失败，其余匹配仍生效。对于大量重复替换，优先用 Python 脚本预处理。

### 5.9 Chain 输出门控 — 防止空输出传播

**问题**：chain 中某步 agent 完成工作但输出 artifact 为空（turn 耗尽），后续步骤看不到上游总结，只能从零开始。

**根因**：chain 不对步骤输出做门控验证。即使某步输出为空，chain 仍继续执行下一步。

**教训**：
1. **在重量级步骤后插入 `checkpoint`**——让编排器检查上游输出是否有效
2. **对 hephaestus 设 `acceptance: "checked"`**——要求 agent 自我验证
3. **用 `outputSchema` 约束输出格式**——确保包含必要字段（文件清单、变更摘要）

**正例**：
```javascript
subagent({ chain: [
  { agent: 'prometheus', task: 'Design plan',
    outputSchema: { type: 'object', required: ['files', 'steps'] } },
  { checkpoint: 'review-plan', message: '确认计划' },
  { agent: 'hephaestus', task: 'Implement {previous}',
    turnBudget: { maxTurns: 35, graceTurns: 5 },
    acceptance: 'checked',
    outputSchema: { type: 'object', required: ['summary', 'files_changed'] } },
  { checkpoint: 'verify-output', message: '确认输出有效' },
  { agent: 'momus', task: 'Review {previous}',
    turnBudget: { maxTurns: 25, graceTurns: 3 } }
], clarify: false})
```


## 相关技能

- **预防性质量关卡**：`development-quality-gates.md` — 在写代码时逐条对照 11 个关卡，预防本循环中会被审查出来的大部分问题。建议在循环开始前先过一次关卡清单。
- **ML 训练自优化闭环**：`ml-training.md` §11 提供了专门针对机器学习训练场景的优化循环变体
- **文档更新协议**：`project-documentation-protocol.md` §阶段B — 循环结束后必须按协议更新文档、重建 graphify
- **资源感知调度**：`resource-aware-delegation.md` — 本循环使用 subagent（momus 审查 + hephaestus 修复），每次调用前应检查系统资源
- **Git 安全网**：本技能依赖的 git 快照规范见 `git_safety_net.md`
- **交互式 CLI/TUI 审查标准**：`interactive-cli-design.md` §5 验收清单——审查交互工具时逐条打勾，替代通用审查焦点
- **本地二进制部署**：`development-quality-gates.md` §关卡 11——循环每一轮修改后必须构建并安装最新二进制到本地（§3.4）
- **Turn 预算速查**：§5.7 推荐值表——启动 subagent 前查表设置 `turnBudget`

---

## 变更日志

### 1.4.0 (2026-08-03)
- 新增：§5.7–5.9 Chain 输出捕获与 turn 预算——从 news-report 项目 chain 中 subagent 输出丢失事故提取
  - 5.7 turn 预算保护：实现 agent 必须设 `turnBudget`，留足够 turns 给输出
  - 5.8 Edit 预验证模式：批量 edit 前先 `grep` 验证 oldText 存在
  - 5.9 Chain 输出门控：用 `checkpoint` + `acceptance` 防止空输出传播

### 1.3.0 (2026-08-03)
- 新增：§5「编排实践经验」——从 news-report 项目的 subagent 编排中提取 6 条实战经验
  - 5.1 Chain 调用必须传 `clarify: false`
  - 5.2 `timeoutMs` 必须显式设置（含推荐值速查表）
  - 5.3 资源感知调度（`pi-resmon --recommend` 前置检查）
  - 5.4 Edit 批量操作原子性（全有或全无）
  - 5.5 TUI 视图级按键处理完整性（所有 `handle*Key` 函数必须覆盖）
  - 5.6 字符串存储类型选择（`[]rune` 优于 `string`+byte 索引，Go 专项）

### 1.2.0 (2026-08-03)
- 新增：§3.4「部署最新二进制」——每轮修改验证通过后必须构建并安装最新二进制到本地（`~/.local/bin`），未部署 = 改动未生效
- 新增：阶段 1 修改后部署提醒 + 阶段 5 输出增加「部署状态」
- 新增：相关技能增加 `development-quality-gates.md` §关卡 11 引用
