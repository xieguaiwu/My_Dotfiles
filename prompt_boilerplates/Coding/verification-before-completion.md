---
name: verification-before-completion
version: 1.1.0
description: 声称工作完成、已修复、已通过之前，必须运行验证命令并确认输出——证据先于断言。核心移植自 obra/superpowers verification-before-completion（MIT）
triggers:
  - "声称完成"
  - "修好了"
  - "测试通过"
  - "完成声明"
  - "验证结果"
  - "确认结果"
  - "提交前"
  - "报告完成"
inputs:
  - name: claim
    description: 要声明的完成结论（如"测试通过"、"bug 已修复"、"训练完成"）
    required: true
  - name: verification_command
    description: 能证明该结论的命令（缺省时由 agent 自行确定）
    required: false
    default: ""
tools:
  - read
  - bash
  - grep
  - find
---

# Verification Before Completion — 完成前验证

## 核心理念

**证据先于断言，永远如此。**
**"Skip any step = lying, not verifying"**（跳过任何一步 = 撒谎，不是验证）。

> 本 skill 移植自 obra/superpowers 的 `verification-before-completion`（MIT License）。原文核心：
> **"Violating the letter of this rule is violating the spirit of this rule."**
> （违背本规则字面条款，即违背本规则精神）

---

## Iron Law（铁律）

```text
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

**本消息内未运行验证命令，则不得声称其通过。**

「上次跑过」「应该能过」「感觉没问题」皆非证据。**惟本次完整运行、亲见输出之验证方为算数。**

---

## Gate Function（门函数）

```text
在声称任何状态或表达满意之前：

1. IDENTIFY  确定：什么命令能证明这个结论？
2. RUN       执行：完整命令（全新、不截断）
3. READ      读取：完整输出、退出码、失败计数
4. VERIFY    对照：输出真的确认了这个结论吗？
   - 否 → 如实报告实际状态（附证据）
   - 是 → 带证据一起声称
5. ONLY THEN 声称完成

