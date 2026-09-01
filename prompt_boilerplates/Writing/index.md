---
name: writing-index
version: 1.0.0
description: Writing 技能集入口——按写作任务类型路由到对应 skill，学术写作项目先过文档管理纪律
triggers:
  - "学术写作"
  - "论文项目"
  - "论文文档管理"
  - "写作任务路由"
  - "写论文"
  - "写网络小说"
  - "论文排版"
  - "写作技能集"
inputs:
  - name: task_type
    description: 写作任务类型描述（学术/文学/规范）
    required: false
    default: "auto-detect"
tools:
  - read
  - bash
  - grep
  - find
---

# Writing 技能集入口

> 本文件是 Writing 技能集的入口。被触发时按下方路由表加载对应 skill；学术写作项目必先过文档管理纪律（体检 → 结构 → 术语 → 引用分级 → 勘误 → 归档）。

---

## 立即执行

**当本 skill 被加载时，按以下步骤路由：**

### 步骤 1：判定任务类别

| 类别 | 任务特征 | 入口 |
|:---|:---|:---|
| **A. 学术论文项目** | 多文档、长线、含 tex/bib/审稿材料 | → 先加载 academic-writing-project-management.md，再按需加载排版/审查 skill |
| **B. 单篇论文处理** | 排版、编译、语言审查、参考文献 | → 直接加载对应 skill |
| **C. 作文批改** | AP/SAT 等应试作文评分 | → ap-lang-rhetorical-analysis-assist.md |
| **D. 文学创作** | 网络小说、风格模仿、发表推广 | → 对应创作 skill |
| **E. 功能性文档** | README、计划、笔记、指令文本 | → technical-writing-standard.md |

### 步骤 2：A 类项目先体检

学术项目进入时，先执行 academic-writing-project-management.md 之 audit 模式（读 todo.md / foundation.md → 盘点现行 vs 归档 → grep 术语与编号漂移），再动正文。

### 步骤 3：无明确指向

说不清楚 → 按任务描述与下表「用途」列做子串匹配；仍无命中 → 询问用户。

---

## 任务 → skill 决策树

```text
学术论文项目（多文档长线）？
  ├─ 项目结构 / 任务追踪 / 术语统一 / 归档 → academic-writing-project-management.md
  ├─ LaTeX 排版 / 编译调试 / 格式检查 → latex-academic-writing-assist.md
  ├─ 草稿语言与引用审查 → paper_assist.md
  ├─ 参考文献 key 命名 → bib_key_naming.md
  └─ 数据分析防幻觉 → critical-data-analysis.md

AP 英语作文批改 / 修辞分析评分 → ap-lang-rhetorical-analysis-assist.md

网络小说？
  ├─ 创作全流程（大纲/章节/一致性）→ web-novel-writing.md
  └─ 平台发表与推广 → novel-publish-promotion.md

模仿用户风格 / 清除 AI 痕迹 → style-imitate.md

功能性文档写作（README/计划/笔记/指令）→ technical-writing-standard.md
```

---

## 以下为 Writing 技能集完整目录

### 一、学术写作类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 1 | [academic-writing-project-management.md](academic-writing-project-management.md) | 1.0.0 | 学术论文长线项目文档体系管理——目录结构、任务追踪、术语统一、引用可信度分级、勘误留痕、归档纪律 | 论文项目结构、术语统一、论文归档、多文档协同 |
| 2 | [latex-academic-writing-assist.md](latex-academic-writing-assist.md) | 1.2.0 | 学术论文 LaTeX 排版、格式检查、编译调试与样式优化 | 论文排版、LaTeX 编译、参考文献格式 |
| 3 | [paper_assist.md](paper_assist.md) | 1.1.0 | 论文草稿审查与改进建议（语法、引用补充） | 论文审查、论文改进（注：tools 字段仍为 OpenCode 时代命名，待修正） |
| 4 | [bib_key_naming.md](bib_key_naming.md) | — (规范文档) | BibTeX key 命名铁律：{全小写人名}{年份} | 新增 bib 条目、key 命名 |
| 5 | [critical-data-analysis.md](critical-data-analysis.md) | 1.0.0 | 复杂数据分析防幻觉——多 Agent 批判性交叉验证 | 数据分析验证、防幻觉分析 |

