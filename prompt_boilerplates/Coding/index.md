---
name: coding-skills-index
version: 1.4.0
description: Coding 技能集入口——进入项目时自动加载项目文档协议、检测项目特征并引导加载对应领域技能
triggers:
  - "进入项目"
  - "开始工作"
  - "项目入口"
  - "项目开始"
  - "新项目"
  - "查看项目"
  - "项目状态"
inputs:
  - name: project_dir
    description: 项目根目录
    required: false
    default: "当前目录"
tools:
  - read
  - bash
  - grep
  - find
  - subagent
---

# Coding Skills 入口

> 先执行，再看目录。本文件是 Coding 技能集的入口——被触发时立即开始项目标准化流程，流程结束后下方目录供浏览参考。

---

## 立即执行

**当本 skill 被加载时，不要只是浏览——立即按以下步骤执行：**

### 步骤 1：加载项目文档协议（必须）

`project-documentation-protocol.md` 定义了所有项目的标准文档读写流程。**立即加载它并执行其阶段 A（文档阅读）**：

1. 检查项目文档清单（§A1）
2. graphify 知识图谱优先查阅（§A2，含时效性检测）
3. 环境/服务器状态验证（§A3，条件执行）
4. 输出阅读摘要（§A4）
5. 根据项目特征加载领域 skill（§A5）

```bash
# 如果在 pi-agent 环境中，可用 subagent 加载协议：
# subagent({ agent: "...", task: "按照 project-documentation-protocol.md §阶段A 执行项目文档阅读流程" })
# 或直接读取协议文件并按步骤手动执行
```

### 步骤 2：加载基础设施 skill

阅读摘要输出后，确认以下基础设施 skill 已就绪：

| 必须加载 | 用途 |
|:---|:---|
| `development-quality-gates.md` | 编码时逐条对照 11 个关卡 |
| `resource-aware-delegation.md` | subagent 调用前执行 pi-resmon |

### 步骤 3：按项目特征加载领域 skill

根据 §A5 的检测结果，加载对应的领域 skill（如 `ml-training.md`、`vps-operations.md` 等）。

### 步骤 4：开始实际工作

文档读完了、技能就绪了——现在可以开始实际工作。编码时对照 `development-quality-gates.md`，工作完成后执行 `project-documentation-protocol.md` §阶段B。

---

## 工作流速查

```
进入项目
  │
  ├─ 1. project-documentation-protocol（阶段A）
  │     阅读文档 → graphify 查架构 → 输出状态摘要 → 加载领域 skill
  │
  ├─ 2. development-quality-gates（编码阶段）
  │     关卡 1-10 自检
  │     └─ subagent 调用前 → resource-aware-delegation 检查资源
  │
  └─ 3. project-documentation-protocol（阶段B）
        更新文档 → 重建 graphify → 漂移检测 → 更新 CONTEXT
```

---

## 以下为 Coding 技能集完整目录

> 以下是 `~/prompt_boilerplates/Coding/` 下所有编码相关 skill 的中央注册表。
> 每个 skill 文件均可独立加载；本目录说明它们之间的关系、加载优先级和触发场景。

## 一、基础设施层（所有项目均需加载）

这些 skill 定义了跨项目通用的基础行为规范：

| # | Skill | 版本 | 用途 | 何时生效 |
|:--|:---|:---:|:---|---|
| 1 | [development-quality-gates.md](development-quality-gates.md) | 1.4.0 | 编码质量 11 关卡——写每行代码时自我对照 | 编码阶段 |
| 2 | [project-documentation-protocol.md](project-documentation-protocol.md) | 1.0.1 | 文档阅读与更新协议——进入项目时读文档、完成工作时更新文档（含 graphify 知识图谱） | 项目入口 + 项目退出 |
| 3 | [resource-aware-delegation.md](resource-aware-delegation.md) | 1.1.0 | subagent 资源感知调度——启动子代理前检查 CPU/内存/GPU 状态 | subagent 调用前 |

## 二、通用工作流

按需加载，适用于特定工作模式：

| # | Skill | 版本 | 用途 | 触发场景 |
|:--|:---|:---:|:---|---|
| 4 | [improvement-loop.md](improvement-loop.md) | 1.4.0 | 修改→审查（momus）→修复（hephaestus）→再审查 的迭代循环 | 代码重构后验证质量、bug 修复后全面检查 |
| 5 | [interactive-cli-design.md](interactive-cli-design.md) | 1.3.0 | 交互式 CLI/TUI 设计规范——强制键位集、信息密集界面导航与搜索、PTY 自动化测试验收、已有代码资产复用 | 构建/审查任何交互式终端工具时逐条对照 |

> **与其他 skill 的关系**：
> - `improvement-loop.md`：循环内「审查」阶段可结合 `development-quality-gates.md` 的关卡清单作为审查标准；循环结束后应触发 `project-documentation-protocol.md` 的阶段 B 更新文档
> - `interactive-cli-design.md`：其中 §5 验收清单可作为 `improvement-loop.md` 内审查交互工具时的审查标准；§4 测试规范是 `development-quality-gates.md` §关卡 6（测试同步）的 TUI 专属细化

## 三、领域专用

仅在特定领域/项目类型时加载：

