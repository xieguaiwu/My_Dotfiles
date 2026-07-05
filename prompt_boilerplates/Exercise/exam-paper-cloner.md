---
name: exam-paper-cloner
version: 1.0.0
description: 阅读现有试卷作为模板和/或根据知识点描述，生成全英文LaTeX试卷，使用tectonic编译，极致节省纸张
triggers:
  - "clone exam"
  - "生成试卷"
  - "generate paper"
  - "make exam"
  - "出卷"
  - "exam cloner"
inputs:
  - name: template_path
    description: 作为模板参考的现有试卷路径（可选；不提供则根据知识点从头生成）
    required: false
    default: ""
  - name: topics
    description: 要考察的知识点列表（提供template_path时作为补充约束；无模板时作为出题依据）
    required: false
    default: ""
  - name: question_count
    description: 目标题目数量（0=自动根据模板或知识点决定）
    required: false
    default: 0
  - name: output_name
    description: 输出文件名（不含扩展名）
    required: false
    default: Generated_Exam
  - name: options_count
    description: 每题选项数（4 或 5）
    required: false
    default: 4
  - name: subject
    description: 科目名称（如 AP Calculus BC、Linear Algebra），用于文件命名
    required: false
    default: ""
  - name: exam_type
    description: 试卷类型标签（如 Practice_Test、Quiz_Midterm），用于文件命名
    required: false
    default: "Practice"
  - name: output_dir
    description: 输出目录（默认当前工作目录）
    required: false
    default: "."
tools:
  - write
  - bash
  - read
  - glob
  - grep
  - edit
  - subagent
  - fetch_content
---

# 试卷克隆生成器 (Exam Paper Cloner & Generator)

## 任务目标

根据**现有试卷模板**（克隆其结构、题型、格式、难度分布）和/或**知识点描述**，生成一份新的全英文 LaTeX 试卷。要求：

1. **克隆模式**：读入一份已有的 .tex 或 .md 格式试卷，提取其结构特征（题型分布、选项数、编号方式、段落风格），然后用全新的题目内容填充
2. **知识点模式**：无模板时根据用户提供的知识点列表，从零设计题目
3. **全英文**：所有题干、选项、说明文字均为英文
4. **纸张节省**：通过排版技巧最大化题目密度，最小化页数
5. **答案分离**：试卷与答案**始终生成独立的两个文件**，分别用 tectonic 编译
6. **tectonic 编译**：最终产出试卷 PDF + 答案 PDF

---

## 完整工作流程

### Phase 0: 输入分析

#### 0.1 确定模式

| 条件 | 模式 | 说明 |
|------|------|------|
| 提供了 `template_path` | **克隆模式** | 分析模板结构 → 用新题目替换 |
| 提供了 `topics` 但无模板 | **知识点模式** | 根据知识点设计整份试卷 |
| 两者都提供 | **混合模式** | 克隆结构 + 知识点约束题目内容 |
| 都没有提供 | 报错 | 必须至少提供一项 |

#### 0.2 确定试卷类型

从用户输入或模板推断试卷类型，影响题目设计策略：

| 试卷类型 | 特征 | 典型结构 |
|----------|------|----------|
| **标准考试卷**（如 AP Mock） | 选择题 + 简答题，有计时限制 | Part A (无计算器) + Part B (需计算器) |
| **专项练习**（如积分练习） | 纯计算题，无选择题 | 按主题分 Section，题量大 |
| **错题/复习卷** | 概念诊断 + 应用 | 混合题型，难度递进 |
| **随堂测验** | 短小精悍，含姓名日期栏 | Name/Date 抬头，15-25 题 |

#### 0.3 读取模板（克隆模式）

```bash
# 读取模板文件
read "{template_path}"
```

**处理不同模板格式：**

| 模板格式 | 处理方式 |
|----------|----------|
| `.tex`（LaTeX 源码） | 直接解析文档类、宏包、`\\begin{document}` 内的结构 |
| `.md`（Markdown） | 先识别 YAML front matter（如有），再分析 Markdown 标题层级推断结构；将 Markdown 格式映射为等效 LaTeX 结构 |
| `.pdf` | 不可直接解析——终止并提示用户提供 `.tex` 或 `.md` 格式的模板 |

