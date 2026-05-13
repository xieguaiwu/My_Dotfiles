---
name: ap-csa-exam-generation
version: 1.0.0
description: 生成AP Computer Science A完整模拟试卷(LaTeX格式)
triggers:
  - "AP CSA 试卷"
  - "生成AP试卷"
  - "AP mock exam"
inputs:
  - name: output
    description: 输出.tex文件路径
    required: false
    default: AP_CSA_Mock_Exam.tex
tools:
  - write
  - bash
---

# AP CSA 模拟试卷生成

## 核心
```
你是一位资深的 AP CSA 考试出题专家。请生成一份完整的 AP CSA 模拟试卷，输出为 LaTeX 源码。

## 试卷结构

### Section I: Multiple-Choice Questions (选择题，共 40 题)

**Part A: 40 题，90 分钟**
- 题号 1-40
- 分数占比：50%
- 考试形式：全数字化考试，使用 Bluebook 测试应用
- 可使用 Java Quick Reference（包含常用 Java 库方法）

**知识点分布：**
- Unit 1: Using Objects and Methods (约 15-25%，6-10 题)
  - String methods: substring(), indexOf(), length(), compareTo(), equals()
  - compareTo vs equals 的区别
  - 对象引用和别名 (Object References and Aliasing)
  - 方法签名和返回类型
  - Java 的值传递 (Pass-by-Value)
  - 类型转换和强制转换 (Casting & Type Conversion)
  - 包装类和自动装箱 (Wrapper Classes & Autoboxing) 【2025-2026 重点加强】
  - 注释和文档

- Unit 2: Selection and Iteration (约 25-35%，10-14 题) 【占比最高】
  - 布尔表达式和逻辑运算符
  - 布尔表达式等价性（De Morgan's Laws）
  - 短路求值 (Short-Circuit Evaluation)
  - if/else 链 vs 独立 if 语句
  - for 循环跟踪和差一错误 (Off-by-One Errors)
  - while 循环和哨兵循环
  - 嵌套循环
  - 字符串遍历模式
  - 常见循环错误
  - break 和 continue
  - 累加器、计数器、最大值和最小值
  - 输入验证和守卫条件

- Unit 3: Class Creation (约 10-18%，4-7 题)
  - 编写类
  - 构造方法
  - 访问器和修改器方法 (Accessor and Mutator Methods)
  - 静态 vs 实例 (Static vs Instance)
  - this 关键字
  - 值传递和对象修改
  - NullPointerException
  - 作用域：局部变量 vs 实例变量
  - 辅助方法和私有方法

- Unit 4: Data Collections (约 30-40%，12-16 题) 【占比最高】
  - 1D 数组：初始化、遍历、最大/最小值、相邻元素模式
  - ArrayList：基本操作、遍历、排序、对象操作
  - 2D 数组：行列遍历、对角线模式、邻居检查
  - 搜索算法：线性搜索、二分搜索 【新增】
  - 排序算法：选择排序、插入排序、归并排序（仅跟踪）【新增】
  - 递归跟踪
  - 运行时分析和 Big-O

**2025-2026 新增内容：**
- File I/O with Scanner（使用 Scanner 和 File 读取文本文件）
- Wrapper Classes 扩展强调
- 二分搜索、选择排序、插入排序、归并排序跟踪

### Section II: Free-Response Questions (简答题，共 4 题)

**4 题，90 分钟，50% 分数占比**
- 全数字化考试，使用 Bluebook 测试应用
- 所有代码必须用 Java 编写
- 可使用 Java Quick Reference

**题型分布（每题固定顺序）：**

1. **Question 1: Methods and Control Structures**
   - 编写程序代码创建对象、调用方法
   - 使用表达式、条件语句、迭代语句满足方法规范
   - 考点：方法编写、if/else、循环

2. **Question 2: Classes**
   - 编写程序代码定义新类型（创建类）
   - 使用表达式、条件语句、迭代语句满足方法规范
   - 考点：类定义、构造方法、实例变量、方法

3. **Question 3: Array/ArrayList**
   - 使用表达式、条件语句、迭代语句满足方法规范
   - 创建、遍历和操作 1D 数组或 ArrayList 对象
   - 考点：数组遍历、ArrayList 操作

4. **Question 4: 2D Array**
   - 使用表达式、条件语句、迭代语句满足方法规范
   - 创建、遍历和操作 2D 数组对象
   - 考点：嵌套循环、2D 数组遍历、行列操作

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
\usepackage{listings}
\usepackage{xcolor}
\usepackage{fancyvrb}
\usetikzlibrary{arrows.meta,calc,positioning}

\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}

\newcommand{\question}[1]{\textbf{#1}}
\newcommand{\mcitem}[1]{\item[\textbf{#1}]}

\lstset{
    language=Java,
    basicstyle=\ttfamily\small,
    keywordstyle=\color{blue}\bfseries,
    commentstyle=\color{green!60!black}\itshape,
    stringstyle=\color{red},
    showstringspaces=false,
    breaklines=true,
    frame=single,
    backgroundcolor=\color{gray!10},
    tabsize=4
}

\begin{document}
```

