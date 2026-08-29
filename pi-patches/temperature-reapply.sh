#!/bin/bash
# Reapply pi-agent temperature chain patches (version-aware)
# Last updated: 2026-08-29 — v2.20.0: pi-subagents 0.59.0 (18th removal) / pi-coding-agent 0.84.4 + CRITICAL fix:
#   esbuild 入口 chunk 名**不得硬编码**。v2.18.0/2.19.0 把检测写成 grep 'chunk-E5KXRMZK'，
#   而 0.84.4 构建产物改名为 chunk-OMWWHBTG.js → 检测退化成 bundle=0 → 去查运行时根本不
#   加载的散装 dist/*.js（v2.18.0 刚修过的假阳性陷阱复发），报「20 缺失」但补丁落点错误。
#   v2.20.0 改为从 bin 入口 dist/bundle/cli.js 解析 import 的 chunk 列表，取体积最大且含
#   createAgentSessionFromServices 结构标记者为入口 chunk；apply_bundle 经 PI_BUNDLE_CHUNK
#   环境变量取路径，路径未解析时拒绝打补丁。实测 0.84.4 七个 bundle 锚点全部存活（零改写）。
#   运行时断链模拟四场景通过：YAML 兜底 explore.md=0.1 / env 0.7 优先 / CLI 0.3 最高 / 全未设=undefined。
#
# v2.19.0: pi-subagents 0.57.0 (17th removal) + CRITICAL fix:
#   apply_pi_subagents 调用曾被孤立在 apply_082x() 尾部——bundle 模式（pi-coding-agent >= 0.84.3）
#   永远不会走到它，src 层补丁在每次 pi-subagents 更新后无人重打。v0.57.0 更新暴露此 bug。
#   v2.19.0 将调用移入 apply_bundle() 尾部，两条路径均重打 src 层。锚点 v0.57.0 全部存活无需适配。(17th removal)
#
# v2.17.0 (pi-subagents 0.55.0 / pi-coding-agent 0.84.2): 15th upstream removal + ARCH CHANGE.
#   v0.55.0 重构 spawnRunner：不再内联构建 steps，只序列化 cfg JSON 后 spawn runner 子进程。
#   旧 6-tab 检查点（#19）架构性过时 → 版本条件化：>=0.55 时改验 cfg 序列化链
#   （buildSeqStep `temperature: a.temperature` 入 cfg → subagent-runner `step.temperature` 出）。
#   agents.ts Pick 列表新增 modelProvider 致旧长锚点失配 → 改短锚点 "thinking" | "systemPromptMode"。
#   subagent-runner 状态存储断言放宽为 >=1（v0.55 有 revival/恢复路径的合法第二处 4-tab 行）。
#
# Architecture: PI_SUBAGENT_TEMPERATURE env → cli/args.js → main.js →
#   agent-session-services.js → sdk.js → agent.js → createLoopConfig() →
#   streamFn → buildBaseOptions → provider API
#
# v2.16.0 (pi-subagents 0.50.0 / pi-coding-agent 0.84.2): 14th upstream removal.
#   v0.50.0 added Orca progress tabs / FleetView external jobs / foregroundDetachShortcut 等
#   （未触碰 temperature 结构），但再次删除全部 13 个 pi-subagents 检查点。
#   锚点与 v0.49.0 完全一致，--apply 一次重打 21/21 成功（无漂移警告）。
#
# v2.15.0 (pi-subagents 0.49.0 / pi-coding-agent 0.84.2): 13th upstream removal.
#   v0.49.0 added single-child run/debug.run/tools inherit/terminal examples 等
#   （未触碰 temperature 结构），但再次删除全部 13 个 pi-subagents 检查点
#   （npm pack 原始 tarball 验证：pi-args.ts/agents.ts 0 引用 temperature）。
#   src 层由 postinstall 自动重打 13/13；dist 层被 pi update 0.84.2
#   （--ignore-scripts，postinstall 不触发）覆盖为原生无温度 → 8 检查点全缺，
#   手动 --apply 一次重打 21/21 成功；运行时断链模拟三场景全部通过。
# v2.14.0 (pi-subagents 0.48.0 / pi-coding-agent 0.84.1): 12th upstream removal.
#   v0.48.0 added fan-out budget cap/async session cap/Prompt Audit drawer/global
#   timeoutMs/PI_SUBAGENT_TASK_DELIVERY env/LLM intent arbiter（未触碰 temperature 结构），
#   但再次删除全部 13 个 pi-subagents 检查点；v2.13.0 锚点全部命中，21/21 一次重打（无漂移警告）。
#   Also fixed the "source files (12)" heading miscount → (13)（实为 13 个检查点）。
# v2.13.0 (pi-subagents 0.47.0 / pi-coding-agent 0.84.1): 11th upstream removal.
#   v0.47.0 added model-scope enforcement/storage move to .pi/subagents/ etc（未触碰 temperature 结构），
#   但再次删除全部 13 个 pi-subagents 检查点；v2.12.0 锚点全部命中，21/21 一次重打（无漂移警告）。
# v2.12.0 (pi-subagents 0.46.0 / pi-coding-agent 0.84.1): 10th upstream removal.
#   v0.46.0 added prompts.render/project-panes API/guide 等（未触碰 temperature 结构），
#   但再次删除全部 13 个 pi-subagents 检查点；v2.11.0 锚点全部命中，21/21 一次重打，
#   插入点人工核验通过（buildSeqStep 3-tab / recovery spread / spawnRunner 6-tab）。
# v2.11.0 (pi-subagents 0.45.2 / pi-coding-agent 0.84.1): 9th upstream removal.
#   v0.45.1/0.45.2 重构 async-execution.ts thinking 逻辑（effectiveThinking/thinkingOverrides），
#   但 v2.10.0 锚点（resolveEffectiveThinking 3-tab/spawnRunner 6-tab/recovery spread）仍全部命中，21/21 一次重打。
# v2.10.0 (pi-subagents 0.45.0 / pi-coding-agent 0.84.1): 8th upstream removal.
#   v0.44.0 (missions/schedules) + v0.45.0 (subagent_wait completions) changed
#   no temperature structure — all 13 pi-subagents checkpoints missing again,
#   anchors unchanged from v0.43.0 era, 21/21 via existing patterns in one pass.
#
# v2.9.0 (pi-subagents 0.43.0 / pi-coding-agent 0.84.1): 7th upstream removal.
#   v0.43.0 added refinement overlays/missions/steer/gate (no temperature
#   structure changes) — all 13 pi-subagents checkpoints missing again, anchors
#   unchanged from v0.42.1 era, 21/21 via existing patterns in one pass.
#
# v2.8.0 (pi-subagents 0.42.1 / pi-coding-agent 0.84.1): 6th upstream removal.
#   Anchors unchanged from v0.41.0 era (spread syntax still present) — 21/21 via
#   existing patterns. FIXED CRITICAL bug: the sdk.js readFileSync import check
#   used `if 'readFileSync' not in content` AFTER the insertion replace — the
#   inserted block itself contains 'readFileSync(' usage, so the check was always
#   False and the import was NEVER added (ReferenceError at runtime in YAML
#   fallback path). Fixed: check the exact import line
#   `import { readFileSync } from "node:fs";` instead. Also fixed Python
#   SyntaxWarnings (invalid escape sequences \s / \g).
#
# v2.5.0 defense-in-depth: sdk.js ALSO falls back to reading temperature
# directly from ~/.pi/agent/agents/<name>.md frontmatter (using
# PI_SUBAGENT_CHILD_AGENT + getAgentDir). The agent YAML is our authoritative
# source and its path/format never changes with pi-subagents versions, so the
# chain keeps working even if upstream drops the env passthrough again.
#
# v2.6.0 (pi-subagents 0.40.0): 11 anchor fixes + HEAL for the v0.40.0
# str.replace corruption bug — the 3-tab buildSeqStep pattern matched INSIDE
# the 6-tab spawnRunner line (substring semantics), inserting a 3-tab
# `temperature: a.temperature,` with an out-of-scope `a` (ReferenceError).
# Fix: anchored ^...$ regex + heal-corrupt block + integrity assertions.
#
# Update policy: when pi-coding-agent is updated to a new major/minor version,
# run: pi and ask "apply temperature fix from ~/prompt_boilerplates/System_Fix/subagent-temperature-fix.md"
# Then update the PATTERNS_VERSION_082x section below with the new fix patterns.