**从 LaTeX 模板提取的以下特征：**

| 特征 | 提取内容 |
|------|----------|
| 文档类与宏包 | `\documentclass[...]`, `\usepackage{...}` |
| 页面设置 | 边距、纸张大小、页眉页脚 |
| 题型结构 | 选择题/简答题/填空题，各部分数量 |
| 编号方式 | `\arabic*`, `\alph*`, `\Alph*` |
| 选项格式 | `(A)`, `\Alph*`, 4 或 5 选项 |
| 间距设置 | `\parskip`, `\itemsep`, `nosep` |
| 答案表格式 | 表格列数、排列方式 |
| 题目风格 | 题干长度、场景描述方式、公式密度 |
| 难度分布 | 简单/中等/困难的比例 |

**提取后记录为结构特征清单**，后续生成严格遵循。

#### 0.4 混合模式：模板 + 知识点协同

当同时提供 `template_path` 和 `topics` 时，两者协同工作：

| 场景 | 模板的作用 | 知识点的作用 |
|------|-----------|-------------|
| 模板科目匹配知识点 | 提供完整结构（题型分布、格式、难度） | 约束每道题的具体内容方向 |
| 模板科目不匹配知识点 | **不克隆**题目内容，仅借用格式（如选项样式、间距设置） | 完全决定题目内容 |
| 知识点多于模板覆盖 | 保持模板结构，多余知识点追加为额外 Section | 提供追加部分的出题范围 |
| 知识点少于模板覆盖 | 砍掉模板中未对应的 Section，或缩减题量 | 决定保留哪些模板 Section |

**示例**：模板是 45 题 AP Calculus BC 试卷（30 MCQ + 6 FRQ），提供 topics = "derivatives, integration"
→ 保留 MCQ 30 题、FRQ 6 题的结构
→ 题目全部改为导数与积分内容
→ 跳过原模板中的极坐标、级数题目

---

### Phase 1: 题目生成

#### 1.1 确定题目数量与分布

> 知识点模式的题目拆分与分配规则见 §6 知识点模式专项。以下为总览。

**克隆模式**：保持与原模板相同的题量、各题型比例、难度分布。

**知识点模式**：根据 `topics` 数量和复杂度分配：

| 知识点数 | 建议总题数 | 每题覆盖 |
|----------|-----------|----------|
| 1-3 个 | 15-25 | 每个知识点 5-8 题 |
| 4-6 个 | 25-35 | 每个知识点 4-6 题 |
| 7+ 个 | 35-45 | 每个知识点 3-5 题 |

#### 1.2 文档结构与 `\newcommand` 宏定义

从 AP 专项 skill 中提取的常用宏，可用于简化 LaTeX 编写：

```latex
\newcommand{\question}[1]{\textbf{#1}}          % 题目标签，如 \question{Q1:}（可选—不用也可直接写 \item）
\newcommand{\mcitem}[1]{\item[\textbf{#1}]}     % 选项标签，如 \mcitem{A}（可选—标准 enumerate 也可）
\newcommand{\prob}[1]{\item $\displaystyle #1$} % 纯计算题的积分/极限题目，如 \prob{\int x^2\, dx}
```

**`\prob` 用法示例（纯计算题 Section）：**
```latex
\section*{Section 1: U-Substitution}
\begin{enumerate}
    \prob{\int x\sqrt{1 + x^2}\, dx}
    \prob{\int e^{\sin x}\cos x\, dx}
    \prob{\int \frac{dx}{x\ln x}}
\end{enumerate}
```

**随堂测验/练习卷**可加姓名日期栏：
```latex
{\large Name: \underline{\hspace{4cm}} \qquad Date: \underline{\hspace{3cm}}}
```

**试卷结束标记**（可选）：
```latex
\vspace{0.5em}
\hrule
\vspace{0.3em}
\begin{center}
    {\itshape --- End ---}
\end{center}
```

#### 1.3 `\displaystyle` 规范

