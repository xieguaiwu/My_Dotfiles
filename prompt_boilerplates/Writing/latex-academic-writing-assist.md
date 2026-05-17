---
name: latex-academic-writing-assist
version: 1.0.0
description: 学术论文LaTeX排版、格式检查、编译调试与样式优化
triggers:
  - "LaTeX辅助"
  - "论文排版"
  - "参考文献格式"
  - "LaTeX编译"
  - "学术写作排版"
  - "LaTeX格式检查"
inputs:
  - name: tex_file
    description: 主LaTeX文件路径
    required: true
  - name: bib_file
    description: 参考文献.bib文件路径
    required: false
    default: ""
  - name: output_dir
    description: 编译输出目录
    required: false
    default: "."
  - name: template
    description: 论文模板（article, report, book, beamer等）
    required: false
    default: "article"
tools:
  - read
  - write
  - edit
  - bash
  - glob
  - grep
  - websearch_web_search_exa
  - webfetch
  - look_at
  - task
  - todowrite
---

# 学术论文 LaTeX 排版辅助

## 任务目标

基于给定的 LaTeX 源文件，完成以下一项或多项任务：

1. **排版与格式检查** — 检查 LaTeX 文档结构、包引用、节标题层级、图表/公式/引用格式
2. **编译调试** — 定位并修复 LaTeX 编译错误（Missing package、Undefined control sequence 等）
3. **参考文献管理** — 补充/修正 bib 条目、统一引用格式、检查引用完整性
4. **版式优化** — 调整页面布局、字体、间距、图表位置、交叉引用
5. **文档结构构建** — 从草稿/Markdown 创建完整 LaTeX 文档框架（用于学术期刊/会议/毕业论文）

后续以「示例论文项目」 `/home/xieguiawu/works/阐述/关于LLM的语言习得与乔姆斯基理论/latex_minds_and_machines_source/` 中的 LaTeX 源文件为风格参考。

---

## 执行流程

### 0. 前置准备

读取输入文件并确认项目结构：

```bash
read tex_file
# 如有 bib_file，一并读取
if bib_file is not empty:
    read bib_file
# 查看项目资源目录（图片、样式文件等）
glob 路径: "{tex_file所在目录}/**"
```

**确认事项**：
- 主文档是否依赖外部图片/样式/bib 文件
- 是否存在 `\input{}` 或 `\include{}` 拆分子文件
- 编译工具链（tectonic / pdflatex+bibtex / xelatex+biber 等）

---

### 1. 文档结构检查

#### 1.1 文档类与包引用

检查 `\documentclass{}` 参数是否正确：
- `article` / `report` / `book` / `beamer` 等模板是否匹配预期输出
- 字号（10pt, 11pt, 12pt）、纸张（a4paper, letterpaper）、双栏（twocolumn）等选项

检查必要包是否缺失或冗余。以「示例论文」为参考，常见学术论文包应包括：

| 功能域 | 必备包 | 用途 |
|--------|--------|------|
| 参考文献 | `natbib` | 文献引用 (citep/citet) |
| 页面边距 | `geometry` | 页边距设置 |
| 数学公式 | `amsmath`, `amssymb`, `latexsym` | 公式排版 |
| 图片 | `graphicx`, `float` | 插图与浮动体 |
| 子图 | `caption`, `subcaption` | 子图排版 |
| 表格 | `booktabs`, `multirow`, `adjustbox` | 专业表格 |
| 字体编码 | `T1` fontenc, `utf8` inputenc | 编码支持 |
| 超链接 | `hyperref` | 内部/外部链接（注意加载顺序——最后加载） |
| 交叉引用 | `cleveref` | 智能引用（在 hyperref 后加载） |
| 语言/语言学 | `linguex`, `relsize` | 语言学例句 |
| 列表 | `enumitem` | 自定义列表间距 |
| 段落格式 | `titlesec`, `titlespacing` | 节标题格式 |
| 颜色/高亮 | `xcolor`, `soul` | 文字颜色与高亮 |
| 注释/待办 | `todonotes` | TODO 标记 |
| 排版微调 | `microtype` | 字符间距微调 |
| URL | `url` | URL 换行 |
| 字体 | `times`, `inconsolata` | Times 与等宽字体 |

