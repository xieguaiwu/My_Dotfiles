#!/bin/bash
# Reapply pi-agent temperature chain patches (version-aware)
# Last updated: 2026-08-11 — v2.12.0: pi-subagents 0.46.0 / pi-coding-agent 0.84.1 (10th removal)
#
# Architecture: PI_SUBAGENT_TEMPERATURE env → cli/args.js → main.js →
#   agent-session-services.js → sdk.js → agent.js → createLoopConfig() →
#   streamFn → buildBaseOptions → provider API
#
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
echo "=== Temperature chain check — pi-coding-agent v$PICA_VER ==="

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
echo "--- pi-coding-agent dist files (5) ---"
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

echo ""
echo "--- pi-subagents source files (12) ---"
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
check_pcre "$NPM_DIR/src/runs/background/async-execution.ts" '^\t{6}temperature: agentConfig\.temperature,$' 'async spawnRunner (6-tab)'
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
    echo "  Run with --apply to auto-fix (v0.82.x - v0.89.x / pi-subagents <= v0.46.x):"
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
import sys, os
NPM_DIR = os.path.expanduser("~/.pi/agent/npm/node_modules/pi-subagents")

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
if 'Pick<AgentConfig, "model" | "fallbackModels" | "thinking" | "temperature"' not in c:
    before = c
    c = c.replace(
        '"model" | "fallbackModels" | "thinking" | "systemPromptMode"',
        '"model" | "fallbackModels" | "thinking" | "temperature" | "systemPromptMode"'
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
if not has_spawn_temp:
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
if ac_count != 1:
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
if store_count != 1:
    print(f"  ❌ subagent-runner.ts integrity FAIL: status store `step.temperature` count={store_count} (expected 1)")
PYEOF
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
        # v0.83.0 verified: uses same 0.82.x patterns with improved fallbacks
        # v0.83.0 delta: agent-session-services.js has sessionStartEvent as last field
        #               agent.js createLoopConfig reasoning line unchanged
        echo "  Applying v0.83.x temperature chain patches (compatible with 0.82.x patterns)..."
        apply_082x
        ;;
    *)
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