根据所有 AP Calculus source skills 的一致要求：

| 场景 | 要求 | 示例 |
|------|------|------|
| 题干中的极限 | `$\displaystyle\lim_{x\to a}$` | `$\displaystyle\lim_{x\to 0}\frac{\sin x}{x}$` |
| 题干中的积分 | `$\displaystyle\int_a^b f(x)\, dx$` | `$\displaystyle\int_0^1 x^2\, dx$` |
| 题干中的求和 | `$\displaystyle\sum_{n=1}^{\infty} a_n$` | `$\displaystyle\sum_{n=1}^{\infty}\frac{1}{n^2}$` |
| 分数（题干） | 复杂用 `\dfrac`，简单用 `\frac` | `$\dfrac{a}{b}$` vs `$\frac{a}{b}$` |
| 选项内公式 | **行内大小**（禁用 `\displaystyle`） | 选项里积分/求和保持紧凑 |
| 纯计算题 | `\prob` 宏自动加 `\displaystyle` | `\prob{\int x^2\, dx}` |

#### 1.4 LaTeX 数学符号规范（禁止 Unicode 替代）

所有数学公式**必须使用纯 LaTeX 命令**，不得用 Unicode 字符或 ASCII 替代。

| 含义 | LaTeX 命令（正确 ✅） | Unicode / ASCII（错误 ❌） |
|------|----------------------|--------------------------|
| 无穷 | `$\infty$` | `∞` |
| 偏导 | `$\partial$` | `∂` |
| 积分 | `$\int$` | `∫` |
| 求和 | `$\sum$` | `∑` |
| 属于 | `$\in$` | `∈` |
| 子集 | `$\subseteq$`, `$\subset$` | `⊆`, `⊂` |
| 空集 | `$\emptyset$`, `$\varnothing$` | `∅` |
| 点乘 | `$\cdot$` | `·` |
| 蕴涵 | `$\to$`, `$\rightarrow$` | `→` |
| 全称量词 | `$\forall$` | `∀` |
| 存在量词 | `$\exists$` | `∃` |
| 否定 | `$\neg$`, `$\lnot$` | `¬` |
| 合取/与 | `$\land$` | `∧` |
| 析取/或 | `$\lor$` | `∨` |

**原则**：任何在 LaTeX 数学模式中出现的符号，都必须用 `\command` 形式，不能用对应 Unicode 码点。这保证了：
- tectonic 编译不会因 Unicode 符号报错
- 公式在不同字体/环境下渲染一致
- PDF 复制粘贴不会丢失信息

例外：常见标点（+ - = < > / ( ) [ ] %）和普通字母数字可以直接输入。

#### 1.5 设计原则（来自多份 skill 的综合提取）

##### 题干设计

| 原则 | 要求 |
|------|------|
| 自包含 | 题干完整描述场景，不依赖外部图片 |
| 图片替代 | 原图场景用精确的英文文本描述替代 |
| 清晰无歧义 | 每道题只有一个正确的解释方向 |
| 全英文 | 题目/选项/说明全部为英文 |
| 数据独立 | 所有数值数据必须重新设计（克隆模式时全部替换为新值） |
| 无重复 | 同一份试卷内不出现相似题目 |
| 语言正式 | 使用学术英语，语法正确，术语标准 |

##### 选项设计

| 选项数 | 适用场景 |
|--------|----------|
| 4 个 (A-D) | 通用练习卷、校内考试、非 AP 标准化考试 |
| 5 个 (A-E) | AP 模拟卷、部分竞赛类考试 |

**每道题的选项必须满足：**

1.  **唯一正确答案** — 每题有且仅有一个正确选项
2.  **迷惑性干扰项** — 每个错误选项对应一种**常见的、真实的**学生错误
    - 要有明确的"错误来源"（如：符号错误、公式混淆、off-by-one、概念误解、单位错误等）
    - 不能是明显可排除的"凑数"选项
    - 至少有一个干扰项需要深度理解/完整推导才能排除
