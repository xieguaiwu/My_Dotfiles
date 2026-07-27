## Cross-Agent Guidelines

These rules apply to ALL agents in this system:

1. **Be concise** — Direct answers, no preamble, no flattery
2. **Use `subagent` for delegation** — When a task is outside your scope or requires specialist skills, delegate rather than doing it poorly
3. **Parallelize independent work** — If multiple agents can work simultaneously, fan out with `tasks: []`
4. **Synthesize results** — When you receive subagent output, summarize and integrate it, don't just pass through raw results
5. **Call out uncertainty** — If you're unsure about something, say so directly. Don't guess.
### 编码专用规则

6. **No type-error suppression** — Never use `as any`, `@ts-ignore`, or equivalent to silence type errors
7. **Bugfix → fix minimally** — Fix the bug, don't refactor the surrounding code

### 编排规则

8. **Chain calls should use `clarify: false`** — Always pass `clarify: false` on `subagent({ chain: [...] })` calls to skip the interactive TUI and run directly. This avoids unnecessary approval prompts during multi-agent orchestration.

### 超时保护

9. **Subagent 调用必须传 `timeoutMs`** — 每次调用 subagent 时必须传递 `timeoutMs` 参数，防止单个 agent 无限挂起整个工作流。推荐值：
   - 轻量任务 (`explore`, `quick`, `librarian`): `timeoutMs: 300000` (5 min)
   - 中等任务 (`deep`, `momus`, `oracle`, `prometheus`, `metis`): `timeoutMs: 600000` (10 min)
   - 重量任务 (`hephaestus`, `ultrabrain`): `timeoutMs: 900000` (15 min)
   - Chain 调用: `timeoutMs` 设为各步推荐值之和，最低 600000

   注意：`timeoutMs` 到期后编排器可继续推进，不要因为一个 agent 卡住而阻塞整个会话。

### 资源感知调度

10. **Subagent 资源感知调度** — 每次发起 `subagent({ tasks: [...] })`、`subagent({ chain: [...] })` 或调用重量级子 agent（hephaestus/ultrabrain/deep）前，必须先执行 `pi-resmon --recommend [--class light|medium|heavy]` 获取当前资源评估。
    - 根据 `ACTION` 字段调整策略：`free_parallel`（自由并行）、`restricted_parallel`（最大并行 ≤ `MAX_PARALLEL`，仅限 `WEIGHT_AGENTS` 允许的 agent）、`serialize_only`（仅串行）、`defer_or_direct`（不启动 subagent，直接处理）。
    - 应用 `SUGGESTED_MAXTURNS_FACTOR` 缩放 `turnBudget.maxTurns`（规则 #13），`SUGGESTED_TIMEOUTMS_FACTOR` 缩放 `timeoutMs`（规则 #9）。
    - 若 `WARNINGS` 含 `disk_usage>90%`，避免写入大文件。
    - 详见 skill `resource-aware-delegation`，阈值矩阵通过 `pi-resmon --show-thresholds` 查看。
