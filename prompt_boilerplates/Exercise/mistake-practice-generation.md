---
name: mistake-practice-generation
version: 1.1.0
description: 不限科目，支持诊断驱动生成与目录扫描双模式。从错题诊断（trap type + difficulty）或错题文件直接生成全英文 LaTeX 选择题练习卷。SAT 模式支持 CB 官方拟真格式（Question ID + Assessment 头 + Rationale 逐项解析）。内置语义甄别专项模式、难度递进设计、答案分布均衡算法、系列化增量生成。
triggers:
  - "错题重排"
  - "生成错题卷"
  - "生成练习卷"
  - "生成SAT练习卷"
  - "同类错题练习"
  - "mistake practice"
  - "错题积累"
  - "诊断出题"
  - "陷阱练习"
inputs:
  - name: target_dir
    description: 错题文件所在目录（默认为当前工作目录）。diagnostic_specs 提供时忽略。
    required: false
  - name: output_name
    description: 输出文件名前缀（不含扩展名、不含 _Practice_N 后缀）
    required: false
    default: Mistake_Practice
  - name: question_count
    description: 目标题目数量（0=自动根据文件数量决定）
    required: false
    default: 0
  - name: diagnostic_specs
    description: 诊断规格对象。{ trap_families: [{family, difficulty?, count?}], format: "sat"|"generic" }。提供时跳过目录扫描，直接进入陷阱→题目设计。trap_family 可选值含 "semantic-discrimination" "subject-verb-agreement" "modifier-placement" "transitions" "boundaries" "form-structure-sense" 等。
    required: false
  - name: format
    description: 输出格式（"generic" 或 "sat"）。sat 模式使用 CB 官方拟真格式。
    required: false
    default: "generic"
  - name: series
    description: 系列生成参数。{ set_number: 1, continue_from: null }。continue_from 为前一册的 Practice_N 编号，新册自动递增。
    required: false
tools:
  - write
  - bash
  - read
  - grep
  - edit
  - subagent
  - todo_create
---

# 错题练习卷生成 (Mistake Practice Generation) v1.1.0

## 核心理念

将学生错题诊断或错题积累文件转化为高质量选择题练习卷。v1.1.0 支持两种入口模式：

- **诊断驱动模式**：用户口头/文本指定错因诊断（陷阱类型 + 难度）→ 直接出题。不依赖任何已有文件。
- **目录扫描模式（v1.0.0 兼容）**：读取目录下 markdown 错题文件 → 提取改造 → 输出练习卷。

输出格式支持：
- **SAT 拟真模式**：hex Question ID、Assessment 头行、CB 规范提问句式、答案文件含官方 Rationale 风格逐项解析、难度标注。
- **通用模式**：双栏紧凑排版，适合数理化等非 SAT 科目。

试卷与答案**强制二分**为两个独立文件：`[Name]_Practice_N.tex`（纯题目）和 `[Name]_Practice_N_Answers.tex`（正确答案 + 逐项解析）。

## 入口路由

```
用户请求
  ├── diagnostic_specs 已提供？
  │     ├── YES → 诊断驱动生成模式（跳过目录扫描，直接进入 §陷阱→题目设计方法论）
  │     └── NO  → 目录扫描模式（§完整工作流程 阶段 0-5）
  └── format 参数
        ├── "sat"   → SAT 拟真格式（§SAT 拟真格式规范）
        └── "generic" → 通用双栏格式（§通用格式规范）
```

---

## 诊断驱动生成模式

### 输入规格

```yaml
diagnostic_specs:
  trap_families:
    - family: "semantic-discrimination"   # 陷阱家族标识
      difficulty: "hard"                   # Easy | Medium | Hard
      count: 4                            # 该家族生成题数
    - family: "modifier-placement"
      difficulty: "medium"
      count: 3
    - family: "subject-verb-agreement"
      difficulty: "easy"
      count: 3
  format: "sat"
  total_questions: 10                     # 也可由 count 之和自动决定
```

### 处理流程

1. **解析 diagnostic_specs**：提取陷阱家族列表、每家族题数、难度分布
2. **陷阱→题目设计**（见下文 §陷阱→题目设计方法论）：对每个家族 × 难度组合，按 6 步方法论生成题目
3. **答案分布均衡**（见 §答案分布均衡算法）：设计所有正确选项后重排字母分布
4. **LaTeX 输出**：按 format 参数选择模板
5. **编译验证**：tectonic 编译双文件 → subagent 验证 → 修复迭代

### 陷阱家族标识符

