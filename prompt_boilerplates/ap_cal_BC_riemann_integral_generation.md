# AP Calculus BC 黎曼和与定积分转换专项练习生成

---

## 核心
```
你是一位资深的 AP Calculus BC 考试出题专家。请生成一份 AP Calculus BC 黎曼和与定积分转换专项练习，输出为 LaTeX 源码。

**重要：不要在试卷末尾添加参考答案。**
```

## 试卷结构

### Section I: Multiple-Choice Questions (选择题，共 30 题)

**Part A: 20 题，40 分钟，无计算器**
- 题号 1-20
- 涵盖主题：
  - 黎曼和基础概念 (约 2-3 题)
  - 左黎曼和计算 (约 3 题)
  - 右黎曼和计算 (约 3 题)
  - 中点黎曼和计算 (约 2-3 题)
  - 梯形法则 (约 3-4 题)
  - 黎曼和与定积分的关系 (约 3-4 题)
  - 定积分的极限定义 (约 2-3 题)

**Part B: 10 题，20 分钟，需要图形计算器**
- 题号 21-30
- 涵盖主题：
  - 数据表估算积分
  - 误差估计与分析
  - 过高估计与过低估计判定
  - 凹凸性与误差方向关系
  - 复杂函数的黎曼和数值计算

### Section II: Free-Response Questions (简答题，共 6 题)

**Part A: 2 题，18 分钟，需要计算器**
- 题目通常涉及：数据表估算、误差分析、数值积分应用

**Part B: 4 题，36 分钟，无计算器**
- 题目通常涉及：极限定义证明、黎曼和表达式、积分转换、误差分析

**注意：不生成答案部分**

---

## LaTeX 格式规范

### 文档头部

```latex
\documentclass[11pt,letterpaper]{article}
\usepackage[margin=0.75in]{geometry}
\usepackage{amsmath,amssymb,amsfonts}
\usepackage{graphicx}
\usepackage{enumitem}
\usepackage{multicol}
\usepackage{fancyhdr}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,calc,positioning}

\pagestyle{fancy}
\fancyhf{}
\rhead{AP Calculus BC: Riemann Sums \& Definite Integrals}
\lhead{Page \thepage}
\cfoot{}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}

\newcommand{\question}[1]{\textbf{#1}}

\begin{document}
```

### 标题格式

```latex
\begin{center}
{\Large\bfseries AP Calculus BC: Riemann Sums \& Definite Integrals}\\[0.5em]
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
- 求和符号使用 `\sum_{i=1}^{n}` 格式
- 极限符号使用 `\displaystyle\lim_{n\to\infty}`

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
| 黎曼和 | `$\displaystyle\sum_{i=1}^{n} f(x_i^*) \Delta x$` |
| 左黎曼和 | `$\displaystyle\sum_{i=1}^{n} f(x_{i-1}) \Delta x$` |
| 右黎曼和 | `$\displaystyle\sum_{i=1}^{n} f(x_i) \Delta x$` |
| 中点黎曼和 | `$\displaystyle\sum_{i=1}^{n} f\left(\dfrac{x_{i-1}+x_i}{2}\right) \Delta x$` |
| 梯形法则 | `$\dfrac{\Delta x}{2}\displaystyle\sum_{i=1}^{n} [f(x_{i-1}) + f(x_i)]$` |
| 定积分极限定义 | `$\displaystyle\int_a^b f(x)\, dx = \lim_{n\to\infty}\sum_{i=1}^{n} f(x_i^*) \Delta x$` |
| 子区间宽度 | `$\Delta x = \dfrac{b-a}{n}$` |
| 分数 | `$\dfrac{a}{b}$` |

---

## 题目设计要求

### 通用原则

1. **难度分布**：简单 (30%) / 中等 (50%) / 困难 (20%)
2. **答案设计**：
   - 正确答案随机分布 (A-E 均衡)
   - 干扰项应基于常见错误设计
   - 避免"以上皆非"类选项
3. **数值题**：
   - 答案应为简洁的数值或表达式
   - 避免过度复杂的计算
4. **概念题**：
   - 题目表述清晰无歧义
   - 测试核心概念而非记忆

### 黎曼和主题

| 主题 | 要求 |
|------|------|
| 左黎曼和 | 使用左端点值计算，注意区间划分 |
| 右黎曼和 | 使用右端点值计算，注意区间划分 |
| 中点黎曼和 | 使用区间中点值计算 |
| 梯形法则 | 平均相邻函数值，注意系数 $\dfrac{\Delta x}{2}$ |
| 极限与积分转换 | 识别求和式对应的定积分 |
| 定积分极限定义 | 理解 $\lim_{n\to\infty}\sum$ 形式 |

### 误差分析主题

| 主题 | 要求 |
|------|------|
| 凹凸性与误差方向 | 上凹函数：左黎曼和为低估，右黎曼和为高估 |
| 增函数误差分析 | 左黎曼和为低估，右黎曼和为高估 |
| 减函数误差分析 | 左黎曼和为高估，右黎曼和为低估 |
| 梯形法则误差 | 上凹时低估，下凹时高估 |
| 中点法则误差 | 通常比左右黎曼和更精确 |

### BC 专属主题

必须在试卷中出现的 BC 专属内容：

| 主题 | 最少题数 |
|------|----------|
| 极限定义转换为定积分 | 3-4 题 |
| 数据表估算积分 | 4-5 题 |
| 误差分析与判定 | 3-4 题 |
| 梯形法则应用 | 3-4 题 |

---

## 题目类型示例

### 黎曼和计算选择题示例

```latex
% Q1: Left Riemann Sum
\item The left Riemann sum approximation of $\displaystyle\int_0^{4} x^2\, dx$ with $n = 4$ subintervals of equal width is
\begin{enumerate}[label=(\Alph*)]
\item 14
\item 20
\item 21
\item 27
\item 30
\end{enumerate}
```

```latex
% Q2: Right Riemann Sum
\item Using a right Riemann sum with 4 subintervals of equal width, approximate $\displaystyle\int_1^{5} \dfrac{1}{x}\, dx$. The approximation is
\begin{enumerate}[label=(\Alph*)]
\item $\dfrac{13}{12}$
\item $\dfrac{19}{12}$
\item $\dfrac{25}{12}$
\item $\dfrac{31}{12}$
\item $\ln 5$
\end{enumerate}
```

```latex
% Q3: Trapezoidal Rule
\item The trapezoidal sum approximation of $\displaystyle\int_0^{2} (3x + 1)\, dx$ with $n = 4$ subintervals of equal width is
\begin{enumerate}[label=(\Alph*)]
\item 6
\item 7
\item 8
\item 9
\item 10
\end{enumerate}
```

### 极限转换选择题示例

```latex
% Q4: Limit Definition to Integral
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(\dfrac{2i}{n}\right)^2 \cdot \dfrac{2}{n} =$