3.  **禁止项** — 不使用 "All of the above" / "None of the above" / "以上皆是" / "以上皆非"
4.  **选项独立** — 选项之间不重叠含义，不互相包含
5.  **数值接近**（数值题）— 正确值与干扰项数值在量级上接近，不能一眼看出

##### 数据修改规范（克隆模式 + 知识点模式均适用）

创建题目时，所有具体数值必须**重新设计**。参考以下修改范围：

| 数据类型 | 修改范围 | 示例 |
|----------|----------|------|
| 整数常量 | 变为不同的整数 | 100 | → 75 |
| 小数 | 改变有效数字 | 3.14 → 2.71 |
| 角度 | ±15°–30°偏移 | 30° → 45° |
| 函数参数 | 替换为同类函数 | sin → cos, x² → x³ |
| 矩阵维度 | 3×3 → 4×4 等 | 保持复杂度一致 |
| 代码变量 | 全部重命名 | nums → values |

> 修改后必须验证新数值是否保持数学/物理/逻辑合理性。

#### 1.6 克隆模式：题目替换策略

**不要直接照搬模板题目！** 克隆结构而非内容：

| 模板元素 | 克隆策略 |
|----------|----------|
| 某题考极限 | 换一组极限表达式（如 x→2 → x→0，多项式 → 三角） |
| 某题考导数应用 | 换场景（如速度 → 增长率，切线 → 线性逼近） |
| 某题考 String 方法 | 换字符串内容、换方法组合 |
| 某题考循环跟踪 | 换循环边界、换数组内容 |
| 简答题场景 | 保留题型结构（如"面积+旋转体"），换函数和边界 |

**结构克隆清单：**

- [ ] 保留题型分布（选择题 n 题 + 简答题 m 题）
- [ ] 保留各部分占比
- [ ] 保留难度比例（简单:中等:困难 ≈ 3:5:2）
- [ ] 保留每个小题的子题数量（如 FRQ 的 a/b/c/d）
- [ ] 全部替换为新的具体内容

---

### Phase 2: 答案分布编排

#### 2.1 答案分布目标

| 选项数 | 目标分布 |
|--------|----------|
| 4 选项 (A-D) | A≈B≈C≈D，各约 25% |
| 5 选项 (A-E) | A≈B≈C≈D≈E，各约 20% |

允许 ±1 题的偏差（如 40 题中 A 出现 9-11 次）。

#### 2.2 调节方法

1. 先写好题目和正确答案（不指定选项位置）
2. 然后将所有正确答案填入分布表，统计各选项出现次数
3. 对出现过多的位置，交换该题正确选项与一个未出现/出现少的选项位置
4. 交换后必须同步调整干扰项位置（即重新排列 A-B-C-D）
5. 验证：交换后所有干扰项仍然保持合理（没有把"严重错误"放到正确选项位置）

#### 2.3 避免可预测规律

- 不要连续 3 题以上相同答案（如 A-A-A）
- 不要形成明显模式（如 A-B-C-D-A-B-C-D）
- 不要因正确答案位置固定让某位置出现过多"正确"

---

### Phase 3: LaTeX 排版 — 纸张节省专项

这是本 skill 的核心特色。所有排版决策围绕**最大信息密度 + 最小纸张消耗**。

#### 3.1 文档配置

```latex
\documentclass[9pt,twocolumn,letterpaper]{extarticle}
% 使用 extarticle 支持 9pt（article 类不支持 9pt，会静默回退到 10pt）
% 9pt 比常规 10pt/11pt 节省约 10-15% 空间
% twocolumn 替代 multicols 环境，更高效利用页面

\usepackage{amsmath,amssymb}
\usepackage{enumitem}  % inputenc utf8 省略——LaTeX 2018+ 默认 UTF-8
\usepackage[margin=0.3in]{geometry}
% 0.3in 边距比常见 0.35in 进一步压缩
% 注意：无需加载 multicol 包——twocolumn 文档类选项已提供双栏
\pagestyle{empty}

% --- 极致紧凑设置 ---
\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}                    % 段落间不空行
\setlength{\columnsep}{0.25in}               % 栏间距压缩
\setlength{\topskip}{0pt}
\setlength{\headsep}{0pt}
\setlength{\footskip}{0pt}

% --- 列表间距压缩 ---
\setlist[enumerate]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}
\setlist[enumerate,2]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}

% --- 数学间距压缩 ---
\setlength{\abovedisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\belowdisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\abovedisplayshortskip}{0pt plus 1pt}
\setlength{\belowdisplayshortskip}{0pt plus 1pt}
```