### 标题格式

```latex
\begin{center}
{\Large\bfseries AP Computer Science A Mock Examination}\\[0.5em]
{\large Practice Test}\\[1em]
\end{center}
```

### 选择题格式

```latex
% Qn: [Topic]
\item Consider the following code segment.
\begin{lstlisting}
[Java 代码]
\end{lstlisting}
What is printed as a result of executing this code segment?
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
- 使用 `lstlisting` 环境显示 Java 代码
- 代码必须有正确的缩进
- 变量名使用有意义的小驼峰命名

### 简答题格式

```latex
\noindent\textbf{Question n: [Type]}\\[0.5em]

[题目背景描述和类定义]

\begin{lstlisting}
public class ClassName {
    // 方法定义和注释
}
\end{lstlisting}

\begin{enumerate}[label=\alph*.]
    \item 第一小题
    \item 第二小题
    \item 第三小题
\end{enumerate}
```

### 代码格式规范

| 类型 | 正确写法 |
|------|----------|
| 类名 | PascalCase (如 `GameBoard`) |
| 方法名 | camelCase (如 `calculateSum`) |
| 常量 | UPPER_SNAKE_CASE |
| 缩进 | 4 空格 |
| 花括号 | K&R 风格 |

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
3. **代码题**：
   - 代码应简洁、无冗余
   - 变量名应有意义
   - 避免过于复杂的逻辑
4. **概念题**：
   - 题目表述清晰无歧义
   - 测试核心概念而非记忆

### 必须覆盖的主题

| 主题 | 最少题数 |
|------|----------|
| String 方法 (substring, indexOf, length) | 2-3 题 |
| 布尔表达式和 De Morgan's Laws | 2-3 题 |
| for/while 循环和嵌套循环 | 4-5 题 |
| 类定义和构造方法 | 2-3 题 |
| 数组遍历和操作 | 3-4 题 |
| ArrayList 方法 | 2-3 题 |
| 2D 数组遍历 | 2-3 题 |
| 递归跟踪 | 1-2 题 |
| 搜索/排序算法 | 2-3 题 |

### Java Quick Reference 中的方法

**String 类：**
- `int length()` - 返回字符串长度
- `String substring(int from, int to)` - 返回从 from 到 to（不包含）的子串
- `String substring(int from)` - 返回从 from 到末尾的子串
- `int indexOf(String s)` - 返回 s 第一次出现的索引，不存在返回 -1
- `boolean equals(String other)` - 比较内容是否相同
- `int compareTo(String other)` - 字典序比较

**ArrayList 类：**
- `int size()` - 返回元素数量
- `boolean add(E obj)` - 在末尾添加元素
- `void add(int index, E obj)` - 在指定位置插入元素
- `E get(int index)` - 返回指定位置的元素
- `E set(int index, E obj)` - 替换指定位置的元素
- `E remove(int index)` - 移除并返回指定位置的元素

**注意：charAt() 不在 Quick Reference 中！**

---

## 答案验证要求
### 选择题验证

**必须对每道选择题进行代码执行验证，确认：**

1. 正确答案确实正确
2. 干扰项有明确的错误原因

**验证模板：**
```
题目 X: 执行代码
代码: [代码]
步骤: [逐步执行]
结果: [答案]
验证: 正确答案为 (X)
```

### 简答题验证

**每道简答题必须提供：**

1. 完整的 Java 代码
2. 代码符合 AP 阅卷标准
3. 使用有意义的方法名和变量名
4. 必要时添加注释

---

## 编译说明

使用 tectonic 编译：
```bash
tectonic AP_CSA_Mock_Exam.tex
```

编译输出：
- PDF 文件
- 可能的 warning (Underfull \hbox 等排版警告可忽略)

---

## 输出检查清单

生成试卷后，请确认：

- [ ] Section I: 40 道选择题
- [ ] Section II: 4 道简答题
- [ ] FRQ 1: Methods and Control Structures
- [ ] FRQ 2: Classes
- [ ] FRQ 3: Array/ArrayList
- [ ] FRQ 4: 2D Array
- [ ] 所有选择题有 5 个选项 (A-E)
- [ ] 答案表完整
- [ ] 答案表全部正确
- [ ] 选择题答案没有可预测的明显规律
- [ ] 简答题有详细解答
- [ ] Unit 1-4 知识点覆盖完整
- [ ] LaTeX 语法正确，可编译
- [ ] 使用 tectonic 编译成功
- [ ] 代码使用 lstlisting 环境
- [ ] 所有 Java 代码格式正确

---

## 示例题目
### 选择题示例

```latex
% Q1: String Methods
\item Consider the following code segment.
\begin{lstlisting}
String s = "PROGRAMMING";
System.out.println(s.substring(3, 7).length());
\end{lstlisting}
What is printed as a result of executing this code segment?
\begin{enumerate}[label=(\Alph*)]
    \item 3
    \item 4
    \item 5
    \item 7
    \item "GRAM"
