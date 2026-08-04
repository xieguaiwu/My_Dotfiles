---
name: error-checklist-creator
version: 1.4.0
description: 按学科生成全英文超紧凑LaTeX易错点清单——三轨排版：文科轨（liberal_arts，AP_Lang 表格型 + Tip/Rule + Quick Checklist）、理科轨（science，common_necessaties / physics_common 双栏公式速查）、计算机轨（cs，最终CSA易错点整理 代码驱动型）；只积累普遍性易错规律、禁止照搬具体错题；所有轨道产出物一律全英文
triggers:
  - "易错点清单"
  - "生成错题清单"
  - "error checklist"
  - "错误清单排版"
  - "学科易错点"
  - "易错总结"
  - "清单排版"
inputs:
  - name: subject
    description: 学科名称（如 AP English、AP Physics、German、AP Biology 等）
    required: true
  - name: topics
    description: 需覆盖的主题列表（逗号分隔）
    required: false
    default: "all"
  - name: output_dir
    description: 输出目录
    required: false
    default: "."
  - name: output_name
    description: 输出文件名（不含扩展名）
    required: false
    default: "{subject}_Error_Checklist"
  - name: style
    description: 排版轨道（liberal_arts=文科表格型[默认] / science=理科公式速查型 / cs=计算机代码型 / biology=9pt错题表格型[文科变体]；ap_lang、physics 为兼容别名）
    required: false
    default: "liberal_arts"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - subagent
---

# 易错点清单生成器 (Error Checklist Creator)

## 任务目标

基于用户指定的学科和主题，生成**全英文、超紧凑、吃重点**的 LaTeX 易错点清单。

**排版按学科轨道三选一**：

- **文科轨 `liberal_arts`**：完全模仿 `~/高一/英语/AP English/AP_Lang_Master_Checklist.tex`（单栏 booktabs 表格 + Tip/Rule + Quick Checklist），精简变体参考 `~/高一/英语/AP English/Rhetorical_Devices_Checklist.tex`
- **理科轨 `science`**：模仿 `~/高一/数学/common_necessaties.tex` 与 `~/高一/物理/physics_common.tex`（双栏公式速查，`\sect/\subsect` 分节，7-8pt 极限密度）
- **计算机轨 `cs`**：模仿 `~/高一/ap计算机/最终CSA易错点整理.tex`（8pt 单栏代码驱动：lstlisting 代码块 + itemize + 对比表 + `\imp` 红字强调）

**所有轨道产出物一律全英文，禁止任何中文**（含代码注释、易错点描述、表头、Tip/Rule）——CS 模板原稿为中英混合，生成时必须全部英文化，并删除 fontspec/XeTeX 中文依赖。

确保：

- 一页承载最大信息量
- 错误类型清晰分类（文科：表格呈现；理科：公式行 + 陷阱对照）
- 每条错误/要点都有「错误形式 - 正确形式 - 说明」三要素
- **只积累普遍性知识，不做错题照搬**：每条易错点必须是脱离具体题目也可成立的普遍规律（规则/公式/思维陷阱），可迁移到同类题；禁止粘贴题干、题号、专有数字链、人名/情境；示例仅作一行式数字演示
- **产出物一律全英文，禁止中文**（含代码注释、易错点描述、表头、Tip/Rule，所有轨道统一）
- **编译仅使用 tectonic**（全英文内容无中文依赖，不需要 xelatex）

---

## 排版规范 —— 三轨总览

> 参考文件：
> - 文科轨：`~/高一/英语/AP English/AP_Lang_Master_Checklist.tex`（AP 英语主清单，867 行）、`~/高一/英语/AP English/Rhetorical_Devices_Checklist.tex`（文科精简变体）、`~/高一/生物/期末复习/Biology_Error_Checklist.tex`（9pt 表格型）、`~/高一/德语/German_Error_Checklist.tex`（德语错题表）
> - 理科轨：`~/高一/数学/common_necessaties.tex`（7pt 数学公式表）、`~/高一/物理/physics_common.tex`（8pt 物理公式表）
> - 计算机轨：`~/高一/ap计算机/最终CSA易错点整理.tex`（8pt 单栏代码驱动型，原稿中英混合 → 产出须全英文化，见 H 节）