set -e

# ─── Paths ──────────────────────────────────────────────────────────────────
PICA="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent"
AGENT_CORE="$PICA/node_modules/@earendil-works/pi-agent-core"
CLI_ARGS="$PICA/dist/cli/args.js"
MAIN_JS="$PICA/dist/main.js"
SERVICES_JS="$PICA/dist/core/agent-session-services.js"
SDK_JS="$PICA/dist/core/sdk.js"
AGENT_JS="$AGENT_CORE/dist/agent.js"

# ─── Version detection ──────────────────────────────────────────────────────
PICA_VER=$(node -e "console.log(require('$PICA/package.json').version)" 2>/dev/null || echo "unknown")
SUB_VER=$(node -e "console.log(require('$HOME/.pi/agent/npm/node_modules/pi-subagents/package.json').version)" 2>/dev/null || echo unknown)
SUB_MM=$(echo "$SUB_VER" | grep -oP '^\d+\.\d+')
# pi-subagents >= 0.55: spawnRunner 只做 cfg 序列化转发，6-tab 检查点作废
SUB_CFG_SER=$(awk -v a="${SUB_MM:-0}" 'BEGIN{print (a>=0.55)?1:0}')
# v2.18.0: pi-coding-agent >= 0.84.3 改为 esbuild bundle 架构 — bin 入口
# dist/bundle/cli.js -> chunks/*.js（全内联），散装 dist/*.js 运行时不被加载。
# v2.20.0: 入口 chunk 名不再硬编码。esbuild 每次构建都可能改 hash
#   （0.84.3=chunk-E5KXRMZK → 0.84.4=chunk-OMWWHBTG），硬编码会让 bundle 检测
#   退化成 bundle=0，然后去查运行时根本不加载的散装 dist/*.js —— 即 v2.18.0
#   修过的假阳性陷阱复发。改为从 bin 入口解析被 import 的 chunk 列表，
#   取其中体积最大的那个（全内联主 chunk），并要求它含已知结构标记。
BUNDLE_CLI="$PICA/dist/bundle/cli.js"
BUNDLE_CHUNK=""
if [ -f "$BUNDLE_CLI" ]; then
    BUNDLE_CHUNK=$(node -e '
        const fs = require("fs"), path = require("path");
        const cli = process.argv[1];
        const src = fs.readFileSync(cli, "utf8");
        const names = [...src.matchAll(/\.\/chunks\/(chunk-[A-Za-z0-9_]+)\.js/g)].map(m => m[1]);
        const dir = path.join(path.dirname(cli), "chunks");
        let best = "", bestSize = -1;
        for (const n of [...new Set(names)]) {
            const p = path.join(dir, n + ".js");
            try { const s = fs.statSync(p).size; if (s > bestSize) { bestSize = s; best = p; } } catch {}
        }
        // 主 chunk 必须是内联了 agent-session 结构的那份，否则视为解析失败
        if (best && !/createAgentSessionFromServices/.test(fs.readFileSync(best, "utf8"))) best = "";
        if (best) console.log(best);
    ' "$BUNDLE_CLI" 2>/dev/null)
fi
if [ -n "$BUNDLE_CHUNK" ]; then
    BUNDLE_MODE=1
else
    BUNDLE_MODE=0
fi
echo "=== Temperature chain check — pi-coding-agent v$PICA_VER / pi-subagents v$SUB_VER (bundle=$BUNDLE_MODE) ==="
[ "$BUNDLE_MODE" = "1" ] && echo "    entry chunk: $(basename "$BUNDLE_CHUNK") ($(wc -c < "$BUNDLE_CHUNK") bytes)"

# ─── Verification ───────────────────────────────────────────────────────────
PASS=0 FAIL=0
check() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qF "$pattern" "$file" 2>/dev/null; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}
check_regex() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}
check_pcre() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qP "$pattern" "$file" 2>/dev/null; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "--- pi-coding-agent runtime bundle (v2.18.0+; loose dist NOT loaded) ---"
if [ "$BUNDLE_MODE" = "1" ]; then
    check "$BUNDLE_CHUNK" 'arg==="--temperature"' 'CLI --temperature parsing (bundle)'
    check "$BUNDLE_CHUNK" 'parsed.temperature!==void 0' 'buildSessionOptions parsed.temperature (bundle)'
    check "$BUNDLE_CHUNK" 'temperature:sessionOptions.temperature' 'main.js → services (bundle)'
    check "$BUNDLE_CHUNK" 'thinkingLevel:options.thinkingLevel,temperature:options.temperature' 'services pass-through (bundle)'
    check "$BUNDLE_CHUNK" 'PI_SUBAGENT_TEMPERATURE' 'sdk env/opt read (bundle)'
    check "$BUNDLE_CHUNK" 'PI_SUBAGENT_CHILD_AGENT' 'sdk YAML fallback (bundle)'
    check "$BUNDLE_CHUNK" 'this.temperature=runtimeOptions.temperature' 'Agent constructor stores temp (bundle)'
    check "$BUNDLE_CHUNK" 'temperature:this.temperature' 'createLoopConfig exports temp (bundle)'
