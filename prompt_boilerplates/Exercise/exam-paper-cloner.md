---
name: exam-paper-cloner
version: 1.3.0
description: 阅读现有试卷作为模板和/或根据知识点描述，生成全英文LaTeX试卷，使用tectonic编译，极致节省纸张。支持扫描版PDF作为模板（§0.3a Vision OCR 流水线）。v1.2.0 新增难度升级专项（§1.7）：按学科分轨（数理禁堆计算量/文科允许句法复杂度），12+10 维度矩阵与反堆料检查清单，难度档案标注（规范见 difficulty-escalation-framework.md）。v1.3.0 更新 §0.3a：vision 模型可用性实测表+fallback 链+增量保存+rationale 缺失检测+新增 §0.3a.11 服务器端扫描（资源确认/SSH 不稳应对/RapidOCR 版本坑）
triggers:
  - "clone exam"
  - "生成试卷"
  - "generate paper"
  - "make exam"
  - "出卷"
  - "exam cloner"
inputs:
  - name: template_path
    description: 作为模板参考的现有试卷路径（可选；不提供则根据知识点从头生成）
    required: false
    default: ""
  - name: topics
    description: 要考察的知识点列表（提供template_path时作为补充约束；无模板时作为出题依据）
    required: false
    default: ""
  - name: question_count
    description: 目标题目数量（0=自动根据模板或知识点决定）
    required: false
    default: 0
  - name: output_name
    description: 输出文件名（不含扩展名）
    required: false
    default: Generated_Exam
  - name: options_count
    description: 每题选项数（4 或 5）
    required: false
    default: 4
  - name: subject
    description: 科目名称（如 AP Calculus BC、Linear Algebra），用于文件命名
    required: false
    default: ""
  - name: exam_type
    description: 试卷类型标签（如 Practice_Test、Quiz_Midterm），用于文件命名
    required: false
    default: "Practice"
  - name: difficulty
    description: 难度模式（standard=30/50/20[默认] / hard=15/40/45 / max=0/30/70 / auto=沿用模板难度分布）。升级维度选择见 §1.7 与 difficulty-escalation-framework.md
    required: false
    default: "auto"
  - name: escalation_focus
    description: 难度升级维度清单（可选，逗号分隔，如 "D1,D6" 或 "L2,L3"；维度编码见 §1.7 / difficulty-escalation-framework.md §3-4）
    required: false
    default: ""
  - name: output_dir
    description: 输出目录（默认当前工作目录）
    required: false
    default: "."
tools:
  - write
  - bash
  - read
  - grep
  - edit
  - subagent
  - fetch_content
---

# 试卷克隆生成器 (Exam Paper Cloner & Generator)

## 任务目标

根据**现有试卷模板**（克隆其结构、题型、格式、难度分布）和/或**知识点描述**，生成一份新的全英文 LaTeX 试卷。要求：

1. **克隆模式**：读入一份已有的 .tex 或 .md 格式试卷，提取其结构特征（题型分布、选项数、编号方式、段落风格），然后用全新的题目内容填充
2. **知识点模式**：无模板时根据用户提供的知识点列表，从零设计题目
3. **全英文**：所有产出物（题干、选项、说明、答案、干扰项分析）一律为英文，禁止出现中文
4. **纸张节省**：通过排版技巧最大化题目密度，最小化页数
5. **答案分离**：试卷与答案**始终生成独立的两个文件**，分别用 tectonic 编译
6. **tectonic 编译**：最终产出试卷 PDF + 答案 PDF

---

## 完整工作流程

### Phase 0: 输入分析

#### 0.1 确定模式

| 条件 | 模式 | 说明 |
|------|------|------|
| 提供了 `template_path` | **克隆模式** | 分析模板结构 → 用新题目替换 |
| 提供了 `topics` 但无模板 | **知识点模式** | 根据知识点设计整份试卷 |
| 两者都提供 | **混合模式** | 克隆结构 + 知识点约束题目内容 |
| 都没有提供 | 报错 | 必须至少提供一项 |

#### 0.2 确定试卷类型

从用户输入或模板推断试卷类型，影响题目设计策略：

| 试卷类型 | 特征 | 典型结构 |
|----------|------|----------|
| **标准考试卷**（如 AP Mock） | 选择题 + 简答题，有计时限制 | Part A (无计算器) + Part B (需计算器) |
| **专项练习**（如积分练习） | 纯计算题，无选择题 | 按主题分 Section，题量大 |
| **错题/复习卷** | 概念诊断 + 应用 | 混合题型，难度递进 |
| **随堂测验** | 短小精悍，含姓名日期栏 | Name/Date 抬头，15-25 题 |

#### 0.3 读取模板（克隆模式）

```bash
# 读取模板文件
read "{template_path}"
```

**处理不同模板格式：**

| 模板格式 | 处理方式 |
|----------|----------|
| `.tex`（LaTeX 源码） | 直接解析文档类、宏包、`\\begin{document}` 内的结构 |
| `.md`（Markdown） | 先识别 YAML front matter（如有），再分析 Markdown 标题层级推断结构；将 Markdown 格式映射为等效 LaTeX 结构 |
| `.pdf` | 先 `pdftotext` 逐页检测文字层；文本页直接解析，扫描页自动走 §0.3a 视觉 OCR 流水线（需 vision API key） |

**从 LaTeX 模板提取的以下特征：**

| 特征 | 提取内容 |
|------|----------|
| 文档类与宏包 | `\documentclass[...]`, `\usepackage{...}` |
| 页面设置 | 边距、纸张大小、页眉页脚 |
| 题型结构 | 选择题/简答题/填空题，各部分数量 |
| 编号方式 | `\arabic*`, `\alph*`, `\Alph*` |
| 选项格式 | `(A)`, `\Alph*`, 4 或 5 选项 |
| 间距设置 | `\parskip`, `\itemsep`, `nosep` |
| 答案表格式 | 表格列数、排列方式 |
| 题目风格 | 题干长度、场景描述方式、公式密度 |
| 难度分布 | 简单/中等/困难的比例 |

**提取后记录为结构特征清单**，后续生成严格遵循。

##### 0.3a Scanned PDF Processing via Vision OCR

当模板 PDF 存在无法通过 `pdftotext` 提取文字层的扫描/图片页时，自动启动以下流水线。

###### 0.3a.1 Detect Scanned vs Text Pages

```bash
for p in $(seq 1 $(pdfinfo "$pdf" | awk '/Pages/{print $2}')); do
  chars=$(pdftotext -f $p -l $p "$pdf" - 2>/dev/null | wc -c)
  echo "p$p: $chars $( [ $chars -lt 10 ] && echo 'SCANNED' || echo 'TEXT' )"
done
```

