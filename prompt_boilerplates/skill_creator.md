---
name: skill-creator
version: 2.0.0
description: 协助AI打包特定工作流程，创建符合pi-agent规范的skill文件
triggers:
  - "创建skill"
  - "新建skill"
  - "打包工作流"
  - "make skill"
  - "写一个skill"
  - "生成skill"
inputs:
  - name: skill_name
    description: 新skill的名称（英文小写，使用连字符分隔）
    required: true
  - name: description
    description: skill的简短描述（一句中文片段，不加句号）
    required: true
  - name: workflow_description
    description: 工作流程的详细描述
    required: true
  - name: output_dir
    description: skill输出目录
    required: false
    default: ~/prompt_boilerplates/
tools:
  - read
  - write
  - edit
  - glob
  - bash
  - grep
---

<!--
  ╔══════════════════════════════════════════════════════════╗
  ║  元指令：以下为 agent 执行指引，不写入生成的 skill 文件   ║
  ╚══════════════════════════════════════════════════════════╝
-->

# Skill 创建器

## 任务目标
根据用户描述的工作流程，创建符合 pi-agent 规范的 skill 文件。

---

## 执行流程

### 1. 读取参考文件

先从 `{output_dir}` 的子目录中读取 2-3 个已有 skill 文件作为风格参考：

```bash
glob 模式: "{output_dir}/**/*.md"
# 优先选择与目标 skill 同领域的已有文件
```

### 2. 提取工作流程要素

根据 `workflow_description` 分析：

1. **触发条件**：用户在什么场景下需要这个 skill
2. **输入参数**：需要哪些参数才能执行工作流
3. **所需工具**：执行工作流需要用到的 pi-agent 工具
4. **执行步骤**：详细的、可操作的工作流程步骤
5. **输出结果**：最终产出的内容与格式

### 3. 生成 Skill 文件

根据下方「Skill 格式规范」和提取的要素，生成完整的 skill 文件。

### 4. 验证格式

按照「生成检查清单」逐项验证。

### 5. 写入文件

使用 `write` 创建新文件（目标文件不存在时）或 `edit` 更新已有文件。

---

## 输出格式

在 `{output_dir}` 下创建 `{skill_name}.md` 文件。

完成后输出：
```text
✓ Skill 创建成功
文件路径: {output_dir}/{skill_name}.md
```

## 注意事项

- 若目标文件已存在，使用 `edit` 而非 `write` 覆写
- 生成后必须按「七、生成检查清单」逐项验证
- 若用户未提供足够的 workflow 细节，先追问再生成，不猜测

---

<!--
  ╔══════════════════════════════════════════════════════════╗
  ║  以下为 Skill 格式规范 —— 生成 skill 文件时的模板规则    ║
  ╚══════════════════════════════════════════════════════════╝
-->

# Skill 格式规范

---

## 一、标点符号与语言规范（优先阅读）

以下规则适用于 skill 文件的**正文部分**（Markdown 内容）。YAML front matter 和代码块中保持英文标点不变。

### 1.1 中文上下文中必须使用全角中文标点

中文正文中**禁止混用半角标点**。

| 正确 | 错误 | 说明 |
|------|------|------|
| `读取源文件，提取关键信息。` | `读取源文件, 提取关键信息.` | 中文逗号是 `，` 不是 `,` |
| `检查以下内容：` | `检查以下内容:` | 中文冒号是 `：` 不是 `:` |
| `步骤（详见附录）` | `步骤(详见附录)` | 中文括号是 `（）` 不是 `()` |
| `《论文标题》` | `"论文标题"` | 中文书名号是 `《》` 不是英文引号 |

**例外**：
- YAML front matter 内保持英文标点（`name: value`）
- 代码块内保持原语言标点
- 英文术语、文件名、命令保持英文标点（如 `read`、`glob`、`web_search`）
- 路径保持英文标点（如 `/home/user/skill.md`）

### 1.2 中文不使用斜体

中文字体没有真正的 italic，禁止 `*中文斜体*` 或 `_中文斜体_`。需要强调时用 `**粗体**`。

### 1.3 数字与中文间加半角空格

| 正确 | 错误 |
|------|------|
| `共 45 题` | `共45题` |
| `使用 2-4 个关键词` | `使用2-4个关键词` |
| `约 3 个步骤` | `约3个步骤` |

### 1.4 description 不加结尾标点