else
    check      "$CLI_ARGS"       'result.temperature'        'CLI --temperature parsing'
    check      "$MAIN_JS"        'options.temperature'        'main.js buildSessionOptions'
    check      "$MAIN_JS"        'temperature: sessionOptions.temperature' 'main.js → services'
    check      "$SERVICES_JS"    'temperature: options.temperature' 'services.js pass-through'
    check_regex "$SDK_JS"        'PI_SUBAGENT_TEMPERATURE|temperature =' 'sdk.js env/opt read'
    check_regex "$SDK_JS"        'PI_SUBAGENT_CHILD_AGENT' 'sdk.js YAML fallback'
    echo ""
    echo "--- pi-agent-core dist files (1) ---"
    check      "$AGENT_JS"       'this.temperature'           'Agent constructor stores temp'
    check      "$AGENT_JS"       'temperature: this.temperature' 'createLoopConfig exports temp'
fi
echo ""
echo "--- pi-subagents source files (13) ---"
NPM_DIR="$HOME/.pi/agent/npm/node_modules/pi-subagents"
check      "$NPM_DIR/src/agents/agent-serializer.ts" '"temperature"'  'KNOWN_FIELDS whitelist'
check      "$NPM_DIR/src/agents/agent-serializer.ts" 'config.temperature' 'serializer outputs temperature'
check      "$NPM_DIR/src/agents/agents.ts"            'temperature?: number' 'AgentConfig interface'
check      "$NPM_DIR/src/agents/agents.ts"            'Number(frontmatter.temperature)' 'frontmatter parsing'
check      "$NPM_DIR/src/runs/shared/pi-args.ts"      'temperature?: number' 'BuildPiArgsInput interface'
check      "$NPM_DIR/src/runs/shared/pi-args.ts"      'PI_SUBAGENT_TEMPERATURE' 'env var set'
check      "$NPM_DIR/src/runs/shared/parallel-utils.ts" 'temperature?: number' 'parallel-utils interface'
check      "$NPM_DIR/src/runs/foreground/execution.ts" 'temperature: agent.temperature' 'execution.ts pass-through'
check      "$NPM_DIR/src/runs/background/async-execution.ts" 'temperature: a.temperature' 'async buildSeqStep'
check      "$NPM_DIR/src/runs/background/async-execution.ts" 'temperature: agentConfig.temperature' 'async agentConfig path'
if [ "$SUB_CFG_SER" = "1" ]; then
    echo "  ⏭️  async spawnRunner — N/A in pi-subagents >= 0.55 (cfg serialization; chain via buildSeqStep→runner)"
    PASS=$((PASS + 1))
else
    check_pcre "$NPM_DIR/src/runs/background/async-execution.ts" '^\t{6}temperature: agentConfig\.temperature,$' 'async spawnRunner (6-tab)'
fi
check      "$NPM_DIR/src/runs/background/subagent-runner.ts" 'temperature: step.temperature' 'subagent-runner store'
# subagent-runner needs temperature in BOTH status store AND buildPiArgs call
runner_count=$(grep -cF 'temperature: step.temperature' "$NPM_DIR/src/runs/background/subagent-runner.ts" 2>/dev/null || true)
if [ "${runner_count:-0}" -ge 2 ]; then
    echo "  ✅ subagent-runner buildPiArgs"
    PASS=$((PASS + 1))
else
    echo "  ❌ subagent-runner buildPiArgs"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "  Results: $PASS passed, $FAIL missing"

if [ $FAIL -eq 0 ]; then
    echo "  🎉 Temperature chain intact"
    exit 0
fi

# ─── Auto-apply (only for known versions) ───────────────────────────────────
if [ "$1" != "--apply" ] && [ "$1" != "-a" ]; then
    echo ""
    echo "  ⚠️  Temperature chain broken ($FAIL checkpoints)."
    echo "  Run with --apply to auto-fix (v0.82.x - v0.89.x / bundle>=0.84.3 入口 chunk 自动解析 / pi-subagents <= v0.59.x):"
    echo "    $0 --apply"
    echo "  Or ask pi: 'apply temperature fix from subagent-temperature-fix skill'"
    exit 1
fi

echo ""
echo "--- Auto-applying temperature fix for v$PICA_VER ---"