| 维度 | 文科轨 `liberal_arts`（表格驱动） | 理科轨 `science`（公式驱动） |
|------|--------------------------------|------------------------------|
| 参考模板 | AP_Lang_Master_Checklist.tex（主）/ Rhetorical_Devices_Checklist.tex（精简） | common_necessaties.tex（数学）/ physics_common.tex（物理） |
| 字号/纸张 | 10pt a4paper（可降 9pt） | 7pt（数学）/ 8pt（物理）letterpaper |
| 边距 | 0.55in | 0.3in（数学）/ 0.25in（物理） |
| 布局 | 单栏 | 双栏 `multicols*`，columnsep 4pt |
| 分节 | `\section*{Part X}` + `\subsection*{分类}`（titlesec 压缩） | `\sect{编号. 主题}` + `\subsect{子节}`（hrule 分隔） |
| 内容载体 | booktabs 表格（4列概念表 / 3列错对表 / 2列模板表） | 公式行流式排版 + 少量小型对照表 |
| 每节总结 | `\textbf{Tip:}` / `\textbf{Rule:}` 必加 | 简短 `\textit{Note:}` / `\textbf{...}`，可省 |
| 勾选清单 | Quick Checklist（`$\square$` itemize） | 无 |
| 词库 | multicols 词汇银行（可选） | 无（公式即词库） |
| 数学排版 | 仅行内 `$...$` | amsmath 全量 + mathtools + `\thinmuskip` 等收紧 |
| 图表 | 无 | tikz 可选（物理示意图） |
| 页眉 | `\pagestyle{empty}` | 数学版 fancyhdr 页眉 / 物理版 empty |

> 计算机轨 `cs` 与上述两轨差异较大（8pt extarticle 单栏 + lstlisting 代码块 + `\imp` 红字强调），单独成节，详见 H 节。

### A. 文科轨前导码（默认，直接复制 AP_Lang_Master_Checklist.tex）

```latex
\documentclass[10pt,a4paper]{article}

\usepackage[margin=0.55in]{geometry}
\usepackage{booktabs}
\usepackage{array}
\usepackage{enumitem}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{setspace}
\usepackage{xcolor}
\usepackage{colortbl}
\usepackage{multicol}
\setstretch{0.78}
\raggedbottom
\usepackage{titlesec}
\pagestyle{empty}
\titlespacing*{\section}{0pt}{0.6ex}{0.2ex}
\titleformat*{\section}{\normalsize\bfseries}
\titlespacing*{\subsection}{0pt}{0.2ex}{0.05ex}
\titleformat*{\subsection}{\small\bfseries}

\begin{document}
\setlength{\topsep}{0pt}
\setlength{\partopsep}{0pt}
\vspace*{-2em}
```

> 注：tectonic 下 `\usepackage[utf8]{inputenc}` 会提示已过时（无害警告），可删；`hyperref` 首次编译会自动拉取宏包（需联网）。

### B. 文科轨页面与字号 —— 密度分级

| 密度级 | 字号 | 边距 | 布局 | 适用场景 |
|--------|------|------|------|---------|
| **AP_Lang 默认** | 10pt | 0.55in | 单栏 | **文科通用推荐**（完全模仿 AP_Lang） |
| **紧凑** | 9pt | 0.4in | 单栏 | 文科内容较多时 |
| **极限** | 7-8pt | 0.25-0.3in | 双栏 `multicols*` | **改走理科轨**（公式速查/海量公式） |

纸张: **a4paper**（与 AP_Lang 一致）。段距: `\parskip=0pt` `\parindent=0pt`。页眉页脚: `\pagestyle{empty}`。行距: `\setstretch{0.78}`（AP_Lang 原值）。标题区: 顶部 `\vspace*{-2em}` 去空白。

### C. 文科轨章节结构 —— AP_Lang 风格

```latex
% 大分区（Part）
\section*{Part I: Rhetorical Devices Checklist}
\addcontentsline{toc}{section}{Part I: Rhetorical Devices Checklist}

% 小节（分类）
\subsection*{Appeals \& Emotional Devices}
```

- 大分区用 `\section*` + `\addcontentsline`（titlesec 已压缩间距）
- 分类小节用 `\subsection*`（titlesec 压缩：`0.2ex/0.05ex`）
- **每节内容后加 `\textbf{Tip:}` 或 `\textbf{Rule:}` 总结段**（AP_Lang 每节都有）

