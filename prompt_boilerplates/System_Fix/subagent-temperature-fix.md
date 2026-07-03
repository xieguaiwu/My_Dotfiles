---
name: subagent-temperature-fix
version: 2.0.0
description: 验证并修复 pi-agent subagent 的 temperature 配置链。检测 4 个包 12 个文件是否完整传递 temperature，如被 npm update 覆盖则自动重新打补丁。同时可作为温度配置审计工具。
triggers:
  - "subagent温度修复"
  - "temperature fix"
  - "agent温度配置失效"
  - "修复temperature"
  - "修复温度"
  - "温度配置不生效"
  - "temperature not working"
  - "apply temperature patches"
  - "温度链验证"
  - "temperature audit"
  - "检查温度配置"
inputs:
  - name: mode
    description: "verify-only: 只检查不修改 | auto: 检测到缺失自动修复（默认）"
    required: false
    default: "auto"
tools:
  - read
  - edit
  - bash
  - grep
  - find
---

# Subagent Temperature 配置 — 验证 & 修复

## 目标

验证 **Agent YAML → LLM API** 的完整温度传递链是否完好。如果 npm update / 重装覆盖了补丁，自动重新应用。

**数据流**：
```
Agent YAML → frontmatter解析 → AgentConfig.temperature
  → buildPiArgs({temperature}) → PI_SUBAGENT_TEMPERATURE env var
  → 子进程 pi → createAgentSession → new Agent({temperature})
  → createLoopConfig() → { temperature } → streamFn options
  → streamSimple → provider → if (temperature !== undefined) → LLM API
```

## 影响范围

| 包 | 文件 | 作用 |
|---|---|---|
| `pi-subagents` | `agent-serializer.ts` | KNOWN_FIELDS 白名单 + 序列化 |
| | `agents.ts` | 接口定义 + frontmatter 解析 + 覆写逻辑 |
| | `pi-args.ts` → `pi-args.ts` | env var 传递 |
| | `execution.ts` | 前台路径 buildPiArgs |
| | `parallel-utils.ts` | 并行任务接口 |
| | `async-execution.ts` | 后台异步路径 |
| | `subagent-runner.ts` | 后台 runner 路径 |
| `pi-coding-agent` | `cli/args.js` | CLI `--temperature` 参数 |
| | `main.js` | 选项透传 |
| | `agent-session-services.js` | 会话创建透传 |
| | `core/sdk.js` | env var → Agent |
| `pi-agent-core` | `agent.js` | Agent 类接收 + createLoopConfig |

> `pi-ai` providers 原生支持 `options.temperature`，无需修改 ✅

---

## 执行流程

### Step 0：设定路径

```bash
NPM_DIR="$HOME/.pi/agent/npm/node_modules/pi-subagents"
PI_CODING_DIR="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE_DIR="$PI_CODING_DIR/node_modules/@earendil-works/pi-agent-core"
AGENT_YAML_DIR="$HOME/.pi/agent/agents"

echo "pi-subagents:    ${NPM_DIR:?NOT FOUND}"
echo "pi-coding-agent: ${PI_CODING_DIR:?NOT FOUND}"
echo "pi-agent-core:   ${AGENT_CORE_DIR:?NOT FOUND}"
echo "agent YAML dir:  ${AGENT_YAML_DIR:?NOT FOUND}"
```

---

### Step 1：全链验证（检测模式）

运行以下脚本，逐项检查每层温度传递是否完整。`✅`=通过，`❌`=缺失。

