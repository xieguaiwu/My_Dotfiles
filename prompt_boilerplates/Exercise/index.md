---
name: exercise-index
version: 1.2.0
description: Exercise 技能集入口——先判素材、再定产物、后选 skill，统一路由出卷、错题重练、易错清单、拆题入库、证明写作训练、词汇例句、作业作答与国际象棋对局分析；凡加难度必先过共享升级框架
triggers:
  - "练习技能集"
  - "出题流程"
  - "生成练习"
  - "试卷生成"
  - "错题重练"
  - "SAT工具链"
  - "Exercise目录"
  - "练习入口"
inputs:
  - name: task_type
    description: '任务类型描述（auto-detect 时按下方路由表判定）'
    required: false
    default: "auto-detect"
  - name: source_material
    description: '手上素材：知识点描述 / 试卷 PDF（文本层或扫描）/ 错题记录 / 截图 / 棋局 PGN 或 FEN / 单词表'
    required: false
    default: "unknown"
tools:
  - read
  - bash
  - grep
  - find
  - ask_user
---

# Exercise 技能集入口

> 先判素材，再定产物，后选 skill。本文件是 Exercise 技能集入口——被触发时按路由表加载对应 skill；出卷类任务必先过「难度升级共享框架」，交付类任务必过一次校验闸。

---

## 立即执行

**本 skill 被加载时，按以下步骤路由：**

### 步骤 1：判定素材与产物

| 类别 | 手上素材 | 欲产出 | 入口 skill |
|:---|:---|:---|:---|
| A. 整卷仿制/命题 | 既有试卷作模板，或知识点清单 | 全英文 LaTeX 试卷（省纸排版） | [exam-paper-cloner.md](exam-paper-cloner.md) |
| B. 错题驱动出卷 | 错题诊断（trap + difficulty）或错题文件 | 全英文选择题练习卷 | [mistake-practice-generation.md](mistake-practice-generation.md) |
| C. AP CSA 专项 | 无（直接命题） | AP CSA 模拟卷（代码驱动型） | [ap_csa_generation.md](ap_csa_generation.md) |
| D. 证明写作训练 | Rudin 章节号 | S0–S5 分层练习卷 + 答案卷 | [rudin-proof-writing.md](rudin-proof-writing.md) |
| E. 易错点速查 | 学科 + 陷阱规律 | 超紧凑三轨 LaTeX 清单 | [error-checklist-creator.md](error-checklist-creator.md) |
| F. 专题练习拆分 | 多份专题练习 PDF（文本层，任意科目） | 题目卷 + 答案卷两个 LaTeX | [exercise-splitter.md](exercise-splitter.md) |
| G. 整卷扫描 OCR | 扫描版试卷（无文本层，任意科目） | 同上（vision 转录流水线） | splitter §0.3a + [ocr-pipeline/](ocr-pipeline/README.md) |
| H. 错题笔记沉淀 | SAT 答题记录 + 试卷 PDF | Obsidian 错题分析笔记 | [sat-error-note-generator.md](sat-error-note-generator.md) |
| I. 题目提取入库 | 题目图片 / 文档 | Obsidian Markdown 题库 | [problem_extraction.md](problem_extraction.md) |
| J. 截图解题 | 一张题目截图 | 直接作答与讲解 | [screenshot_task_solver.md](screenshot_task_solver.md) |
| K. 词汇例句 | 外语单词 | 画面感记忆例句 | [vocab-example-generator.md](vocab-example-generator.md) |
| L. 找真题资源 | 科目/考试名 | 真题下载来源清单 | [find_exam_assist.md](find_exam_assist.md) |
| M. 棋局分析 | PGN / SAN 着法串 / FEN 快照 | 三件套（PGN + 引擎数据 + 分析报告） | [chess-game-analysis.md](chess-game-analysis.md) |
| Z. 加难度/出难题 | 任意已出题组 | 难度档案 + 升级维度 | 先 [difficulty-escalation-framework.md](difficulty-escalation-framework.md)，再回 A/B/C/D |

### 步骤 2：出卷类必先过难度框架