**理科轨变体标题宏**（`style=science` 时用，完整前导码见 F 节）：`\sect{编号. 主题}` 大分区 + `\subsect{子节}` 小分节，`\sect` 自带 `\hrule` 分隔线

### D. 文科轨数据呈现 —— 核心表格（booktabs + center + footnotesize）

**D1. 四列表（AP_Lang Part I 风格，最常用）** — 术语/概念清单

适用于：任何「概念 - 定义 - 分析/要点 - 示例」型内容。

```latex
\begin{center}
\footnotesize
\begin{tabular}{p{2.6cm}p{3.2cm}p{3.2cm}p{5.3cm}}
\toprule
\textbf{Device} & \textbf{Definition} & \textbf{Analysis Focus} & \textbf{Example} \\
\midrule
Diction & Word choice (formal / colloquial, positive / negative connotation) & Conveys attitude; shapes tone & Compare: ``protesters'' vs.\ ``rioters'' --- same action, different judgment. \\
\bottomrule
\end{tabular}
\end{center}
```

**D2. 三列表（AP_Lang Part II 风格）** — 错误-正确对比

适用于：任何有「错误-正确」对比的场景（语法、拼写、介词、用词）。

```latex
\begin{center}
\footnotesize
\begin{tabular}{p{3.5cm}p{3.5cm}p{6cm}}
\toprule
\textbf{Wrong} & \textbf{Right} & \textbf{Pattern / Explanation} \\
\midrule
deeply rooted & deeply rooted \textbf{in} & ``rooted'' requires ``in'' \\
\bottomrule
\end{tabular}
\end{center}
```

**D3. 模板/策略表（AP_Lang Part III 风格）** — 两列或三列

适用于：可复用句型、写作模板、分析框架。

```latex
\begin{center}
\footnotesize
\begin{tabular}{p{5cm}p{8cm}}
\toprule
\textbf{Template} & \textbf{Example} \\
\midrule
Rather than [X], the author [Y] & ``Rather than lecturing the audience, Cronon lets the evidence speak.'' \\
\bottomrule
\end{tabular}
\end{center}
```

**列宽总约束**：A4 单栏可用宽 = 21cm − 2×0.55in ≈ **18.2cm**。表格列宽合计 + tabcolsep（默认 6pt×8≈1.7cm）必须 ≤ 可用宽。上表 14.3 / 13 / 13cm 均安全。`style=biology` 时用 `p{0.3cm}p{2.6cm}p{2.6cm}p{8.8cm}`（\# | Wrong | Correct | Note）。

**表头必为英文**：`Device / Definition / Analysis Focus / Example`、`Wrong / Right / Pattern / Explanation`、`\# / Error / Correction / Note`。

### E. 文科轨内容要素（AP_Lang 独有，必须模仿）

1. **Quick Checklist**（Part 末尾，勾选式清单）：
```latex
\begin{itemize}[nosep, leftmargin=2.2em, label=$\square$]
  \item \textbf{Appeals}: Identify Ethos / Pathos / Logos balance --- which dominates and why?
\end{itemize}
```
2. **词汇/术语银行**（多栏压缩，可选）：
```latex
\begin{multicols}{4}
\raggedcolumns
\footnotesize
\textbf{Tone Descriptors}\par
\vspace{0.3em}
calm yet penetrating\par
...
\end{multicols}
```
3. **颜色标记**（理科轨可选，AP_Physics_Error_Checklist 风格，用于陷阱强调）：
```latex
\newcommand{\err}[1]{\textcolor{red}{\textbf{#1}}}
\newcommand{\corr}[1]{\textcolor[gray]{0.25}{\textbf{#1}}}
```

### F. 理科轨（`style=science`）—— 公式驱动（参考 common_necessaties.tex / physics_common.tex）

**F1. 前导码**（数学 7pt 版提炼自 `common_necessaties.tex`；物理 8pt 版调整自 `physics_common.tex`）：

