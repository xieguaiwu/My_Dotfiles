---
name: sat-error-note-generator
version: 2.0.0
description: 从SAT答题记录和试卷PDF中提取错题/标记题，按 v3.3 标准模板（7 步结构）生成或追加 Obsidian 错题分析笔记（整卷分析与单题积累两种模式）
triggers:
  - "整理SAT错题"
  - "生成SAT错题笔记"
  - "SAT错题分析"
  - "整理阅读语法错题"
  - "积累SAT错题"
inputs:
  - name: answer_file
    description: 答题记录文件路径（如 ~/高一/英语/SAT/25.5-4_answers.md）；单题积累模式可省略
    required: false
  - name: test_pdf
    description: 试卷/答案解析 PDF 路径（官方题库 PDF 含文本层与 Question ID，优先）
    required: true
  - name: question_specs
    description: '单题积累模式的题目指定列表，如 [{"question": 3, "answer": "A", "correct": "D"}, {"id": "5b8f9cf2", "answer": "C", "correct": "B"}]；无 answer_file 时使用'
    required: false
  - name: output_dir
    description: Obsidian Vault 输出目录
    required: false
    default: "~/Documents/Obsidian Vault/SAT/"
  - name: note_title
    description: 笔记标题（中文，如 "SAT RW FormStructureSense Hard 错题积累"）
    required: false
    default: "SAT RW {set_name} 错题积累"
tools:
  - read
  - write
  - edit
  - bash
  - grep
---

# SAT 错题笔记生成器

## 任务目标
根据学生的 SAT 阅读语法答题记录（含标记的错题/不确定题）和试卷 PDF，生成或追加 **Obsidian 错题分析笔记**，遵循以下核心原则：

1. **两种模式** — 「整卷分析」：一次生成一份完整错题笔记；「单题积累」：把指定题目追加进已有积累笔记（检测已有 → 更新计数/目录/汇总 → 追加新节）
2. **中文分析 + 英文题干** — 题干、选项保留英文原文；考点说明、推理、总结一律中文（跟随 vault 既有笔记惯例）
3. **无词汇积累** — 不包含词汇表、学术词汇表、同义词/反义词表
4. **7 步标准结构** — 每道题严格按 v3.3 标准模板（`SAT RW 错题解析标准模板.md`，位于 `~/Documents/Obsidian Vault/SAT/`）的 7 步书写：Task → Step 1 Map → Step 2 Mark(T/F/NG) → Step 3 Source-check → Step 4 Chain-check → Trap → Principle；不再使用旧的「题干 / 选项分析 / 推理过程 / 解题策略」松散结构
5. **文本链优先** — 推理链用文本 `A → B → C` 表达（简洁可复制）；Mermaid 仅在有复杂分支时使用，每题最多一个
6. **Question ID 一等公民** — 记录官方题库题目 ID（便于 Bluebook 回查），并提取官方 rationale 交叉验证
7. **符合 vault 标签规范** — 复用已有标签体系（SAT / Reading / 错题）

### SAT 工具链定位

本 skill 位于 SAT 练习工作流的**中游**——从上游处理好的题目中提取错题，提炼陷阱分类诊断，供下游生成练习卷：

```
sat-exercise-splitter（上游：拆分官方题库 PDF 为结构化 LaTeX / 错题源）
    │
    ▼
sat-error-note-generator（本 skill — 中游：积累错题到 Obsidian，提炼陷阱分类诊断）
    │
    ▼
mistake-practice-generation（下游：根据陷阱诊断生成同类 AI 练习卷）
```

## 执行流程

### 1. 读取答题记录（或题目指定）

优先使用 `read` 读取 `answer_file`；无 answer_file 时解析 `question_specs`（题号或 Question ID + 我的答案 + 正确答案）。识别：

- Section/Module 划分
- 每道题的作答字母
- 特殊标记：`(?)` = 不确定, `(?, high difficulty)` = 高难度
- 纠正标记：`(wrong, correction: X)` = 错选且已核对正确答案
- 缺失作答的题号（可能为未完成）
- **学生自注错因**：答案文件底部的 reasons for mistakes / 题旁注释（如"不用冒号，因为……"），原样保留备用