# ─── pi-subagents source patches ────────────────────────────────────────────
apply_pi_subagents() {
    local NPM_DIR="$HOME/.pi/agent/npm/node_modules/pi-subagents"
    echo "  Patching pi-subagents source files..."

    python3 << 'PYEOF'
import sys, os, json
NPM_DIR = os.path.expanduser("~/.pi/agent/npm/node_modules/pi-subagents")
_sub_v = json.load(open(os.path.join(NPM_DIR, "package.json")))["version"].split(".")
SUB_NEW_ARCH = tuple(int(x) for x in _sub_v[:2]) >= (0, 55)

# 1) agent-serializer.ts: add "temperature" to KNOWN_FIELDS
f = os.path.join(NPM_DIR, "src/agents/agent-serializer.ts")
with open(f) as fh: c = fh.read()
if '"temperature"' not in c:
    c = c.replace('"thinking",', '"thinking",\n\t"temperature",')
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ agent-serializer.ts: KNOWN_FIELDS")
else:
    print("  ⏭️  agent-serializer.ts: already patched")

# 1b) agent-serializer.ts: add temperature output line to serializeAgent
if 'config.temperature' not in c:
    c = c.replace(
        'lines.push(`thinking: ${config.thinking ?? ""}`);',
        'lines.push(`thinking: ${config.thinking ?? ""}`);\n\tif (config.temperature !== undefined || preserve("temperature")) lines.push(`temperature: ${config.temperature ?? ""}`);'
    )
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ agent-serializer.ts: temperature output line")
else:
    print("  ⏭️  agent-serializer.ts: temperature output already present")

# 2) agents.ts: interfaces + frontmatter parsing + cloneOverrideBase
f = os.path.join(NPM_DIR, "src/agents/agents.ts")
with open(f) as fh: c = fh.read()
patched = False
# BuiltinAgentOverrideBase interface
if 'temperature?: number' not in c:
    c = c.replace(
        'thinking?: string | false;\n\tsystemPromptMode: SystemPromptMode;',
        'thinking?: string | false;\n\ttemperature?: number;\n\tsystemPromptMode: SystemPromptMode;'
    )
    patched = True
# BuiltinAgentOverrideConfig interface
if 'temperature?: number | false' not in c:
    c = c.replace(
        'thinking?: string | false;\n\tsystemPromptMode?: SystemPromptMode;',
        'thinking?: string | false;\n\ttemperature?: number | false;\n\tsystemPromptMode?: SystemPromptMode;'
    )
    patched = True
# AgentConfig interface (v0.38.0: also needs temperature field)
if 'export interface AgentConfig {' in c:
    head, rest = c.split('export interface AgentConfig {', 1)
    iface = rest.split('\n}', 1)[0]
    if 'temperature?: number;' not in iface and 'thinking?: string | false;' in iface:
        iface = iface.replace('thinking?: string | false;', 'thinking?: string | false;\n\ttemperature?: number;', 1)
        c = head + 'export interface AgentConfig {' + iface + '\n}' + rest.split('\n}', 1)[1]
        patched = True
# frontmatter parsing (v0.41.0: spread syntax; ≤v0.40: plain line)
if 'Number(frontmatter.temperature)' not in c:
    before = c
    # v0.41.0 spread anchor
    c = c.replace(
        '...(frontmatter.thinking !== undefined ? { thinking: frontmatter.thinking === "false" ? false : frontmatter.thinking } : {}),',
        '...(frontmatter.thinking !== undefined ? { thinking: frontmatter.thinking === "false" ? false : frontmatter.thinking } : {}),\n\t\t\t...(frontmatter.temperature !== undefined ? { temperature: Number(frontmatter.temperature) } : {}),'
    )
    if c == before:
        # ≤v0.40 plain anchor
        c = c.replace(
            'thinking: frontmatter.thinking === "false" ? false : frontmatter.thinking,',
            'thinking: frontmatter.thinking === "false" ? false : frontmatter.thinking,\n\t\t\ttemperature: frontmatter.temperature !== undefined ? Number(frontmatter.temperature) : undefined,'
        )
    if c != before:
        patched = True
    else:
        print("  ⚠️  agents.ts: frontmatter parsing anchor not found — version drift, check manually")
# cloneOverrideBase (v0.41.0: spread syntax; ≤v0.40: plain line)
if 'temperature: agent.temperature' not in c:
    before = c
    c = c.replace(
        '...(agent.thinking !== undefined ? { thinking: agent.thinking } : {}),',
        '...(agent.thinking !== undefined ? { thinking: agent.thinking } : {}),\n\t\t...(agent.temperature !== undefined ? { temperature: agent.temperature } : {}),'
    )
    if c == before:
        c = c.replace(
            'thinking: agent.thinking,',
            'thinking: agent.thinking,\n\t\ttemperature: agent.temperature,'
        )
    if c != before:
        patched = True
    else:
        print("  ⚠️  agents.ts: cloneOverrideBase anchor not found — version drift, check manually")
# buildBuiltinOverrideConfig Pick: add "temperature" (v0.41.0 spread-era Pick list)
# v2.17.0: short-anchor — v0.55 Pick 列表新增 modelProvider 使旧长锚点失配；
# 新旧版本均含 '"thinking" | "systemPromptMode"' 子串
if '"thinking" | "temperature"' not in c:
    before = c
    c = c.replace(
        '"thinking" | "systemPromptMode"',
        '"thinking" | "temperature" | "systemPromptMode"'
    )
    if c != before:
        patched = True
    else:
        print("  ⚠️  agents.ts: buildBuiltinOverrideConfig Pick anchor not found — version drift, check manually")
# buildBuiltinOverrideConfig body: carry draft.temperature into override
if 'override.temperature' not in c:
    before = c
    c = c.replace(
        'if (draft.thinking !== base.thinking) override.thinking = draft.thinking ?? false;',
        'if (draft.thinking !== base.thinking) override.thinking = draft.thinking ?? false;\n\tif (draft.temperature !== base.temperature) override.temperature = draft.temperature ?? false;'
    )
    if c != before:
        patched = True
    else:
        print("  ⚠️  agents.ts: buildBuiltinOverrideConfig body anchor not found — version drift, check manually")
if patched:
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ agents.ts: interfaces/parsing/overrideBase")
else:
    print("  ⏭️  agents.ts: already patched")

# 3) pi-args.ts: interface + env var
f = os.path.join(NPM_DIR, "src/runs/shared/pi-args.ts")
with open(f) as fh: c = fh.read()
patched = False
if 'temperature?: number' not in c:
    c = c.replace(
        'childAgentName?: string;',
        'childAgentName?: string;\n\ttemperature?: number;'
    )
    patched = True
if 'PI_SUBAGENT_TEMPERATURE' not in c:
    c = c.replace(
        'if (input.childAgentName) {',
        'if (input.temperature !== undefined) {\n\t\tenv.PI_SUBAGENT_TEMPERATURE = String(input.temperature);\n\t}\n\tif (input.childAgentName) {'
    )
    patched = True
if patched:
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ pi-args.ts: interface + PI_SUBAGENT_TEMPERATURE env")
else:
    print("  ⏭️  pi-args.ts: already patched")

# 4) execution.ts: foreground path
f = os.path.join(NPM_DIR, "src/runs/foreground/execution.ts")
with open(f) as fh: c = fh.read()
if 'temperature: agent.temperature' not in c:
    c = c.replace(
        'thinking: effectiveThinking,',
        'thinking: effectiveThinking,\n\t\ttemperature: agent.temperature,'
    )
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ execution.ts: foreground buildPiArgs")
else:
    print("  ⏭️  execution.ts: already patched")

# 5) parallel-utils.ts: interface
f = os.path.join(NPM_DIR, "src/runs/shared/parallel-utils.ts")
with open(f) as fh: c = fh.read()
if 'temperature?: number' not in c:
    c = c.replace(
        'thinking?: string;',
        'thinking?: string;\n\ttemperature?: number;'
    )
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ parallel-utils.ts: RunnerSubagentStep interface")
else:
    print("  ⏭️  parallel-utils.ts: already patched")

# 6) async-execution.ts: buildSeqStep + recoveryDescriptor + spawnRunner steps
import re as _re
f = os.path.join(NPM_DIR, "src/runs/background/async-execution.ts")
with open(f) as fh: c = fh.read()
patched = False
seq_patched = recovery_patched = spawn_patched = heal_patched = False

# --- HEAL (must run FIRST): corrupt spawnRunner from old str.replace bug ---
# v0.40.0 lesson: plain str.replace uses SUBSTRING matching, so the 3-tab
# buildSeqStep pattern matched INSIDE the 6-tab spawnRunner line, splitting it
# and inserting a 3-tab `temperature: a.temperature,` where `a` is undefined
# (ReferenceError at runtime). Detect + heal the corrupted block:
corrupt_re = _re.compile(r'(?m)^\t\t\t\t\t\tthinking: resolveEffectiveThinking\(model, effectiveThinking\),\n\t\t\ttemperature: a\.temperature,\n(\t\t\t\t\t\tmodelCandidates,)')
if corrupt_re.search(c):
    c = corrupt_re.sub(
        r'\t\t\t\t\t\tthinking: resolveEffectiveThinking(model, effectiveThinking),\n\t\t\t\t\t\ttemperature: agentConfig.temperature,\n\1',
        c,
    )
    heal_patched = True

# --- buildSeqStep (3-tab) ---
# MUST use ^...$ ANCHORED regex, never str.replace: the 3-tab pattern is a
# SUBSTRING of the 6-tab spawnRunner line, so str.replace corrupts spawnRunner.
seq_re = _re.compile(r'(?m)^\t\t\tthinking: resolveEffectiveThinking\(model, effectiveThinking\),$')
if 'temperature: a.temperature' not in c:
    if seq_re.search(c):
        c = seq_re.sub('\\g<0>\n\t\t\ttemperature: a.temperature,', c, count=1)
        seq_patched = True
    else:
        print("  ⚠️  async-execution.ts: buildSeqStep anchor not found — version drift, check manually")

# --- recoveryDescriptor (single-run path, 2-tab spread) ---
rec_anchor = '(effectiveThinking ? { thinking: resolveEffectiveThinking(model, effectiveThinking) } : {}),'
if 'temperature: agentConfig.temperature' not in c:
    if rec_anchor in c:
        c = c.replace(
            rec_anchor,
            rec_anchor + '\n\t\t...(agentConfig.temperature !== undefined ? { temperature: agentConfig.temperature } : {}),'
        )
        recovery_patched = True
    else:
        print("  ⚠️  async-execution.ts: recoveryDescriptor anchor not found — version drift, check manually")

# --- spawnRunner steps (6-tab, bare modelCandidates) ---
# NOTE: never gate on `c.split('spawnRunner', 1)[1]` — the FIRST 'spawnRunner'
# occurrence is the function DECLARATION (before recoveryDescriptor), so the
# slice includes the recovery patch and falsely reports "already patched".
spawn_anchor = '\t\t\t\t\t\tthinking: resolveEffectiveThinking(model, effectiveThinking),\n\t\t\t\t\t\tmodelCandidates,'
spawn_re = _re.compile(_re.escape(spawn_anchor))
has_spawn_temp = bool(_re.search(r'(?m)^\t{6}temperature: agentConfig\.temperature,$', c))
if SUB_NEW_ARCH:
    print("  ⏭️  async-execution.ts: spawnRunner N/A (v0.55+ cfg serialization; temperature via buildSeqStep)")
elif not has_spawn_temp:
    if spawn_re.search(c):
        # insert BETWEEN thinking and modelCandidates (canonical v0.38 shape)
        c = spawn_re.sub(
            '\t\t\t\t\t\tthinking: resolveEffectiveThinking(model, effectiveThinking),\n\t\t\t\t\t\ttemperature: agentConfig.temperature,\n\t\t\t\t\t\tmodelCandidates,',
            c,
            count=1,
        )
        spawn_patched = True
    else:
        print("  ⚠️  async-execution.ts: spawnRunner anchor not found — version drift, check manually")

# --- integrity assertions (fail loudly, never silently) ---
a_count = len(_re.findall(r'(?m)^\t\t\ttemperature: a\.temperature,$', c))
ac_count = len(_re.findall(r'(?m)^\t\t\t\t\t\ttemperature: agentConfig\.temperature,$', c))
if a_count != 1:
    print(f"  ❌ async-execution.ts integrity FAIL: buildSeqStep `a.temperature` count={a_count} (expected 1)")
if ac_count != 1 and not SUB_NEW_ARCH:
    print(f"  ❌ async-execution.ts integrity FAIL: spawnRunner `agentConfig.temperature` count={ac_count} (expected 1)")

patched = seq_patched or recovery_patched or spawn_patched or heal_patched
if patched:
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ async-execution.ts: buildSeqStep %s / recoveryDescriptor %s / spawnRunner %s%s" % (
        "patched" if seq_patched else "ok",
        "patched" if recovery_patched else "ok",
        "patched" if spawn_patched else "ok",
        " / healed-corruption" if heal_patched else ""))
