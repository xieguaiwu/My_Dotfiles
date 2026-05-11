---
name: ap-calculus-bc-exam-generation
version: 1.0.0
description: 生成AP Calculus BC完整模拟试卷(LaTeX格式)
triggers:
  - "AP Calculus BC 试卷"
  - "生成AP试卷"
  - "AP mock exam"
inputs:
  - name: output
    description: 输出.tex文件路径
    required: false
    default: AP_Calculus_BC_Mock_Exam.tex
tools:
  - write
  - bash
---

# AP Calculus BC 模拟试卷生成

## 核心
```
你是一位资深的 AP Calculus BC 考试出题专家。请生成一份完整的 AP Calculus BC 模拟试卷，输出为 LaTeX 源码。

## 试卷结构

### Section I: Multiple-Choice Questions (选择题，共 45 题)

**Part A: 30 题，60 分钟，无计算器**
- 题号 1-30
- 涵盖主题：
  - 极限与连续性 (约 3-4 题)
  - 导数定义与求导法则 (约 6-7 题)
  - 导数应用：相关速率、曲线分析、最值 (约 6-7 题)
  - 积分基础与定积分 (约 5-6 题)
  - 积分技巧 (约 2-3 题)
  - 微分方程 (约 2-3 题)
  - 参数方程 (约 2 题) [BC 专属]
  - 极坐标 (约 2 题) [BC 专属]
  - 无穷级数 (约 5-6 题) [BC 专属]

**Part B: 15 题，45 分钟，需要图形计算器**
- 题号 31-45
- 涵盖主题：
  - 数值积分与近似 (约 2 题)
  - 导数计算与应用 (约 2 题)
  - 面积与体积 (约 2 题)
  - 微分方程与欧拉法 (约 2 题)
  - 向量函数 (约 2 题) [BC 专属]
  - 参数方程与极坐标应用 (约 2 题) [BC 专属]
  - 级数与泰勒多项式 (约 3 题) [BC 专属]

### Section II: Free-Response Questions (简答题，共 6 题)

**Part A: 2 题，30 分钟，需要计算器**
- 题目通常涉及：面积、体积、微分方程

**Part B: 4 题，60 分钟，无计算器**
- 题目通常涉及：泰勒级数、函数分析、参数/极坐标、级数收敛

### Answer Key (答案)

- 选择题答案表
- 简答题详细解答步骤

### Knowledge Points Covered (知识点覆盖)

- 列出试卷涵盖的知识点及对应题号

---

## LaTeX 格式规范

### 文档头部

```latex
\documentclass[10pt,letterpaper]{article}
\usepackage[margin=0.35in]{geometry}
\usepackage{amsmath,amssymb,amsfonts}
\usepackage{graphicx}
\usepackage{enumitem}
\usepackage{multicol}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,calc,positioning}

\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}

