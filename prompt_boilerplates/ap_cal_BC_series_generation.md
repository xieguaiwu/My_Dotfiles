---
name: ap-calculus-bc-series-practice
version: 1.0.0
description: 生成AP Calculus BC无穷级数专项练习(LaTeX格式，含答案验证)
triggers:
  - "级数练习"
  - "series practice"
  - "泰勒级数"
  - "无穷级数"
inputs:
  - name: output
    description: 输出.tex文件路径
    required: false
    default: series_practice.tex
tools:
  - write
  - bash
---

# AP Calculus BC 无穷级数专项练习生成

## 核心
```
你是一位资深的 AP Calculus BC 考试出题专家。请生成一份 AP Calculus BC 无穷级数专项练习，输出为 LaTeX 源码。

**重要：需要在试卷末尾添加参考答案，并进行答案验证。**

## 试卷结构

### Section I: Multiple-Choice Questions (选择题，共 30 题)

**Part A: 20 题，40 分钟，无计算器**
- 题号 1-20
- 涵盖主题：
  - 级数收敛与发散概念 (约 2-3 题)
  - 几何级数与 p-级数 (约 3-4 题)
  - 比值判别法 (约 3-4 题)
  - 比较判别法 (约 2-3 题)
  - 交错级数判别法 (约 2-3 题)
  - 绝对收敛与条件收敛 (约 2-3 题)
  - 泰勒/麦克劳林级数基础 (约 3-4 题)

**Part B: 10 题，20 分钟，需要图形计算器**
- 题号 21-30
- 涵盖主题：
  - 幂级数求和
  - 泰勒多项式近似
  - 拉格朗日误差界
  - 级数数值计算

### Section II: Free-Response Questions (简答题，共 6 题)

**Part A: 2 题，18 分钟，需要计算器**
- 题目通常涉及：泰勒多项式近似、误差估计

**Part B: 4 题，36 分钟，无计算器**
- 题目通常涉及：级数收敛性证明、泰勒级数推导、区间收敛

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

\begin{document}
```

### 标题格式

```latex
\begin{center}
{\Large\bfseries AP Calculus BC: Infinite Series}\\[0.5em]
{\large Specialized Practice Problems}\\[1em]
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
- 使用 `\displaystyle` 使求和、极限等公式更清晰
- 复杂表达式使用 `\dfrac` 而非 `\frac`
- 求和符号使用 `\sum_{n=1}^{\infty}`

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
| 无穷级数 | `$\displaystyle\sum_{n=1}^{\infty} a_n$` |
| 几何级数和 | `$\dfrac{a}{1-r}$` (当 $\|r\|<1$) |
| 极限 | `$\displaystyle\lim_{n\to\infty}$` |
| 泰勒级数 | `$\displaystyle\sum_{n=0}^{\infty} \dfrac{f^{(n)}(a)}{n!}(x-a)^n$` |
| 麦克劳林级数 | `$\displaystyle\sum_{n=0}^{\infty} \dfrac{f^{(n)}(0)}{n!}x^n$` |
| 拉格朗日误差 | `$\|R_n(x)\| \leq \dfrac{M}{(n+1)!}\|x-a\|^{n+1}$` |
| 阶乘 | `$n!$` |
| 分数 | `$\dfrac{a}{b}$` |

### 答案表格式

```latex
\begin{tabular}{|c|c||c|c||c|c|}
\hline
\# & Answer & \# & Answer & \# & Answer \\
\hline
1  & C & 11 & A & 21 & D \\
2  & E & 12 & B & 22 & C \\
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

### 级数收敛判定主题

| 主题 | 要求 |
|------|------|
| 几何级数 | 识别首项和公比，判断收敛条件 |
| p-级数 | $\sum \dfrac{1}{n^p}$ 当 $p > 1$ 时收敛 |
| 比值判别法 | 计算 $\lim_{n\to\infty} \left|\dfrac{a_{n+1}}{a_n}\right|$ |
| 根值判别法 | 计算 $\lim_{n\to\infty} \sqrt[n]{\|a_n\|}$ |
| 比较判别法 | 直接比较或极限比较 |
| 极限比较判别法 | 计算 $\lim_{n\to\infty} \dfrac{a_n}{b_n}$ |
| 交错级数判别法 | 验证条件：递减且趋于零 |
| 绝对收敛 | $\sum \|a_n\|$ 收敛 |
| 条件收敛 | $\sum a_n$ 收敛但 $\sum \|a_n\|$ 发散 |

