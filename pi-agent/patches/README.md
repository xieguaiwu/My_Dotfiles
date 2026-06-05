# Pi-Agent Patches

Applied: 2026-06-05 (updated)
Method: `reapply.sh` — unified shell script, auto-triggered via npm postinstall hook

## Auto-reapply mechanism

Two layers of protection against `pi update` overwriting patches:

| Layer | Trigger | Coverage |
|-------|---------|----------|
| **npm postinstall** | `npm install` / `pi update` | `~/.pi/agent/npm/node_modules/` (pi-tui, etc.) |
| **`piu` fish function** | Manual `piu` (replaces `pi update`) | Global pi-coding-agent + npm packages |

Use `piu` instead of `pi update` for safe updates.

## Patch catalog

### 1. Temperature (2026-06-05)
Source config: `~/.config/opencode/oh-my-openagent.jsonc`
Method: `PI_TEMPERATURE` env var → `agent.js createLoopConfig()` → API

Files (4 source + 21 YAML):
- `pi-agent-core/dist/agent.js`
- `pi-subagents/src/agents/agents.ts`
- `pi-subagents/src/runs/shared/pi-args.ts`
- `pi-subagents/src/runs/foreground/execution.ts`
- `~/.pi/agent/agents/*.md` (21 agents, temperature 0.1–0.7)

### 2. Autocomplete (2026-06-05)
Fixes dropdown disappearing when user types exact completion text.

Files:
- `@earendil-works/pi-tui/dist/components/editor.js`
  - `updateAutocomplete()`: force state no longer persists from Tab to typing
  - `getBestAutocompleteMatchIndex()`: slash command prefix matching (`/subagent` ↔ `subagent`)
  - `runAutocompleteRequest()`: auto-accepts single exact-match items

### 3. Context Bar Lag (2026-06-05)
Fixes status bar showing `0%/0` for providers without contextWindow metadata.

Files:
- `@earendil-works/pi-coding-agent/dist/core/agent-session.js`
  - `getContextUsage()`: returns token estimate even when contextWindow is 0
- `@earendil-works/pi-coding-agent/dist/modes/interactive/components/footer.js`
  - `render()`: shows `~N tokens` instead of `?/0` when contextWindow unknown

### 4. pi-ui Theme (2026-06-05)
- `@rokiy/pi-ui/dist/ui.js` → `pi-ui-ui.ts.patched`

## Reapply manually
```bash
bash ~/.pi/patches/reapply.sh
```
