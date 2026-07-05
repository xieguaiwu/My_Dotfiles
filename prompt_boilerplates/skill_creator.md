---
name: skill-creator
version: 1.0.0
description: 协助AI打包特定工作流程，创建符合规范的skill文件
triggers:
  - "创建skill"
  - "新建skill"
  - "打包工作流"
  - "make skill"
inputs:
  - name: skill_name
    description: 新skill的名称（英文，使用连字符分隔）
    required: true
  - name: description
    description: skill的简短描述
    required: true
  - name: workflow_description
    description: 工作流程的详细描述
    required: true
  - name: output_dir
    description: skill输出目录
    required: false
    default: "/home/xieguiawu/prompt_boilerplates/"
tools:
  - read
  - write
  - glob
---

# Skill 创建器

## 任务目标
根据用户描述的工作流程，创建符合规范格式的 skill 文件。

## 执行流程

### 1. 分析现有 Skill 格式

首先读取目录下已有的 skill 文件，分析其格式结构：

```bash
# 读取现有 skill 文件作为参考
```

**标准格式模板**：

```markdown
---
name: {skill名称}
version: 1.0.0
description: {简短描述}
triggers:
  - "{触发词1}"
  - "{触发词2}"
inputs:
  - name: {参数名}
    description: {参数描述}
    required: {true/false}
    default: {默认值}
tools:
  - {工具1}
  - {工具2}
---

# {Skill标题}

{主要内容...}
```

### 2. 提取工作流程要素

根据 `workflow_description` 分析：

1. **触发条件**：用户在什么场景下需要这个 skill
2. **输入参数**：需要哪些参数才能执行工作流
3. **所需工具**：执行工作流需要用到哪些工具
4. **执行步骤**：详细的工作流程步骤
5. **输出结果**：最终产出的内容

### 3. 生成 Skill 文件

根据模板和提取的要素，生成完整的 skill 文件。

---

## 格式规范（必读）

### YAML Front Matter

**必须包含的字段**：

```yaml
---
name: skill-name          # 使用小写字母和连字符
version: 1.0.0            # 版本号
description: 简短描述      # 一句话描述skill功能
triggers:                 # 触发关键词列表
  - "关键词1"
  - "关键词2"
inputs:                   # 输入参数列表
  - name: param_name
    description: 参数说明
    required: true/false
    default: 默认值       # 仅 required: false 时需要
tools:                    # 所需工具列表
  - tool_name
---
```

### 正文结构

推荐使用以下结构：

```markdown
# {Skill标题}

## 任务目标
简要说明skill的目标

## 执行流程
### 1. 步骤一
### 2. 步骤二
...

## 输出格式
说明输出内容的格式

## 注意事项
重要提醒
```

---

### LaTeX 输出规范（当 skill 涉及公式排版时）

如果创建的 skill 会生成 LaTeX 文档（如试卷、易错清单、公式速查、闪卡等），**必须在 skill 正文中嵌入以下 LaTeX 公式与符号排版规范块**，确保下游 agent 一步到位生成合规的 LaTeX 源码，无需重头提取规则。

将此块整体复制到 skill 的「输出格式」或「注意事项」章节：