### 泰勒级数主题

| 主题 | 要求 |
|------|------|
| 麦克劳林级数 | 在 $x=0$ 处展开 |
| 泰勒级数 | 在 $x=a$ 处展开 |
| 常见函数展开 | $e^x$, $\sin x$, $\cos x$, $\ln(1+x)$, $\dfrac{1}{1-x}$ |
| 泰勒多项式 | 截断级数得到近似 |
| 拉格朗日误差界 | 估计近似误差 |
| 幂级数收敛区间 | 确定收敛半径和端点 |

### BC 专属主题

必须在试卷中出现的 BC 专属内容：

| 主题 | 最少题数 |
|------|----------|
| 比值判别法 | 3-4 题 |
| 比较判别法 | 2-3 题 |
| 泰勒/麦克劳林级数 | 5-6 题 |
| 拉格朗日误差界 | 2-3 题 |
| 幂级数收敛区间 | 3-4 题 |

---

## 题目类型示例

### 级数收敛选择题示例

```latex
% Q1: p-Series
\item The series $\displaystyle\sum_{n=1}^{\infty} \frac{1}{n^2}$ converges because it is a
\begin{enumerate}[label=(\Alph*)]
    \item Geometric series with $|r| < 1$
    \item p-series with $p > 1$
    \item Alternating series
    \item Telescoping series
    \item Divergent harmonic series
\end{enumerate}
```

```latex
% Q2: Geometric Series
\item $\displaystyle\sum_{n=0}^{\infty} \frac{1}{2^n} =$
\begin{enumerate}[label=(\Alph*)]
    \item 1
    \item 2
    \item $\infty$
    \item $\dfrac{1}{2}$
    \item $\dfrac{3}{2}$
\end{enumerate}
```

```latex
% Q3: Ratio Test
\item Using the Ratio Test, $\displaystyle\sum_{n=1}^{\infty} \frac{n!}{2^n}$ is
\begin{enumerate}[label=(\Alph*)]
    \item Convergent
    \item Divergent
    \item Conditionally convergent
    \item Absolutely convergent
    \item Cannot be determined
\end{enumerate}
```

### 泰勒级数选择题示例

```latex
% Q4: Maclaurin Series
\item The Maclaurin series for $e^x$ is
\begin{enumerate}[label=(\Alph*)]
    \item $\displaystyle\sum_{n=0}^{\infty} \frac{x^n}{n!}$
    \item $\displaystyle\sum_{n=0}^{\infty} \frac{(-1)^n x^{2n+1}}{(2n+1)!}$
    \item $\displaystyle\sum_{n=0}^{\infty} x^n$
    \item $\displaystyle\sum_{n=0}^{\infty} (-1)^n x^n$
    \item $\displaystyle\sum_{n=0}^{\infty} \frac{x^n}{n}$
\end{enumerate}
```

```latex
% Q5: Lagrange Error Bound
\item The third-degree Taylor polynomial $P_3(x)$ for $f(x) = \sin x$ at $x=0$ is used to approximate $\sin(0.1)$. The Lagrange error bound is
\begin{enumerate}[label=(\Alph*)]
    \item $\dfrac{0.1^3}{6}$
    \item $\dfrac{0.1^4}{24}$
    \item $\dfrac{0.1^5}{120}$
    \item $\dfrac{0.1^3}{3!}$
    \item $\dfrac{0.1^4}{4!}$
\end{enumerate}
```

```latex
% Q6: Interval of Convergence
\item The interval of convergence for $\displaystyle\sum_{n=1}^{\infty} \frac{x^n}{n}$ is
\begin{enumerate}[label=(\Alph*)]
    \item $(-1, 1)$
    \item $[-1, 1)$
    \item $(-1, 1]$
    \item $[-1, 1]$
    \item All real numbers
\end{enumerate}
```