#### 3.2 纸张节省排版检查清单

| 项目 | 推荐值 | 说明 |
|------|--------|------|
| 字号 | **9pt** 或 10pt | 9pt 每页多容纳约 15% 内容 |
| 纸张 | **letterpaper** (US) 或 **a4paper** | 保持默认网格 |
| 边距 | **0.3in** 或 **0.25in** | 最小安全边距，打印仍可接受 |
| 布局 | **twocolumn** (文档类) 或 `\begin{multicols}{2}` | 双栏布局 |
| 栏间距 | **0.2-0.25in** | 减少栏间空白 |
| 列表间距 | **nosep + itemsep=0pt + topsep=0pt** | 消除列表内外所有多余间距 |
| 数学间距 | abovedisplayskip ≤ 2pt | 公式前后压缩 |
| 段落间距 | **parskip=0pt** | 段落间不空行 |
| 页眉页脚 | 无 (pagestyle{empty}) | 省去页眉页脚占位 |
| 答案位置 | **答案文件单独生成**（见 Phase 4） | 试卷中不含答案 |
| 行距 | 默认 (不做 \linespread) | 压缩行距牺牲可读性得不偿失 |
| 图片 | 不用图片，用文本替代 | 图片极占空间 |

#### 3.3 模板

```latex
\documentclass[9pt,twocolumn,letterpaper]{extarticle}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage[margin=0.3in]{geometry}
\pagestyle{empty}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}
\setlength{\columnsep}{0.2in}

\setlist[enumerate]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}
\setlist[enumerate,2]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}

\setlength{\abovedisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\belowdisplayskip}{2pt plus 1pt minus 1pt}

\begin{document}

%% ===== TITLE =====
{\Large\bfseries Subject --- Exam Title}
\hfill
{\itshape N Questions}
\vspace{0.2cm}

%% ===== QUESTIONS =====
\begin{enumerate}[label=\textbf{\arabic*.}]

%% -- Question template --
\item Stem text ...
\begin{enumerate}[label=(\Alph*)]
    \item Option A
    \item Option B
    \item Option C
    \item Option D
\end{enumerate}

%% -- More questions --
\end{enumerate}

\end{document}
```

#### 3.4 答案文件模板 (`answer_key.tex`)

试卷 `exam.tex` **不含任何答案**。答案单独生成在 `answer_key.tex` 中，同样用 tectonic 编译。

```latex
\documentclass[9pt,letterpaper]{extarticle}
\usepackage[margin=0.5in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}
\setlength{\parindent}{0pt}

\begin{document}

{\Large\bfseries Answer Key --- [Exam Title]}
\vspace{0.3cm}

%% ===== MCQ ANSWER TABLE =====
\noindent\textbf{Section I: Multiple Choice}
\medskip

\noindent
\begin{tabular}{@{}c|c@{\hspace{1.2em}}c|c@{\hspace{1.2em}}c|c@{}}
\hline
\# & Ans & \# & Ans & \# & Ans \\
\hline
1  & A & 11 & C & 21 & B \\
2  & D & 12 & A & 22 & D \\
% ...
\hline
\end{tabular}

\vspace{0.5cm}

%% ===== FRQ SOLUTIONS =====
\noindent\textbf{Section II: Free Response}
\medskip

\noindent\textbf{Question 1}\\[0.3em]
\begin{enumerate}[label=\alph*.)]
    \item $\displaystyle \text{[solution]}$
    \item $\displaystyle \text{[solution]}$
\end{enumerate}

\noindent\textbf{Question 2}\\[0.3em]
% ...

%% ===== DISTRACTOR ANALYSIS =====
\vspace{0.3cm}
\noindent\textbf{Answer Justifications}
\medskip

\noindent\textbf{1.} Correct: A. \hfill Distractors: B (sign error), C (formula confusion), D (off-by-one)\\
\textbf{2.} Correct: D. \hfill Distractors: A (chain rule order), B (missing inner derivative), C (wrong antiderivative)\\

\end{document}
```

