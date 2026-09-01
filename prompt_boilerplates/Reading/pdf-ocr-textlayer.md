---
name: pdf-ocr-textlayer
version: 1.2.0
description: 扫描版PDF转为可搜索/可复制的高质量版本——支持文本层PDF（原图+不可见文字）和LaTeX重排版（纯文字），自动处理对开横版扫描
triggers:
  - "扫描版PDF转文字"
  - "PDF加文字层"
  - "OCR转纯文字PDF"
  - "pdf ocr"
  - "文字层PDF"
  - "扫描件转文字"
  - "扫描版转LaTeX"
  - "PDF转排版版"
inputs:
  - name: source_pdf
    description: 源扫描版 PDF 路径
    required: true
  - name: output_mode
    description: '输出模式：textlayer（默认，原图+不可见文本层）、latex（LaTeX重排版）、both（两者）'
    required: false
    default: "textlayer"
  - name: workers
    description: OCR 并发进程数
    required: false
    default: 2
  - name: dpi
    description: 页面渲染分辨率
    required: false
    default: 300
  - name: server
    description: '远程服务器连接串'
    required: false
    default: ""
  - name: delete_originals
    description: '完成后是否删除源文件'
    required: false
    default: "ask"
tools:
  - read
  - write
  - bash
  - grep
  - find
  - subagent
---

# PDF 扫描版转文字层 / LaTeX 版 Skill

> 将扫描版 PDF 转为高质量可读版本。支持两种输出模式：
> 1. **文本层 PDF**（`textlayer`）：原图完整保留，文字以 `render_mode=3` 不可见文本层嵌入，视觉零变化、可搜索/复制
> 2. **LaTeX 重排版**（`latex`）：提取 OCR 文字 → 清洗错误 → 重新排版为书籍格式（无扫描图），用 tectonic 编译
> 3. **两者都要**（`both`）

## 前置询问项（一次性搞定）

开始处理前，先问用户以下问题，避免多次返工。建议用 `ask_user` 工具逐项确认：

| 问题 | 选项 | 默认 | 理由 |
|---|---|---|---|
| 输出模式？ | textlayer / latex / both | textlayer | textlayer 保原图，latex 出纯文字排版 |
| 源 PDF 页面方向？ | 单页竖版 / 对开横版 / 不确定 | 自动检测 | 对开横版（每页两个书页）需拆页，否则阅读序交错 |
| 文字语言？ | 中文 / 英文 / 中英混排 | 自动检测 | 影响 RapidOCR 模型选择和 LaTeX 字体设置 |
| 是否删除原版？ | 保留 / 删除 | 保留 | 删除后不可恢复 |
| 运行环境？ | 本机 / 服务器（SSH） | 本机 | 服务器需先确认资源 |
| 服务器地址（若上一步选服务器）？ | 连接串 | — | `user@host -p port` |

**一次性目标**：用户回答后，全流程自动执行，产出一份"易读的 PDF"。

## 任务目标

将扫描版 PDF（无文字层、每页纯图像）转为高质量文本版本。核心逻辑：

```
问清用户需求 → 渲染页面 → OCR → 据 output_mode 分支：
  ├─ textlayer: 嵌入不可见文本层（保留原图）
  └─ latex: 清洗 OCR 文字 → 修复错误 → LaTeX 排版 → tectonic 编译
```

## 执行流程

### 0. 前置问答（一次性）

按上表逐项问用户，收集所有偏好。然后全自动执行。

### 1. 确认扫描版性质

用 PyMuPDF 检测目标文件：页数、每页文字量与图片数。

```python
import fitz
doc = fitz.open(pdf_path)
for i in range(min(3, len(doc))):
    print(i, 'text=', len(doc[i].get_text().strip()),
          'imgs=', len(doc[i].get_images()))
```

文字量 0 且图片 ≥1 → 纯扫描版，走本流程；有文字层则先剥离再走。

### 2. 检测页面方向（对开横版 vs 单页竖版）