`description` 是**一句话片段**，无论中文还是英文，均不以 `。` 或 `.` 结尾。

| 正确 | 错误 |
|------|------|
| `从Markdown公式文件生成Anki闪卡(.apkg)` | `从Markdown公式文件生成Anki闪卡(.apkg)。` |
| `生成AP Calculus BC完整模拟试卷` | `生成AP Calculus BC完整模拟试卷。` |

### 1.5 代码块必须标注语言

所有 fenced code block 必须标注语言标识符。

```markdown
# 正确
```yaml
name: my-skill
```

# 错误
```
name: my-skill
```
```

### 1.6 段落间空行

- 每个 `##` 标题前保留一个空行（除非它是文件第一个内容行）
- 每个 `###` 标题前保留一个空行
- 列表前后各保留一个空行（可选但推荐）

---

## 二、YAML Front Matter

### 2.1 必须包含的字段（按此顺序）

```yaml
---
name: skill-name          # 英文小写 + 连字符，与文件名一致（不含 .md）
version: 1.0.0            # 语义化版本 X.Y.Z
description: 简短描述      # 一句中文片段，不加句号，不加引号
triggers:                 # 触发关键词列表，3-8 个
  - "关键词1"
  - "关键词2"
inputs:                   # 输入参数列表
  - name: param_name
    description: 参数说明
    required: true
  - name: optional_param
    description: 可选参数说明
    required: false
    default: 默认值       # required: false 时必须有 default
tools:                    # 所需 pi-agent 工具列表
  - read
  - write
---
```

### 2.2 字段详细规则

#### `name`
- 英文小写字母 + 连字符（kebab-case）
- **必须与文件名对应**：`name: my-skill` 对应文件 `my-skill.md`（文件名中用下划线 `_` 代替连字符 `-` 属于历史遗留，新 skill 应优先用连字符命名文件）
- 不含空格、驼峰、下划线
- 不含 `.md` 后缀

#### `version`
- 语义化版本 `X.Y.Z`
- 初始版本始终为 `1.0.0`

#### `description`
- 一句中文片段，不加引号
- 不加结尾标点（`。` 或 `.`）
- 描述具体功能，不应笼统（「帮助用户处理文件」→ 太模糊）

#### `triggers`
- **数量 3-8 个**
- 使用自然语言关键词，不使用正则表达式
- 具体、有辨识度，不应过于通用（「处理」「分析」→ 太宽泛）
- 中英文均可，同一 skill 中可混合

#### `inputs`
- 每个参数必须有 `name`、`description`、`required`
- `required: false` 时**必须**提供 `default`
- `default` 值规则：
  - 路径类：不带引号，用相对路径或 `~`/`$HOME` 路径（如 `./output`、`~/My_Dotfiles`、`$HOME/BOOKS/`），避免硬编码绝对路径
  - 字符串类：带引号（如 `"auto"`、`"normal"`）
  - 布尔类：不带引号（`true`、`false`）
  - 数字类：不带引号（`5`、`30`）
  - 空字符串默认值：`""`

#### `tools`
- 只列出 pi-agent 环境中真实可用的工具
- 无工具时为 `tools: []`（不允许省略或留空）
- **禁止使用 OpenCode 工具名**（如 `websearch_web_search_exa`、`webfetch`、`task`、`todowrite`、`look_at`）

### 2.3 可选扩展字段

以下字段允许但不强制：

```yaml
author: 作者名             # skill 作者
tags: [tag1, tag2]        # 分类标签（不用于触发匹配）
requires: [other-skill]   # 依赖的其他 skill name
status: active             # active | deprecated | superseded
superseded_by: new-skill  # 当 status: superseded 时，指向替代 skill
```

### 2.4 pi-agent 可用工具列表

```text
- read         读取文件内容
- write        创建/覆写文件
- edit         精确编辑文件（推荐用于已有文件）
- bash         执行 Shell 命令
- grep         文本搜索
- find         文件搜索
- ls           列出目录内容
- glob         通配搜索文件
- web_search   网络搜索（多 provider）
- fetch_content 获取网页/视频内容
- subagent     调用子代理执行任务
- todo_create  创建待办任务
- todo_update  更新待办任务
- ask_user     向用户提问
- memory_write 写入记忆
- memory_read  读取记忆
- memory_search 搜索记忆
- scratchpad   管理临时备忘
```

---