\begin{enumerate}[label=(\Alph*)]
\item $\displaystyle\int_0^{2} x^2\, dx$
\item $\displaystyle\int_0^{2} 2x^2\, dx$
\item $\displaystyle\int_0^{2} 4x^2\, dx$
\item $\displaystyle\int_0^{4} x^2\, dx$
\item $\displaystyle\int_0^{2} 2x\, dx$
\end{enumerate}
```

```latex
% Q5: Integral to Limit Expression
\item Which of the following represents $\displaystyle\int_1^{3} x^3\, dx$ as a limit of Riemann sums using right endpoints?
\begin{enumerate}[label=(\Alph*)]
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(1 + \dfrac{2i}{n}\right)^3 \cdot \dfrac{2}{n}$
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(\dfrac{i}{n}\right)^3 \cdot \dfrac{1}{n}$
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(1 + \dfrac{i}{n}\right)^3 \cdot \dfrac{1}{n}$
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(\dfrac{2i}{n}\right)^3 \cdot \dfrac{2}{n}$
\item $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(3 + \dfrac{2i}{n}\right)^3 \cdot \dfrac{2}{n}$
\end{enumerate}
```

### 数据表估算选择题示例

```latex
% Q6: Table Data Estimation
\item Selected values of a continuous function $f$ are given in the table below.

\begin{center}
\begin{tabular}{|c|c|c|c|c|c|c|}
\hline
$x$ & 0 & 1 & 2 & 3 & 4 & 5 \\
\hline
$f(x)$ & 2 & 3 & 5 & 4 & 6 & 7 \\
\hline
\end{tabular}
\end{center}

Using a left Riemann sum with 5 subintervals of equal width, the approximation of $\displaystyle\int_0^{5} f(x)\, dx$ is

\begin{enumerate}[label=(\Alph*)]
\item 18
\item 20
\item 23
\item 25
\item 27
\end{enumerate}
```

```latex
% Q7: Midpoint Riemann Sum from Table
\item Selected values of a differentiable function $f$ are given in the table below.

\begin{center}
\begin{tabular}{|c|c|c|c|c|c|}
\hline
$x$ & 0 & 0.5 & 1 & 1.5 & 2 \\
\hline
$f(x)$ & 4 & 5 & 7 & 6 & 8 \\
\hline
\end{tabular}
\end{center}

Using the midpoint sum with 2 subintervals of equal width, approximate $\displaystyle\int_0^{2} f(x)\, dx$.

\begin{enumerate}[label=(\Alph*)]
\item 11
\item 12
\item 13
\item 14
\item 15
\end{enumerate}
```

### 误差分析选择题示例

```latex
% Q8: Error Analysis - Concavity
\item Let $f$ be a continuous, increasing, and concave up function on $[a, b]$. Which of the following correctly describes the relationship between the approximations and the actual value of $\displaystyle\int_a^b f(x)\, dx$?
\begin{enumerate}[label=(\Alph*)]
\item Left sum $<$ Actual $<$ Right sum
\item Right sum $<$ Actual $<$ Left sum
\item Left sum $<$ Right sum $<$ Actual
\item Actual $<$ Left sum $<$ Right sum
\item Left sum $=$ Right sum $<$ Actual
\end{enumerate}
```

```latex
% Q9: Trapezoidal Error
\item If $f$ is a continuous function that is concave down on $[a, b]$, then the trapezoidal sum approximation of $\displaystyle\int_a^b f(x)\, dx$ is
\begin{enumerate}[label=(\Alph*)]
\item less than the actual value
\item greater than the actual value
\item equal to the actual value
\item cannot be determined without knowing $f$
\item sometimes less and sometimes greater than the actual value
\end{enumerate}
```

### 简答题示例

```latex
\noindent\textbf{Question 1}\\[0.5em]

