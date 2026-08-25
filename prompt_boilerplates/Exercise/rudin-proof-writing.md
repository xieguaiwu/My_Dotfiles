---
name: rudin-proof-writing
version: 1.0.0
description: 面向 AP Calculus BC 与 AP Physics 1 满分高中生，用 Rudin《数学分析原理》训练本科级证明写作——S0-S5 脚手架分层（定义翻译/语句解析/骨架填充/策略引导/完整证明/批判变体）、AP 桥梁映射、Rudin 原题与定制题双轨、模型证明答案卷与评分准则
triggers:
  - "Rudin证明练习"
  - "PMA证明题"
  - "生成证明写作练习"
  - "数学证明训练"
  - "Rudin proof practice"
  - "生成PMA练习卷"
inputs:
  - name: chapter
    description: 章节号（1-11）
    required: true
  - name: tier
    description: '脚手架层级组合，逗号分隔（如 S0,S2,S4）'
    required: false
    default: "S0,S1,S2,S3,S4"
  - name: num_problems
    description: 题目总数（1-20）
    required: false
    default: 8
  - name: source
    description: '题目来源（rudin/custom/mixed）'
    required: false
    default: "mixed"
  - name: ap_bridge
    description: 是否启用 AP 桥梁注释（true/false）
    required: false
    default: true
  - name: output_dir
    description: 输出目录
    required: false
    default: ./
  - name: compile
    description: 是否用 tectonic 编译验证（true/false）
    required: false
    default: true
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
  - subagent
  - todo_create
  - ask_user
---

# Rudin 证明写作练习生成器

专为已获 AP Calculus BC 与 AP Physics 1 满分（5 分）的高中生设计，以 Rudin《数学分析原理》（第 3 版）为教材，训练本科级专业数学证明写作。本 skill 生成按章节组织的证明写作练习卷（LaTeX 双文件：题目卷 + 答案卷），并配套模型证明、策略注释与评分准则。

## 任务目标

将「会算」转为「会证」：把 AP 阶段建立的直觉与计算能力，升级为严谨的定义、命题与证明写作能力。产出两样东西：

1. 章节证明练习卷：题目卷 + 答案卷（LaTeX，全英文，tectonic 编译）
2. 证明技能清单（markdown）：记录达成度、弱点与待复习项

## 执行流程

### 1. 解析输入并读取教材

先校验参数：

- `chapter` 须为 1-11，越界则 ask_user 追问
- `tier` 各值须在 S0-S5 内；`num_problems` 为 1-20；`source` 三选一
- 参数不全时，先 ask_user，勿猜测

再读教材：用 PyMuPDF 打开教材 PDF（默认路径 `~/Desktop/math/Principles of Mathematical Analysis Third Edition (Retyped, Edited, Updated) (Walter Rudin) (z-library.sk, 1lib.sk, z-lib.sk).pdf`），以 `get_toc()` 定位该章起始页，提取正文与 Exercises 列表文本。若 `output_dir` 已有同章旧卷，先 `read` 旧卷，在此基础上更新而非覆写。

### 2. 定位章节技能矩阵与 AP 桥梁

按表选取本章核心技能 1-3 项，为本卷训练目标：

| 章 | 内容 | 核心证明技能 |
|----|------|--------------|
| 1 | 数系与确界 | sup/inf 构造、反证、域公理推导 |
| 2 | 基本拓扑 | 开闭/紧致定义运用、有限子覆盖、反证 |
| 3 | 序列与级数 | ε-N 论证、不等式放缩、Cauchy 准则、上极限 |
| 4 | 连续性 | ε-δ 论证、紧致与连通传递 |
| 5 | 微分 | 中值定理链、极限与不等式混合 |
| 6 | Riemann-Stieltjes 积分 | 分割与 ε/3 技巧、上/下和估计 |
| 7 | 函数序列与级数 | 双量化词（一致 vs 逐点）、换序论证 |
| 8 | 特殊函数 | 幂级数严格化、完备性证明 |
| 9 | 多元函数 | 线性映射、压缩原理、反/隐函数 |
| 10 | 微分形式 | 换元、Stokes 链 |
| 11 | Lebesgue 理论 | 测度构造、单调类、积分换序 |

AP 桥梁表——标出可迁移直觉与须修正的直觉（`ap_bridge: true` 时，在题目卷头部输出精简注释版）：

