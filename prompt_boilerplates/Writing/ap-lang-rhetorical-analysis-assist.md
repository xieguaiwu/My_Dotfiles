---
name: ap-lang-rhetorical-analysis-assist
version: 1.0.0
description: 阅读并修改AP English Language Rhetorical Analysis作文，识别硬性错误，按AP 6分制评分并提供修改建议
triggers:
  - "AP Lang 作文修改"
  - "rhetorical analysis 批改"
  - "修作文"
  - "AP rhetorical score"
inputs:
  - name: essay_file
    description: 学生作文Markdown文件路径
    required: true
  - name: prompt_pdf
    description: AP官方FRQ Prompt PDF文件路径
    required: true
  - name: AP_Lang_Master_Checklist
    description: LaTeX错误检查清单文件路径
    required: false
    default: ""
  - name: output_docx
    description: 是否转换为docx格式
    required: false
    default: "true"
tools:
  - read
  - write
  - edit
  - bash
  - task
  - look_at
  - glob
---

# AP English Language Rhetorical Analysis 作文批改

## 任务目标

阅读学生的 Rhetorical Analysis 作文（AP Lang FRQ Question 2），完成四件事：

1. **找出所有硬性错误**（拼写、语法、用词、冠词、主谓一致、介词搭配等）
2. **按 AP 6 分制评分**（Row 1 Thesis → Row 2–4 Evidence & Commentary → Row 5 Sophistication），给出分数和具体理由
3. **直接修改源文件**，修正所有硬性错误
4. 可选：将错误条目添加到 LaTeX 错误检查清单，编译 PDF，以及转换为 docx

---

## 执行流程

### 0. 读取文件

```bash
# 读取学生作文
read essay_file
# 读取 FRQ Prompt PDF
# 如果无法直接读PDF，使用 look_at 或将PDF文本提取出来
```

**关键信息**：
- 确定本次考试的 prompt 要求（一般是：analyze the rhetorical choices the writer makes to convey her message）
- 了解学生的原文对应哪一年的哪套题

### 1. 通读全文，标记硬性错误

逐句检查以下六类错误 —— 每发现一个都要记录：

#### A. 拼写错误（Spelling）
| 错误特征 | 举例 |
|---------|------|
| 同音/近音替代 | `repitition` → `repetition` |
| 字母遗漏/多余 | `majory` → `majority` |
| 字母换位 | `throns` → `thorns` |
| 双写错误 | `editting` → `editing` |
| 误加/漏加连字符 | `pre-determined` → `predetermined` |

#### B. 冠词错误（Articles）
- 可数名词单数缺冠词：`authentic connection` → `an authentic connection`
- a/an 错误：`a admirable` → `an admirable`
- the 多余/缺失

#### C. 介词与搭配（Preposition & Collocation）
- `engage for` → `engage through / with`
- `indulge to do` → `indulge in doing`
- `teach the hardship` → `teach about the hardship`
- `emphasis of` → `emphasis on`
- `rely of` → `rely on`

#### D. 主谓一致与数一致（Subject-Verb & Number Agreement）
- `effects ... does not` → `effects ... do not`
- `another setbacks` → `another setback / other setbacks`
- `woman, aliens` → `women, immigrants`

#### E. 词性与词形（Word Form）
- 形容词 → 副词：`incredible strong` → `incredibly strong`
- 动词混用：`sparkles connection` → `sparks connection`

#### F. 用词不当 / 自造词（Diction）
- `backsliding ending`（义不对）→ `disheartening ending`
- `anti-expectation`（非标准）→ `subversion of expectations`
- `aliens`（严重贬义）→ `immigrants`

**⚠️ 标准**：只标记明确的语法/拼写/用词错误。风格偏好、句式单调、不够优美不算硬性错误。

以错误表格形式输出，格式：
```markdown
| # | 原文 | 位置 | 类型 | 正确写法 | 说明 |
|---|------|------|------|---------|------|
```

### 2. AP 评分（6 分制）

#### Row 1: Thesis（0–1 分）
判断 thesis 是否：
- ✅ 识别了修辞选择（至少两种）
- ✅ 提出了可辩护的主张
- ❌ 只是"作者用了X、Y、Z"的列举（不给分）

#### Rows 2–4: Evidence & Commentary（0–4 分）
参照标准：
| 分数 | 描述 |
|------|------|
| **4** | 持续深入解释证据如何支持论点；精准分析修辞选择与作者目的的关系 |
| **3** | 合理解释部分证据与论点关系；评论有深度但不持续 |
| **2** | 有评论但多为描述/复述；引文与解释不连贯 |
| **1** | 内容摘要；无分析 |