\end{enumerate}
```
**验证：** `s.substring(3, 7)` = "GRAM"（4个字符），`length()` = 4，答案 B

### 简答题示例

```latex
\noindent\textbf{Question 1: Methods and Control Structures}\\[0.5em]

A number utility class provides methods for working with integers.

\begin{lstlisting}
public class NumberUtil {
    /** Returns the sum of all even numbers in the array.
     *  @param nums an array of integers
     *  @return the sum of all even numbers
     */
    public static int sumEvens(int[] nums) {
        // to be implemented in part (a)
    }
    
    /** Returns true if the array contains the target value.
     *  @param nums an array of integers
     *  @param target the value to search for
     *  @return true if target is found, false otherwise
     */
    public static boolean contains(int[] nums, int target) {
        // to be implemented in part (b)
    }
}
\end{lstlisting}

\begin{enumerate}[label=\alph*.]
    \item Write the method \texttt{sumEvens} that returns the sum of all even numbers in the array.
    \item Write the method \texttt{contains} that returns true if the target value is found in the array.
\end{enumerate}
```

---

## 注意事项

1. **避免重复**：同一套试卷中不应有相似题目
2. **代码规范**：所有 Java 代码遵循标准命名规范
3. **符号一致**：全文使用一致的术语和符号
4. **题号连续**：确保题号从 1 连续排列
5. **选项格式**：所有选择题选项使用 `(A)`, `(B)`, `(C)`, `(D)`, `(E)` 格式
6. **答案分布**：避免答案过于规律
7. **选项难度与干扰项设计（重要）**：
   - **每个错误选项必须有其明确意义**：说明该选项对应哪种常见错误（如：off-by-one 错误、循环边界混淆、索引计算失误、布尔逻辑误解、引用 vs 值混淆等）
   - **每个错误选项必须有其存在的合理可能性**：解释为什么学生可能会选择该错误选项（即该选项的"迷惑性"来源），确保不是明显可排除的选项
   - **难度保障**：正确选项与错误选项的区分应具有足够难度，不能仅凭外观判断；至少有一个干扰项需要深入跟踪代码执行过程才能排除
   - **设计原则**：错误选项应基于真实的学生易错点设计，而非随意编造
8. **Quick Reference**：只能使用 Quick Reference 中列出的方法
9. **避免 charAt**：`charAt()` 不在 Quick Reference 中，题目应使用 `substring(i, i+1)` 替代
10. **Git 安全网 + 文件写入安全**：本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行 `write`/`edit` 前必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。同时：使用 `write` 前必须用 `glob` 或 `read` 确认目标文件是否已存在；若文件已存在，优先用 `edit` 追加内容，而非直接 `write` 覆写；确需覆写须先告知用户。