else:
    print("  ⏭️  async-execution.ts: already patched")

# 7) subagent-runner.ts: add temperature to buildPiArgs call + status store (background path)
f = os.path.join(NPM_DIR, "src/runs/background/subagent-runner.ts")
with open(f) as fh: c = fh.read()
# Pattern: model: candidate, followed by inheritProjectContext
# (the buildPiArgs call in runSingleStep)
import re
pattern = r'(\t\t\tmodel: candidate,\n)(\t\t\tinheritProjectContext:)'
if 'temperature: step.temperature,' not in c.split('inheritProjectContext:')[0].rsplit('model: candidate,', 1)[1] if 'model: candidate,' in c and 'inheritProjectContext:' in c else True:
    # Insert temperature after model: candidate, in buildPiArgs
    c = re.sub(pattern, r'\1\t\t\ttemperature: step.temperature,\n\2', c)
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ subagent-runner.ts: buildPiArgs temperature")
else:
    print("  ⏭️  subagent-runner.ts: buildPiArgs already patched")
# status store line: v0.38.0 removed native step.temperature serialization — add it
if 'temperature: step.temperature,' not in c.split('thinking: step.thinking,')[1] if 'thinking: step.thinking,' in c else True:
    c = c.replace(
        'thinking: step.thinking,',
        'thinking: step.thinking,\n\t\t\t\ttemperature: step.temperature,'
    )
    with open(f, 'w') as fh: fh.write(c)
    print("  ✅ subagent-runner.ts: status store temperature")
else:
    print("  ⏭️  subagent-runner.ts: status store already patched")

# --- subagent-runner integrity assertions ---
import re as _re2
bpi_count = len(_re2.findall(r'(?m)^\t\t\ttemperature: step\.temperature,$', c))
store_count = len(_re2.findall(r'(?m)^\t\t\t\ttemperature: step\.temperature,$', c))
if bpi_count != 1:
    print(f"  ❌ subagent-runner.ts integrity FAIL: buildPiArgs `step.temperature` count={bpi_count} (expected 1)")
# v2.17.0: 放宽为 >=1 — v0.55 有 revival/恢复路径的合法第二处 4-tab store 行（3501 行）
if store_count < 1:
    print(f"  ❌ subagent-runner.ts integrity FAIL: status store `step.temperature` count={store_count} (expected >= 1)")
PYEOF
}

