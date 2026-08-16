---
name: project-documentation-protocol
version: 1.1.0
description: 跨项目标准化文档协议——进入项目时按规范阅读项目文档（含 graphify 知识图谱）和工作完成后按规范更新项目文档（含 graphify 知识图谱）
triggers:
  - "标准化文档流程"
  - "文档协议"
  - "文档清单"
  - "文档漂移"
  - "知识图谱"
  - "graphify"
  - "项目状态摘要"
  - "更新CONTEXT"
inputs:
  - name: action
    description: 执行阶段（read / update / both）
    required: false
    default: "both"
  - name: project_dir
    description: 项目根目录
    required: false
    default: "当前目录"
  - name: change_scope
    description: 变更范围（architecture / feature / bugfix / training），影响更新哪些文档
    required: false
    default: "feature"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
  - subagent
---

# Project Documentation Protocol — 项目文档协议

## 任务目标

为所有项目建立标准化的文档阅读和更新流程，确保：

1. **阅读阶段**：无论进入哪个项目，Agent 都按统一顺序阅读关键文档，避免遗漏重要上下文（如已推翻结论、当前状态），并在阅读文档前优先使用 graphify 知识图谱了解架构
2. **更新阶段**：每次工作完成后，按统一清单更新文档、重建 graphify 知识图谱、检测文档与代码的一致性，确保下一位 Agent 无缝接手

**核心原则**：文档是项目状态的事实来源。未记录在文档中的训练等于没跑、未记录在文档中的修复等于没做、未记录在文档中的结论推翻等于没发生。

---

## 执行流程

### 阶段 A：文档阅读（进入项目时）

**适用场景**：首次进入项目、从其他项目切换回来、长时间离开后返回。

#### A1. 检查项目文档清单

进入项目后，按以下优先级顺序阅读文档：

| 优先级 | 文档 | 用途 | 是否必须 | 适用范围 |
|:------:|:---|---|:--------:|:---|
| P0 | **graphify-out/GRAPH_REPORT.md**（如存在） | 项目架构概览、God Nodes、社区划分、模块依赖 | 如有则必须 | 全部项目 |
| P0 | **graphify-out/wiki/index.md**（如存在） | 可导航的知识图谱 wiki，替代直接读代码 | 如有则优先 | 全部项目 |
| P1 | **CONTEXT_FOR_NEXT_AGENT.md**（如存在） | 项目当前状态、最后完成的工作、遗留问题 | 推荐 | 多 Agent 协作项目 |
| P1 | **FALSIFICATION_SUMMARY.md**（如存在） | 哪些方向/结论已被推翻，哪些不可信 | 推荐 | 多轮实验项目（ML/量化） |
| P1 | **ASSET_INVENTORY.md**（如存在） | 目录结构、文件用途、服务器列表、密码/端口 | 推荐 | 有远程资源/复杂目录的项目 |
| P1 | **GOAL.md**（如存在） | 项目目标和当前 Phase | 推荐 | 多阶段项目 |
| P2 | **FINAL_HONEST_ASSESSMENT.md**（如存在） | 诚实评估——哪个方向是真实的、哪个是疑似噪音 | 推荐 | 多轮实验项目 |
| P2 | 最近的 daily log / scratchpad | 上一个 Agent 在做什么、训练状态、PID | 推荐 | 多 Agent 协作项目 |
| P3 | 领域相关的方法论文档（如 `ml-training.md`） | 适用于当前任务的工作方法论 | 按需 | 特定领域 |
| P3 | 项目 README / CHANGELOG / ARCHITECTURE | 基础信息 | 按需 | 全部项目 |

**执行方式**：

```bash
# 检查哪些文档存在
for doc in "graphify-out/GRAPH_REPORT.md" "CONTEXT_FOR_NEXT_AGENT.md" \
           "FALSIFICATION_SUMMARY.md" "ASSET_INVENTORY.md" "GOAL.md" \
           "FINAL_HONEST_ASSESSMENT.md"; do
  if [ -f "$doc" ]; then echo "✅ $doc" ; else echo "❌ $doc"; fi
done
```

#### A2. graphify 知识图谱优先原则

**首先检测图谱时效性**——图谱可能因代码变更而过期：