| 标识符 | 说明 | 适用科目 |
|--------|------|----------|
| `semantic-discrimination` | 语义甄别（见专项章节） | SAT R&W |
| `modifier-placement` | 修饰语位置 / 悬垂修饰语 | SAT R&W |
| `subject-verb-agreement` | 主谓一致（含倒装、复合主语） | SAT R&W |
| `transitions` | 逻辑过渡词选择 | SAT R&W |
| `boundaries` | 句子边界 / 标点 | SAT R&W |
| `form-structure-sense` | 形式·结构·语义综合 | SAT R&W |
| `words-in-context` | 语境词汇 | SAT R&W |
| `cross-text-connections` | 跨文本关联 | SAT R&W |
| `textual-evidence` | 文本证据（Command of Evidence） | SAT R&W |
| `central-ideas` | 中心思想与细节 | SAT R&W |
| `rhetorical-synthesis` | 修辞综合（笔记题） | SAT R&W |
| `inferences` | 推理题 | SAT R&W |
| `newton-laws` | 牛顿定律应用 | Physics |
| `energy-conservation` | 能量守恒 | Physics |
| `circular-motion` | 圆周运动 / 向心力 | Physics |
| *(任意自定义标识符)* | 可扩展 | 任意 |

---

## 陷阱→题目设计方法论

对所有模式（诊断驱动 + 目录扫描中从错题转化）的核心题目设计流程：

### 六步法

```
Step 1: 识别陷阱子类型
    ↓
Step 2: 选取新主题替换（保留陷阱结构）
    ↓
Step 3: 设计正确选项
    ↓
Step 4: 设计 3 个干扰项（每个对应一个不同的错误子类型）
    ↓
Step 5: 重排选项平衡字母分布
    ↓
Step 6: 撰写 CB 风格 Rationale（SAT 模式）或简洁解析（通用模式）
```

### Step 1: 识别陷阱子类型

每个陷阱家族内部有多个子类型。以 `modifier-placement` 为例：

| 子类型 | 描述 | 例题特征 |
|--------|------|----------|
| `dangling-appositive` | 同位语悬垂 — 修饰语描述 X 但紧跟的是 Y | "A prolific writer, X's novels..."（应为 "the novelist"） |
| `dangling-participle` | 分词悬垂 — 分词短语的逻辑主语不匹配 | "Walking through the park, the statue was..."（应为 "I saw"） |
| `there-expletive` | there be 句型中修饰语误指 there | "Designed in 1920, there is a bridge..."（应为 "the bridge"） |
| `entity-misattribution` | 属性/作品归因错误 — 人 vs 作品 vs 来源 | "Based on diaries, the memoir..." → "the author wrote" |

### Step 2: 选取新主题替换

**理科**：数据 ×1.5–3x，保持物理/数学合理性。

**文科/SAT 语法等效原则**：保留陷阱结构，替换主题/名称/上下文。干扰项的错误类型保持完全一致。

```
原题: "A botanist's meticulous study, the field guide became..."
替换: "An archaeologist's meticulous study, the excavation report became..."
      ── 陷阱结构不变（同位语修饰人vs作品），主题从植物学→考古学
```

常用替换映射：
- 职业：botanist → archaeologist, chemist → physicist, historian → sociologist
- 作品：memoir → chronicle, novel → manuscript, study → survey
- 场景：heatstroke → hypothermia, desert → tundra, marina → observatory
- 名称：随机生成，确保不重复使用原题名称

### Step 3: 设计正确选项

正确选项必须：
- 唯一正确（答案唯一性）
- 语法完美（SAT 模式：符合 Standard English conventions）
- 语义通顺（填入后句子读起来自然）
- 非 SVA 捷径可排除（在 modifier-placement 题中，所有选项的主谓一致都应正确，避免学生仅凭单复数排除）

### Step 4: 设计三个干扰项

每个干扰项对应一个**不同的错误子类型**，且都有迷惑性：

| 干扰项 | 必须条件 |
|--------|----------|
| Distractor 1 | 对应错误子类型 A（如 there 引入悬垂修饰） |
| Distractor 2 | 对应错误子类型 B（如错误实体归因——人写成作品） |
| Distractor 3 | 对应错误子类型 C（如语法成立但语义指错对象） |

**禁止的干扰项类型**：
- 仅靠主谓一致（单复数）就能排除的选项
- 语义荒谬到不可能被选中的选项
- 与题干上下文明显矛盾的选项