### 二、作文批改类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 6 | [ap-lang-rhetorical-analysis-assist.md](ap-lang-rhetorical-analysis-assist.md) | 1.0.0 | AP English Language 修辞分析作文批改与 6 分制评分 | AP Lang 作文修改、rhetorical analysis 批改 |

### 三、文学创作类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 7 | [web-novel-writing.md](web-novel-writing.md) | 1.2.0 | 网络小说创作全流程——定位、档案、爆点、分章、AI 痕迹清除 | 写网络小说、网文创作、小说大纲 |
| 8 | [novel-publish-promotion.md](novel-publish-promotion.md) | 2.2.0 | 网络小说平台发表与推广策略（引流+发表双线） | 发表策略、平台推广、晋江/豆瓣发表 |
| 9 | [style-imitate.md](style-imitate.md) | 1.0.0 | 提取用户写作风格特征并模仿，清除 AI 痕迹 | 模仿风格、仿写、按我的风格 |

### 四、写作规范类

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|---|---|
| 10 | [technical-writing-standard.md](technical-writing-standard.md) | 1.3.0 | 功能性文档写作规范（ASD-STE100 简化技术英语）——README、计划、笔记、指令文本 | 文档写作、技术写作、写 README |

---

## skill 间交叉引用速查

| 当前 skill | 应参阅 | 原因 |
|:---|:---|:---|
| `academic-writing-project-management.md` §流程2 | `latex-academic-writing-assist.md` | 排版编译归后者 |
| `academic-writing-project-management.md` §流程2 | `bib_key_naming.md` | references.bib 条目 key 规范 |
| `academic-writing-project-management.md` §注意事项 | `paper_assist.md` | 草稿语言审查归后者 |
| `academic-writing-project-management.md` §流程8 | `technical-writing-standard.md` | foundation.md/todo.md 等项目文档写作规范 |
| `academic-writing-project-management.md` §流程8 | [../skill_creator.md](../skill_creator.md) | 子代理 timeoutMs 推荐值 |
| `latex-academic-writing-assist.md` | `bib_key_naming.md` | 参考文献格式一致性 |
| `critical-data-analysis.md` | `academic-writing-project-management.md` §流程5 | 数据引用核查与承诺分级衔接 |
| `technical-writing-standard.md` | [../skill_creator.md](../skill_creator.md) §1.8 | 同源规范，skill 指令文本亦遵守 |
| `web-novel-writing.md` | `style-imitate.md` | 章节成稿后的风格一致性 |
| `novel-publish-promotion.md` | `web-novel-writing.md` | 创作完成后的发表衔接 |

## 维护约定

- 新增 skill 后**必须更新本文件**：对应分类下添加条目 + 更新决策树 + 交叉引用表
- skill 版本升级时同步目录表版本号；front matter `version` 与目录表一致
- skill 退役时保留条目并注明替代者
- 全部 front matter 严格 YAML 解析（命令见 `skill_creator.md` 步骤 4）；路由完整性自检（triggers ↔ 决策树 ↔ 目录表三者一致）
- 已知遗留：paper_assist.md 之 tools 字段仍用 OpenCode 工具名（websearch_web_search_exa/webfetch），待其升级时修正

## 变更日志

### 1.0.0 (2026-08-26)
- 初始发布：Writing 目录从被动文件集升级为可触发入口技能
- 新增：#1 `academic-writing-project-management.md` 1.0.0（学术论文长线项目文档体系管理）——经验源《中介与剩余》项目实战沉淀
- 收录既有 9 个文件入目录表，分四类（学术写作 / 作文批改 / 文学创作 / 写作规范）
- 新增：任务决策树 + 交叉引用表 + 维护约定（含 paper_assist tools 字段遗留注记）

*最后更新: 2026-08-26（index 1.0.0：academic-writing-project-management 1.0.0 入册）*