| 章 | AP 已有 | 本阶段动作 |
|----|---------|------------|
| 1 | 数轴直觉、矢量合成（Physics 1 平行四边形律） | 形式化：确界、域公理、完备性；物理直觉仅作理解辅助 |
| 2 | 「附近/邻域」直觉 | 形式化：邻域、开闭、紧致；紧致为全新概念 |
| 3 | 序列极限、比值/根式判别、调和级数记忆（Calc BC） | 直觉 → ε-N 定义；判别法 → 证明；「通项 → 0 则收敛」为**错误**直觉，须修正为仅发散判别 |
| 4 | 极限与连续直觉、IVT（Calc BC 使用未证） | 直觉 → ε-δ；IVT → 连通性证明 |
| 5 | 导数计算、MVT 使用（Calc BC 未证） | 计算 → 定义证明；MVT → 严格证明 |
| 6 | Riemann 和逼近（Calc BC） | 和式估计 → 分割与上/下和；FTC → 证明 |
| 7 | Taylor 幂级数、逐项微积分（Calc BC 未证） | 「逐项」→ 一致收敛条件；换序须证 |
| 8 | e^x、三角函数计算（Calc BC） | 计算 → 严格定义与性质证明 |
| 9-11 | 无直接对应 | 全新；先建定义直觉，再练证明 |

### 3. 设计题组（六步法）

1. 定技能目标：按步骤 2 所取技能与 `tier` 组合
2. 定来源：`source` 决定 Rudin 原题 / 定制脚手架题 / 混合
3. 定层级与难度：难度分布 standard（Easy 30% / Medium 50% / Hard 20%）；S0-S1 多为 Easy，S2-S3 多为 Medium，S4-S5 多为 Hard
4. 写模型证明：每题的完整证明，标出关键步骤与策略动机
5. 设陷阱：每题埋 1-2 个常见错误（S5 批判题直接暴露）；错误分类见下表
6. 标难度档案：卷头 `% Difficulty Profile: E/M/H = 30/50/20`，每题行尾 `% diff: hard S5` 注记

反堆料铁律（见 difficulty-escalation-framework）：难度 = 认知负荷类型与深度，非任务量。升级换维度（定义翻译 → 策略选择 → 反例构造），禁加计算、禁加长句。

常见错误分类表（S5 批判题素材与答案卷陷阱注）：

| 编号 | 错误类型 | 示例 |
|------|----------|------|
| E1 | 量化词顺序错误 | 一致收敛写成逐点收敛（∃N ∀n 反序） |
| E2 | 循环论证 | 用结论本身证明结论 |
| E3 | 假设存在性 | 未证存在即取 sup 或极限 |
| E4 | ε 余量不足 | 用 ε 而非 ε/2 导致无法收尾 |
| E5 | 推理方向颠倒 | 从结论推条件而未证可逆 |
| E6 | 滥用直觉 | 「显然」「由 AP 知」代替论证 |
| E7 | 放缩方向错误 | 上界放缩成更大值 |
| E8 | 漏查定理条件 | 非空、有界、闭集等前提未验证 |

### 4. 生成 LaTeX 双文件

命名与版式：

- 题目卷 `Rudin_Ch{chapter}_ProofPractice.tex`；答案卷 `Rudin_Ch{chapter}_ProofPractice_answer_key.tex`
- 版式沿用 Exercise 系规范：`\documentclass[9pt,twocolumn,letterpaper]{extarticle}`、`margin=0.3in`、`\pagestyle{empty}`、`\setlist[enumerate]{leftmargin=*,nosep}`、公式间距 ≤2pt（极致省纸）；答案卷可改单栏 `[9pt,letterpaper]` 以便排模型证明
- 题号风格：`enumerate[label=\textbf{\arabic*.}]`，子问 `(Alph*)`；题干公式用 `\displaystyle`；证明题区域留白充足

题目卷结构：

1. 头部：标题（章名）、题数与 tier 分布、难度档案、指令（ASD-STE100）、AP 桥梁精简注释（可选）
2. 按 tier 分组：`\section*{S0 Definition Translation}` 等；各组题号自 1 重排
3. 每题：题号、来源标注（如 `(Rudin Ex. 1.1)` 或 `(Custom)`）、题面；S2 骨架题以 `[Gap k]` 标空缺；S3 引导题附编号 Hints；S5 批判题给含错证明并要求定位
4. 全部英文，零中文

答案卷结构：

1. 每题模型证明：分步书写，关键步后括注策略动机（`\emph{...}`）
2. 陷阱注：标注该题对应错误分类（E1-E8）与避坑要点
3. 评分准则（每题适用）：