```bash
NPM_DIR="$HOME/.pi/agent/npm/node_modules/pi-subagents"
PI_CODING_DIR="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE_DIR="$PI_CODING_DIR/node_modules/@earendil-works/pi-agent-core"
AGENT_YAML_DIR="$HOME/.pi/agent/agents"

PASS=0 FAIL=0
check() { local file=$1 label=$2 pattern=$3; shift 3
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  ✅ $label"; ((PASS++))
  else
    echo "  ❌ $label"; ((FAIL++))
  fi
}

echo "=== Step 1：全链温度验证 ==="
echo ""
echo "--- pi-subagents 源文件（7） ---"
check "$NPM_DIR/src/agents/agent-serializer.ts" \
  "KNOWN_FIELDS 包含 temperature" '"temperature"'
check "$NPM_DIR/src/agents/agents.ts" \
  "AgentConfig 接口有 temperature?: number" "temperature?: number"
check "$NPM_DIR/src/agents/agents.ts" \
  "loadAgentsFromDir 解析 frontmatter.temperature" "Number(frontmatter.temperature)"
check "$NPM_DIR/src/runs/shared/pi-args.ts" \
  "BuildPiArgsInput 有 temperature?: number" "temperature?: number"
check "$NPM_DIR/src/runs/shared/pi-args.ts" \
  "buildPiArgs 设置 PI_SUBAGENT_TEMPERATURE env" "PI_SUBAGENT_TEMPERATURE"
check "$NPM_DIR/src/runs/foreground/execution.ts" \
  "execution.ts buildPiArgs 传 temperature" "temperature: agent.temperature"
check "$NPM_DIR/src/runs/background/async-execution.ts" \
  "async-execution.ts 传 temperature（buildSeqStep）" "temperature: a.temperature"
check "$NPM_DIR/src/runs/background/async-execution.ts" \
  "async-execution.ts 传 temperature（agentConfig）" "temperature: agentConfig.temperature"
check "$NPM_DIR/src/runs/background/subagent-runner.ts" \
  "subagent-runner.ts buildPiArgs 传 temperature" "temperature: step.temperature"

echo ""
echo "--- pi-coding-agent 编译文件（4） ---"
check "$PI_CODING_DIR/dist/cli/args.js" \
  "CLI --temperature 参数解析" "result.temperature"
check "$PI_CODING_DIR/dist/main.js" \
  "main.js 读取 parsed.temperature" "parsed.temperature"
check "$PI_CODING_DIR/dist/core/agent-session-services.js" \
  "agent-session-services.js 透传 temperature" "temperature: options.temperature"
check "$PI_CODING_DIR/dist/core/sdk.js" \
  "sdk.js 读取 PI_SUBAGENT_TEMPERATURE env" "PI_SUBAGENT_TEMPERATURE"

echo ""
echo "--- pi-agent-core 编译文件（1） ---"
check "$AGENT_CORE_DIR/dist/agent.js" \
  "Agent 构造函数接受 temperature" "this.temperature = options.temperature"
check "$AGENT_CORE_DIR/dist/agent.js" \
  "Agent createLoopConfig 返回 temperature" "temperature: this.temperature"

echo ""
echo "--- Agent YAML 配置完整性 ---"
YAML_COUNT=0
for f in "$AGENT_YAML_DIR"/*.md; do
  t=$(grep -oP 'temperature: \K[\d.]+' "$f" 2>/dev/null)
  if [ -n "$t" ]; then
    echo "  ✅ $(basename $f): $t"
    ((YAML_COUNT++))
  fi
done
echo "  共 $YAML_COUNT 个 YAML 已配置 temperature"

echo ""
echo "=== 结果: $PASS 通过, $FAIL 缺失 ==="
if [ $FAIL -eq 0 ]; then echo "🎉 温度全链完好"; else echo "⚠️  需要修复（$FAIL 处缺失）"; fi
```

---

### Step 2：修复模式（如验证发现缺失）

如果 `$FAIL > 0`，根据缺失项运行对应的修复脚本。每个脚本是幂等的——多次运行不会重复插入。

#### 2a. pi-subagents — `KNOWN_FIELDS` 白名单

```bash
# 文件: src/agents/agent-serializer.ts
FILE="$NPM_DIR/src/agents/agent-serializer.ts"
if ! grep -q '"temperature"' "$FILE"; then
  # 在 "thinking" 之后插入 "temperature"
  sed -i '/"thinking",/a\	"temperature",' "$FILE"
  echo "✅ agent-serializer.ts: 已加入 temperature 到 KNOWN_FIELDS"
fi
```

#### 2b. pi-subagents — `agents.ts` 接口 + 解析 + 覆写

```bash
FILE="$NPM_DIR/src/agents/agents.ts"

# AgentConfig 接口：添加 temperature?: number
if ! grep -q "temperature" < <(sed -n '/interface AgentConfig/,/^}/p' "$FILE"); then
  sed -i '/thinking?: string;/a\temperature?: number;' "$FILE"
fi

# BuiltinAgentOverrideConfig 接口
if ! grep -q "temperature" < <(sed -n '/interface BuiltinAgentOverrideConfig/,/^}/p' "$FILE"); then
  sed -i '/thinking?: string;/a\\ttemperature?: number | false;' "$FILE"
fi

# loadAgentsFromDir 解析 frontmatter（在 thinking 行后添加）
if ! grep -q "Number(frontmatter.temperature)" "$FILE"; then
  sed -i '/thinking: frontmatter.thinking,/a\\ttemperature: frontmatter.temperature !== undefined ? Number(frontmatter.temperature) : undefined,' "$FILE"
fi

# cloneOverrideBase
if ! grep -q "temperature: agent.temperature" "$FILE"; then
  sed -i '/thinking: agent.thinking,/a\\ttemperature: agent.temperature,' "$FILE"
fi

# buildBuiltinOverrideConfig：在 Pick 中加入 temperature
if ! grep -q '"temperature"' "$FILE" | grep -q "Pick"; then
  sed -i 's/\("thinking".*\)"\(.*\)"/\1"temperature", \2/' "$FILE" 2>/dev/null || true
fi

echo "✅ agents.ts: 接口/解析/覆写已补全"
```

