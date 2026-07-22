---
name: resource-aware-delegation
version: 1.0.0
description: 在发起 subagent 前检查系统资源状态，根据 CPU/内存/Swap/GPU/PSI 压力数据自动调整并行策略、turnBudget 和 timeoutMs，避免 OOM 和系统卡顿
triggers:
  - "资源检查"
  - "subagent 规划"
  - "系统负载"
  - "并行前检查"
  - "subagent 调度"
  - "subagent delegation"
  - "资源感知调度"
  - "pi-resmon"
  - "资源吃紧"
  - "OOM"
inputs:
  - name: agent_class
    description: 即将启动的子 agent 类型（light / medium / heavy）
    required: false
    default: "medium"
  - name: force_check
    description: 即使明显空闲也执行一次检查
    required: false
    default: "false"
tools:
  - bash
  - read
---

# Resource-Aware Delegation

## 任务目标

避免 pi-agent 在资源紧张时通过 subagent 过度并行/启动重量 agent 导致 OOM 或系统卡顿。通过轻量监测脚本 pi-resmon 在每次关键决策点采集系统快照，用风险等级指导调度策略。

## 执行流程

### 1. 触发时机（强制）

以下每个操作 **之前** 都必须执行 `pi-resmon --recommend [--class light|medium|heavy]`：

- `subagent({ tasks: [...] })` — 任何并行调用前
- `subagent({ chain: [...] })` — 任何链式调用前
- 启动以下子 agent 前：
  - **heavy**: `hephaestus`, `ultrabrain`, `deep`（高资源消耗）
  - **medium**: `momus`, `oracle`, `prometheus`, `metis`, `artistry`（中等资源）
  - **light**: `explore`, `quick`, `librarian`, `writing`, `visual-engineering`（低资源）

### 2. 执行监测

```bash
# 默认（medium class）
pi-resmon --recommend

# 明确 agent 类型
pi-resmon --recommend --class heavy
pi-resmon --recommend --class light

# 查阈值
pi-resmon --show-thresholds

# 快速看一眼
pi-resmon
```

### 3. 解读输出

`--recommend` 输出两行结构化 key=value：

**第 1 行：指标快照**

| 字段 | 说明 | 示例 |
|------|------|------|
| `RISK` | 风险等级 | `LOW` |
| `LOAD_RATIO` | 5-min 负载 / 逻辑核心数 | `0.34` |
| `MEM_AVAIL_MB` | 可用内存 MB（cgroup 感知） | `11476` |
| `MEM_TOTAL_MB` | 总内存 MB | `15871` |
| `MEM_CGROUP_LIMIT` | cgroup 上限是否就绪 | `inf` 或 `set` |
| `SWAP_PCT` | Swap 使用率 % | `20.4` |
| `SWAP_TYPE` | Swap 类型 | `zram` / `disk` / `none` |
| `PSI_CPU` | CPU 压力停顿 % | `1.77` |
| `PSI_MEM` | 内存压力停顿 % | `0.00` |
| `PSI_IO` | I/O 压力停顿 % | `0.00` |
| `GPU_AVAIL` | 是否有 GPU | `yes` / `no` |
| `DISK_PCT` | 当前分区使用率 % | `57` |
| `SELF_RSS_MB` | pi-agent 自身 RSS MB | `1014` |

**第 2 行：调度建议**

| 字段 | 说明 | 示例 |
|------|------|------|
| `ACTION` | 模式 | `free_parallel` |
| `MAX_PARALLEL` | 最大并行数 | `4` |
| `SUGGESTED_MAXTURNS_FACTOR` | turnBudget 缩放系数 | `1.0` |
| `SUGGESTED_TIMEOUTMS_FACTOR` | timeoutMs 缩放系数 | `1.0` |
| `WEIGHT_AGENTS` | 允许的 agent 重量级 | `all` |

**可选第 3 行：告警**

| 字段 | 说明 |
|------|------|
| `WARNINGS` | 如 `disk_usage=92%` / `load_spike_1m=3.2` |

### 4. 应用建议

#### 4.1 ACTION 模式

| 模式 | 含义 | 操作 |
|------|------|------|
| `free_parallel` | 资源充裕 | 可自由并行，上限由 `MAX_PARALLEL` 约束 |
| `restricted_parallel` | 资源适中 | 并行 ≤ `MAX_PARALLEL`，只启动 `WEIGHT_AGENTS` 允许的 agent |
| `serialize_only` | 资源紧张 | 不并行，全部串行；`WEIGHT_AGENTS` 外的 agent 禁用 |
| `defer_or_direct` | 资源临界 | 不启动 subagent，直接在当前上下文处理；向用户报告资源不足 |

#### 4.2 动态参数缩放