```bash
# 检测图谱是否过期（比较 graph.json 时间戳 vs 最新源代码时间戳）
GRAPH_TIME=$(stat -c %Y graphify-out/graph.json 2>/dev/null || echo 0)
CODE_TIME=$(find . -name '*.py' -o -name '*.go' -o -name '*.ts' -o -name '*.rs' -o -name '*.js' \
  | grep -v node_modules | grep -v '.git/' \
  | xargs stat -c %Y 2>/dev/null | sort -rn | head -1)
if [ "$GRAPH_TIME" -lt "$CODE_TIME" ] && [ "$GRAPH_TIME" -ne 0 ]; then
  echo "⚠️ 知识图谱可能过期（图谱: $(date -d @$GRAPH_TIME '+%Y-%m-%d %H:%M'), 最新代码: $(date -d @$CODE_TIME '+%Y-%m-%d %H:%M')）"
  echo "建议执行: graphify update ."
fi

# 检查 needs_update 标记文件（graphify watch 模式自动生成）
if [ -f graphify-out/needs_update ]; then
  echo "⚠️ graphify 检测到代码变更，需要更新"
fi
```

**如果项目已有 graphify-out/：**

1. 先读 `graphify-out/GRAPH_REPORT.md` 了解 God Nodes 和社区结构
2. 若有 `graphify-out/wiki/index.md`，优先通过 wiki 导航而非直接 grep 代码
3. 用 `graphify query` / `graphify explain` / `graphify path` 查询特定模块关系
4. **只在 graphify 提供的信息不够时**才 fallback 到 grep 原始文件

```bash
# 查阅架构概览
cat graphify-out/GRAPH_REPORT.md

# 查询特定模块的关系（比 grep 更全面）
graphify query "数据流走向" --graph graphify-out/graph.json
graphify explain "核心模块" --graph graphify-out/graph.json
graphify path "数据加载" "模型" --graph graphify-out/graph.json
```

**何时用哪个命令**：

| 你想知道 | 用 | 示例 |
|:---|:---|:---|
| 某模块被哪些模块依赖/引用 | `graphify query` | `graphify query "AuthModule" --graph graphify-out/graph.json` |
| 两个模块之间的完整调用路径 | `graphify path` | `graphify path "config" "handler" --graph graphify-out/graph.json` |
| 核心模块的功能描述与邻居 | `graphify explain` | `graphify explain "SwinTransformer" --graph graphify-out/graph.json` |
| 项目整体架构与 God Nodes | 读文件 | `cat graphify-out/GRAPH_REPORT.md` |
| 按功能社区导航 | 读 wiki | `cat graphify-out/wiki/index.md`（如存在）|

**如果尚无 graphify-out/：**

```bash
# 构建知识图谱（首次）
graphify update .
# 或快速构建（无 LLM，仅代码结构）
graphify update . --no-llm

# 然后按上述流程阅读
cat graphify-out/GRAPH_REPORT.md
```

#### A3. 环境/服务器状态验证（条件执行）

**仅当项目依赖远程资源时执行本节**（如远程 GPU 服务器、远程数据库、远程 API 服务）。
对于纯本地项目，跳过本节。

判断是否需要远程验证：
- 项目文档（CONTEXT_FOR_NEXT_AGENT.md / ASSET_INVENTORY.md）中提及了服务器地址 → 执行
- 代码中有 `ssh` / `scp` / `paramiko` / `fabric` 调用 → 执行
- 上述皆无 → 跳过，标记「无远程依赖」

```bash
# 服务器密码验证（如有）
ssh user@server "echo OK" 2>/dev/null || echo "❌ 服务器密码/端口可能已变更"

# GPU 状态（如有 GPU）
ssh user@server "nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader" 2>/dev/null

# 运行中的进程（如 ML 训练）
ssh user@server "ps aux | grep -E 'python.*train|watchdog' | grep -v grep" 2>/dev/null

# 远程数据库/服务（按项目类型调整）
ssh user@server "systemctl is-active postgresql nginx docker" 2>/dev/null
```

#### A4. 输出：阅读摘要

阅读完成后，输出项目状态摘要：

