#!/bin/bash
# Reapply pi-agent temperature patches after npm update
# Generated: 2026-06-05
set -e

AGENT_JS="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-agent-core/dist/agent.js"
AGENTS_TS="$HOME/.pi/agent/npm/node_modules/pi-subagents/src/agents/agents.ts"
PI_ARGS_TS="$HOME/.pi/agent/npm/node_modules/pi-subagents/src/runs/shared/pi-args.ts"
EXECUTION_TS="$HOME/.pi/agent/npm/node_modules/pi-subagents/src/runs/foreground/execution.ts"

echo "=== Checking pi-agent temperature patches ==="

check_line() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qF "$pattern" "$file" 2>/dev/null; then
        echo "  ✅ $desc"
    else
        echo "  ❌ MISSING: $desc — needs reapply"
        return 1
    fi
}

FAIL=0

echo "--- agent.js ---"
check_line "$AGENT_JS" "this._temperature = process.env.PI_TEMPERATURE" "_temperature from env" || FAIL=1
check_line "$AGENT_JS" "temperature: this._temperature" "temperature in createLoopConfig" || FAIL=1

echo "--- agents.ts ---"
check_line "$AGENTS_TS" "temperature?: number" "AgentConfig.temperature field" || FAIL=1
check_line "$AGENTS_TS" "const parsedTemperature = Number(frontmatter.temperature)" "temperature parsing" || FAIL=1
check_line "$AGENTS_TS" "temperature: Number.isFinite(parsedTemperature)" "temperature in push" || FAIL=1

echo "--- pi-args.ts ---"
check_line "$PI_ARGS_TS" "temperature?: number" "BuildPiArgsInput.temperature" || FAIL=1
check_line "$PI_ARGS_TS" "PI_TEMPERATURE" "PI_TEMPERATURE env set" || FAIL=1

echo "--- execution.ts ---"
check_line "$EXECUTION_TS" "temperature: agent.temperature" "agent.temperature pass-through" || FAIL=1

if [ $FAIL -eq 0 ]; then
    echo "=== All patches intact ==="
else
    echo "=== Some patches missing — run: $0 --apply ==="
    exit 1
fi