# ─── v2.18.0 bundle architecture patches ───────────────────────────────────
apply_bundle() {
    echo "  Applying v2.20.0 bundle temperature chain patches (esbuild $(basename "${BUNDLE_CHUNK:-<unresolved>}"))..."
    [ -f "${BUNDLE_CHUNK:-}" ] || { echo "  ❌ BUNDLE_CHUNK unresolved — refusing to patch"; return 1; }
    PI_BUNDLE_CHUNK="$BUNDLE_CHUNK" python3 << 'PYEOF'
import sys, os

B = os.environ["PI_BUNDLE_CHUNK"]

with open(B, "r", encoding="utf-8") as f:
    content = f.read()

orig = content
patched = 0
warnings = []


def rep(old, new, label):
    global content, patched
    if new in content:
        print(f"  ⏭️  {label}: already present")
        return
    if old not in content:
        warnings.append(f"⚠️  {label}: anchor NOT FOUND (version drift?)")
        return
    content = content.replace(old, new, 1)
    patched += 1
    print(f"  ✅ {label}")

# 1) CLI args
rep(
    'else if(arg==="--print"||arg==="-p"){',
    'else if(arg==="--temperature"&&i+1<args.length){let value=parseFloat(args[++i]);Number.isNaN(value)||value<0||value>2?result.diagnostics.push({type:"warning",message:`Invalid temperature "${args[i]}". Expected 0-2.`}):result.temperature=value}else if(arg==="--print"||arg==="-p"){',
    "cli/args.js (bundle) --temperature",
)

# 2) buildSessionOptions
rep(
    "let options={},diagnostics=[],cliThinkingFromModel=!1;",
    "let options={},diagnostics=[],cliThinkingFromModel=!1;parsed.temperature!==void 0&&(options.temperature=parsed.temperature);",
    "buildSessionOptions parsed.temperature",
)

# 3) main.js -> services
rep(
    "createAgentSessionFromServices({services:services2,sessionManager:sessionManager2,sessionStartEvent,model:sessionOptions.model,thinkingLevel:sessionOptions.thinkingLevel,",
    "createAgentSessionFromServices({services:services2,sessionManager:sessionManager2,sessionStartEvent,model:sessionOptions.model,thinkingLevel:sessionOptions.thinkingLevel,temperature:sessionOptions.temperature,",
    "main.js -> services temperature",
)

# 4) services pass-through
rep(
    "function createAgentSessionFromServices(options){return createAgentSession({cwd:options.services.cwd,agentDir:options.services.agentDir,modelRuntime:options.services.modelRuntime,settingsManager:options.services.settingsManager,resourceLoader:options.services.resourceLoader,sessionManager:options.sessionManager,model:options.model,thinkingLevel:options.thinkingLevel,",
    "function createAgentSessionFromServices(options){return createAgentSession({cwd:options.services.cwd,agentDir:options.services.agentDir,modelRuntime:options.services.modelRuntime,settingsManager:options.services.settingsManager,resourceLoader:options.services.resourceLoader,sessionManager:options.sessionManager,model:options.model,thinkingLevel:options.thinkingLevel,temperature:options.temperature,",
    "createAgentSessionFromServices pass-through",
)

# 5) createAgentSession: env + YAML fallback (MUST insert AFTER `extensionRunnerRef={};`
#    statement terminator — inserting inside the let-chain causes SyntaxError)
rep(
    "extensionRunnerRef={};agent=new Agent({initialState:{systemPrompt:\"\",model,thinkingLevel,tools:[]},",
    'extensionRunnerRef={};let temperature=options.temperature;if(temperature===void 0){let envTemperature=Number(process.env.PI_SUBAGENT_TEMPERATURE);Number.isFinite(envTemperature)&&(temperature=envTemperature)}if(temperature===void 0){let agentName=process.env.PI_SUBAGENT_CHILD_AGENT;if(agentName){try{let yamlText=readFileSync(join29(getAgentDir(),"agents",agentName+".md"),"utf8"),tempMatch=yamlText.match(/^temperature:\\s*([0-9.]+)/m);tempMatch&&(temperature=Number(tempMatch[1]))}catch(e){}}}agent=new Agent({initialState:{systemPrompt:"",model,thinkingLevel,tools:[]},temperature,',
    "createAgentSession env+YAML resolution",
)

# 6) Agent constructor
rep(
    'this.toolExecution=runtimeOptions.toolExecution??"parallel"',
    'this.toolExecution=runtimeOptions.toolExecution??"parallel",this.temperature=runtimeOptions.temperature',
    "Agent constructor this.temperature",
)

# 7) createLoopConfig
rep(
    "createLoopConfig(options={}){let skipInitialSteeringPoll=options.skipInitialSteeringPoll===!0,shouldStopAfterTurn=this.shouldStopAfterTurn;return{model:this._state.model,reasoning:this._state.thinkingLevel===\"off\"?void 0:this._state.thinkingLevel,",
    "createLoopConfig(options={}){let skipInitialSteeringPoll=options.skipInitialSteeringPoll===!0,shouldStopAfterTurn=this.shouldStopAfterTurn;return{model:this._state.model,temperature:this.temperature,reasoning:this._state.thinkingLevel===\"off\"?void 0:this._state.thinkingLevel,",
    "createLoopConfig exports temperature",
)

# Integrity assertions
asserts = {
    "args --temperature": 'arg==="--temperature"&&i+1<args.length' in content,
    "parsed.temperature": "parsed.temperature!==void 0" in content,
    "sessionOptions.temperature": "temperature:sessionOptions.temperature" in content,
    "services pass-through": "thinkingLevel:options.thinkingLevel,temperature:options.temperature" in content,
    "env resolution": "PI_SUBAGENT_TEMPERATURE" in content,
    "yaml fallback": "PI_SUBAGENT_CHILD_AGENT" in content,
    "this.temperature": "this.temperature=runtimeOptions.temperature" in content,
    "createLoopConfig": "temperature:this.temperature" in content,
}

failed = [k for k, v in asserts.items() if not v]
for k, v in asserts.items():
    print(f"  {'✅' if v else '❌'} assert {k}")

if failed:
    print(f"❌ FAILED assertions: {failed}")
    sys.exit(1)

if content != orig:
    with open(B, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"🎉 bundle patched ({patched} insertion(s))")
else:
    print("  no changes (already patched)")

for w in warnings:
    print(w)
if warnings:
    sys.exit(2)
PYEOF
    # 6. pi-subagents source patches
    # v2.19.0 FIX: this call was previously orphaned at the tail of apply_082x(),
    # so bundle mode NEVER patched the src layer — every pi-subagents npm update
    # silently wiped all 13 src checkpoints (exposed by v0.57.0, the 17th removal).
    apply_pi_subagents
}