| # | Skill | 版本 | 适用领域 | 何时加载 |
|:--|:---|:---:|:---|---|
| 6 | [ml-training.md](ml-training.md) | 1.5.0 | ML 深度学习/RL 训练 | 项目含 `.py` + `train` 脚本 + 远程 GPU 服务器 |
| 7 | [quant-ml-falsification.md](quant-ml-falsification.md) | 1.1.0 | 量化投资 ML | 项目含 `Sharpe` / `IC` / `alpha` / 金融数据 |
| 8 | [vps-operations.md](vps-operations.md) | 2.0.0 | VPS 部署运维 | 需要配置/管理远程 Linux 服务器 |
| 9 | [copr_packaging.md](copr_packaging.md) | 1.1.0 | RPM/COPR 打包 | 项目含 `.spec` 文件或需要发布 RPM 包 |
| 10 | [cp-review-fix.md](cp-review-fix.md) | 1.0.0 | 竞技编程题解 | 审查算法竞赛（Codeforces/AtCoder/洛谷）代码 |

### 领域 skill 加载决策树

```
项目中有 .py + train 相关文件？
  ├─ 是 → 加载 ml-training.md
  │        └─ 项目中有 Sharpe/IC/alpha 词汇？ → 同时加载 quant-ml-falsification.md
  └─ 否 → 继续

需要配置远程 Linux 服务器？
  └─ 是 → 加载 vps-operations.md

项目中有 .spec 文件或需要 RPM 发布？
  └─ 是 → 加载 copr_packaging.md

审查算法竞赛代码？
  └─ 是 → 加载 cp-review-fix.md

项目含交互式 CLI/TUI 组件（REPL、菜单、表单、浏览器）？
  ├─ 是 → 加载 interactive-cli-design.md（§1-5 对照）
  │    └─ 项目中含已有 TUI 组件？ → 同时参考 interactive-cli-design.md §3 代码资产复用指南
  └─ 否 → 继续
```

## 四、skill 间交叉引用速查

| 当前 skill | 应参阅 | 原因 |
|:---|:---|:---|
| `development-quality-gates.md` §关卡5 | `project-documentation-protocol.md` §阶段B | 关卡 5 说「更新文档」，协议给出完整更新清单 |
| `development-quality-gates.md` §关卡11 | `improvement-loop.md` §3.4 + `interactive-cli-design.md` §5-E | 每次代码变更后构建并安装最新二进制到本地 |
| `development-quality-gates.md` §关卡10 | `project-documentation-protocol.md` §A2 + §B3 | 关卡 10 说「查 graphify」，协议覆盖完整生命周期 |
| `project-documentation-protocol.md` §阶段B | `development-quality-gates.md` | 编码阶段应逐条对照质量关卡 |
| `project-documentation-protocol.md` §阶段B | `resource-aware-delegation.md` | subagent 调用前必须检查资源 |
| `improvement-loop.md` | `development-quality-gates.md` | 审查标准可使用关卡清单 |
| `improvement-loop.md` | `project-documentation-protocol.md` §阶段B | 循环结束后必须更新文档 |
| `ml-training.md` §Step7 | `project-documentation-protocol.md` §阶段B | 训练后的文档更新遵循统一协议 |
| `ml-training.md` §0.1 | `project-documentation-protocol.md` §阶段A | 进入项目时的文档阅读遵循统一协议 |
| `interactive-cli-design.md` §4 | `development-quality-gates.md` §关卡6 | TUI 测试规范是关卡 6 的专属细化 |
| `interactive-cli-design.md` §5 | `improvement-loop.md` | 验收清单可作为审查循环的审查标准 |
| `interactive-cli-design.md` | `project-documentation-protocol.md` §阶段B | TUI 工具完成后按协议更新文档 |
| `interactive-cli-design.md` §3 | 本机项目 `bl`/`news-report`/`在深渊` 等 | 已有代码资产可复用，避免轮子再造 |

## 五、维护约定

- 新增 skill 后**必须更新本文件**：在对应分类下添加条目 + 更新交叉引用表
- skill 版本升级时：如果新增了与已有 skill 重叠的内容，更新交叉引用表
- skill 退役（deprecated/superseded）时：在此文件中标记状态，保留条目但注明替代者

---

## 变更日志

### 1.4.0 (2026-08-03)
- improvement-loop → 1.4.0：新增 §5.7–5.9 Chain 输出捕获 / Edit 预验证 / 输出门控
- development-quality-gates → 1.4.0：新增关卡 12「字符串 / Rune 安全」
- interactive-cli-design → 1.2.0：新增 §1.6 CJK 安全、§2.3 简繁搜索、§2.7 阅读器窗口、§6 外部工具集成
- index → 1.4.0：版本同步

### 1.3.0 (2026-08-03)
- 移除：领域 skill #11 `opencode_health_check.md`（文件已删除）——同步移除决策树 OpenCode 分支

### 1.2.0 (2026-08-03)
- 新增：`development-quality-gates.md` 关卡 11「本地二进制部署」（v1.2.0 → 1.3.0）——每次代码变更后必须把最新二进制构建安装到本机
- 修改：`improvement-loop.md` 升级 1.1.0 → 1.2.0（新增 §3.4 部署步骤）
- 修改：`interactive-cli-design.md` 升级 1.0.0 → 1.1.0（§5 验收清单新增 E 节本地部署）
- 新增：交叉引用表增加 `development-quality-gates.md` §关卡 11 条目

### 1.1.0 (2026-08-03)
- 新增：`interactive-cli-design.md`（通用工作流 #5）——交互式 CLI/TUI 工具设计规范
- 修改：领域专用 skill 编号后移（原 5-10 → 6-11）
- 新增：加载决策树增加交互式 CLI/TUI 分支
- 新增：交叉引用表增加 4 条 `interactive-cli-design` 相关引用

### 1.0.0 (2026-07-30)
- 初始发布：从被动目录升级为可触发入口技能
- 新增：YAML front matter + 触发词 +「立即执行」章节
- 新增：步骤 1-4 的明确执行指令
- 保留原有目录内容供浏览参考

*最后更新: 2026-08-03*
