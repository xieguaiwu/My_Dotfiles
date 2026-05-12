---
name: ap-calculus-bc-integration-practice
version: 1.0.0
description: 生成AP Calculus BC积分专项练习(LaTeX格式)
triggers:
  - "积分练习"
  - "integration practice"
  - "AP积分"
inputs:
  - name: output
    description: 输出.tex文件路径
    required: false
    default: integration_practice.tex
tools:
  - write
  - bash
---

# AP Calculus BC 积分专项练习生成

## 核心
```
你是一位资深的 AP Calculus BC 考试出题专家。请生成一份 AP Calculus BC 积分计算专项练习，输出为 LaTeX 源码。

**重要：不要在试卷末尾添加参考答案。**

## 试卷结构

### 题目形式

本练习为**纯计算题**形式，不包含选择题或简答题。所有题目要求计算不定积分。

### 题目数量与分布

共 65 题，分为 7 个 Section：

| Section | 主题 | 题数 |
|---------|------|------|
| 1 | Basic Integration Formulas (基本积分公式) | 5 题 |
| 2 | U-Substitution (换元积分) | 10 题 |
| 3 | Integration by Parts (分部积分) | 10 题 |
| 4 | Partial Fractions (部分分式) | 10 题 |
| 5 | Trigonometric Integrals (三角函数积分) | 10 题 |
| 6 | Trigonometric Substitution (三角替换) | 10 题 |
| 7 | Mixed Practice (综合练习) | 10 题 |

### 难度分布

- 简单 (30%)：直接应用公式
- 中等 (50%)：需要识别方法
- 困难 (20%)：需要多种技巧组合

### BC 专属内容

必须包含以下 BC 专属积分技巧：

| 技巧 | 最少题数 |
|------|----------|
| 分部积分 | 10 题 |
| 部分分式 | 10 题 |
| 三角积分 | 10 题 |
| 三角替换 | 10 题 |

---

## LaTeX 格式规范

### 文档头部

```latex
\documentclass[10pt,a4paper]{article}
\usepackage{amsmath,amssymb,amsfonts}
\usepackage{geometry}
\usepackage{enumitem}
\usepackage{multicol}
\usepackage{titlesec}

\geometry{margin=0.35in}

\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}