Let $f$ be a continuous function on the interval $[0, 4]$. Selected values of $f$ are given in the table below.

\begin{center}
\begin{tabular}{|c|c|c|c|c|c|}
\hline
$x$ & 0 & 1 & 2 & 3 & 4 \\
\hline
$f(x)$ & 2 & 5 & 3 & 7 & 6 \\
\hline
\end{tabular}
\end{center}

\begin{enumerate}[label=\alph*.]
\item Approximate $\displaystyle\int_0^{4} f(x)\, dx$ using a left Riemann sum with four subintervals of equal width. Show your work.
\item Approximate $\displaystyle\int_0^{4} f(x)\, dx$ using a trapezoidal sum with four subintervals of equal width. Show your work.
\item If $f$ is known to be concave up on $[0, 4]$, which approximation, the left sum or the trapezoidal sum, is guaranteed to be less than the actual value of $\displaystyle\int_0^{4} f(x)\, dx$? Explain your reasoning.
\item Use a midpoint sum with two subintervals of equal width to approximate $\displaystyle\int_0^{4} f(x)\, dx$.
\end{enumerate}
```

```latex
\noindent\textbf{Question 2}\\[0.5em]

Consider the limit $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(3 + \dfrac{4i}{n}\right)^2 \cdot \dfrac{4}{n}$.

\begin{enumerate}[label=\alph*.]
\item Express the limit as a definite integral.
\item Evaluate the integral.
\item Write a right Riemann sum with $n$ subintervals that represents $\displaystyle\int_0^{6} x^3\, dx$.
\item Use the result from part (b) and the definition of the definite integral to evaluate $\displaystyle\lim_{n\to\infty}\sum_{i=1}^{n} \left(\dfrac{6i}{n}\right)^3 \cdot \dfrac{6}{n}$.
\end{enumerate}
```

```latex
\noindent\textbf{Question 3}\\[0.5em]

A car's velocity is measured in feet per second at various times. The data is shown in the table below.

\begin{center}
\begin{tabular}{|c|c|c|c|c|c|c|c|}
\hline
$t$ (seconds) & 0 & 2 & 4 & 6 & 8 & 10 & 12 \\
\hline
$v(t)$ (ft/s) & 0 & 12 & 20 & 18 & 24 & 28 & 32 \\
\hline
\end{tabular}
\end{center}

\begin{enumerate}[label=\alph*.]
\item Use a right Riemann sum with six subintervals to approximate the total distance traveled by the car from $t = 0$ to $t = 12$ seconds.
\item Use a trapezoidal sum with six subintervals to approximate the total distance traveled.
\item Which approximation, the right sum or the trapezoidal sum, gives a better estimate if the velocity function $v(t)$ is known to be concave down? Justify your answer.
\item If the velocity was increasing throughout the 12 seconds, which type of Riemann sum (left or right) would give an underestimate of the total distance? Explain.
\end{enumerate}
```

---

## 计算器部分要求

Part B (Question 21-30) 需要计算器的题目：

1. **数值近似**：答案保留 3 位小数
2. **复杂计算**：涉及多个数据点的计算
3. **格式要求**：
   - 选项使用小数形式（如 12.345）
   - 避免过于精确的数值（合理近似）

```latex
% Calculator Example - Trapezoidal Sum
\item Using the data in the table below, the trapezoidal sum approximation of $\displaystyle\int_0^{10} f(x)\, dx$ with five subintervals is

\begin{center}
\begin{tabular}{|c|c|c|c|c|c|c|}
\hline
$x$ & 0 & 2 & 4 & 6 & 8 & 10 \\
\hline
$f(x)$ & 1.2 & 2.5 & 3.8 & 2.9 & 4.1 & 5.3 \\
\hline
\end{tabular}
\end{center}

\begin{enumerate}[label=(\Alph*)]
\item 28.75
\item 29.20
\item 31.50
\item 32.80
\item 35.60
\end{enumerate}
```

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic riemann_integral_practice.tex
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
- [ ] **不包含答案表**
- [ ] **不包含解答步骤**
- [ ] 左黎曼和计算题目充足
- [ ] 右黎曼和计算题目充足
- [ ] 中点黎曼和计算题目充足
- [ ] 梯形法则应用题目充足
- [ ] 极限与积分转换题目充足
- [ ] 数据表估算题目充足
- [ ] 误差分析题目充足
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
7. **无答案**：**不要在试卷末尾添加任何答案或解答**
8. **BC 专属**：所有内容均为 BC 专属，题目中无需特别标注 "(BC Only)"