**核心：用像素灰度分析检测是否对开横版扫描**（⚠️ 2026-08-31 实测修正：**先查页面 rect 宽高比**，宽>高才可能是对开；竖版书页即使页眉/正文/页脚空隙多，也绝不会是对开）。

```python
import numpy as np
# ① 先查 rect：宽>高才可能是对开横版（否则直接判单页竖版，跳过灰度分析）
if rect.width <= rect.height:
    is_spread = False
else:
    pix = page.get_pixmap(dpi=150)
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    gray = img[:,:,0]
    # 每列暗像素占比
    dark_col = (gray < 128).sum(axis=0) / pix.height
    smooth = np.convolve(dark_col, np.ones(8)/8, mode="same")
    text = smooth > 0.003
    # 找文字横向区间
    runs = []; in_run = False
    for i in range(pix.width):
        if text[i] and not in_run: start = i; in_run = True
        elif not text[i] and in_run: runs.append((start,i)); in_run = False
    if in_run: runs.append((start, pix.width))
    main = [r for r in runs if (r[1]-r[0]) > pix.width*0.05]
    is_spread = len(main) >= 2 and (main[1][0]-main[0][1]) > pix.width*0.02
```

**发现对开横版后的处理**：
- 用 gutter 中点作为 split 线
- 左右半页各自独立 OCR（避免跨页合并）
- 拆成两个竖版书页输出（每页 portrait，单列文本）
- 参见 §1.1 对开横版详解

### 3. 选运行环境

- 本机跑：确认 `rapidocr-onnxruntime` 与 `pymupdf` 已装（`pip show rapidocr-onnxruntime pymupdf`）
- 服务器跑：先确认资源再开工（防干扰既有任务）：

```bash
ssh root@host -p port 'uptime; free -h; df -h /; ps aux --sort=-%cpu | head -5'
# 或用 pi-resmon 检查
pi-resmon --recommend --class medium
```

- 无 GPU 完全可行（RapidOCR 纯 CPU）
- 上传源 PDF：`rsync -avz -e "ssh -p port" "源.pdf" root@host:/tmp/scan_input/书名.pdf`——目标目录须先 `mkdir -p`
- 服务器上装依赖：`pip install rapidocr-onnxruntime pymupdf`

### 4. 渲染页面 + OCR（核心）

**四步走**：渲染 → 检测页面方向 → 并行 OCR → 根据 output_mode 分支。

#### 4.1 渲染

`page.get_pixmap(dpi=DPI)` 转 PNG（300 dpi 起步）。

#### 4.2 对开横版检测（如没有前置问答则自动检测）

用 §2 的像素灰度分析。若 `is_spread=True`，gutter split 中点 = `(main[0][1] + main[1][0]) // 2`。

#### 4.3 并行 OCR

```python
from concurrent.futures import ProcessPoolExecutor

def process_page(args):
    pdf_path, page_index, dpi, out_dir = args
    import fitz
    doc = fitz.open(pdf_path)
    page = doc[page_index]
    rect = page.rect
    pix = page.get_pixmap(dpi=dpi)
    is_spread, split_pt, W, H = detect_gutter(pix, rect)
    if is_spread:
        # 对开页：左半页 + 右半页分别 OCR
        lp = page.get_pixmap(dpi=dpi, clip=fitz.Rect(0, 0, split_pt, rect.height))
        # → OCR 左半页
        rp = page.get_pixmap(dpi=dpi, clip=fitz.Rect(split_pt, 0, rect.width, rect.height))
        # → OCR 右半页
        # 返回两个输出页信息
    else:
        # 单页直接 OCR
        lines = ocr_lines(full_path)
```

**多进程坑**：每 worker 必须独立创建 `RapidOCR()` 实例，主进程创建的不能 pickle。

**OCR 返回格式**（rapidocr-onnxruntime 实测）：`(result, elapse)`，result 为列表，每元素 `[box, text, score]`；box 为 4 角点 `[[x1,y1],[x2,y2],[x3,y3],[x4,y4]]`（像素坐标）。**写解析前先探针**。

#### 4.4 分支：textlayer 模式