**在语义甄别模式下**：刻意**不包含** there is/are 选项（因为学生已能过 there-trap）。所有干扰项必须是"语法成立、语义通顺、但修饰语不描述它"的其他实体。

### Step 5: 重排选项平衡字母分布

见 §答案分布均衡算法。

### Step 6: 撰写 Rationale（SAT 模式）

```
Choice X is the best answer. The convention being tested is [trap family].
This choice [解释为什么正确——语法结构 + 语义逻辑].

Choice A is incorrect because [具体的错误原因，对应子类型 A].
Choice B is incorrect because [具体的错误原因，对应子类型 B].
Choice C is incorrect because [具体的错误原因，对应子类型 C].
Choice D is incorrect because [具体的错误原因，对应子类型 D].
```

---

## 语义甄别专项模式 (Semantic Discrimination)

### 背景

**核心诊断发现**：学生能过 `there is/are` 陷阱（通过机械化规则识别），但不会 **entity-discrimination**——即区分修饰语究竟修饰句子中的哪一个实体。there-trap 只是 entity-discrimination 的一个子集。真正的能力是：读完一个长修饰语后，能甄别它所描述的是句子中出现的哪个人/物/概念。

### 模式激活

当 `diagnostic_specs.trap_families[].family = "semantic-discrimination"` 时自动激活。

### 设计约束

1. **所有干扰项必须是"语法成立、语义通顺、但修饰语不描述它"的其他实体**
2. **刻意不包含 there is/are 选项**（学生已过 this trap，there 变成机械化排除信号而非思考）
3. 每个干扰项对应的实体必须在上下文中出现或可合理推断

### 四种核心甄别维度

| 维度 | 说明 | 例题模式 |
|------|------|----------|
| **人 vs 作品** | 修饰语描述人还是他/她的作品 | "A meticulous observer of migratory patterns, ____" → the biologist ✓ / the biologist's field notes ✗ |
| **来源材料 vs 作品** | 修饰语描述原始素材还是基于素材的创作 | "Based on previously unpublished letters, ____" → the biography ✓ / the letters' author ✗ |
| **整体 vs 部分** | 修饰语描述整体概念还是其中一部分 | "Known for its vibrant colors and intricate patterns, ____" → the tapestry ✓ / the dye used in the tapestry ✗ |
| **代词逻辑反证** | 修饰语中的代词（its/their/his）指向必须与主语匹配 | "With its distinctive striped coat, ____" → the tiger ✓ / the jungle ✗（jungle 无 striped coat） |

### 设计原则

```
题干构造：
  [长修饰语, 含 its/his/their 指代词], [主语候选位置] [谓语...].

干扰项设计（必须全部语法正确）：
  A: there is/are ... ← 不包含！学生已能排除
  B: 描述实体 X 但有修饰语指代错配（整体vs部分）
  C: 描述实体 Y 但修饰语实际描述 X 的作品/产出（人vs作品）
  D: 描述实体 Z 但代词逻辑矛盾（代词逻辑反证）
  E: 正确选项——修饰语所描述的正确实体

由于只有 A-D 四个选项，there 选项被排除后，B/C/D 中选三个维度呈现。
```

### 示例：semantic-discrimination 题目

```
题干上下文:
  The correspondence between the two composers spanned nearly four decades.
  [修饰语] ________________, was published in its entirety only last year.

修饰语:
  A treasure trove of musical insight and personal reflection, painstakingly
  assembled from archives in three countries,

正确选项 (C):
  the collection of letters

干扰项:
  A: the two composers' friendship           ← 维度：来源材料 vs 作品
     （修饰语指 assembled from archives → 是书信集，不是友情本身）
  B: the archives' curator                      ← 维度：人 vs 作品
     （修饰语描述的是书信集的内容特征，不是策展人）
  D: the task of assembling the letters     ← 维度：整体 vs 部分
     （修饰语描述的是书信集的属性，不是汇编这个动作）
```

---

## 难度递进设计原则

同一陷阱家族内的题目必须按难度递进排列，从浅入深：

### 递进路径

```
Easy → Medium → Hard

Easy:   短修饰语 + 明显错误主语（学生能直观感知）
        修饰语 ≤ 8 词，错误选项与正确选项语义差异大
        示例: "Walking down the street, the car passed by." → 仅需基础语法意识

Medium: 长修饰语 + 双修饰语嵌套
        修饰语 10-20 词，可能含两个子修饰语
        示例: "Designed by a team of engineers in Zurich and tested in extreme
               conditions, the device..." → 需在长句中保持语法意识

Hard:   代词逻辑反证 / 隐藏主语
        修饰语含代词（its/his/their），需结合语义推敲而非机械化语法规则
        或主语被大量插入成分遮蔽
        示例: "With its distinctive approach to narrative structure and its
               unflinching portrayal of rural poverty, the novel..." → 需甄别
               its 指代 novel 而非 author/rural poverty
```

