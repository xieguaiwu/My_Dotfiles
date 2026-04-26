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
- [ ] Front matter 后有空行
- [ ] Markdown 格式正确

### 内容质量检查
- [ ] 触发词具体、有辨识度
- [ ] 参数描述清晰
- [ ] 工作流步骤完整
- [ ] 考虑了边界情况
- [ ] 提供了示例（如适用）

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