#### 2c. pi-subagents — `pi-args.ts` 环境变量

```bash
FILE="$NPM_DIR/src/runs/shared/pi-args.ts"

# BuildPiArgsInput 接口添加 temperature
if ! grep -q "temperature?: number" "$FILE"; then
  sed -i '/childAgentName?: string;/a\\ttemperature?: number;' "$FILE"
fi

# buildPiArgs 设置 env var
if ! grep -q "PI_SUBAGENT_TEMPERATURE" "$FILE"; then
  sed -i '/if (input.childAgentName !== undefined)/i\\tif (input.temperature !== undefined) {\n\t\tenv.PI_SUBAGENT_TEMPERATURE = String(input.temperature);\n\t}' "$FILE"
fi
echo "✅ pi-args.ts: 环境变量传递已补全"
```

#### 2d. pi-subagents — `execution.ts` 前台路径

```bash
FILE="$NPM_DIR/src/runs/foreground/execution.ts"
if ! grep -q "temperature: agent.temperature" "$FILE"; then
  sed -i '/thinking: agent.thinking,/a\\ttemperature: agent.temperature,' "$FILE"
  echo "✅ execution.ts: 前台 buildPiArgs 传 temperature"
fi
```

#### 2e. pi-subagents — `parallel-utils.ts` 接口

```bash
FILE="$NPM_DIR/src/runs/shared/parallel-utils.ts"
if ! grep -q "temperature?: number" "$FILE"; then
  sed -i '/thinking?: string;/a\\ttemperature?: number;' "$FILE"
  echo "✅ parallel-utils.ts: RunnerSubagentStep 添加 temperature"
fi
```

#### 2f. pi-subagents — `async-execution.ts` 后台双路径

```bash
FILE="$NPM_DIR/src/runs/background/async-execution.ts"
# buildSeqStep 路径
if ! grep -q "temperature: a.temperature" "$FILE"; then
  sed -i '/thinking: a.thinking,/a\\ttemperature: a.temperature,' "$FILE"
fi
# agentConfig 路径（第二个位置）
if ! grep -q "temperature: agentConfig.temperature" "$FILE"; then
  sed -i '0,/temperature: a.temperature/! s|/thinking: step.thinking,/|&\n\\ttemperature: agentConfig.temperature,|' "$FILE" 2>/dev/null || true
fi
echo "✅ async-execution.ts: 后台双路径已补全"
```

#### 2g. pi-subagents — `subagent-runner.ts` 后台 runner

```bash
FILE="$NPM_DIR/src/runs/background/subagent-runner.ts"
if ! grep -q "temperature: step.temperature" "$FILE"; then
  sed -i '/thinking: step.thinking,/a\\ttemperature: step.temperature,' "$FILE"
  echo "✅ subagent-runner.ts: 后台 runner buildPiArgs 传 temperature"
fi
```

#### 2h. pi-coding-agent — `cli/args.js` 参数解析

```bash
FILE="$PI_CODING_DIR/dist/cli/args.js"
if ! grep -q "-temperature" "$FILE"; then
  # 在 --print 处理前插入
  sed -i '/else if (arg === "--print"/i\\telse if (arg === "--temperature" \&\& i + 1 < args.length) {\n\t\tconst value = parseFloat(args[++i]);\n\t\tif (!isNaN(value) \&\& value >= 0 \&\& value <= 2) {\n\t\t\tresult.temperature = value;\n\t\t} else {\n\t\t\tresult.diagnostics.push({ type: "warning", message: `Invalid temperature "${args[i]}". Expected 0-2.` });\n\t\t}\n\t}' "$FILE"
  echo "✅ cli/args.js: --temperature 参数解析已添加"
fi
```

#### 2i. pi-coding-agent — `main.js` 选项透传