### LaTeX 标注

每题在题目头行和答案文件中均标注难度：

**题目文件**：
```latex
\section*{Question ID a1b2c3d4}
\noindent\textit{Assessment: SAT \quad Test: Reading and Writing \quad
Domain: Standard English Conventions \quad Skill: Form, Structure, and Sense \quad
Difficulty: Easy}
```

**答案文件**（每题 Rationale 末尾）：
```latex
\textit{Question Difficulty: Easy}
```

### 套卷内难度分布

总题数 N 的推荐分布：

| 题数 | Easy | Medium | Hard |
|------|------|--------|------|
| 10   | 3    | 4      | 3    |
| 12   | 3    | 5      | 4    |
| 15   | 4    | 6      | 5    |

同一陷阱家族的题目从 Easy 到 Hard 连续排列（便于学生感知递进），不同家族之间再随机打乱。

---

## 答案分布均衡算法

替换 v1.0.0 的"各约 25%"为可操作方法：

### 算法

```
输入: N 道题目的正确选项内容（内容已确定）
输出: 每题选项的字母排列，使 A/B/C/D 分布均衡

Step 1: 先设计所有题目的正确选项内容（不改动）
Step 2: 统计：当前若全放在 A，分布为 N/0/0/0
Step 3: 对于每道题，选择目标字母 target：
        - 计算当前 A/B/C/D 计数
        - target = 计数最小的字母
        - 若平局，选本轮尚未用过的字母
Step 4: 将该题的正确选项内容放到 target 位置
        - 其余 3 个干扰项随机填入剩余 3 个字母位置
Step 5: 重复 Step 3-4 直至所有题分配完毕
Step 6: 微调：检查是否有连续 3 题以上相同字母，若有一一两两互换
```

### 目标分布

| 总题数 N | 理想分布 | 允许范围 |
|----------|----------|----------|
| 8        | 2/2/2/2  | ±1 |
| 10       | 3/3/2/2  | ±1 |
| 12       | 3/3/3/3  | ±1 |
| 15       | 4/4/4/3  | ±1 |
| 16       | 4/4/4/4  | ±1 |

### 示例（12 题）

```
初始分配（内容已定，仅排位置）:
  Q1  → C (语义甄别-正确实体)
  Q2  → A (主谓一致-was)
  Q3  → B (修饰语位置-novel)
  Q4  → D (修饰语位置-travelers)
  Q5  → A (主谓一致-has been)
  Q6  → C (语义甄别-collection)
  Q7  → B (修饰语位置-memoir)
  Q8  → D (修饰语位置-film)
  Q9  → A (主谓一致-has endorsed)
  Q10 → C (语义甄别-field notes)
  Q11 → D (修饰语位置-Éamon)
  Q12 → B (主谓一致-are studying)

结果: A=3, B=3, C=3, D=3 ✓
```

---

## 完整工作流程（目录扫描模式）

当 `diagnostic_specs` 未提供时使用此模式。

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

1. **识别陷阱类型**：将每个易错点归类到陷阱家族（见 §诊断驱动生成模式 陷阱家族标识符）
2. **应用陷阱→题目设计方法论**：按六步法生成题目（见 §陷阱→题目设计方法论）
3. **数据修改**：
   - 理科：数据 ×1.5–3x 随机因子
   - 文科/SAT 语法：保留陷阱结构，替换主题/名称/上下文（见 §数据修改规范）

#### 从已有题目提取

1. 阅读题目文本和相关图片描述
2. 将题目转化为自包含的选择题（不依赖外部图片）
3. 用文本描述替代图片场景
4. 修改所有数值数据（见 §数据修改规范）
5. 生成 4 个选项 (A-D)，按干扰项设计原则构造

### 阶段 2：打乱与编排

1. **陷阱家族内排序**：同一家族的题目按难度递进排列（Easy → Medium → Hard）
2. **家族间打乱**：不同家族随机排列，避免同一家族连续出现超过 3 题
3. **答案分布均衡**：应用 §答案分布均衡算法

### 阶段 3：LaTeX 文档生成

根据 `format` 参数选择模板：

- `"sat"` → §SAT 拟真格式规范
- `"generic"` → §通用格式规范

两种模式均输出**两个独立文件**：题目文件和答案文件。

