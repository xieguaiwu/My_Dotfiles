---
name: ap-calculus-bc-parametric-polar-vector
version: 1.0.0
description: 生成AP Calculus BC参数方程、极坐标与向量专项练习(LaTeX格式)
triggers:
  - "参数方程练习"
  - "极坐标练习"
  - "向量函数练习"
  - "parametric polar"
inputs:
  - name: output
    description: 输出.tex文件路径
    required: false
    default: parametric_polar_vector_practice.tex
tools:
  - write
  - bash
---

# AP Calculus BC 参数方程、极坐标与向量函数专项练习生成

## 核心
```
你是一位资深的 AP Calculus BC 考试出题专家。请生成一份 AP Calculus BC 参数方程、极坐标与向量函数专项练习，输出为 LaTeX 源码。

**重要：不要在试卷末尾添加参考答案。**

## 试卷结构

### Section I: Multiple-Choice Questions (选择题，共 30 题)

**Part A: 20 题，40 分钟，无计算器**
- 题号 1-20
- 涵盖主题：
  - 参数方程基础与转换 (约 3-4 题)
  - 参数方程求导 (约 4-5 题)
  - 极坐标基础与转换 (约 3-4 题)
  - 极坐标求导 (约 2-3 题)
  - 向量函数基础 (约 3-4 题)
  - 向量函数求导与积分 (约 2-3 题)

**Part B: 10 题，20 分钟，需要图形计算器**
- 题号 21-30
- 涵盖主题：
  - 参数方程弧长计算
  - 极坐标面积计算
  - 向量函数运动分析
  - 数值近似问题

### Section II: Free-Response Questions (简答题，共 6 题)

**Part A: 2 题，18 分钟，需要计算器**
- 题目通常涉及：参数方程运动分析、极坐标面积

**Part B: 4 题，36 分钟，无计算器**
- 题目通常涉及：参数方程切线、极坐标曲线分析、向量运动

**注意：不生成答案部分**

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
{\Large\bfseries AP Calculus BC: Parametric, Polar \& Vector Functions}\\[0.5em]
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
- 使用 `\displaystyle` 使公式更清晰
- 复杂表达式使用 `\dfrac` 而非 `\frac`
- 向量使用 `\langle a, b \rangle` 或 `\mathbf{v}`

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
| 参数方程导数 | `$\dfrac{dy}{dx} = \dfrac{dy/dt}{dx/dt}$` |
| 参数方程二阶导数 | `$\dfrac{d^2y}{dx^2} = \dfrac{d}{dt}\left(\dfrac{dy}{dx}\right) \div \dfrac{dx}{dt}$` |
| 弧长 | `$\displaystyle\int_a^b \sqrt{\left(\dfrac{dx}{dt}\right)^2 + \left(\dfrac{dy}{dt}\right)^2}\, dt$` |
| 速度 | `$\|\mathbf{v}(t)\| = \sqrt{(x')^2 + (y')^2}$` |
| 极坐标转换 | `$x = r\cos\theta$, $y = r\sin\theta$` |
| 极坐标面积 | `$\dfrac{1}{2}\displaystyle\int_\alpha^\beta r^2\, d\theta$` |
| 极坐标导数 | `$\dfrac{dy}{dx} = \dfrac{r\cos\theta + r'\sin\theta}{-r\sin\theta + r'\cos\theta}$` |
| 向量 | `$\mathbf{v}(t) = \langle x(t), y(t) \rangle$` |
| 分数 | `$\dfrac{a}{b}$` |

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

### 参数方程主题

| 主题 | 要求 |
|------|------|
| 参数方程转笛卡尔坐标 | 消参、识别曲线类型 |
| 参数方程求导 | $\dfrac{dy}{dx} = \dfrac{dy/dt}{dx/dt}$ |
| 参数方程二阶导数 | 正确应用链式法则 |
| 切线方程 | 给定点或参数值求切线 |
| 弧长 | BC 专属公式应用 |
| 速度与速率 | 位置、速度、加速度关系 |

### 极坐标主题

| 主题 | 要求 |
|------|------|
| 极坐标与笛卡尔坐标转换 | 双向转换 |
| 极坐标曲线识别 | 圆、玫瑰曲线、心形线、螺线 |
| 极坐标面积 | $\dfrac{1}{2}\int r^2\, d\theta$ |
| 两极坐标曲线间面积 | 分区域计算 |
| 极坐标切线斜率 | $\dfrac{dy}{dx}$ 公式应用 |

### 向量函数主题

| 主题 | 要求 |
|------|------|
| 向量函数基础 | 位置、速度、加速度向量 |
| 向量求导 | $\mathbf{r}'(t) = \langle x'(t), y'(t) \rangle$ |
| 速度与速率 | 速度向量与标量速率 |
| 运动方向 | 切向量方向 |
| 位移与路程 | 区分概念与计算 |

### BC 专属主题

必须在试卷中出现的 BC 专属内容：

| 主题 | 最少题数 |
|------|----------|
| 参数方程弧长 | 3-4 题 |
| 极坐标面积 | 4-5 题 |
| 向量函数运动分析 | 3-4 题 |

---

## 题目类型示例

### 参数方程选择题示例

```latex
% Q1: Parametric Derivative
\item If $x = t^2$ and $y = t^3$, find $\dfrac{dy}{dx}$.
\begin{enumerate}[label=(\Alph*)]
    \item $\dfrac{3t}{2}$
    \item $\dfrac{2}{3t}$
    \item $\dfrac{3t^2}{2t}$
    \item $\dfrac{2t}{3t^2}$
    \item $3t^2$
