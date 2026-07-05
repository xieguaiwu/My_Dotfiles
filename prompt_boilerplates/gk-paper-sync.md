---
name: gk-paper-sync
version: 1.0.0
description: 将论文更新从 Glaubenskrieg_TMP（工作台）同步至 GK-Paper-Working（发布版），生成带详细变更记录的提交信息
triggers:
  - "同步论文"
  - "sync paper"
  - "论文提交"
  - "提交Working"
inputs:
  - name: tmp_repo_path
    description: Glaubenskrieg_TMP 仓库路径（源）
    required: false
    default: "/home/xieguiawu/works/阐述/Glaubenskrieg论文"
  - name: working_repo_path
    description: GK-Paper-Working 仓库路径（目标）
    required: false
    default: "/home/xieguiawu/works/阐述/GK-Paper-Working"
  - name: commit_message_suffix
    description: 附加到提交信息末尾的标签（如协作者名、issue号）
    required: false
    default: ""
tools:
  - read
  - write
  - edit
  - bash
---

# GK Paper Sync — 双仓库同步 Skill

## 任务目标
将 `Glaubenskrieg_TMP` 中的论文核心文件更新同步到 `GK-Paper-Working`，**生成结构化的提交信息**，逐条记录每个文件的具体变更内容（修改位置、改动性质、变更原因），而不是笼统的 "update paper"。

## 核心原则
- **可追溯**：每次提交信息必须精确描述改了什么、为什么改
- **只发布核心文件**：不同步 TMP 中的草稿、审稿报告、中间检查文件
- **逐个文件分析**：对每个变更文件做差异化分析，而非批量模糊描述

## 监控文件清单
同步时只关注以下核心文件（Working 仓库的发布范围）：

| 文件/目录 | 说明 | 变更分析方式 |
|-----------|------|------------|
| `GK_paper.tex` | 论文主源文件 | `git diff --word-diff` 逐行分析 |
| `GK_paper.pdf` | 编译版 PDF | 仅记录更新，不做内容分析 |
| `GK_paper_plain.md` | 纯文本版 | `diff` 按行分析 |
| `references.bib` | 参考文献 | `diff` 检测新增/删除条目 |
| `auto_generated_tables.tex` | 自动生成表格 | `diff` 按行分析 |
| `bib_key_naming.md` | Bib key 命名规范 | `diff` 检测变更 |
| `出路.md` | 思考笔记 | `diff` 检测变更 |
| `figures/` | 图表目录 | `rsync -ai` 列出新增/修改/删除的文件 |
| `methodology/` | 方法论文档 | `diff` 逐文件分析 |

**以下文件/目录不应同步**（TMP 工作台独有）：
`findings/`, `guide/`, `literature/`, `results/`, `draft.md`, `oracle_*.md`, `HALLUCINATION_AUDIT*.md`, `session1_*.md`, `paper_assist.md`, `workable.md`, `git_safety_net.md`, `architecture_prompt.md`, `CLASSIC_LITERATURE_COMPARISON.md`, `IC_BENCHMARK_COMPARISON.md`, `LATERAL_COMPARISON.md`, `NEGATIVE_RESULTS_REPORT.md`, `REPRODUCIBILITY_ASSESSMENT.md`, `STRATEGIC_PLAN.md`, `CONTEXT_*.md`, `oracle_assessment.md`, `evaluation_and_outline.md`, `section7_lessons.md`, `results_summary.md`, `abstract_v2.md`, `ridge_architecture.md`, `00_paper_outline.md`

## 执行流程

### 1. 检查仓库状态

```bash
# 确认两个仓库都是正常 git 仓库
cd "$TMP_REPO" && git status --short
cd "$WORKING_REPO" && git status --short
```

确认 Working 仓库没有未提交的更改，否则先询问用户如何处理。

### 2. 全面对比文件变更

对监控清单中的每类文件执行差异分析：

#### 2a. TeX 主文件 (`GK_paper.tex`)

```bash
diff -u "$WORKING_REPO/GK_paper.tex" "$TMP_REPO/GK_paper.tex"
```

分析 diff 输出，提取以下信息：
- **变更位置**：第几行（LaTeX 节/段/公式）
- **变更类型**：新增/删除/修改/重写
- **变更摘要**：用一句话描述改了什么（如 "精简引言第一段，删除冗余状语"）
- **变更量**：增/删/改了多少字符或行