| 维度 | 3 分 | 2 分 | 1 分 | 0 分 |
|------|------|------|------|------|
| 逻辑完整 | 无缺步 | 缺次要步 | 缺关键步 | 无法成立 |
| 依据充分 | 每步有定理/定义依据 | 偶有跳步 | 多处跳步 | 无依据 |
| 假设使用 | 全部条件用尽 | 用主要条件 | 漏用条件 | 未用条件 |
| 结构规范 | 结构清晰、记号一致 | 基本清晰 | 混乱 | 不可读 |

### 5. 编译验证

- 双文件逐一 `tectonic` 编译；失败先查断行/溢出，勿先调列宽
- Overfull hbox 处理：`\emergencystretch=0.5em` 局部解决
- 编译毕清理中间文件（`.aux`、`.log`、`.synctex.gz`），仅留 `.tex` 与 `.pdf`

### 6. 独立验证（必须 subagent）

生成 agent 勿自验答案。委托 `momus` 或 `oracle` 逐题核对：

- 数学正确性：模型证明无错误、无跳步
- 脚手架恰当性：S2 gap 可填、S3 hint 不泄答案、S5 含错证明确有错
- 反堆料：难度升级换维度而非加量
- LaTeX 合规：无 Unicode 符号、双文件编译通过

调用示例：

```python
subagent({
  agent: "momus",
  task: "核对 {output_dir}/Rudin_Ch{chapter}_ProofPractice_answer_key.tex 的模型证明……",
  timeoutMs: 600000
})
```

若有误，修之复验，直至通过。

### 7. 学习闭环（可选）

生成 `Rudin_Ch{chapter}_ProofChecklist.md`：本章技能达成度（逐题打勾）、错误分类命中统计、待复习项（与后续章节衔接）。此文件亦为下次生成同章新卷的输入，供针对性加强。

## 输出格式

### 文件清单

| 文件 | 内容 | 语言 |
|------|------|------|
| `Rudin_Ch{N}_ProofPractice.tex` | 题目卷 | 英文 |
| `Rudin_Ch{N}_ProofPractice_answer_key.tex` | 模型证明答案卷 | 英文 |
| `Rudin_Ch{N}_ProofChecklist.md` | 技能清单（可选） | 中文 |

### 题目卷示例（片段）

```latex
%% ===== S0-1: Definition Translation (Easy) =====
\item Translate the following statement into an $\varepsilon$--$N$ form:
``the sequence $(s_n)$ converges to $s$.'' Then write its negation
(what it means for $(s_n)$ \emph{not} to converge to $s$). \hfill (Custom)

%% ===== S3-1: Strategy-Guided Proof (Medium) =====
\item Prove that if $r\neq 0$ is rational and $x$ is irrational, then
$rx$ is irrational. \hfill (Rudin Ex. 1.1, part 2)

\begin{quote}\small\textbf{Hints.}
(1) Proceed by contradiction.
(2) Suppose $rx=p/q$ with $p,q\in\mathbb{Z}$, $q\neq 0$.
(3) Solve for $x$; use closure of $\mathbb{Q}$ under multiplication
by nonzero rationals.
\end{quote}
```

### 答案卷示例（对应模型证明）

```latex
\textbf{S3-1.} Suppose, to the contrary, that $rx$ is rational; write
$rx=p/q$ with $p,q\in\mathbb{Z}$, $q\neq 0$. Since $r\neq 0$, write
$r=a/b$ with $a,b\in\mathbb{Z}$, $a\neq 0$. Then
$x=(p/q)\cdot(b/a)=pb/(qa)$, a quotient of integers with $qa\neq 0$,
so $x\in\mathbb{Q}$ --- contradicting the irrationality of $x$.
\emph{(Strategy: contradiction converts a negative claim into algebra;
the key move is dividing by $r\neq 0$.)}
```

### LaTeX 公式与符号排版规范（强制）

**绝对禁止：Unicode/ASCII 替代 LaTeX 符号**

所有数学符号必须用 LaTeX 命令，禁止使用外观相似的 Unicode 字符或 ASCII 替代写法。

| 场景 | ✅ LaTeX 命令 | ❌ 禁止写法 |
|------|--------------|------------|
| 蕴涵/箭头 | `\to` `\rightarrow` `\Rightarrow` | → ⇒ `=>` |
| 量词 | `\forall` `\exists` | ∀ ∃ |
| 属于 | `\in` | ∈ |
| 否定 | `\neg` `\lnot` | ¬ |
| 合取/析取 | `\land` `\lor` | ∧ ∨ |
| 不等/约等 | `\neq` `\approx` | ≠ ≈ |
| 大于等于/小于等于 | `\ge` `\le` | ≥ ≤ |
| 点乘/叉乘 | `\cdot` `\times` | · × |
| 无穷 | `\infty` | ∞ |
| 希腊字母 | `\theta` `\mu` `\omega` `\pi` `\alpha` `\beta` `\delta` | θ μ ω π α β δ |
| 积分/求和 | `\int` `\sum` | ∫ ∑ |
| 根号 | `\sqrt{}` | √（缺上横线） |
| 空集 | `\emptyset` | ∅ |
| 偏导/梯度 | `\partial` `\nabla` | ∂ ∇ |