### 阶段 4：编译与验证

见 §验证体系。

### 阶段 5：修复与迭代

1. 根据验证结果修复错误
2. 重新编译验证
3. 重复直至所有检查通过

---

## SAT 拟真格式规范

### 题目文件模板

```latex
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[margin=0.9in]{geometry}
\usepackage{parskip}
\usepackage{enumitem}
\usepackage{titlesec}
\usepackage{amsmath,amssymb}
\emergencystretch=0.5em
\setlength{\parskip}{0.5em}
\titleformat{\section}{\normalfont\large\bfseries}{}{0em}{}

\begin{document}

\begin{center}
{\LARGE\bfseries SAT Reading and Writing}\\[0.3em]
{\large [Skill Area] --- [Set Label]}\\[0.5em]
{\normalsize N Questions \quad$|$\quad [Domain Name]}
\end{center}

\vspace{0.6em}
\noindent\rule{\textwidth}{0.4pt}

\section*{Question ID [8-char hex]}
\noindent\textit{Assessment: SAT \quad Test: Reading and Writing \quad
Domain: [Craft and Structure | Standard English Conventions | Information and Ideas | Expression of Ideas] \quad
Skill: [Skill Name] \quad Difficulty: [Easy | Medium | Hard]}

[上下文段落 1-3 句]

[含空白句子] \rule{2.6cm}{0.4pt} [句子后半部分]

\noindent\textit{[Which choice completes the text so that it conforms to the
conventions of Standard English? |
Which choice completes the text with the most logical transition? |
Which choice most logically completes the text? |
Which choice best states the main idea of the text? |
Which choice completes the text with the most logical and precise word or phrase? |
Based on the texts, how would the author of Text 2 most likely respond to
the claim in Text 1? |
Which choice most effectively uses data from the table to complete the statement? |
...]}

\begin{enumerate}[label=\Alph*),leftmargin=2em,itemsep=0.15em]
\item [选项 A 文本]
\item [选项 B 文本]
\item [选项 C 文本]
\item [选项 D 文本]
\end{enumerate}

% ... 重复 N 题 ...

\end{document}
```

### 答案文件模板

```latex
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[margin=0.9in]{geometry}
\usepackage{parskip}
\usepackage{enumitem}
\usepackage{titlesec}
\usepackage{amsmath,amssymb}
\emergencystretch=0.5em
\setlength{\parskip}{0.5em}
\titleformat{\section}{\normalfont\large\bfseries}{}{0em}{}

\begin{document}

\begin{center}
{\LARGE\bfseries SAT Reading and Writing}\\[0.3em]
{\large [Skill Area] --- [Set Label]}\\[0.3em]
{\normalsize Answer Key and Explanations}
\end{center}

\vspace{0.6em}
\noindent\rule{\textwidth}{0.4pt}

\section*{Question ID [8-char hex]}
\textbf{Correct Answer: [A-D]}

\textbf{Rationale}
Choice [X] is the best answer. The convention being tested is [trap family].
[This choice 解释为什么正确——语法结构 + 修改后的上下文如何被正确选项补全].

Choice A is incorrect because [具体错误原因，对应干扰项子类型].
Choice B is incorrect because [具体错误原因，对应干扰项子类型].
Choice C is incorrect because [具体错误原因，对应干扰项子类型].
Choice D is incorrect because [具体错误原因，对应干扰项子类型].

\textit{Question Difficulty: [Easy | Medium | Hard]}

% ... 重复 N 题 ...

\end{document}
```

### SAT 规范提问句式速查

| Domain / Skill | 提问句式 |
|----------------|----------|
| SEC / Form, Structure, and Sense | Which choice completes the text so that it conforms to the conventions of Standard English? |
| C&E / Transitions | Which choice completes the text with the most logical transition? |
| C&E / Words in Context | Which choice completes the text with the most logical and precise word or phrase? |
| C&E / Text Structure and Purpose | Which choice best describes the overall structure of the text? |
| C&E / Cross-Text Connections | Based on the texts, how would the author of Text 2 most likely respond to the claim in Text 1? |
| I&I / Central Ideas and Details | Which choice best states the main idea of the text? |
| I&I / Command of Evidence: Textual | Which quotation from the text most effectively illustrates the claim? |
| I&I / Command of Evidence: Quantitative | Which choice most effectively uses data from the table to complete the statement? |
| I&I / Inferences | Which choice most logically completes the text? |
| EoI / Rhetorical Synthesis | Which choice most effectively uses relevant information from the notes to accomplish the goal? |
| EoI / Transitions | Which choice completes the text with the most logical transition? |