**检查标准**：
- ✅ 所有 `\usepackage{}` 有明确用途，无废弃包
- ✅ `hyperref` 在大多数其他包之后加载（cleveref 在 hyperref 之后）
- ✅ 包无冲突（如 `subfigure` 与 `subcaption` 不共存）
- ✅ `\hypersetup{}` 配置完整（colorlinks, citecolor, linkcolor, urlcolor, breaklinks）

#### 1.2 节标题层级

检查节标题组织的合理性：

```latex
\section{Introduction}          % 一级
\subsection{Background}         % 二级
\subsubsection{Related Works}   % 三级
\paragraph{}                    % 四级（可选）
```

**检查标准**：
- ✅ 不跳级（`\subsection` 不在 `\section` 外）
- ✅ 各级标题使用 `\titlespacing` 或 `titlesec` 统一间距
- ✅ 标题大小写风格全文一致（Sentence case 或 Title Case）
- ✅ 附录中使用 `\appendix` 切换

#### 1.3 自定义命令

检查用户定义的 `\newcommand{}`：
- 是否有重复定义
- 是否与已有包命令冲突
- 是否符合全文统一风格

**示例**（来自参考项目）：
```latex
\newcommand{\keywords}[1]{\par\vspace{0.5em}\noindent\textbf{Keywords:} #1}
```

---

### 2. 图表格式检查

#### 2.1 图片插入

参考项目的图片插入模式：

```latex
\begin{figure}[ht]
    \centering
    \includegraphics[width=0.65\textwidth]{./natural_syntax_tree.png}
    \caption{Natural language operates on hierarchical tree structures}
    \label{fig:natural-structure}
\end{figure}
```

**检查标准**：
- ✅ 使用 `\centering` 居中
- ✅ `\caption{}` 在 `\includegraphics` 之后（图片在上、caption 在下）  
- ✅ `\label{}` 在 `\caption{}` 之后（使其引用正确）
- ✅ 标签命名规范：`fig:xxx`, `tab:xxx`, `eq:xxx`
- ✅ 图片路径正确，文件存在
- ✅ 宽度控制：使用相对宽度（`\textwidth`, `\columnwidth`）而非绝对尺寸
- ✅ 位置参数合理（`ht`, `H`, `!htbp`）

#### 2.2 并排子图

参考项目使用的子图模式：

```latex
\begin{figure}[ht]
    \centering
    \begin{subfigure}{0.48\textwidth}
        \centering
        \includegraphics[width=\textwidth]{./loss_all_loss_comparison_aligned.png}
        \caption{Overall loss value comparison in experiment 1}
        \label{fig:exp1-loss}
    \end{subfigure}
    \hfill
    \begin{subfigure}{0.48\textwidth}
        \centering
        \includegraphics[width=\textwidth]{./t_test_loss_comparison.png}
        \caption{Loss distribution comparison for experiment 1}
        \label{fig:exp1-loss-t-test}
    \end{subfigure}
    \caption{Loss value comparison in experiment 1}
    \label{fig:exp1-combined}
\end{figure}
```

**检查标准**：
- ✅ 子图宽度之和 ≤ `\textwidth`（常见 0.48+0.48 或 0.45+0.45+hfill）
- ✅ 使用 `\hfill` 或 `\hspace{}` 分隔
- ✅ 子图有独立 caption 和 label
- ✅ 总图有总 caption 和 label

#### 2.3 表格

参考项目中使用 `booktabs` 排版表格：