```
━━━ 项目状态摘要 ━━━
项目: {project_name}
文档就绪: GRAPH_REPORT.md ✅ | CONTEXT_FOR_NEXT_AGENT.md ✅ | FALSIFICATION_SUMMARY.md ❌
服务器: user@host:port（密码已验证 ✅）
GPU:    0 (空闲) / 1 (运行中: Z74 训练 PID 12345)
知识图谱: graphify-out/ 存在，God Node: 4 个

项目当前方向:
  P0: SGX Z74 — 信噪比最高
  P1: 期货 AlphaGPT — 待 walkforward
  ❌ 已推翻: 美股 35 特征选股

本次计划:
  1. 检查 Z74 训练结果
  2. 如已完成 → 读 results.json + 更新文档
━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### A5. 根据项目特征加载领域 skill

阅读文档后，根据项目特征判断是否需要加载额外的领域专用 skill：

```bash
# 检测项目特征，输出推荐加载的领域 skill
echo "=== 项目特征检测 ==="

# ML/训练项目
grep -rq -E 'train|model|\.pth|torch|tensorflow|sklearn' --include='*.py' . 2>/dev/null && \
  echo "📌 检测到 ML 项目特征 → 建议加载 ml-training.md"
grep -rq -E 'Sharpe|alpha|IC\b|backtest|walkforward' --include='*.md' --include='*.py' . 2>/dev/null && \
  echo "📌 检测到量化金融特征 → 建议加载 quant-ml-falsification.md"

# VPS/运维项目
grep -rq -E 'Dockerfile|docker-compose|systemd|nginx|hysteria' . 2>/dev/null && \
  echo "📌 检测到运维特征 → 建议加载 vps-operations.md"

# 打包项目
find . -name '*.spec' -o -name '*.rpm' 2>/dev/null | grep -q . && \
  echo "📌 检测到 RPM 打包特征 → 建议加载 copr_packaging.md"

# 算法竞赛
head -5 *.cpp *.py 2>/dev/null | grep -qE 'Codeforces|AtCoder|洛谷|洛谷|LeetCode' && \
  echo "📌 检测到算法竞赛特征 → 建议加载 cp-review-fix.md"
```

**加载决策矩阵**：

| 项目特征 | 应加载的 skill |
|:---|---|
| 含有 `.py` + `train` / `model` / `torch` / `tensorflow` 文件 | `ml-training.md` |
| 含有 `Sharpe` / `IC` / `alpha` / `backtest` / 金融数据 | `ml-training.md` + `quant-ml-falsification.md` |
| 含有 `Dockerfile` / `docker-compose.yml` / `systemd` 配置 | `vps-operations.md` |
| 含有 `.spec` 文件 | `copr_packaging.md` |
| 算法竞赛代码（`.cpp` / `.py` 包含 OJ 题号） | `cp-review-fix.md` |
| 以上皆非 | 仅基础设施 skill 即可 |

> ⚠️ **加载时机**：领域 skill 应在阅读摘要输出后、开始实际工作前加载。不要在项目入口阶段就加载所有 skill——按需加载避免上下文膨胀。

---

### 阶段 B：文档更新（工作完成后）

**适用场景**：实验完成、代码修复、架构变更、新增功能后。

> **在开始工作前**，如果项目特征检测（§A5）建议了领域 skill，应先加载它们；
> 编码阶段应参照 `development-quality-gates.md` 的 11 个关卡逐条自检；
> 如果涉及 subagent 调用，先执行 `resource-aware-delegation.md` 的资源检查；
> 如果需要迭代改进，可启动 `improvement-loop.md` 的修改→审查→修复循环。

#### B1. 确定变更范围

先判断本次改动的范围，决定更新哪些文档：

| 变更类型 | 说明 | 需更新 |
|:--------:|:---|---|
| `experiment` | 跑完一轮实验/训练/基准测试 | CONTEXT_FOR_NEXT_AGENT.md + 实验记录 + 必要时 FALSIFICATION_SUMMARY（如有） |
| `bugfix` | 修复代码 bug | CONTEXT_FOR_NEXT_AGENT.md + 相关文档修复 |
| `feature` | 新增/修改功能 | CONTEXT_FOR_NEXT_AGENT.md + README/DEVELOPMENT.md + 重建 graphify |
| `architecture` | 重构/模块增删 | 全部核心文档 + ARCHITECTURE.md + **重建 graphify** |
| `conclusion` | 结论变更/推翻（仅在多轮实验项目中适用） | FALSIFICATION_SUMMARY.md（如有）+ CONTEXT_FOR_NEXT_AGENT.md |

#### B2. 文档更新清单

根据变更范围，更新对应文档：

| 文档 | experiment | bugfix | feature | architecture | conclusion |
|:---|---|:---:|:---:|:---:|:---:|
| **CONTEXT_FOR_NEXT_AGENT.md** | ✅ 追加/重写 | ✅ 更新 | ✅ 更新 | ✅ 重写 | ✅ 重写 |
| **实验记录/运行日志** | ✅ 追加一行 | — | — | — | — |
| **ASSET_INVENTORY.md** | — | — | ✅ 目录变动 | ✅ 目录变动 | — |
| **README / DEVELOPMENT.md** | — | ✅ 如有接口变化 | ✅ 文档同步 | ✅ 重写 | — |
| **FALSIFICATION_SUMMARY.md**（如有） | ✅ 如有结论变更 | — | — | — | ✅ 追加 |
| **graphify-out/（知识图谱）** | — | — | ✅ 重建 | ✅ 重建 | — |
| **特征/接口文档** | — | ✅ 修复描述 | ✅ 新增描述 | ✅ 重写 | — |
| **GOAL.md**（如有） | ✅ 阶段更新 | — | ✅ 如有 scope 变化 | ✅ 重写 | ✅ 重写 |

#### B3. graphify 知识图谱更新

代码变更后必须重建知识图谱，确保下一位 Agent 看到的是最新架构：

```bash
# 重建知识图谱
graphify update .