形成**待分析题号列表**（整卷模式 = 标记题；积累模式 = question_specs 指定题）。

### 2. 从PDF还原题目内容（按优先级）

**官方题库 PDF（首选）**：
```bash
pdftotext "{test_pdf}" - > /tmp/sat_pdf.txt
grep -n "Question ID" /tmp/sat_pdf.txt   # 建立 题号 ↔ Question ID ↔ 页码 索引
```
- 每题带 `ID: xxxxxxxx`、`Correct Answer`、`Rationale`、`Question Difficulty`（Hard/Medium/Easy）
- **提取官方 rationale 与难度**：用于交叉验证自写分析（防幻觉）并记录到笔记
- 定位方式：`grep -n "ID: {question_id}"` 直接跳转，无需 OCR

**扫描版 PDF（无文本层）→ OCR fallback**：
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

> ⚠️ **tesseract 仅限“建立题号索引”这一步**（低质量但快）；精确转录（题干/选项/解析原文）必须走 vision 模型流水线——见 `exam-paper-cloner.md` §0.3a（模型可用性/fallback 链/服务器端扫描 §0.3a.11）。tesseract 对数学/排版符号质量不够，直接用它转录会污染错题笔记。

> 不建议按"每页约 2 题"线性估算——SAT 阅读长文一页常只覆盖 1-2 题甚至跨页，线性估算会漏题或定位错页。

OCR 后手动确认题目编号与答案文件匹配。

### 3. 分析每道题

对每道待分析题，执行以下分析：

#### a. 题干提取
从 PDF/OCR 结果中提取完整题干、选项（A/B/C/D）、官方 rationale 与难度。**记录 Question ID**。

#### b. 考点识别
SAT Reading & Writing 常见考点分类：
- **Words in Context** — 根据上下文选择最精确的词汇
- **Command of Evidence** — 使用笔记/数据支持特定写作目的
  - Rhetorical Purpose（begin a narrative, emphasize, contrast, etc.）
  - Scientific Reasoning（支持结论/削弱论点/数据匹配）
- **Transition/Logical Connection** — 逻辑过渡词选择
- **Standard English Conventions** — 语法/标点/句子结构（细分到具体考点，如 Subject-Modifier Placement、Subject-Verb Agreement、Boundaries）

#### c. 选项判定（Step 2 — Mark）
列出 4 个选项的 T/F/NG 判定表（依据用中文），格式：

```markdown
| 选项 | 判定 | 依据 |
|:---|:---|:---|
| **A** | NG | 引入了原文未出现的元素（命名缺失元素） |
| **B** | T | 每个元素都能在原文找到（指出支撑句） |
| **C** | F | 与原文某句直接矛盾（写出矛盾点） |
| **D** | NG | ... |
```

判定标准：T = 选项每个元素都能在原文找到；F = 与原文某句直接矛盾；NG = 引入原文从未出现的元素。语法题用 T/F + 语法规则依据（可引用 Checklist A1.x/A2.x 规则编号，引用前必须 grep 核实编号存在）。

#### d. 推理链（Step 1 Map + Step 4 Chain-check）
- **Step 1 — Map**：阅读题给每句标注职责（set-up / claim / evidence / contrast / conclusion / answer）；语法题标注句法结构，先找主句/从句的真正谓语
- **Step 4 — Chain-check**：把原文逻辑写成链 `A → B → C`（因果/转折/回答），确认幸存选项是链上的一环而非跳链；语法题做边界测试（一个分句只有一个有限动词）
- 对 Command of Evidence 题：拆解假说→证据→结论的关系
- 对 Scientific Reasoning 题：列出关键数据比较，解释推理过程

#### e. 学生错因校验
- 若有学生自注错因，**逐条校验归因是否正确**；发现错误归因（如把悬垂修饰语误判为标点题）时，在笔记中显式指出并写明真正考点
- 与官方 rationale 交叉验证：自写分析与官方解析结论一致才算完成；不一致时以官方为准并标注差异

