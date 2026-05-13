---
name: mistake-practice-generation
version: 1.0.0
description: 不限科目，阅读目录下的错题积累和题目文件，生成打乱顺序、修改数据后的全英文LaTeX选择题练习卷
triggers:
  - "错题重排"
  - "生成错题卷"
  - "生成练习卷"
  - "mistake practice"
  - "错题积累"
inputs:
  - name: target_dir
    description: 错题文件所在目录（默认为当前工作目录）
    required: false
  - name: output_name
    description: 输出文件名前缀（不含扩展名）
    required: false
    default: Mistake_Practice
  - name: question_count
    description: 目标题目数量（0=自动根据文件数量决定）
    required: false
    default: 0
tools:
  - write
  - bash
  - read
  - glob
  - grep
  - edit
  - task
  - todowrite
---

# 错题练习卷生成 (Mistake Practice Generation)

## 核心理念

将任意科目的错题积累文件和题目文件，自动转化为一份选择题练习卷：

- 读取目录下所有 markdown 文件
- 将概念性「易错点」转化为选择题
- 从已有题目中提取并改造为选择题
- 打乱题目顺序、修改数据避免机械记忆
- 输出全英文 LaTeX 双栏紧凑排版
- 自动编译为 PDF 并验证

## 完整工作流程

### 阶段 0：分析目录结构

```
1. 列出目标目录下所有 .md 文件
2. 区分三类文件：
   - 错题总结（文件名含「易错」「错题」等关键词，或内容为概念列表）
   - 题目文件（文件名含 Problems、题目 等，内容为编号题目）
   - 理论/概念文件（纯知识点讲解，无具体题目）
3. 统计各文件的题目数量和主题分布
```

### 阶段 1：提取与转化题目

#### 从错题总结转化

每个「易错点」条目转化为一道选择题：

1. **读懂易错点**：理解该知识点对应的常见误解
2. **设计题目**：构造一个具体的物理/数学场景来测试该知识点
3. **设计选项**：
   - 1 个正确选项
   - 3 个干扰项，每个对应一种常见的错误理解
   - 干扰项必须有迷惑性，不能明显错误
4. **修改数据**：将原数据乘以 1.5-3 倍随机因子

#### 从已有题目提取

1. 阅读题目文本和相关图片描述
2. 将题目转化为自包含的选择题（不依赖外部图片）
3. 用文本描述替代图片场景
4. 修改所有数值数据（质量、速度、角度、距离等）
5. 生成 4 个选项 (A-D)

### 阶段 2：打乱与编排

1. **打乱顺序**：将所有题目随机排列，避免同一主题连续出现
2. **答案均衡**：重新排列选项使正确答案分布大致均匀（A-D 各约 25%）
3. **题目自包含**：确保每题文本完整可独立作答

### 阶段 3：LaTeX 文档生成

#### 文档模板

```latex
\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{geometry}
\geometry{margin=0.35in}
\usepackage{multicol}
\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}

\begin{document}

\textbf{\Large [Subject] --- Mistake Collection Practice} \hfill \textit{N Questions}

\vspace{0.3cm}

\begin{multicols}{2}
\begin{enumerate}[label=\textbf{\arabic*.}]

% Qn: [Topic] (source)
\begin{question}
\item [题目文本]
\begin{enumerate}[label=(\Alph*)]
    \item 选项 A
    \item 选项 B
    \item 选项 C
    \item 选项 D
\end{enumerate}
\end{question}

...

\end{enumerate}

\vspace{0.3cm}
\noindent\textbf{Answer Key}

\begin{center}
\begin{tabular}{|c|c||c|c||c|c|}
\hline
\# & Answer & \# & Answer & \# & Answer \\
\hline
1  & A & 19 & C & 37 & D \\
\hline
...
\end{tabular}
\end{center}

\end{multicols}
\end{document}
```

#### 排版要点

| 参数 | 值 | 说明 |
|------|-----|------|
| 字号 | 10pt | 紧凑排版 |
| 页边距 | 0.35in | 最大化空间 |
| 布局 | 双栏 (multicols) | 减少页数 |
| 答案表 | 三列格式 | 紧凑显示 |
| 选项间距 | nosep | 去除多余空白 |
| 页码 | 无 | 节省空间 |

### 阶段 4：编译与验证

#### 编译

