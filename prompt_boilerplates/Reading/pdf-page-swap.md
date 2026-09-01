---
name: pdf-page-swap
version: 1.0.0
description: 用另一本同书 PDF 的封面、前几页、尾页替换目标 PDF 对应页，产出合并版 PDF
triggers:
  - "pdf换页"
  - "替换封面"
  - "封面换页"
  - "pdf page swap"
  - "换封面页"
  - "用另一本替换"
inputs:
  - name: target_pdf
    description: 目标 PDF 路径（被替换页的）
    required: true
  - name: source_pdf
    description: 源 PDF 路径（提供封面与首尾页的）
    required: true
  - name: front_pages
    description: '源 PDF 前部替换页范围（如 "0-3"），缺省自动判定'
    required: false
    default: "auto"
  - name: back_pages
    description: '源 PDF 尾部替换页范围（如 "463-465"），缺省自动判定'
    required: false
    default: "auto"
  - name: output_pdf
    description: 输出路径，缺省为目标同目录加 -swapped 后缀
    required: false
    default: "auto"
tools:
  - read
  - write
  - bash
  - grep
  - find
  - subagent
  - ask_user
---

# PDF 换页 Skill

> 手头 PDF 封面丑（带 "NOT FOR RESALE" 水印）、首尾空白页多；另有一份同书实体书扫描，封面与前尾页干净。取后者之封面、前几页、尾页，替换前者对应页，得美观完整版。两版常为不同版本、页数迥异（实战：4e 教师版 918 页 + 7e 学生版 466 页 → 909 页），映射按内容对应，非页码对应。

## 任务目标

用源 PDF 的封面、前几页、尾页替换目标 PDF 对应区域，生成新 PDF。保留目标 PDF 版权页起的全部正文。核心保障：替换范围须经文本 + 视觉双重确认，防误删有用表页、防映射错位。

## 执行流程

### 1. 核对两文件基本信息

用 `pdfinfo` 或 pymupdf 读取两文件：页数、页面尺寸分布、首尾页文本。记录版本差异（书名页版本号、版权页年份）。

```bash
pdfinfo "$TARGET_PDF" | head -12
```

### 2. 分析首尾页结构

提取目标 PDF 前 12 页、末 12 页文本，识别空白页、乱码页、半书名页、书名页、参考表、后封面：

```python
for i in list(range(0, 12)) + list(range(doc.page_count - 12, doc.page_count)):
    print(i, '|', doc[i].get_text().strip().replace(chr(10), ' ')[:80])
```

渲染首尾候选页为图片（70-100 dpi），派视觉子代理分类。任务描述须含：

- 逐页问询：是封面/空白/衬页/半书名页/书名页/参考表/后封面？
- 显式警告：页若空白如实报空白，禁编造文字（参考 pdf-cover-removal 幻觉教训）
- 重点问询：目标版尾部空白页前后有无统计表（Z 表/t 表/χ² 表续页），勿误删

### 3. 确定替换映射

按内容对应，勿按页码对应：

- **前部**：源 PDF 封面 + 前几页（封面照、财产页、About the Cover、书名页）→ 替换目标 PDF 封面 + 空白衬页 + 半书名页 + 书名页区域
- **主体**：目标 PDF 版权页起至正文结束，原样保留
- **尾部**：源 PDF 尾页（参考表、书末速查表）→ 替换目标 PDF 尾部空白页、乱码页、旧参考表、后封面区域
- 目标版尾部若有未重复的有用附录表（随机数字表、χ² 表续页），保留之

### 4. PyMuPDF 合并

```python
import fitz
out = fitz.open()
out.insert_pdf(x, from_page=0, to_page=3)      # 前部替换（源 0-3）
out.insert_pdf(z, from_page=7, to_page=908)    # 主体保留（目标 7-908）
out.insert_pdf(x, from_page=463, to_page=465)  # 尾部替换（源 463-465）
out.save(out_path, garbage=4, deflate=True)
```

### 5. 验证

- **页数校验**：原 918 → 新 909（4 + 902 + 3），数与映射一致
- **文本抽查**：新 PDF 首 4 页、末 3 页文本对应预期
- **视觉复核**：渲染新首尾页，派视觉子代理确认无白屏、无错位、封面显示正常
- **书签大纲**：目标 PDF 有 toc 时，检查页码偏移（前部页数差 + 尾部页数差），偏移大则重建或删除大纲

## 输出格式

新 PDF（默认 `{target_pdf 目录}/原文件名 - swapped.pdf`），目标原文件不动。汇报替换映射与页数变化：

| 项目 | 内容 |
|---|---|
| 前部替换 | 源 0-3（封面照/财产页/About the Cover/书名页）→ 目标 0-6（封面/空白衬页/半书名页/书名页） |
| 尾部替换 | 源 463-465（随机数字表/Assumptions/Quick Guide）→ 目标 910-917（空白/参考表/后封面） |
| 页数 | 918 → 909 |

## 注意事项

- **版本差异**：两版常不同（4e vs 7e），替换后书名页/尾页为源版式，正文仍是目标版——接受或先问用户
- **页面尺寸混合**：源 612x783、目标 549x744 并存属正常，PDF 阅读器按页缩放
- **封面照分辨率低**（实战 700x895 px 嵌入 336x430 pt 页）：勿过度放大，保持原样插入
- **重复内容**：两版皆有随机数字表时，源尾页整块保留或跳过重复页——先问用户
- **尾部误删风险**：目标版尾部空白页间可能夹统计表续页（文本层乱码但实为表），须视觉确认后再删
- **不覆写**：输出新文件，目标原文件保留
- **文件名含空格/括号**：脚本用变量传递路径，禁字符串拼命令
- 视觉代理结论与像素统计交叉验证（墨量/方差），疑则重渲染复核

## 变更日志

### 1.0.0 (2026-08-27)
- 初始发布。沉淀 2026-08-27 实战：zlib IA 扫描 4e 教师版（918 页，封面带 TEACHER'S REVIEW COPY 水印 + 尾部 8 页空白）替换为 7e 实体书扫描（466 页）封面照/财产页/About the Cover/书名页 + 尾部 3 页，产出 909 页合并版
- 流程核心：文本层定结构 → 视觉子代理分类 → 内容对应映射 → PyMuPDF insert_pdf → 页数/文本/视觉三重验证