# 验证重建成功
cat graphify-out/GRAPH_REPORT.md | head -20
graphify query "God Nodes" --graph graphify-out/graph.json
```

**何时必须重建：**
- ✅ 新增/删除/重命名模块（文件、包、目录）
- ✅ 修改核心数据结构或接口
- ✅ 新增或修改跨模块调用关系
- ⚠️ 纯文档更新、配置变更、实验参数调整 → 不需要重建
- ❌ 仅修改注释或非代码文件 → 不需要重建

**验证图谱一致性**：

```bash
# 1. 检查 God Nodes 是否仍然合理
PREV_GODS=""  # 从重建前的 GRAPH_REPORT.md 提取（如有）
graphify query "God Node" --graph graphify-out/graph.json

# 2. 检查核心模块的连接数变化
PREV_EDGES=$(cat graphify-out/graph.json.bak 2>/dev/null | python3 -c "import sys,json; g=json.load(sys.stdin); print(len(g.get('edges',[])))" || echo "N/A")
CURR_EDGES=$(python3 -c "import sys,json; g=json.load(sys.stdin); print(len(g.get('edges',[])))" < graphify-out/graph.json)
echo "边数: $PREV_EDGES → $CURR_EDGES"

# 3. 检查节点数是否异常（突然减半 = 构建失败/路径错误）
PREV_NODES=$(cat graphify-out/graph.json.bak 2>/dev/null | python3 -c "import sys,json; g=json.load(sys.stdin); print(len(g.get('nodes',[])))" || echo "N/A")
CURR_NODES=$(python3 -c "import sys,json; g=json.load(sys.stdin); print(len(g.get('nodes',[])))" < graphify-out/graph.json)
if [ "$PREV_NODES" != "N/A" ] && [ "$CURR_NODES" -lt $((PREV_NODES / 2)) ]; then
  echo "🔥 节点数骤降: $PREV_NODES → $CURR_NODES，可能构建路径错误"
fi

# 4. 检查新增模块是否正确归类到社区
graphify query "新模块名" --graph graphify-out/graph.json

# 5. 备份旧图谱（供下次比较）
cp graphify-out/graph.json graphify-out/graph.json.bak
```

#### B4. 文档漂移检测

更新文档后，检查**文档声明 vs 实际代码**的一致性：

```bash
# 检查文档中声明的特征数是否与代码一致
# （以实际项目为准调整 grep 模式）
DOC_CLAIM=$(grep -c '特征数.*[0-9]' docs/feature_spec.md 2>/dev/null || echo "unknown")
CODE_ACTUAL=$(grep -c 'feats\.append\|F\[.*,\s*[0-9]' *.py 2>/dev/null || echo "unknown")
echo "文档声称特征数: $DOC_CLAIM, 代码实际: $CODE_ACTUAL"