```latex
\documentclass[7pt,letterpaper]{article}   % 数学 7pt；物理 8pt
\usepackage[margin=0.3in]{geometry}        % 数学 0.3in；物理 0.25in
\usepackage{amsmath,amssymb,amsfonts}
\usepackage{mathtools}                     % 数学版必需
\DeclareMathOperator{\arccsc}{arccsc}      % 缺失运算符用 \DeclareMathOperator 定义
\DeclareMathOperator{\arccot}{arccot}
\DeclareMathOperator{\arcsec}{arcsec}
\usepackage{enumitem}
\usepackage{multicol}
\usepackage{fancyhdr}                      % 数学版页眉；物理版改 \pagestyle{empty}
\usepackage{xcolor}
\usepackage{array}                         % 物理版（对照表）+ tikz（示意图）

\pagestyle{fancy}
\fancyhf{}
\rhead{\scriptsize {Subject} Formula Sheet}
\lhead{\scriptsize Page \thepage}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}                  % 物理版 0.3em
\setlist[itemize]{leftmargin=*,itemsep=0pt,topsep=0pt,parsep=0pt}
\setlength{\columnsep}{4pt}

% 数学间距收紧（两版通用）
\thinmuskip=1mu
\medmuskip=1mu minus 1mu
\thickmuskip=2mu minus 2mu

\newcommand{\sect}[1]{\vspace{0.05em}\noindent\textbf{\small #1}\hrule\vspace{0.05em}}
\newcommand{\subsect}[1]{\noindent\textbf{#1}\\[0.05em]}

\begin{document}
\begin{multicols*}{2}
% ...公式流...
\end{multicols*}
\end{document}
```

**F2. 结构规范**：
- `\sect{编号. 主题}` 大分区（数学版编号如 `\sect{5. Integration}`；物理版可省编号），`\subsect{子节}` 小分节
- 内容形式：**公式行流式排版**——多个公式同行用 `\quad` / `\hfill` 分隔，复杂推导另起一行；每个公式 `$...$` 或独立公式
- 对照/数据用小型 `tabular`：`{lll}`（如 trig substitution 对照表）、`{cccc}`（角度三角函数值表）、`{ll}`（转动惯量表/考试结构表）
- 易错陷阱：`\begin{itemize}` 条目或 `\textit{Note:}` 句（如 `\textit{Never mix the two rules}: monotonicity $\to$ $L_n/R_n$; concavity $\to$ $M_n/T_n$.`）
- 关键强调用 `\textbf{...}`（如 `\textbf{Necessary condition}`）；物理版需要示意图时用 `tikz`
- 可选陷阱标记（AP_Physics_Error_Checklist 风格）：`\newcommand{\err}[1]{\textcolor{red}{\textbf{#1}}}`、`\newcommand{\corr}[1]{\textcolor[gray]{0.25}{\textbf{#1}}}`

**F3. 数学版 vs 物理版差异**：

| 差异项 | 数学（common_necessaties.tex） | 物理（physics_common.tex） |
|--------|-------------------------------|----------------------------|
| 字号/边距 | 7pt / 0.3in | 8pt / 0.25in |
| 页眉 | fancyhdr（`\rhead{\scriptsize ... Formula Sheet}`） | `\pagestyle{empty}` |
| parskip | 0pt | 0.3em |
| 额外宏包 | mathtools（+ `\DeclareMathOperator`） | array、tikz |
| 内容重点 | 公式全集 + 规则对照表 | 公式 + 物理量注释 + 数据表 + 示意图 |

**F4. 文科错题表格变体（`style=biology`，归文科轨）** — 9pt a4paper 0.4in 单栏：
- 表格列 `p{0.3cm}p{2.6cm}p{2.6cm}p{8.8cm}`：`\# | Wrong | Correct | Note`
- 参考 `Biology_Error_Checklist.tex` / `German_Error_Checklist.tex`

### G. 公式与符号规范（理科轨核心；文科/计算机轨遇零星公式同样适用）

1. **禁止 Unicode 数学符号**：所有数学符号必须用 LaTeX 命令。`→` 用 `\to`/`\rightarrow`；`∀` 用 `\forall`；`∃` 用 `\exists`；`∈` 用 `\in`；`¬` 用 `\neg`；`∧` 用 `\land`；`∨` 用 `\lor`；`≠` 用 `\neq`；`≤/≥` 用 `\leq`/`\geq`；`∞` 用 `\infty`；`∂` 用 `\partial`；`√` 用 `\sqrt{}`；`·` 用 `\cdot`；`×` 用 `\times`；`°` 用 `\circ`；`∑` 用 `\sum`；`∫` 用 `\int`；`π` 用 `\pi`；`θ` 用 `\theta`；`μ` 用 `\mu`；`∅` 用 `\emptyset`；`⊆` 用 `\subseteq`；`⇒` 用 `\Rightarrow`；`⋯` 用 `\dots`/`\cdots`。不确定的符号查证后再写。
2. **单位/变量区分**：物理单位用 `\mathrm{}` 正体（`$\mathrm{kg}$`），变量默认斜体（`$m$`）；数字与单位间加 `\,`（`$5\,\mathrm{kg}$`）。
3. **多字符上下标用花括号**：`$v_{0}$`、`$e^{2x}$`。
4. **行内公式优先**：表格中公式一律 `$...$`；独立公式 `\[...\]` 占比 ≤5%；复杂分式用 `\dfrac`。
5. **省略号**：用 `\dots`/`\cdots`，禁止三个句点。
6. **标点例外**：`+ - = < > / ( ) [ ] %` 和普通字母数字可直接输入。

