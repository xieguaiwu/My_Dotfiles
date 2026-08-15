---
name: sat-exercise-splitter
version: 1.0.4
description: 识别多个SAT专题练习文件，按难度分section生成题目与答案+解析两个LaTeX文件，各section题号自 1 重排，tectonic编译。位于 SAT 工具链上游——下游可接入 sat-error-note-generator（Obsidian 错题笔记）或 mistake-practice-generation（AI 练习卷）
triggers:
  - "拆分SAT专题练习"
  - "题目答案解析分离"
  - "生成SAT练习LaTeX"
  - "SAT exercise split"
  - "专题练习转LaTeX"
  - "按难度分组SAT题目"
inputs:
  - name: source_dir
    description: 专题练习文件所在目录
    required: false
    default: "./"
  - name: output_dir
    description: 输出目录
    required: false
    default: "./"
  - name: output_name
    description: 输出文件名前缀（不含扩展名）
    required: false
    default: "SAT_Practice"
  - name: topic_order
    description: 专题顺序（逗号分隔），缺省 auto 按文件名自然排序
    required: false
    default: "auto"
  - name: show_topic
    description: 题目文件是否标注每题专题来源
    required: false
    default: false
  - name: answer_space
    description: 题目文件每题末尾是否留作答横线
    required: false
    default: false
  - name: compile
    description: 是否用 tectonic 编译为 PDF
    required: false
    default: true
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
  - glob
  - subagent
---

# SAT 专题练习拆分器

## 任务目标
识别目录下多个 SAT 专题练习文件（官方题库「Answer and Explanation」PDF 为主，结构化 md 为辅），拆分为**题目**与**答案+解析**两个独立 LaTeX 文档：一者作答、一者核对，两不相混。两文档皆按难度（Easy/Medium/Hard）分大 section 承载各难度题目集合，专题顺序与题内顺序保持原样，每个 section 题号自 1 起排，以方便作答。产物用 tectonic 编译为 PDF。

### 工具链定位

本 skill 位于 SAT 练习工作流的**最上游**——将原始官方题库 PDF 转化为结构化 LaTeX 后，下游可继续接入：

```
sat-exercise-splitter（本 skill）
    │
    ├── 产出 _questions.tex / _answers.tex（两文件二分，编译后即可直接使用）
    │
    ├──→ sat-error-note-generator（读回 PDF 原文或参考答案文件，按 Question ID 定位错题，
    │    生成/追加 Obsidian 错题积累笔记）
    │
    └──→ mistake-practice-generation（读 Obisidian 错题笔记中的陷阱分类诊断，
         生成同类型 AI 练习卷）
```

完整闭环：拆分题库 → 积累错题 → 诊断陷阱 → 生成练习。

## 执行流程

### 1. 识别专题练习
先以 `ls` + `find` 扫描 `{source_dir}`，辨文件类型：

| 类型 | 特征 | 处理 |
|---|---|---|
| 官方题库 PDF | 文件名形如 `NN. {Topic} {Difficulty} Answer and Explanation.pdf`，含文本层（Question ID / Correct Answer / Rationale / Question Difficulty） | 主格式 |
| 结构化 md | 含题干、选项、答案标记 | 辅格式 |
| 扫描版 PDF | pdftotext 输出为空 | 提示用户，可 OCR 或跳过 |

每文件提取：
- **专题名**：文件名中 `{Topic}` 段（如 `Word in Context`、`Text Structure and Purpose`）
- **难度**：Easy / Medium / Hard（文件名末段；若与题内 `Question Difficulty` 标记不符，以题内为准并报告）
- **排序键**：文件名数字前缀（`10.` `11.` 等）；无前缀者按字典序

### 2. 解析文本
```bash
pdftotext "{file}" - > /tmp/sat_block.txt
grep -n "^ID: " /tmp/sat_block.txt        # 题目块索引
grep -n "Answer$" /tmp/sat_block.txt      # 答案块索引
```
按 `ID: {8位hex}` 切块：
- **题目块**：`ID: xxxxxxxx` 起，至 `ID: xxxxxxxx Answer` 止，含题干与 A-D 选项
- **答案块**：`ID: xxxxxxxx Answer` 起，含 `Correct Answer: X`、`Rationale` 及解析原文、`Question Difficulty`
- md 输入：按题目分隔符切块，识别答案标记