**答案文件包含：**
- 选择题答案表（紧凑多列格式）
- 简答题完整解答步骤
- 每题干扰项分析（可选，用于教师版）

#### 3.5 极端纸张节省技巧（经验之谈）

1. **加题不加页**：若剩余空间能塞下 1-2 题，调整题目长度使之适配
2. **公式内联**：能行内公式 `$(...)$` 的就不用显示公式 `\[...\]`，除非必要
3. **合并短题**：若两题都非常短，考虑合并为"一题两问"（如 a) ... b) ...）
4. **`\dfrac` 只在必要时用**：简单分数用 `\frac` 即可，省垂直空间
5. **单位紧凑**：`cm$^3$/s` 优于 `cm$^3$ / s`
6. **不用 `\displaystyle` 在选项中**：选项里的积分/求和保持行内大小
7. **题干和选项之间不要空行**：连续排版
8. **答案表复用模板**：预先设计不含题号的 `\foreach` 模板，填题号即可
9. **答案紧凑排列在答案文件中**：答案 `_answer_key.tex` 中也用紧凑排版，多题答案可共用一页

---

### Phase 4: 答案文件单独生成（强制）

**答案与试卷必须分离为两个独立文件**。试卷中不出现任何答案或解答。

#### 4.1 逐题答案记录

设计每道题时必须同步记录：

```
题号: 3
正确答案: C
验证过程: [逐步推导]
干扰项分析:
  A: 典型错误——忘记取绝对值 → 得 -5
  B: 典型错误——混淆链式法则顺序 → 得 2x·sin(x)
  D: 典型错误——漏掉内层导数 → 得 cos(x²)
```

#### 4.2 生成 `answer_key.tex`

使用 §3.4 的模板，将上述记录填入：

**答案表**：选择题答案以多列紧凑表格呈现
- 40 题以下用 3 列（# / Ans / # / Ans / # / Ans）
- 40 题以上用 4 列

**解答步骤**：简答题提供完整推导
- 每个子题（a/b/c/d）单独列步骤
- 关键中间结果标注
- 最终答案加粗或框出

**干扰项分析**（可选但推荐）：
- 每题一行，标注正确选项 + 各干扰项的错误原因

```latex
\noindent\textbf{3.} Correct: C. \hfill Distractors: A (missing abs), B (chain rule order), D (inner derivative)\\
```

#### 4.3 答案验证（强制）

**在答案文件中，必须对每道题进行验证**（写入答案文件内容前）：

| 题型 | 验证方法 |
|------|----------|
| 数学计算题 | 逐步推导，确认最终值 |
| 概念题 | 确认概念定义无偏差 |
| 代码跟踪题 | 逐行模拟执行 |
| 代码写作题 | 确认语法正确、逻辑完整 |
| 图形/几何 | 检查数值合理性 |

#### 4.4 完整性检查

- [ ] 试卷不含任何答案标记
- [ ] 答案表中题号与试卷一一对应
- [ ] 答案分布符合目标（各选项出现次数偏差 ≤ 1）
- [ ] 简答题有完整解答步骤
- [ ] 每道选择题的干扰项已标注错误来源

---

### Phase 4.5: 写入 .tex 文件

在编译前，将设计好的内容写入两个 .tex 文件。

#### 4.5.1 构建文件名

根据 §0 的输入参数构建文件名：
```
{subject}_{exam_type}_{output_name}.tex            → 试卷源码
{subject}_{exam_type}_{output_name}_answer_key.tex → 答案源码
```

若 `subject` 为空，则从模板文件名或 `topics` 推断；若 `exam_type` 为空，默认用 `Practice`。

#### 4.5.2 写入试卷文件