凡任务含「更难 / 升级 / 出难题」，**勿直接堆料**。先加载 `difficulty-escalation-framework.md`，按学科分轨取维度：数理轨禁堆计算量（改边界、追踪、反证、建模深度），文科轨容句法复杂度但禁晦涩堆砌，计算机轨禁超长代码（改边界情况、调试找错、算法选择）。产物须附难度档案标注。

### 步骤 3：编译与排版统一约定

- LaTeX 默认 `tectonic`；含中文或不兼容时转 `xelatex`（用户偏好 ⑤）。
- 禁用 Unicode `–` `—`，改 `--` / `---`（偏好 ⑥）。CJK 排版铁律见 `error-checklist-creator.md` §A.1（偏好 ⑥-b）。
- Overfull 轻微超宽先查断行设置，勿擅调列宽。

### 步骤 4：算力与远程执行

- 国际象棋引擎**一律远程**，本机禁跑（用户铁律，详见 MEMORY ㉟ 与 `chess-game-analysis.md` 前置铁律 1）。
- 起子代理或远端批任务前，先按 `resource-aware-delegation` 查资源。

### 步骤 5：素材不足或指代不明

`ask_user` 问清（素材边界、执子方/科目/难度目标、是否只要结果），**禁猜**。典型：用户给 FEN 却说「这盘棋」，须先说明 FEN 是照片、非录像，无着法序列即无逐着评估（见 `chess-game-analysis.md` 步骤 1）。

---

## 症状 → skill 决策树

```text
要出题/出卷？
  ├─ 有旧卷当模板，或只给知识点 ──────────→ exam-paper-cloner.md
  │     └─ 旧卷是扫描件 ─────────────────→ 转 splitter §0.3a + ocr-pipeline/
  ├─ 有错题（诊断结论或错题文件）──────────→ mistake-practice-generation.md
  ├─ AP CSA 模拟卷 ─────────────────────→ ap_csa_generation.md
  ├─ 证明写作训练（Rudin/AP 桥梁）────────→ rudin-proof-writing.md
  └─ 觉得题太简单、要加难度 ─────────────→ difficulty-escalation-framework.md（先）→ 回上面对应 skill

要整理已有题？
  ├─ 专题练习按难度分 section ───────────→ exercise-splitter.md（扫描整卷 → ocr-pipeline/）
  ├─ 错题写进 Obsidian 笔记（SAT 专用）───→ sat-error-note-generator.md
  ├─ 题目图片/文档提取入库 ───────────────→ problem_extraction.md
  └─ 学科易错点做成速查清单 ─────────────→ error-checklist-creator.md

只有零散需求？
  ├─ 截图里这题怎么做 ───────────────────→ screenshot_task_solver.md
  ├─ 作业题图/文档解题，要学生作答记录 ───→ homework-answer-sheet.md
  ├─ 给单词造记忆例句（英/德）───────────→ vocab-example-generator.md
  ├─ 找 AP 真题资源下载 ─────────────────→ find_exam_assist.md
  └─ 复盘一盘国际象棋（PGN/SAN/FEN）─────→ chess-game-analysis.md

链条走通（真题 → 练习 → 清单）：
  find_exam_assist → exercise-splitter →（做错）→ sat-error-note-generator
      → mistake-practice-generation → error-checklist-creator
```

---

## 以下为 Exercise 技能集完整目录

### 一、出卷与命题类

| # | Skill | 版本 | 用途 | 触发场景 | pi 安装态 |
|:--|:---|:---:|---|---|:---:|
| 1 | [exam-paper-cloner.md](exam-paper-cloner.md) | 1.5.0 | 以现有试卷为模板和/或按知识点生成全英文 LaTeX 试卷，tectonic 编译，极致省纸；支持扫描卷作模板（§0.3a vision 流水线）；§1.7 难度升级专项 | 出卷、生成试卷、仿制考卷 | ✅ 已装 |
| 2 | [mistake-practice-generation.md](mistake-practice-generation.md) | 1.4.0 | 从错题诊断或错题文件生成全英文选择题练习卷；语义甄别专项、难度递进、答案分布均衡、系列化增量；SAT 模式支持 CB 拟真格式 | 错题重排、生成练习卷、陷阱练习 | ✅ 已装 |
| 3 | [ap_csa_generation.md](ap_csa_generation.md) | 1.2.0 | 生成 AP CSA 完整模拟卷（LaTeX）；CS 轨难度升级专项（禁代码堆料，改边界/追踪/调试/算法选择/设计约束） | AP CSA 试卷、生成 AP 试卷 | ❌ 未装 |
| 4 | [rudin-proof-writing.md](rudin-proof-writing.md) | 1.0.0 | 用 Rudin《数学分析原理》训练本科级证明写作——S0–S5 脚手架、AP 桥梁映射、原题与定制双轨、模型证明与评分准则 | Rudin 证明练习、PMA 证明题 | ✅ 已装 |