< 10 字符 = 扫描页；> 100 字符 = 文本层可用。混合型 PDF（部分文字层+部分扫描）常见于用户手工拼装的文件。

###### 0.3a.2 Vision Model Selection & Pre-flight

**不可用的模型（已知坑，跳过）：**
- `opencode-go/qwen3.6-plus` → 月度额度耗尽 (429)
- `nvidia/meta/llama-4-maverick-17b-128e-instruct` → 410 Gone（已下架）
- `doubao-seed-2-0-pro-260215` → **账号级 429 `SetLimitExceeded`**（错误消息含 "Safe Experience Mode"，模型服务被暂停）。这是**账号配额**问题，换 IP/代理无用；恢复时间不定（分钟~小时级），触发后立即降级到备选模型，勿傻等
- `doubao-seed-1-6-vision-250815` → 404（**账号未开通**该模型；volcengine 部分模型需在控制台激活后才能按名调用）
- `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` → 503 Service Unavailable（已不可用）

**可用模型（按推荐顺序，2026-08 实测）：**

| 模型 | Provider | 质量 | 备注 |
|---|---|---|---|
| `doubao-seed-2-0-pro-260215` | volcengine | ★★★★★ | 数学/表格 OCR 最准，中英文均好；**有账号级配额上限，超限 429** |
| `nvidia/nemotron-nano-12b-v2-vl` | nvidia | ★★★ | 实测可用（9s/页），免费；**偶发漏读**——rationale 段报 "Not answerable" / "not provided in the image"，需补扫 |
| `kimi-k3` | moonshot | ★★★★ | 1M ctx，易触发 429 限频 |

**Pre-flight（必做）**：
1. **模型 ID 探测**——正式转录前，用 1 张典型页对候选链每个模型各发一次 100-token 请求：
   - 200 → 可用；**404 → 该账号未开通，永久跳过**；**429 SetLimitExceeded → 账号配额耗尽，降级**；503/5xx → 暂不可用，可稍后重试
   - 单次调用超时上限 60-120s，卡住即判失败（部分 provider 配额挂起时请求会**静默挂起**而非报错，urllib 必须设 timeout）
2. **fallback 链**——脚本内按序尝试多个模型：`[doubao-pro, nemotron-nano-vl, kimi-k3]`；429/5xx 退避重试（15s/30s/60s），**4xx（非限流）立即换下一个模型**；每页记录实际所用模型（便于质量回溯）
3. 取一张典型页用候选模型各试一次，对照已知答案键比较准确度，选最佳模型。

###### 0.3a.3 Probe Document Structure

正式转录前先探测关键页的元信息（只问 3 个问题，不转录全文）：

```python
PROMPT = """
Scanned exam page. Answer EXACTLY:
HEADER: <section name> | BOOKLET_PAGE: <number> | QUESTIONS: <list> |
HAS_TABLES: yes/no | HAS_FIGURES: yes/no |
FIRST_WORDS: <first 12 words>
"""
```

产出 **页面-内容映射表**（PDF 页码 ↔ booklet 页码 ↔ 题目号 ↔ 章节类型），用于：
- 定位 Section 边界（No Calculator vs Calculator）
- 发现缺失页面（对照答案键，答案覆盖的题号是否都有对应扫描页）
- 排除重复前页（混合 PDF 常有前后重复的内容页）

###### 0.3a.4 Page Rendering

```bash
pdftoppm -png -r 200 -f {start} -l {end} "$pdf" pages/
# 200 DPI 是质量/文件大小的平衡点；数学文本需 ≥ 150 DPI
```

###### 0.3a.5 Transcription Script

写 Python 脚本逐页调用 vision API。关键模板：

```python
PROMPT = """Transcribe with 100% fidelity.
PAGE: <filename>
HEADER: <section header, directions, calculator/no-calc icon>
Q<num>: <full problem text verbatim>
  A) <choice>  B) <choice>  C) <choice>  D) <choice>
MATH: exponents as ^, fractions as (a)/(b), sqrt(), absolute |...|
TABLES: pipe format | col1 | col2 |
FIGURES: description + FIGURE_BBOX_Q<num>: <x1-x2%, y1-y2%>
FOOTER: <page number, CONTINUE/STOP>
"""

payload = {"model": MODEL, "temperature": 0.1, "max_tokens": 6000}
# 重试：exponential backoff 15s, 30s, 60s, 120s（vision API 偶发 429/5xx）
# 限频：每页间 sleep(1-2s)
# fallback 链：429/5xx 退避重试；404/410 等 4xx 立即换下一个模型
# 每页必须强制输出 FOOTER：模型自报的 Q<num> 不可信，题号以 FOOTER/页面序为准
```

**增量保存（防中断全丢）**：每页转录完成立即写入 `raw.json`（key=页码），并另存 `models.json` 记录每页所用模型；进程被杀/断网后可断点续跑（跳过已存页）。

**rationale 缺失检测**：转录完成后 `grep -l "Not answerable\|not provided in the image\|Not answerable" raw.json`——漏读页用**另一模型**重扫，或裁剪解析区域单独重读；仍缺失则后续自写解析（结论必须与答案一致）。

###### 0.3a.6 Answer Key Cross-Validation

**这是整个流程中最重要的质量保证步骤。**

转录完成后，对每道题用答案键验证：
- MC 题：重新解算，确认 transcribed choice = key answer
- Grid-in 题：解算验证
- 若矛盾 → 该题可能有 OCR 错误 → 裁剪该区域单独重读 → 修复

本项目 58 道题全部通过此步验证（30+28），0 错误。此步骤**本质是用数学逻辑修复 OCR 不确定性**。

###### 0.3a.7 Figure Cropping — Two Pass

**Pass 1**（初裁）：用转录中返回的 FIGURE_BBOX 百分比裁剪：

```python
from PIL import Image
img = Image.open(f"pages/pg-{page}.png")
W, H = img.size
box = (int(W*x1/100), int(H*y1/100), int(W*x2/100), int(H*y2/100))
img.crop(box).save(f"figs/{name}.png")
```

**Pass 2**（精修）：将初裁图片送入 vision 模型自检：

```python
prompt = "Any partial/cut-off TEXT in this crop? If yes, where exactly (top/bottom/left/right)?"
# 根据反馈收紧对应边 2-6%
```

**常见杂字来源**：图上方问题文本末行、图下方选项/页脚行、双栏邻栏溢出、页眉/页码。

**大长图防溢出**：裁剪后计算渲染高度：
```
height_in_pt = desired_width * crop_px_height / crop_px_width
if height_in_pt > 0.75 * textheight: reduce width
```
本项目中 Q15 四联选项图 0.42\textwidth → 735pt → 缩小至 0.24 解决 overfull vbox。