```latex
\begin{table}[ht]
    \centering
    \begin{tabular}{lccc}
        \toprule
        Condition & Loss (final) & Loss (min) & AUC \\
        \midrule
        Natural      & 0.8287 & 0.7973 & 0.9326 \\
        Parity Neg.  & 1.6251 & 1.6051 & 1.7433 \\
        Reversed     & 1.8140 & 1.7916 & 1.9865 \\
        \bottomrule
    \end{tabular}
    \caption{Loss value comparison across conditions}
    \label{tab:loss-comparison}
\end{table}
```

**检查标准**：
- ✅ 使用 `\toprule`, `\midrule`, `\bottomrule`（booktabs 风格）
- ✅ 不使用垂直分割线（booktabs 惯例）
- ✅ 数字列右对齐，文本列左对齐
- ✅ 表内 font size 如有需要可用 `\small`, `\footnotesize`
- ✅ 表格不超宽（可用 `\adjustbox{max width=\textwidth}{...}` 处理）

---

### 3. 数学公式检查

#### 3.1 行内公式

```latex
loss ratios up to 2.25$\times$ natural
perplexity $= e^{\mathcal{L}}$
```

#### 3.2 独立公式

```latex
\begin{equation}
\mathcal{L} = -\frac{1}{N}\sum_{i=1}^{N}\log P_\theta(x_i \mid x_{<i})
\label{eq:cross-entropy}
\end{equation}
```

#### 3.3 多行对齐公式

```latex
\begin{align}
Sentence &\rightarrow NP + VP \\
VP &\rightarrow Verb + NP \\
NP &\rightarrow \{ NP_{sing}, NP_{pl} \}
\label{eq:cfg-rules}
\end{align}
```

**检查标准**：
- ✅ 独立公式用 `\equation` 或 `\align`，不用 `$$...$$`（LaTeX 原生环境产生更好的间距）
- ✅ 关键公式有 `\label{}` 用于交叉引用
- ✅ 公式中变量用斜体（默认），常量/算子用直体（`\mathrm{}`）

---

### 4. 文献引用管理

#### 4.1 引用命令

参考项目使用 natbib 的引用命令：

```latex
\citep{chomsky2023nyt}    % (Author, Year) — 括号引用
\citet{chomsky2009}       % Author (Year) — 正文引用
\citep{lewis2001,perfors2011}  % 多文献引用
```

**检查标准**：
- ✅ 全文统一使用 natbib 引用命令（不混用 `\cite`）
- ✅ `\citep` 用于句末括号引用，`\citet` 用于正文作者插入
- ✅ 所有 `\cite*{}` 中的 key 在 `.bib` 文件中都有对应条目
- ✅ 无明显遗漏引用：论述中提及的观点/数据/方法都有对应引用

#### 4.2 Bib 文件格式

参考项目中的 bib 条目示例：

```bib
@article{chomsky2023nyt,
    title={The false promise of ChatGPT},
    author={Chomsky, Noam},
    journal={The New York Times},
    year={2023},
    url={https://www.nytimes.com/2023/03/08/opinion/noam-chomsky-chatgpt-ai.html}
}

@book{chomsky1957,
    title={Syntactic structures},
    author={Chomsky, Noam},
    publisher={Mouton and Co},
    year={1957}
}

@incollection{chomsky1973,
    title={Language and freedom},
    author={Chomsky, Noam},
    booktitle={For the reason of state},
    pages={387--408},
    publisher={Random House},
    year={1973}
}
```

**检查标准**：
- ✅ 每个条目有完整必要字段
  - @article: author, title, journal, year, (volume, number, pages, doi)
  - @book: author, title, publisher, year
  - @incollection: author, title, booktitle, publisher, year, (pages)
  - @inproceedings: author, title, booktitle, year, (pages, doi)
