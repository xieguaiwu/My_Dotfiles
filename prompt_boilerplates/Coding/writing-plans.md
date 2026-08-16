---
name: writing-plans
version: 1.2.0
description: 多步骤任务实施前的强制计划编写——零上下文执行者假设、bite-sized 任务粒度、接口契约块、无占位符、自审查三查。核心移植自 obra/superpowers writing-plans（MIT）
triggers:
  - "写计划"
  - "实施计划"
  - "多步任务"
  - "拆分任务"
  - "任务分解"
  - "写方案"
  - "动手前先计划"
  - "规划后再实施"
inputs:
  - name: spec
    description: 规格/需求描述（目标、约束、验收标准）
    required: true
  - name: target_dir
    description: 目标项目目录
    required: false
    default: "当前目录"
  - name: plan_dir
    description: 计划保存目录
    required: false
    default: "docs/plans/"
tools:
  - read
  - bash
  - grep
  - find
  - edit
  - write
  - subagent
---

# Writing Plans — 实施计划编写

## 核心理念

**写计划时假设执行者对这个代码库零上下文、且品味可疑。** 把所有执行者需要的信息写进计划：每个任务动哪些文件、代码、测试、要查的文档、怎么验证。

> 本 skill 移植自 obra/superpowers 的 `writing-plans`（MIT License）。核心原则：DRY、YAGNI、TDD、频繁 commit。

**执行者假设**：他们是熟练的开发者，但几乎不了解你的工具链和问题域，也不太懂好的测试设计。**计划必须自足**——每个任务只靠自己的文本就能完成，不依赖执行者"猜"。

---

## 适用场景

- 规格/需求明确的多步骤任务（≥3 个独立可测任务）
- 涉及多个文件的实现
- 需要与既有代码库集成的变更
- 给 subagent（hephaestus/worker）执行的任务

**不适用**：单文件小改动（直接做）、探索性任务（先 brainstorm 再计划）、用户只要快速原型。

---

## 计划保存位置

```text
docs/plans/YYYY-MM-DD-<feature-name>.md
```

---

## 范围检查

如果规格覆盖多个独立子系统，应拆成多个独立计划——每个计划自身产出可工作、可测试的软件。一个计划做一件事。

---

## 计划文档结构

### Header（必须）

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** 按本计划任务逐项实施。步骤用 checkbox（`- [ ]`）跟踪。

**Goal:** [一句话描述要构建什么]

**Architecture:** [2-3 句方法概述]

**Tech Stack:** [关键技术/库]

**Spec:** [规格文档路径——计划从规格论证而来，执行者两者都要读]

## Global Constraints

[项目级约束——版本下限、依赖限制、命名/拷贝规则、平台要求，每行一条，
数值从规格逐字复制。每个任务的要求隐式包含本段]
```

---

### 任务结构模板（每个任务用这个模板）

```markdown
### Task N: [组件名]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [本任务使用的前置任务的产物——精确签名]
- Produces: [后续任务依赖的产物——精确函数名、参数和返回类型。
  任务实现者只看自己的任务，本块是相邻任务学习名字和类型的唯一途径]

- [ ] **Step 1: 写失败测试**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: 写最小实现**