###### 0.3a.8 Two-Column Layout Awareness

SAT / ACT 等标准化考试的数学页常用**双栏布局**（如左栏 Q11、右栏 Q12）。若整页转录可能将两栏问题混排。

**检测**：某页 probe 返回 N 题但文本提取只出现 N/2 题的选项 → 双栏。

**对策**：转录时显式提示 "this page may have a two-column layout"；验证时逐栏裁剪重读确认。

###### 0.3a.9 Bilingual / CJK Content

若试卷含中英文混排注释，**需用 xelatex**（tectonic 中文不稳定）：

> 注（2026-08-13 实测）：tectonic 也可编译中文——fontspec + 静态 TTF 全局 `\setmainfont{Noto Sans SC}` 方案（不依赖 ctex）已跑通；xelatex 仅在不便改字体方案时使用。

```latex
% 1. 必须静态 TTF，不可用可变 TTC（xdvipdfmx fatal: Invalid TTC index）
\newfontfamily\cnfont[Path=/path/to/fonts/,
  BoldFont=NotoSansSC-Bold.ttf]{NotoSansSC-Regular.ttf}
\newcommand{\cn}[1]{{\cnfont #1}}

% 2. 中日韩换行（缺这两行 = 中文整串不换行；症状：Overfull hbox 大超宽（>10pt）且误判为列宽问题 → 先查此处，别调列宽）
\XeTeXlinebreaklocale "zh"
\XeTeXlinebreakskip = 0pt plus 1pt

% 3. PDF 书签禁用中文命令
\pdfstringdefDisableCommands{\renewcommand{\cn}[1]{#1}}

% 4. 所有中文字符必须在 \cn{...} 内，否则 Latin Modern 缺字
```

###### 0.3a.11 Server-side OCR（服务器优先，本机 API 限流时）

当本机 vision API 限流/不可用，或任务量大时，**优先在运行中的服务器上做扫描**（避免与正在运行的训练/任务抢资源，先确认）。

**0.3a.11.1 服务器资源确认（必做，防干扰现有任务）**
```bash
uptime; free -h; df -h /; ps aux --sort=-%cpu | head -8   # 已有训练/任务进程
nvidia-smi 2>/dev/null || echo "no GPU driver"            # 无 GPU 时用 CPU OCR
```
- 有训练任务占 N 核 → OCR 线程数 ≤ 剩余核数 - 1；内存可用 < 2GB 时放弃该机
- 磁盘 < 5GB 放弃；GPU 驱动不可用 ≠ 不能跑（CPU 版 RapidOCR 可用）

**0.3a.11.2 SSH 不稳定应对（kex reset / 连接频率限制）**
- 现象：`kex_exchange_identification: read: Connection reset by peer`；连上一次后短时间再连必 reset（疑似 fail2ban/频率限制）
- 对策：
  - **重试包装**：连接/命令/传输统一走重试循环（8 次，间隔 4s×i 递增），直到成功
  - **单会话完成多步**：传脚本+启动+验证合并为一次 SSH 调用（`ssh host 'cmd1 && cmd2'`），避免二次连接
  - 连上一次后若需再连，间隔 ≥ 40-90s；连续失败时停止重试 5 分钟防封禁
  - 小文件用 `echo {b64} | base64 -d > file` 传输（防引号转义）；大文件用 scp（同样套重试）
  - 后台任务：`setsid nohup python3 script.py > log 2>&1 < /dev/null &`，随后**必须**检查日志文件已生成+进程存在

**0.3a.11.3 远程进程排查防自匹配**
- `pgrep -f pattern` / `pkill -f pattern` 在远程 `bash -c "..."` 环境下会**匹配到自己的包装进程**（cmdline 含完整命令）→ 误判"进程在跑"
- 正确：`ps aux | grep "[s]erver_ocr"`（方括号技巧）；kill 用 `ps aux | grep [x]xx | awk '{print $2}' | xargs -r kill`

**0.3a.11.4 RapidOCR 版本格式坑（2026-08 实测）**
- `rapidocr-onnxruntime` 1.4.x 返回结构剧变：`(items, scores)` 二元组，且 items 内**混合** `[box, text]` 与 `[box, text, score]` 两种元素——旧版 `[box, text, score]` 解包写法全部报错（`too many values to unpack` / `float() ... not 'list'`）
- **铁律：写解析代码前先探针**——打印 `type(out)`、`len(out)`、元素类型与长度，确认后再写 normalize
- 兼容写法：tuple 取 `out[0]`；每元素按长度取 `box=it[0], text=it[1], score=it[2] if len(it)>2 else 0.0`；score 是 list 时取首元素
- 需要稳定旧格式可 pin：`pip install rapidocr_onnxruntime==1.3.24`（清华镜像可能不提供旧版，装完用 `pip show` 验证版本）
- 每页 1-2s（CPU 4 线程，200DPI 页面），57 页约 2-5 分钟

**0.3a.11.5 双路交叉验证**
vision 转录与本地 OCR 是两条独立管道：OCR 行文本+坐标可验证 vision 转录的题目/选项文字，vision 可补 OCR 缺的解析语义。两路结果不一致时以 vision 转录为准并人工复核。

###### 0.3a.10 Glossary

| 术语 | 含义 |
|---|---|
| booklet 页码 | 原印刷册子的页码（≠ PDF 页码），通常印在页面底部 |
| QAS | College Board Question-and-Answer Service，付费获取完整试卷+答案 |
| Section 3/4 | SAT 数学两部分：3=不可用计算器 25min 20题，4=可用 55min 38题 |
| grid-in | SAT 填空题（输入数字答案而非选 ABCD） |
| bbox | bounding box，图中图形区域的百分比坐标 (x1-x2%, y1-y2%) |

#### 0.4 混合模式：模板 + 知识点协同

当同时提供 `template_path` 和 `topics` 时，两者协同工作：

| 场景 | 模板的作用 | 知识点的作用 |
|------|-----------|-------------|
| 模板科目匹配知识点 | 提供完整结构（题型分布、格式、难度） | 约束每道题的具体内容方向 |
| 模板科目不匹配知识点 | **不克隆**题目内容，仅借用格式（如选项样式、间距设置） | 完全决定题目内容 |
| 知识点多于模板覆盖 | 保持模板结构，多余知识点追加为额外 Section | 提供追加部分的出题范围 |
| 知识点少于模板覆盖 | 砍掉模板中未对应的 Section，或缩减题量 | 决定保留哪些模板 Section |

**示例**：模板是 45 题 AP Calculus BC 试卷（30 MCQ + 6 FRQ），提供 topics = "derivatives, integration"
→ 保留 MCQ 30 题、FRQ 6 题的结构
→ 题目全部改为导数与积分内容
→ 跳过原模板中的极坐标、级数题目