### 二、错题与清单沉淀类

| # | Skill | 版本 | 用途 | 触发场景 | pi 安装态 |
|:--|:---|:---:|---|---|:---:|
| 5 | [error-checklist-creator.md](error-checklist-creator.md) | 1.8.0 | 按学科生成超紧凑 LaTeX 易错点清单（文科/理科/计算机三轨 + 章节分组 + 陷阱分类 + TikZ 示意图 + 视觉验证闭环） | 易错点清单、学科易错点 | ✅ 已装 |
| 6 | [sat-error-note-generator.md](sat-error-note-generator.md) | 2.0.0 | 从答题记录与试卷 PDF 提取错题，按 v3.3 七步结构生成/追加 Obsidian 错题笔记（整卷分析 + 单题积累双模式） | 整理 SAT 错题、错题笔记 | ❌ 未装 |

### 三、素材获取与提取类（工具链上游）

| # | Skill | 版本 | 用途 | 触发场景 | pi 安装态 |
|:--|:---|:---:|---|---|:---:|
| 7 | [exercise-splitter.md](exercise-splitter.md) | 2.0.0 | 识别多份任意科目专题练习，按难度分 section 生成题目卷与答案卷两个 LaTeX（题号各自重排）；文本层几何提取；扫描整卷接 ocr-pipeline | 拆分专题练习、题目答案分离 | ✅ 已装 |
| 8 | [problem_extraction.md](problem_extraction.md) | 1.1.0 | 从图片/文档提取题目并整理为 Obsidian Markdown 笔记 | 整理题目、提取题目 | ❌ 未装 |
| 9 | [find_exam_assist.md](find_exam_assist.md) | 1.0.0 | 查找 AP 考试真题资源（MCQ 与 FRQ） | 查找真题、AP 真题 | ❌ 未装 |
| 10 | [screenshot_task_solver.md](screenshot_task_solver.md) | 1.0.0 | 识别并完成截图中的题目或任务，支持复杂图像分析 | 截图解题、分析截图 | ❌ 未装 |
| 11 | [vocab-example-generator.md](vocab-example-generator.md) | 1.1.0 | 按输入单词生成画面感强、便于记忆的例句（英语/德语） | 单词例句、英语例句 | ❌ 未装 |
| 12 | [homework-answer-sheet.md](homework-answer-sheet.md) | 1.0.0 | 从作业题图/文档逐题求解，输出学生作答记录风格 Markdown 答案文档（仅题号与答案）；科目不限（数学物理化学生物英语历史计算机） | 作业作答、作业答案、学生作答记录 | ✅ 已装 |

### 四、非学业练习类（棋局分析）

| # | Skill | 版本 | 用途 | 触发场景 | pi 安装态 |
|:--|:---|:---:|---|---|:---:|
| 13 | [chess-game-analysis.md](chess-game-analysis.md) | 1.0.0 | 国际象棋对局/局面快照在远程服务器跑 Stockfish 18，产出 PGN + 引擎数据表 + 中文分析三件套；棋谱模式与照片模式双轨、静态攻守实测、PGN 往返校验、引擎部署踩坑库 | 棋局复盘、FEN 局面分析、部署 Stockfish | ✅ 已装（本次新增） |

### 五、共享规范与脚本资产