```python
def function(input):
    return expected
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

---

## 任务粒度（bite-sized）

**每个 step 是一个动作（2-5 分钟）**：
- "写失败测试" — step
- "跑它确认失败" — step
- "写最小实现让它通过" — step
- "跑测试确认通过" — step
- "提交" — step

**任务边界**：一个任务 = 能独立携带自己的测试周期、值得单独审查的最小单位。配置/脚手架/文档步骤并入需要它们产出的任务；只在「审查者能拒绝 A 而批准 B」之处拆分。

---

## 文件结构规划

写任务之前先画出文件结构：哪些文件新建/修改、各自负责什么。分解决策在此锁定：

- 设计边界清晰、接口明确的单元；每个文件一个明确职责
- 文件聚焦时编辑更可靠。偏好小而聚焦的文件，而非什么都装的大文件
- 一起变化的文件应该住在一起。按职责拆分，勿按技术层拆
- 在既有代码库中遵循既有模式。代码库用大文件时勿单方面重构——但待改文件已臃肿时，计划中包含拆分是合理的

---

## No Placeholders（禁止占位符）

**每个 step 必须包含执行者需要的实际内容。以下皆计划失败**：

| 禁止 | 示例 |
|------|------|
| TBD / TODO | "TBD", "implement later", "fill in details" |
| 空指令 | "add appropriate error handling" / "add validation" / "handle edge cases"（不带具体做法） |
| 无代码的测试要求 | "Write tests for the above"（没有实际测试代码） |
| 引用式偷懒 | "Similar to Task N"（重复代码——执行者可能不按顺序读任务） |
| 只有描述没有做法 | 需要代码块的步骤却没有代码块 |
| 悬空引用 | 引用了任何任务中都没定义的类型/函数/方法 |

---

## Self-Review（自审查，写完计划后必须做）

写完完整计划后，用新鲜眼睛看一遍规格，对照检查计划。**此乃你自己跑的检查清单，非派 subagent**：

**1. Spec 覆盖**：扫一遍规格的每个章节/需求。能指出实现它的任务吗？列出缺口。

**2. 占位符扫描**：搜索计划中的红旗——上面 "No Placeholders" 的任何模式。修复它们。

**3. 类型一致性**：后续任务用的类型/方法签名/属性名与先前任务定义的一致吗？
Task 3 里叫 `clearLayers()`、Task 7 里叫 `clearFullLayers()`——这是 bug。

发现的问题就地修复，无需再审查——修复完继续。发现规格里有需求没有任务 → 加任务。

---

## 执行交接

保存计划后，提供执行选择：

**"计划已完成并保存到 `docs/plans/<filename>.md`。两种执行方式：**

**1. Subagent 驱动（推荐）** — 每个任务派全新 subagent，任务之间审查，快速迭代（本地对应：`improvement-loop.md` 阶段 1-4 + `resource-aware-delegation.md` 调度）

**2. 内联执行** — 本会话内按任务逐项执行，检查点处审查（`verification-before-completion.md` 验证每个任务）"

---

## 适用边界与豁免

本 skill 约束计划编写，非约束一切。以下情形可豁免或降级：

| 情形 | 处理 |
|------|------|
| 单文件小改动（<3 个独立可测步骤） | 不写正式计划，直接实施 |
| 探索性任务 / spike | 先 brainstorm 明确目标再决定是否计划 |
| 用户要求快速原型 | 用户指示优先，跳过正式计划 |
| 被派发的 subagent 已获完整任务文本 | 任务文本即 mini 计划，不重复产出计划文件 |
| 项目已有计划约定 | 项目约定优先，本 skill 降级为参考 |

---

## 与本地 skill 的衔接

| 相关 skill | 关系 |
|:--|:--|
| `improvement-loop.md` | 本 skill 是其缺失的「计划前链」：improvement-loop 的修改阶段前，先用本 skill 产出计划、momus 审计划、再实施 |
| `verification-before-completion.md` | 每个任务 step 4 的"Expected: PASS"按它的 Gate Function 确认；声称任务完成时必须附命令输出 |
| `development-quality-gates.md` | 计划的 Global Constraints 应包含质量关卡要求（安全、文档同步、测试真实性） |
| `resource-aware-delegation.md` | Subagent 驱动执行时，每个 subagent 调用前执行资源检查 |
| `prometheus`/`metis` agent | 规划类 subagent 的任务即"用本 skill 编写实施计划" |
| `hephaestus` agent | 执行类 subagent 的任务即"按计划文件逐任务实施，每步验证" |

## 作业要求

```text
多步任务 → 用本 skill 写计划（Header + Global Constraints + 任务模板）→ Self-Review 三查 → 保存 docs/plans/ → 交接执行
```

1. 计划中每个任务必须自足（执行者只看自己的任务就能完成）
2. 禁止 TBD/引用式偷懒/无代码的指令
3. 写完必须过三查（覆盖/占位符/类型一致性）

---

## 计划文本写作规范（ASD-STE100）

实施计划是功能性文档，遵守 ASD-STE100（简化技术英语，国际标准，现行 Issue 9）原则：

- **短句**：每句 ≤ 20 词（中文 ≤ 40 字），一句一个主题
- **指令祈使**：任务描述直接以动词开头（"Add the config field."），不用 "should/could" 绕弯
- **一词一义**：同一概念全文同一词汇（执行者零上下文，同义词换说法会造成误解）
- **编号步骤**：任务用编号列表，结构平行
- **条件前置**：依赖条件放句首（If X exists, then ...）
- **主动语态**：描述用 A does B

完整规范见 [technical-writing-standard.md](../technical-writing-standard.md)。

## 变更日志

### 1.2.0 (2026-08-16)
- 新增：文档写作规范（ASD-STE100）——实施计划文本遵守简化技术英语原则，完整规范见 technical-writing-standard.md

### 1.1.0 (2026-08-14)
- 修复（momus 审查轮）：豁免表增加「项目已有计划约定优先」
- 新增：「适用边界与豁免」章节——小改动/探索任务/快速原型/subagent 完整任务文本四种豁免，防教条化
- 修改：正文叙述浅文言压缩约 30%，任务模板/No Placeholders 表/代码块保持不变
- 修复：front matter description 去句号、triggers 精简至 8 个、代码块标注语言

### 1.0.0 (2026-08-14)
- 初始发布：移植 obra/superpowers `writing-plans`（MIT License）核心——零上下文执行者假设、bite-sized 任务粒度、Files/Interfaces/Steps 模板、No Placeholders 清单、Self-Review 三查
- 本地化：计划保存位置改为 `docs/plans/`、执行交接映射到本地 improvement-loop/资源感知调度、衔接表
- 保留原文原则：DRY、YAGNI、TDD、频繁 commit；"写计划时假设执行者零上下文且品味可疑"

*来源：obra/superpowers writing-plans（MIT License, Copyright (c) 2025 Jesse Vincent）*