跳过任何一步 = 撒谎，不是验证
```

---

## Common Failures（常见失败模式）

| 声称 | 需要 | 不足以证明 |
|------|------|-----------|
| 测试通过 | 测试命令输出：0 失败 | 上次跑过、"应该能过" |
| Lint 干净 | Lint 输出：0 错误 | 只查了部分文件、凭经验推断 |
| 构建成功 | 构建命令：退出码 0 | Lint 通过、日志看着正常 |
| Bug 已修复 | 原始症状的测试：通过 | 代码改了、假设已修复 |
| 回归测试有效 | 红-绿循环已验证 | 测试只通过过一次 |
| Agent 完成了任务 | VCS diff 显示实际变更 | Agent 自己报告"成功" |
| 需求已满足 | 逐行核对检查清单 | 测试通过了 |
| 训练完成 | 训练日志/结果 JSON 真实存在 | watchdog 说在跑 |
| 服务器部署好了 | SSH 登录 + 运行验证命令 | scp 命令没报错 |
| 文档同步了 | grep 确认新内容在文档中 | 记忆里"应该写了" |

---

## Red Flags — STOP（自我识别）

- 用了"应该""可能""似乎""应该可以"
- 验证之前即表达满意（"Great!""Perfect!""Done!"）
- 准备 commit/push/PR 但未验证
- 相信 agent 的成功报告
- 依赖部分验证（只跑一个测试即声称全部通过）
- 想「就这一次」
- 累了想快点结束
- **任何未运行验证即暗示成功的措辞**

---

## 反合理化表

| 借口 | 现实 |
|------|------|
| "应该能行" | 去 RUN 验证 |
| "我很确信" | 信心 ≠ 证据 |
| "就这一次" | 没有例外 |
| "Lint 过了" | Lint ≠ 编译/运行 |
| "Agent 说成功了" | 独立验证 |
| "我累了" | 疲劳不是借口 |
| "部分检查就够了" | 部分证明不了什么 |
| "换个说法就不算违规" | 精神重于字面 |

---

## 关键模式

**测试类**：
```text
✅ [运行测试命令] [看到: 34/34 通过] → "全部测试通过"
❌ "应该能过" / "看起来正确" / "上次是过的"
```

**修复类**：
```text
✅ [复现原始症状的命令] [看到: 症状消失] → "bug 已修复"
❌ "代码改了，应该修好了"
```

**训练类（ML 特有）**：
```text
✅ [cat results/xxx/results.json | jq '.top_formulas[:3]'] [看到: 真实 JSON 数据] → "训练完成"
❌ "nohup 在跑" / "进程还在"
```

**部署类**：
```text
✅ [SSH 上去跑 --version / systemctl status] [看到: 新版本号] → "已部署"
❌ "scp 没报错" / "文件传上去了"
```

---

## 适用边界与豁免

本 skill 约束完成声明，非约束一切。以下情形可豁免或降级：

| 情形 | 处理 |
|------|------|
| 探索性试跑（明确标注 throwaway） | 验证降级为「记录实际观察」，不要求完整 Gate Function |
| 用户在场实时交互 | 用户亲见输出即为证据，最终声称仍须引用该输出 |
| 被派发 subagent 报告中间结果 | 编排器做最终验证，subagent 只须附命令输出 |
| 项目已有验证约定 | 项目约定优先，本 skill 降级为参考 |

---

## 与本地 skill 的衔接

| 相关 skill | 关系 |
|:--|:--|
| `improvement-loop.md` | §5.9 Chain 输出门控是**平台层**的输出验证（turnBudget 防止空输出）；本 skill 是**方法论层**的完成验证（任何声明都要证据）。审查 agent 用本 skill 的 Gate Function 核对实现 agent 的完成声明 |
| `ml-training.md` | §七 快速验收流程（量化验收阈值表）定义"什么是好的训练结果"；本 skill 定义"如何证明结果存在且真实"——先验证后验收 |
| `development-quality-gates.md` | 关卡 6（测试同步）+ 关卡 11（本地部署）的验证步骤均以本 skill 的 Gate Function 为执行标准 |
| `project-documentation-protocol.md` | 文档声称的结论（Sharpe、IC）必须与结果 JSON 一致（§B4 文档漂移检测）——这正是 Gate Function 在文档场景的应用 |

## 作业要求

```text
完成任何工作 → 自问「什么命令能证明」 → 运行完整命令 → 读完整输出 → 带证据声称完成 → 记入文档/commit
```

1. **每次声称「完成/修复/通过」必须附命令 + 输出证据**，不允许裸声称
2. 对 subagent 报告的结果，独立验证（不信转述）
3. 训练/长任务：验证产物（results JSON、checkpoint 文件、日志尾部）而非进程存在性

---

## 变更日志

### 1.1.0 (2026-08-14)
- 修复（momus 审查轮）：悬空引用 §2.5 → §B4；豁免表增加「项目已有验证约定优先」；触发词「完成」→「声称完成」去泛化
- 新增：「适用边界与豁免」章节——探索性试跑/用户在场/subagent 中间报告三种豁免，防教条化
- 修改：正文叙述浅文言压缩约 30%，铁律原文/表格/命令保持不变
- 修复：front matter description 去句号、triggers 精简至 8 个、代码块标注语言

### 1.0.0 (2026-08-14)
- 初始发布：移植 obra/superpowers `verification-before-completion`（MIT License）
- 本地化：新增 ML 训练/部署类验证模式（结果 JSON、SSH 验证）、与 improvement-loop/ml-training/文档协议的衔接表
- 保留原文核心原则："跳过任何一步 = 撒谎"；Gate Function 五步

*来源：obra/superpowers verification-before-completion（MIT License, Copyright (c) 2025 Jesse Vincent）*
