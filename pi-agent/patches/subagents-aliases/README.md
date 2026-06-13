# subagents-aliases 补丁

为 pi-subagents (v0.28.0) 添加 agent 别名支持。

## 改动

在 `AgentConfig` 接口中添加 `aliases?: string[]` 字段，agent 定义可通过前置元数据设置别名：

```yaml
---
name: hephaestus
aliases: worker, builder
---
```

所有 `agents.find((a) => a.name === name)` 替换为 `findAgentConfig(agents, name)`，同时匹配名称和别名。

## 修改的文件

| 文件 | 改动 |
|---|---|
| src/agents/agents.ts | AgentConfig 加 aliases 字段，导出 findAgentConfig()，解析前置元数据 |
| src/agents/agent-serializer.ts | 序列化 aliases |
| src/agents/agent-management.ts | formatAgentDetail 显示别名 |
| src/runs/foreground/subagent-executor.ts | 9 处 agents.find → findAgentConfig |
| src/runs/foreground/execution.ts | 1 处 |
| src/runs/foreground/chain-execution.ts | 3 处 |
| src/runs/background/async-execution.ts | 4 处 |
| src/shared/settings.ts | 1 处 |
| src/slash/slash-commands.ts | 2 处 |

## 安装

将 `src/` 下的文件覆盖到 `pi-subagents` 包（`~/.pi/agent/npm/node_modules/pi-subagents/src/`），重启 pi。

## Agent 别名配置

- `hephaestus` → `worker`, `builder`
- `explore` → `scout`
- `prometheus` → `planner`
- `momus` → `reviewer`
- `oracle` → `oracle-builtin`