---

### Phase 1: 题目生成

#### 1.1 确定题目数量与分布

> 知识点模式的题目拆分与分配规则见 §6 知识点模式专项。以下为总览。

**克隆模式**：保持与原模板相同的题量、各题型比例、难度分布。

**知识点模式**：根据 `topics` 数量和复杂度分配：

| 知识点数 | 建议总题数 | 每题覆盖 |
|----------|-----------|----------|
| 1-3 个 | 15-25 | 每个知识点 5-8 题 |
| 4-6 个 | 25-35 | 每个知识点 4-6 题 |
| 7+ 个 | 35-45 | 每个知识点 3-5 题 |

#### 1.2 文档结构与 `\newcommand` 宏定义

从 AP 专项 skill 中提取的常用宏，可用于简化 LaTeX 编写：

```latex
\newcommand{\question}[1]{\textbf{#1}}          % 题目标签，如 \question{Q1:}（可选—不用也可直接写 \item）
\newcommand{\mcitem}[1]{\item[\textbf{#1}]}     % 选项标签，如 \mcitem{A}（可选—标准 enumerate 也可）
\newcommand{\prob}[1]{\item $\displaystyle #1$} % 纯计算题的积分/极限题目，如 \prob{\int x^2\, dx}
```

**`\prob` 用法示例（纯计算题 Section）：**
```latex
\section*{Section 1: U-Substitution}
\begin{enumerate}
    \prob{\int x\sqrt{1 + x^2}\, dx}
    \prob{\int e^{\sin x}\cos x\, dx}
    \prob{\int \frac{dx}{x\ln x}}
\end{enumerate}
```

**随堂测验/练习卷**可加姓名日期栏：
```latex
{\large Name: \underline{\hspace{4cm}} \qquad Date: \underline{\hspace{3cm}}}
```

**试卷结束标记**（可选）：
```latex
\vspace{0.5em}
\hrule
\vspace{0.3em}
\begin{center}
    {\itshape --- End ---}
\end{center}
```

#### 1.3 `\displaystyle` 规范

根据所有 AP Calculus source skills 的一致要求：

| 场景 | 要求 | 示例 |
|------|------|------|
| 题干中的极限 | `$\displaystyle\lim_{x\to a}$` | `$\displaystyle\lim_{x\to 0}\frac{\sin x}{x}$` |
| 题干中的积分 | `$\displaystyle\int_a^b f(x)\, dx$` | `$\displaystyle\int_0^1 x^2\, dx$` |
| 题干中的求和 | `$\displaystyle\sum_{n=1}^{\infty} a_n$` | `$\displaystyle\sum_{n=1}^{\infty}\frac{1}{n^2}$` |
| 分数（题干） | 复杂用 `\dfrac`，简单用 `\frac` | `$\dfrac{a}{b}$` vs `$\frac{a}{b}$` |
| 选项内公式 | **行内大小**（禁用 `\displaystyle`） | 选项里积分/求和保持紧凑 |
| 纯计算题 | `\prob` 宏自动加 `\displaystyle` | `\prob{\int x^2\, dx}` |

#### 1.4 LaTeX 数学符号规范（禁止 Unicode 替代）

所有数学公式**必须使用纯 LaTeX 命令**，不得用 Unicode 字符或 ASCII 替代。

| 含义 | LaTeX 命令（正确 ✅） | Unicode / ASCII（错误 ❌） |
|------|----------------------|--------------------------|
| 无穷 | `$\infty$` | `∞` |
| 偏导 | `$\partial$` | `∂` |
| 积分 | `$\int$` | `∫` |
| 求和 | `$\sum$` | `∑` |
| 属于 | `$\in$` | `∈` |
| 子集 | `$\subseteq$`, `$\subset$` | `⊆`, `⊂` |
| 空集 | `$\emptyset$`, `$\varnothing$` | `∅` |
| 点乘 | `$\cdot$` | `·` |
| 蕴涵 | `$\to$`, `$\rightarrow$` | `→` |
| 全称量词 | `$\forall$` | `∀` |
| 存在量词 | `$\exists$` | `∃` |
| 否定 | `$\neg$`, `$\lnot$` | `¬` |
| 合取/与 | `$\land$` | `∧` |
| 析取/或 | `$\lor$` | `∨` |

**原则**：任何在 LaTeX 数学模式中出现的符号，都必须用 `\command` 形式，不能用对应 Unicode 码点。这保证了：
- tectonic 编译不会因 Unicode 符号报错
- 公式在不同字体/环境下渲染一致
- PDF 复制粘贴不会丢失信息

例外：常见标点（+ - = < > / ( ) [ ] %）和普通字母数字可以直接输入。

#### 1.5 设计原则（来自多份 skill 的综合提取）

##### 题干设计

| 原则 | 要求 |
|------|------|
| 自包含 | 题干完整描述场景，不依赖外部图片 |
| 图片替代 | 原图场景用精确的英文文本描述替代 |
| 清晰无歧义 | 每道题只有一个正确的解释方向 |
| 全英文 | 题目/选项/说明全部为英文 |
| 数据独立 | 所有数值数据必须重新设计（克隆模式时全部替换为新值） |
| 无重复 | 同一份试卷内不出现相似题目 |
| 语言正式 | 使用学术英语，语法正确，术语标准 |

##### 选项设计

| 选项数 | 适用场景 |
|--------|----------|
| 4 个 (A-D) | 通用练习卷、校内考试、非 AP 标准化考试 |
| 5 个 (A-E) | AP 模拟卷、部分竞赛类考试 |

**每道题的选项必须满足：**

1.  **唯一正确答案** — 每题有且仅有一个正确选项
2.  **迷惑性干扰项** — 每个错误选项对应一种**常见的、真实的**学生错误
    - 要有明确的"错误来源"（如：符号错误、公式混淆、off-by-one、概念误解、单位错误等）
    - 不能是明显可排除的"凑数"选项
    - 至少有一个干扰项需要深度理解/完整推导才能排除
3.  **禁止项** — 不使用 "All of the above" / "None of the above" / "以上皆是" / "以上皆非"
4.  **选项独立** — 选项之间不重叠含义，不互相包含
5.  **数值接近**（数值题）— 正确值与干扰项数值在量级上接近，不能一眼看出

##### 数据修改规范（克隆模式 + 知识点模式均适用）

创建题目时，所有具体数值必须**重新设计**。参考以下修改范围：

| 数据类型 | 修改范围 | 示例 |
|----------|----------|------|
| 整数常量 | 变为不同的整数 | 100 | → 75 |
| 小数 | 改变有效数字 | 3.14 → 2.71 |
| 角度 | ±15°–30°偏移 | 30° → 45° |
| 函数参数 | 替换为同类函数 | sin → cos, x² → x³ |
| 矩阵维度 | 3×3 → 4×4 等 | 保持复杂度一致 |
| 代码变量 | 全部重命名 | nums → values |