```markdown
### LaTeX 公式与符号排版规范

#### ① 绝对禁止：Unicode/ASCII 替代 LaTeX 符号

所有数学符号**必须用 LaTeX 命令**，禁止使用外观相似的 Unicode 字符或 ASCII 替代写法。

| 场景 | ✅ LaTeX 命令 | ❌ 禁止写法 |
|------|--------------|------------|
| 蕴涵/箭头 | `\to` `\rightarrow` `\Rightarrow` | → ⇒ `=>` |
| 量词 | `\forall` `\exists` | ∀ ∃ |
| 属于 | `\in` | ∈ |
| 否定 | `\neg` `\lnot` | ¬ |
| 合取/析取 | `\land` `\lor` | ∧ ∨ |
| 模态必然/可能 | `\Box` `\Diamond` | □ ◇ `[]` `<>` |
| 语义/语法后承 | `\models` `\vdash` | ⊨ ⊢ `|=` `|-` |
| 不等/约等 | `\neq` `\approx` | ≠ ≈ |
| 大等于/小等于 | `\ge` `\le` | ≥ ≤ |
| 点乘/叉乘 | `\cdot` `\times` | · × |
| 无穷 | `\infty` | ∞ |
| 常见希腊字母 | `\theta` `\mu` `\omega` `\pi` `\alpha` `\beta` `\delta` | θ μ ω π α β δ |
| 偏导/梯度 | `\partial` `\nabla` | ∂ ∇ |
| 积分/求和 | `\int` `\sum` | ∫ ∑ |
| 根号 | `\sqrt{}` | √（缺上横线） |
| 空集 | `\emptyset` | ∅ |

**规则：不确定某个符号的 LaTeX 命令时，查证后再写，绝不直接粘贴 Unicode。**

#### ② 数学字体规范

| 用途 | 写法 | 示例 |
|------|------|------|
| 变量 | 默认斜体 | `$m$` `$v$` `$t$` |
| 物理单位 | `\mathrm{}` 正体 | `$\mathrm{kg}$` `$\mathrm{N\cdot m}$` |
| 多字母函数 | `\sin` `\log` `\mathrm{}` | `$\sin\theta$` `$\mathrm{KE}$` |
| 矢量 | `\vec{}` | `$\vec{F}$` |
| 数字与单位间 | `\,` 小空格 | `$5\,\mathrm{kg}$` |

#### ③ 公式排版上下文

| 位置 | 语法 | 用量 |
|------|------|------|
| 行内 | `$...$` | **默认首选，≥95%** |
| 行内加大 | `$\displaystyle...$` | 复杂分式/积分时 |
| 独立展示 | `\[...\]` 或 `$$...$$` | 仅核心公式，≤5% |

表格中的公式一律用 `$...$` 行内，不乱版面。

#### ④ 书写规范

- **上下标**：多字符必须用花括号 —— `$v_{0}$`（正确）✓，`$v_0$`（可能歧义）△
- **分式**：行内用 `\frac{}{}`，表格中复杂分式用 `$\displaystyle\frac{}{}$`
- **省略号**：`\dots` `\cdots`，禁止三个句点 `...`
- **括号**：简单括号直接用 `(` `)`，花括号转义 `\{` `\}`

#### ⑤ 生成后自查

- [ ] 所有 Unicode 符号（→ ∀ ∃ ∈ ¬ 等）已替换为 LaTeX 命令
- [ ] 物理单位用 `\mathrm{}` 正体，数字与单位间有 `\,`
- [ ] 多字符下标用 `{...}` 包裹（`$v_{0}$` 不是 `$v_0$`）
- [ ] 数学函数名用正体（`$\sin$` `$\log$`，不是 `$sin$` `$log$`）
- [ ] 独立行间公式 `$$...$$` ≤内容的 5%

---

## 易错问题清单

### 格式错误

#### ❌ 错误：name 使用空格或驼峰命名
```yaml
name: My Skill           # 错误：包含空格
name: mySkill            # 错误：驼峰命名
```

#### ✅ 正确：使用小写字母和连字符
```yaml
name: my-skill           # 正确
name: anki-flashcard-generation  # 正确
```

---

#### ❌ 错误：triggers 使用正则表达式
```yaml
triggers:
  - "/生成.*闪卡/"       # 错误：不要使用正则
```

#### ✅ 正确：使用自然语言关键词
```yaml
triggers:
  - "生成闪卡"
  - "anki卡片"
```

---

#### ❌ 错误：inputs 缺少 default 但 required 为 false
```yaml
inputs:
  - name: output_dir
    description: 输出目录
    required: false       # 错误：required为false但没有default
```

#### ✅ 正确：非必需参数必须提供默认值
```yaml
inputs:
  - name: output_dir
    description: 输出目录
    required: false
    default: "./"         # 正确：提供默认值
```

---

#### ❌ 错误：tools 列出不可用的工具
```yaml
tools:
  - image_read           # 如果环境中没有这个工具
  - nonexistent_tool     # 不存在的工具
```

#### ✅ 正确：只列出可用工具
```yaml
tools:
  - read
  - write
  - bash
  - websearch_web_search_exa
  - task                 # 用于调用 agent
```

**可用工具列表**：
- `read`, `write`, `edit`
- `glob`, `read`（目录列表）, `grep`
- `bash`
- `websearch_web_search_exa`, `webfetch`
- `look_at`
- `task`（调用 subagent）
- `todowrite`

---

### 内容错误

#### ❌ 错误：描述过于笼统
```yaml
description: 帮助用户处理文件
```

#### ✅ 正确：描述具体功能
```yaml
description: 从Markdown公式文件生成Anki闪卡(.apkg)
```

---

#### ❌ 错误：触发词过于通用
```yaml
triggers:
  - "处理"
  - "分析"
