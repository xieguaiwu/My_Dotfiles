---
name: error-checklist-creator
version: 1.0.0
description: 按学科生成极简LaTeX易错点清单——从参考文档提取排版规范，按错误类型分类输出表格+规则总结
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
    description: 学科名称（如物理、AP英语、德语、AP化学等）
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
tools:
  - read
  - write
  - edit
  - bash
  - glob
  - grep
  - subagent
---

# 易错点清单生成器 (Error Checklist Creator)

## 任务目标

基于用户指定的学科和主题，生成**极简、省空间、吃重点**的 LaTeX 易错点清单。

文档排版必须遵循下方从三份参考文档中提取的**排版规范**（一套可直接执行的空间压缩规则 + 内容呈现格式），确保：
- 一页承载最大信息量
- 错误类型清晰分类
- 每条错误/要点都有「错例-正例-说明」三要素

---

## 排版规范（从参考文档提取）

> 来源: `physics_common.tex` (物理紧凑双栏)、`Rhetorical_Devices_Checklist.tex` (英语修辞表)、`German_Error_Checklist.tex` (德语错题分析)

### A. 页面与字号 —— 空间压缩基线

| 密度级 | 字号 | 边距 | 列间距 | 行距 | 数学间距 | 适用范围 |
|--------|------|------|--------|------|---------|---------|
| **普通** | 10pt | 0.5-0.55in | 默认 | `\setstretch{0.78}` | 默认 | 术语表/清单（英语修辞风格） |
| **紧凑** | **9pt** | **0.35-0.45in** | 默认 | `\setstretch{0.78}` | 默认 | **通用推荐，平衡密度与可读** |
| **极限** | **7-8pt** | **0.25-0.3in** | **4pt** | `\setstretch{0.78}` | `\thinmuskip=1mu` `\medmuskip=1mu minus 1mu` `\thickmuskip=2mu minus 2mu` | 公式速查/海量内容（数学/物理风格） |

纸张: **a4paper** 或 letterpaper 按场景选。分栏: 内容多时用 `multicols*` **双栏**。
段距: `\parskip=0pt` `\parindent=0pt`。页眉页脚: `\pagestyle{empty}`。
标题区: 顶部 `\vspace*{-2em}` 去掉多余空白。

### B. 章节结构 —— 极简标题

优先级从高到低选择：

**Option A: 自定义 \sect{标题}（紧凑，物理风格）**
```latex
\newcommand{\sect}[1]{\vspace{0.3em}\noindent\textbf{\small #1}\vspace{0.1em}\hrule\vspace{0.2em}}
\newcommand{\subsect}[1]{\noindent\textbf{#1}\\}
```

**Option B: titlesec 压缩（英语/德语风格）**
```latex
\usepackage{titlesec}
\titlespacing*{\section}{0pt}{0.6ex}{0.2ex}
\titleformat*{\section}{\normalsize\bfseries}
\titlespacing*{\subsection}{0pt}{0.2ex}{0.05ex}
\titleformat*{\subsection}{\small\bfseries}
```

**Option C: 极限紧凑 \sect{标题}（数学/高考速查风格，`common_necessaties.tex`）**
```latex
\newcommand{\sect}[1]{\vspace{0.05em}\noindent\textbf{\small #1}\hrule\vspace{0.05em}}
\newcommand{\subsect}[1]{\noindent\textbf{#1}\\[0.05em]}
```

**选用原则：**
- 清单有 5+ 个大分类 → 用 Option A 或 C（更省空间）
- 每个分类下有深层子类 → 用 Option B（结构更清晰）
- 混用：大类用 `\section*` 加 `\addcontentsline`，子类用手动 `\subsect`
- **极限密度（7-8pt）时必选 Option C**，配合 `0pt` 段距和 muskip 收紧

### C. 列表格式 —— 零冗余

```latex
\usepackage{enumitem}
\setlist[itemize]{leftmargin=*,nosep,itemsep=0pt,topsep=0pt,parsep=0pt}
\setlist[enumerate]{leftmargin=*,nosep,itemsep=0pt,topsep=0pt,parsep=0pt}
```

**极限密度时** `topsep=0pt`（与 `common_necessaties.tex` 一致）。

### D. 数据呈现 —— 三种核心表格

**D1. 错题分析表（德语风格，最常用）**

适用于：任何有「错误-正确」对比的场景。