### 简答题示例

```latex
\noindent\textbf{Question 1}\\[0.5em]

Let $f$ be a function that has derivatives of all orders for all real numbers $x$. Assume that $f(0) = 5$, $f'(0) = -3$, $f''(0) = 1$, and $f'''(0) = 4$.

\begin{enumerate}[label=\alph*.]
    \item Write the third-degree Taylor polynomial for $f$ about $x = 0$.
    \item Use your answer in part (a) to approximate $f(0.1)$.
    \item Write the fourth-degree Taylor polynomial for $g(x) = f(x^2)$ about $x = 0$.
    \item The Taylor series for $f$ about $x = 0$ converges to $f(x)$ for all $x$ in the interval of convergence. Show that the sixth-degree Taylor polynomial for $f$ about $x = 0$ approximates $f(0.1)$ with error less than $10^{-8}$.
\end{enumerate}
```

```latex
\noindent\textbf{Question 2}\\[0.5em]

\textbf{(BC Only)} Consider the infinite series $\displaystyle\sum_{n=1}^{\infty} \frac{(-1)^{n+1}}{n^p}$ for $p > 0$.

\begin{enumerate}[label=\alph*.]
    \item Show that the series converges for all $p > 0$.
    \item Determine all values of $p$ for which the series converges absolutely.
    \item For $p = 2$, find the sum of the first 10 terms. Determine whether this partial sum is greater than or less than the sum of the infinite series.
    \item Find the smallest value of $n$ such that the error in approximating the sum of the series for $p = 1$ by the $n$th partial sum is less than $0.01$.
\end{enumerate}
```

---

## 计算器部分要求

Part B (Question 21-30) 需要计算器的题目：

1. **数值近似**：答案保留 3 位小数
2. **泰勒多项式计算**：特定点的函数值近似
3. **格式要求**：
   - 选项使用小数形式（如 0.3125）
   - 避免过于精确的数值（合理近似）

```latex
% Calculator Example - Series Sum
\item $\displaystyle\sum_{n=0}^{\infty} \frac{2^n}{3^n}$ converges to
\begin{enumerate}[label=(\Alph*)]
    \item 1
    \item 2
    \item 3
    \item 6
    \item Diverges
\end{enumerate}
```

```latex
% Calculator Example - Taylor Polynomial
\item The fourth-degree Taylor polynomial for $f(x) = \ln(1+x)$ at $x=0$ evaluated at $x=0.5$ is approximately
\begin{enumerate}[label=(\Alph*)]
    \item 0.3125
    \item 0.4010
    \item 0.4375
    \item 0.4844
    \item 0.5000
\end{enumerate}
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

**示例：**
```
题目 1: 判断级数 $\sum_{n=1}^{\infty} \frac{1}{n^2}$ 的收敛原因
分析: 这是 p-级数，其中 p = 2 > 1
结论: p-级数当 p > 1 时收敛
验证: 正确答案为 (B)

题目 2: 计算 $\sum_{n=0}^{\infty} \frac{1}{2^n}$
分析: 这是几何级数，首项 a = 1，公比 r = 1/2
计算: S = a/(1-r) = 1/(1-1/2) = 1/(1/2) = 2
验证: 正确答案为 (B)
```

### 简答题验证

**每道简答题必须提供：**

1. 完整的解题步骤
2. 最终答案
3. 关键中间结果

**示例：**
```
Question 1:
(a) Taylor多项式: $P_3(x) = 5 - 3x + \dfrac{x^2}{2} + \dfrac{2x^3}{3}$
    推导: $P_3(x) = f(0) + f'(0)x + \dfrac{f''(0)}{2!}x^2 + \dfrac{f'''(0)}{3!}x^3$
         $= 5 + (-3)x + \dfrac{1}{2}x^2 + \dfrac{4}{6}x^3$
         $= 5 - 3x + \dfrac{x^2}{2} + \dfrac{2x^3}{3}$

(b) 近似值: $f(0.1) \approx P_3(0.1) = 5 - 0.3 + 0.005 + 0.00067 = 4.70567$