## 三、正文结构（必须包含）

每个 skill 的正文**必须**包含以下章节，按此顺序：

```markdown
# {Skill 标题}

（标题后正文开头，可选 1-2 句补充说明）

## 任务目标
（1-3 句话说明 skill 要解决什么问题、产出什么结果）

## 执行流程
（详细、可操作的步骤。每个步骤用 ### 编号子标题）

### 1. 步骤一

### 2. 步骤二

...

## 输出格式
（说明产出内容的格式、结构、示例）

## 注意事项
（边界情况、已知限制、安全提示、常见陷阱）
```

### 3.1 各章节内容要求

**语言选择**：全中文 skill 使用中文章节名（任务目标 / 执行流程 / 输出格式 / 注意事项）；全英文 skill 可使用英文章节名（## Goal / ## Workflow / ## Output Format / ## Notes），此时规则 1.1-1.4 的标点规范按英文惯例处理。中英混合 skill 以主体语言为准。

#### 任务目标
- 1-3 句话，清晰说明 skill 的用途
- 回答「这个 skill 是干什么的」

#### 执行流程
- 使用 `### 1. 步骤名` 格式编号
- 每个步骤包含：
  - 做什么（操作描述）
  - 用什么工具（如 `read`、`web_search`）
  - 为什么这样做（如有必要）
- 步骤粒度：一个步骤约等于一个独立可理解的操作单元

#### 输出格式
- 说明输出文件的类型（`.md`、`.tex`、`.apkg` 等）
- 说明输出内容的结构（字段、章节等）
- **提供具体示例**（如适用）

#### 注意事项
- 边界情况（如输入为空、文件不存在）
- 已知限制（如不支持某些格式）
- 安全提示（如敏感信息处理）
- 常见陷阱（如容易出错的地方）

---

## 四、LaTeX 输出规范（当 skill 涉及公式排版时）

如果创建的 skill 会生成 LaTeX 文档（如试卷、公式速查、闪卡等），**必须在 skill 正文中嵌入以下 LaTeX 公式与符号排版规范块**，放在「输出格式」或「注意事项」章节中。

### 4.1 绝对禁止：Unicode/ASCII 替代 LaTeX 符号

所有数学符号**必须用 LaTeX 命令**，禁止使用外观相似的 Unicode 字符或 ASCII 替代写法。

| 场景 | ✅ LaTeX 命令 | ❌ 禁止写法 |
|------|--------------|------------|
| 蕴涵/箭头 | `\to` `\rightarrow` `\Rightarrow` | → ⇒ `=>` |
| 量词 | `\forall` `\exists` | ∀ ∃ |
| 属于 | `\in` | ∈ |
| 否定 | `\neg` `\lnot` | ¬ |
| 合取/析取 | `\land` `\lor` | ∧ ∨ |
| 模态必然/可能 | `\Box` `\Diamond` | □ ◇ `[]` `<>` |
| 语义/语法后承 | `\models` `\vdash` | ⊨ ⊢ `\|=` `\|-` |
| 不等/约等 | `\neq` `\approx` | ≠ ≈ |
| 大于等于/小于等于 | `\ge` `\le` | ≥ ≤ |
| 点乘/叉乘 | `\cdot` `\times` | · × |
| 无穷 | `\infty` | ∞ |
| 常见希腊字母 | `\theta` `\mu` `\omega` `\pi` `\alpha` `\beta` `\delta` | θ μ ω π α β δ |
| 偏导/梯度 | `\partial` `\nabla` | ∂ ∇ |
| 积分/求和 | `\int` `\sum` | ∫ ∑ |
| 根号 | `\sqrt{}` | √（缺上横线） |
| 空集 | `\emptyset` | ∅ |

**规则：不确定某个符号的 LaTeX 命令时，查证后再写，绝不直接粘贴 Unicode。**

### 4.2 数学字体规范

| 用途 | 写法 | 示例 |
|------|------|------|
| 变量 | 默认斜体 | `$m$` `$v$` `$t$` |
| 物理单位 | `\mathrm{}` 正体 | `$\mathrm{kg}$` `$\mathrm{N\cdot m}$` |
| 多字母函数 | `\sin` `\log` `\mathrm{}` | `$\sin\theta$` `$\mathrm{KE}$` |
| 矢量 | `\vec{}` | `$\vec{F}$` |
| 数字与单位间 | `\,` 小空格 | `$5\,\mathrm{kg}$` |

