---
name: subagent-temperature-fix
version: 2.15.0
description: 验证并修复 pi-agent subagent 的 temperature 配置链。v2.5.0 起采用双保险架构：① 传递链补丁（pi-subagents 解析→buildPiArgs→env）② 消费点 YAML 兜底（sdk.js 在 env 缺失时直读 ~/.pi/agent/agents/<name>.md frontmatter）——即使上游 pi-subagents 再次删除 temperature 支持，温度依然生效。v2.6.0 适配 pi-subagents v0.40.0（第 4 次删除）并修复 str.replace 子串误伤 spawnRunner 的静默污染 bug（heal + 锚定正则 + 完整性断言）。v2.7.0 适配 pi-subagents v0.41.0 + pi-coding-agent v0.84.0（第 5 次删除）：agents.ts 全面改为 spread 语法，修复 reapply.sh 假阳性 bug（双锚点回退 + 变更检测）。v2.8.0 适配 pi-subagents v0.42.1 + pi-coding-agent v0.84.1（第 6 次删除）：锚点未漂移（21/21 直接命中），但发现并修复 **CRITICAL bug**——sdk.js 的 readFileSync import 检查在插入后执行且用子串匹配（插入块本身含 readFileSync 字样），导致 import 永不添加，YAML 兜底路径运行时抛 ReferenceError；修复为精确匹配 import 行。v2.9.0 适配 pi-subagents v0.43.0（第 7 次删除）：锚点与 v0.42.1 完全一致，21/21 一次重打成功。v2.10.0 适配 pi-subagents v0.45.0（第 8 次删除）：v0.44.0（mission/schedule）+ v0.45.0（subagent_wait completions）均未触碰 temperature 结构，锚点与 v0.43.0 完全一致，21/21 一次重打成功。v2.11.0 适配 pi-subagents v0.45.2（第 9 次删除）：v0.45.1/0.45.2 重构 async-execution.ts 的 thinking 计算（effectiveThinking/thinkingOverrides 新机制），但 v2.10.0 的 resolveEffectiveThinking 锚点全部命中，21/21 一次重打成功（无漂移警告）。v2.12.0 适配 pi-subagents v0.46.0（第 10 次删除）：v0.46.0（prompts.render/project-panes API/guide）未触碰 temperature 结构，v2.11.0 锚点全部命中，21/21 一次重打成功（无漂移警告，插入点人工核验通过）。v2.13.0 适配 pi-subagents v0.47.0（第 11 次删除）：v0.47.0（模型 scope 强制/storage 迁移 .pi/subagents/）未触碰 temperature 结构，v2.12.0 锚点全部命中，21/21 一次重打成功（无漂移警告）。v2.14.0 适配 pi-subagents v0.48.0（第 12 次删除）：v0.48.0（fan-out budget 上限/异步会话 cap/Prompt Audit drawer/全局 timeoutMs/PI_SUBAGENT_TASK_DELIVERY env/LLM intent arbiter）未触碰 temperature 结构，v2.13.0 锚点全部命中，postinstall 自动重打 21/21 成功；另修复 reapply.sh 标题计数错误（source files (12) → (13)）。v2.15.0 适配 pi-subagents v0.49.0 + pi-coding-agent v0.84.2（第 13 次删除）：v0.49.0（单 child 运行/debug.run/tools inherit/终端示例）未触碰 temperature 结构但再次删除全部 13 个 src 检查点（npm pack 原始 tarball 验证 0 引用），src 层由 postinstall 自动重打 13/13；dist 层被 pi update 0.84.2（--ignore-scripts 不触发 postinstall）覆盖 → 8 检查点全缺，手动 --apply 一次重打 21/21，运行时断链模拟三场景全部通过。共 21 个检查点（含 spawnRunner 6-tab 专用 + serializer 输出 + YAML 兜底），补丁集成在 ~/.pi/patches/temperature/reapply.sh（postinstall 自动重打）。⚠️ 补丁后必须重启 pi 主进程才生效（tsx 模块缓存，见注意事项 #7）。
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

**数据流**（双保险）：
```
主路径（传递链）：
Agent YAML → frontmatter解析 → AgentConfig.temperature
  → buildPiArgs({temperature}) → PI_SUBAGENT_TEMPERATURE env var

兜底路径（消费点 YAML 直读，v2.5.0 新增）：
  → 子进程 env 无温度时，sdk.js 用 PI_SUBAGENT_CHILD_AGENT + getAgentDir()
    直读 ~/.pi/agent/agents/<name>.md frontmatter 的 temperature

汇合：
  → 子进程 pi → new Agent({temperature})
  → createLoopConfig() → { temperature } → streamFn options
  → streamSimple → provider → if (temperature !== undefined) → LLM API
```

**为什么兜底是一劳永逸的**：pi-subagents 已连续 3 个版本（0.37/0.38/0.39）删除 temperature 支持，每次结构都变（anchor 漂移）。但 `~/.pi/agent/agents/*.md` 的路径和 frontmatter 格式由我们控制、从不变化；`PI_SUBAGENT_CHILD_AGENT` env 是 pi-subagents 从未删过的核心机制。兜底把温度权威源固定在「子进程入口 + 我们的文件」上，中间链条断掉也无害（2026-08-02 已实测：禁用 env 传递后，子进程仍从 YAML 读到正确温度 0.1）。

## 影响范围

| 包 | 文件 | 作用 |
|---|---|---|
| `pi-subagents` | `agent-serializer.ts` | KNOWN_FIELDS 白名单 + 序列化 |
| | `agents.ts` | 接口定义 + frontmatter 解析 + 覆写逻辑 |
| | `pi-args.ts` | env var 传递 |
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

