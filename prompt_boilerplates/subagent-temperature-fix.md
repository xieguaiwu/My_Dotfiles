---
name: subagent-temperature-fix
version: 1.0.0
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

| 包 | 文件数 | 作用 |
|---|---|---|
| `pi-subagents` | 7 | 解析 YAML → 传递 env var |
| `pi-coding-agent` | 4 | CLI 参数 → SDK → Agent |
| `pi-agent-core` | 1 | Agent 类接受 + 传递温度 |
| `pi-ai` providers | 0 | 已支持 `options.temperature`，无需修改 |

## 执行流程

### 0. 环境检测

```bash
# 自动检测 pi-agent npm 模块路径
NPM_DIR=$(find /home/xieguiawu/.pi/agent/npm/node_modules/pi-subagents -maxdepth 0 -type d 2>/dev/null)
PI_AI_DIR=$(find /home/xieguiawu/.pi/agent/npm/node_modules/@earendil-works/pi-ai -maxdepth 0 -type d 2>/dev/null)
PI_CODING_DIR=$(find /home/xieguiawu/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent -maxdepth 0 -type d 2>/dev/null)
AGENT_CORE_DIR=$(find /home/xieguiawu/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-agent-core -maxdepth 0 -type d 2>/dev/null)
AGENT_YAML_DIR="/home/xieguiawu/.pi/agent/agents"

echo "pi-subagents:   ${NPM_DIR:-✗ NOT FOUND}"
echo "pi-ai:          ${PI_AI_DIR:-✗ NOT FOUND}"
echo "pi-coding-agent:${PI_CODING_DIR:-✗ NOT FOUND}"
echo "pi-agent-core:  ${AGENT_CORE_DIR:-✗ NOT FOUND}"
echo "agent YAML dir: ${AGENT_YAML_DIR:-✗ NOT FOUND}"
```

如果任何包未找到，报错退出。

### 1. pi-subagents — 识别 temperature 为已知字段

#### 1a. `agent-serializer.ts` — 加入 KNOWN_FIELDS

在 `KNOWN_FIELDS` Set 中添加 `"temperature"`（和 `"thinking"` 并列）：

```typescript
// 找到以下行附近（thinking 所在行）：
// "thinking",
// 在其后添加：
"temperature",
```

**文件路径**：`<NPM_DIR>/pi-subagents/src/agents/agent-serializer.ts`

#### 1b. `agents.ts` — 扩展接口和解析逻辑

四处修改：

**① 在 `AgentConfig` 接口中添加 `temperature?: number`**（在 `thinking` 之后）：
```typescript
thinking?: string;
temperature?: number;   // ← 新增
systemPromptMode: SystemPromptMode;
```

**文件路径**：`<NPM_DIR>/pi-subagents/src/agents/agents.ts`

**② 在 `BuiltinAgentOverrideBase` 接口中添加 `temperature?: number`**（在 `thinking` 之后）

**③ 在 `BuiltinAgentOverrideConfig` 接口中添加 `temperature?: number | false`**

**④ 在 `loadAgentsFromDir` 解析 frontmatter 时添加**：
```typescript
thinking: frontmatter.thinking,
temperature: frontmatter.temperature !== undefined ? Number(frontmatter.temperature) : undefined,  // ← 新增
systemPromptMode,
```

**⑤ 在 `cloneOverrideBase` 中添加 `temperature: agent.temperature`**

**⑥ 在 `cloneOverrideValue` 中添加 temperature 展开**

**⑦ 在 `parseBuiltinOverrideEntry` 中添加 temperature 解析分支**

**⑧ 在 `applyBuiltinOverride` 中添加 temperature 应用**

**⑨ 在 `buildBuiltinOverrideConfig` 中：将 `"temperature"` 加入 `Pick` 类型，添加比较逻辑**

#### 1c. `pi-args.ts` — 传递 temperature 到子进程环境变量

**① `BuildPiArgsInput` 接口添加 `temperature?: number`**