### 4.3 公式排版上下文

| 位置 | 语法 | 用量 |
|------|------|------|
| 行内 | `$...$` | 默认首选，不少于 95% |
| 行内加大 | `$\displaystyle...$` | 复杂分式/积分时 |
| 独立展示 | `\[...\]` 或 `$$...$$` | 仅核心公式，不超过 5% |

表格中的公式一律用 `$...$` 行内。

### 4.4 书写规范

- **上下标**：多字符必须用花括号 —— `$v_{0}$`（正确），`$v_0$`（可能歧义）
- **分式**：行内用 `\frac{}{}`，表格中复杂分式用 `$\displaystyle\frac{}{}$`
- **省略号**：`\dots` `\cdots`，禁止三个句点 `...`
- **括号**：简单括号直接用 `(` `)`，花括号转义 `\{` `\}`

### 4.5 LaTeX 生成后自查

- [ ] 所有 Unicode 符号（→ ∀ ∃ ∈ ¬ 等）已替换为 LaTeX 命令
- [ ] 物理单位用 `\mathrm{}` 正体，数字与单位间有 `\,`
- [ ] 多字符下标用 `{...}` 包裹（`$v_{0}$` 不是 `$v_0$`）
- [ ] 数学函数名用正体（`$\sin$` `$\log$`，不是 `$sin$` `$log$`）
- [ ] 独立行间公式 `$$...$$` ≤ 内容的 5%

---

## 五、Subagent 调用规范

当 skill 需要委托子代理执行任务时，使用 pi-agent 的 `subagent` 语法：

```python
# 单代理调用
subagent({
  agent: "hephaestus",
  task: "具体任务描述",
  timeoutMs: 600000
})

# 并行调用
subagent({
  tasks: [
    { agent: "explore", task: "搜索代码库中的 X" },
    { agent: "momus", task: "审查 Y 的代码质量" }
  ],
  timeoutMs: 600000,
  clarify: false
})
```

### timeoutMs 推荐值

| 任务类型 | timeoutMs | 适用 agent |
|----------|-----------|------------|
| 轻量（搜索/编辑） | 300000 | explore, quick, librarian |
| 中等（分析/审查） | 600000 | deep, momus, oracle, prometheus, metis |
| 重量（构建/推理） | 900000 | hephaestus, ultrabrain |

**`timeoutMs` 是必填参数**，防止单个 agent 无限挂起。

---

## 六、易错问题清单

### 6.1 格式错误

#### ❌ name 使用空格或驼峰
```yaml
name: My Skill           # 错误
name: mySkill            # 错误
```
#### ✅ 使用 kebab-case
```yaml
name: my-skill
```

---

#### ❌ description 加句号
```yaml
description: 生成试卷。       # 错误
description: Generate exams.  # 错误
```
#### ✅ 不加结尾标点
```yaml
description: 生成AP Calculus BC完整模拟试卷
```

---

#### ❌ triggers 用正则或过于通用
```yaml
triggers:
  - "/生成.*/"           # 错误：正则
  - "处理"               # 错误：太通用
```
#### ✅ 具体自然语言
```yaml
triggers:
  - "生成anki闪卡"
  - "公式转闪卡"
```

---

#### ❌ required: false 没有 default
```yaml
inputs:
  - name: output_dir
    description: 输出目录
    required: false        # 错误：没有 default
```
#### ✅ 必须提供 default
```yaml
inputs:
  - name: output_dir
    description: 输出目录
    required: false
    default: ./
```

---

#### ❌ tools 列表使用 OpenCode 工具名
```yaml
tools:
  - websearch_web_search_exa   # 错误：OpenCode 工具名
  - webfetch                    # 错误：OpenCode 工具名
  - task                        # 错误：应改用 subagent
  - todowrite                   # 错误：应改用 todo_create
  - look_at                     # 错误：pi-agent 无此工具
```
#### ✅ 使用 pi-agent 工具名
```yaml
tools:
  - web_search
  - fetch_content
  - subagent
  - todo_create
```

---

#### ❌ tools 为空时省略或留空
```yaml
tools:                  # 错误：省略
# 或
tools:
                        # 错误：空
```
#### ✅ 显式空列表
```yaml
tools: []
```

---