\end{enumerate}
```

```latex
% Q2: Parametric Arc Length
\item For the curve given by $x = \cos t$, $y = \sin t$, the arc length for $0 \le t \le \pi$ is
\begin{enumerate}[label=(\Alph*)]
    \item 1
    \item $\pi$
    \item $2\pi$
    \item $\dfrac{\pi}{2}$
    \item $2$
\end{enumerate}
```

### 极坐标选择题示例

```latex
% Q3: Polar Conversion
\item Convert the polar point $(2, \frac{\pi}{3})$ to Cartesian coordinates.
\begin{enumerate}[label=(\Alph*)]
    \item $(1, \sqrt{3})$
    \item $(\sqrt{3}, 1)$
    \item $(1, 1)$
    \item $(2\sqrt{3}, 2)$
    \item $(2, \sqrt{3})$
\end{enumerate}
```

```latex
% Q4: Polar Area
\item The area enclosed by the polar curve $r = 2$ for $0 \le \theta \le \pi$ is
\begin{enumerate}[label=(\Alph*)]
    \item $2\pi$
    \item $4\pi$
    \item $\pi$
    \item $2$
    \item $4$
\end{enumerate}
```

### 向量函数选择题示例

```latex
% Q5: Vector Derivative
\item If $\mathbf{r}(t) = \langle t^2, e^t \rangle$, then $\mathbf{r}'(2) =$
\begin{enumerate}[label=(\Alph*)]
    \item $\langle 4, e^2 \rangle$
    \item $\langle 2, e^2 \rangle$
    \item $\langle 4, 2e^2 \rangle$
    \item $\langle 2t, e^t \rangle$
    \item $\langle 2, e \rangle$
\end{enumerate}
```

```latex
% Q6: Speed
\item For the curve $x = t^2 - 1$, $y = t^3 - t$, the speed at $t = 2$ is approximately
\begin{enumerate}[label=(\Alph*)]
    \item 6.08
    \item 8.06
    \item 10.05
    \item 11.70
    \item 15.23
\end{enumerate}
```

### 简答题示例

```latex
\noindent\textbf{Question 1}\\[0.5em]

\textbf{(BC Only)} A particle moves in the $xy$-plane so that its position at time $t \geq 0$ is given by the parametric equations $x(t) = t^2 - 4t$ and $y(t) = t^3 - 3t$.

\begin{enumerate}[label=\alph*.]
    \item Find the velocity vector $\mathbf{v}(t)$ and the acceleration vector $\mathbf{a}(t)$ at time $t$.
    \item Find the speed of the particle at time $t = 2$.
    \item Find the equation of the line tangent to the path of the particle at $t = 2$.
    \item Find the total distance traveled by the particle for $0 \leq t \leq 3$.
\end{enumerate}
```

```latex
\noindent\textbf{Question 2}\\[0.5em]

Consider the polar curve $r = 3 - 2\sin\theta$ for $0 \leq \theta \leq 2\pi$.

\begin{enumerate}[label=\alph*.]
    \item Find the area enclosed by the curve.
    \item Find the values of $\theta$ where $r$ has a maximum value and a minimum value.
    \item Find the slope of the tangent line to the curve at $\theta = \dfrac{\pi}{2}$.
    \item Set up, but do not evaluate, an integral expression for the perimeter of the region enclosed by the curve.
\end{enumerate}
```

---

## 计算器部分要求

Part B (Question 21-30) 需要计算器的题目：

1. **数值近似**：答案保留 3 位小数
2. **复杂积分**：无法手算的积分表达式
3. **格式要求**：
   - 选项使用小数形式（如 6.08）
   - 避免过于精确的数值（合理近似）

```latex
% Calculator Example - Parametric Speed
\item For the curve $x = t^2 - 1$, $y = t^3 - t$, the speed at $t = 2$ is approximately
\begin{enumerate}[label=(\Alph*)]
    \item 6.08
    \item 8.06
    \item 10.05
    \item 11.70
    \item 15.23
\end{enumerate}
```

```latex
% Calculator Example - Polar Area
\item The area enclosed by the polar curve $r = 2 + \sin(3\theta)$ is approximately
\begin{enumerate}[label=(\Alph*)]
    \item 9.87
    \item 12.57
    \item 15.71
    \item 18.85
    \item 25.13
\end{enumerate}
```

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic parametric_polar_vector_practice.tex
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
- [ ] 参数方程主题覆盖完整（求导、弧长、运动）
- [ ] 极坐标主题覆盖完整（转换、面积、切线）
- [ ] 向量函数主题覆盖完整（位置、速度、加速度）
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
8. **选项难度与干扰项设计（重要）**：
   - **每个错误选项必须有其明确意义**：说明该选项对应哪种常见错误（如：符号错误、公式混淆、概念误解、计算跳步等）
   - **每个错误选项必须有其存在的合理可能性**：解释为什么学生可能会选择该错误选项（即该选项的"迷惑性"来源），确保不是明显可排除的选项
   - **难度保障**：正确选项与错误选项的区分应具有足够难度，不能仅凭外观（如数值接近程度）判断；至少有一个干扰项需要在深入理解后才能排除
   - **设计原则**：错误选项应基于真实的学生易错点设计，而非随意编造
9. **BC 专属**：所有内容均为 BC 专属，题目中无需特别标注 "(BC Only)"
10. **Git 安全网 + 文件写入安全**：本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行 `write`/`edit` 前必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。同时：使用 `write` 前必须用 `glob` 或 `read` 确认目标文件是否已存在；若文件已存在，优先用 `edit` 追加内容，而非直接 `write` 覆写；确需覆写须先告知用户。