**嵌入不可见文本层（⚠️ 勿用 `insert_text`，有 32 字符截断限制）：**

```python
# ❌ 错误做法（有 32 字符限制）：
page.insert_text(fitz.Point(x, y), text, fontname="china-s", fontsize=fs, render_mode=3)

# ✅ 正确做法（用 TextWriter，无字符限制）：
tw = fitz.TextWriter(page.rect)
font = fitz.Font("china-s")
for x0, y0, x1, y1, text, conf in lines:
    fs_h = (y1 - y0) * 0.98 * scale
    if fs_h < 2: continue
    # 自适应字号：取行高 vs 行宽 的较小值，防超出页面宽度被裁剪
    w_px = x1 - x0
    if w_px > 0 and text:
        fs_w = w_px * scale / max(font.text_length(text, 1), 0.1)
    else:
        fs_w = fs_h
    fs = min(fs_h, fs_w)
    tw.append(fitz.Point(x0*scale, y0*scale+fs*0.8), text, font=font, fontsize=fs)
tw.write_text(page, render_mode=3)
```

**`insert_text` 之坑（2026-08-31 实测）**：
- `insert_text` 对 CJK 字体（`china-s`）限制 32 字符，英文长行（50+ 字符）被截断
- 务必用 `TextWriter` + `write_text(page, render_mode=3)`
- `TextWriter` 的 `page.rect` 做 width 检查：文本超出页面宽度时被 `write_text` 裁剪（因为 `china-s` 拉丁字形较宽）。**必须用自适应字号**（`fs = min(fs_h, fs_w)`，`fs_w = box_width / font.text_length(text, 1)`）确保每行文本不超出检测框宽度。

**字体**：`china-s` 内置 CJK 字体，中文英文都能嵌。

#### 4.5 分支：latex 模式

**OCR 文本 → 清洗 → LaTeX 排版 → tectonic 编译。**

##### 4.5.1 提取 OCR 文本

从 textlayer 的 OCR 结果或直接 `pdftotext` 提取。输出为段落格式（每段一行，空行分隔）。

##### 4.5.2 清洗 OCR 错误

使用字典修复常见 OCR 错误（英文扫描常见）：

```python
FIXES = [
    (r'\bsoine\b', 'some'), (r'\bfrst\b', 'first'),
    (r'\b1 know\b', 'I know'), (r'\b1 have\b', 'I have'),
    # l→h, m→n, b→h 等模式
    (r'\blody\b', 'body'), (r'\bluas\b', 'has'),
    (r'\bwns\b', 'was'), (r'\bwus\b', 'was'),
    (r'\bhorn\b', 'born'), (r'\bliis\b', 'his'),
    # ... 完整字典见附录
]
for pat, repl in FIXES:
    text = re.sub(pat, repl, text)
```

##### 4.5.3 生成 LaTeX

```latex
\documentclass[11pt,a5paper]{book}
\usepackage[T1]{fontenc}
\usepackage{ebgaramond}
\usepackage[parfill]{parskip}
\setcounter{chapter}{N-1}  % 设章号
\chapter{Title}
% 文本段落...
\end{document}
```

##### 4.5.3a 中文 LaTeX（实测 2026-08-31，费希特《伦理学体系》清洗失败后以摩尔《伦理学原理》长河译成功）

**必须用 xelatex 引擎的 CJK 前导码（tectonic 可直接跑，无需切 xelatex）：**

```latex
\documentclass[11pt,a5paper]{book}
\usepackage[top=1.8cm,bottom=1.8cm,left=1.5cm,right=1.5cm]{geometry}
\usepackage{fontspec}
\setmainfont{Noto Sans SC}          % 静态 TTF，勿用可变 TTC（xdvipdfmx fatal）
\XeTeXlinebreaklocale "zh"          % ← 缺这两行 = 中文整串不换行
\XeTeXlinebreakskip = 0pt plus 1pt
\usepackage{setspace}
\onehalfspacing
\usepackage{fancyhdr}
\pagestyle{plain}
\usepackage[parfill]{parskip}
\setlength{\parindent}{2em}        % 中文首行缩进两字
\usepackage{hyperref}

\title{伦理学原理}
\author{G. E. Moore（乔治·摩尔）\\ 长河 译}
\begin{document}
\frontmatter
\maketitle
\thispagestyle{empty}
\mainmatter
\chapter{第一章  伦理学的研究对象}  % 章节名直接带“第X章”全称
% 文本段落...
\end{document}
```