#### Row 5: Sophistication（0–1 分）
给分条件：至少满足一项——
- 讨论修辞选择的**复杂性或张力**（非二元分析）
- 将分析置于**更广泛语境**（文化/历史/情境）
- 论证**娴熟地识别设备之间的相互作用**

不给分情况：
- 只是高端词汇堆砌
- 只有"更进一步的""更重要的是"这类空洞衔接
- 结论只是重复开头

#### 总分公式
```
总分 = Thesis (0-1) + Evidence (0-4) + Sophistication (0-1) = /6
```

### 3. 直接修改源文件

使用 `edit` 工具直接在 `essay_file` 中修正所有硬性错误，务必不要不小心直接覆盖掉原始文件！

**修改原则**：
- 只改硬性错误，不改风格
- 不改变学生原意
- 修正后确保源文件阅读流畅

### 4. 可选：添加至 LaTeX 错误检查清单

默认路径为：/home/{用户名}/高一/英语/AP English/AP_Lang_Master_Checklist.tex，使用 `edit` 而非 `write` 命令进行修改，注意绝对不要覆盖掉原始文件，先阅读并确认用户之前是否已经创建了文件再进行修改。如果提供了其他的 `checklist_tex` 路径，则采用提供的路径

将错误分门别类加入相应的 LaTeX 表格：

| 错误类型 | LaTeX 中的对应 subsection |
|---------|--------------------------|
| 拼写：后缀 | `Spelling: Suffix Confusion` |
| 拼写：遗漏/双写/换位 | `Spelling: Letter Omission, Doubling & Transposition` |
| 拼写：复合词 | `Spelling: Compound Words` |
| 冠词 | `Grammar: Article Errors` |
| 介词 | `Grammar: Preposition Omission` |
| 主谓一致 | `Grammar: Subject--Verb Agreement` |
| 词形 | `Grammar: Word Form Confusion` |
| 用词不当 | `Diction: Word Choice Errors` |

添加后使用 tectonic 编译：
```bash
tectonic -X compile "{checklist_tex}"
```

### 5. 可选：转换 docx

如 `output_docx = true`，将修改后的作文转为 docx：
```bash
pandoc "{essay_file}" -o "{essay_file%.md}.docx"
```

### 6. 删除中间文件（如适用）

删除过程中生成的修订稿副本，确保只保留：
- 修改后的源文件（覆盖原文件）
- 转换后的 docx（如有）
- 更新后的 LaTeX PDF（如有）

---

## 输出格式

### 错误报告

```markdown
## 硬性错误一览

| # | 原文 | 位置 | 类型 | 正确写法 | 说明 |
|---|------|------|------|---------|------|
| 1 | repitition | L13 | 拼写 | repetition | — |

共性弱点：{系统性语法问题概述}
```

### AP 评分

```markdown
| 评分维度 | 得分 | 分析 |
|---------|------|------|
| Row 1: Thesis | **?/1** | {理由} |
| Rows 2–4: Evidence & Commentary | **?/4** | {理由} |
| Row 5: Sophistication | **?/1** | {理由} |
| **总分** | **?/6** | {总结} |
```

### 改进空间

```markdown
### 1. {最突出的问题}
{具体描述 + 示例 + 优化方向}

### 2. {次突出问题}
...
```

---

## 注意事项

1. **只修硬伤，不动风格**：单词拼写、语法、主谓一致、介词搭配这些是必须修的。句式丰富性、论证深度等属于评分改进建议，但不属于"硬性错误"的修正范围。
2. **a/an 注意听读音**：`an admirable`（admirable 以元音音节开头），`a university`（university 以辅音 /j/ 开头）
3. **高危词汇**：`aliens`（指人时带贬义）、`backsliding`（词义与"失败结局"完全不同）等，需特别警觉
4. **排版规范**：LaTeX 表格中添加行时，注意反斜杠转义（`\texttt`, `\textbf`, `\emph` 等）
5. **PDF 读取**：如果模型无法直接解析 PDF 的 prompt，可以从已知的 AP 官方题目信息中推断 prompt 要求，但必须以学生文章中实际回应为基线分析
6. **⚠️ 文件写入安全（严格执行）**：使用 `write` 或 `edit` 前，必须先 `read` 目标文件确认其存在和内容。**绝对禁止在未读取文件的情况下直接 `write` 覆写**。修改 checklist 时必须先确认文件存在再用 `edit`。对所有写入操作，先用 `glob` 或 `read` 核实目标路径。