# 检查文档中声明的测试数
grep -n 'tests\b\|test cases\b' README.md 2>/dev/null

# 检查文档声明的 API 端点是否存在
grep 'route\|endpoint' docs/API.md 2>/dev/null | while read line; do
  endpoint=$(echo "$line" | grep -oP '"/\w+(/\w+)*"')
  grep -q "$endpoint" main.py 2>/dev/null && echo "✅ $endpoint" || echo "❌ $endpoint 不存在"
done
```

**常见漂移模式（以下为示例，实际随项目类型变化）**：

| 模式 | 表现 | 修复 | 适用项目 |
|:---|---|:---|:---|
| 函数签名不匹配 | 文档写 `func(a, b)` 代码是 `func(a, b, c=None)` | 更新文档参数表 | 全部 |
| API 端点缺席 | 文档声明了 `/api/v2/users` 但路由中不存在 | 删除文档中的过时端点或补充实现 | Web/API 项目 |
| 命令选项过期 | README 写 `--verbose` 但代码已改为 `--debug` | 更新 CLI 参考文档 | CLI 工具 |
| 密码/端口过期 | 文档密码无法登录服务器 | SSH 验证后更新 | 运维项目 |
| 特征数撒谎 | docstring 写 24，实际 feats.append 只有 22 | 从代码源读取真实数量更新文档 | ML 项目 |
| IC 值过期 | 文档写着 IC=0.160，服务器 json 是 0.090 | 重跑后更新 | 量化 ML |
| 结论过度概括 | "所有方向均已证伪"（实际某方向有信号） | 区分领域、区分模型精准表述 | 多轮实验 |
| 版本号不一致 | README 写 v2.0，package.json 是 1.5.3 | 以代码中版本号为准，统一全部文档 | 全部 |

#### B5. CONTEXT_FOR_NEXT_AGENT.md 更新规范

这是最重要的跨 Agent 文档。每次工作完成后必须更新：

```markdown
# CONTEXT_FOR_NEXT_AGENT.md

## 项目当前状态
{最新的工作/修复/结论状态}

## 最后一次完成的工作
- {工作 1}：{结果}
- {工作 2}：{结果}

## 遗留问题 / 待办
- [ ] {问题 1}：{当前状态}
- [ ] {问题 2}：{当前状态}

## 远程资源（如有）
<!-- 仅当项目依赖远程服务器/数据库/GPU 时填写 -->
- {server_alias}: user@host:port（密码已验证 ✅/❌）
- GPU 0: {状态} / GPU 1: {状态}
- 运行中的任务：{任务名 PID xxx}

## 知识图谱
- graphify-out/: {存在 / 不存在 / 已过期}
- 最后更新: {日期}

## 最后更新时间
YYYY-MM-DD HH:MM
```

**更新频率**：
| 场景 | 操作 |
|:---|---|
| 单次训练/修复完成 | 追加到 CONTEXT，替换旧结果 |
| 多次训练/修复完成 | 全部重写，替换旧状态 |
| 服务器信息变更 | 立即更新服务器状态部分 |
| 结论变更 | 更新 + 同步到 FALSIFICATION_SUMMARY.md |

#### B6. 结论归档（防文档污染）

**适用场景**：多轮实验项目（ML 训练、量化回测、A/B 测试），每一轮可能推翻上一轮的结论。
对于普通软件项目（单线开发、功能迭代），本节不是必须的——CHANGELOG.md 和 git commit history 就够。

当项目积累了多轮结论、且每轮可能推翻上一轮时：

```
项目根目录/
├── CONTEXT_FOR_NEXT_AGENT.md   ← 唯一有效的当前结论，每次重写
├── FALSIFICATION_SUMMARY.md    ← 累积的已证伪方向
└── docs/archive/               ← 历史记录
    ├── 2026-07-05_analysis_report.md
    ├── 2026-07-12_walkthrough.md
    └── ...