### H. 计算机科学轨（`style=cs`）—— 代码驱动（参考 最终CSA易错点整理.tex）

> 原稿 `~/高一/ap计算机/最终CSA易错点整理.tex` 为中英混合（fontspec + Noto Sans SC + XeTeX 中文断行）；**产出时必须全英文化**：删除 fontspec/XeTeX 中文设置，代码注释、易错点描述、表头一律英文，改回 tectonic 编译。

**H1. 前导码**（全英文版提炼，tectonic 可直接编译）：

```latex
\documentclass[8pt,a4paper]{extarticle}   % extarticle 支持 8pt

\usepackage[margin=0.25in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{booktabs}
\usepackage{array}
\usepackage{enumitem}
\usepackage{xcolor}
\usepackage{hyperref}
\usepackage{setspace}
\usepackage{titlesec}
\usepackage{listings}                     % 代码高亮（核心）
\lstset{
  language=Java,
  basicstyle=\ttfamily\small,
  keywordstyle=\color{blue}\bfseries,
  commentstyle=\color{gray}\itshape,
  stringstyle=\color{red},
  showstringspaces=false,
  breaklines=true,
  frame=none,
  xleftmargin=0.3em,
  framexleftmargin=0.2em,
  numbers=none,
  tabsize=4,
  columns=flexible,
  morekeywords={String,boolean,var},
  literate={<=}{{$\leq$}}1 {>=}{{$\geq$}}1 {!=}{{$\neq$}}1,
}
\hypersetup{colorlinks=true,linkcolor=blue!60!black,urlcolor=blue!70!black}
\setstretch{0.7}
\raggedbottom
\pagestyle{empty}
\titlespacing*{\section}{0pt}{0.6ex}{0.2ex}
\titleformat*{\section}{\normalsize\bfseries}
\titlespacing*{\subsection}{0pt}{0.2ex}{0.05ex}
\titleformat*{\subsection}{\small\bfseries}

\definecolor{impcolor}{RGB}{180,30,30}
\newcommand{\imp}[1]{\textcolor{impcolor}{\textbf{#1}}}   % 易错强调（红字加粗）

\begin{document}
\vspace*{-2em}
\setlength{\topsep}{0pt}
\setlength{\partopsep}{0pt}
% ...内容...
\end{document}
```

**H2. 结构规范**：
- 大分区 `\section{Unit 1: ...}`（原稿按月组织 Sep/Oct/Nov/Dec/Jan/March/FRQ，可按单元/主题组织），小分节 `\subsection{主题}`，必要时 `\subsubsection{子主题}`
- 内容载体：**lstlisting 代码块为主**（每个易错点配错误/正确代码示例）+ itemize 要点 + 少量 tabular 对比表
- 代码术语一律 `\texttt{...}`（如 `\texttt{String.length()}`）；易错点用 `\imp{...}` 红字加粗强调（`\imp{Common mistake:}`、`\imp{Key point:}`、`\imp{Note:}`）
- 对比表：如 `public` vs `public static` 特性表、Scanner hasNext/next 对照表、选项分析表（`\checkmark` / `$\times$`）
- 算法要点：时间复杂度/空间复杂度/稳定性用 itemize 或 `\textbf{}` 条目列出
- 数学符号沿用 G 节规范（行内公式：`$O(n^2)$`、`$\lceil \log_2(n+1) \rceil$`）

**H3. 全英文化转换规则**（原稿中英混合，产出时必须转换）：