#### ❌ Front matter 后缺少空行
```markdown
---
name: my-skill
---
# 标题    # 错误
```
#### ✅ Front matter 后保留一个空行
```markdown
---
name: my-skill
---

# 标题
```

---

#### ❌ 代码块未标注语言
````markdown
```
name: my-skill
```
````
#### ✅ 标注语言
````markdown
```yaml
name: my-skill
```
````

---

### 6.2 内容错误

#### ❌ 中文正文中混用英文标点
```markdown
读取源文件, 提取关键信息. 检查以下内容:
```
#### ✅ 中文用中文标点
```markdown
读取源文件，提取关键信息。检查以下内容：
```

---

#### ❌ 中文用斜体
```markdown
*注意*：此功能仅支持 PDF 格式
```
#### ✅ 中文用粗体
```markdown
**注意**：此功能仅支持 PDF 格式
```

---

#### ❌ 执行步骤过于笼统
```markdown
### 1. 读取文件
### 2. 处理内容
### 3. 输出结果
```
#### ✅ 提供详细可操作步骤
```markdown
### 1. 读取源文件
使用 read 工具读取 `{source}` 路径的文件内容。支持 .md 和 .txt 格式。

### 2. 提取关键信息
- 识别标题层级（匹配 `^#{1,3}\s`）
- 提取 LaTeX 公式（匹配 `$$...$$` 和 `$...$`）
- 记录分类标签（匹配 `#标签名`）

### 3. 格式转换
将提取的内容转换为 Anki 卡片格式，正面为题面，反面为答案...
```

---

#### ❌ 缺失输出格式说明
```markdown
## 输出
生成文件。
```
#### ✅ 明确输出格式和示例
```markdown
## 输出格式
生成 .apkg 文件，包含以下字段：

| 字段 | 内容 |
|------|------|
| Question | 问题面（LaTeX 公式） |
| Answer | 答案面（LaTeX 公式） |

示例卡片：
- **Question**: $\sin^2\theta + \cos^2\theta = ?$
- **Answer**: $1$
```

---

### 6.3 结构错误

#### ❌ 缺失强制章节
```markdown
# My Skill

## 执行流程
...（缺少「任务目标」「输出格式」「注意事项」）
```

#### ✅ 四个强制章节齐全
```markdown
# My Skill
## 任务目标
## 执行流程
## 输出格式
## 注意事项
```

---

## 七、生成检查清单

生成 skill 后，逐项检查：

### A. Front Matter 检查
- [ ] 文件存在 front matter（`---` 包裹）
- [ ] `name` 使用 kebab-case，与文件名对应（不含 `.md`，下划线文件名属历史遗留）
- [ ] 字段顺序为 name → version → description → triggers → inputs → tools
- [ ] `version` 格式为 `X.Y.Z`
- [ ] `description` 为无引号单行片段，无结尾标点，描述具体而非笼统
- [ ] `triggers` 数量 3-8 个，使用自然语言非正则
- [ ] `inputs` 每个参数都有 `name`、`description`、`required`
- [ ] `required: false` 的参数都有 `default`
- [ ] `default` 格式正确（路径无引号、字符串有引号）
- [ ] `tools` 不为空值（无工具时写 `tools: []`）
- [ ] 所有工具名均为 pi-agent 工具名（非 OpenCode 工具名）
- [ ] 若有 `status: superseded`，必须同时有 `superseded_by`

### B. 正文检查
- [ ] 包含 `## 任务目标`（1-3 句话）
- [ ] 包含 `## 执行流程`（`### N. 步骤名` 格式，步骤详细可操作）
- [ ] 包含 `## 输出格式`（说明产物类型、结构、有示例）
- [ ] 包含 `## 注意事项`（边界情况、已知限制、安全提示）
- [ ] Front matter 后有一个空行
- [ ] 所有代码块标注了语言
- [ ] 若使用 subagent 调用，每次调用都包含 `timeoutMs`
- [ ] 版本升级时，末尾追加了变更日志

### C. 标点与语言检查
- [ ] 中文正文使用全角中文标点（，。：（）「」《》等）
- [ ] YAML 和代码块中保持英文标点
- [ ] 中文内容不使用斜体（`*text*` 或 `_text_`）
- [ ] 数字与中文间有半角空格
- [ ] 段落间空行一致

### D. 内容质量检查
- [ ] 触发词具体、有辨识度
- [ ] 参数描述清晰、说明用途
- [ ] 工作流步骤完整、可独立执行
- [ ] 考虑了边界情况（输入为空、文件不存在等）
- [ ] 提供了具体示例（如适用）