#### f. 陷阱命名（Trap）
陷阱必须压缩为**可复用命名模式**（一句话规则 + 一句话防法），不是"这题做错了"。常见命名模式：
- 范围缺口（Scope Gap）、程度夸大（Intensity Inflation）、set-up 当中心、话题偷换
- 双谓语、comma splice、虚位主语陷阱、邻近干扰（Proximity Trap）、所有格伪装、人/作品主语混淆
- 指标混淆、张冠李戴、净效应抵消、时间窗口错位、以偏概全（Cherry-pick）等

#### g. 对应原则（Principle）
标注本题违反/应用的核心原则：原则一 文本依据 / 原则二 逻辑优先 / 原则三 功能定位 / 原则四 中心问题；语法题标注「结构优先」（逻辑优先的语法版）。

### 4. 生成 / 追加笔记

先检查目标笔记是否已存在（`ls` + `read`）：

- **不存在 → 新建**（`write`）：按下方模板生成完整笔记
- **已存在 → 追加**（`edit` 精确修改，**禁止 `write` 覆写**）：
  1. 更新 header 中的「当前积累」题数与「薄弱技能」
  2. 目录（TOC）追加新条目锚点
  3. 在「积累小结」之前追加新题分析节（`---` 分隔）
  4. 更新「积累小结」汇总表（题号/考点/我的答案/正确答案/错误类型）
  5. 更新「行动项」——合并重复出现的陷阱模式（如多题同犯悬垂修饰语 → 提炼共同对策）

遵循 `Note_Creating/obsidian_note_generation.md` 格式规范：

#### YAML Front Matter
```yaml
---
title: SAT RW {set_name} 错题积累
tags:
  - SAT
  - Reading
  - 错题
created: {YYYY-MM-DD}
---
```

#### 笔记结构

```markdown
# SAT RW {set_name} 错题积累

> [!abstract] 试卷信息
> - **试卷**: {test name}
> - **来源**: `{source pdf}`
> - **当前积累**: N 题（{question list}）
> - **薄弱技能**: {weak areas}
> - **备注**: {按 v3.3 标准模板重塑（{date}）——仅在重塑时追加}

---

> [!danger] 分析原则
> 详见 [[SAT Reading - Analysis Principles]]。

## 目录

- [[#1. {Q} — 考点（中文）]]
- [[#2. {Q} — 考点（中文）]]
...

---

# 1. {Q} — 考点（中文）

> [!info] 我的答案: {letter} — 错误 | 正确答案: **{letter}**
> Question ID: `{xxxxxxxx}` | 难度: {Hard/Medium/Easy}

## Task（题干与选项）
{英文题干 + 选项，逐字保留}

## Step 1 — Map（结构标注）
{阅读题：逐句标注职责（claim / evidence / contrast / conclusion / answer / set-up）
语法题：标注句法结构，先找主句/从句真正谓语}

## Step 2 — Mark（T / F / NG 判定）
{表格：选项 | 判定 | 依据；语法题用 T/F + 语法规则依据（Checklist A1.x/A2.x）}

## Step 3 — Source-check（溯源）
{幸存 T 选项逐元素溯源到原文句子；NG 命名缺失元素；F 命名矛盾句}

## Step 4 — Chain-check（链条验证）
{文本逻辑链 A → B → C；确认幸存选项是链上一环；语法题做边界测试（一分句一有限动词）}

## Trap（陷阱命名）
> [!warning] {可复用命名模式}
> 规则：一句话规则。
> 防法：一句话防法。

## Principle（对应原则）
{原则一 文本依据 / 原则二 逻辑优先 / 原则三 功能定位 / 原则四 中心问题；语法题=结构优先}

---

# 2. {Q} — 考点（中文）
...

---

## 积累小结

| 题号 | 考点 | 我的答案 | 正确答案 | 错误类型 |
|:---|:---|:---:|:---:|:---|

**行动项**: {重复陷阱合并后的共同对策}
```

