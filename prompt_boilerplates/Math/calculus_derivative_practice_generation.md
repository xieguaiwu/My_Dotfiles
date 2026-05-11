---
name: calculus-derivative-practice-generation
version: 1.0.0
description: 生成微积分求导运算选择题练习试卷(含详细解答)
triggers:
  - "生成求导练习"
  - "求导试卷"
  - "导数练习题"
  - "derivative practice"
inputs:
  - name: topics
    description: 题目主题（如 chain-rule, product-rule, quotient-rule, trigonometric, exponential, logarithmic, implicit, 或 all）
    required: false
    default: "all"
  - name: num_questions
    description: 题目数量
    required: false
    default: "30"
  - name: difficulty
    description: 难度分布（easy/medium/hard 或 mixed）
    required: false
    default: "mixed"
  - name: output
    description: 输出文件路径（.md 或 .tex）
    required: false
    default: "Derivative_Practice.md"
tools:
  - write
  - bash
---

# 微积分求导运算练习试卷生成

## 任务目标

生成一份包含指定数量的求导运算选择题练习试卷，每道题目包含：
- 题干：求导表达式
- 四个选项（A-D）：一个正确答案，三个干扰项
- 详细解答步骤
- 正确答案标注

## 题目类型覆盖

当 `topics` 为 `all` 时，按以下比例分配：

| 主题 | 占比 | 典型题型 |
|------|------|----------|
| Chain Rule（链式法则） | 25% | $\frac{d}{dx}\sin(\sqrt{x})$ |
| Product Rule（乘法法则） | 15% | $\frac{d}{dx}(x^2 \sin x)$ |
| Quotient Rule（除法法则） | 15% | $\frac{d}{dx}\frac{x}{x+1}$ |
| Trigonometric（三角函数） | 15% | $\frac{d}{dx}\tan^2 x$ |
| Exponential（指数函数） | 10% | $\frac{d}{dx}e^{x^2}$ |
| Logarithmic（对数函数） | 10% | $\frac{d}{dx}\ln(x^2+1)$ |
| Implicit（隐函数求导） | 10% | $x^2 + y^2 = 1$, find $\frac{dy}{dx}$ |

## 题目设计规范

### 基本格式

每道题目遵循以下结构：

```
## Q{n}

> $\displaystyle \frac{d}{dx}[\text{表达式}] = ?$
> 
> (A) $\text{选项A}$
> (B) $\text{选项B}$
> (C) $\text{选项C}$
> (D) $\text{选项D}$

**解答**：

设 $f(x) = \text{表达式}$

步骤1：识别需要使用的求导法则
步骤2：应用求导法则
步骤3：化简结果

$$\text{推导过程}$$

**答案：X**
```

### 正确答案设计

- 正确答案在 A-D 中随机分布，保持均衡
- 每种选项出现频率大致相同（约各占 25%）
- 避免连续多题答案相同

### 干扰项设计原则

**常见错误类型**：

1. **忘记链式法则**：$\frac{d}{dx}\sin(x^2) = \cos(x^2)$（错误，应乘以 $2x$）

2. **链式法则应用不完整**：$\frac{d}{dx}\sin(\sqrt{x}) = \cos(\sqrt{x}) \cdot \frac{1}{\sqrt{x}}$（错误，应为 $\frac{1}{2\sqrt{x}}$）

3. **符号错误**：$\frac{d}{dx}\ln x = \frac{1}{x}$ 的变体中正负号搞反

4. **系数错误**：漏乘或错乘常数因子

5. **三角恒等变换错误**：混淆 $\sin^2 x$ 和 $(\sin x)^2$

6. **未化简形式**：给出未化简的正确结果作为干扰项

### 难度分级

**Easy（简单）**：
- 单一法则应用
- 表达式结构简单
- 答案形式简洁

示例：
> $\frac{d}{dx}[x^3 \sin x] = ?$

**Medium（中等）**：
- 2-3 层嵌套
- 需要结合多个法则
- 适度化简

示例：
> $\frac{d}{dx}[e^{\sin x}] = ?$

**Hard（困难）**：
- 深层嵌套
- 隐函数求导
- 需要多步化简
- 参数方程求导

示例：
> $\frac{d}{dx}[\ln(\sin(e^{x^2}))] = ?$

## 输出格式

### Markdown 格式（默认）