> 修改后必须验证新数值是否保持数学/物理/逻辑合理性。

#### 1.7 难度升级专项（Difficulty Escalation）⚠️ 核心能力

> 完整规范见 `difficulty-escalation-framework.md`（同目录）。本节为强制执行浓缩版。

**铁律：难度 = 认知负荷的类型与深度，不是任务量。** 升级难度必须改变"考什么能力"，而不是延长"做什么"。

**学科分轨（先分类，再选维度）：**

| 轨 | 学科 | 允许的升级方式 | 严禁 |
|----|------|--------------|------|
| 数理轨 | 数学/物理/化学/统计/CS | D1-D12 维度（下表） | **堆砌计算量**：长多项式展开、超大数运算、连环代入、更多层循环、超长代码追踪 |
| 文科轨 | 语言/阅读/写作/历史 | L1-L10 维度（下表） | 生僻词堆砌、故意晦涩、超纲背景知识、信息重复的长句 |
| 混合轨 | 数学文字题/SAT数学/经济 | 两轨维度按需组合（每题 ≤ 2 个） | 两轨禁止项均生效 |

**数理轨维度速查**（矩阵见框架 §3）：
`D1` 概念辨别（考定义边界）｜`D2` 逆向推理（给结果求条件）｜`D3` 边界情况（n=0/1、退化、参数=0）｜`D4` 参数化（具体数→一般公式）｜`D5` 概念迁移（陌生情境应用）｜`D6` 多步推理链（每步心算可完成，难在链条组织）｜`D7` 反例构造（证伪命题）｜`D8` 错误诊断（找错+修正）｜`D9` 约束优化（多约束求最优）｜`D10` 估算与合理性（数量级、量纲）｜`D11` 证明与论证（为何成立）｜`D12` 信息充分性（条件多余/缺失）

**文科轨维度速查**（矩阵见框架 §4）：
`L1` 句法复杂度（嵌套/插入/长距依赖——长度必须伴随结构层次，信息不重复）｜`L2` 语义精度（近义词 connotation/register 甄别）｜`L3` 推理层级（定位→推断→评价）｜`L4` 结构意识（段落功能/论证结构）｜`L5` 多文本关联（双篇互答）｜`L6` 修辞细腻（反讽/轻描淡写/tone shift）｜`L7` 证据权衡（冲突证据/数据匹配）｜`L8` 隐含信息（言外之意/预设）｜`L9` 逻辑论证（谬误识别/支持削弱）｜`L10` 语境词汇（生词精确义）

**升级操作规则：**
1. 每道题只升级一个维度（诊断性）；Hard 题最多组合 2 个维度
2. 同卷 Easy→Medium→Hard 沿同一维度递进，或每次只加一个新维度
3. 数理轨 Hard 题干扰项 = 错误概念/常见误解，**不是计算错误**
4. 文科轨 Hard 题所有选项自身语法正确，仅语义/逻辑区分；至少 2 个选项"表面正确"
5. 每个升级必须对应明确能力目标（理解/分析/评价/创造），无目标不升级

**反堆料检查清单（生成后逐条自检）：**
- [ ] 数理轨：Hard 题计算量 ≤ Easy 题 3 倍？超过 → 砍计算、换维度
- [ ] 难题不是"更多步骤的同类机械运算"？
- [ ] 文科轨：长句信息不重复（长度 = 结构层次，非形容词堆砌）？
- [ ] 每题只升级一个维度（Hard ≤ 2 个）？
- [ ] 每个升级对应明确能力目标（理解/分析/评价/创造）？无目标不升级
- [ ] Hard 题答案可证明/可验证？不可验证 → 删除或改题
- [ ] 学生做完能提炼可迁移策略？纯堆料题 → 重设计

**难度档案标注（每卷强制）：**
- 试卷源码头部加注释：`% Difficulty Profile` + 分布比例 + 使用维度（见框架 §7 模板）
- 每题源码注释标注 `% diff: easy|medium|hard [D#/L#]`（如 `% diff: hard D6+D3`）
- 答案文件解析末尾标注该题考察维度与能力目标

---

#### 1.6 克隆模式：题目替换策略

**不要直接照搬模板题目！** 克隆结构而非内容：

| 模板元素 | 克隆策略 |
|----------|----------|
| 某题考极限 | 换一组极限表达式（如 x→2 → x→0，多项式 → 三角） |
| 某题考导数应用 | 换场景（如速度 → 增长率，切线 → 线性逼近） |
| 某题考 String 方法 | 换字符串内容、换方法组合 |
| 某题考循环跟踪 | 换循环边界、换数组内容 |
| 简答题场景 | 保留题型结构（如"面积+旋转体"），换函数和边界 |

**结构克隆清单：**

- [ ] 保留题型分布（选择题 n 题 + 简答题 m 题）
- [ ] 保留各部分占比
- [ ] 保留难度比例（简单:中等:困难 ≈ 3:5:2，**除非 `difficulty` 参数显式覆盖**——见 §1.7）
- [ ] 保留每个小题的子题数量（如 FRQ 的 a/b/c/d）
- [ ] 全部替换为新的具体内容

---

### Phase 2: 答案分布编排

#### 2.1 答案分布目标

| 选项数 | 目标分布 |
|--------|----------|
| 4 选项 (A-D) | A≈B≈C≈D，各约 25% |
| 5 选项 (A-E) | A≈B≈C≈D≈E，各约 20% |

允许 ±1 题的偏差（如 40 题中 A 出现 9-11 次）。

#### 2.2 调节方法

1. 先写好题目和正确答案（不指定选项位置）
2. 然后将所有正确答案填入分布表，统计各选项出现次数
3. 对出现过多的位置，交换该题正确选项与一个未出现/出现少的选项位置
4. 交换后必须同步调整干扰项位置（即重新排列 A-B-C-D）
5. 验证：交换后所有干扰项仍然保持合理（没有把"严重错误"放到正确选项位置）

#### 2.3 避免可预测规律

- 不要连续 3 题以上相同答案（如 A-A-A）
- 不要形成明显模式（如 A-B-C-D-A-B-C-D）
- 不要因正确答案位置固定让某位置出现过多"正确"

---

### Phase 3: LaTeX 排版 — 纸张节省专项

这是本 skill 的核心特色。所有排版决策围绕**最大信息密度 + 最小纸张消耗**。

#### 3.1 文档配置