- ✅ key 命名规范：`authorYYYY` 或 `authorYYYYtitle`（小写，无空格）
- ✅ 不缺失必填字段
- ✅ 作者格式统一：`Last, First` 或 `First Last` — 全文一致
- ✅ 期刊名不使用缩写与使用缩写不混用
- ✅ 页码连接号使用 `--`（en-dash）
- ✅ 有 DOI 的条目尽量补充

#### 4.3 未引用条目检查

运行 bib 文件检查，标记 `.bib` 中存在但 `.tex` 中未引用的条目（`\nocite{}` 除外）。如确需保留，使用：

```latex
\nocite{*}  % 引用所有未引用条目
```

---

### 5. 交叉引用检查

```latex
Figure~\ref{fig:natural-structure}
Table~\ref{tab:results}
Equation~\ref{eq:cross-entropy}
Section~\ref{sec:introduction}
```

**检查标准**：
- ✅ 所有 `\ref{}` 有对应的 `\label{}`
- ✅ 引用时使用 `Figure~\ref`、`Table~\ref`、`Section~\ref` 而非裸 `\ref`
- ✅ 标签命名命名空间清晰：`fig:`、`tab:`、`eq:`、`sec:`、`app:`
- ✅ 无 `??` 引用（编译后出现 ?? 表示 label 未定义）
- ✅ 如使用 `cleveref`，可用 `\Cref{fig:xxx}` 自动生成 "Figure X" 格式

---

### 6. 编译与错误修复

#### 6.1 编译流程

根据项目选择编译工具：

**Option A: tectonic（推荐，自动处理 bib）**
```bash
tectonic -X compile "{tex_file}"
```

**Option B: 传统链（pdflatex + bibtex + pdflatex × 2）**
```bash
pdflatex -interaction=nonstopmode "{tex_file}"
bibtex "{tex_file%.tex}"
pdflatex -interaction=nonstopmode "{tex_file}"
pdflatex -interaction=nonstopmode "{tex_file}"
```

**Option C: latexmk（自动循环）**
```bash
latexmk -pdf -interaction=nonstopmode "{tex_file}"
```

#### 6.2 常见错误与修复

| 错误信息 | 原因 | 修复方法 |
|---------|------|---------|
| `! LaTeX Error: File \`xxx.sty' not found.` | 缺少包 | `tlmgr install xxx` 或注释掉该包 |
| `! Undefined control sequence.` | 命令未定义 | 检查包是否导入；检查拼写 |
| `! Missing $ inserted.` | 数学模式未正确闭合 | 检查 `$...$` 或 `\[...\]` 匹配 |
| `! Package natbib Error: Bibliography not compatible with author-year.` | bib 样式不兼容 | 改用 `\bibstylestyle{acl_natbib}` 或 `plainnat` |
| `! Emergency stop.` | 严重错误 | 查看 .log 文件末尾定位具体错误 |
| `! LaTeX Error: Too many unprocessed floats.` | 浮动体过多 | 加 `\clearpage` 或 `\usepackage{morefloats}` |
| `Citation \`xxx' on page y undefined` | 引用未找到 | 确认 bib key 拼写；确认 bib 文件被正确引用 |
| `There were undefined references.` | 交叉引用未解析 | 重新编译（需多次编译） |

#### 6.3 编译后检查

- 查看 `.log` 文件中的 Warning（Overfull \hbox, Underfull \vbox, 未定义引用等）
- 检查 PDF 输出中的 `??`（未解析引用）或 `[??]`（未解析 citation）
- 检查页面是否超出边界

---

### 7. 版式一致性检查

#### 7.1 全文一致性清单