```latex
\usepackage{booktabs,array}
\begin{tabular}{p{0.3cm}p{3cm}p{3cm}p{7cm}}
\toprule
\textbf{\#} & \textbf{错误形式} & \textbf{正确形式} & \textbf{错误类型与说明} \\
\midrule
1 & 错误写法/用法 & 正确写法/用法 & 错误类别。简短解释为什么错。 \\
\bottomrule
\end{tabular}
```

**D2. 概念速查表（英语修辞风格）**

适用于：需要记录定义、要点、例子的知识清单。

```latex
\begin{tabular}{p{2.5cm}p{3.5cm}p{3.5cm}p{5cm}}
\toprule
\textbf{概念} & \textbf{定义} & \textbf{分析要点} & \textbf{示例} \\
\midrule
术语 & 定义 & 如何分析/使用 & 具体例子 \\
\bottomrule
\end{tabular}
```

**D3. 公式/数据对比表（物理风格）**

适用于：公式、常数、对比值。

```latex
\begin{tabular}{lll}
变量 & 公式 & 说明 \\
\midrule
$a$ & $F=ma$ & 牛顿第二定律 \\
\end{tabular}
```

### E. 整体页面模板（极简风格）

**默认（紧凑）：**
```latex
\documentclass[9pt,a4paper]{article}
\usepackage[margin=0.4in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{booktabs,array}
\usepackage{multicol}
\usepackage{enumitem}
\usepackage{setspace}
\usepackage{titlesec}
\usepackage{xcolor}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}

% === 空间压缩 ===
\setstretch{0.78}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}
\setlength{\columnsep}{4pt}
\setlist[itemize]{leftmargin=*,nosep,topsep=0pt,parsep=0pt}
\setlist[enumerate]{leftmargin=*,nosep,topsep=0pt,parsep=0pt}

% === 极简标题 ===
\newcommand{\sect}[1]{\vspace{0.3em}\noindent\textbf{\small #1}\vspace{0.1em}\hrule\vspace{0.2em}}
\newcommand{\subsect}[1]{\noindent\textbf{#1}\\}

\begin{document}
\vspace*{-2.5em}
\begin{center}
{\large\textbf{[学科] — [标题]}}
\end{center}
\vspace{-0.5em}

\begin{multicols*}{2}
% 内容...
\end{multicols*}
\end{document}
```

**极限密度（数学/物理速查风格，`common_necessaties.tex`）：**
```latex
\documentclass[7pt,letterpaper]{article}
\usepackage[margin=0.3in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{multicol}
\usepackage{enumitem}
\usepackage{setspace}
\usepackage{xcolor}

% === 空间压缩 ===
\setstretch{0.78}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}
\setlength{\columnsep}{4pt}
\setlist[itemize]{leftmargin=*,nosep,topsep=0pt,parsep=0pt}
\setlist[enumerate]{leftmargin=*,nosep,topsep=0pt,parsep=0pt}

% === 数学间距收紧（来自 common_necessaties.tex） ===
\thinmuskip=1mu
\medmuskip=1mu minus 1mu
\thickmuskip=2mu minus 2mu

% === 极简标题（0.05em 间距） ===
\newcommand{\sect}[1]{\vspace{0.05em}\noindent\textbf{\small #1}\hrule\vspace{0.05em}}
\newcommand{\subsect}[1]{\noindent\textbf{#1}\\[0.05em]}

\begin{document}
\vspace*{-2.5em}
\begin{center}
{\large\textbf{[学科] — [标题]}}
\end{center}
\vspace{-0.5em}

\begin{multicols*}{2}
% 内容...
\end{multicols*}
\end{document}
```

### F. 内容组织规范

```
第1层: 大分类（按错误类型/知识模块）
  ↓ \sect{分类标题} 或 \section*
第2层: 细分（可选，仅当需要子分类）
  ↓ \subsect{子标题} 或 \subsection*
内层: 表格/列表/公式行
  ↓ tabular / itemize / 内联inline
```

**分类原则（从参考文档总结）：**
- 物理：按力学章节（运动学/牛顿定律/功与能/动量/转动/SHM/流体）
- 英语修辞：按功能分群（诉求/逻辑/人格/句法/修辞格/风格）
- 德语：按语法类别（完成时/语义/变格/情态/介词/拼写）

### G. 公式与符号排版规范（从 Obsidian 笔记规范提取）

本节规则适用于清单中所有数学公式、物理公式、逻辑符号以及任何需要 LaTeX 排版的符号表达式。

#### G1. 绝对禁止：Unicode/ASCII 替代 LaTeX 符号

这是最常见也最隐蔽的错误。所有数学符号**必须用 LaTeX 命令**，禁止使用外观相似的 Unicode 字符或 ASCII 替代写法。