# ─── v0.82.x patterns ──────────────────────────────────────────────────────
apply_082x() {
    echo "  Applying v0.82.x temperature chain patches..."

    # 1. cli/args.js: insert --temperature after --thinking block, before --print
    # Strategy: find "else if (arg === \"--print\"" and insert before it
    # But only if not already patched
    if ! grep -qF 'result.temperature' "$CLI_ARGS"; then
        python3 -c "
import re
with open('$CLI_ARGS') as f: content = f.read()
# Insert temperature parsing block before --print handler
insertion = '''        else if (arg === \"--temperature\" && i + 1 < args.length) {
            const value = parseFloat(args[++i]);
            if (!isNaN(value) && value >= 0 && value <= 2) {
                result.temperature = value;
            }
            else {
                result.diagnostics.push({
                    type: \"warning\",
                    message: \`Invalid temperature \"\${args[i]}\". Expected 0-2.\`,
                });
            }
        }
'''
# Find --print line and insert before it
pattern = r'(        else if \(arg === \"--print\" \|\| arg === \"-p\"\) \{)'
content = re.sub(pattern, insertion + r'\1', content, count=1)
# Also add to help text after --thinking line
help_insert = '  --temperature <value>          Set temperature 0-2 (e.g. 0.7). Overrides PI_SUBAGENT_TEMPERATURE env.\\\\n'
content = re.sub(
    r'(  --thinking <level>             Set thinking level: .+)',
    r'\\1\\n' + help_insert,
    content, count=1
)
with open('$CLI_ARGS', 'w') as f: f.write(content)
print('  ✅ cli/args.js')
" && echo "  ✅ cli/args.js" || echo "  ❌ cli/args.js failed"
    else
        echo "  ⏭️  cli/args.js already patched"
    fi

    # 2. main.js: add temperature to buildSessionOptions and createAgentSessionFromServices
    if ! grep -qF 'options.temperature' "$MAIN_JS"; then
        python3 -c "
with open('$MAIN_JS') as f: content = f.read()
# Add temperature to buildSessionOptions return
content = content.replace(
    '    if (parsed.excludeTools) {\n        options.excludeTools = [...parsed.excludeTools];\n    }\n    return { options, cliThinkingFromModel, diagnostics };',
    '    if (parsed.excludeTools) {\n        options.excludeTools = [...parsed.excludeTools];\n    }\n    // Temperature from CLI\n    if (parsed.temperature !== undefined) {\n        options.temperature = parsed.temperature;\n    }\n    return { options, cliThinkingFromModel, diagnostics };'
)
# Add temperature to createAgentSessionFromServices call
content = content.replace(
    '            customTools: sessionOptions.customTools,\n        });',
    '            customTools: sessionOptions.customTools,\n            temperature: sessionOptions.temperature,\n        });'
)
with open('$MAIN_JS', 'w') as f: f.write(content)
print('  ✅ main.js')
" && echo "  ✅ main.js" || echo "  ❌ main.js failed"
    else
        echo "  ⏭️  main.js already patched"
    fi

    # 3. agent-session-services.js: add temperature pass-through
    # v0.83.0: insert before the closing }); of createAgentSessionFromServices
    if ! grep -qF 'temperature: options.temperature' "$SERVICES_JS"; then
        python3 -c "
with open('$SERVICES_JS') as f: content = f.read()
# v0.83.0: last field is sessionStartEvent before });
# Try exact pattern first, then relaxed pattern
import re
new_field = '        temperature: options.temperature,\n'
# Match the closing }); of createAgentSessionFromServices with preceding sessionStartEvent
pattern = r'( {8}sessionStartEvent: options\.sessionStartEvent,\n)(    \}\);)'
if re.search(pattern, content):
    content = re.sub(pattern, r'\1' + new_field + r'\2', content)
    with open('$SERVICES_JS', 'w') as f: f.write(content)
    print('  ✅ agent-session-services.js')
else:
    # Fallback: try older pattern
    old = '        customTools: options.customTools,\n        sessionStartEvent: options.sessionStartEvent,'
    new = '        customTools: options.customTools,\n        temperature: options.temperature,\n        sessionStartEvent: options.sessionStartEvent,'
    if old in content:
        content = content.replace(old, new)
        with open('$SERVICES_JS', 'w') as f: f.write(content)
        print('  ✅ agent-session-services.js (fallback)')
    else:
        print('  ❌ agent-session-services.js: pattern not found')
        sys.exit(1)
" && echo "  ✅ agent-session-services.js" || echo "  ❌ agent-session-services.js failed"
    else
        echo "  ⏭️  agent-session-services.js already patched"
    fi

    # 4. sdk.js: add temperature resolution + pass to Agent
    #    Step A: ensure env/opt resolution exists (fresh sdk.js after upgrade)
    if ! grep -qE 'PI_SUBAGENT_TEMPERATURE|temperature =' "$SDK_JS"; then
        python3 -c "
with open('$SDK_JS') as f: content = f.read()
# Insert temperature resolution before agent = new Agent({
insertion = '''    // Temperature: CLI --temperature > PI_SUBAGENT_TEMPERATURE env > agent YAML fallback > undefined
    // YAML fallback makes the chain immune to pi-subagents dropping the env passthrough.
    let temperature = options.temperature;
    if (temperature === undefined) {
        const envTemperature = Number(process.env.PI_SUBAGENT_TEMPERATURE);
        if (Number.isFinite(envTemperature)) temperature = envTemperature;
    }
    if (temperature === undefined) {
        const agentName = process.env.PI_SUBAGENT_CHILD_AGENT;
        if (agentName) {
            try {
                const yamlText = readFileSync(join(getAgentDir(), \"agents\", agentName + \".md\"), \"utf8\");
                const tempMatch = yamlText.match(/^temperature:\\\\s*([0-9.]+)/m);
                if (tempMatch) temperature = Number(tempMatch[1]);
            } catch { /* unreadable: keep undefined (provider default) */ }
        }
    }
    agent = new Agent({
'''
content = content.replace(
    '    agent = new Agent({\n        initialState: {\n            systemPrompt: \"\",\n            model,\n            thinkingLevel,\n            tools: [],\n        },',
    insertion + '        initialState: {\n            systemPrompt: \"\",\n            model,\n            thinkingLevel,\n            tools: [],\n        },\n        temperature, // passed through createLoopConfig → streamFn options → provider'
)
# ensure readFileSync import exists (check the IMPORT LINE, not 'readFileSync':
# the inserted block below contains 'readFileSync(' usage, so substring check
# after replace() would always be False and the import would never be added)
if 'import { readFileSync } from \"node:fs\";' not in content:
    content = content.replace(
        'import { join } from \"node:path\";',
        'import { join } from \"node:path\";\nimport { readFileSync } from \"node:fs\";',
        1
    )
with open('$SDK_JS', 'w') as f: f.write(content)
print('  ✅ sdk.js')
" && echo "  ✅ sdk.js" || echo "  ❌ sdk.js failed"
    else
        echo "  ⏭️  sdk.js env/opt already patched"
    fi

    # 4b. sdk.js: upgrade to YAML fallback (idempotent, applies to older patches too)
    if ! grep -qF 'PI_SUBAGENT_CHILD_AGENT' "$SDK_JS"; then
        python3 -c "
with open('$SDK_JS') as f: content = f.read()
if 'import { readFileSync } from \"node:fs\";' not in content:
    content = content.replace(
        'import { join } from \"node:path\";',
        'import { join } from \"node:path\";\nimport { readFileSync } from \"node:fs\";',
        1
    )
old_block = '''    // Temperature: CLI --temperature > PI_SUBAGENT_TEMPERATURE env > default undefined
    const temperature = options.temperature !== undefined
        ? options.temperature
        : (Number.isFinite(Number(process.env.PI_SUBAGENT_TEMPERATURE))
            ? Number(process.env.PI_SUBAGENT_TEMPERATURE)
            : undefined);'''
new_block = '''    // Temperature: CLI --temperature > PI_SUBAGENT_TEMPERATURE env > agent YAML fallback > undefined
    // YAML fallback makes the chain immune to pi-subagents dropping the env passthrough.
    let temperature = options.temperature;
    if (temperature === undefined) {
        const envTemperature = Number(process.env.PI_SUBAGENT_TEMPERATURE);
        if (Number.isFinite(envTemperature)) temperature = envTemperature;
    }
    if (temperature === undefined) {
        const agentName = process.env.PI_SUBAGENT_CHILD_AGENT;
        if (agentName) {
            try {
                const yamlText = readFileSync(join(getAgentDir(), \"agents\", agentName + \".md\"), \"utf8\");
                const tempMatch = yamlText.match(/^temperature:\\\\s*([0-9.]+)/m);
                if (tempMatch) temperature = Number(tempMatch[1]);
            } catch { /* unreadable: keep undefined (provider default) */ }
        }
    }'''
if old_block in content:
    content = content.replace(old_block, new_block, 1)
elif 'let temperature = options.temperature;' not in content:
    # Fresh variant without the old comment (defensive)
    content = content.replace(
        'const temperature = options.temperature !== undefined',
        'let temperature = options.temperature;\n    if (temperature === undefined) {\n        const envTemperature = Number(process.env.PI_SUBAGENT_TEMPERATURE);\n        if (Number.isFinite(envTemperature)) temperature = envTemperature;\n    }\n    if (temperature === undefined) {\n        const agentName = process.env.PI_SUBAGENT_CHILD_AGENT;\n        if (agentName) {\n            try {\n                const yamlText = readFileSync(join(getAgentDir(), \"agents\", agentName + \".md\"), \"utf8\");\n                const tempMatch = yamlText.match(/^temperature:\\\\s*([0-9.]+)/m);\n                if (tempMatch) temperature = Number(tempMatch[1]);\n            } catch { /* unreadable: keep undefined (provider default) */ }\n        }\n    }'
    )
with open('$SDK_JS', 'w') as f: f.write(content)
print('  ✅ sdk.js YAML fallback')
" && echo "  ✅ sdk.js YAML fallback" || echo "  ❌ sdk.js YAML fallback failed"
    else
        echo "  ⏭️  sdk.js YAML fallback already present"
    fi

    # 5. agent.js: add temperature to constructor + createLoopConfig
    if ! grep -qF 'this.temperature' "$AGENT_JS"; then
        # Add this.temperature after toolExecution
        sed -i 's/        this.toolExecution = runtimeOptions.toolExecution ?? "parallel";/        this.toolExecution = runtimeOptions.toolExecution ?? \"parallel\";\n        this.temperature = runtimeOptions.temperature;/' "$AGENT_JS" 2>/dev/null || \
        python3 -c "
with open('$AGENT_JS') as f: content = f.read()
content = content.replace(
    '        this.toolExecution = runtimeOptions.toolExecution ?? \"parallel\";',
    '        this.toolExecution = runtimeOptions.toolExecution ?? \"parallel\";\n        this.temperature = runtimeOptions.temperature;'
)
with open('$AGENT_JS', 'w') as f: f.write(content)
print('  ✅ agent.js (constructor)')
" && echo "  ✅ agent.js (constructor)" || echo "  ❌ agent.js constructor failed"
    else
        echo "  ⏭️  agent.js constructor already patched"
    fi

    if ! grep -qF 'temperature: this.temperature' "$AGENT_JS"; then
        python3 -c "
import re
with open('$AGENT_JS') as f: content = f.read()
# v0.83.0: insert temperature after reasoning line in createLoopConfig return
# Pattern: reasoning line followed by sessionId line
pattern = r'(            reasoning: this\._state\.thinkingLevel === \"off\" \? undefined : this\._state\.thinkingLevel,\n)(            sessionId: this\.sessionId,)'
replacement = r'\1            temperature: this.temperature,\n\2'
if re.search(pattern, content):
    new_content = re.sub(pattern, replacement, content)
    with open('$AGENT_JS', 'w') as f: f.write(new_content)
    print('  ✅ agent.js (createLoopConfig)')
else:
    # Fallback: try older exact string match
    old = '            model: this._state.model,\n            reasoning: this._state.thinkingLevel === \"off\" ? undefined : this._state.thinkingLevel,\n            sessionId: this.sessionId,'
    new = '            model: this._state.model,\n            reasoning: this._state.thinkingLevel === \"off\" ? undefined : this._state.thinkingLevel,\n            temperature: this.temperature,\n            sessionId: this.sessionId,'
    if old in content:
        content = content.replace(old, new)
        with open('$AGENT_JS', 'w') as f: f.write(content)
        print('  ✅ agent.js (createLoopConfig) [fallback]')
    else:
        print('  ❌ agent.js createLoopConfig: pattern not found')
        import sys; sys.exit(1)
" && echo "  ✅ agent.js (createLoopConfig)" || echo "  ❌ agent.js createLoopConfig failed"
    else
        echo "  ⏭️  agent.js createLoopConfig already patched"
    fi

    # 6. pi-subagents source patches
    apply_pi_subagents
}