(c) $g(x) = f(x^2)$ 的四阶Taylor多项式: $P_4(x) = 5 - 3x^2 + \dfrac{x^4}{2}$

(d) 误差界: $\dfrac{M \cdot |0.1|^6}{6!}$ 其中 $M$ 是 $|f^{(6)}(x)|$ 的上界
    若 $M \leq 720$，则误差 $\leq \dfrac{720 \times 10^{-6}}{720} = 10^{-6} < 10^{-8}$
    需要更小的 M 或更多项来达到 $10^{-8}$ 精度
```

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic series_practice.tex
```

编译输出：
- PDF 文件
- 可能的 warning (Underfull \hbox 等排版警告可忽略)

---

## 输出检查清单

生成试卷后，请确认：

- [ ] Section I Part A: 20 道选择题 (无计算器)
- [ ] Section I Part B: 10 道选择题 (需计算器)
- [ ] Section II Part A: 2 道简答题 (需计算器)
- [ ] Section II Part B: 4 道简答题 (无计算器)
- [ ] 所有选择题有 5 个选项 (A-E)
- [ ] 答案表完整
- [ ] 答案表全部正确
- [ ] 选择题答案没有可预测的明显规律
- [ ] 简答题有详细解答
- [ ] **选择题已进行验证（每题验证过程）**
- [ ] **简答题已提供完整解题步骤**
- [ ] 级数收敛判定主题覆盖完整
- [ ] 泰勒级数主题覆盖完整
- [ ] 拉格朗日误差界题目充足
- [ ] LaTeX 语法正确，可编译
- [ ] 使用 tectonic 编译成功

---

## 注意事项

1. **避免重复**：同一套试卷中不应有相似题目
2. **数值合理**：答案数值应合理，避免过于复杂
3. **符号一致**：全文使用一致的数学符号
4. **题号连续**：确保题号从 1 连续排列
5. **选项格式**：所有选择题选项使用 `(A)`, `(B)`, `(C)`, `(D)`, `(E)` 格式
6. **答案分布**：避免答案过于规律
7. **答案验证**：**必须对每道选择题进行验证，确保答案正确**
8. **选项难度与干扰项设计（重要）**：
   - **每个错误选项必须有其明确意义**：说明该选项对应哪种常见错误（如：收敛性判定方法误用、级数和公式记错、展开项数错误、端点收敛未检查等）
   - **每个错误选项必须有其存在的合理可能性**：解释为什么学生可能会选择该错误选项（即该选项的"迷惑性"来源），确保不是明显可排除的选项
   - **难度保障**：正确选项与错误选项的区分应具有足够难度，不能仅凭外观（如数值接近程度）判断；至少有一个干扰项需要在深入理解后才能排除
   - **设计原则**：错误选项应基于真实的学生易错点设计，而非随意编造
9. **解答步骤**：**简答题必须提供完整的解题步骤**
10. **BC 专属**：所有内容均为 BC 专属，题目中无需特别标注 "(BC Only)"

---

## 常见函数的泰勒级数参考

| 函数 | 麦克劳林级数 | 收敛区间 |
|------|--------------|----------|
| $e^x$ | $\displaystyle\sum_{n=0}^{\infty} \dfrac{x^n}{n!}$ | $(-\infty, \infty)$ |
| $\sin x$ | $\displaystyle\sum_{n=0}^{\infty} \dfrac{(-1)^n x^{2n+1}}{(2n+1)!}$ | $(-\infty, \infty)$ |
| $\cos x$ | $\displaystyle\sum_{n=0}^{\infty} \dfrac{(-1)^n x^{2n}}{(2n)!}$ | $(-\infty, \infty)$ |
| $\dfrac{1}{1-x}$ | $\displaystyle\sum_{n=0}^{\infty} x^n$ | $(-1, 1)$ |
| $\ln(1+x)$ | $\displaystyle\sum_{n=1}^{\infty} \dfrac{(-1)^{n+1} x^n}{n}$ | $(-1, 1]$ |
| $\arctan x$ | $\displaystyle\sum_{n=0}^{\infty} \dfrac{(-1)^n x^{2n+1}}{2n+1}$ | $[-1, 1]$ |