```

**归档规则**：
1. 每轮工作结束时：旧版本的文档移入 `docs/archive/`
2. 按日期重命名：`YYYY-MM-DD_original_name.md`
3. 根目录只保留当前有效的文档
4. 引用旧结论时明确注明"参见 archive/YYYY-MM-DD_xxx.md"

---

### 阶段 C：创建项目文档基础设施（可选）

对新项目或尚无文档体系的项目，建立基础文档结构：

#### C1. 最小文档集

```
docs/
├── current/                    # 当前文档（唯一有效）
│   ├── CONTEXT_FOR_NEXT_AGENT.md
│   └── FALSIFICATION_SUMMARY.md  # 按需
├── archive/                    # 历史归档
└── experiments/                # 实验记录
    └── experiments.csv
```

#### C2. 首次 graphify 构建

```bash
# 构建知识图谱（LLM 增强模式，需 API）
graphify update .

# 或仅代码结构（无 API 也可）
graphify update . --no-llm

# 查看结果
cat graphify-out/GRAPH_REPORT.md
graphify query "God Nodes" --graph graphify-out/graph.json
graphify query "社区划分" --graph graphify-out/graph.json
```

#### C3. 文档模板创建

```markdown
# CONTEXT_FOR_NEXT_AGENT.md 模板

## 项目当前状态
{项目名称} — {一句话描述}

## 已完成的工作
- {日期}：{工作 + 结果}

## 待办
- [ ] {优先级}：{任务}

## 服务器
- {别名}：{user@host:port}（{密码状态}）

## 知识图谱
- graphify-out/: {存在 / 不存在}
- 最后更新: {日期}
```

---

## 输出格式

阅读阶段输出（ML/实验项目示例）：

```
━━━ 项目 {project_name} 文档阅读摘要 ━━━
文档就绪情况:
  ✅ graphify-out/GRAPH_REPORT.md（God Nodes: 4）
  ✅ CONTEXT_FOR_NEXT_AGENT.md（最后更新: 2026-07-29）
  ❌ FALSIFICATION_SUMMARY.md
  ✅ ASSET_INVENTORY.md

知识图谱查询结果:
  - God Node: ModelTrainer（连接数: 12）
  - 社区: 4 个（数据预处理、特征工程、模型训练、结果分析）
  - 核心依赖: data_loader → feature_engine → trainer → evaluator

服务器状态:
  - {alias}: 在线 ✅ | GPU 0: 空闲 | GPU 1: 训练中 (PID 12345)

项目当前方向（按优先级）:
  P0: SGX Z74
  ❌ 已推翻: 美股 35 特征选股
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

阅读阶段输出（通用软件项目示例）：

```
━━━ 项目 vpn-check 文档阅读摘要 ━━━
文档就绪情况:
  ✅ graphify-out/GRAPH_REPORT.md（God Nodes: 3）
  ❌ CONTEXT_FOR_NEXT_AGENT.md（建议创建）
  ✅ README.md
  ✅ DEVELOPMENT.md

知识图谱查询结果:
  - God Node: AuthServer（连接数: 8）
  - 社区: 3 个（认证、VPN 代理、监控）
  - 核心依赖: config → auth → proxy → monitor

远程资源: 无

本次计划:
  1. 修复 AuthServer token 刷新 bug
  2. 更新 DEVELOPMENT.md 架构图
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

更新阶段输出（ML/实验项目示例）：

```
━━━ 项目 {project_name} 文档更新完成 ━━━
更新的文档:
  ✅ CONTEXT_FOR_NEXT_AGENT.md — 追加 Z74 训练结果
  ✅ 实验记录 — 追加一行 (Z74, IC=+0.168, 2026-07-30)
  ✅ graphify-out/ — 重建完成
  ✅ FALSIFICATION_SUMMARY.md — 追加 SGX 配对交易证伪

文档一致性检查:
  ✅ 特征数: 文档 24 = 代码 24
  ✅ API 端点: GET /predict 存在
  ⚠️ 服务器密码: 未验证

知识图谱状态:
  ✅ graphify update . 完成
  ✅ God Nodes 检查通过
  ✅ 新模块 'sgx_z74' 已正确归类

下一位 Agent 可无缝接手 ✅
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 文档写作规范（ASD-STE100）

本 skill 产出的项目文档（README、CONTEXT、CHANGELOG、计划等）是功能性文档，遵守 ASD-STE100 简化技术英语（国际标准，现行 Issue 9）核心规则：