**② `buildPiArgs` 函数体添加 env var 设置**（和 `childAgentName` 逻辑放一起）：
```typescript
if (input.temperature !== undefined) {
    env.PI_SUBAGENT_TEMPERATURE = String(input.temperature);
}
```

**文件路径**：`<NPM_DIR>/pi-subagents/src/runs/shared/pi-args.ts`

#### 1d. `execution.ts` — 从 agent config 读取 temperature 传入 buildPiArgs

在 `runSingleAttempt` 的 `buildPiArgs({...})` 调用中添加：
```typescript
model,
thinking: agent.thinking,
temperature: agent.temperature,  // ← 新增
systemPromptMode: agent.systemPromptMode,
```

**文件路径**：`<NPM_DIR>/pi-subagents/src/runs/foreground/execution.ts`

#### 1e. `parallel-utils.ts` — 扩展 RunnerSubagentStep 接口

在 `RunnerSubagentStep` 接口中添加 `temperature?: number`（在 `thinking` 之后）。

**文件路径**：`<NPM_DIR>/pi-subagents/src/runs/shared/parallel-utils.ts`

#### 1f. `async-execution.ts` — 后台异步路径加入 temperature

两处修改（step 创建时从 agent config 读取 `a.temperature`）：

**① `executeAsyncChain` 中的 step 创建**（`thinking` 所在行之后添加 `temperature: a.temperature`）

**② 另一处 step 创建（`agentConfig.temperature` 同理）**

**文件路径**：`<NPM_DIR>/pi-subagents/src/runs/background/async-execution.ts`

#### 1g. `subagent-runner.ts` — 后台 runner 的 buildPiArgs 调用

两处修改（在 `buildPiArgs({...})` 调用中添加 `temperature: step.temperature`）：

**① 首次 buildPiArgs 调用**（~line 707）：在 `model: candidate` 之后添加

**② 二次 buildPiArgs 调用**（~line 869，finalization loop）：在 `thinking: step.thinking` 之后添加

**文件路径**：`<NPM_DIR>/pi-subagents/src/runs/background/subagent-runner.ts`

### 2. pi-coding-agent — 接收并传递 temperature

#### 2a. `cli/args.js` — 添加 `--temperature` 参数解析

在 `--print` 处理分支之前，添加：

```javascript
else if (arg === "--temperature" && i + 1 < args.length) {
    const value = parseFloat(args[++i]);
    if (!isNaN(value) && value >= 0 && value <= 2) {
        result.temperature = value;
    } else {
        result.diagnostics.push({
            type: "warning",
            message: `Invalid temperature "${args[i]}". Expected a number between 0 and 2.`,
        });
    }
}
```

同时在 `printHelp` 的 options 列表中追加帮助文本。

**文件路径**：`<PI_CODING_DIR>/dist/cli/args.js`

#### 2b. `main.js` — buildSessionOptions 读取并传递 temperature

**① 在 `buildSessionOptions` 函数中，在 "API key from CLI" 注释前添加**：
```javascript
// Temperature from CLI
if (parsed.temperature !== undefined) {
    options.temperature = parsed.temperature;
}
```

**② 在 `createAgentSessionFromServices` 调用中添加 `temperature: sessionOptions.temperature`**

**文件路径**：`<PI_CODING_DIR>/dist/main.js`

#### 2c. `agent-session-services.js` — 透传 temperature

在 `createAgentSession` 调用中添加 `temperature: options.temperature`。

**文件路径**：`<PI_CODING_DIR>/dist/core/agent-session-services.js`

#### 2d. `core/sdk.js` — 读取 env var 并传给 Agent

在 `new Agent({...})` 调用之前，添加：

```javascript
// Read temperature from options or env var (set by pi-subagents when spawning child)
const temperature = options.temperature !== undefined
    ? options.temperature
    : process.env.PI_SUBAGENT_TEMPERATURE !== undefined
        ? parseFloat(process.env.PI_SUBAGENT_TEMPERATURE)
        : undefined;
```

然后在 `new Agent({` 的参数中添加 `temperature,`。

