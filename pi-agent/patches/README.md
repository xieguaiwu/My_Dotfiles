# Pi-Agent Temperature Patch

Applied: 2026-06-05
Source config: ~/.config/opencode/oh-my-openagent.jsonc
Method: PI_TEMPERATURE env var → agent.js createLoopConfig() → API

## Files patched (4 source + 21 YAML)

### Source patches
1. pi-agent-core/dist/agent.js — reads PI_TEMPERATURE env, injects into loop config
2. pi-subagents/src/agents/agents.ts — parses temperature from YAML frontmatter
3. pi-subagents/src/runs/shared/pi-args.ts — passes temperature via PI_TEMPERATURE env
4. pi-subagents/src/runs/foreground/execution.ts — wires agent.temperature → buildPiArgs

### YAML configs
~/.pi/agent/agents/*.md — 21 agents, temperature range 0.1–0.7

## Reapply after npm update
Check and reapply each source file if overwritten.