```

#### ✅ 正确：使用具体、有辨识度的触发词
```yaml
triggers:
  - "生成anki闪卡"
  - "公式转闪卡"
```

---

#### ❌ 错误：工作流描述缺少细节
```markdown
## 执行流程
1. 读取文件
2. 处理内容
3. 输出结果
```

#### ✅ 正确：提供详细的执行步骤
```markdown
## 执行流程

### 1. 读取源文件
使用 read 工具读取指定路径的文件内容。

### 2. 提取关键信息
- 识别标题层级
- 提取公式内容（匹配 `$$...$$` 格式）
- 记录分类信息

### 3. 格式转换
将提取的内容转换为 Anki 卡片格式...
```

---

#### ❌ 错误：未说明输出格式
```markdown
## 输出
生成文件
```

#### ✅ 正确：明确输出格式和示例
```markdown
## 输出格式
生成 .apkg 文件，包含以下字段：

| 字段 | 内容 |
|------|------|
| Question | 问题面 |
| Answer | 答案面 |

## 示例
**Question**: $\sin^2\theta + \cos^2\theta = ?$
**Answer**: $1$
```

---

### 结构错误

#### ❌ 错误：Front matter 后缺少空行
```markdown
---
name: my-skill
---
# 标题    # 错误：Front matter后没有空行
```

#### ✅ 正确：Front matter 后保留空行
```markdown
---
name: my-skill
---

# 标题
```

---

#### ❌ 错误：工具列表格式错误
```yaml
tools:
  read, write   # 错误：逗号分隔
```

#### ✅ 正确：使用 YAML 列表格式
```yaml
tools:
  - read
  - write
```

---

## 创建检查清单

生成 skill 后，逐项检查：

### Front Matter 检查
- [ ] `name` 使用小写字母和连字符
- [ ] `version` 格式为 `X.Y.Z`
- [ ] `description` 简洁明确（一句话）
- [ ] `triggers` 包含 2-4 个触发关键词
- [ ] `inputs` 每个参数都有 `name`、`description`、`required`
- [ ] 非必需参数都有 `default` 值
- [ ] `tools` 只列出可用工具

### 正文检查
- [ ] 有明确的任务目标说明
- [ ] 执行步骤详细、可操作
- [ ] 说明了输出格式
- [ ] 添加了必要的注意事项
- [ ] 涉及 LaTeX 输出时，已嵌入公式与符号排版规范块
- [ ] Front matter 后有空行
- [ ] Markdown 格式正确

### 内容质量检查
- [ ] 触发词具体、有辨识度
- [ ] 参数描述清晰
- [ ] 工作流步骤完整
- [ ] 考虑了边界情况
- [ ] 提供了示例（如适用）

### LaTeX 输出检查（如适用）
- [ ] 已包含 Unicode 符号禁止规则（含对照表）
- [ ] 已包含字体规范（正体单位 / 斜体变量）
- [ ] 已包含公式排版上下文选择规则
- [ ] 已包含书写规范（花括号下标、分式、省略号）
- [ ] 已包含生成后自查清单

---

## 生成流程

1. **读取参考文件**：使用 `glob` 和 `read` 读取现有 skill 文件
2. **分析工作流**：根据 `workflow_description` 提取要素
3. **生成文件**：使用 `write` 创建新的 skill 文件
4. **验证格式**：按照检查清单验证生成的文件

## 输出

在 `{output_dir}` 下创建 `{skill_name}.md` 文件。

完成后输出：
```
✓ Skill 创建成功
文件路径: {output_dir}/{skill_name}.md
```

## ⚡ Git 安全网 + 文件写入安全

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行所有 `write`/`edit` 操作前，必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。

同时遵守以下基本写入安全规则：
1. **写入前先检查**：使用 `glob` 或 `read` 确认目标文件是否已存在
2. **已有文件优先用 `edit`**：如果文件已存在，使用 `edit` 追加/修改，而非 `write` 覆写
3. **`write` 仅用于新建**：确保目标文件确实不存在再使用 `write`
4. **覆写前确认**：如果必须覆写已有文件，先告知用户并获得明确许可