- **短句**：每句 ≤ 20 词，一句一个主题
- **指令祈使**：操作说明直接以动词开头（"Run the command."），不用叙述式（"The command should be run."）
- **主动语态**：描述用 "A does B"，仅在必要时用被动
- **现在时为主**：不用 will 将来时与 -ing 进行时
- **一词一义**：同一概念全文同一词汇，不换同义词；不用行话/含糊词
- **数字用数字**：写 5、25，不写 five、twenty-five
- **条件前置**：关键条件放句首（If ..., then ...）
- **列表平行**：编号步骤动词开头、结构平行

完整规范见 [technical-writing-standard.md](../technical-writing-standard.md)。

## 注意事项

### 边界情况

1. **项目无任何文档**：执行阶段 C（创建文档基础设施），至少建立 CONTEXT_FOR_NEXT_AGENT.md
2. **graphify 不可用**（无 API）：`graphify update . --no-llm` 生成纯代码结构图
3. **文档与代码严重不一致**：以代码实际行为为准更新文档，并在 CONTEXT 中注明修复
4. **服务器密码过期**：在 CONTEXT 中标记 ❌，尝试从其他文档或用户获取新密码
5. **混合多项目**：每个项目有独立的文档体系，切换项目时重新执行阶段 A
6. **graphify graph.json 过大**（>10MB）：优先读 GRAPH_REPORT.md 和 wiki，仅在必要时查图

### 已知限制

- graphify 对动态语言（Python）的分析精度高于静态语言（Go/Rust）
- graphify 的 INode（LLM 推断节点）可能不准确，优先依赖 EXTRACTED（代码中确有的）节点
- 跨仓库项目需要分别在每个仓库中运行 graphify

### 常见陷阱

- **陷阱 1**：读了 CONTEXT_FOR_NEXT_AGENT.md 但没读 FALSIFICATION_SUMMARY.md → 在已推翻结论上浪费时间
- **陷阱 2**：先 grep 代码再读 graphify → 失去架构视野，容易微观优化
- **陷阱 3**：改了代码但没重建 graphify → 下一个 Agent 看到的架构图是过期的
- **陷阱 4**：只更新了 CONTEXT 但不同步 FALSIFICATION → 后续 Agent 发现矛盾
- **陷阱 5**：记录了新密码但没更新 ASSET_INVENTORY → 密码丢失
- **陷阱 6**：`graphify update .` 时不在项目根目录 → 图谱指向错误目录
- **陷阱 7**：写了 CONTEXT 但不在顶部注明最后更新时间 → 后续 Agent 无法判断时效

### 协议关系图

```
┌─────────────────────────────────────────────────────────┐
│                 项目文档协议                              │
│                                                         │
│  ┌─ 阶段 A（进入时）─────────────┐                       │
│  │  1. 检查文档清单               │                       │
│  │  2. 读 GRAPH_REPORT.md 优先   │                       │
│  │  3. graphify query 深入查询   │                       │
│  │  4. 验证服务器实际状态          │                       │
│  │  5. 输出阅读摘要               │                       │
│  └──────────────────────────────┘                       │
│                      ↓                                   │
│  ┌─ 执行主要工作 ────────────────┐                       │
│  │  (训练 / 编码 / 修复 / 分析)   │                       │
│  └──────────────────────────────┘                       │
│                      ↓                                   │
│  ┌─ 阶段 B（完成后）─────────────┐                       │
│  │  1. 判断变更范围               │                       │
│  │  2. 按清单更新文档             │                       │
│  │  3. 重建 graphify 知识图谱    │                       │
│  │  4. 文档漂移检测               │                       │
│  │  5. 归档旧结论                 │                       │
│  │  6. 更新 CONTEXT              │                       │
│  └──────────────────────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

---

## 变更日志

### 1.1.0 (2026-08-16)
- 新增：文档写作规范（ASD-STE100）——项目文档遵守简化技术英语核心规则，完整规范见 technical-writing-standard.md

### 1.0.1 (2026-08-03)
- 移除：§A5 中 OpenCode 配置特征检测与决策矩阵条目（opencode_health_check.md 已删除）

### 1.0.0 (2026-07-30)
- 初始发布：跨项目文档阅读与更新协议
- 三个阶段：文档阅读（A）、文档更新（B）、文档基础设施创建（C）
- 整合 graphify 知识图谱的阅读（优先）与更新（变更后重建）
- 文档漂移检测机制
- 结论归档防污染规范
