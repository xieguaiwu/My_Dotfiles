---
name: subagent-temperature-fix
version: 1.1.0
description: 修复 pi-agent subagent 的 temperature 配置——打通从 Agent YAML 到 LLM API 的完整温度传递链，使 agent 文件中定义的 temperature 值真正生效
triggers:
  - "subagent温度修复"
  - "temperature fix"
  - "agent温度配置失效"
  - "修复temperature"
  - "修复温度"
  - "温度配置不生效"
  - "temperature not working"
  - "apply temperature patches"
inputs:
  - name: target_dir
    description: pi-agent npm 包安装目录（自动检测）
    required: false
    default: "auto-detect"
  - name: agent_yaml_dir
    description: agent YAML 定义文件所在目录
    required: false
    default: "auto-detect"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
---

# Subagent Temperature 配置修复

## 任务目标
修复 pi-agent 生态中 Agent YAML 文件 `temperature:` 字段无法传递给 LLM API 的问题。所有 agent 定义文件中精心设置的温度值（如 `artistry=0.7`, `explore=0.1`）被完全忽略，LLM 调用始终使用 API 默认温度。

**修复后数据流**：
```
Agent YAML → frontmatter解析 → AgentConfig.temperature
  → buildPiArgs({temperature}) → PI_SUBAGENT_TEMPERATURE env var
  → 子进程 pi → createAgentSession → new Agent({temperature})
  → createLoopConfig() → { temperature } → streamFn options
  → streamSimple → provider → if (temperature !== undefined) → LLM API
```

## 影响范围
4 个包，涉及 **12 个文件**：

| 包 | 文件数 | 作用 | 状态 |
|---|---|---|---|
| `pi-subagents` | 7 | 解析 YAML → 传递 env var | ⚠️ 已修复 2026-06-24 |
| `pi-coding-agent` | 4 | CLI 参数 → SDK → Agent | ✅ 已修复 2026-06-24（运行时路径 `~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/`） |
| `pi-agent-core` | 1 | Agent 类接受 + 传递温度 | ✅ 已修复 2026-06-24 |
| `pi-ai` providers | 0 | 已支持 `options.temperature`，无需修改 | ✅ 无需修改 |

> **注意路径差异**：`pi-coding-agent` 和 `pi-agent-core` 的运行时路径在 `~/.npm-global/lib/node_modules/` 下，**不是** `~/.pi/agent/npm/node_modules/`。`pi-subagents` 的运行时路径在 `~/.pi/agent/npm/node_modules/pi-subagents/`。

## 执行流程

### 0. 环境检测

```bash
# 自动检测 pi-agent 模块路径（注意：pi-coding-agent 在 npm-global 下，不在 .pi/agent/npm 下）
NPM_DIR="/home/xieguiawu/.pi/agent/npm/node_modules/pi-subagents"
PI_CODING_DIR="/home/xieguiawu/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE_DIR="$PI_CODING_DIR/node_modules/@earendil-works/pi-agent-core"
AGENT_YAML_DIR="/home/xieguiawu/.pi/agent/agents"

echo "pi-subagents:   ${NPM_DIR:-✗ NOT FOUND}"
echo "pi-coding-agent:${PI_CODING_DIR:-✗ NOT FOUND}"
echo "pi-agent-core:  ${AGENT_CORE_DIR:-✗ NOT FOUND}"
echo "agent YAML dir: ${AGENT_YAML_DIR:-✗ NOT FOUND}"
```

> ⚠️ **路径纠正**：`pi-coding-agent` 和 `pi-agent-core` 不在 `~/.pi/agent/npm/node_modules/` 下，而是在 `~/.npm-global/lib/node_modules/@earendil-works/` 下。

### 1. pi-subagents — 识别 temperature 为已知字段 ✅ 已修复

#### 1a. `agent-serializer.ts` — 加入 KNOWN_FIELDS ✅

在 `KNOWN_FIELDS` Set 中添加 `"temperature"`（在 `"thinking"` 之后）。

**文件路径**：`<NPM_DIR>/pi-subagents/src/agents/agent-serializer.ts`
**状态**：✅ 已应用

#### 1b. `agents.ts` — 扩展接口和解析逻辑 ✅

全部 9 处修改已应用：

- `AgentConfig` 接口添加 `temperature?: number`
- `BuiltinAgentOverrideBase` 添加 `temperature?: number`
- `BuiltinAgentOverrideConfig` 添加 `temperature?: number | false`
- `loadAgentsFromDir` 解析 frontmatter：`Number(frontmatter.temperature)`
- `cloneOverrideBase`/`cloneOverrideValue`/`parseBuiltinOverrideEntry`/`applyBuiltinOverride`/`applyCustomAgentOverride` 均覆盖
- `buildBuiltinOverrideConfig` 的 `Pick` 类型和比较逻辑

#### 1c. `pi-args.ts` — 传递 temperature 到子进程环境变量 ✅

- `BuildPiArgsInput` 接口添加 `temperature?: number`
- `buildPiArgs` 设置 `env.PI_SUBAGENT_TEMPERATURE = String(input.temperature)`

#### 1d. `execution.ts` — 从 agent config 读取 temperature 传入 buildPiArgs ✅

- `buildPiArgs` 调用添加 `temperature: agent.temperature`

#### 1e. `parallel-utils.ts` — 扩展 RunnerSubagentStep 接口 ✅

- `RunnerSubagentStep` 添加 `temperature?: number`

#### 1f. `async-execution.ts` — 后台异步路径加入 temperature ✅

- `buildSeqStep` 返回对象添加 `temperature: a.temperature`
- 第二条 step 创建路径添加 `temperature: agentConfig.temperature`