### SAT Rationale 写作风格

```
Choice X is the best answer. The convention being tested is [trap family].
[This choice + 正面解释 + 上下文如何被正确补全].

Choice A is incorrect because [用 the placement/sentence structure/verb form
results in... 的句式描述错误].
Choice B is incorrect because [同上].
Choice C is incorrect because [同上].
Choice D is incorrect because [同上].
```

关键风格要素：
- 用 "The convention being tested is..." 开篇
- 每个错误选项用完整的因果句：先描述句式特征 → 再解释为什么不合理
- 用 "illogically suggests that..." / "does not agree in number with..." / "results in a dangling modifier" 等 CB 常用术语

---

## 通用格式规范

用于非 SAT 科目（数理化等）的紧凑双栏排版。

### 题目文件模板

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

\textbf{\Large [Subject] --- [Set Label]} \hfill \textit{N Questions}

\vspace{0.3cm}

\begin{multicols}{2}
\begin{enumerate}[label=\textbf{\arabic*.}]

% Q1: [Topic] (source) [Difficulty: Easy/Medium/Hard]
\item [题目文本]
\begin{enumerate}[label=(\Alph*)]
    \item 选项 A
    \item 选项 B
    \item 选项 C
    \item 选项 D
\end{enumerate}

% ... 重复 N 题 ...

\end{enumerate}
\end{multicols}
\end{document}
```

### 答案文件模板

```latex
\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{geometry}
\geometry{margin=0.75in}
\usepackage{multicol}
\usepackage{parskip}
\setlength{\parskip}{0.3em}

\begin{document}

\textbf{\Large [Subject] --- Answer Key and Explanations}

\vspace{0.3cm}

\section*{Quick Answer Key}
\begin{center}
\begin{tabular}{|c|c||c|c||c|c|}
\hline
\# & Answer & \# & Answer & \# & Answer \\
\hline
1  & A & 6  & C & 11 & D \\
\hline
2  & B & 7  & B & 12 & A \\
\hline
... & ... & ... & ... & ... & ... \\
\hline
\end{tabular}
\end{center}

\vspace{0.5cm}

\section*{Detailed Explanations}

\textbf{Q1. [Correct Answer: A]} \quad Difficulty: Easy

[解析：为什么正确 + 为什么每个错误选项不对 + 对应的误解来源]

\vspace{0.3cm}

% ... 重复 N 题 ...

\end{document}
```

---

## 验证体系

### 必须委托 subagent 验证

验证必须委托 subagent（momus 或 oracle），**不得由生成 agent 自行验证**。

### 逐题验证清单

| # | 检查项 | 方法 |
|---|--------|------|
| 1 | **答案唯一性** | "这个选项会不会有第二个正确答案？" 逐题排除。检查边缘案例：两个选项是否在特定解读下都成立？ |
| 2 | **干扰项质量** | 每个错误选项是否对应**真实的常见 SAT 错误模式**？禁止仅靠 SVA 捷径可排除的干扰项。检查：学生能否不读题干仅凭主谓一致排除 2+ 个选项？ |
| 3 | **数据表 / 数值一致性** | 如有表格或数据引用，逐格核对数值与题干一致性。 |
| 4 | **拟真度（SAT 模式）** | CB 格式 fidelity：Question ID 格式、Assessment 头行字段完整、提问句式匹配 Domain/Skill、Rationale 风格符合官方模式。 |
| 5 | **答案分布** | A/B/C/D 计数是否满足目标分布（见 §答案分布均衡算法）。 |
| 6 | **难度递进** | 同家族内是否 Easy→Medium→Hard 递进？难度标注是否与题目实际难度匹配？ |
| 7 | **语法正确性** | 每题所有选项是否自身语法正确（SAT 模式）？干扰项不应因拼写/基本语法错误而被排除。 |
| 8 | **编译完整性** | 两个 .tex 文件是否分别通过 tectonic 编译？无 overfull hbox 警告（或只有偶发微小溢出）。 |

### 验证流程

```
1. tectonic [Name]_Practice_N.tex && tectonic [Name]_Practice_N_Answers.tex
2. 若编译失败 → 修复 LaTeX 语法 → 重新编译
3. 编译成功后，启动验证 subagent：
   subagent({ name: "momus", message: "验证练习卷 [path] 的 8 项指标..." })