使用 `write` 工具创建 `{subject}_{exam_type}_{output_name}.tex`：
1. 应用 §3.3 的模板结构
2. 填入 Phase 1 设计的题目内容
3. **不包含**答案表、解答步骤、干扰项分析
4. 检查所有 `\ref` / `\label` 一致性

#### 4.5.3 写入答案文件

使用 `write` 工具创建 `{subject}_{exam_type}_{output_name}_answer_key.tex`：
1. 应用 §3.4 的答案模板结构
2. 填入 Phase 4 整理的答案表、解答步骤、干扰项分析

> **写入前必须先执行 Git 安全网步骤**（见 §Git 安全网 + 文件写入安全）
> 用 `glob` 或 `find` 确认目标文件是否已存在，已存在时优先用 `edit` 而非 `write`。

---

### Phase 5: 双文件编译

#### 5.1 编译试卷和答案

```bash
cd "{output_dir}"
# 编译试卷
 tectonic "{subject}_{exam_type}_{output_name}.tex"
# 编译答案
 tectonic "{subject}_{exam_type}_{output_name}_answer_key.tex"
```

**预期产物：**
```
{subject}_{exam_type}_{output_name}.tex              → 试卷 LaTeX 源码（不含答案）
{subject}_{exam_type}_{output_name}.pdf              → 试卷 PDF（给学生）
{subject}_{exam_type}_{output_name}_answer_key.tex   → 答案 LaTeX 源码
{subject}_{exam_type}_{output_name}_answer_key.pdf   → 答案 PDF（给教师）
```

示例：
- `AP_Calculus_BC_Practice_Test_1.tex` + `AP_Calculus_BC_Practice_Test_1_answer_key.tex`
- `Linear_Algebra_Quiz_Midterm.tex` + `Linear_Algebra_Quiz_Midterm_answer_key.tex`

#### 5.3 编译异常处理

| 症状 | 处理方式 |
|------|----------|
| `Underfull \hbox` 警告 | 无操作——排版警告可忽略，不影响内容 |
| `Overfull \hbox` | 在对应行加 `\emergencystretch=0.5em` 或调整换行 |
| 缺少宏包错误 | 安装缺失宏包或替换为等效功能 |
| LaTeX 语法错误 | 定位错误行修复后重新编译 |
| tectonic 未安装 | `cargo install tectonic` |

#### 5.4 验证输出

编译完成后检查：

- [ ] 试卷 PDF 正常生成，页数合理
- [ ] 答案 PDF 正常生成
- [ ] 所有数学公式渲染正确
- [ ] 选项对齐正常
- [ ] 试卷中不含任何答案标记
- [ ] 无内容被截断或溢出页边距

#### 5.5 答案正确性最终核查（强制）

**这是最关键的一步。生成流程结束后，必须对所有答案进行逐题正确性核查。**

AI 有编造答案的倾向，尤其在试题量大的情况下。此步骤不可跳过。

**核查流程：**

1. **逐一对照**：打开 `_answer_key.tex`，对每个题号，去 `.tex` 源码中找到对应题目
2. **验证每题**：对每道题重新做一遍（计算/推导/代码跟踪），确认答案表中的选项确实正确
3. **标记可疑**：若发现某题答案存疑，立即重新计算。不确定时用 subagent 求助或搜索确认
4. **修复错误**：发现错误后：
   - 修复 `_answer_key.tex` 中的答案
   - 如果错误是因题目本身设计问题导致，同时修复 `.tex` 中的题目
   - 重新编译两个文件
5. **二次核查**：修复后再次确认所有答案正确
6. **最终确认**：确认后才可报告任务完成

**核查记录模板（直接在回复中输出）：**
```
=== 答案核查 ===
Q1: C → 验证: lim_{x→0} sin(x)/x = 1 ✅
Q2: D → 验证: 链式法则正确 ✅
Q3: A → 验证: ... ❌ 计算错误，应为 B（已修复）
...
总计: N/N 通过
```

**必须生成核查记录并逐题确认后，才能报告任务完成。**

当 `template_path` 为空、仅提供 `topics` 时，采用知识点模式：

### 6.1 知识点拆分