**中文 LaTeX 关键坑（均为实测）：**

| 坑 | 症状 | 解法 |
|---|---|---|
| 缺 `\XeTeXlinebreaklocale "zh"` | 中文长句整串不换行 → Overfull hbox 大超宽（实测 36pt） | 前导码必须加；诊断时先查断行，勿先调列宽（调窄更恶化） |
| 控制序列后紧跟中文 | `\dots`/`\ldots` 后直接写中文 → `Undefined control sequence`（CJK 字符并入控制序列名） | `\dots{}` 空组隔离 |
| 用可变 TTC 字体 | `xdvipdfmx fatal` 崩溃 | 用静态 TTF（`~/.fonts/NotoSansSC-Regular.ttf`） |
| `\chapter` 名带“第”字 | 若脚本用 `ch[len("第"):]` 截断 → 输出“一章/二章”错名 | 章节标题直接存全称“第X章 标题”，`\chapter{全称}` |
| 中文引号 | `“”` 是正常字符 | 保留（勿按英文 FIXES 把 `“`→`"`） |

**中文 OCR 文本清洗要点（与英文不同）：**

- **RapidOCR ch 模型对中文识别率极高（~99%）**，正文几乎无需字符级纠错；主要工作不是错字而是**结构清洗**
- **页眉必须过滤**：中文书每页顶部重复书名/章节名（如“伦理学原理”“第一章伦理学的研究对象”），OCR 全识别进来。用黑名单集合精确匹配（含 OCR 变体如“形面上学”“关子行为”）
- **孤立页码行**：`^\s*\d+\s*$` 且 ≤4 位 → 删除
- **章节标题 vs 页眉冲突**：章节标题（“第四章”）是独立成行，页眉是“第四章形而上学的伦理学”。过滤规则要先滤页眉长串，再识别章节短标题——否则误删真实章节标题
- **版前页（封面/版权/出版说明/目录）跳过**：从第一个“序”或“第X章”才进入正文
- **目录条目**：形如 `序/1`、`第一章 伦理学的研究对象/6`，含页码 → 整段跳过
- **脚注/译者注**：OCR 把脚注识别为行内文本（如 `——译者注`），可保留为行内括号说明，不强行转 LaTeX 脚注（工作量大且易错）
- **标点修复**：中文书 OCR 常见 `一`（破折号误读）、`，，` 双标点、`一一` → 统一
- **中文特殊字符**：`★`（注释标记）、`①` 等圈号保留即可

**中文书识别结构（标准排版）：** 封面/版权页（跳过）→ 丛书说明（跳过）→ 目录（跳过）→ 序 → 第X章（每章可多页）→ 附录/译名对照表（可选保留）


##### 4.5.4 编译

```bash
tectonic book.tex
```

### 5. 旧文本层剥离（如源 PDF 已有旧 OCR 层）

源 PDF 可能已有不可见文本层（旧 OCR 乱码），嵌入新层前必须剥离。

**方法：删除内容流中的 BT...ET 文本块**：

```python
import re
cs = page.read_contents()
page.clean_contents()
xref = page.get_contents()[0]
# 删除 BT...ET 平衡文本块
cleaned = re.sub(rb'BT.*?ET', b'', cs, flags=re.S)
doc.update_stream(xref, cleaned)
```

**验证**：剥离后 `page.get_text()` 应返回空字符串，但渲染图像应完全不变（像素 diff = 0）。

### 6. 验证输出

```python
doc = fitz.open(out)
for i in range(3):
    print(i, 'text=', len(doc[i].get_text().strip()))
print('imgs_preserved=', len(doc[0].get_images()))
```

