#!/usr/bin/env python3
"""Switch pi-agent subagent model routing between DeepSeek peak / off-peak modes.

Peak hours (CN workdays): 09:00-12:00, 14:00-18:00 — same DefaultSchedule as belater.
Why: DeepSeek API prices double during peak; pi has no time-based routing
(fallbackModels only triggers on provider failures). Agent frontmatter is
re-read from disk on every subagent launch, so rewriting files takes effect
immediately without restarting pi.

Peak semantics since 2026-08-30 (read peak-routing.json _comment too):
  * The primary model is DeepSeek official (deepseek/deepseek-v4-pro) in BOTH
    modes. Subagents no longer run qwen-authored models.
  * Peak mode only reorders fallbackModels: subscription-billed DeepSeek routes
    (qwen/deepseek-v4-pro-0813 on the Bailian Token Plan, opencode-go/deepseek-v4-pro)
    move ahead of off-family models such as opencode-go/glm-5.3. So when the
    official route fails or is limited at peak, the child degrades to a
    same-family route that is already paid for.
  * This does NOT avoid peak double pricing for the primary route — it only
    changes where degradations land. Do not "optimise" it by swapping models:
    keep the routing table and this docstring in sync with peak-routing.json.

Usage:
  peak-switch.py on        -> apply peak routing (workday 09:00 / 14:00 cron)
  peak-switch.py off       -> restore off-peak routing (workday 12:00 / 18:00 cron)
  peak-switch.py status    -> show current mode + routed agents
  peak-switch.py on --force / off --force -> bypass state-file idempotency (testing)

Safety:
  * Before switching, validates every routed agent's current frontmatter equals
    the OTHER mode's mapping — refuses to clobber manual edits.
  * Atomic writes (tmp + os.replace), one file at a time.
  * State file ~/.cache/pi-peak-mode makes repeated cron runs no-ops.
"""
import datetime
import json
import os
import sys

DIR = os.path.expanduser("~/.pi/agent")
AGENTS_DIR = os.path.join(DIR, "agents")
ROUTING = os.path.join(DIR, "peak-routing.json")
STATE = os.path.expanduser("~/.cache/pi-peak-mode")
LOG = os.path.expanduser("~/.cache/peak-switch.log")


def log(msg: str) -> None:
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        with open(LOG, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass


def read_lines(path: str) -> list[str]:
    with open(path, encoding="utf-8") as f:
        return f.read().splitlines()


def write_lines(path: str, lines: list[str]) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, path)


def field_pos(lines: list[str], field: str):
    """Return (index, value) of first `field:` line in frontmatter, or (None, None)."""
    for i, ln in enumerate(lines):
        if ln.startswith(field + ":"):
            return i, ln[len(field) + 1:].strip()
    return None, None


def current_mode() -> str:
    try:
        return open(STATE).read().strip()
    except OSError:
        return "offpeak"


def apply_mode(mode: str, force: bool) -> int:
    if not force and current_mode() == mode:
        log(f"no-op: already {mode}")
        return 0
    routing = json.load(open(ROUTING, encoding="utf-8"))
    mapping = routing.get(mode, {})
    other = "offpeak" if mode == "peak" else "peak"
    if not mapping:
        log(f"ERROR: routing has no '{mode}' section")
        return 1

    # Phase 1: validate ALL agents against the other-mode mapping before any write.
    # (Two-pass closes the partial-application gap: a failure at agent N must not
    # leave agents 1..N-1 rewritten while the state file stays untouched.)
    plan: list[tuple[str, list[str]]] = []
    for name, cfg in sorted(mapping.items()):
        path = os.path.join(AGENTS_DIR, name + ".md")
        if not os.path.exists(path):
            log(f"ERROR: {path} missing")
            return 1
        expected = routing[other].get(name)
        if expected is None:
            log(f"ERROR: {name} has no '{other}' mapping in {ROUTING}")
            return 1

        lines = read_lines(path)
        mi, mv = field_pos(lines, "model")
        if mi is None:
            log(f"ERROR: {name} has no 'model:' line")
            return 1
        if mv != expected["model"]:
            log(f"ERROR: {name} current model '{mv}' != {other} '{expected['model']}' (manual edit?) — refusing")
            return 1
        fi, fv = field_pos(lines, "fallbackModels")
        exp_fb = expected.get("fallbackModels") or ""
        cur_fb = fv if fi is not None else ""
        if cur_fb != exp_fb:
            log(f"ERROR: {name} fallbackModels '{cur_fb}' != {other} '{exp_fb}' (manual edit?) — refusing")
            return 1

        new_model = cfg["model"]
        new_fb = cfg.get("fallbackModels")
        # Touch fallbackModels first (indices shift), then model (always before it).
        if new_fb:
            if fi is not None:
                lines[fi] = f"fallbackModels: {new_fb}"
            else:
                lines.insert(mi + 1, f"fallbackModels: {new_fb}")
        else:
            if fi is not None:
                del lines[fi]
        lines[mi] = f"model: {new_model}"
        plan.append((name, lines))

    # Phase 2: write everything.
    changed: list[str] = []
    for name, lines in plan:
        write_lines(os.path.join(AGENTS_DIR, name + ".md"), lines)
        changed.append(name)

    with open(STATE, "w") as f:
        f.write(mode + "\n")
    log(f"switched {mode}: {', '.join(changed)}")
    return 0


def status() -> int:
    mode = current_mode()
    print(f"mode: {mode}")
    routing = json.load(open(ROUTING, encoding="utf-8"))
    for name, cfg in sorted(routing.get(mode, {}).items()):
        path = os.path.join(AGENTS_DIR, name + ".md")
        lines = read_lines(path)
        _, mv = field_pos(lines, "model")
        _, fv = field_pos(lines, "fallbackModels")
        fb = fv or "(none)"
        print(f"  {name}: model={mv} fallback=[{fb}]")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    cmd = args[0] if args else "status"
    force = "--force" in args
    if cmd == "on":
        sys.exit(apply_mode("peak", force))
    elif cmd == "off":
        sys.exit(apply_mode("offpeak", force))
    elif cmd == "status":
        sys.exit(status())
    else:
        print(__doc__)
        sys.exit(2)