> [!important] 权威规范
> 完整模板规范（含阅读题/语法题双样板、旧结构→新结构映射表、5 条铁律）以 `~/Documents/Obsidian Vault/SAT/SAT RW 错题解析标准模板.md` 为准。生成笔记前先 read 该文件。

#### 关键约束
1. **不包含**任何形式的词汇积累/学术词汇/同反义词表
2. **7 步铁律** — 每题必须完整出现 7 步：Task / Step 1 Map / Step 2 Mark / Step 3 Source-check / Step 4 Chain-check / Trap / Principle，缺一不可
3. 每道题以 `# 序号. {Q} — 考点` 为一级标题开始，每题内部用 `##` 级 7 步标题
4. 每道题之间用 `---` 分隔
5. **中文分析 + 英文题干**：题干/选项保留原文；分析、总结、callout 一律中文
6. **Question ID**：每题记录官方题库 ID 与难度，便于 Bluebook 回查
7. **逐字保留** — 题干、选项、我的答案、正确答案逐字保留，不得改写、缩写到失真
8. **不加新分析** — 不得添加原笔记没有的新分析/新事实（Trap 命名、T/F/NG 判定等模板元素除外）
9. **Trap 可复用** — 陷阱必须是可复用命名模式（范围缺口、程度夸大、双谓语…），不能只是"这题做错了"

### 5. 验证与清理

- 删除 OCR 生成的临时 PNG 文件
- 确认笔记文件已写入/更新于 `output_dir`
- 追加模式下：确认 TOC、header 计数、积累小结表、行动项均已同步更新
- 与官方 rationale 一致性：每题结论与官方 Correct Answer 一致
- 验证所有锚点链接正确（标题中的中文括号等特殊字符不会影响 Obsidian 内部跳转）

## 输出格式

在 `{output_dir}` 下生成/更新一个 `.md` 文件，文件名为 `SAT RW {set_name} 错题积累.md`。

**新建**完成后输出：
```
✓ SAT 错题笔记已生成
File: {output_dir}/SAT RW {set_name} 错题积累.md
Questions: {question numbers}
```

**追加**完成后输出：
```
✓ SAT 错题笔记已追加
File: {output_dir}/SAT RW {set_name} 错题积累.md
追加题目: {question numbers}
当前积累: N 题
```

## 实战经验

> 每次实战后回填：新增题型模式与流程教训，版本号 +1，变更日志追加。

### 1. 本地 LaTeX 源优先，零 OCR（2026-08-16, 26.6-2）

真题套卷常配套本地 LaTeX：`练习批注版.tex`（题目）与 `标准答案与解析.tex`（解析）。此时**完全跳过 PDF/OCR 流程**：

```bash
grep -n "qtitle{13}" 练习批注版.tex        # 定位题干
sed -n '1428,1480p' 标准答案与解析.tex     # 定位官方解析
```

- `\qans{13.}{B}` 结构直接给出官方答案，逐项中文解析是现成 ground truth（比 OCR 可靠得多）
- 有本地解析 tex 时以其为权威；官方题库 PDF 的 Question ID 流程仅在无本地源时启用

### 2. M1+M2 合并文件同题号——必须与用户确认 Module（教训）

M1+M2 合并文件会有两个 `qtitle{13}`，**凭 answer_file 猜测会出错**：本次用户说"第十三题"，我按"学生已作答的 M1 Q13"推断，实际用户要的是 M2 Q13（未作答）。

定位规则：

1. `grep -n "qtitle{13}"` 看全部命中，复述确认——**不确定时直接问用户要哪个 Module**，不要猜
2. 若用户说"第二部分的第 13 题"这类表述，直接映射 Module 2
3. 两套答案不要混：M1 Q13 与 M2 Q13 是不同题

### 3. 范围匹配题模式（scope matching）

Command of Evidence / Scientific Reasoning 高频子类：题干给出**目标范围**（worldwide / global / 所有群体）与**已验证范围**（单一物种 / 单一地区 / 单一群体）的差距，问哪个发现能证明工具/结论支持目标范围。