```markdown
# 微积分求导运算练习

**生成日期**：{日期}
**题目数量**：{数量}
**难度分布**：简单 {n1} 题 / 中等 {n2} 题 / 困难 {n3} 题

---

## Q1

> $\displaystyle \frac{d}{dx}\left[2(\sin\sqrt{x})^2\right] = ?$
> 
> (A) $4\cos\left(\dfrac{1}{2\sqrt{x}}\right)$
> (B) $4\sin\sqrt{x}\,\cos\sqrt{x}$
> (C) $\dfrac{2\sin\sqrt{x}}{\sqrt{x}}$
> (D) $\dfrac{2\sin\sqrt{x}\,\cos\sqrt{x}}{\sqrt{x}}$

**解答**：

设 $f(x) = 2(\sin\sqrt{x})^2 = 2\sin^2(\sqrt{x})$

使用链式法则与幂法则：

$$\begin{aligned}
f'(x) &= 2 \cdot 2\sin(\sqrt{x}) \cdot \cos(\sqrt{x}) \cdot \frac{d}{dx}(\sqrt{x}) \\
&= 4\sin(\sqrt{x})\cos(\sqrt{x}) \cdot \frac{1}{2\sqrt{x}} \\
&= \frac{2\sin(\sqrt{x})\cos(\sqrt{x})}{\sqrt{x}}
\end{aligned}$$

**答案：D**

---

## 答案速查表

| 题号 | 答案 | 题号 | 答案 | 题号 | 答案 |
|------|------|------|------|------|------|
| 1 | D | 11 | B | 21 | A |
| 2 | A | 12 | C | 22 | D |
| ... | ... | ... | ... | ... | ... |
```

### LaTeX 格式（可选）

当 output 参数以 `.tex` 结尾时，生成 LaTeX 格式：

```latex
\documentclass[10pt,a4paper]{article}
\usepackage[margin=0.35in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{multicol}
\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}

\begin{document}

\noindent\textbf{\Large 微积分求导运算练习} \hfill \textit{N Questions}

\vspace{0.3cm}

\begin{multicols}{2}
\begin{enumerate}[label=\textbf{\arabic*.}]

\item $\displaystyle\frac{d}{dx}\left[2(\sin\sqrt{x})^2\right] = ?$
\begin{enumerate}[label=(\Alph*)]
    \item $4\cos\left(\dfrac{1}{2\sqrt{x}}\right)$
    \item $4\sin\sqrt{x}\,\cos\sqrt{x}$
    \item $\dfrac{2\sin\sqrt{x}}{\sqrt{x}}$
    \item $\dfrac{2\sin\sqrt{x}\,\cos\sqrt{x}}{\sqrt{x}}$
\end{enumerate}

\textbf{解答}：...
\textbf{答案：D}

...

\end{enumerate}

\vspace{0.3cm}
\noindent\textbf{Answer Key}

\begin{center}
\begin{tabular}{|c|c||c|c||c|c|}
\hline
\# & Answer & \# & Answer & \# & Answer \\
\hline
1  & D & 11 & B & 21 & A \\
\hline
\end{tabular}
\end{center}

\end{multicols}
\end{document}
```

## 执行流程

### 1. 参数解析

- 解析 `topics` 参数，确定题目类型分布
- 解析 `num_questions` 参数，确定题目数量
- 解析 `difficulty` 参数，确定难度分布
- 解析 `output` 参数，确定输出格式

### 2. 题目生成

按照以下循环生成每道题目：

```
for i in 1 to num_questions:
    1. 根据类型分布选择题目类型
    2. 根据难度分布选择难度级别
    3. 生成原函数表达式
    4. 计算正确的导数结果
    5. 设计3个干扰项
    6. 随机排列选项顺序（记录正确答案位置）
    7. 编写解答步骤
    8. 格式化输出
```

### 3. 验证检查

生成后进行以下检查：

- [ ] 题目数量正确
- [ ] 每道题有4个选项
- [ ] 正确答案经过计算验证
- [ ] 干扰项有明确的错误原因
- [ ] 答案分布均衡（A/B/C/D 各约 25%）
- [ ] 无重复或高度相似的题目
- [ ] 数学公式格式正确
- [ ] 解答步骤清晰完整

### 4. 输出文件

根据 output 参数的扩展名选择格式：
- `.md` → Markdown 格式
- `.tex` → LaTeX 格式

## 题目生成示例库

### Chain Rule（链式法则）

| 原函数 | 正确导数 | 难度 |
|--------|----------|------|
| $\sin(x^2)$ | $2x\cos(x^2)$ | Easy |
| $(x^2+1)^{10}$ | $20x(x^2+1)^9$ | Easy |
| $e^{\sin x}$ | $e^{\sin x}\cos x$ | Medium |
| $\sqrt{\sin x}$ | $\dfrac{\cos x}{2\sqrt{\sin x}}$ | Medium |
| $\ln(\tan x)$ | $\dfrac{\sec^2 x}{\tan x}$ | Medium |
| $\sin(e^{x^2})$ | $2xe^{x^2}\cos(e^{x^2})$ | Hard |
| $\ln(\sin(e^x))$ | $\dfrac{e^x\cos(e^x)}{\sin(e^x)}$ | Hard |