```bash
FILE="$PI_CODING_DIR/dist/main.js"
if ! grep -q "parsed.temperature" "$FILE"; then
  sed -i '/\/\/ API key from CLI/i\\t// Temperature from CLI\n\tif (parsed.temperature !== undefined) {\n\t\toptions.temperature = parsed.temperature;\n\t}' "$FILE"
  # 在 createAgentSessionFromServices 调用中添加 temperature
  sed -i 's/\(createAgentSessionFromServices({\)/\1\n\ttemperature: sessionOptions.temperature,/' "$FILE"
  echo "✅ main.js: temperature 从 CLI 到 session 透传"
fi
```

#### 2j. pi-coding-agent — `agent-session-services.js`

```bash
FILE="$PI_CODING_DIR/dist/core/agent-session-services.js"
if ! grep -q "temperature: options.temperature" "$FILE"; then
  sed -i '/createAgentSession({/a\\ttemperature: options.temperature,' "$FILE"
  echo "✅ agent-session-services.js: 透传 temperature"
fi
```

#### 2k. pi-coding-agent — `core/sdk.js` env var → Agent

```bash
FILE="$PI_CODING_DIR/dist/core/sdk.js"
if ! grep -q "PI_SUBAGENT_TEMPERATURE" "$FILE"; then
  sed -i '/new Agent({/i\\tconst envTemperature = process.env.PI_SUBAGENT_TEMPERATURE;\n\tconst temperature = options.temperature !== undefined ? options.temperature : (Number.isFinite(Number(envTemperature)) ? Number(envTemperature) : undefined);' "$FILE"
  sed -i '/new Agent({/a\\ttemperature,' "$FILE"
  echo "✅ sdk.js: env var → Agent 传递"
fi
```

#### 2l. pi-agent-core — `agent.js` Agent 类

```bash
FILE="$AGENT_CORE_DIR/dist/agent.js"
if ! grep -q "this.temperature = options.temperature" "$FILE"; then
  sed -i '/this.toolExecution =/a\\tthis.temperature = options.temperature;' "$FILE"
  sed -i '/reasoning: this.reasoning,/a\\ttemperature: this.temperature,' "$FILE"
  echo "✅ agent.js: Agent 类接受 + 传递 temperature"
fi
```

---

### Step 3：修复后验证

重新运行 Step 1 的验证脚本，确认所有 `❌` 变为 `✅`。

```bash
# 快速二次验证：检查关键路径
NPM_DIR="$HOME/.pi/agent/npm/node_modules/pi-subagents"
PI_CODING_DIR="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE_DIR="$PI_CODING_DIR/node_modules/@earendil-works/pi-agent-core"

echo "=== 修复后快验 ==="
echo -n "KNOWN_FIELDS:        "; grep -q '"temperature"' "$NPM_DIR/src/agents/agent-serializer.ts" && echo "✅" || echo "❌"
echo -n "PI_SUBAGENT env var: "; grep -q "PI_SUBAGENT_TEMPERATURE" "$NPM_DIR/src/runs/shared/pi-args.ts" && echo "✅" || echo "❌"
echo -n "CLI --temperature:   "; grep -q -e "result.temperature" "$PI_CODING_DIR/dist/cli/args.js" && echo "✅" || echo "❌"
echo -n "SDK env var read:    "; grep -q "PI_SUBAGENT_TEMPERATURE" "$PI_CODING_DIR/dist/core/sdk.js" && echo "✅" || echo "❌"
echo -n "Agent accept temp:   "; grep -q "this.temperature = options.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅" || echo "❌"
echo -n "Agent createLoop:    "; grep -q "temperature: this.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅" || echo "❌"
```

---

## ⚠️ 注意事项

1. **npm update 会覆盖**：所有修改在 `node_modules/` 中。运行 `npm update` 或重装后需重新运行本 skill。
2. **Anthropic 特例**：启用 thinking 时跳 temperature（API 限制），`compat.supportsTemperature=false` 的模型也不接受自定义温度。这是 provider 层行为，非本修复引入。
3. **默认值行为**：`temperature` 未设置（`undefined`）时，provider 使用 API 默认温度，与修复前一致。
4. **版本要求**：`pi-subagents >= 0.28.0`，`pi-coding-agent >= 0.79.0`。
5. **Git 安全网不适用**：修改的是 `~/.pi/agent/npm/` 和 `~/.npm-global/` 下的 `node_modules` 文件，位于 HOME 目录内。不能用 git 追踪。每次 npm update 后重新运行本 skill。