```bash
tectonic [output_name].tex
```

#### 验证（委托 subagent）

编译成功后，必须启动验证 agent 检查：

```
1. 物理/数学正确性：逐一核对所有题目的答案
2. 答案表完整性：确认每个题号都有对应答案
3. 干扰项质量：确认每个错误选项都有迷惑性
4. LaTeX 语法：确认无编译错误
5. 答案分布：确认 A-D 大致均衡
```

### 阶段 5：修复与迭代

1. 根据验证结果修复错误
2. 重新编译验证
3. 重复直至所有检查通过

---

## 题目设计原则

### 选择题设计

| 原则 | 要求 |
|------|------|
| 选项数 | 4 个 (A-D) |
| 正确性 | 每题只有一个明确正确的答案 |
| 迷惑性 | 每个错误选项对应一种常见误解 |
| 数据修改 | 所有数值乘以 1.5-3x 因子 |
| 自包含 | 题目文本完整描述场景，不依赖外部图片 |
| 语言 | 全英文 |

### 干扰项设计

每个错误选项必须有明确的「错误来源」：

```
示例：牛顿第三定律题目
A: 对同一物体的两个力（平衡力误解）→ 常见错误：混淆平衡力与反作用力
B: 两个重力（同类型但非配对）→ 常见错误：认为只要是同类型力就是配对
C: [正确答案] → 不同物体、同类型、等大反向
D: 重力与压力的组合 → 常见错误：认为所有数值相等的力都是配对
```

### 数据修改规范

| 数据类型 | 修改范围 | 示例 |
|----------|----------|------|
| 质量 | 1.5-3x | 2kg → 5kg |
| 速度 | 1.5-2x | 3m/s → 7m/s |
| 角度 | ±15°-30° | 30° → 45° |
| 距离/高度 | 1.5-3x | 10m → 25m |
| 力 | 1.5-3x | 100N → 250N |

### 答案分布

- 目标：A≈B≈C≈D（各约 25%）
- 通过重新排列各题选项实现
- 同时确保每个选项位置的错误答案也有合理迷惑性

---

## 执行要点

### 必须做

1. 阅读目录下**所有** .md 文件
2. 错题总结中的**每一个**条目都转化为题目
3. 所有数值数据必须修改
4. 题目**彻底打乱**（不连续出现同主题）
5. 编译后**必须验证**
6. 输出全英文

### 禁止做

1. 不要在题目文本中保留中文
2. 不要跳过任何错题条目
3. 不要使用「以上皆是/以上皆非」
4. 不要创作「明显可排除」的干扰项
5. 不要忽略图片——用文本描述替代
6. 不要保留原始数据值
7. **Git 安全网 + 不要盲目覆写文件**：本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行 `write`/`edit` 前必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。同时：使用 `write` 前必须先用 `glob` 或 `read` 确认目标 `.tex` 文件是否已存在；若文件已存在，用 `edit` 追加而非 `write` 覆写；确需覆写须先告知用户。

---

## 文件命名规范

```
[Subject]_Mistake_Practice.tex   → LaTeX 源码
[Subject]_Mistake_Practice.pdf   → 编译输出
```

示例：
- `AP1_Mistake_Practice.tex`
- `Calculus_BC_Mistake_Practice.tex`
- `Chemistry_Mistake_Practice.tex`

---

## 目录结构预期

```
[Subject-Directory]/
├── [Subject] 易错点总结.md          ← 错题总结（核心输入）
├── [Topic 1] Problems.md            ← 题目文件
├── [Topic 2] Problems.md
├── ... (更多题目文件)
├── [Theory] - Complete Review.md    ← 理论文件（可选参考）
└── [output]_Mistake_Practice.tex    ← 输出
```

---

## 输出检查清单

生成试卷后必须确认：

- [ ] 所有错题条目均已转化为题目
- [ ] 所有题目数据已修改
- [ ] 题目顺序随机，无连续同主题
- [ ] 每题 4 个选项 (A-D)
- [ ] 答案表完整且正确（答案数与题目数一致）
- [ ] 答案分布大致均衡 (A-D 各 18-22)
- [ ] 全英文，无中文在题目/选项中
- [ ] LaTeX 语法正确，tectonic 编译成功
- [ ] PDF 输出正常
- [ ] 干扰项有明确错误来源