**正解**：把效果从已验证范围**推广到目标范围**的发现（跨物种、跨地区，关键词直接对位题干范围词，如 "outside the Indian Ocean" ↔ "worldwide"）。

**典型干扰项**：
- **性质混淆**：稳定性/耐久性等"工具品质" ≠ 跨范围有效性
- **本地相关**：已验证范围内的高浓度-效果相关性（范围不扩展）
- **同范围内比较**：同一物种受损 vs 健康场景的比较

### 4. 答对/未作答题也可积累

单题积累模式不只限错题。答对但考点典型（标注「答对 · 代表性题」）或未作答需讲解（标注「未作答 · 代表性题」）的题均可入笔记，用于题型模式提炼与下游练习卷生成。

## 写作规范（ASD-STE100 中文适配）

分析笔记是功能性文档，套用 ASD-STE100（简化技术英语，国际标准）的写作原则：

- **短句**：一句一个主题，中文单句控制在 40 字内
- **主动语态优先**：A 做 B，少用"被"
- **术语一致**：同一概念全文同一说法，不换同义词
- **条件前置**：如果...则...，关键条件放句首
- **编号步骤**：分析/行动项用编号列表，结构平行

题干/选项保留英文原文不受约束。完整规范见 [technical-writing-standard.md](../technical-writing-standard.md)。

## 注意事项

1. **词汇表禁止** — 任何时候都不要添加词汇积累、词汇表、同/反义词、学术词汇等列表。本 skill 的产出是**逻辑分析笔记**，不是词汇本
2. **单文件原则** — 每次调用只生成/更新一个 `.md` 文件，所有题目合并。整卷分析与单题积累共用同一文件体系
3. **追加安全** — 笔记已存在时禁止 `write` 覆写：先 `read` 了解现状，再 `edit` 精确追加与更新（计数/目录/汇总/行动项）
4. **OCR 质量** — OCR 可能不完美，如果某题 OCR 结果模糊，应结合上下文合理推测。如果完全无法识别，在笔记中标注 "[OCR 识别不清]"
5. **标签复用** — 使用 vault 已有标签（SAT / Reading / 错题）。如发现新领域标签，则在首次使用时创建，并在后续复用
6. **客观呈现学生答案** — 标注学生的作答结果，但不预设对错；重点在解释正确的推理过程
7. **文本链优先** — 推理链优先用文本 `A → B → C`；Mermaid 仅保留复杂分支场景，每题最多一个
8. **语言** — 题干/选项保留英文原文，分析/总结/callout 一律中文（跟随 vault 既有笔记惯例）
9. **官方解析优先** — PDF 自带 rationale 时作为 ground truth 交叉验证（防幻觉）；与官方不一致时以官方为准并标注差异

## 变更日志

- **2.0.0** (2026-08-17): 全面升级为 v3.3 标准模板（对齐 `SAT_RW_Error_Checklist.tex` Chapter E 样板与 Obsidian 标准模板文件）——每题改为 7 步结构（Task → Step 1 Map → Step 2 Mark(T/F/NG) → Step 3 Source-check → Step 4 Chain-check → Trap 命名 → Principle 四原则）；选项分析表改为 T/F/NG 判定表；mermaid 改为文本链优先；语法题可引用 Checklist A1.x/A2.x 规则编号（须核实存在）；权威规范指向 `SAT RW 错题解析标准模板.md`（含双样板与映射表）

- **1.4.0** (2026-08-16): 新增写作规范小节（ASD-STE100 中文适配）——分析笔记遵守简化技术英语原则（短句/术语一致/主动语态/条件前置），完整规范见 technical-writing-standard.md

- **1.3.0** (2026-08-16): 新增「实战经验」章节——① 本地 LaTeX 源（`练习批注版.tex` / `标准答案与解析.tex`）优先于 PDF/OCR，`\qtitle{}`/`\qans{}{}` 直接 grep 定位；② M1+M2 合并文件同题号**必须与用户确认 Module**（凭 answer_file 猜测曾出错，教训）；③ 范围匹配题模式（scope matching）正解 = 效果推广到目标范围 + 三类干扰；④ 答对/未作答题均可积累