### 3. 文本清洗与转义
- 合并 PDF 断行：行尾连字符（hyphenation）还原，段内换行并为空格
- 转义 LaTeX 特殊字符：`\ & % $ # _ { } ~ ^`
- Unicode 符号改 LaTeX 命令（依「LaTeX 符号规范」）
- 弯引号与长破折号转换：`’‘` → `'`，`“”` → `` `` '' ``，`—` → `---`，`–` → `--`
- 每题保留 Question ID 于注释行 `% QID: xxxxxxxx`（正文不显，便于 Bluebook 回查）

### 4. 分类编排
- 按难度分三组，固定顺序 Easy → Medium → Hard；某难度无题则省其 section 并报告
- 组内顺序：专题按 `{topic_order}`（缺省 auto = 文件名自然排序）；专题内题目保持原 PDF 顺序
- 跨文件同 Question ID 去重（保留先者，报告重复数）
- 记录每题来源专题，答案文件标注用

### 5. 生成题目文件
写 `{output_dir}/{output_name}_questions.tex`，结构如下：

```latex
\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{geometry}
\geometry{margin=0.5in}
\setlist[enumerate]{leftmargin=*,nosep}

\begin{document}

\begin{center}
{\Large\bfseries SAT Practice --- Questions}
\end{center}

\section{Easy}
\begin{enumerate}[label=\textbf{\arabic*.}]
\item 题干原文
\begin{enumerate}[label=(\Alph*)]
    \item 选项 A
    \item 选项 B
    \item 选项 C
    \item 选项 D
\end{enumerate}
% QID: 84b5125b
\end{enumerate}

\section{Medium}
\begin{enumerate}[label=\textbf{\arabic*.}]
\item ...
\end{enumerate}

\section{Hard}
\begin{enumerate}[label=\textbf{\arabic*.}]
\item ...
\end{enumerate}

\end{document}
```

要点：
- **每个难度 section 独立 enumerate，题号自 1 起**；禁跨 section 续号（禁 `resume`、禁共享计数器）
- `{show_topic}` 为 true 时，每题题干前加 `\textsc{[专题名]}` 前缀
- `{answer_space}` 为 true 时，每题末尾加 `\hfill \textbf{Answer:} \rule{1.5cm}{0.4pt}` 作答横线
- 短题（词汇类）如需省页，可加 `\usepackage{multicol}` 双栏；长文阅读题必单栏

### 6. 生成答案与解析文件
写 `{output_dir}/{output_name}_answers.tex`，section 结构与题目文件一一对应，enumerate 题号同位对应。每题格式：

```latex
\section{Easy}
\begin{enumerate}[label=\textbf{\arabic*.}]
\item \textbf{B} \quad (\textsc{Word in Context})
\begin{quote}
Choice B is the best answer because ...（rationale 原文）
\end{quote}
% QID: 84b5125b
\end{enumerate}
```

- 答案字母粗体，后注来源专题（同难度多专题混排，须指明出处）
- Rationale 原文入 `quote`；若原文缺失（如 md 无解析），以自写解析补之，惟结论须与 Correct Answer 一致（防幻觉）

### 7. tectonic 编译与验证
```bash
tectonic "{output_name}_questions.tex"
tectonic "{output_name}_answers.tex"
```
- 退出码 0 且 PDF 生成 = 通过；失败则读 `.log` 修错后重编
- 清理辅助文件（`.aux` `.log` `.out` `.toc` 等；tectonic 默认不留，有则 `rm -f`）
- 验证：
  - 题目数 = 答案数
  - 各 section 题号连续，自 1 起无跳号
  - 两文件 section 结构一致
  - `grep -c '\\item'` 与源题块数相符
  - **答案字母抽样校验**：从 Easy/Medium/Hard 各随机抽 3 题，对照源 PDF 的 Correct Answer 字段手工确认——此步检测文本提取中的 OCR 错误或清洗失误（尤其当源 PDF 包含扫描页时）
  - **题干完整性校验（必做，防 vision 模型静默丢内容）**：
    1. 每页 probe FIRST_WORDS token 覆盖检查（见注意 #13）——命中 < 50% 的页补扫
    2. 问题含 "underlined" 的页必须有 `*[UL_START]*` 标记
    3. notes 题型页必须有 bullet 列表（生成后 grep `\\begin{itemize}` 数 = notes 题数）
    4. 引用 table/graph 的题必须有对应 tabular/图片（grep `tabular` 数 = 表格题数）
    5. 抽 3-5 页渲染图用多模态 agent（visual-engineering / multimodal-looker）视觉复核：填空下划线、划线句、表格对齐、中文渲染、无溢出/重叠