- [ ] 字体一致（同一字体族，不使用互斥字体包）
- [ ] 字号一致（标题、正文、脚注、caption 各层级统一）
- [ ] 行距一致（`\linespread{}` 或 `setspace` 包控制）
- [ ] 页边距一致（`\geometry{}` 统一设置）
- [ ] 段落间距一致（`\parskip` 或 `\setlength{\parskip}{}`）
- [ ] 列表环境间距一致（`enumitem` 统一配置）
- [ ] 图/表 caption 格式一致（字体、标点）
- [ ] 引用格式一致（全部使用 natbib `\citep`/`\citet`）
- [ ] 标点符号一致（中英文混排时注意全角/半角切换）
- [ ] 关键词/术语的强调方式一致（全部 `\textit{}` 或全部 `\emph{}`）

#### 7.2 页面布局

参考项目配置：
```latex
\geometry{a4paper,margin=2.5cm}
```

常见学术布局参数：
- 页边距：2.5cm（大多数期刊）或 1in（IEEE 等）
- 行距：`\singlespacing`、`\onehalfspacing`、`\doublespacing`
- 段落：首行缩进（默认）或段间距（`\setlength{\parskip}{6pt}` 加 `\setlength{\parindent}{0pt}`）

---

### 8. 从 Markdown/草稿创建 LaTeX 文档

如输入为 Markdown 草稿，按以下映射转换为 LaTeX：

| Markdown | LaTeX |
|----------|-------|
| `# 标题` | `\section{标题}` |
| `## 标题` | `\subsection{标题}` |
| `### 标题` | `\subsubsection{标题}` |
| `**粗体**` | `\textbf{粗体}` |
| `*斜体*` | `\textit{斜体}` |
| `` `code` `` | `\texttt{code}` |
| `- 列表项` | `\item 列表项` |
| `1. 列表项` | `\item[1.] 列表项` |
| `[text](url)` | `\href{url}{text}` 或 `\url{url}` |
| `![caption](path)` | `\includegraphics[]{path}` + `\caption{}` |
| `> 引用` | `\begin{quote} ... \end{quote}` |
| `$$公式$$` | `\begin{equation} ... \end{equation}` |
| `` `术语` `` | `\textit{术语}` 或 `\emph{术语}` |

**创建流程**：

1. 根据 `template` 参数（article/report/book）生成文档框架（documentclass、包引用、title/author/abstract）
2. 按上述映射转换正文内容
3. 识别人名引用和文献引用，插入 `\citep{}`/`\citet{}` 占位
4. 创建 `.bib` 文件框架并引导用户补充条目
5. 编译测试

---

### 9. 创建格式检查报告

如进行格式检查，生成 `{tex_file_name}_格式报告.md`，包含：

```
# LaTeX 格式审查报告

## 一、文档结构

### 文档类
- 当前: `{documentclass}`
- 建议: {如有建议}

### 包引用检查
✅ {通过的包}
⚠️ {有疑问的包}
❌ {问题包}

### 节标题
✅ 层级合理 / ⚠️ {节标题问题}

## 二、图表

### 图片
- 总数: {n}
- 问题: {图片格式/路径等问题}

### 表格
- 总数: {n}
- 问题: {表格格式问题}

## 三、引用与参考文献

### 引用完整性
- 已定义引用: {n} 条
- 未找到引用: {n} 条
- 未使用条目: {n} 条

### Bib 文件问题
{具体问题条目}

## 四、交叉引用
- 未定义 label: {n} 处
- 未使用 label: {n} 处

## 五、编译结果
- 编译成功/失败
- 警告: {n} 条（详见 `.log`）
- Overfull \hbox: {n} 处
- 其他问题: {描述}

## 六、格式一致性
- 字体: ✅/⚠️
- 行距: ✅/⚠️
- 引用风格: ✅/⚠️
- 其他: ✅/⚠️

---

*报告生成时间: {日期}*
*编译工具链: {tectonic/pdflatex+bibtex/latexmk}*
```

---

## 输出格式

根据具体任务不同，输出以下内容之一：

### 格式检查
- 格式审查报告 `.md` 文件
- 直接修改 `.tex` 文件中的格式问题（经确认后）

### 编译
- 编译产生的 PDF 文件
- 如编译失败：错误定位与修复建议