规则：不确定某个符号的 LaTeX 命令时，查证后再写，绝不直接粘贴 Unicode。

**数学字体规范**

| 用途 | 写法 | 示例 |
|------|------|------|
| 变量 | 默认斜体 | `$m$` `$v$` `$t$` |
| 多字母函数 | `\sin` `\log` `\mathrm{}` | `$\sin\theta$` `$\mathrm{sup}$` |
| 矢量 | `\vec{}` | `$\vec{F}$` |

**公式排版上下文**

| 位置 | 语法 | 用量 |
|------|------|------|
| 行内 | `$...$` | 默认首选，不少于 95% |
| 行内加大 | `$\displaystyle...$` | 复杂分式/积分时 |
| 独立展示 | `\[...\]` 或 `$$...$$` | 仅核心公式，不超过 5% |

**书写规范**

- 上下标：多字符必须用花括号——`$s_{n}$`（正确），`$s_n$`（可能歧义）
- 分式：行内用 `\frac{}{}`，表格中复杂分式用 `$\displaystyle\frac{}{}$`
- 省略号：`\dots` `\cdots`，禁止三个句点 `...`
- 括号：简单括号直接用 `(` `)`，花括号转义 `\{` `\}`
- 双连字符 `--` 表示区间（en dash），三连 `---` 表示破折号（em dash），禁 Unicode `–` `—`

**生成后自查清单**

- [ ] 所有 Unicode 符号（→ ∀ ∃ ∈ ¬ 等）已替换为 LaTeX 命令
- [ ] 多字符下标用 `{...}` 包裹（`$s_{n}$` 不是 `$s_n$`）
- [ ] 数学函数名用正体（`$\sin$` `$\log$`，不是 `$sin$` `$log$`）
- [ ] 独立行间公式 ≤ 内容的 5%
- [ ] 题目卷与答案卷均无中文残留

### 中英术语对照（题目与解析用词基准）

| 教材术语 | 中文 |
|----------|------|
| ordered set / order | 有序集 / 序 |
| least-upper-bound property | 最小上界性质（完备性） |
| neighborhood / open ball | 邻域 / 开球 |
| compact / open cover | 紧致 / 开覆盖 |
| Cauchy sequence | Cauchy 序列 |
| uniformly convergent | 一致收敛 |
| partition / Riemann-Stieltjes integral | 分割 / Riemann-Stieltjes 积分 |
| equicontinuous | 等度连续 |
| contraction | 压缩映射 |

## 注意事项

1. **验证委托铁律**：答案核对必须 subagent（momus/oracle），生成 agent 勿自验（见步骤 6）
2. **教材自带 outline 习题**（如 Ex. 1.7、1.20）：勿照抄提示，改为引导式 S3 hint 或 S2 骨架，避免答案泄底
3. **定理复现题**：标注「关书复现」；要求学生不翻教材重证该章定理（如 Thm 1.21 n 次方根存在性）
4. **全英文零中文**：题目卷与答案卷禁中文；中文仅限 skill 侧说明与技能清单
5. **量化词是重点**：S0 必练否命题与量词翻转；Ch 7 之前可在 Ch 3 铺垫双量化词题（收敛 vs 一致收敛雏形）
6. **旧卷不覆写**：同章旧卷存在时先 read，再 edit 更新或另存新版本
7. **参数边界**：chapter 越界、tier 非法、tectonic 缺失时，报错并给出修正指引，勿静默继续
8. **PDF 提取失败**：改用 `pdftotext` 或 ask_user 提供章节文本；习题页页码以 `get_toc()` 为准
9. **难度标注**：每题 `% diff:` 注记与卷头难度档案须一致；反堆料清单自检（见 difficulty-escalation-framework §6）
10. **ASD-STE100**：题面指令与解析文字短句（≤ 20 词）、祈使开头、主动语态、一词一义；数学公式豁免

## 变更日志

### 1.0.0 (2026-08-24)
- 初始发布：S0-S5 脚手架分层、AP 桥梁映射、Rudin 原题与定制题双轨、模型证明答案卷与评分准则、tectonic 编译与 subagent 验证闭环