| 场景 | ✅ LaTeX 命令（正确） | ❌ Unicode/ASCII（禁止） |
|------|----------------------|------------------------|
| 蕴涵/箭头 | `\to` `\rightarrow` `\Rightarrow` | → ⇒ `=>` |
| 全称量词 | `\forall` | ∀ |
| 存在量词 | `\exists` | ∃ |
| 属于 | `\in` | ∈ |
| 否定/非 | `\neg` 或 `\lnot` | ¬ |
| 合取 | `\land` 或 `\wedge` | ∧ |
| 析取 | `\lor` 或 `\vee` | ∨ |
| 方框（模态必然） | `\Box` | □ `[]` |
| 菱形（模态可能） | `\Diamond` | ◇ `<>` |
| 语义后承 | `\models` | ⊨ `|=` |
| 语法后承 | `\vdash` | ⊢ `\`\`-\` |
| 大于等于 | `\ge` 或 `\geq` | ≥ |
| 小于等于 | `\le` 或 `\leq` | ≤ |
| 不等号 | `\neq` 或 `\ne` | ≠ |
| 约等于 | `\approx` | ≈ |
| 正比于 | `\propto` | ∝ |
| 无穷 | `\infty` | ∞ |
| 偏导 | `\partial` | ∂ |
| 纳布拉/梯度 | `\nabla` | ∇ |
| 拉普拉斯 | `\Delta` 或 `\triangle` | Δ（注意与三角形区别） |
| 点乘 | `\cdot` | · |
| 叉乘 | `\times` | × |
| 圆圈（角标用） | `\circ` | ° |
| 根号 | `\sqrt{}` | √（Unicode 根号缺上横线） |
| 积分 | `\int` | ∫ |
| 求和 | `\sum` | ∑ |
| 圆周率 | `\pi` | π |
| theta | `\theta` `\Theta` | θ Θ |
| mu（微/摩擦系数） | `\mu` | μ |
| omega | `\omega` `\Omega` | ω Ω |
| alpha | `\alpha` | α |
| beta | `\beta` | β |
| delta | `\delta` `\Delta` | δ Δ |
| 空集 | `\emptyset` 或 `\varnothing` | ∅ |
| 子集 | `\subset` `\subseteq` | ⊂ ⊆ |
| 并集 | `\cup` | ∪ |
| 交集 | `\cap` | ∩ |

**规则：如果不确定某个符号的 LaTeX 命令，查证后再写，绝不直接粘贴 Unicode 符号。**

#### G2. 数学字体规范

| 用途 | LaTeX 命令 | 示例 | 说明 |
|------|-----------|------|------|
| 多字母变量/函数 | `\mathrm{}` | `$\mathrm{KE}$` `$\sin$` `$\log$` | 多字母缩写用正体 |
| 物理单位 | `\mathrm{}` | `$\mathrm{m/s}$` `$\mathrm{N\cdot m}$` | 单位始终正体 |
| 变量 | 默认斜体 | `$m$` `$v$` `$t$` `$\theta$` | 单字母变量用斜体（LaTeX 默认） |
| 矢量 | `\vec{}` 或 `\mathbf{}` | `$\vec{F}$` `$\mathbf{v}$` | 推荐 `\vec` 简洁 |
| 矩阵/张量 | `\mathbf{}` | `$\mathbf{I}$` | 矩阵用粗体 |
| 集合 | `\mathcal{}` | `$\mathcal{A}$` | 集合用花体 |

**物理单位和变量区分**（易错清单常见错误）：
- 变量用斜体：$m$（质量）、$v$（速度）、$t$（时间）
- 单位用正体：$\mathrm{kg}$、$\mathrm{m/s}$、$\mathrm{N}$
- 错误示范（混用）：$m = 5 kg$ ✗ → 应为 $m = 5\,\mathrm{kg}$ ✓
- 数字与单位间加小空格：`$5\,\mathrm{kg}$` 中的 `\,`

#### G3. 公式排版上下文选择

| 位置 | 语法 | 适用场景 |
|------|------|---------|
| 行内 | `$...$` | **默认首选**。易错清单中 95% 的公式应行内 |
| 行内加大 | `$\displaystyle...$` | 需要清晰显示分式、积分、求和时 |
| 独立展示 | `\[...\]` 或 `$$...$$` | 仅用于**必须**独占一行的核心公式（易错清单中≤5%） |

**易错清单排版原则**：
- 表格中的公式一律用 `$...$` 行内（不乱版面）
- 分子分母复杂的分数用 `\dfrac` 加 `\displaystyle` 确保可读
- 即使 `$...$` 内也可用 `\tfrac`（小分式）节省空间
- 避免 `\displaystyle` 滥用——只在需要清晰分辨上标/下标时使用

#### G4. 公式书写规范

**括号：**
- 始终用 `\left(` 和 `\right)` 自动匹配大小（但易错清单中简单括号直接用 `(` `)` 即可，节省编译量）
- 花括号在 LaTeX 中是特殊字符，须转义：`\{` `\}`
- 绝对值：`\lvert x \rvert` 或 `|x|`

**上下标：**
- 多字符下标**必须用花括号**：`$v_{0}$`（正确）✓，`$v_0$`（可能歧义）△
- 多字符上标同样：`$e^{2x}$`（正确）✓，`$e^2x$`（表示 $e^2 \cdot x$）✗

**分式：**
- 行内推荐 `\frac{}{}`，若分子分母简单也可用 `\tfrac{}{}` 进一步压缩
- 表格中遇复杂分式：用 `$\displaystyle\frac{}{}$` 或改为 `$a/b$` 斜杠形式

**省略号：**
- `\dots` 或 `\ldots`（底部点），`\cdots`（居中点，用于运算符之间）
- 禁止三个句点 `...` 替代

#### G5. 化学与学科特定符号

**化学方程（如果清单涉及）：**
- 用 `\mathrm` 或 `\ce{}`（需加载 `mhchem` 包）：`$\mathrm{H_2O}$`、`$\ce{CO2}$`
- 箭头：`\rightarrow`（反应正向）、`\leftrightarrow`（可逆）
- 沉淀/气体符号：`$\downarrow$` `$\uparrow$`
- 不推荐用 Unicode 化学箭头

**德语/语言学（如果清单涉及）：**
- IPA 符号用 `\ipa{}`（需加载 `tipa` 包）或直接 Unicode
- 特殊字符 ä ö ü ß 直接输入（UTF-8 编码即可，无需 `\"a` 等过时写法）