4. 根据验证结果修复问题
5. 重新编译 + 重新验证（如有修改）
6. 所有 8 项通过 → 完成
```

### 双 Agent 审查（可选增强）

对于高价值产出（如正式使用的练习卷、评估用途的试卷），推荐使用双 agent 并行审查：

```
subagent({ tasks: [
  { name: "momus",   message: "准确性审查：[path] — 逐题验证答案唯一性、干扰项质量、数据一致性、拟真度" },
  { name: "ultrabrain", message: "完整性审查：[path] — 验证难度递进、答案分布均衡、陷阱覆盖度、Rationale 完整性、系列一致性" }
]})

→ 合成两份审查报告 → 逐条修复 → 重新编译 → 单 agent 最终验证
```

---

## 系列化增量生成

### 命名约定

```
[Topic]/set1/
├── [Skill]_Practice_1.tex
├── [Skill]_Practice_1_Answers.tex
├── [Skill]_Practice_2.tex
├── [Skill]_Practice_2_Answers.tex
├── [Skill]_Practice_3.tex
└── [Skill]_Practice_3_Answers.tex

[Topic]/set2/
├── [Skill]_Practice_1.tex
├── [Skill]_Practice_1_Answers.tex
├── ...
```

- `set1/` `set2/` 对应不同生成批次
- 同一 set 内 `Practice_1` → `Practice_2` → `Practice_3` 依次递增
- 同题材（相同 Skill / 相同陷阱家族）应放在同一目录
- 不同题材用不同目录

### Git 追踪

```
每次生成新套卷时：
1. 检查目标目录是否已有 git repo
   if ! git rev-parse --git-dir 2>/dev/null; then
     git init && git add -A && git commit -m "Initialize practice set"
   fi
2. 生成新文件后：
   git add [new_files]
   git commit -m "Add [Skill]_Practice_N — [N] questions, [difficulty distribution]"
3. 系列完成时：
   git tag -a "set1-v1" -m "Set 1 complete: [summary]"
```

### 系列参数

```yaml
series:
  set_number: 1          # 第几套
  continue_from: 3       # 可选：已有 Practice_1~3，新册从 Practice_4 开始
  git_init: true         # 是否自动初始化 git（默认 true）
```

---

## 题目设计原则（通用）

### 选择题设计

| 原则 | 要求 |
|------|------|
| 选项数 | 4 个 (A-D) |
| 正确性 | 每题只有一个明确正确的答案 |
| 迷惑性 | 每个错误选项对应一种常见误解 |
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

---

## 数据修改规范

### 理科（物理、化学、数学等）

| 数据类型 | 修改范围 | 示例 |
|----------|----------|------|
| 质量 | 1.5–3x | 2kg → 5kg |
| 速度 | 1.5–2x | 3m/s → 7m/s |
| 角度 | ±15°–30° | 30° → 45° |
| 距离/高度 | 1.5–3x | 10m → 25m |
| 力 | 1.5–3x | 100N → 250N |

### 文科 / SAT 语法等效原则

**保留陷阱结构，替换主题/名称/上下文。干扰项的错误类型保持完全一致。**

| 替换层级 | 操作 | 示例 |
|----------|------|------|
| 职业/身份 | 替换为不同领域但结构相同的职业 | botanist → archaeologist, composer → playwright |
| 作品/产出 | 替换为同类型作品 | memoir → chronicle, symphony → concerto |
| 场景/环境 | 替换为保持修饰语结构的平行场景 | heatstroke → hypothermia, desert → tundra |
| 名称 | 随机生成新名称（不重复使用） | Mário → Éamon, Lisbon → Prague |
| 时间/地点 | 替换但不改变时态要求 | 1920s → 1950s, Zurich → Copenhagen |

**禁止**：
- 改变陷阱结构（如把修饰语题变成主谓一致题）
- 改变干扰项的错误类型分布
- 仅修改 1-2 个词使得题目与原文高度相似（避免机械记忆）

---

## 执行要点

### 必须做

1. **入口路由**：检查 diagnostic_specs → 选择模式
2. **试卷答案二分**：始终输出两个独立 .tex 文件（题目 + 答案）
3. **诊断驱动模式**：按 §陷阱→题目设计方法论 六步法逐题生成
4. **目录扫描模式**：阅读目录下**所有** .md 文件，错题总结中**每一个**条目都转化为题目
5. **数据修改**：理科 1.5–3x，文科保留陷阱替换主题（见 §数据修改规范）
6. **答案分布均衡**：应用 §答案分布均衡算法
7. **编译后必须委托 subagent 验证**（见 §验证体系）
8. **输出全英文**
9. **系列生成时初始化 git**（见 §系列化增量生成）

### 禁止做

1. 不要在题目文本中保留中文
2. 不要跳过任何错题条目（目录扫描模式）
3. 不要使用「以上皆是/以上皆非」
4. 不要创作「明显可排除」的干扰项
5. 不要忽略图片——用文本描述替代
6. 不要保留原始数据值
7. **不要自行验证**——验证必须委托 subagent
8. **禁止单文件输出**——题目和答案必须分离为两个文件

### 知识边界约束

本 skill 遵守 [知识边界规范](../knowledge_boundary.md)。涉及的科目可能超出模型训练数据的准确覆盖范围。

- **题目设计时**：对公式推导、定理应用、数值计算没有十足把握时，通过计算验证而非猜测硬答。
- **干扰项设计时**：每个错误选项必须有明确的常见误解来源，不能编造"看起来合理"但实际无依据的选项。
- **数据修改时**：如果修改后的数值导致题目失去物理/数学合理性，应调整而非执意输出。
- **SAT 语法题设计时**：必须符合 Standard English conventions（即 SAT 官方认可的美式英语语法规则）。不确定时查阅官方指南。

### Git 安全网 + 文件操作

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。

- 执行 `write`/`edit` 前必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令
- 使用 `write` 前必须先用 `read` 确认目标 `.tex` 文件是否已存在
- 若文件已存在，用 `edit` 追加而非 `write` 覆写；确需覆写须先告知用户
- **系列生成时**：自动 `git init`（如尚未初始化）并逐次 `git add` + `git commit`

### 全英文产出 + tectonic 编译

- 产出物（题目、选项、答案、解析、验证输出）一律全英文，禁止出现中文
- 编译仅用 tectonic（全英文内容无需 xelatex 等回退）
- 编译后清理中间文件（`.aux` `.bbl` `.blg` `.log` `.out` `.toc` `.synctex.gz` 等）

---

## 文件命名规范

```
标准格式:
[Subject/Skill]_Practice_N.tex          → 题目文件
[Subject/Skill]_Practice_N_Answers.tex  → 答案文件