```latex
\documentclass[9pt,twocolumn,letterpaper]{extarticle}
% 使用 extarticle 支持 9pt（article 类不支持 9pt，会静默回退到 10pt）
% 9pt 比常规 10pt/11pt 节省约 10-15% 空间
% twocolumn 替代 multicols 环境，更高效利用页面

\usepackage{amsmath,amssymb}
\usepackage{enumitem}  % inputenc utf8 省略——LaTeX 2018+ 默认 UTF-8
\usepackage[margin=0.3in]{geometry}
% 0.3in 边距比常见 0.35in 进一步压缩
% 注意：无需加载 multicol 包——twocolumn 文档类选项已提供双栏
\pagestyle{empty}

% --- 极致紧凑设置 ---
\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}                    % 段落间不空行
\setlength{\columnsep}{0.25in}               % 栏间距压缩
\setlength{\topskip}{0pt}
\setlength{\headsep}{0pt}
\setlength{\footskip}{0pt}

% --- 列表间距压缩 ---
\setlist[enumerate]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}
\setlist[enumerate,2]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}

% --- 数学间距压缩 ---
\setlength{\abovedisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\belowdisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\abovedisplayshortskip}{0pt plus 1pt}
\setlength{\belowdisplayshortskip}{0pt plus 1pt}
```

#### 3.2 纸张节省排版检查清单

| 项目 | 推荐值 | 说明 |
|------|--------|------|
| 字号 | **9pt** 或 10pt | 9pt 每页多容纳约 15% 内容 |
| 纸张 | **letterpaper** (US) 或 **a4paper** | 保持默认网格 |
| 边距 | **0.3in** 或 **0.25in** | 最小安全边距，打印仍可接受 |
| 布局 | **twocolumn** (文档类) 或 `\begin{multicols}{2}` | 双栏布局 |
| 栏间距 | **0.2-0.25in** | 减少栏间空白 |
| 列表间距 | **nosep + itemsep=0pt + topsep=0pt** | 消除列表内外所有多余间距 |
| 数学间距 | abovedisplayskip ≤ 2pt | 公式前后压缩 |
| 段落间距 | **parskip=0pt** | 段落间不空行 |
| 页眉页脚 | 无 (pagestyle{empty}) | 省去页眉页脚占位 |
| 答案位置 | **答案文件单独生成**（见 Phase 4） | 试卷中不含答案 |
| 行距 | 默认 (不做 \linespread) | 压缩行距牺牲可读性得不偿失 |
| 图片 | 不用图片，用文本替代 | 图片极占空间 |

#### 3.3 模板

```latex
\documentclass[9pt,twocolumn,letterpaper]{extarticle}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage[margin=0.3in]{geometry}
\pagestyle{empty}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0pt}
\setlength{\columnsep}{0.2in}

\setlist[enumerate]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}
\setlist[enumerate,2]{leftmargin=*,nosep,itemsep=0pt,parsep=0pt,topsep=0pt}

\setlength{\abovedisplayskip}{2pt plus 1pt minus 1pt}
\setlength{\belowdisplayskip}{2pt plus 1pt minus 1pt}

\begin{document}

%% ===== TITLE =====
{\Large\bfseries Subject --- Exam Title}
\hfill
{\itshape N Questions}
\vspace{0.2cm}

%% ===== QUESTIONS =====
\begin{enumerate}[label=\textbf{\arabic*.}]

%% -- Question template --
\item Stem text ...
\begin{enumerate}[label=(\Alph*)]
    \item Option A
    \item Option B
    \item Option C
    \item Option D
\end{enumerate}

%% -- More questions --
\end{enumerate}

\end{document}
```

#### 3.4 答案文件模板 (`answer_key.tex`)

试卷 `exam.tex` **不含任何答案**。答案单独生成在 `answer_key.tex` 中，同样用 tectonic 编译。

```latex
\documentclass[9pt,letterpaper]{extarticle}
\usepackage[margin=0.5in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\pagestyle{empty}

\setlist[enumerate]{leftmargin=*,nosep}
\setlength{\parindent}{0pt}

\begin{document}

{\Large\bfseries Answer Key --- [Exam Title]}
\vspace{0.3cm}

%% ===== MCQ ANSWER TABLE =====
\noindent\textbf{Section I: Multiple Choice}
\medskip

\noindent
\begin{tabular}{@{}c|c@{\hspace{1.2em}}c|c@{\hspace{1.2em}}c|c@{}}
\hline
\# & Ans & \# & Ans & \# & Ans \\
\hline
1  & A & 11 & C & 21 & B \\
2  & D & 12 & A & 22 & D \\
% ...
\hline
\end{tabular}

\vspace{0.5cm}

%% ===== FRQ SOLUTIONS =====
\noindent\textbf{Section II: Free Response}
\medskip

\noindent\textbf{Question 1}\\[0.3em]
\begin{enumerate}[label=\alph*.)]
    \item $\displaystyle \text{[solution]}$
    \item $\displaystyle \text{[solution]}$
\end{enumerate}

\noindent\textbf{Question 2}\\[0.3em]
% ...

%% ===== DISTRACTOR ANALYSIS =====
\vspace{0.3cm}
\noindent\textbf{Answer Justifications}
\medskip

\noindent\textbf{1.} Correct: A. \hfill Distractors: B (sign error), C (formula confusion), D (off-by-one)\\
\textbf{2.} Correct: D. \hfill Distractors: A (chain rule order), B (missing inner derivative), C (wrong antiderivative)\\

\end{document}
```

**答案文件包含：**
- 选择题答案表（紧凑多列格式）
- 简答题完整解答步骤
- 每题干扰项分析（可选，用于教师版）

#### 3.5 极端纸张节省技巧（经验之谈）

1. **加题不加页**：若剩余空间能塞下 1-2 题，调整题目长度使之适配
2. **公式内联**：能行内公式 `$(...)$` 的就不用显示公式 `\[...\]`，除非必要
3. **合并短题**：若两题都非常短，考虑合并为"一题两问"（如 a) ... b) ...）
4. **`\dfrac` 只在必要时用**：简单分数用 `\frac` 即可，省垂直空间
5. **单位紧凑**：`cm$^3$/s` 优于 `cm$^3$ / s`
6. **不用 `\displaystyle` 在选项中**：选项里的积分/求和保持行内大小
7. **题干和选项之间不要空行**：连续排版
8. **答案表复用模板**：预先设计不含题号的 `\foreach` 模板，填题号即可
9. **答案紧凑排列在答案文件中**：答案 `_answer_key.tex` 中也用紧凑排版，多题答案可共用一页

---

### Phase 4: 答案文件单独生成（强制）

**答案与试卷必须分离为两个独立文件**。试卷中不出现任何答案或解答。

#### 4.1 逐题答案记录

设计每道题时必须同步记录：