- textlayer 模式：文字量 > 0 且图片数不减 → 成功
- latex 模式：`pdfinfo out.pdf` 检查页数

### 7. 回传与清理

- 服务器产物 `scp`/`rsync` 回本地
- 按用户选择的 `delete_originals` 删除源文件
- 清理中间文件（渲染 PNG、临时脚本、模型缓存等）

## 输出格式

| 模式 | 命名 | 内容 |
|---|---|---|
| textlayer | `原名_OCR.pdf` | 原图 + 不可见文本层 |
| latex | `原名.pdf` + `原名.tex` | LaTeX 重排版 + 源代码 |
| both | 两者 | 全要 |

## 注意事项

### 环境兼容性

- **PaddleOCR 勿用（本机 CPU 环境）**：paddlepaddle 3.3.1 + numpy 2.4 二进制不兼容（`ValueError: numpy.dtype size changed`）；且 Broadwell 无 AVX512 时 MKL 报 `Intel MKL function load error`。RapidOCR（ONNX Runtime）零 MKL 依赖，即装即用
- **numpy 版本冲突**：装 `paddle2onnx` 或 `onnx` 包可能把 numpy 拉回 2.x，导致 pandas/pyarrow/torch import 崩。降级并固定：`pip install "numpy==1.26.4"`

### 文本层嵌入

- **`insert_text` 对 CJK 字体有 32 字符限制**（2026-08-31 实测）。英文长行（50+ 字符）被截断。必须用 `TextWriter` 替代
- **`TextWriter` 自适应字号**：防超宽文本被页面矩形裁剪
- **`china-s` 字体**：内置 CJK 字体，拉丁字形偏宽，需用 `font.text_length()` 计算宽度
- **`render_mode=3`** 不可见文本层；`render_mode=0` 可见

### 对开横版扫描

- 像素 gutter 检测比 OCR 框聚类更可靠（OCR 框可能跨 gutter 合并）
- 分半后各自 OCR（避免跨列合并 + 截断）
- 拆页后每页 portrait，阅读序正确（左书页→右书页）

### 多进程 & 资源

- 每 worker 独立 `RapidOCR()` 实例
- worker 数 ≈ 核数 × 0.7；ONNX 超订时减到 2
- `pi-resmon --recommend` 检查资源后再启动

### 英文 OCR 质量

- RapidOCR ch 模型（PP-OCRv4）含拉丁字符，英文识别率 ~95%；专名、艺术字偶误
- 常见系统错误：`l→h`、`m→n`、`1→I`、`o→c`、`frst→first`、`soine→some`
- 字典修复能覆盖 80%+ 错误；如需精校可派子代理通读
- 英文专用模型（PP-OCRv4_en_rec）的 paddle2onnx 转换有 Concat 缺陷（2026-08-31 实测），建议用 ch 模型 + 字典修复

## 附录：常见 OCR 错误修复字典（英文）