- 题量逾 40 时，调 subagent 复核题目-答案对应（momus 或 oracle，`timeoutMs: 600000`，`clarify: false`）

### 8. 汇报
输出统计：

```text
✓ 已生成 2 个 .tex 与 2 个 .pdf（compile=false 时仅 .tex）
专题: Word in Context(20 题) / Text Structure and Purpose(10 题)
Easy: 12 题 | Medium: 12 题 | Hard: 6 题
文件: {output_dir}/{output_name}_questions.tex / {output_name}_answers.tex

下游建议:
  积累错题 → 使用 sat-error-note-generator
  生成练习 → 使用 mistake-practice-generation
```

## 输出格式
产物四件（compile=false 时为两件 `.tex`）：

| 文件 | 内容 |
|---|---|
| `{output_name}_questions.tex` / `.pdf` | 纯题目卷：按难度分 section，题号各 section 自 1 起 |
| `{output_name}_answers.tex` / `.pdf` | 答案+解析卷：同结构，每题答案字母 + rationale + 专题来源 |

示例（Easy 节首题）：

```latex
\section{Easy}
\begin{enumerate}[label=\textbf{\arabic*.}]
\item Artist Marilyn Dingle's intricate, coiled baskets are \_\_\_\_ sweetgrass and palmetto palm. ... Which choice completes the text with the most logical and precise word or phrase?
\begin{enumerate}[label=(\Alph*)]
    \item indicated by
    \item handmade from
    \item represented by
    \item collected with
\end{enumerate}
% QID: 84b5125b
\item ...
\end{enumerate}
```

## LaTeX 符号规范

### 禁止 Unicode/ASCII 替代 LaTeX 符号
所有数学符号**必须用 LaTeX 命令**，禁止粘贴外观相似的 Unicode 字符或 ASCII 替代写法：

| 场景 | LaTeX 命令 | 禁止写法 |
|------|-----------|---------|
| 蕴涵/箭头 | `\to` `\rightarrow` `\Rightarrow` | → ⇒ `=>` |
| 量词 | `\forall` `\exists` | ∀ ∃ |
| 属于 | `\in` | ∈ |
| 否定 | `\neg` `\lnot` | ¬ |
| 合取/析取 | `\land` `\lor` | ∧ ∨ |
| 语义/语法后承 | `\models` `\vdash` | ⊨ ⊢ `\|=` |
| 不等/约等 | `\neq` `\approx` | ≠ ≈ |
| 大于等于/小于等于 | `\ge` `\le` | ≥ ≤ |
| 点乘/叉乘 | `\cdot` `\times` | · × |
| 无穷 | `\infty` | ∞ |
| 常见希腊字母 | `\theta` `\mu` `\omega` `\pi` `\alpha` | θ μ ω π α |
| 根号 | `\sqrt{}` | √ |
| 积分/求和 | `\int` `\sum` | ∫ ∑ |
| 长破折号 | `---` | — |
| 短破折号 | `--` | – |

**规则：不确定某符号的 LaTeX 命令时，查证后再写，绝不直接粘贴 Unicode。**

### 数学字体规范
| 用途 | 写法 | 示例 |
|------|------|------|
| 变量 | 默认斜体 | `$m$` `$v$` `$t$` |
| 多字母函数 | `\sin` `\log` `\mathrm{}` | `$\sin\theta$` `$\mathrm{KE}$` |
| 数字与单位间 | `\,` 小空格 | `$5\,\mathrm{kg}$` |