对规则 #9（timeoutMs）和 #13（turnBudget）的推荐值做缩放：

```python
adjusted_timeoutMs = base_timeoutMs * SUGGESTED_TIMEOUTMS_FACTOR
adjusted_maxTurns  = base_maxTurns * SUGGESTED_MAXTURNS_FACTOR  # round up
```

示例（HIGH 风险下启动 heavy agent）：
```
base:   timeoutMs=900000, maxTurns=30
factor: timeoutMs ×1.5 → 1350000,  maxTurns ×0.6 → 18
apply:  subagent({ agent:"hephaestus", timeoutMs: 1350000, turnBudget: { maxTurns: 18 } })
```

#### 4.3 WARNINGS 响应

- `disk_usage > 90%` → 避免写入大文件（日志、缓存、生成物）；优先用 `edit` 而非 `write`
- `load_spike` → 若 spike 伴随高 PSI，等待 30s 后复检再决定是否并行

### 5. CRITICAL 时的回退策略

当 `RISK=CRITICAL` 时：

1. **串行化**：将所有任务转为 `chain` 而非 `tasks: []`
2. **降级**：替换重量 agent 为轻量（hephaestus → quick, ultrabrain → explore）
3. **等待复检**：若自身已占大量资源（`SELF_RSS_MB` 很大），先完成当前工作再启动新 agent
4. **通知用户**：持续 CRITICAL 时向用户报告："系统资源不足（Mem ≤1GB / 负载 >2.5），建议关闭其他进程后重试"

### 6. agent 重量级分类

| 重量 | agent | 内存估计 | 推荐场景 |
|------|-------|---------|---------|
| light | explore, quick, librarian, writing, technical-writing, sisyphus-junior | ~50-200MB | 搜索、读文件、小修改 |
| medium | momus, oracle, prometheus, metis, artistry, frontend-tester | ~200-500MB | 审查、规划、中等实现 |
| heavy | hephaestus, ultrabrain, deep | ~500-2000MB+ | 大实现、复杂推理 |

## 输出示例

### 空闲机器（LOW）

```
$ pi-resmon --recommend
RISK=LOW LOAD_RATIO=0.34 MEM_AVAIL_MB=11476 MEM_TOTAL_MB=15871 MEM_CGROUP_LIMIT=inf SWAP_PCT=20.4 SWAP_TYPE=zram PSI_CPU=1.77 PSI_MEM=0.00 PSI_IO=0.00 GPU_AVAIL=no DISK_PCT=57 SELF_RSS_MB=1014
ACTION=free_parallel MAX_PARALLEL=4 SUGGESTED_MAXTURNS_FACTOR=1.0 SUGGESTED_TIMEOUTMS_FACTOR=1.0 WEIGHT_AGENTS=all
```

→ 自由并行，无需调整

### 重负载（HIGH）

```
$ pi-resmon --recommend --class heavy
RISK=HIGH LOAD_RATIO=2.10 MEM_AVAIL_MB=1500 MEM_TOTAL_MB=15871 MEM_CGROUP_LIMIT=inf SWAP_PCT=8 SWAP_TYPE=disk PSI_CPU=45.2 PSI_MEM=18.7 PSI_IO=3.2 GPU_AVAIL=no DISK_PCT=92 SELF_RSS_MB=980
ACTION=serialize_only MAX_PARALLEL=1 SUGGESTED_MAXTURNS_FACTOR=0.6 SUGGESTED_TIMEOUTMS_FACTOR=1.5 WEIGHT_AGENTS=light_only
WARNINGS=disk_usage=92%
```

→ 串行化、仅 light agent、timeoutMs ×1.5、maxTurns ×0.6

## 注意事项

1. **pi-resmon 是权威源** — 决策矩阵只存在于脚本内；本 skill 不重复数值，只说明用法。矩阵数值通过 `pi-resmon --show-thresholds` 动态查看。
2. **无状态快照** — pi-resmon 每次运行独立采样，不做趋势预测。如需趋势分析，由 orchestrator 多次调用后自行判断。
3. **zram vs disk** — pi-resmon 自动区分 swap 类型。zram 是压缩内存（健康行为），阈值远宽于磁盘 swap。
4. **cgroup 感知** — 在容器或 systemd slice 中运行时，pi-resmon 自动读取 cgroup v2 内存上限，不会因 `/proc/meminfo` 显示宿主总内存而虚高。
5. **PSI 优先** — PSI（Pressure Stall Information）是内核级真实停顿百分比，比 loadavg / swap% 更准确。无 PSI 的老内核（<4.20）降级为 loadavg + swap 回退。
6. **Self RSS** — 输出包含 pi-agent 自身 RSS，orchestrator 可了解自己已消耗的内存。