| # | 资产 | 版本 | 用途 | 引用方 |
|:--|:---|:---:|---|---|
| 14 | [difficulty-escalation-framework.md](difficulty-escalation-framework.md) | 1.1.0 | 难度升级共享框架——铁律「难度 = 认知负荷的深度，不是任务量」；分轨维度矩阵、递进阶梯、反堆料清单、难度档案标注 | #1 #2 #3 #4 #5 |
| 15 | [ocr-pipeline/](ocr-pipeline/README.md) | 脚本 | 扫描版整卷 OCR 流水线（多路 vision 转录 + 答案键条带裁剪 + LaTeX 生成，科目参数化 books.json），含 `probe_providers.py` / `build_latex.py` / `final_build.sh` 等 | #7 |

---

## 链式工作流（跨 skill 串联）

| 链 | 顺序 | 交接物 |
|:---|:---|:---|
| 真题/题库 → 练习闭环 | `find_exam_assist` → `exercise-splitter`（扫描件走 `ocr-pipeline/`）→ 学生作答 → `sat-error-note-generator` → `mistake-practice-generation` → `error-checklist-creator` | PDF 真题 → 题/答 LaTeX → Obsidian 错题笔记 → 新练习卷 → 速查清单 |
| 加难度链 | 任一出卷 skill 成稿 → `difficulty-escalation-framework` 取维度 → 回原 skill 重出 | 难度档案标注 + 反堆料检查结果 |
| 证明训练链 | `rudin-proof-writing` 出题 → 学生写 → 模型证明对照 → 错题规律回填 `error-checklist-creator` | 练习卷 + 答案卷 + 易错条目 |
| 棋局链 | `chess-game-analysis`（远程 Stockfish）→ 三件套落 `~/works/记录/chess/<日期>game/` → 有完整棋谱时切 game 模式补逐着表 | PGN + 引擎数据 txt + 分析 md（+ 参考续着 pgn） |

## skill 间交叉引用速查

| 当前 skill | 应参阅 | 原因 |
|:---|:---|:---|
| `exam-paper-cloner.md` §1.7 | `difficulty-escalation-framework.md` | 难度维度与反堆料检查归共享框架 |
| `mistake-practice-generation.md` §难度递进 | `difficulty-escalation-framework.md` | 同上（升级 = 换更深维度，非加计算量） |
| `ap_csa_generation.md` §CS 轨升级 | `difficulty-escalation-framework.md` | CS 轨禁代码堆料专项 |
| `rudin-proof-writing.md` §评分/批判变体 | `difficulty-escalation-framework.md` | 认知负荷分档口径统一 |
| `error-checklist-creator.md` §A.1 | `exam-paper-cloner.md` §0.3a.9 / `exercise-splitter.md` 注意事项 #6 | CJK 排版铁律三处同源，改一处须同步 |
| `exercise-splitter.md` §0.3a | `ocr-pipeline/README.md` | 扫描卷可执行脚本落点 |
| `sat-error-note-generator.md` | `mistake-practice-generation.md` | 错题笔记是后者的诊断输入 |
| `chess-game-analysis.md` 步骤 6/8 | [../Coding/verification-before-completion.md](../Coding/verification-before-completion.md) | 「证据先于断言」同源；交付前必附校验输出 |
| `chess-game-analysis.md` 步骤 2/5 | [../Coding/resource-aware-delegation.md](../Coding/resource-aware-delegation.md) | 远程选机与子代理资源感知 |
| 本 index 的 YAML/结构约定 | [../skill_creator.md](../skill_creator.md) | 检查清单 A–H 组与严格 YAML 校验命令 |
| 全部出卷类 | [../Writing/technical-writing-standard.md](../Writing/technical-writing-standard.md) | 题目与解析的指令文本遵守 ASD-STE100 |

## 维护约定