#### G6. 公式检查要点

生成后逐条检查：
- [ ] 所有 `→` `⇒` `∀` `∃` `∈` `¬` 等 Unicode 符号已替换为 `\to` `\Rightarrow` `\forall` `\exists` `\in` `\neg`
- [ ] 物理单位用 `\mathrm{}` 正体（如 `\mathrm{kg}`），不是斜体
- [ ] 数字与单位间有 `\,` 小空格（`$5\,\mathrm{kg}$`）
- [ ] 多字符下标用 `{...}` 包裹（`$v_{0}$` 不是 `$v_0$`）
- [ ] 数学函数名用正体（`$\sin$` `$\log$` `$\cos$`，不是 `$sin$` `$log$`）
- [ ] 独立行间公式 `$$...$$` 数量≤内容的 5%（多数用 `$...$` 行内）

**记忆口诀**：
> 正体单位斜体量，花括号裹上下标；
> Unicode 绝不碰，\to 才是真蕴涵。

---

## 执行流程

### 阶段 1：理解需求与学科分析

1. 读取用户指定的 `{subject}` 和 `{topics}`
2. 如果 `{topics}` 为 "all"，自动分解为该学科的核心模块：
   - **物理**: 运动学、牛顿定律、能量、动量、转动、简谐运动、流体
   - **AP英语/语文**: 修辞手法、论证技巧、语法、文体
   - **德语**: 动词、变格、介词、句法、拼写
   - **数学**: 代数、微积分、几何、概率
   - **化学/生物**: 按教材章节分解
3. 按分类识别该学科/主题下的**高频易错点**（需结合学科知识，给出具体、不空泛的易错点）

### 阶段 2：内容组织

对每个易错点，必须按「三要素」呈现：

```
┌──────────┬─────────────────────────────────┐
│  要素     │  要求                          │
├──────────┼─────────────────────────────────┤
│  ❌ 错例  │ 真实、具体的错误写法/用法       │
│  ✅ 正例  │ 对应的正确写法/用法             │
│  💡 说明  │ 简短解释错误原因 + 记忆技巧      │
└──────────┴─────────────────────────────────┘
```

**物理风格**（公式型）可省略"错例"，改用：
```
公式 + 常见陷阱/注意点
```

**英语修辞风格**（清单型）保持：
```
概念 | 定义 | 分析要点 | 示例
```

### 阶段 3：选择排版轨道

根据内容类型选择最佳排版：