echo "pi-subagents:    ${NPM_DIR:?NOT FOUND} ($(node -e "console.log(require('$NPM_DIR/package.json').version)" 2>/dev/null || echo '?'))"
echo "pi-coding-agent: ${PI_CODING_DIR:?NOT FOUND} ($(node -e "console.log(require('$PI_CODING_DIR/package.json').version)" 2>/dev/null || echo '?'))"
echo "pi-agent-core:   ${AGENT_CORE_DIR:?NOT FOUND} ($(node -e "console.log(require('$AGENT_CORE_DIR/package.json').version)" 2>/dev/null || echo '?'))"
echo "agent YAML dir:  ${AGENT_YAML_DIR:?NOT FOUND}"
```

---

### Step 1：快速检测（推荐）

优先使用集成检测脚本（覆盖全部 21 检查点）：
```bash
~/.pi/patches/temperature/reapply.sh
```

### Step 2：手动全链验证（备选）

仅在 reapply.sh 不可用时运行以下脚本，逐项检查每层温度传递是否完整。`✅`=通过，`❌`=缺失。

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

echo "=== Step 2：全链温度验证 ==="
echo ""
echo "--- pi-subagents 源文件（13） ---"
check "$NPM_DIR/src/agents/agent-serializer.ts" \
  "KNOWN_FIELDS 包含 temperature" '"temperature"'
check "$NPM_DIR/src/agents/agent-serializer.ts" \
  "serializer 输出 temperature" "config.temperature"
check "$NPM_DIR/src/agents/agents.ts" \
  "AgentConfig 接口有 temperature?: number" "temperature?: number"
check "$NPM_DIR/src/agents/agents.ts" \
  "loadAgentsFromDir 解析 frontmatter.temperature" "Number(frontmatter.temperature)"
check "$NPM_DIR/src/runs/shared/pi-args.ts" \
  "BuildPiArgsInput 有 temperature?: number" "temperature?: number"
check "$NPM_DIR/src/runs/shared/pi-args.ts" \
  "buildPiArgs 设置 PI_SUBAGENT_TEMPERATURE env" "PI_SUBAGENT_TEMPERATURE"
check "$NPM_DIR/src/runs/shared/parallel-utils.ts" \
  "parallel-utils.ts 有 temperature?: number" "temperature?: number"
check "$NPM_DIR/src/runs/foreground/execution.ts" \
  "execution.ts buildPiArgs 传 temperature" "temperature: agent.temperature"
check "$NPM_DIR/src/runs/background/async-execution.ts" \
  "async-execution.ts 传 temperature（buildSeqStep）" "temperature: a.temperature"
check "$NPM_DIR/src/runs/background/async-execution.ts" \
  "async-execution.ts 传 temperature（recoveryDescriptor）" "temperature: agentConfig.temperature"
check "$NPM_DIR/src/runs/background/async-execution.ts" \
  "async-execution.ts 传 temperature（spawnRunner 6-tab）" "$(printf '\t\t\t\t\t\t')temperature: agentConfig.temperature,"
check "$NPM_DIR/src/runs/background/subagent-runner.ts" \
  "subagent-runner.ts 状态存储传 temperature" "temperature: step.temperature"
check "$NPM_DIR/src/runs/background/subagent-runner.ts" \
  "subagent-runner.ts buildPiArgs 传 temperature" "temperature: step.temperature"

echo ""
echo "--- pi-coding-agent 编译文件（6） ---"
check "$PI_CODING_DIR/dist/cli/args.js" \
  "CLI --temperature 参数解析" "result.temperature"
check "$PI_CODING_DIR/dist/main.js" \
  "main.js 读取 parsed.temperature" "parsed.temperature"
check "$PI_CODING_DIR/dist/main.js" \
  "main.js 会话透传 temperature" "temperature: sessionOptions.temperature"
check "$PI_CODING_DIR/dist/core/agent-session-services.js" \
  "agent-session-services.js 透传 temperature" "temperature: options.temperature"
check "$PI_CODING_DIR/dist/core/sdk.js" \
  "sdk.js 读取 PI_SUBAGENT_TEMPERATURE env" "PI_SUBAGENT_TEMPERATURE"
check "$PI_CODING_DIR/dist/core/sdk.js" \
  "sdk.js YAML 兜底（断链免疫）" "PI_SUBAGENT_CHILD_AGENT"

echo ""
echo "--- pi-agent-core 编译文件（2） ---"
check "$AGENT_CORE_DIR/dist/agent.js" \
  "Agent 构造函数接受 temperature" "this.temperature"
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

### Step 3：修复模式（如验证发现缺失）

> ⚠️ **v2.6.0 起强烈建议直接用 `~/.pi/patches/temperature/reapply.sh --apply`**：它按 pi-coding-agent 版本路由、适配任意 pi-subagents 版本（含 v0.38+/v0.39/v0.40 的 11 处结构漂移），并带 heal + 完整性断言。以下手动 sed 脚本锚点基于 ≤v0.37 时代结构（如 `thinking: a.thinking,`），对 v0.38+ 不适用，仅保留作历史参考。

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
if ! grep -q 'Pick.*"temperature"' "$FILE"; then
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
if ! grep -q "this.temperature" < <(grep -v "createLoopConfig" "$FILE"); then
  sed -i '/this.toolExecution =/a\\tthis.temperature = runtimeOptions.temperature;' "$FILE"
  sed -i '/reasoning: this.reasoning,/a\\ttemperature: this.temperature,' "$FILE"
  echo "✅ agent.js: Agent 类接受 + 传递 temperature"
fi
```

---