| 原稿位置 | 转换 |
|---------|------|
| `\imp{易错}` / `\imp{重点}` / `\imp{注意}` | `\imp{Common mistake:}` / `\imp{Key point:}` / `\imp{Note:}` |
| 中文描述句（如"注意Java中的常量关键字是…"） | 全英文描述（`In Java, constants use the keyword \texttt{final}...`） |
| 代码内中文注释（如 `// 抛出 ArithmeticException`） | 英文注释（`// throws ArithmeticException`） |
| 中文表头（如"判断方法/读取方法"） | 英文表头（`Predicate / Reader`） |
| fontspec、`\setmainfont{Noto Sans SC}`、`\XeTeXlinebreaklocale "zh"` | 全部删除（无中文 → 无 CJK 依赖 → tectonic 编译） |

---

## 执行流程

### 阶段 1：理解需求与学科分析

1. 读取用户指定的 `{subject}` 和 `{topics}`
2. 如果 `{topics}` 为 "all"，自动分解为该学科的核心模块（物理力学/电磁、AP 英语修辞/语法、德语动词/变格/介词、生物分子/遗传等）
3. 按分类识别该学科/主题下的**高频易错点**（具体、不空泛）

### 阶段 2：内容组织（全英文三要素）

对每个易错点，必须按「三要素」呈现（全英文）。**每个易错点必须提炼为普遍性规律**：错题/试卷只作触发素材，产出时一律泛化——去掉题设上下文、专有数字、人名/情境；「错误形式」给出该规律的普遍形态（pattern），「说明」给出规则/记忆点，使条目脱离原题仍成立、可迁移到同类题。

```
┌──────────┬─────────────────────────────────┐
│ 要素     │  要求（英文）                   │
├──────────┼─────────────────────────────────┤
│ 错误形式 │ Real, specific wrong usage      │
│ 正确形式 │ The corresponding correct usage │
│ 说明     │ Brief reason + memory tip       │
└──────────┴─────────────────────────────────┘
```

- **表格型**（AP_Lang 风格）：`Wrong | Right | Explanation` 三列表
- **公式型**（物理风格）：公式 + 常见陷阱（`\err{...}` / `\corr{...}` 成对）
- **清单型**：`Device | Definition | Analysis Focus | Example` 四列表

### 阶段 3：选择排版轨道

| 内容类型 | style 参数 | 模板参考 |
|---------|-----------|---------|
| **文科**：概念/术语清单（修辞、语法规则、文学、历史、学科知识点） | `liberal_arts`（默认） | AP_Lang_Master_Checklist.tex（精简变体 Rhetorical_Devices_Checklist.tex） |
| **文科**：错题表格（生物/德语等大量 Wrong/Correct 对） | `biology` | Biology_Error_Checklist.tex / German_Error_Checklist.tex |
| **理科**：公式速查（数学/物理/化学/统计） | `science` | common_necessaties.tex（数学）/ physics_common.tex（物理） |
| **计算机**：代码/语法易错点（编程语言、算法、数据结构） | `cs` | 最终CSA易错点整理.tex（全英文化） |

### 阶段 4：LaTeX 文档生成

1. 先按学科选轨道：文科（英语/德语/生物/历史等）→ `liberal_arts`（或 `biology` 变体）用 A-E 节规范；理科（数学/物理/化学/统计）→ `science` 用 F 节规范；计算机（编程/算法/数据结构）→ `cs` 用 H 节规范
2. 文科轨：`\section*{Part X}` 分区 + `\subsection*{分类}` 小节，逐分类输出表格内容；理科轨：`\sect` + `\subsect` 公式流；计算机轨：`\section{Unit}` + `\subsection` + lstlisting 代码块
3. 文科轨**每节后加 `\textbf{Tip:}` 或 `\textbf{Rule:}` 总结**；理科轨关键处加 `\textit{Note:}` / `\textbf{...}`；计算机轨易错点用 `\imp{...}` 强调
4. 文科轨内容较长的 Part 末尾加 **Quick Checklist**（`$\square$` 勾选式）；理科/计算机轨无勾选清单
5. 以 `\end{document}` 结尾（理科轨内容须包在 `multicols*` 内）
6. **普遍性检查**：逐条自检——若某条必须依赖具体题目上下文才能成立/理解（题干、题号、专有数字链、人名情境），则泛化重写；示例不得超过一行数字演示

### 阶段 5：编译与验证

```bash
# 仅使用 tectonic（产出全英文，无中文依赖）
tectonic {output_name}.tex
```

