---
name: problem-extraction
version: 1.0.0
description: 从图片或文档中提取题目并整理成Obsidian格式的Markdown笔记
triggers:
  - "整理题目"
  - "提取题目"
  - "录入题目"
  - "题目整理"
inputs:
  - name: source
    description: 题目来源（图片路径或文档路径）
    required: true
  - name: output_file
    description: 输出文件路径
    required: true
  - name: question_numbers
    description: 需要提取的题号（如 "9,10" 或 "12,14"）
    required: false
    default: "all"
  - name: translate
    description: 是否将英文题干翻译成中文
    required: false
    default: true
tools:
  - look_at
  - read
  - write
  - edit
---

# 题目整理与录入

请按照以下步骤整理题目：

1. **读取源文件**
   - 如果是图片，使用工具或者调用有视觉能力的subagent提取题目内容
   - 如果是文档，使用 read 工具读取内容

2. **提取题目信息**
   - 准确识别题目编号
   - 逐字转录题干内容
   - 提取所有选项（如有）
   - 确保数学公式和符号的准确性

3. **格式转换**
   - 将所有数学表达式转换为 LaTeX 格式
   - 行内公式使用 `$...$`
   - 独立公式使用 `$$...$$`
   - 保持公式排版清晰美观

4. **翻译处理**
   - 若 translate 为 true，将英文题干和选项翻译成中文
   - 数学公式保持原样，不翻译
   - 保持专业术语的准确性

5. **添加解析**
   - 为每道题目添加详细的解题步骤
   - 说明使用的定理、公式或方法
   - 给出最终答案

6. **追加到目标文件**
   - 使用 edit 工具将题目追加到 output_file 末尾
   - 保持与现有内容的格式一致
   - 使用 `## Q{题号}` 作为题目标题

## 输出格式示例

```markdown
## Q{题号}
> {题干内容（中文翻译）}
> (A) $\displaystyle \sum_{n=1}^{\infty} \frac{1}{n}$
> (B) ...选项B...
> (C) ...选项C...
> (D) ...选项D...

**解析**：使用{方法名称}，...

计算过程：
$$\int_1^{\infty} f(x) \, dx = ...$$

**答案：A**
```

## 注意事项

- 数学符号：确保上标、下标、希腊字母等符号准确
- 专业术语：使用标准的数学中文术语
- 格式一致：保持与目标文件中现有题目的格式一致
- 链接引用：适当添加相关知识点笔记的链接（如 `[[Infinite Series]]`）

### ⚡ Git 安全网 + 文件写入安全

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行所有 `write`/`edit` 操作前，必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。

同时遵守以下基本写入安全规则：
1. **写入前先检查**：使用 `glob` 或 `read` 确认 `output_file` 是否已存在
2. **已有文件优先用 `edit`**：文件已存在时，用 `edit` 在末尾追加，而非 `write` 覆写
3. **`write` 仅用于新建**：确保目标文件确实不存在再使用 `write`
4. **覆写前确认**：如果必须覆写已有文件，先告知用户并获许可