### Step 4：修复后验证

重新运行 Step 2 的验证脚本，确认所有 `❌` 变为 `✅`。

⚠️ **静态检查通过 ≠ 运行时生效**：pi 主进程启动时通过 tsx 加载 pi-subagents TS 源码并缓存模块，运行中修改 src 文件不会热生效。必须重启 pi 主进程后，用真实子代理验证：让一个带 `temperature` 的 agent（如 explore=0.1）在 bash 中执行 `echo $PI_SUBAGENT_TEMPERATURE`，应输出 `0.1`。

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
echo -n "Agent accept temp:   "; grep -q "this.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅" || echo "❌"
echo -n "Agent createLoop:    "; grep -q "temperature: this.temperature" "$AGENT_CORE_DIR/dist/agent.js" && echo "✅" || echo "❌"
```

---

## ✅ 当前状态（2026-08-24）

温度链已全部修复并验证通过 ✅ （**21 检查点全绿，其中 spawnRunner 1 项按 v0.55+ 新架构标记 N/A**；pi-coding-agent **v0.84.3**（bundle 架构），pi-subagents **v0.56.0**）。

**2026-08-24 v0.84.3 bundle 架构适配（reapply.sh v2.18.0，第 16 次删除 + 架构变更）**：pi-coding-agent 升至 v0.84.3 改用 **esbuild bundle 架构**——bin 入口 `dist/bundle/cli.js` 只 re-export `dist/bundle/chunks/*.js`（7.2MB 全内联），**散装 `dist/*.js`（sdk.js/main.js/args.js/agent-session-services.js）运行时根本不加载**。v2.17.0 的 dist 层 8 检查点全部假阳性（补丁打在无人加载的文件上，reapply.sh 报 21/21 全绿但运行时温度链 0 处存在——实测 TEMP_DEBUG 永不触发才暴露）。适配：① 新增 bundle 检测（bin 入口存在 + 引用 chunk-E5KXRMZK → bundle 模式）② 7 个注入点全在 chunk-E5KXRMZK.js（CLI `--temperature` 解析 / buildSessionOptions / main→services / services 透传 / createAgentSession env+YAML 兜底 / Agent 构造 this.temperature / createLoopConfig）③ 踩坑：`let temperature=...` 插进 let 声明链中间导致 SyntaxError——必须插在 `extensionRunnerRef={};` 分号后独立语句位置 ④ 运行时三场景实测：无 env → YAML 兜底 explore.md=**0.1** ✅，env 0.7 → **0.7** ✅，CLI 0.3 → **0.3** ✅（CLI > env > YAML）。

**2026-08-24 v0.55.0 适配（reapply.sh v2.17.0，第 15 次删除 + 架构变更）**：pi-subagents 升至 v0.55.0 再次删除全部 13 个 src 检查点，且 **spawnRunner 重构**——不再内联构建 steps（旧 6-tab 插入点消失），只序列化 cfg JSON 后 spawn runner 子进程。新数据流：buildSeqStep `temperature: a.temperature` 入 cfg → subagent-runner 三处 `step.temperature`（1553 buildPiArgs / 2399 状态存储 / 3501 revival 路径）出 env。适配：① 6-tab 检查点版本条件化（≥0.55 标 N/A）② agents.ts Pick 列表新增 modelProvider 致旧长锚点失配 → 改短锚点 ③ subagent-runner store 断言放宽 ≥1 ④ 手工补 Pick 缺失的 `"temperature"`。--apply 重打后全绿，无漂移警告、幂等复验通过。

---

### 历史状态（2026-08-14，v2.15.0）

**2026-08-14 v0.49.0/v0.84.2 适配（v2.15.0，第 13 次删除）**：pi-subagents 升至 v0.49.0，再次删除全部 13 个 src 检查点（npm pack 原始 tarball 验证：pi-args.ts/agents.ts 中 temperature 0 引用）。CHANGELOG 显示 v0.49.0 新增单 child 运行（#1059）/debug.run（#1037）/tools: inherit（#1047）/终端示例等（均为功能新增，未触碰 temperature 结构）——src 层已由 postinstall 自动重打 13/13 ✅。**dist 层特殊状况**：本次 `pi update`（0.84.1→0.84.2）使用 `--ignore-scripts`（npm 参数），**postinstall 钩子不触发** → pi-coding-agent 的 8 个 dist 检查点被新版本覆盖为原生无温度且无人自动重打，reapply.sh 检测报 8 缺失。手动 `--apply` 一次重打 21/21 成功（无漂移警告），运行时断链模拟三场景全部验证通过：① 无 env → YAML 兜底读 explore.md = **0.1** ✅ ② `PI_SUBAGENT_TEMPERATURE=0.7` → **0.7** 优先于 YAML ✅。优先级链：CLI > env > YAML 兜底。reapply.sh 版本声明已更新（v2.15.0 / `pi-subagents <= v0.49.x`）。

**2026-08-13 v0.48.0/v0.84.1 适配（v2.14.0，第 12 次删除）**：pi-subagents 经 `pi update --extensions` 升至 v0.48.0，再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。CHANGELOG 显示 v0.48.0 新增 per-run 子代理 fan-out budget 上限（#1031）、活跃异步会话并发 cap（#1029）、Fleet Prompt Audit 抽屉（#1021）、全局 timeoutMs 配置（#1018）、`PI_SUBAGENT_TASK_DELIVERY` env（#1028）、LLM intent arbiter（#1020）等（均为功能新增/修复，未触碰 temperature 结构）——**v2.13.0 锚点全部命中**，postinstall `--apply` 自动重打 21/21 成功，幂等复跑 ✅，无 ⚠️ 漂移警告。同时修复 reapply.sh 标题计数错误（`source files (12)` → `(13)`，实为 13 个检查点）。reapply.sh 版本声明已更新（v2.14.0 / `pi-subagents <= v0.48.x`）。

**2026-08-12 v0.47.0/v0.84.1 适配（v2.13.0，第 11 次删除）**：pi-subagents 经 `pi update --extensions` 升至 v0.47.0，再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。CHANGELOG 显示 v0.47.0 新增模型 scope 强制（#995）、legacy chain 字段裁剪（#977）、存储迁移 `.pi-subagents/` → `.pi/subagents/`（#971）等（均为功能新增/优化，未触碰 temperature 结构）——**v2.12.0 锚点全部命中**，postinstall `--apply` 一次重打 21/21 成功，幂等复跑 ✅，无 ⚠️ 漂移警告。reapply.sh 版本声明已更新（v2.13.0 / `pi-subagents <= v0.47.x`）。

**2026-08-11 v0.46.0/v0.84.1 适配（v2.12.0，第 10 次删除）**：pi-subagents 经 `pi update --extensions` 升至 v0.46.0，再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。CHANGELOG 显示 v0.46.0 新增 prompts.render（#960）、project-panes TS API（#949）、guide 子命令、mission 决策解析等（均为功能新增，未触碰 temperature 结构）——**v2.11.0 锚点全部命中**，`--apply` 一次重打 21/21 成功，幂等复跑 ✅，无 ⚠️ 漂移警告。插入点人工核验：buildSeqStep 3-tab `temperature: a.temperature,`（759 行，thinking 与 launchResolvedExtensions 之间）、recoveryDescriptor 2-tab spread（1384 行）、spawnRunner 6-tab（1438 行，thinking 与 modelCandidates 之间）、agents.ts frontmatter spread（1629 行）/cloneOverrideBase（574 行）、serializer 第 15/75 行、pi-args 737 行、subagent-runner 1336/2092 行全部正确。运行时断链模拟三场景全部验证通过：① 无 env → YAML 兜底读 explore.md = **0.1** ✅ ② `PI_SUBAGENT_TEMPERATURE=0.7` → **0.7** 优先于 YAML ✅ ③ CLI `--temperature 0.3` → **0.3** 最高优先 ✅。优先级链：CLI > env > YAML 兜底。reapply.sh 版本声明已更新（v2.12.0 / `pi-subagents <= v0.46.x`）。

**2026-08-10 v0.45.2/v0.84.1 适配（v2.11.0，第 9 次删除）**：pi-subagents 经 `pi update --extensions` 升至 v0.45.2，再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。v0.45.1/0.45.2 重构了 async-execution.ts 的 thinking 计算（引入 `effectiveThinking` / `thinkingOverridesByFlatIndex` / `applyThinkingSuffix` 新机制，buildSeqStep 与 spawnRunner 的 thinking 行改为 `thinking: resolveEffectiveThinking(model, effectiveThinking),`），但 **v2.10.0 的锚点全部命中**——`resolveEffectiveThinking` 3-tab 裸行、spawnRunner 6-tab 裸行、recoveryDescriptor 2-tab spread 均无漂移，`--apply` 一次重打 21/21 成功，幂等复跑 ✅，无 ⚠️ 漂移警告。插入点核验：buildSeqStep 3-tab `temperature: a.temperature,`（thinking 与 launchResolvedExtensions 之间）、recoveryDescriptor spread `...(agentConfig.temperature !== undefined ? { temperature: agentConfig.temperature } : {}),`、spawnRunner 6-tab `temperature: agentConfig.temperature,`（thinking 与 modelCandidates 之间）全部正确。reapply.sh 版本声明已更新（v2.11.0 / `pi-subagents <= v0.45.x`）。

**2026-08-09 v0.45.0/v0.84.1 适配（v2.10.0，第 8 次删除）**：pi-subagents v0.45.0 再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。CHANGELOG 显示 v0.44.0（自动 mission/durable workflow state/schedule storeRoot）与 v0.45.0（subagent_wait completions 结构化载荷、PowerShell 前缀、reads 路径展开等）均未触碰 temperature 结构——**锚点与 v0.43.0 完全一致，reapply.sh 既有模式一次重打 21/21 成功**，幂等复跑 ✅，无 ⚠️ 漂移警告、无完整性断言失败。插入点人工核验：buildSeqStep 3-tab（`a.temperature`，在 thinking 与 launchResolvedExtensions 之间）、recoveryDescriptor 2-tab spread（`...(agentConfig.temperature !== undefined ? ...)`）、spawnRunner 6-tab（`agentConfig.temperature,`，在 thinking 与 modelCandidates 之间）、agents.ts frontmatter/cloneOverrideBase spread、Pick 列表、override 函数体、subagent-runner 两处（1336 buildPiArgs / 2092 状态存储）全部正确。运行时断链模拟三场景全部验证通过（临时 [TEMP] 日志，测后移除）：① 无 env → YAML 兜底读 explore.md = **0.1** ✅ ② `PI_SUBAGENT_TEMPERATURE=0.7` → **0.7** 优先于 YAML ✅ ③ CLI `--temperature 0.3` → **0.3** 最高优先 ✅。优先级链：CLI > env > YAML 兜底。reapply.sh 版本声明已更新（v2.10.0 / `pi-subagents <= v0.45.x`）。

**2026-08-08 v0.43.0/v0.84.1 适配（v2.9.0，第 7 次删除）**：pi-subagents v0.43.0 再次删除 temperature 支持（13 个 pi-subagents 检查点全缺，dist 层 8 个完好）。CHANGELOG 显示 v0.43.0 新增 refinement overlays、goal missions、steer 模式、gate 验证、mission state 等（均为功能新增，未触碰 agents.ts/serializer/pi-args 等 temperature 结构）——**锚点与 v0.42.1 完全一致，reapply.sh 既有模式一次重打 21/21 成功**，幂等复跑 ✅。运行时断链模拟三场景全部验证通过（临时 TEMP 日志，测后移除）：① 无 env → YAML 兜底读 explore.md = **0.1** ✅ ② `PI_SUBAGENT_TEMPERATURE=0.7` → **0.7** 优先于 YAML ✅ ③ CLI `--temperature 0.3` → **0.3** 最高优先 ✅。优先级链：CLI > env > YAML 兜底。reapply.sh 版本声明已更新（v2.9.0 / `pi-subagents <= v0.43.x`）。

**2026-08-07 v0.42.1/v0.84.1 适配（v2.8.0，第 6 次删除）**：pi-subagents v0.42.1 再次删除 temperature 支持（21 检查点全缺），但 v0.41.0 时代的全部锚点（spread 语法 frontmatter 解析、cloneOverrideBase、buildSeqStep/spawnRunner/recoveryDescriptor、dist 文件结构）**未漂移**——reapply.sh 既有模式直接命中，21/21 一次重打成功。

**发现并修复 CRITICAL bug（v2.8.0）**：sdk.js 的 readFileSync import 检查 `if 'readFileSync' not in content:` 在插入 replace **之后**执行——而插入块本身含 `readFileSync(` 使用，子串检查恒为 False → `import { readFileSync } from "node:fs"` 永不添加 → YAML 兜底路径运行时抛 `ReferenceError: readFileSync is not defined`。修复：改为精确匹配 import 行 `if 'import { readFileSync } from "node:fs";' not in content:`（4a/4b 两处）。同时消除 Python SyntaxWarning（bash 双引号 `\s` 需 4 反斜杠、`\g<0>` 需双反斜杠）。

**回归测试（v2.8.0）**：从 GitHub tag v0.42.1 + npm pack 还原全部原始文件 → 修复后脚本 `--apply` → 21/21 ✅ + readFileSync import 正确添加 + 无 SyntaxWarning + 幂等复跑 ✅。运行时验证（断链模拟 + 临时 TEMP_DEBUG 日志，测后移除）：① 无 env → YAML 兜底读 explore.md = **0.1** ✅ ② `PI_SUBAGENT_TEMPERATURE=0.7` → **0.7** 优先于 YAML ✅ ③ `--temperature 0.3` → **0.3** 最高优先 ✅ ④ 无 ReferenceError ✅。优先级链：CLI > env > YAML 兜底。

**2026-08-06 v0.41.0/v0.84.0 适配（v2.7.0，第 5 次删除）**：pi-subagents v0.41.0 再次删除 temperature 支持（21 检查点全缺），且 `agents.ts` 全面重构为 spread 语法（`...(x !== undefined ? { x } : {})`），旧锚点 `thinking: frontmatter.thinking === "false" ? false : frontmatter.thinking,` 与 `thinking: agent.thinking,` 不再存在：
- **frontmatter 解析漂移**：新锚点 `...(frontmatter.thinking !== undefined ? { thinking: ... } : {}),` → 在其后插入 `...(frontmatter.temperature !== undefined ? { temperature: Number(frontmatter.temperature) } : {}),`
- **cloneOverrideBase 漂移**：新锚点 `...(agent.thinking !== undefined ? { thinking: agent.thinking } : {}),` → 插入 `...(agent.temperature !== undefined ? { temperature: agent.temperature } : {}),`
- **buildBuiltinOverrideConfig**：Pick 列表补 `"temperature"`（`"thinking" | "systemPromptMode"` 之间）+ 函数体补 `if (draft.temperature !== base.temperature) override.temperature = draft.temperature ?? false;`
- **发现并修复假阳性 bug（CRITICAL）**：reapply.sh 的 frontmatter/cloneOverrideBase 补丁在 `str.replace` 无匹配时仍置 `patched=True` 并报告 ✅——v0.41.0 锚点漂移后 `--apply` 静默失败但输出成功。v2.7.0 改为：先试 spread 锚点，无变更再回退旧式锚点，仍无变更打印 ⚠️ 警告（不谎报）；Pick/函数体补丁同规则
- **实测验证**：修复后 21/21 ✅，幂等复跑 21/21 ✅。其余 19 检查点（dist 文件 + serializer + pi-args/execution/async/subagent-runner）v0.84.0/v0.41.0 锚点未变，reapply.sh 原有模式直接命中

**2026-08-05 复验（`pi update --extensions` 后）**：pi-subagents 仍为 v0.40.0 未变动，reapply.sh 21/21 全部通过 ✅。扩展 npm 树新增 overrides（`brace-expansion ^5.0.9` / `undici ^8.9.0`）清零 2 高危漏洞后 `npm install` 触发 postinstall，自动重打输出 `[patch] Temperature chain OK` ✅。

**2026-08-05 教训（更新挂起 56m45s）**：`pi update --extensions` 的 git fetch 在 `package-manager.js` 中**无超时**（`runCommand("git", fetchArgs, ...)` 未传 timeoutMs），代理节点抽风时连接停滞即无限挂起（实测 56m45s，FETCH_HEAD 均在结束时才写入）。已设全局 git 停滞超时防复发：`git config --global http.lowSpeedLimit 1000` + `http.lowSpeedTime 30` + `http.connectTimeout 15`（停滞 30s 即中止）。修后实测 `pi update --extensions` 9s 完成。此挂起不影响补丁链，但会推迟 postinstall 重打。

**2026-08-12 扩展树漏洞清理（连带教训）**：`pi update --extensions` 升至 pi-subagents 0.47.0 后 audit 报 1 高危：① `pdfjs-dist@5.7.284`（GHSA-hq66-cqwq-w95j 恶意 PDF 任意 JS 执行，直接依赖，unpdf 解析 PDF 用）→ bump `^6.2.108` 修复；② `@mariozechner/pi-coding-agent@0.73.1` peer 占位（旧 scope 已停更，GHSA-jfgx-wxx8-mp94 可预测临时路径本地提权等 3 advisory 无修复版）→ `npm install --legacy-peer-deps` 重装后占位被清除，audit 归零（运行时本就被 loader.js aliases 到 bundled 0.84.1，漏洞不可达）。**⚠️ 踩坑：npm `overrides` 写 `npm:` alias（如 `"@mariozechner/pi-coding-agent": "npm:@earendil-works/pi-coding-agent@0.84.1"`）会触发 arborist reify bug——`ERR_INVALID_ARG_TYPE: The "from" argument must be of type string. Received undefined`（path.relative 收到 undefined），install 直接崩。这不是兼容性问题，是 npm 10.9.x 对 peer + alias override 组合的内部 bug。正确做法：不用 alias override，直接用 `--legacy-peer-deps` 重装清掉 peer 占位**（与 pi 官方 package-manager.js 第 1486 行一致，也是 2026-08-05 扩展树清理的同一机制）。

**2026-08-05 扩展树清理**：`--legacy-peer-deps` 下 `npm install` 会清除 `@earendil-works/pi-*` 过期 peer 自动安装（设计预期，运行时走 loader aliases，见 package-manager.js 注释）；若某次更新后扩展报错，先检查 `~/.pi/agent/npm/node_modules/@earendil-works/` 是否被清空而非怀疑温度补丁。断链模拟实测：手动 spawn 子进程（env 无 PI_SUBAGENT_TEMPERATURE）→ sdk.js 从 explore.md 直读 temperature=0.1 → 注入 Agent ✅。今后 pi-subagents 再次删除 temperature 支持，不再需要适配——兜底自动接管，传递链补丁只是锦上添花。

**v0.40.0 适配（v2.6.0）**：0.40.0 第 4 次从 pi-subagents 源码删除全部 temperature 支持（与 0.38/0.39 同模式，12 检查点全缺）。reapply.sh 已适配 + 加固：
- **发现并修复 str.replace 子串误伤 bug（CRITICAL）**：buildSeqStep 补丁用 `str.replace` 插入 3-tab `temperature: a.temperature,` 时，因 Python 子串语义，**6-tab 的 spawnRunner 行包含 3-tab 模式作为子串**（最后 3 个 tab + `thinking:`），被同时匹配劈开——在 spawnRunner 里插入了一个作用域不存在的 `a`（运行时 ReferenceError）。且污染后 spawnRunner 的 6-tab anchor 断裂 → 补丁静默跳过 + 报告误报 "ok"
- **修复 guard 缺陷**：spawnRunner 检查原用 `c.split('spawnRunner', 1)[1]`——第一个 `spawnRunner` 是函数声明（在 recoveryDescriptor 之前），同轮 recovery 补丁一打，guard 就误判已补丁 → spawnRunner 永远跳过。改为 `^\t{6}temperature: agentConfig\.temperature,$` 正则直接检测
- **三处加固**：① buildSeqStep 改用 `(?m)^...$` 锚定正则（3-tab 不再匹配 6-tab 行）② 新增 heal 逻辑（检测污染形态 `6-tab thinking + 3-tab a.temperature + modelCandidates` 自动修复）③ 完整性断言（a_count/ac_count 必须各为 1，失败大声报错）
- **新增第 21 检查点**：`async spawnRunner (6-tab)` 专用检测（PCRE `^\t{6}temperature: agentConfig\.temperature,$`）——旧 checkpoint #18 的 `temperature: agentConfig.temperature` 会被 recoveryDescriptor 匹配掩盖，无法发现 spawnRunner 缺失
- **实测验证**：故障演练三连——还原原始态跑 --apply 全 21 ✅ → 模拟污染跑 --apply 自动 heal 全 21 ✅ → 幂等复跑全 21 ✅

**v0.39.0 适配**：0.39.0 再次从 pi-subagents 源码中删除全部 temperature 支持（与 0.38.0 相同模式，11 处缺失）。reapply.sh 已适配：
- **buildSeqStep anchor 修复**：0.39.0 在 `thinking:` 与 `modelCandidates:` 之间插入了 `launchResolvedExtensions,`，旧的「thinking + modelCandidates 两行锚定」失配导致补丁静默失败（且被其他子补丁置位 `patched=True` 误报 ✅）。改为只锚定 3-tab 裸 `thinking: resolveEffectiveThinking(...)` 行——该写法在 buildSeqStep 唯一（spread 是 2-tab `{ thinking: ... } : {}`，spawnRunner 是 6-tab）
- **分项补丁报告**：async-execution.ts 的 buildSeqStep / recoveryDescriptor / spawnRunner 三个子补丁分别跟踪 `seq_patched / recovery_patched / spawn_patched`，各自独立报告 patched/ok，锚点找不到时输出 ⚠️ 警告而非静默
- **端到端验证教训**：静态检查全过 ≠ 运行时生效（彼时 18 检查点）。pi 主进程（tsx 模块缓存）在补丁前启动时仍执行旧代码，实测子代理 env 中无 `PI_SUBAGENT_TEMPERATURE`。修复后必须重启 pi 主进程，并用真实子代理 echo 验证

**v0.38.0 适配**：0.38.0 再次从 pi-subagents 源码中删除了全部 temperature 支持（`agent-serializer.ts`/`agents.ts`/`pi-args.ts`/`parallel-utils.ts`/`execution.ts`/`async-execution.ts`/`subagent-runner.ts` 共 11 处）。reapply.sh 已适配：
- `agents.ts` 补丁新增 **AgentConfig 接口**补丁（此前只补 BuiltinAgentOverrideBase/Config）
- `async-execution.ts` 补丁新增 **spawnRunner steps** 路径（单跑异步路径，缩进 6-tab，`temperature: agentConfig.temperature`）——注意 buildSeqStep 的 replace 必须带 3-tab + `buildModelCandidates` 后缀精确匹配，否则全局 replace 会误伤 spawnRunner 处插入不存在的 `a` 变量导致 ReferenceError
- `subagent-runner.ts` 补丁新增 **status store** 补丁（`thinking: step.thinking,` 后插入）——0.38.0 不再原生包含 status store 序列化
- 修复 shell bug：`[ $(grep -cF ... || echo 0) -ge 2 ]` 无匹配时会变 `[ 0 0 -ge 2 ]` 报 too many arguments，改用 `runner_count=$(... || true)` + 变量比较

**v0.83.0 适配**：`reapply.sh` 的 `agent-session-services.js` 和 `agent.js createLoopConfig` 补丁模式已改进为 regex fallback，兼容 v0.82.x 和 v0.83.x 代码结构。

**持久化机制已就绪**：`~/.pi/patches/temperature/reapply.sh` 现覆盖全部三层，postinstall 钩子自动重打，无需手动干预。

## 🔄 v0.82.0+ 重大变更

**pi-coding-agent v0.82.0+ 移除了整个 temperature 传递链**：
- `cli/args.js` — 无 `--temperature` 参数
- `main.js` / `sdk.js` / `agent-session-services.js` — 无 temperature 字段
- `pi-agent-core/agent.js` — 无 `this.temperature`，`createLoopConfig()` 不包含 temperature
- Pi-ai provider 层（`simple-options.js` → `buildBaseOptions`）**仍原生支持** `options.temperature`
- pi-subagents（`pi-args.ts`）**仍设置** `PI_SUBAGENT_TEMPERATURE` 环境变量

**断点在 pi-coding-agent 中间层**，需在 5 个 dist 文件中重建传递链。

### 新数据流（v0.82.1 修复后）

```
Agent YAML → buildPiArgs → PI_SUBAGENT_TEMPERATURE
             ↘ 或 CLI: --temperature <value>
  → sdk.js (resolve CLI > env > undefined)
    → Agent({temperature})
      → agent.js: this.temperature
        → createLoopConfig() → { temperature }
          → streamFn → ...options
            → buildBaseOptions → temperature: options?.temperature
              → provider API (anthropic/openai/gemini)
```

### 检查点清单（21 个，reapply.sh 覆盖全部）

| # | 文件 | 检查模式 |
|---|------|----------|
| 1 | `pi-coding-agent/dist/cli/args.js` | `result.temperature` |
| 2 | `pi-coding-agent/dist/main.js` | `options.temperature` |
| 3 | `pi-coding-agent/dist/main.js` | `temperature: sessionOptions.temperature` |
| 4 | `pi-coding-agent/dist/core/agent-session-services.js` | `temperature: options.temperature` |
| 5 | `pi-coding-agent/dist/core/sdk.js` | `PI_SUBAGENT_TEMPERATURE` or `temperature =` (env/opt) |
| 6 | `pi-coding-agent/dist/core/sdk.js` | `PI_SUBAGENT_CHILD_AGENT` (YAML fallback) |
| 7 | `pi-agent-core/dist/agent.js` | `this.temperature` |
| 8 | `pi-agent-core/dist/agent.js` | `temperature: this.temperature` |
| 9 | `pi-subagents/src/agents/agent-serializer.ts` | `"temperature"` (KNOWN_FIELDS) |
| 10 | `pi-subagents/src/agents/agent-serializer.ts` | `config.temperature` (serializer output) |
| 11 | `pi-subagents/src/agents/agents.ts` | `temperature?: number` (接口) |
| 12 | `pi-subagents/src/agents/agents.ts` | `Number(frontmatter.temperature)` (解析) |
| 13 | `pi-subagents/src/runs/shared/pi-args.ts` | `temperature?: number` (接口) |
| 14 | `pi-subagents/src/runs/shared/pi-args.ts` | `PI_SUBAGENT_TEMPERATURE` (env var) |
| 15 | `pi-subagents/src/runs/shared/parallel-utils.ts` | `temperature?: number` (接口) |
| 16 | `pi-subagents/src/runs/foreground/execution.ts` | `temperature: agent.temperature` |
| 17 | `pi-subagents/src/runs/background/async-execution.ts` | `temperature: a.temperature` (buildSeqStep) |
| 18 | `pi-subagents/src/runs/background/async-execution.ts` | `temperature: agentConfig.temperature` (recoveryDescriptor) |
| 19 | `pi-subagents/src/runs/background/async-execution.ts` | 6-tab `temperature: agentConfig.temperature,` (spawnRunner) |
| 20 | `pi-subagents/src/runs/background/subagent-runner.ts` | `temperature: step.temperature`（状态存储）|
| 21 | `pi-subagents/src/runs/background/subagent-runner.ts` | `temperature: step.temperature,`（buildPiArgs 调用）|

> **主要执行路径**：优先使用 `~/.pi/patches/temperature/reapply.sh` 进行一键检测/修复，以下 Step 2/3/4 的手动脚本仅在 reapply.sh 不可用或版本不兼容时作为备选。

## 🤖 自动重打（持久化）

修复已集成到 `~/.pi/patches/temperature/reapply.sh`，通过 `~/.pi/patches/reapply.sh` → pi-agent postinstall 钩子自动触发。

**覆盖范围**（21 检查点，1 个脚本）：
- pi-coding-agent `dist/` 文件：6 检查点（`cli/args.js`, `main.js`×2, `agent-session-services.js`, `sdk.js`×2 含 YAML 兜底）
- pi-agent-core `dist/` 文件：2 检查点（`agent.js`×2）
- pi-subagents `src/` 文件：13 检查点（`agent-serializer.ts`, `agents.ts`×2, `pi-args.ts`×2, `parallel-utils.ts`, `execution.ts`, `async-execution.ts`×3 含 spawnRunner 6-tab, `subagent-runner.ts`×2）

**自动触发链路**：
```
npm update / pi update
  → pi-agent postinstall hook
    → ~/.pi/patches/reapply.sh
      → ~/.pi/patches/temperature/reapply.sh --apply
        → 检测全部 21 点 → 缺则自动修复（含 spawnRunner 污染 heal）→ 二次验证
```

**手动重打**：
```bash
~/.pi/patches/temperature/reapply.sh          # 纯检测
~/.pi/patches/temperature/reapply.sh --apply  # 检测 + 自动修复
```

**幂等性**：所有补丁操作均为幂等——已修复项自动跳过，多次运行安全。

**版本兼容**：脚本对 0.82.x 自动修复，对 0.83+ 尝试修复并报告，对未知版本输出诊断。**v0.49.0/v0.84.2 已实测（v2.15.0）**；v0.48.0/v0.84.1 已实测（v2.14.0）；v0.47.0/v0.84.1 已实测（v2.13.0）；v0.46.0/v0.84.1 已实测（v2.12.0）；v0.45.2/v0.84.1 已实测（v2.11.0）；v0.45.0/v0.84.1 已实测（v2.10.0）；v0.43.0/v0.84.1 已实测（v2.9.0）；v0.42.1/v0.84.1 已实测（v2.8.0）。

## ⚠️ 注意事项

1. **npm update 会自动修复**：postinstall 钩子触发 `~/.pi/patches/reapply.sh` → `temperature/reapply.sh --apply` 自动重打全部补丁。仅在自动重打失败时才需手动执行本 skill。
   - ⚠️ **例外（2026-08-14 实测）**：`pi update` 自身用 `npm install -g --ignore-scripts`（跳过 postinstall）——升级 pi-coding-agent 后 dist 层 8 个检查点被覆盖但**不会自动重打**。此时需手动 `~/.pi/patches/temperature/reapply.sh --apply`。而 `pi update --extensions`（git+npm install，postinstall 正常触发）会自动重打 src 层。升级后建议直接跑一次 `reapply.sh` 确认 21/21。
2. **Anthropic 特例**：启用 thinking 时跳 temperature（API 限制），`compat.supportsTemperature=false` 的模型也不接受自定义温度。这是 provider 层行为，非本修复引入。
3. **默认值行为**：`temperature` 未设置（`undefined`）时，provider 使用 API 默认温度，与修复前一致。
4. **版本要求**：`pi-subagents >= 0.36.0`，`pi-coding-agent >= 0.82.1`。
5. **Git 安全网不适用**：修改的是 `~/.pi/agent/npm/` 和 `~/.npm-global/` 下的 `node_modules` 文件。补丁脚本在 `~/.pi/patches/temperature/` 下。
6. **v0.84.3+ bundle 架构（2026-08-24）**：pi-coding-agent 运行时只加载 `dist/bundle/chunks/chunk-E5KXRMZK.js`（esbuild 全内联），散装 `dist/*.js` 不被加载——reapply.sh 已自动检测 bundle 模式并打 7 个 bundle 注入点（含 YAML 兜底）。注意 bundle 是压缩单行 JS，手工改必须跑 `node --check` 验证语法；`let temperature` 声明必须插在独立语句位置（`extensionRunnerRef={};` 之后），插入 let 声明链中间会 SyntaxError。
7. **版本升级**：若 pi-coding-agent 升级到 0.83+ 且 auto-apply 失败，用 pi agent 运行本 skill 进行适配。
8. **补丁生效需重启 pi 主进程**：pi 主进程启动时通过 tsx 加载 pi-subagents TS 源码并缓存模块，运行中修改 `src/` 文件不会热生效。静态检查通过但运行中的主进程仍执行旧代码（2026-08-02 实测两次：补丁前启动的主进程不传 env；禁用补丁后主进程仍继续传 env——缓存是双向的）。补丁后必须重启 pi（退出当前会话/重启服务），并用真实子代理 `echo $PI_SUBAGENT_TEMPERATURE` 验证（explore=0.1 应输出 0.1）。
9. **断链模拟测试法**（验证兜底，无需重启）：手动 spawn 子进程并故意不设 `PI_SUBAGENT_TEMPERATURE`——`env -i HOME=$HOME PATH=$PATH PI_SUBAGENT_CHILD_AGENT=explore pi --mode json -p "task"`，观察子进程日志中温度解析结果（临时在 sdk.js 加 `console.error('[TEMP] ' + temperature)` 可见）。子进程每次全新加载最新代码，不受主进程缓存影响。bundle 架构下改在 chunk-E5KXRMZK.js 的温度解析处加临时日志（sdk.js 散装文件不被加载）。