编译成功后删除中间文件（`.aux` `.bbl` `.blg` `.log` `.out` `.toc` `.synctex.gz` 等），只保留 `.tex` 与 `.pdf`：
```bash
rm -f {output_name}.aux {output_name}.bbl {output_name}.blg {output_name}.log {output_name}.out {output_name}.toc {output_name}.synctex.gz
```

验证清单（须全部通过）：
- [ ] LaTeX 编译无报错（tectonic）
- [ ] **全英文：产出物无任何中文**（标题、表头、内容、Tip/Rule、示例、代码注释——所有轨道统一）
- [ ] 易错点覆盖完整（无遗漏核心模块）
- [ ] 每条易错点都有错例+正例+说明（三要素）
- [ ] 表格对齐正确，未溢出页面（列宽合计 ≤ 可用宽；理科轨双栏每栏内容不超栏宽）
- [ ] **普遍性：无任何题干/题号照搬**——每条均为脱离原题也可成立的普遍规律，示例 ≤1 行数字演示
- [ ] 「正确」内容精确无误（有疑虑时查阅资料确认）
- [ ] 正例/规则逐条正确性核查：有疑虑的条目查阅资料确认，无法确认的标注"Verify"（建议核实）
- [ ] 中间文件已清理，只留 `.tex` 与 `.pdf`

**正确性核查**：清单中的「正确形式」「说明」属知识性内容，生成后须逐条过一遍（可委托 subagent：`momus`/`oracle`）；任何存疑条目不得凭记忆硬写，标注 "Verify" 或查资料确认。

---

## 示例输出结构（全英文，三轨）

### 文科示例：AP 英语修辞清单（`style=liberal_arts`）

```latex
\section*{Part I: Rhetorical Devices Checklist}
\addcontentsline{toc}{section}{Part I: Rhetorical Devices Checklist}

\subsection*{Appeals \& Emotional Devices}

\begin{center}
\footnotesize
\begin{tabular}{p{2.6cm}p{3.2cm}p{3.2cm}p{5.3cm}}
\toprule
\textbf{Device} & \textbf{Definition} & \textbf{Analysis Focus} & \textbf{Example} \\
\midrule
Anecdote & Brief personal story & Builds emotional connection & ``At age ten, I watched...'' \\
\bottomrule
\end{tabular}
\end{center}

\textbf{Tip:} Always link the evoked emotion to the author's \textbf{purpose}.
```

### 文科变体示例：德语语法错题表（`style=biology` 表格型）

```latex
\subsection*{Perfektbildung}

\begin{tabular}{p{0.3cm}p{2.6cm}p{2.6cm}p{8.8cm}}
\toprule
\textbf{\#} & \textbf{Wrong} & \textbf{Correct} & \textbf{Note} \\
\midrule
1 & hat erfolgte & ist passiert & Wrong auxiliary verb + wrong participle. \\
\bottomrule
\end{tabular}
```

### 理科示例：微积分公式速查（`style=science`，模仿 common_necessaties.tex）

```latex
\sect{5. Integration}

\subsect{Basic Formulas}
$\int \frac{1}{x} dx = \ln|x|$ \quad $\int e^x dx = e^x$ \quad $\int a^x dx = \frac{a^x}{\ln a}$ \quad $\int \frac{f'(x)}{f(x)}dx=\ln |f(x)|$

\subsect{Trigonometric Integrals}
$\int \tan x\, dx = \ln|\sec x|$ \quad $\int \cot x\, dx = \ln|\sin x|$
$\int \sec x\, dx = \ln|\sec x + \tan x|$ \quad $\int \csc x\, dx = \ln|\csc x - \cot x|$

\subsect{Riemann Sum Error Direction}
\begin{tabular}{lll}
& $f$ increasing & $f$ decreasing \\ \hline
$L_n$ (left) & \textbf{under}estimates & \textbf{over}estimates \\
$R_n$ (right) & \textbf{over}estimates & \textbf{under}estimates \\
\end{tabular}
\textit{Never mix the two rules}: monotonicity $\to$ $L_n/R_n$; concavity $\to$ $M_n/T_n$.
```

### 计算机示例：Java 易错点（`style=cs`，模仿 最终CSA易错点整理.tex 全英文化）