| 学科内容类型 | 推荐排版 | 模板参考 |
|-------------|---------|---------|
| 错误分析型（德语/语法/写作） | 错题分析表 D1 + 规则说明 | German_Error_Checklist |
| 概念清单型（英语修辞/术语） | 概念速查表 D2 + 使用技巧 | Rhetorical_Devices_Checklist |
| 公式速查型（物理/数学/化学） | 极限密度 7pt + 双栏 + 公式对比 D3 | common_necessaties.tex |
| 混合型 | 可混用 D1/D2/D3，用 `\sect` 分区 | 综合 |

### 阶段 4：LaTeX 文档生成

1. 按内容类型选择密度级（普通/紧凑/极限），组装对应的 LaTeX 前导码（参考 A-E 节）
2. 逐分类输出内容
3. 以 `\end{document}` 结尾

### 阶段 5：编译与验证

```bash
# 优先使用 tectonic
tectonic {output_name}.tex

# 若tectonic不支持中文或特殊包，回退 xelatex:
xelatex {output_name}.tex
```

验证清单（须全部通过）：
- [ ] LaTeX 编译无报错
- [ ] 易错点覆盖完整（无遗漏核心模块）
- [ ] 每条易错点都有错例+正例+说明（三要素）
- [ ] 表格对齐正确，未溢出页面
- [ ] 「正确」内容精确无误（有疑虑时查阅资料确认）

---

## 示例输出结构

### 物理易错点清单（节选）

```latex
\sect{1. 运动学常见错误}

\begin{tabular}{p{0.3cm}p{3cm}p{3cm}p{7.2cm}}
\toprule
\textbf{\#} & \textbf{❌ 错误} & \textbf{✅ 正确} & \textbf{💡 说明} \\
\midrule
1 & $v^2 = v_0^2 + 2ax$ 中 $x$ 代位移 & 代\textbf{位置变化量} $\Delta x$ & 公式中的 $x$ 实为 $(x-x_0)$，不是最终位置 \\
2 & 自由落体 $v=gt$ 忘初速度 & $v = v_0 + gt$ & 只有当 $v_0=0$ 时才成立！ \\
\bottomrule
\end{tabular}
```

### 德语语法易错点清单（节选）

```latex
\sect{1. Perfektbildung}

\begin{tabular}{p{0.3cm}p{3cm}p{3cm}p{7.2cm}}
\toprule
\textbf{\#} & \textbf{Falsch} & \textbf{Richtig} & \textbf{Fehlertyp \& Erklärung} \\
\midrule
1 & hat erfolgte & ist passiert & Falsches Hilfsverb + falsche Verbform. \\
\bottomrule
\end{tabular}
```

### AP英语修辞清单（节选）

```latex
\sect{1. Appeals \& Emotional Devices}

\begin{tabular}{p{2.5cm}p{3.5cm}p{3.5cm}p{4.5cm}}
\toprule
\textbf{Device} & \textbf{Definition} & \textbf{Analysis Focus} & \textbf{Example} \\
\midrule
Anecdote & Brief personal story & Builds emotional connection & ``At age ten, I watched...'' \\
\bottomrule
\end{tabular}
```

---

## 文件命名

```
{Subject}_Error_Checklist.tex   → LaTeX 源码
{Subject}_Error_Checklist.pdf   → 编译输出
```

示例：`AP_Physics_1_Error_Checklist.tex`、`German_Error_Checklist.tex`、`AP_Lang_Rhetorical_Checklist.tex`

---

## 执行要点

### 必须做
- 按内容量选择密度级（普通10pt / 紧凑9pt / 极限7pt），**极限密度优先**（这是核心差异化价值）
- 每条易错点都配 **错例 + 正例 + 说明**（三要素）
- 编译后检查 PDF 输出是否超页、表格是否溢出
- 对「正确答案」有疑虑时，先查资料确认，不要硬写

### 禁止做
- 不要用大标题/大段文字浪费空间
- 不要用 `\displaystyle` 或大字号公式（用 `$...$` 内联）
- 不要出现空泛的易错点（如"注意计算"），必须具体
- 不要用 `\boxed`、`\colorbox` 等装饰性元素
- 不要超过表格宽度（用 `p{宽度}` 控制，确保不溢出）

### Git 安全
需遵守 [Git 安全网规范](../git_safety_net.md)：
1. 确认目标 `.tex` 文件不存在时才用 `write` 创建
2. 文件已存在时用 `edit` 追加/修改
3. 修改前 git 快照，修改后 git commit

### 知识边界
遵守 [知识边界规范](../knowledge_boundary.md)：
- 对公式、语法规则等没有十足把握时，通过查阅确认而非猜测硬写
- 知识浓度高（每页应承载该学科核心易错点的 80%+）