SAT 格式示例:
FormStructureSense_Practice_1.tex       → 题目
FormStructureSense_Practice_1_Answers.tex → 答案

通用格式示例:
AP1_Mistake_Practice.tex                → 题目
AP1_Mistake_Practice_Answers.tex        → 答案
```

---

## 目录结构预期

```
[Project-Directory]/
├── set1/                                # 第一批生成
│   ├── [Skill]_Practice_1.tex
│   ├── [Skill]_Practice_1_Answers.tex
│   ├── [Skill]_Practice_2.tex
│   ├── [Skill]_Practice_2_Answers.tex
│   ├── [Skill]_Practice_3.tex
│   └── [Skill]_Practice_3_Answers.tex
├── set2/                                # 第二批生成（可选）
│   └── ...
│
── 或（目录扫描模式）──
│
├── [Subject] 易错点总结.md              ← 错题总结（核心输入）
├── [Topic 1] Problems.md                ← 题目文件
├── [Topic 2] Problems.md
├── [Theory] - Complete Review.md        ← 理论文件（可选参考）
├── [output]_Practice.tex                ← 题目输出
└── [output]_Practice_Answers.tex        ← 答案输出
```

---

## 输出检查清单

生成试卷后必须确认：

- [ ] **模式选择正确**：diagnostic_specs 提供 → 诊断驱动；否则 → 目录扫描
- [ ] **双文件输出**：题目文件和答案文件均已生成
- [ ] 所有错题条目/诊断陷阱均已转化为题目
- [ ] 所有题目数据已修改（理科 1.5–3x / 文科保留陷阱替换主题）
- [ ] 同家族题目按难度递进排列（Easy → Medium → Hard）
- [ ] 每题 4 个选项 (A-D)
- [ ] 每题难度标注正确（SAT 模式：题目头行 + 答案文件末尾）
- [ ] **干扰项质量**：每个错误选项对应真实常见错误模式，非 SVA 捷径可排除
- [ ] **答案分布均衡**：A/B/C/D 计数满足目标分布（±1 容忍）
- [ ] 答案文件包含逐题 Rationale（SAT 模式：CB 风格；通用模式：简洁解析）
- [ ] 全英文，无中文在题目/选项中
- [ ] LaTeX 语法正确，两个 .tex 文件分别 tectonic 编译成功
- [ ] **subagent 验证通过**（8 项逐题检查全部通过）
- [ ] 系列生成：git 已追踪、commit 信息完整