### Product Rule（乘法法则）

| 原函数 | 正确导数 | 难度 |
|--------|----------|------|
| $x \sin x$ | $\sin x + x\cos x$ | Easy |
| $x^2 e^x$ | $xe^x(2+x)$ | Medium |
| $x\ln x$ | $\ln x + 1$ | Easy |
| $e^x \sin x$ | $e^x(\sin x + \cos x)$ | Medium |
| $\sqrt{x}\ln x$ | $\dfrac{\ln x + 2}{2\sqrt{x}}$ | Medium |

### Quotient Rule（除法法则）

| 原函数 | 正确导数 | 难度 |
|--------|----------|------|
| $\dfrac{x}{x+1}$ | $\dfrac{1}{(x+1)^2}$ | Easy |
| $\dfrac{\sin x}{x}$ | $\dfrac{x\cos x - \sin x}{x^2}$ | Medium |
| $\dfrac{e^x}{x}$ | $\dfrac{e^x(x-1)}{x^2}$ | Medium |
| $\dfrac{\ln x}{x}$ | $\dfrac{1 - \ln x}{x^2}$ | Medium |
| $\dfrac{x^2}{x^2+1}$ | $\dfrac{2x}{(x^2+1)^2}$ | Medium |

### Trigonometric（三角函数）

| 原函数 | 正确导数 | 难度 |
|--------|----------|------|
| $\tan^2 x$ | $2\tan x \sec^2 x$ | Easy |
| $\sec x$ | $\sec x \tan x$ | Easy |
| $\sin^3 x$ | $3\sin^2 x \cos x$ | Medium |
| $\tan(x^2)$ | $2x\sec^2(x^2)$ | Medium |
| $\cos(\sin x)$ | $-\sin(\sin x)\cos x$ | Hard |

### Implicit（隐函数求导）

| 方程 | 求 | 正确结果 | 难度 |
|------|-----|----------|------|
| $x^2 + y^2 = 1$ | $\frac{dy}{dx}$ | $-\frac{x}{y}$ | Easy |
| $xy = 1$ | $\frac{dy}{dx}$ | $-\frac{y}{x}$ | Easy |
| $x^3 + y^3 = 6xy$ | $\frac{dy}{dx}$ | $\frac{2y-x^2}{y^2-2x}$ | Hard |
| $e^y = xy$ | $\frac{dy}{dx}$ | $\frac{y}{x(e^y-1)}$ | Hard |

## 注意事项

1. **数学正确性**：每道题的正确答案必须经过严格计算验证
2. **干扰项质量（重要）**：每个干扰项必须基于真实的学生常见错误设计，并明确标注：
   - 该错误选项对应的具体错误类型（如忘记链式法则、符号错误、系数遗漏、法则混淆等）
   - 该错误选项的"迷惑性"来源（学生为什么可能会选择它）
   - 确保每个干扰项都有合理的被选择可能性，不能是明显错误的选项
3. **表达式清晰**：使用 `\displaystyle` 和 `\dfrac` 确保公式美观
4. **难度平衡**：根据 difficulty 参数合理分配简单、中等、困难题目
5. **答案均衡**：确保正确答案在 A/B/C/D 中均匀分布
6. **选项难度与干扰项设计（重要）**：
   - **每个错误选项必须有其明确意义**：说明该选项对应哪种常见求导错误（如：忘记链式法则、符号错误、系数遗漏、法则混淆等）
   - **每个错误选项必须有其存在的合理可能性**：解释为什么学生可能会选择该错误选项（即该选项的"迷惑性"来源），确保不是明显可排除的选项
   - **难度保障**：正确选项与错误选项的区分应具有足够难度，不能仅凭外观（如符号是否相似）判断；至少有一个干扰项需要在正确应用求导法则后才能排除
   - **设计原则**：错误选项应基于真实的学生易错点设计，而非随意编造
7. **避免歧义**：题目表述应清晰无歧义，避免多种理解方式
8. **格式一致**：所有题目使用统一的格式风格

## 检查清单

生成完成后，确认以下事项：

- [ ] 题目数量 = num_questions
- [ ] 每题有 4 个选项（A-D）
- [ ] 正确答案已验证
- [ ] 干扰项有合理依据
- [ ] 答案分布均衡（A/B/C/D 各约 25%）
- [ ] 无重复题目
- [ ] 解答步骤完整
- [ ] 数学公式格式正确
- [ ] 输出文件已创建
