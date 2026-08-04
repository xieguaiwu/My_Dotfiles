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
    default: "SAT RW {exam_no} Error Analysis"
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

**定位策略（按优先级）**：
1. 先用 `pdftotext` 检测文本层：若有文本层，直接全文提取按题号定位，无需 OCR
2. 扫描版（无文本层）：**整本低分辨率 OCR 一遍**（`pdftoppm -r 150` 全页 + tesseract），grep 题号标记建立「题号→页码」索引
3. 仅对目标页高分辨率重扫（`pdftoppm -r 300`）用于精确转录

> 不建议按"每页约 2 题"线性估算——SAT 阅读长文一页常只覆盖 1-2 题甚至跨页，线性估算会漏题或定位错页。

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
- Cause-Effect Reversal (common in vocab questions)
- Net Effect Cancellation (common in evidence questions)
- Correlation ≠ Causation
- Overgeneralization (beyond the data)
- Purpose Confusion (summary vs. narrative)

### 4. 生成单文件笔记

遵循 `obsidian_note_generation.md` 格式规范：

#### YAML Front Matter
```yaml
---
title: SAT RW {exam_no} Error Analysis
tags:
  - SAT
  - Reading
  - Error-Analysis
created: {YYYY-MM-DD}
---
```

#### 笔记结构

```markdown
# SAT RW {exam_no} Error Analysis

> [!abstract] Exam Info
> - **Test**: {test name}
> - **Source**: `{answer_file}`
> - **Marked Questions**: N
> - **Weak Areas**: {weak areas}

## Table of Contents

- [[#1. Module X QX — Question Type]]
- [[#2. Module X QX — Question Type]]
...

---

# 1. Module X QX — Question Type

> [!info] Marked: `{answer letter} ({marker})`

## Question Stem
{complete question stem}

## Options Analysis
{options analysis table}

## Solution Approach

### Skill Tested
{skill description}

### Reasoning Process
{detailed analysis + Mermaid diagram (if applicable)}

### Why {correct option} Is Correct
{explanation}

### Why {wrong option} Is Wrong
{explanation}

> [!warning] Trap Identification
> {common trap description}

---

# 2. Module X QX — Question Type
...

---

## Summary: Weak Area Distribution

{skill distribution table + priorities + action plan}
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

在 `{output_dir}` 下生成一个 `.md` 文件，文件名为 `SAT RW {exam_no} Error Analysis.md`。

完成后输出：
```
✓ SAT error analysis note generated
File: {output_dir}/SAT RW {exam_no} Error Analysis.md
Questions: {question numbers}
```

## 注意事项

1. **词汇表禁止** — 任何时候都不要添加词汇积累、词汇表、同/反义词、学术词汇等列表。本 skill 的产出是**逻辑分析笔记**，不是词汇本
2. **单文件原则** — 每次调用只生成一个 `.md` 文件，所有题目合并。如需分次整理不同卷号，每次生成独立的单文件
3. **OCR 质量** — 扫描版 PDF 的 OCR 可能不完美，如果某题 OCR 结果模糊，应结合上下文合理推测。如果完全无法识别，在笔记中标注 "[OCR 识别不清]"
4. **标签复用** — 优先使用 vault 中已有的标签。如发现新领域标签（如 `SAT`），则在首次使用时创建，并在后续复用
5. **客观呈现学生答案** — 标注学生的作答结果，但不预设对错；重点在解释正确的推理过程
6. **Mermaid 图适度使用** — 仅在有清晰的因果链或流程关系时使用，每道题最多一个
7. **Git 安全** — 执行 `write` 前检查目标文件是否存在；若已存在先读旧内容，与用户确认是否覆写或追加
8. **全英文产出** — 笔记内容（题干、选项分析、推理、总结、标签）一律英文，禁止中文。