- 新增 skill 后**必须更新本文件**：分类表加行 + 决策树加分支 + 交叉引用补全 + 升级本 index 版本与「最后更新」行。
- 目录表版本号须与 skill front matter `version` **完全一致**；skill 升版时同步改此表（历史教训：索引与内容脱节）。
- 触发一致性三查：skill `triggers` ↔ 本 index 决策树 ↔ 目录表「触发场景」列，三者不得互相遗漏。
- **安装态**说明：仅 `~/.agents/skills/<name>/SKILL.md` 存在者会被 pi 自动发现；未装项须由本 index 路由或手动 `read` 加载。新装法：复制源文件至 `~/.agents/skills/<name>/SKILL.md`，并在 front matter 内加一行 `source: ~/prompt_boilerplates/Exercise/<file>.md`（`source:` 必须落在闭合栏之内，勿置于正文首行或文件末尾）。
- 全目录 YAML 严格解析与链式完整性自检：

  ```bash
  cd ~/prompt_boilerplates/Exercise && python3 - <<'EOF'
  import yaml, glob
  bad = []
  for f in sorted(glob.glob("*.md")):
      t = open(f).read()
      if not t.startswith("---"):
          continue
      try:
          d = yaml.safe_load(t.split("---", 2)[1])
          assert d.get("name") and d.get("version") and d.get("description") and d.get("triggers"), "四字段缺"
          assert 3 <= len(d["triggers"]) <= 8, "triggers 数量 %d" % len(d["triggers"])
      except Exception as e:
          bad.append((f, str(e).split("\n")[0]))
  print("全部通过" if not bad else bad)
  EOF
  ```

- 已知遗留：
  1. #3 #6 #8 #9 #10 #11 #14 共 7 项未安装到 `~/.agents/skills/`，pi 层不能凭触发词直达，须经本 index 路由。
  2. `mistake-practice-generation.md` 1.4.0 的 `triggers` 有 9 个，超 skill_creator 上限 3-8（本文件自检脚本会报红）。修法：删一项并升版，须同步目录表版本号。
  3. `difficulty-escalation-framework.md` 1.1.0 的 `description` 以句号收尾，违反规则 1.4。修法：去句尾句号并升 patch 版。
  4. 以上两项为历史遗留，2026-08-29 建立本 index 时由自检脚本首次发现，未擅自修正（改动他 skill 的 front matter 涉及版本号连带）。

## 变更日志

### 1.2.0 (2026-09-03)

- 新增：`homework-answer-sheet.md` 1.0.0（科目通用作业作答文档——从题图/文档解题，输出学生作答记录风格答案：仅题号与答案，含 g 常数锁定与落盘覆写踩坑经验）；已安装至 `~/.agents/skills/homework-answer-sheet/SKILL.md`（source 行已加入 front matter）
- 路由表三区新增 #12；决策树「只有零散需求」新增分支；目录表重排 #12→#13（chess）、#13→#14（difficulty）、#14→#15（ocr-pipeline）

### 1.0.0 (2026-08-29)

- 初始发布：Exercise 目录从被动文件集升级为可触发入口技能
- 收录 13 个 skill + 1 个脚本资产（sat-ocr-pipeline），分五类（出卷命题 / 错题清单 / 素材提取 / 非学业练习 / 共享规范）
- 新增：素材→产物路由表（13 类）、症状→skill 决策树、四条链式工作流（真题/题库→练习闭环、加难度链、证明训练链、棋局链）、交叉引用 11 条
- 新增：pi 安装态列与维护约定（含 `source:` 须落在 front matter 内的规定——2026-08-29 实测 5 个历史安装件放错位置，已修正）
- 新增：维护自检脚本（严格 YAML + 四字段 + triggers 3-8 + description 无句尾句号）与链接/版本一致性核对；据此发现并记录 4 项已知遗留（含 2 处他 skill 的 front matter 历史违规，未擅改）
- 收录本次新建的 `chess-game-analysis.md` 1.0.0

### 1.1.0 (2026-09-02)

- 通用化重构：`sat-exercise-splitter.md` 改名 `exercise-splitter.md`（2.0.0）+ `sat-ocr-pipeline/` 改名 `ocr-pipeline/`——删除 SAT 专门制定，支持任意科目（新增 subject/difficulty_levels 输入项、多科目适配表、书目参数化 books.json）
- 路由表 F/G、决策树、链条行、交叉引用同步更新；下游引用（sat-error-note-generator / mistake-practice-generation）已在两文件中改指 exercise-splitter
- 注意：`sat-error-note-generator` 仍为 SAT 专属（不在本次通用化范围，后续可参照 exercise-splitter 模式）

*最后更新: 2026-09-03（index 1.2.0：新增 homework-answer-sheet 1.0.0 科目通用作业作答文档）*
