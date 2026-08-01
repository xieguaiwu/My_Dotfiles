---
name: sat-error-note-generator
version: 1.1.0
description: 从SAT答题记录和扫描版试卷中提取错题/标记题，生成单文件Obsidian错题分析笔记
triggers:
  - "整理SAT错题"
  - "生成SAT错题笔记"
  - "SAT错题分析"
  - "整理阅读语法错题"
inputs:
  - name: answer_file
    description: 答题记录文件路径（如 ~/高一/英语/SAT/25.5-4_answers.md）
    required: true
  - name: test_pdf
    description: 扫描版试卷PDF路径
    required: true
  - name: output_dir
    description: Obsidian Vault 输出目录
    required: false
    default: "~/Documents/Obsidian Vault/SAT/"
  - name: note_title
    description: 笔记标题（英文Title Case）
    required: false
    default: "SAT RW {卷号} 错题分析"
tools:
  - read
  - write
  - edit
  - bash
  - grep
---

# SAT 错题笔记生成器

## 任务目标
根据学生的 SAT 阅读语法答题记录（含标记的错题/不确定题）和扫描版试卷PDF，自动生成一份**单文件**的 Obsidian 错题分析笔记，遵循以下核心原则：

1. **单文件** — 所有错题合并在一个 `.md` 文件中，用 `---` 分隔 + 目录锚点导航
2. **无词汇积累** — 不包含词汇表、学术词汇表、同义词/反义词表
3. **重逻辑分析** — 每道题的重点在：题干还原、选项分析、正确思路、考点说明、解题策略
4. **可视化** — 优先使用 Mermaid 流程图/思维导图辅助说明推理链条
5. **符合 vault 标签规范** — 复用已有标签体系

## 执行流程

### 1. 读取答题记录

使用 `read` 读取 `answer_file`，识别：

- Section/Module 划分
- 每道题的作答字母
- 特殊标记：`(?)` = 不确定, `(?, high difficulty)` = 高难度
- 缺失作答的题号（可能为未完成）

提取所有带有 `(?)` 标记的题目编号，形成**待分析题号列表**。

### 2. 从PDF还原题目内容

扫描版PDF需要使用 OCR 处理：

```bash
# 估算题目所在页码：按~2题/页估算
# 例：Mod1 Q24 ≈ 第12-13页
pdftoppm -f {start_page} -l {end_page} -png -r 200 "{test_pdf}" ocr_temp
tesseract ocr_temp-{page}.png stdout -l eng+chi_sim 2>/dev/null
```

**页码估算方法**：
- Module 1 (Q1-Q27)：每页约2题，Qn ≈ 第 `ceil(n/2)` 页
- Module 2 (Q1-Q13 或完整)：从 Module 1 结束后继续，留意 "Section 1, Module 2" 标记

OCR 后手动确认题目编号与答案文件匹配。

### 3. 分析每道题

对每道标记题，执行以下分析：

#### a. 题干提取
从 OCR 结果中提取完整题干、选项（A/B/C/D）、笔记内容（如有）。

#### b. 考点识别
SAT Reading & Writing 常见考点分类：
- **Words in Context** — 根据上下文选择最精确的词汇
- **Command of Evidence** — 使用笔记/数据支持特定写作目的
  - Rhetorical Purpose（begin a narrative, emphasize, contrast, etc.）
  - Scientific Reasoning（支持结论/削弱论点/数据匹配）
- **Transition/Logical Connection** — 逻辑过渡词选择
- **Standard English Conventions** — 语法/标点/句子结构

#### c. 选项分析
列出4个选项的逐项分析表，格式：

```markdown
| 选项 | 内容 | 评价 |
|:---|:---|:---|
| **A** ✅ | ... | ✅ 正确理由 |
| **B** ✏️ | ... | ❌ 错误原因 |
```

#### d. 推理链
- 对 Words in Context 题：画出因果链 Mermaid 流程图
- 对 Command of Evidence 题：拆解假说→证据→结论的关系
- 对 Scientific Reasoning 题：列出关键数据比较，解释推理过程

#### e. 陷阱识别
标注常见陷阱类型：
- 因果倒置（词汇题常见）
- 净效应抵消（支持结论题常见）
- 相关性≠因果机制
- 过度推断（超出数据范围）
- 混淆写作目的（summary vs. narrative）

### 4. 生成单文件笔记

遵循 `obsidian_note_generation.md` 格式规范：

#### YAML Front Matter
```yaml
---
title: SAT RW {卷号} 错题分析
tags:
  - SAT
  - Reading
  - 错题
created: {YYYY-MM-DD}
---
```

#### 笔记结构

```markdown
# SAT RW {卷号} 错题分析

> [!abstract] 试卷信息
> - **试卷**: {试卷名称}
> - **来源**: `{answer_file}`
> - **本次错题/标记题**: N 道
> - **薄弱技能**: {技能列表}

## 目录

- [[#1. Module X QX — 题型（关键词）]]
- [[#2. Module X QX — 题型（关键词）]]
...

---

# 1. Module X QX — 题型

> [!info] 标记: `{作答字母} ({标记})`

## 题干
{完整题干}

## 选项分析
{选项分析表}

## 解题思路

### 考点
{考点说明}

### 推理过程
{详细分析 + Mermaid 图（如适用）}

### 为什么 {正确选项} 正确
{解释}

### 为什么 {错误选项} 不对
{解释}

> [!warning] 陷阱识别
> {常见陷阱说明}

---

# 2. Module X QX — 题型
...

---

## 总结：薄弱技能分布

{技能分布表 + 优先级 + 行动建议}
```

#### 关键约束
1. **不包含**任何形式的词汇积累/学术词汇/同反义词表
2. **不使用** `---` 水平分割线分隔章节（Front Matter 后唯一可用），章节间靠 `#` 标题层级分隔
3. 每道题以 `# 序号. Module X QX — 题型` 为二级标题开始
4. 每道题之间用 `---` 分隔

### 5. 验证与清理

- 删除 OCR 生成的临时 PNG 文件
- 确认笔记文件已写入 `output_dir`
- 验证所有锚点链接正确（标题中的中文括号等特殊字符不会影响 Obsidian 内部跳转）

## 输出格式

在 `{output_dir}` 下生成一个 `.md` 文件，文件名为 `SAT RW {卷号} 错题分析.md`。

完成后输出：
```
✓ SAT 错题笔记已生成
文件: {output_dir}/SAT RW {卷号} 错题分析.md
题目: {题号列表}
```

## 注意事项

1. **词汇表禁止** — 任何时候都不要添加词汇积累、词汇表、同/反义词、学术词汇等列表。本 skill 的产出是**逻辑分析笔记**，不是词汇本
2. **单文件原则** — 每次调用只生成一个 `.md` 文件，所有题目合并。如需分次整理不同卷号，每次生成独立的单文件
3. **OCR 质量** — 扫描版 PDF 的 OCR 可能不完美，如果某题 OCR 结果模糊，应结合上下文合理推测。如果完全无法识别，在笔记中标注 "[OCR 识别不清]"
4. **标签复用** — 优先使用 vault 中已有的标签。如发现新领域标签（如 `SAT`），则在首次使用时创建，并在后续复用
5. **客观呈现学生答案** — 标注学生的作答结果，但不预设对错；重点在解释正确的推理过程
6. **Mermaid 图适度使用** — 仅在有清晰的因果链或流程关系时使用，每道题最多一个
7. **Git 安全** — 执行 `write` 前检查目标文件是否存在；若已存在先读旧内容，与用户确认是否覆写或追加