将用户提供的知识点描述拆分为可出题的最小单元：

```
用户输入: "极限与连续，导数定义，洛必达法则"
→ 拆分:
  1. 极限的 ε-δ 定义
  2. 极限的四则运算
  3. 夹逼定理
  4. 间断点分类
  5. 导数的极限定义
  6. 可导与连续的关系
  7. 洛必达法则适用条件
  8. 洛必达法则应用（0/0, ∞/∞）
```

### 6.2 题目分配

| 知识点粒度 | 每知识点题数 | 说明 |
|-----------|-------------|------|
| 大单元（如"导数应用"） | 4-6 题 | 覆盖子主题 |
| 中主题（如"相关速率"） | 2-3 题 | 覆盖主要变体 |
| 小知识点（如"某定理"） | 1-2 题 | 概念理解 + 简单应用 |

### 6.3 难度分配

| 难度 | 占比 | 特征 |
|------|------|------|
| Easy | 30% | 单一概念，直接计算，直接识别 |
| Medium | 50% | 两步骤推理，涉及概念组合 |
| Hard | 20% | 多步骤推理，需要策略选择，综合多个知识点 |

---

## 输出检查清单

### 试卷内容
- [ ] 所有题目为全英文
- [ ] 题干自包含（不依赖外部图片）
- [ ] 每题恰好一个正确答案
- [ ] 每个干扰项有明确错误来源
- [ ] 无 "All of the above" / "None of the above"
- [ ] 无重复或相似的题目
- [ ] 答案分布均衡（偏差 ≤ 1）

### 排版
- [ ] 使用 9pt 或 10pt 字号
- [ ] 双栏布局（twocolumn 或 multicols{2}）
- [ ] 边距 ≤ 0.3in
- [ ] 所有间距压缩（nosep, parskip=0pt, abovedisplayskip ≤ 2pt）
- [ ] 无页眉页脚
- [ ] LaTeX 语法无错误
- [ ] 标题中的科目占位符已替换为实际名称
- [ ] `\displaystyle` 使用符合 §1.3 规范
- [ ] 纯计算题使用 `\prob` 宏（如适用）
- [ ] 试卷不含任何答案（答案在 `_answer_key.tex` 中）

### 克隆模式额外
- [ ] 题型分布与模板一致
- [ ] 难度分布与模板一致
- [ ] 所有题目数据已更换为新值
- [ ] 选项数一致（模板用 5 个选项则新试卷也用 5 个）

### 编译
- [ ] `{output_name}.tex` + `{output_name}_answer_key.tex` 均编译成功
- [ ] 两张 PDF 均输出正常
- [ ] Overfull hbox 已处理
- [ ] 试卷 PDF 不含答案内容

### 答案文件
- [ ] 选择题答案表与试卷题号一一对应
- [ ] 简答题有完整解答步骤
- [ ] 干扰项分析已标注错误来源
- [ ] 答案分布均衡（偏差 ≤ 1）

### 最终核查（强制）
- [ ] 对答案文件中的每道题进行了重新验证（§5.5）
- [ ] 所有答案计算/推导确认正确
- [ ] 发现的错误已修复并重新编译
- [ ] 核查记录已输出

---

## 关于知识边界

本 skill 涉及的科目范围不限定，AI 的知识覆盖可能不足。

- **出题时必须验证所有计算和推导**，不依赖"记忆中的答案"
- **干扰项设计必须有真实错误来源**，不捏造"看起来合理"的迷惑项
- **数学/科学公式必须逐步验证**，不能仅靠直觉判断正确性
- **若某知识点超出模型训练数据的可靠范围**，明确标记"建议由领域专家审核此部分"

参见 [知识边界规范](../knowledge_boundary.md)。

---

## Git 安全网 + 文件写入安全

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。

执行 `write` 或 `edit` 前必须：

1. 读取 `git_safety_net.md` 并执行 git 版本追踪指令
2. 用 `glob` 或 `find` 检查目标文件是否已存在
3. 文件已存在时优先用 `edit` 修改，不用 `write` 覆写
4. 确需覆写时先告知用户