### 书写规范
- **上下标**：多字符必须用花括号（`$v_{0}$`，禁 `$v_0$` 歧义写法）
- **分式**：行内用 `\frac{}{}`，复杂分式用 `$\displaystyle\frac{}{}$`
- **省略号**：`\dots` `\cdots`，禁三个句点 `...`
- **行内公式** `$...$` 为默认首选；独立行间 `$$...$$` 仅限核心公式，不超过 5%

### 生成后自查
- [ ] 所有 Unicode 符号（→ ∀ ∃ ∈ ¬ 等）已替换为 LaTeX 命令
- [ ] 特殊字符（`\ & % $ # _ { } ~ ^`）已转义
- [ ] 多字符下标用 `{...}` 包裹
- [ ] 数学函数名用正体（`$\sin$`，非 `$sin$`）
- [ ] 无残留 `—` `–` `’` `“` 等 Unicode 排版字符

## 注意事项
1. **文件安全**：目标 `.tex` 已存在时，先 `read` 察现状，用 `edit` 更新或询用户后覆写；禁盲目 `write` 覆写（遵 `../git_safety_net.md`）
2. **无文本层 PDF**：pdftotext 输出为空即提示用户，勿静默猜测。
   - **不要用 tesseract**——数学/表格 OCR 质量不够用。
   - 正确路径：指向 `exam-paper-cloner.md` §0.3a 的 Vision OCR 完整流水线（doubao / nemotron-nano 视觉模型 + 图形裁剪两轮 + 答案交叉验证）。
   - tesseract 仅在无 vision API key 且用户接受低质量结果的纯文本题时作为降级方案。
   - **整卷扫描版**（如手机拍照的全套题 PDF，57 页级）：见 §0.3a.11 服务器端扫描（RapidOCR 或 vision API）；先确认服务器资源再部署，勿在本机硬跑。
3. **难度以题内标记为准**：文件名与 `Question Difficulty` 不符时，以题内为准并报告
4. **同 ID 去重**：跨文件重复题仅保留先者，报告重复数
5. **Unicode 禁入正文**：所有符号须转 LaTeX 命令，不确定先查证
6. **中文内容**：SAT 文本本为英文；若解析或注释需含中文（如学生订正批注），注意：
   - **tectonic 实测可行（2026-08-13）**：fontspec + 静态 TTF 全局方案（不依赖 ctex），不必切 xelatex：
     ```latex
     \usepackage{fontspec}
     \setmainfont{Noto Sans SC}           % 全局中文主字体（中文含量高时最简单）
     \XeTeXlinebreaklocale "zh"           % ← 缺这两行 = 中文不换行
     \XeTeXlinebreakskip = 0pt plus 1pt
     ```
     - 只有 `ctex.sty` 方案才需 xelatex（tectonic 缺包）；fontspec 直连方案 tectonic 可编译
     - **缺断行设置的典型症状**：中文长句（表格 `p{}` 列 / 段落）整串不换行 → Overfull hbox 大超宽（>10pt，实测 36pt）
     - **诊断铁律**：Overfull hbox 大超宽 + 中文内容 → 先查断行设置，**别急着调列宽**（列变窄溢出更多，实测 19pt→36pt 恶化）
   - XeLaTeX CJK 常见坑（沿用）：
     - **必须用静态 TTF**（如 `NotoSansSC-Regular.ttf`），不可用可变 TTC（`NotoSansCJK-VF.ttc` → `xdvipdfmx fatal: Invalid TTC index`）
     - PDF 书签防崩溃：`\pdfstringdefDisableCommands{\let\cn\@firstofone}`
     - 所有中文字符必须包在 fontspec 字体命令组内（如 `\cn{...}`），否则 Latin Modern 缺字
     - **控制序列后紧跟中文**：`\dots`/`\ldots` 后直接写中文 → `Undefined control sequence`（CJK 字符被并入控制序列名）；必须 `\dots{}` 空组隔离
   - 若完全不用中文，直接用 tectonic 切 9pt twocolumn 最省纸。