#### 2b. PDF (`GK_paper.pdf`)

仅确认文件二进制不同（时间戳或大小变化），不做内容分析。

```bash
cmp "$WORKING_REPO/GK_paper.pdf" "$TMP_REPO/GK_paper.pdf" || echo "PDF 已更新"
```

#### 2c. 纯文本版 (`GK_paper_plain.md`)

```bash
diff -u "$WORKING_REPO/GK_paper_plain.md" "$TMP_REPO/GK_paper_plain.md"
```

#### 2d. 参考文献 (`references.bib`)

```bash
diff -u "$WORKING_REPO/references.bib" "$TMP_REPO/references.bib"
```

如果有变更，逐条列出新增/删除的引用 key。

#### 2e. 其他文本文件

对 `auto_generated_tables.tex`、`bib_key_naming.md`、`出路.md` 执行同样的 `diff -u` 分析。

#### 2f. 图表目录 (`figures/`)

```bash
rsync -ai --dry-run "$TMP_REPO/figures/" "$WORKING_REPO/figures/"
```

排除临时文件（`*.aux`, `*.log`, `__pycache__/`）。列出新增、修改、删除的图表。

#### 2g. 方法论文档 (`methodology/`)

```bash
for f in 01_walk_forward_protocol.md 02_diagnostic_framework.md 03_statistical_tests.md; do
  diff -u "$WORKING_REPO/methodology/$f" "$TMP_REPO/methodology/$f"
done
```

### 3. 生成结构化提交信息

根据差异分析结果，生成以下格式的提交信息：

```
sync: {一句话概括本次同步的核心变更}

变更详情:

【GK_paper.tex】
- 位置: L{行号}, {节/段名称}
- 性质: {新增 | 修改 | 删除 | 重写}
- 变更: {具体描述了改了什么，如"拆分长句为两段，删除冗余状语"}
- 量级: +{n} / -{m} 行

【GK_paper.pdf】
- 同步编译版本至 TMP commit {短哈希}

【{其他文件名}】
- {逐条描述}

【figures/】
- {新增 | 修改 | 删除}: {文件名} — {说明}

源仓库: Glaubenskrieg_TMP (commit {短哈希})
{commit_message_suffix}
```

### 4. 执行同步

```bash
# 复制所有变更文件
cp "$TMP_REPO/GK_paper.tex" "$WORKING_REPO/"
cp "$TMP_REPO/GK_paper.pdf" "$WORKING_REPO/"
# ... 其他变更文件

# 同步 figures（排除临时文件）
rsync -a --exclude='*.aux' --exclude='*.log' --exclude='__pycache__' \
  "$TMP_REPO/figures/" "$WORKING_REPO/figures/"

# 提交
cd "$WORKING_REPO"
git add -A
git commit -m "$COMMIT_MSG"
```

### 5. 推送远程

```bash
git push origin main
```

### 6. 输出同步报告

完成后输出格式化的同步报告：

```
✓ 同步完成

提交: {短哈希}
文件数: {n} changed
变更概要: {一句话}
源版本: TMP@{短哈希}

变更明细:
- GK_paper.tex: {摘要}
- GK_paper.pdf: 同步
- ...

推送至: https://github.com/xieguaiwu/GK-Paper-Working
```

## 输出格式

最终输出应包含：
1. ✓/✗ 状态标记
2. 本次提交的 Git 哈希
3. 变更文件清单及数量
4. 每项变更的简要说明
5. 推送状态
6. 如有错误，清晰的错误原因和解决建议

## 注意事项

1. **diff 优先于盲目复制**：先对比再复制，避免提交无变更的内容
2. **排除 TMP 独有文件**：严格按照监控清单执行，不将工作台中间产物带入发布版
3. **PDF 仅同步不分析**：PDF 是编译产物，commit message 中注明"同步编译版本"即可，不做逐行分析
4. **图片文件分析到文件名级**：figures 中每个新增/修改/删除的文件都要在 commit message 中列出
5. **提交前确认 Working 仓库干净**：如有本地未提交更改，先暂停并询问用户
6. **git push 在 commit 之后**：commit 成功后必须推送到远程，否则不同步
7. **如果无任何变更**：检测到所有文件相同时，告知用户无更新需同步，不创建空提交