\newcommand{\question}[1]{\textbf{#1}}
\newcommand{\mcitem}[1]{\item[\textbf{#1}]}

\begin{document}
```

### 标题格式

```latex
\begin{center}
{\Large\bfseries AP Calculus BC Mock Examination}\\[0.5em]
{\large Practice Test}\\[1em]
\end{center}
```

### 选择题格式

```latex
% Qn: [Topic]
\item [题目内容]
\begin{enumerate}[label=(\Alph*)]
    \item 选项 A
    \item 选项 B
    \item 选项 C
    \item 选项 D
    \item 选项 E
\end{enumerate}
```

**重要格式要求：**
- 每个选择题必须有 **5 个选项 (A-E)**
- 使用 `\displaystyle` 使分数、极限等公式更清晰
- 复杂表达式使用 `\dfrac` 而非 `\frac`
- 分段函数使用 `cases` 环境

### 简答题格式

```latex
\noindent\textbf{Question n}\\[0.5em]

[题目背景描述]

\begin{enumerate}[label=\alph*.]
    \item 第一小题
    \item 第二小题
    \item 第三小题
    \item 第四小题
\end{enumerate}
```

### 数学公式规范

| 类型 | 正确写法 |
|------|----------|
| 极限 | `$\displaystyle\lim_{x\to a}$` |
| 积分 | `$\displaystyle\int_a^b f(x)\, dx$` |
| 分数 | `$\dfrac{a}{b}$` |
| 求和 | `$\displaystyle\sum_{n=1}^{\infty}$` |
| 导数 | `$\dfrac{dy}{dx}$` 或 `$f'(x)$` |
| 向量 | `$\mathbf{v}(t) = \langle x, y \rangle$` |
| 单位 | `cm$^3$/s` (单位用正体) |

### 答案表格式

```latex
\begin{tabular}{|c|c||c|c||c|c|}
\hline
\# & Answer & \# & Answer & \# & Answer \\
\hline
1  & C & 16 & A & 31 & D \\
2  & E & 17 & B & 32 & B \\
\hline
\end{tabular}
```

---

## 题目设计要求
### 通用原则

1. **难度分布**：简单 (30%) / 中等 (50%) / 困难 (20%)
2. **答案设计**：
   - 正确答案随机分布 (A-E 均衡)
   - 每个干扰项必须基于具体的常见错误设计，需明确标注错误来源
   - 每个干扰项必须具有合理的迷惑性（学生可能因特定误解而选择），不可随意编造明显错误
   - 避免"以上皆非"类选项
   - 所有错误选项需要有清晰的设计依据，确保选项区分具有足够难度
3. **数值题**：
   - 答案应为简洁的数值或表达式
   - 避免过度复杂的计算
4. **概念题**：
   - 题目表述清晰无歧义
   - 测试核心概念而非记忆

### BC 专属主题
必须在试卷中出现的 BC 专属内容：

| 主题 | 最少题数 |
|------|----------|
| 参数方程 (求导、弧长、速度) | 3-4 题 |
| 极坐标 (转换、面积) | 2-3 题 |
| 级数收敛判定 (比值、根值、比较判别法) | 3-4 题 |
| 泰勒/麦克劳林级数 | 3-4 题 |
| 拉格朗日误差界 | 1-2 题 |
| 积分技巧 (分部积分、部分分式) | 2-3 题 |

### 几何公式提示
以下几何公式 **不提供** 在 AP 公式表中，如题目需要应在题目中给出：

- 球体体积：$V = \dfrac{4}{3}\pi r^3$
- 球体表面积：$S = 4\pi r^2$
- 圆锥体积：$V = \dfrac{1}{3}\pi r^2 h$

**示例：**
```latex
\item A spherical balloon is being inflated at a rate of $10$ cm$^3$/s. 
How fast is the radius increasing when the radius is $5$ cm? \\[0.3em]
\textit{(Volume of a sphere: $V = \dfrac{4}{3}\pi r^3$)}
```

---

## 答案验证要求
### 选择题验证

**必须对每道选择题进行计算验证，确认：**

1. 正确答案确实正确
2. 干扰项有明确的错误原因

**验证模板：**
```
题目 X: 计算 [表达式]
步骤 1: ...
步骤 2: ...
结果: [答案]
验证: 正确答案为 (X)
```

### 简答题验证

**每道简答题必须提供：**

1. 完整的解题步骤
2. 最终答案
3. 关键中间结果

**示例：**
```
Question 1:
(a) Area = ∫₀¹ √x dx + ∫₁² (2-x) dx
    = [2x^(3/2)/3]₀¹ + [2x - x²/2]₁²
    = 2/3 + 1/2 = 7/6

(b) Volume = π∫₀¹ x dx + π∫₁² (2-x)² dx
    = π[x²/2]₀¹ + π[(2-x)³/(-3)]₁²
    = π/2 + π/3 = 5π/6
```

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic AP_Calculus_BC_Mock_Exam.tex
```

编译输出：
- PDF 文件
- 可能的 warning (Underfull \hbox 等排版警告可忽略)

---

## 输出检查清单

生成试卷后，请确认：

- [ ] Section I Part A: 30 道选择题 (无计算器)
- [ ] Section I Part B: 15 道选择题 (需计算器)
- [ ] Section II Part A: 2 道简答题 (需计算器)
- [ ] Section II Part B: 4 道简答题 (无计算器)
- [ ] 所有选择题有 5 个选项 (A-E)
- [ ] 答案表完整
- [ ] 答案表全部正确
- [ ] 选择题答案没有可预测的明显规律
- [ ] 简答题有详细解答
- [ ] BC 专属主题覆盖完整
- [ ] LaTeX 语法正确，可编译
- [ ] 使用 tectonic 编译成功

---

## 示例题目
### 选择题示例

```latex
% Q1: Limits
\item $\displaystyle\lim_{x\to 3}\frac{x^2-9}{x-3}=$
\begin{enumerate}[label=(\Alph*)]
    \item 0
    \item 3
    \item 6
    \item 9
    \item Does not exist
\end{enumerate}
```
**验证：** $\lim_{x\to 3}\frac{(x-3)(x+3)}{x-3} = \lim_{x\to 3}(x+3) = 6$，答案 C

### 简答题示例

```latex
\noindent\textbf{Question 1}\\[0.5em]

Let $R$ be the region bounded by the graphs of $y = \sqrt{x}$, $y = 2 - x$, and the $x$-axis.

\begin{enumerate}[label=\alph*.]
    \item Find the area of region $R$.
    \item Find the volume of the solid generated when $R$ is revolved about the $x$-axis.
    \item Write, but do not evaluate, an integral expression for the volume of the solid generated when $R$ is revolved about the line $y = 3$.
    \item Find the volume of the solid whose base is $R$ and whose cross-sections perpendicular to the $x$-axis are squares.
\end{enumerate}
```

---

## 注意事项

1. **避免重复**：同一套试卷中不应有相似题目
2. **数值合理**：答案数值应合理，避免过于复杂
3. **符号一致**：全文使用一致的数学符号
4. **题号连续**：确保题号从 1 连续排列
5. **选项格式**：所有选择题选项使用 `(A)`, `(B)`, `(C)`, `(D)`, `(E)` 格式
6. **选项难度与干扰项设计（重要）**：
   - **每个错误选项必须有其明确意义**：说明该选项对应哪种常见错误（如：符号错误、公式混淆、概念误解、计算跳步等）
   - **每个错误选项必须有其存在的合理可能性**：解释为什么学生可能会选择该错误选项（即该选项的"迷惑性"来源），确保不是明显可排除的选项
   - **难度保障**：正确选项与错误选项的区分应具有足够难度，不能仅凭外观（如数值接近程度）判断；至少有一个干扰项需要在深入理解后才能排除
   - **设计原则**：错误选项应基于真实的学生易错点设计，而非随意编造
7. **答案分布**：避免答案过于规律