```
题号: 3
正确答案: C
验证过程: [逐步推导]
干扰项分析:
  A: 典型错误——忘记取绝对值 → 得 -5
  B: 典型错误——混淆链式法则顺序 → 得 2x·sin(x)
  D: 典型错误——漏掉内层导数 → 得 cos(x²)
```

#### 4.2 生成 `answer_key.tex`

使用 §3.4 的模板，将上述记录填入：

**答案表**：选择题答案以多列紧凑表格呈现
- 40 题以下用 3 列（# / Ans / # / Ans / # / Ans）
- 40 题以上用 4 列

**解答步骤**：简答题提供完整推导
- 每个子题（a/b/c/d）单独列步骤
- 关键中间结果标注
- 最终答案加粗或框出

**干扰项分析**（可选但推荐）：
- 每题一行，标注正确选项 + 各干扰项的错误原因

```latex
\noindent\textbf{3.} Correct: C. \hfill Distractors: A (missing abs), B (chain rule order), D (inner derivative)\\
```

#### 4.3 答案验证（强制）

**在答案文件中，必须对每道题进行验证**（写入答案文件内容前）：

| 题型 | 验证方法 |
|------|----------|
| 数学计算题 | 逐步推导，确认最终值 |
| 概念题 | 确认概念定义无偏差 |
| 代码跟踪题 | 逐行模拟执行 |
| 代码写作题 | 确认语法正确、逻辑完整 |
| 图形/几何 | 检查数值合理性 |

#### 4.4 完整性检查

- [ ] 试卷不含任何答案标记
- [ ] 答案表中题号与试卷一一对应
- [ ] 答案分布符合目标（各选项出现次数偏差 ≤ 1）
- [ ] 简答题有完整解答步骤
- [ ] 每道选择题的干扰项已标注错误来源

---

### Phase 4.5: 写入 .tex 文件

在编译前，将设计好的内容写入两个 .tex 文件。

#### 4.5.1 构建文件名

根据 §0 的输入参数构建文件名：
```
{subject}_{exam_type}_{output_name}.tex            → 试卷源码
{subject}_{exam_type}_{output_name}_answer_key.tex → 答案源码
```

若 `subject` 为空，则从模板文件名或 `topics` 推断；若 `exam_type` 为空，默认用 `Practice`。

#### 4.5.2 写入试卷文件

使用 `write` 工具创建 `{subject}_{exam_type}_{output_name}.tex`：
1. 应用 §3.3 的模板结构
2. 填入 Phase 1 设计的题目内容
3. **不包含**答案表、解答步骤、干扰项分析
4. 检查所有 `\ref` / `\label` 一致性

#### 4.5.3 写入答案文件

使用 `write` 工具创建 `{subject}_{exam_type}_{output_name}_answer_key.tex`：
1. 应用 §3.4 的答案模板结构
2. 填入 Phase 4 整理的答案表、解答步骤、干扰项分析

> **写入前必须先执行 Git 安全网步骤**（见 §Git 安全网 + 文件写入安全）
> 用 `find` 或 `read` 确认目标文件是否已存在，已存在时优先用 `edit` 而非 `write`。

---

### Phase 5: 双文件编译

#### 5.1 编译试卷和答案

> 本 skill 仅使用 tectonic 编译（产出全英文，无需 xelatex 回退）。

```bash
cd "{output_dir}"
# 编译试卷
 tectonic "{subject}_{exam_type}_{output_name}.tex"
# 编译答案
 tectonic "{subject}_{exam_type}_{output_name}_answer_key.tex"
```

编译完成后清理中间文件（`.aux` `.bbl` `.blg` `.log` `.out` `.toc` `.synctex.gz` 等），只保留 `.tex` 与 `.pdf`：
```bash
rm -f "{subject}_{exam_type}_{output_name}".{aux,bbl,blg,log,out,toc,synctex.gz} \
      "{subject}_{exam_type}_{output_name}_answer_key".{aux,bbl,blg,log,out,toc,synctex.gz}
```

**预期产物：**
```
{subject}_{exam_type}_{output_name}.tex              → 试卷 LaTeX 源码（不含答案）
{subject}_{exam_type}_{output_name}.pdf              → 试卷 PDF（给学生）
{subject}_{exam_type}_{output_name}_answer_key.tex   → 答案 LaTeX 源码
{subject}_{exam_type}_{output_name}_answer_key.pdf   → 答案 PDF（给教师）
```

示例：
- `AP_Calculus_BC_Practice_Test_1.tex` + `AP_Calculus_BC_Practice_Test_1_answer_key.tex`
- `Linear_Algebra_Quiz_Midterm.tex` + `Linear_Algebra_Quiz_Midterm_answer_key.tex`

#### 5.3 编译异常处理

| 症状 | 处理方式 |
|------|----------|
| `Underfull \hbox` 警告 | 无操作——排版警告可忽略，不影响内容 |
| `Overfull \hbox` | 在对应行加 `\emergencystretch=0.5em` 或调整换行 |
| 缺少宏包错误 | tectonic 首次使用会自动联网拉取宏包；持续失败检查网络或重试（全英文产出无需 xelatex） |
| LaTeX 语法错误 | 定位错误行修复后重新编译 |
| tectonic 未安装 | `cargo install tectonic`，或发行版包管理器（apt/pacman 的 tectonic 包） |

#### 5.4 验证输出

编译完成后检查：

- [ ] 试卷 PDF 正常生成，页数合理
- [ ] 答案 PDF 正常生成
- [ ] 所有数学公式渲染正确
- [ ] 选项对齐正常
- [ ] 试卷中不含任何答案标记
- [ ] 无内容被截断或溢出页边距

#### 5.5 答案正确性最终核查（强制）

**这是最关键的一步。生成流程结束后，必须对所有答案进行逐题正确性核查。**

AI 有编造答案的倾向，尤其在试题量大的情况下。此步骤不可跳过。

**核查流程：**

1. **逐一对照**：打开 `_answer_key.tex`，对每个题号，去 `.tex` 源码中找到对应题目
2. **验证每题**：对每道题重新做一遍（计算/推导/代码跟踪），确认答案表中的选项确实正确
3. **标记可疑**：若发现某题答案存疑，立即重新计算。不确定时用 subagent 求助或搜索确认
4. **修复错误**：发现错误后：
   - 修复 `_answer_key.tex` 中的答案
   - 如果错误是因题目本身设计问题导致，同时修复 `.tex` 中的题目
   - 重新编译两个文件
5. **二次核查**：修复后再次确认所有答案正确
6. **最终确认**：确认后才可报告任务完成

**核查记录模板（直接在回复中输出）：**
```
=== 答案核查 ===
Q1: C → 验证: lim_{x→0} sin(x)/x = 1 ✅
Q2: D → 验证: 链式法则正确 ✅
Q3: A → 验证: ... ❌ 计算错误，应为 B（已修复）
...
总计: N/N 通过
```