\newcommand{\prob}[1]{\item $\displaystyle #1$}

\begin{document}
```

### 标题格式

```latex
\begin{center}
    {\LARGE\bfseries AP Calculus BC Integration Practice}\\[0.3em]
    {\large Name: \underline{\hspace{4cm}} \qquad Date: \underline{\hspace{3cm}}}
\end{center}

\vspace{0.3em}

\hrule
\vspace{0.3em}

{\bfseries Instructions:} Evaluate the following indefinite integrals. Choose appropriate integration methods.
```

### Section 标题格式

```latex
% Section n: [Topic]
\section{[Topic Name]}
```

### 题目格式

```latex
\begin{enumerate}
    \prob{\int [被积函数] \, dx}
\end{enumerate}
```

**重要格式要求：**
- 使用 `\prob` 命令包裹积分表达式
- 积分符号使用 `\int`
- 被积函数后加 `\, dx`
- 使用 `\displaystyle` 使公式清晰
- 分数使用 `\dfrac` 或 `\frac`
- 根号使用 `\sqrt{}`
- 特殊函数使用 `\sin`, `\cos`, `\tan`, `\sec`, `\cot`, `\csc`, `\ln`, `\arctan`, `\arcsin` 等

### 数学公式规范

| 类型 | 正确写法 |
|------|----------|
| 不定积分 | `$\displaystyle\int f(x)\, dx$` |
| 分数 | `$\dfrac{a}{b}$` |
| 根号 | `$\sqrt{x}$` 或 `$\sqrt[n]{x}$` |
| 幂次 | `$x^n$` 或 `$x^{n}$` |
| 自然对数 | `\ln x` |
| 反三角 | `\arctan x`, `\arcsin x` |
| 三角函数 | `\sin x`, `\cos x`, `\tan x`, `\sec x`, `\cot x`, `\csc x` |

---

## 各 Section 题目设计要求

### Section 1: Basic Integration Formulas

基本积分公式应用，包括：
- 多项式积分
- 有理函数积分（分母为单项式）
- 指数函数积分
- 对数函数积分
- 基本三角函数积分

**示例：**
```latex
\prob{\int (3x^4 - 2x^2 + 5x - 1) \, dx}
\prob{\int \left(e^x - \frac{2}{x} + \frac{1}{x^2}\right) \, dx}
\prob{\int (2\sin x + 3\cos x - \sec^2 x) \, dx}
```

### Section 2: U-Substitution

换元积分法，包括：
- 基本换元
- 三角函数换元
- 指数函数换元
- 对数相关换元
- 复合函数换元

**示例：**
```latex
\prob{\int x\sqrt{1 + x^2} \, dx}
\prob{\int e^{\sin x}\cos x \, dx}
\prob{\int \frac{dx}{x\ln x}}
\prob{\int \tan x \, dx}
```

### Section 3: Integration by Parts

分部积分法，包括：
- 基本分部积分
- 多次分部积分
- 循环积分（如 $\int e^x\sin x\,dx$）
- 含反三角函数的积分
- 含对数函数的积分

**示例：**
```latex
\prob{\int x e^{2x} \, dx}
\prob{\int x^2 \ln x \, dx}
\prob{\int \arctan x \, dx}
\prob{\int e^x \sin x \, dx}
```

### Section 4: Partial Fractions

部分分式积分，包括：
- 线性因式分解
- 重复线性因式
- 不可约二次因式
- 混合情形

**示例：**
```latex
\prob{\int \frac{dx}{x^2 - 9}}
\prob{\int \frac{x^2 + 1}{x(x - 1)^2} \, dx}
\prob{\int \frac{x + 4}{x^3 + 4x} \, dx}
```

### Section 5: Trigonometric Integrals

三角函数积分，包括：
- $\sin^n x$ 或 $\cos^n x$ 类型
- $\sin^m x \cos^n x$ 类型
- $\tan^n x$ 或 $\sec^n x$ 类型
- 三角恒等变换

**示例：**
```latex
\prob{\int \sin^3 x \, dx}
\prob{\int \sin^2 x \cos^3 x \, dx}
\prob{\int \tan^4 x \, dx}
\prob{\int \sin(3x)\cos(2x) \, dx}
```

### Section 6: Trigonometric Substitution

三角替换积分，包括：
- $\sqrt{a^2 - x^2}$ 型（用 $x = a\sin\theta$）
- $\sqrt{a^2 + x^2}$ 型（用 $x = a\tan\theta$）
- $\sqrt{x^2 - a^2}$ 型（用 $x = a\sec\theta$）

**示例：**
```latex
\prob{\int \frac{dx}{\sqrt{9 - x^2}}}
\prob{\int \frac{dx}{x^2\sqrt{x^2 + 4}}}
\prob{\int \frac{\sqrt{x^2 - 1}}{x} \, dx}
```

### Section 7: Mixed Practice

综合练习，需要判断使用哪种方法：
- 可能需要多种方法组合
- 可能需要变形后选择方法
- 可能需要创造性的换元

**示例：**
```latex
\prob{\int \frac{dx}{\sqrt{x} + 1}}
\prob{\int x \arcsin x \, dx}
\prob{\int \frac{dx}{1 + e^x}}
\prob{\int \frac{\sin x + \cos x}{\sin x - \cos x} \, dx}
```

---

## 题目设计原则

### 通用原则

1. **答案形式**：
   - 不定积分答案应包含 $+ C$
   - 答案为简洁的解析表达式
   - 避免过度复杂的中间步骤

2. **题目表述**：
   - 清晰无歧义
   - 使用标准数学符号
   - 被积函数形式便于识别方法

3. **技巧覆盖**：
   - 每个 Section 内题目应有不同的变化
   - 避免同一技巧的重复题目
   - 确保覆盖该主题的常见情形

### 难度控制

| 难度 | 特征 | 比例 |
|------|------|------|
| 简单 | 直接应用公式或基本方法 | 30% |
| 中等 | 需要识别适当方法，有少量变形 | 50% |
| 困难 | 需要多种方法组合或创造性变形 | 20% |

---

## 结尾格式

```latex
\vspace{0.5em}
\hrule
\vspace{0.3em}
\begin{center}
    {\itshape --- End ---}
\end{center}

\end{document}
```

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic integration_practice.tex
```

编译输出：
- PDF 文件
- 可能的 warning (Underfull \hbox 等排版警告可忽略)

---

## 输出检查清单

生成练习后，请确认：

- [ ] Section 1: 5 道基本积分题
- [ ] Section 2: 10 道换元积分题
- [ ] Section 3: 10 道分部积分题
- [ ] Section 4: 10 道部分分式题
- [ ] Section 5: 10 道三角函数积分题
- [ ] Section 6: 10 道三角替换题
- [ ] Section 7: 10 道综合题
- [ ] **不包含答案**
- [ ] **不包含解答步骤**
- [ ] BC 专属积分技巧覆盖完整
- [ ] LaTeX 语法正确，可编译
- [ ] 使用 tectonic 编译成功

---

## 注意事项

1. **避免重复**：同一套练习中不应有非常相似的题目
2. **答案合理**：积分结果应为简洁的标准形式
3. **符号一致**：全文使用一致的数学符号
4. **题号连续**：确保题号从 1 连续排列至 65
5. **方法明确**：每个 Section 的题目应能通过该 Section 的方法解决
6. **无答案**：**不要在试卷末尾添加任何答案或解答**
7. **文件写入安全**：使用 `write` 前必须用 `glob` 或 `read` 确认目标文件是否已存在。若文件已存在，优先用 `edit` 追加内容，而非直接 `write` 覆写。确需覆写须先告知用户。