```latex
\section{Unit 2: Strings}

\subsection{substring}
\imp{Common mistake}: \texttt{String.substring(a, b)} takes $[a,\,b)$ --- the end index is exclusive!
\begin{itemize}[nosep]
  \item To include $b$: use \texttt{String.substring(a, b+1)}
  \item \texttt{String.substring(a)} takes everything from $a$ to the end
\end{itemize}

\subsection{String Comparison}
\texttt{string1 == string2} compares \imp{memory addresses}; use \texttt{string1.equals(string2)} / \texttt{compareTo} to compare contents.
\begin{lstlisting}
String s1 = "abc";
String s2 = "abc";
System.out.println(s1 == s2);        // false (addresses differ)
System.out.println(s1.equals(s2));   // true (contents equal)
\end{lstlisting}
```

---

## 文件命名

```
{Subject}_Error_Checklist.tex   → LaTeX 源码（英文文件名）
{Subject}_Error_Checklist.pdf   → 编译输出
```

示例：`AP_Lang_Error_Checklist.tex`、`AP_Physics_2_Error_Checklist.tex`、`German_Error_Checklist.tex`、`Biology_Error_Checklist.tex`

---

## 执行要点

### 必须做
- **先选轨道**：文科（英语/德语/生物/历史等）→ `style=liberal_arts`（或 `biology`），完全模仿 AP_Lang_Master_Checklist.tex 的前导码、表格、Tip/Rule、Quick Checklist；理科（数学/物理/化学/统计）→ `style=science`，模仿 common_necessaties.tex / physics_common.tex 的双栏公式流；计算机（编程/算法/数据结构）→ `style=cs`，模仿最终CSA易错点整理.tex（全英文化）
- **只提炼普遍性易错规律**：错题/试卷仅作素材来源，产出条目一律泛化为规则 + 记忆点（去题设、去专有数字、去人名情境），示例最多一行数字演示
- 文科轨按内容量选择密度级（10pt 单栏 / 9pt 紧凑），**紧凑优先**；内容量极大且以公式为主时改走理科轨
- 每条易错点都配 **错例 + 正例 + 说明**（三要素）
- 理科轨公式必须使用 LaTeX 命令（G 节），数学间距收紧（`\thinmuskip` 等），行内公式优先
- 产出物**全英文**：表头、内容、Tip、Rule、示例、**代码注释**一律英文，禁止任何中文（所有轨道统一；计算机轨原稿中英混合，生成时必须全部英文化并删除 fontspec/XeTeX 中文依赖）
- 编译**仅用 tectonic**；编译后**删除中间文件**，只留 `.tex` 与 `.pdf`
- 编译后检查 PDF 输出是否超页、表格/公式是否溢出（理科轨双栏尤其要查）
- 对「正确答案」有疑虑时，先查资料确认，不要硬写

### 禁止做
- 不要在产出物中出现任何中文（CJK 字符）
- 不要用 xelatex 或其他引擎编译（仅 tectonic）
- **不要混淆轨道**：文科轨不用 `\sect`/`multicols*` 公式流；理科轨不用 `\section*{Part}` + Tip/Rule + Quick Checklist；计算机轨不用 booktabs 概念表 / multicols 词库
- **禁止照搬具体错题**：不粘贴题目题干/选项、不保留题号、不保留专有数字链与人名情境；任何条目必须脱离原题可独立成立
- **不要混入中文**：不得因原稿含中文而保留中文（CS 模板原稿中英混合，生成时全英文化，不得照抄中文注释/描述）
- 不要用大标题/大段文字浪费空间
- 不要用 `\displaystyle` 或大字号公式（用 `$...$` 内联；独立公式 ≤5%）
- 不要出现空泛的易错点（如"注意计算"），必须具体
- 不要用 `\boxed`、`\colorbox` 等装饰性元素（`\err/\corr` 颜色标记除外）
- 不要超过表格宽度（用 `p{宽度}` 控制，确保不溢出）

### Git 安全
需遵守 [Git 安全网规范](../git_safety_net.md)（本 skill 产出 `.tex` 源文件，需要可回滚历史）：
1. 确认目标 `.tex` 文件不存在时才用 `write` 创建
2. 文件已存在时用 `edit` 追加/修改
3. 修改前 git 快照，修改后 git commit

### 知识边界
遵守 [知识边界规范](../knowledge_boundary.md)：
- 对公式、语法规则等没有十足把握时，通过查阅确认而非猜测硬写
- 知识浓度高（每页应承载该学科核心易错点的 80%+）
- 存疑条目标注 "Verify" 而非编造