**文件路径**：`<PI_CODING_DIR>/dist/core/sdk.js`

### 3. pi-agent-core — Agent 类接受 temperature

#### 3a. `agent.js` — 属性声明 + 构造函数 + createLoopConfig

三处修改：

**① 声明属性**（在 `toolExecution` 后）：
```javascript
/** Temperature parameter passed to the LLM provider. */
temperature;
```

**② 构造函数赋值**（在 `this.toolExecution = ...` 后）：
```javascript
this.temperature = options.temperature;
```

**③ createLoopConfig 返回值添加**（在 `reasoning` 后）：
```javascript
temperature: this.temperature,
```

**文件路径**：`<AGENT_CORE_DIR>/dist/agent.js`

### 4. 验证

```bash
# 4a. 验证 --temperature CLI 参数解析
node -e "
const { parseArgs } = require('$PI_CODING_DIR/dist/cli/args.js');
const r1 = parseArgs(['--temperature', '0.5', '--print', 'test']);
console.assert(r1.temperature === 0.5, 'FAIL: temperature not 0.5');
const r2 = parseArgs(['--print', 'test']);
console.assert(r2.temperature === undefined, 'FAIL: temperature should be undefined');
console.log('✓ CLI parsing OK');
"

# 4b. 验证 Agent 类接受 temperature
grep -q "this.temperature = options.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✓ Agent class accepts temperature"
grep -q "temperature: this.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✓ Agent createLoopConfig includes temperature"

# 4c. 验证 sdk.js 读取 env var
grep -q "PI_SUBAGENT_TEMPERATURE" "$PI_CODING_DIR/dist/core/sdk.js" && echo "✓ SDK reads PI_SUBAGENT_TEMPERATURE env var"

# 4d. 验证 Agent YAML 文件中有 temperature
for f in "$AGENT_YAML_DIR"/*.md; do
    t=$(grep -oP 'temperature: \K[\d.]+' "$f" 2>/dev/null)
    [ -n "$t" ] && echo "  $(basename $f): temperature=$t"
done
```

### 5. 最终检查清单

完成后逐项确认：

- [ ] `KNOWN_FIELDS` 包含 `"temperature"`
- [ ] `AgentConfig.temperature` 已定义（`number` 类型）
- [ ] Frontmatter 解析逻辑转换 `Number(frontmatter.temperature)`
- [ ] `buildPiArgs` 接收 `temperature` 并设置 `PI_SUBAGENT_TEMPERATURE` 环境变量
- [ ] CLI `--temperature` 参数解析（0-2 范围校验）
- [ ] `createAgentSession` 从 options / `PI_SUBAGENT_TEMPERATURE` 读取温度
- [ ] Agent 类 `createLoopConfig` 返回 `temperature`
- [ ] 所有 provider 已有 `if (options.temperature !== undefined)` 处理（无需修改）
- [ ] 后台异步路径（async-execution.ts, subagent-runner.ts）也覆盖

## ⚠️ 注意事项

1. **上游更新覆盖**：修改的是 `node_modules/` 中的文件。运行 `npm update` 或重新安装包时，所有修改会被覆盖。需重新运行本 skill。
2. **Anthropic 特例**：Anthropic 模型在启用 thinking 时跳过 temperature（API 限制），`compat.supportsTemperature` 为 false 的模型也不接受自定义温度。这是 provider 层已有的行为，非本修复引入。
3. **默认值行为**：当 `temperature` 未设置（`undefined`）时，provider 使用 API 默认温度，与修复前行为一致。
4. **版本兼容**：`pi-subagents >= 0.28.0`，`pi-coding-agent >= 0.79.0`（当前已验证版本）。
5. **Git 安全网不适用**：本 skill 修改的是 `~/.pi/agent/npm/` 下的 `node_modules` 文件，位于 HOME 目录内。[Git 安全网规范](../git_safety_net.md) 的 HOME 目录保护规则禁止在此创建 git 仓库。建议每次修改后用本 skill 自带的验证步骤确认完整性即可。