# ─── Version routing ─────────────────────────────────────────────────────────
MAJOR_MINOR=$(echo "$PICA_VER" | grep -oP '^\d+\.\d+')

case "$MAJOR_MINOR" in
    0.82) apply_082x ;;
    0.83|0.84|0.85|0.86|0.87|0.88|0.89)
        if [ "$BUNDLE_MODE" = "1" ]; then
            # v2.18.0: pi-coding-agent >= 0.84.3 esbuild bundle 架构
            # 运行时仅加载 dist/bundle/chunks/*.js，散装 dist/*.js 不加载
            apply_bundle
        else
            # v0.83.0 verified: uses same 0.82.x patterns with improved fallbacks
            # v0.83.0 delta: agent-session-services.js has sessionStartEvent as last field
            #               agent.js createLoopConfig reasoning line unchanged
            echo "  Applying v0.83.x temperature chain patches (compatible with 0.82.x patterns)..."
            apply_082x
        fi
        ;;    *)
        echo "  ❌ Unknown pi-coding-agent version: v$PICA_VER"
        echo "  Cannot auto-apply. Please run:"
        echo "    pi"
        echo "  Then ask: 'apply temperature fix from ~/prompt_boilerplates/System_Fix/subagent-temperature-fix.md'"
        exit 2
        ;;
esac

echo ""
echo "--- Re-verifying after fix ---"
exec "$0"
