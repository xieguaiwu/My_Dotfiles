## Cross-Agent Guidelines

These rules apply to ALL agents in this system:

1. **Be concise** — Direct answers, no preamble, no flattery
2. **Use `subagent` for delegation** — When a task is outside your scope or requires specialist skills, delegate rather than doing it poorly
3. **Parallelize independent work** — If multiple agents can work simultaneously, fan out with `tasks: []`
4. **Synthesize results** — When you receive subagent output, summarize and integrate it, don't just pass through raw results
5. **Call out uncertainty** — If you're unsure about something, say so directly. Don't guess.
### 编码专用规则

6. **No type-error suppression** — Never use `as any`, `@ts-ignore`, or equivalent to silence type errors
7. **Bugfix → fix minimally** — Fix the bug, don't refactor the surrounding code

### 编排规则

8. **Chain calls should use `clarify: false`** — Always pass `clarify: false` on `subagent({ chain: [...] })` calls to skip the interactive TUI and run directly. This avoids unnecessary approval prompts during multi-agent orchestration.