**必须生成核查记录并逐题确认后，才能报告任务完成。**

当 `template_path` 为空、仅提供 `topics` 时，采用知识点模式：

### 6.1 知识点拆分

将用户提供的知识点描述拆分为可出题的最小单元：

```
用户输入: "极限与连续，导数定义，洛必达法则"
→ 拆分:
  1. 极限的 ε-δ 定义
  2. 极限的四则运算
  3. 夹逼定理
  4. 间断点分类
  5. 导数的极限定义
  6. 可导与连续的关系
  7. 洛必达法则适用条件
  8. 洛必达法则应用（0/0, ∞/∞）
```

### 6.2 题目分配

| 知识点粒度 | 每知识点题数 | 说明 |
|-----------|-------------|------|
| 大单元（如"导数应用"） | 4-6 题 | 覆盖子主题 |
| 中主题（如"相关速率"） | 2-3 题 | 覆盖主要变体 |
| 小知识点（如"某定理"） | 1-2 题 | 概念理解 + 简单应用 |

### 6.3 难度分配

难度分布由 `difficulty` 参数决定（默认 auto 沿用模板分布或 standard）：

| 难度模式 | Easy | Medium | Hard | 适用 |
|----------|------|--------|------|------|
| standard（默认） | 30% | 50% | 20% | 常规练习 |
| hard | 15% | 40% | 45% | 强化/考前冲刺 |
| max | 0% | 30% | 70% | 竞赛/拔尖选拔 |

**难度升级的维度选择、操作规则与禁止项见 §1.7 与 `difficulty-escalation-framework.md`**。数理轨严禁以堆砌计算量提升难度；文科轨可用句法复杂度（L1）等维度提升难度。

---

## 输出检查清单

### 试卷内容
- [ ] 所有题目为全英文
- [ ] 题干自包含（不依赖外部图片）
- [ ] 每题恰好一个正确答案
- [ ] 每个干扰项有明确错误来源
- [ ] 无 "All of the above" / "None of the above"
- [ ] 无重复或相似的题目
- [ ] 答案分布均衡（偏差 ≤ 1）

### 难度升级（§1.7 强制）
- [ ] 难度档案已标注（分布比例 + 使用维度，源码头部注释）
- [ ] 每题注释标注难度与维度（`% diff: hard D6+D3`）
- [ ] 数理轨未通过堆砌计算量提升难度（Hard 计算量 ≤ Easy 的 3 倍）
- [ ] 文科轨难度通过句法复杂度/推理层级等维度升级（长句信息不重复）
- [ ] 每题只升级一个维度（Hard ≤ 2 个）
- [ ] Hard 题干扰项对应概念错误（数理轨）/全部语法正确仅语义区分（文科轨）
- [ ] Hard 题答案可验证，解析含完整推理链 + 维度标注

### 排版
- [ ] 使用 9pt 或 10pt 字号
- [ ] 双栏布局（twocolumn 或 multicols{2}）
- [ ] 边距 ≤ 0.3in
- [ ] 所有间距压缩（nosep, parskip=0pt, abovedisplayskip ≤ 2pt）
- [ ] 无页眉页脚
- [ ] LaTeX 语法无错误
- [ ] 标题中的科目占位符已替换为实际名称
- [ ] `\displaystyle` 使用符合 §1.3 规范
- [ ] 纯计算题使用 `\prob` 宏（如适用）
- [ ] 试卷不含任何答案（答案在 `_answer_key.tex` 中）

### 克隆模式额外
- [ ] 题型分布与模板一致
- [ ] 难度分布与模板一致
- [ ] 所有题目数据已更换为新值
- [ ] 选项数一致（模板用 5 个选项则新试卷也用 5 个）

### 编译
- [ ] `{output_name}.tex` + `{output_name}_answer_key.tex` 均编译成功
- [ ] 两张 PDF 均输出正常
- [ ] Overfull hbox 已处理
- [ ] 试卷 PDF 不含答案内容

### 答案文件
- [ ] 选择题答案表与试卷题号一一对应
- [ ] 简答题有完整解答步骤
- [ ] 干扰项分析已标注错误来源
- [ ] 答案分布均衡（偏差 ≤ 1）

### 最终核查（强制）
- [ ] 对答案文件中的每道题进行了重新验证（§5.5）
- [ ] 所有答案计算/推导确认正确
- [ ] 发现的错误已修复并重新编译
- [ ] 核查记录已输出

---

## 关于知识边界

本 skill 涉及的科目范围不限定，AI 的知识覆盖可能不足。

- **出题时必须验证所有计算和推导**，不依赖"记忆中的答案"
- **干扰项设计必须有真实错误来源**，不捏造"看起来合理"的迷惑项
- **数学/科学公式必须逐步验证**，不能仅靠直觉判断正确性
- **若某知识点超出模型训练数据的可靠范围**，明确标记"建议由领域专家审核此部分"

参见 [知识边界规范](../knowledge_boundary.md)。

---

## Git 安全网 + 文件写入安全

本 skill 遵守 [Git 安全网规范](../git_safety_net.md)。

执行 `write` 或 `edit` 前必须：

1. 读取 `git_safety_net.md` 并执行 git 版本追踪指令
2. 用 `find` 或 `read` 检查目标文件是否已存在
3. 文件已存在时优先用 `edit` 修改，不用 `write` 覆写
4. 确需覆写时先告知用户

## 变更日志

### 1.3.0 (2026-08-12)
- §0.3a.2：模型可用性表实测更新——doubao-pro 账号级 429（Safe Experience Mode）移入不可用表；doubao-1.6-vision 404、nemotron-omni 503 标记不可用；新增 nemotron-nano-12b-v2-vl 实测可用（漏读 rationale 需补扫）
- §0.3a.2：Pre-flight 强化——模型 ID 探测（200/404/429/503 分类处理）、fallback 链（4xx 立即换模型）、单次调用必须设 timeout（限流时请求会静默挂起）
- §0.3a.5：新增增量保存（raw.json 断点续跑 + models.json 记录）、模型报题号不可信（以 FOOTER 为准）、rationale 缺失检测与补扫
- §0.3a.11（新增）：服务器端扫描——资源确认防干扰训练、SSH kex reset/频率限制应对（重试包装/单会话多步/base64 传脚本/setsid 后台）、远程 pgrep/pkill 自匹配坑、RapidOCR 1.4.x 返回格式剧变（先探针再写解析）、双路交叉验证

### 1.2.0
- 新增难度升级专项（§1.7）：学科分轨 + 12+10 维度矩阵 + 反堆料检查清单