#### 1g. `subagent-runner.ts` — 后台 runner 的 buildPiArgs 调用 ✅

- 唯一的 `buildPiArgs` 调用添加 `temperature: step.temperature`
> **注意**：v0.31.0 中 `subagent-runner.ts` 只有 1 处 `buildPiArgs` 调用（原文档说 2 处，代码已重构）

### 2. pi-coding-agent — 接收并传递 temperature ✅ 已修复

> **路径说明**：运行时路径为 `~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/`，**不是** `~/.pi/agent/npm/node_modules/`。

所有修改已应用（2026-06-24）。

#### 2a. `dist/cli/args.js` ✅
- `--temperature <value>` 参数解析（0–2 范围校验）
- `printHelp` 追加帮助文本

#### 2b. `dist/main.js` ✅
- `buildSessionOptions` 读取 `parsed.temperature`
- 透传给 `createAgentSessionFromServices`

#### 2c. `dist/core/agent-session-services.js` ✅
- 透传 `temperature: options.temperature`

#### 2d. `dist/core/sdk.js` ✅
- 读取 `PI_SUBAGENT_TEMPERATURE` 环境变量
- 传给 `new Agent({temperature})`

### 3. pi-agent-core — Agent 类接受 temperature ✅ 已修复

> **路径说明**：`~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-agent-core/dist/agent.js`

#### 3a. `dist/agent.js` ✅
- `temperature` 属性声明
- 构造函数 `this.temperature = options.temperature`
- `createLoopConfig` 返回 `temperature: this.temperature`

### 4. 全链验证

```bash
# 检测路径
NPM_DIR="/home/xieguiawu/.pi/agent/npm/node_modules/pi-subagents"
PI_CODING_DIR="/home/xieguiawu/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE_DIR="$PI_CODING_DIR/node_modules/@earendil-works/pi-agent-core"
AGENT_YAML_DIR="/home/xieguiawu/.pi/agent/agents"

# 4a. pi-subagents：YAML 解析 → env var 传递
for src_file in "agent-serializer.ts" "agents.ts" "pi-args.ts" "execution.ts" "parallel-utils.ts" "async-execution.ts" "subagent-runner.ts"; do
  f=$(find "$NPM_DIR" -name "$src_file" -path "*/src/*" 2>/dev/null)
  grep -q "temperature" "$f" 2>/dev/null && echo "✅ $src_file" || echo "❌ $src_file MISSING"
done

# 4b. pi-coding-agent：CLI + SDK
grep -q "temperature" "$PI_CODING_DIR/dist/cli/args.js" && echo "✅ cli/args.js"
grep -q "PI_SUBAGENT_TEMPERATURE" "$PI_CODING_DIR/dist/core/sdk.js" && echo "✅ sdk.js reads env var"

# 4c. pi-agent-core：Agent 类
grep -q "this.temperature = options.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅ Agent class accepts temperature"
grep -q "temperature: this.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅ Agent createLoopConfig includes temperature"

# 4d. 所有 Agent YAML 的 temperature 值
echo "--- Agent YAML temperature 值 ---"
for f in "$AGENT_YAML_DIR"/*.md; do
    t=$(grep -oP 'temperature: \K[\d.]+' "$f" 2>/dev/null)
    [ -n "$t" ] && echo "  $(basename $f): $t"
done
```

### 5. 最终检查清单（当前状态：全部 ✅）

| # | 检查项 | 状态 |
|---|--------|------|
| 1 | `KNOWN_FIELDS` 包含 `"temperature"` | ✅ |
| 2 | `AgentConfig.temperature` `BuiltinAgentOverrideBase.temperature` `BuiltinAgentOverrideConfig.temperature` | ✅ |
| 3 | Frontmatter 解析 `Number(frontmatter.temperature)` | ✅ |
| 4 | `buildPiArgs` 接收 `temperature` 并设置 `PI_SUBAGENT_TEMPERATURE` env var | ✅ |
| 5 | CLI `--temperature` 参数解析（0-2 校验） | ✅ |
| 6 | `createAgentSession` 从 options / env var 读取温度 | ✅ |
| 7 | Agent 类 `createLoopConfig` 返回 `temperature` | ✅ |
| 8 | Provider 层已有 `options.temperature` 支持（无需修改） | ✅ |
| 9 | 前台路径 `execution.ts` 覆盖 | ✅ |
| 10 | 后台异步路径 `async-execution.ts` `subagent-runner.ts` 覆盖 | ✅ |
| 11 | Override 机制（`cloneOverrideBase/Value` `parseBuiltinOverrideEntry` `applyBuiltinOverride` `applyCustomAgentOverride` `buildBuiltinOverrideConfig`）全部覆盖 | ✅ |

## ⚠️ 注意事项

1. **上游更新覆盖**：修改的是 `node_modules/` 中的文件。运行 `npm update` 或重新安装包时，所有修改会被覆盖。需重新运行本 skill。
2. **Anthropic 特例**：Anthropic 模型在启用 thinking 时跳过 temperature（API 限制），`compat.supportsTemperature` 为 false 的模型也不接受自定义温度。这是 provider 层已有的行为，非本修复引入。
3. **默认值行为**：当 `temperature` 未设置（`undefined`）时，provider 使用 API 默认温度，与修复前行为一致。
4. **版本兼容**：`pi-subagents >= 0.28.0`，`pi-coding-agent >= 0.79.0`（当前已验证版本）。
5. **Git 安全网不适用**：本 skill 修改的是 `~/.pi/agent/npm/` 下的 `node_modules` 文件，位于 HOME 目录内。[Git 安全网规范](../git_safety_net.md) 的 HOME 目录保护规则禁止在此创建 git 仓库。建议每次修改后用本 skill 自带的验证步骤确认完整性即可。