### E. LaTeX 输出检查（如适用）
- [ ] 已包含 Unicode 符号禁止规则（含对照表）
- [ ] 已包含字体规范（正体单位 / 斜体变量）
- [ ] 已包含公式排版上下文选择规则
- [ ] 已包含书写规范（花括号下标、分式、省略号）
- [ ] 已包含生成后自查清单

---

## 八、变更日志格式约定

当 skill 升级 version 时，在文件末尾追加变更日志：

```markdown
## 变更日志

### 1.1.0 (YYYY-MM-DD)
- 新增：XXX 功能
- 修复：XXX 问题
- 修改：XXX 行为变更

### 1.0.0 (初始版本)
- 初始发布
```

---

## 九、文件组织与命名约定

### 9.1 目录结构

```text
prompt_boilerplates/
├── skill_creator.md          # 本文件
├── AGENTS.md                 # 全局 agent 指令
├── git_safety_net.md         # Git 安全网
├── content_safe_handler.md   # 内容安全处理器
├── Coding/                   # 编码与工程
├── Math/                     # 数学与试卷生成
├── Writing/                  # 写作与学术
├── Reading/                  # 阅读与翻译
├── System_Fix/              # 系统诊断与修复
├── Exercise/                 # 练习与题目
└── Note_Creating/           # 笔记生成
```

### 9.2 命名约定

- 文件名：`{skill-name}.md`，与 front matter `name` 字段完全一致
- 分类目录：按领域放入对应子目录
- 跨领域 skill：放入最相关的目录，或根目录

### 9.3 pi-agent 同步

如需在 pi-agent 中使用该 skill，将文件复制或链接到：

```text
~/.agents/skills/{分类}/{skill-name}.md
```

### 9.4 Skill 退役

当 skill 不再维护或被替代时，更新 front matter：

```yaml
status: deprecated          # 不再推荐使用
# 或
status: superseded          # 已被替代
superseded_by: new-skill    # 替代者 name（status: superseded 时必填）
```

---

<!--
  ╔══════════════════════════════════════════════════════╗
  ║  Git 安全网 + 文件写入安全（agent 执行指引）         ║
  ╚══════════════════════════════════════════════════════╝
-->

## 文件操作安全规则（agent 必读）

本 skill 遵守 Git 安全网规范。执行所有 `write`/`edit` 操作前：

1. **写入前先检查**：使用 `glob` 或 `read` 确认目标文件是否已存在
2. **已有文件优先用 `edit`**：如果文件已存在，使用 `edit` 追加/修改，而非 `write` 覆写
3. **`write` 仅用于新建**：确保目标文件确实不存在再使用 `write`
4. **覆写前确认**：如果必须覆写已有文件，先告知用户并获得明确许可

## 变更日志

### 2.0.0 (2026-07-26)
- 重大改版：OpenCode → pi-agent 工具名全面迁移
- 新增：第一章「标点符号与语言规范」（6 条硬性规则）
- 新增：第三章「正文结构」从推荐升级为强制（4 个必须章节）
- 新增：第五章「Subagent 调用规范」（含 timeoutMs 推荐值）
- 新增：第二章「可选扩展字段」（author、tags、status 等）
- 新增：第八章「变更日志格式约定」
- 新增：第九章「文件组织与命名约定」+「Skill 退役」机制
- 新增：英文 skill 语言选择指南（第三章）
- 修改：检查清单从 3 组扩展为 5 组（A-E），新增 15+ 检查项
- 修改：元指令与模板输出明确分离（HTML 注释标记）
- 修改：description 规则明确——不加结尾标点
- 修改：triggers 数量约束 3-8 个
- 修改：tools 为空时强制 `tools: []`
- 修改：default 值格式规则（路径无引号、字符串有引号，避免绝对路径）
- 修改：subagent 调用语法从 `subagent { }` 改为 `subagent({ })`
- 修改：模板正文 Unicode 符号替换为中文描述（≥→不少于 等）
- 修改：所有裸代码块标注语言（`text`）
- 修改：name 与文件名规则——承认下划线历史遗留
- 删除：OpenCode 工具名列表（`websearch_web_search_exa`、`webfetch`、`task`、`todowrite`、`look_at`）

### 1.0.0 (初始版本)
- 初始发布