### 文献管理
- 更新后的 `.bib` 文件
- 缺失条目补充建议

### 文档创建
- 生成的 `.tex` 文档框架
- 对应的 `.bib` 文件框架
- 编译测试结果

---

## 注意事项

### 通用原则
1. **不改变学术内容**：仅修改排版格式，不动原文观点、数据、结论
2. **最小化修改**：每次只改明确有问题的内容，不做大规模重构
3. **有疑问先问**：不确定的格式选择（如字体、期刊模板），先询问用户
4. **保留历史**：每次修改前确保 git 已 commit 当前状态（见 Git 安全网）
5. **检查 bib 兼容性**：bib 样式（`\bibliographystyle{}`）应与 natbib 的 author-year 或 numbered 模式匹配

### 包加载顺序
某些包对加载顺序敏感：
```
amsmath → hyperref → cleveref （hyperref 通常在最后加载，cleveref 在 hyperref 之后）
```

### 模板匹配
不同期刊/会议有不同的 LaTeX 模板：
- ACL/EMNLP: `acl_natbib.bst` + natbib
- IEEE: `IEEEtran.cls` + `IEEEbib.bst`
- Elsevier: `elsarticle.cls` + `model1-num-names.bst`
- arXiv: 无严格限制，但推荐使用 `\pdfoutput=1`

### 编译注意事项
1. 参考文献需额外编译步骤（bibtex 或 biblatex 的 biber）
2. 交叉引用需要 2 次 pdflatex 编译才能解析
3. 使用 `tectonic -X compile` 可自动处理所有步骤
4. 编译错误查看 `.log` 文件末尾的 `! ` 开头的行

### 字体与编码
1. 中文 LaTeX 推荐使用 `ctex` 包或 `xelatex` 编译
2. UTF-8 编码现已成标准（`\usepackage[utf8]{inputenc}`）
3. 字体编码推荐 `T1`（`\usepackage[T1]{fontenc}`）以获得更好的断字

### 文件组织
推荐大型项目的文件结构：
```
project/
├── main.tex          % 主文档
├── sections/         % 各节子文件
│   ├── intro.tex
│   ├── methods.tex
│   └── conclusion.tex
├── figures/          % 图片目录
│   ├── fig1.png
│   └── fig2.pdf
├── references.bib    % 文献库
├── acl_natbib.bst    % 样式文件
└── output/           % 编译输出
```

### 常见陷阱
1. **`\\` 滥用**：`\\` 用于换行，不用于分段（分段用空行）
2. **引号**：LaTeX 引号为 `` ` ' ``（反引号+单引号）或 ` `` '' `（双引号），不用直引号 `"`
3. **连字符**：连词用 `-`、数字范围用 `--`（en-dash）、破折号用 `---`（em-dash）
4. **省略号**：用 `\dots` 而非 `...`
5. **脚注**：`\footnote{}` 放在句末标点**之后**
6. **空格**：命令后接文本需用 `{}` 或 `\ ` 控制空格，如 `\LaTeX{} is great`

---

## ⚡ Git 安全网 + 文件写入安全

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。执行所有 `write`/`edit` 操作前，必须先读取并执行 `git_safety_net.md` 中的 git 版本追踪指令。

同时遵守以下基本写入安全规则：
1. **写入前先检查**：使用 `glob` 或 `read` 确认目标文件是否已存在
2. **已有文件优先用 `edit`**：如果文件已存在，使用 `edit` 追加/修改，而非 `write` 覆写
3. **`write` 仅用于新建**：确保目标文件确实不存在再使用 `write`
4. **覆写前确认**：如果必须覆写已有文件，先告知用户并获得明确许可
5. **bib 文件修改需谨慎**：修改 `.bib` 文件时逐条确认，不批量删除条目
6. **编译前确认**：修改 `.tex` 文件后，先问用户是否要编译测试