```python
FIXES = [
    (r'\bsoine\b', 'some'), (r'\bfrst\b', 'first'),
    (r'\b1 know\b', 'I know'), (r'\b1 have\b', 'I have'),
    (r'\b1 am\b', 'I am'), (r'\b1 do\b', 'I do'),
    (r'\b1 was\b', 'I was'), (r'\b1 may\b', 'I may'),
    (r'\b1 can\b', 'I can'), (r'\b1 shall\b', 'I shall'),
    (r'\bto bo\b', 'to be'), (r'\bwns\b', 'was'),
    (r'\bwus\b', 'was'), (r'\bluas\b', 'has'),
    (r'\bllving\b', 'living'), (r'\bllfe\b', 'life'),
    (r'\bllke\b', 'like'), (r'\bllme\b', 'time'),
    (r'\bllnes\b', 'times'), (r'\blln\b', 'in'),
    (r'\blody\b', 'body'), (r'\blluman\b', 'human'),
    (r'\bthc\b', 'the'), (r'\bcarth\b', 'earth'),
    (r'\bwrlth\b', 'with'), (r'\bwithoul\b', 'without'),
    (r'\bunderlng\b', 'undergoing'), (r'\bmoing\b', 'going'),
    (r'\bchunges\b', 'changes'), (r'\bdlintance\b', 'distance'),
    (r'\bcnvironment\b', 'environment'), (r'\bevrry\b', 'every'),
    (r'\bmmny\b', 'many'), (r'\bnuany\b', 'many'),
    (r'\bholdling\b', 'holding'), (r'\bwenring\b', 'wearing'),
    (r'\bolacrving\b', 'observing'), (r'\bjrerived\b', 'perceived'),
    (r'\bnluut\b', 'about'), (r'\bwitliout\b', 'without'),
    (r'\bexpectalions\b', 'expectations'),
    (r'\bpropasitions\b', 'propositions'),
    (r'\bassumplion\b', 'assumption'),
    (r'\bexislence\b', 'existence'), (r'\bbolh\b', 'both'),
    (r'\bihis\b', 'this'), (r'\bwhiich\b', 'which'),
    (r'\bconneclion\b', 'connection'),
    (r'\bproposilion\b', 'proposition'),
    (r'\bdifferenl\b', 'different'),
    (r'\bneccssarily\b', 'necessarily'),
    (r'\bconceivcd\b', 'conceived'),
    (r'\bdescriplion\b', 'description'),
    (r'\bcuuld\b', 'could'), (r'\bwouId\b', 'would'),
    (r'\bshouId\b', 'should'), (r'\bcertainIy\b', 'certainly'),
    (r'\bimportanl\b', 'important'),
    (r'\bhmay\b', 'which may'), (r'\bseern\b', 'seem'),
    (r'\blruc\b', 'true'), (r'\bhorn\b', 'born'),
    # 标点 & 格式
    (r'—', '---'), (r'–', '--'),
    (r'“', '"'), (r'”', '"'), (r"'", "'"),
    (r'（', '('), (r'）', ')'),
]
```

## 变更日志

### 1.2.0 (2026-08-31)
- **新增中文 LaTeX 重排版完整前导码**（§4.5.3a）：fontspec + Noto Sans SC 静态 TTF + `\XeTeXlinebreaklocale "zh"` 断行设置
- **新增中文 LaTeX 坑表**：断行设置缺失/控制序列后中文/可变 TTC 崩溃/章节名截断/中文引号保留
- **新增中文 OCR 清洗要点**：中文识别率极高（~99%），重点在结构清洗（页眉黑名单/孤立页码/目录跳过/版前页跳过），而非字符纠错
- **新增章节标题 vs 页眉冲突处理**：先滤页眉长串再识别章节短标题
- **新增页面方向检测修正**：先查 rect 宽高比（宽>高才可能是对开），再查文字区间——竖版书页的页眉/正文/页脚空隙会被误判为对开
- **实测验证**：摩尔《伦理学原理》长河译 223 页扫描版 → RapidOCR → 清洗 → tectonic 编译 → 218 页 A5 PDF（777KB）

### 1.1.0 (2026-08-31)
- **新增前置询问项**：一次性问清输出模式、页面方向、语言、删除原版等
- **新增对开横版检测**：像素 gutter 分析 + 分半 OCR + 拆页
- **新增 TextWriter 替代 insert_text**：解决 CJK 字体 32 字符截断限制 + 自适应字号防裁剪
- **新增旧文本层剥离**：BT...ET 操作符删除 + 视觉不变验证
- **新增 LaTeX 重排版模式**：OCR 清洗 → 字典修复 → LaTeX 排版 → tectonic 编译
- **新增英文 OCR 错误修复字典**（附录）
- **新增资源检查**：`pi-resmon` 前置调用
- **新增 numpy 版本冲突处理**：`pip install "numpy==1.26.4"`

### 1.0.0 (2026-08-31)
- 初始发布。沉淀 2026-08-31 实战：3 本中文扫描书经服务器 RapidOCR + PyMuPDF 转文字层 PDF