7. **答案一致性**：rationale 原文照录；自写解析须与 Correct Answer 一致，不可臆造
8. **源文件只读**：不修改、不移动输入文件
9. **compile=false 时**：仍须报告两 `.tex` 路径，提示用户可自行 tectonic 编译
10. **QID 注释**：每题保留 `% QID: xxxxxxxx`，便于 Bluebook 回查与去重核对
11. **题号以页面序/FOOTER 为准**：vision 转录时模型自报的 `Q<num>` 不可信（实测报 Q1 实为 Q16）；解析阶段按 PDF 页面顺序编号，用转录的 FOOTER/页码交叉验证
12. **转录增量保存**：整卷转录时每页完成即写入 raw.json，中途失败可断点续跑；rationale 缺失（"Not answerable"/"not provided in the image"）的页面标记待补扫（换模型或裁剪重读），不得静默留空
13. **题干完整性交叉验证（probe FIRST_WORDS 法）**：vision 转录后，模型可能静默丢弃 passage/笔记列表而只输出问题句+选项（实测 M2 Q13 文献整段丢失、4 页 notes 题型笔记列表全丢，长度检测抓不到——丢失后问题句仍有 70-200 字符）。检测：
    - 用 probe 阶段记录的每页 `FIRST_WORDS` 提取关键 token（专有名词/数字/长词），检查转录文本是否包含；命中 < 50% 即 suspect → 补扫
    - 短题干（<130 字符）直接 suspect → 补扫（注：仅长度检测不够，p40 丢失后仍有 144 字符）
    - **notes 题型专项**：页面含 "researching a topic" / "notes" 字样的题，转录必须含 bullet 列表（`- ` 行）；无 bullet → 补扫
    - **划线句题专项**：问题含 "underlined" 的页，转录必须含 `*[UL_START]*...*[UL_END]*` 标记；缺失时用中文解析/答案解析反推划线句文本（实测 glm-4v 只标出 4/6 页）
    - 补扫 prompt 必须强制 `PASSAGE:/QUESTION:/OPTIONS:` 三节结构 + 逐条 bullet 输出，否则模型仍会丢
14. **表格/图表内容检测**：题目引用 table/graph/text 但转录无对应数据块（pipe 行 / FIGURE_BBOX）→ 报警并补扫。生成 LaTeX 时 pipe 表格必须转 `tabular`（自动列宽：表头 >18 字符用 `p{}` 比例列宽 + `\footnotesize`，防 Overfull）
15. **笔记列表 LaTeX 化**：转录的 `- ` bullet 行须转 `\begin{itemize}` 列表（需 `\usepackage{enumitem}` 支持 `[nosep]`）；ASCII 直引号 `"` 须成对转 `` `` '' ``（仅转 Unicode 弯引号不够）

## 变更日志

### 1.0.4 (2026-08-13)
- 新增注意 #13-15 + §7 题干完整性校验：vision 模型静默丢 passage/笔记列表的检测法（probe FIRST_WORDS token 覆盖 / notes 题型 bullet 专项 / 划线句 UL 标记专项 / 表格数据块检测），补扫 prompt 强制 PASSAGE/QUESTION/OPTIONS 三节结构；pipe 表格→tabular 自动列宽；bullet→itemize + ASCII 引号成对转义
- 来源：2026-06 SAT 第二套转录事故（M2 Q13 文献整段丢失、4 页 notes 列表丢失，长度检测抓不到；多模态 agent 视觉复核发现）

### 1.0.3 (2026-08-12)
- 注意 #2：补充整卷扫描版处理路径（指向 exam-paper-cloner §0.3a.11 服务器端扫描）
- 新增注意 #11/#12：题号以页面序为准（模型报号不可信）、转录增量保存与 rationale 缺失补扫

### 1.0.2 (2026-08-06)
- 注意 #2：废弃 tesseract OCR 建议，改为指向 exam-paper-cloner §0.3a 的 vision 模型流水线（tesseract 数学质量不够）
- 注意 #6：重写中文 CJK 排版指引——ctex 不可靠，改为 XeLaTeX + 静态 TTF + linebreak locale + 字体命令组包裹的实战配方
- 编译验证：新增答案字母抽样校验步骤——各难度抽 3 题对照源 PDF 手工确认，防 OCR/清洗漂移

### 1.0.1 (2026-08-06)
- 新增"工具链定位"章节，明确上游角色；引用 sat-error-note-generator 和 mistake-practice-generation 为下游消费者
- 汇报部分增加"下游建议"提示

### 1.0.0 (2026-08-06)
- 初始发布
