import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import fs from "node:fs";
import path from "node:path";

export default function (pi: ExtensionAPI) {
  let ctx: ExtensionContext | undefined;

  // ── Push sidebar on any data change ──
  const refresh = () => { if (ctx) pushSidebar(ctx, pi); };

  pi.on("session_start", async (_event, context) => {
    ctx = context;
    refresh();
  });
  pi.on("session_shutdown", async () => {
    ctx?.ui.setWidget("pixel-sidebar", undefined);
    ctx = undefined;
  });

  // Refresh on relevant events
  pi.on("agent_start", refresh);
  pi.on("agent_end", refresh);
  pi.on("thinking_level_select", refresh);
  pi.on("model_select", refresh);
}

// ── Helpers ──────────────────────────────────────────────────────

function collectUsage(ctx: ExtensionContext) {
  let input = 0, output = 0, cost = 0;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const usage = (entry.message as AssistantMessage).usage;
    if (!usage) continue;
    input += usage.input || 0;
    output += usage.output || 0;
    cost += usage.cost?.total || 0;
  }
  return { input, output, cost };
}

function fmtTokens(n: number): string {
  if (n < 1_000) return `${n}`;
  if (n < 10_000) return `${(n / 1_000).toFixed(1)}k`;
  return `${Math.round(n / 1_000)}k`;
}

function getGitBranch(cwd: string): string | null {
  try {
    const head = fs.readFileSync(path.join(cwd, ".git", "HEAD"), "utf8").trim();
    const m = head.match(/^ref: refs\/heads\/(.+)$/);
    return m ? m[1] : null;
  } catch {
    return null;
  }
}

function getModelLabel(ctx: ExtensionContext): string {
  if (!ctx.model) return "—";
  return [ctx.model.provider, ctx.model.id].filter(Boolean).join("/");
}

function getContextPct(ctx: ExtensionContext): number {
  const info = ctx.getContextUsage?.();
  if (!info) return 0;
  const i = info as any;
  if (typeof info.percent === "number") return info.percent;
  if (typeof i.fraction === "number") return i.fraction * 100;
  if (typeof i.used === "number" && typeof i.limit === "number" && i.limit > 0) return (i.used / i.limit) * 100;
  return 0;
}

// ── Sidebar widget ──────────────────────────────────────────────

function pushSidebar(ctx: ExtensionContext, pi: ExtensionAPI) {
  const usage = collectUsage(ctx);
  const pct = getContextPct(ctx);
  const model = getModelLabel(ctx);
  const thinkLv = pi.getThinkingLevel() || "—";
  const branch = getGitBranch(ctx.cwd || ".");
  const t = ctx.ui.theme;

  // ── Context bar with vibrant coloring ──
  const barW = 8;
  const filled = Math.round((pct / 100) * barW);
  // Brighter: full block + warning/error threshold highlights
  const ctxTone = pct > 90 ? "error" : pct > 70 ? "warning" : "cyan";
  const bar = t.fg(ctxTone, "█".repeat(filled)) +
    t.fg("dim", "░".repeat(Math.max(0, barW - filled)));
  const ctxPct = pct > 90
    ? t.fg("error", ` ${Math.round(pct)}%`)
    : pct > 70
      ? t.fg("warning", ` ${Math.round(pct)}%`)
      : t.fg("muted", ` ${Math.round(pct)}%`);

  // ── Thinking level with vibrant color ──
  const thinkDisplay = thinkLv === "xhigh"
    ? t.fg("accent", thinkLv)     // purple for max thinking
    : thinkLv === "high"
      ? t.fg("cyan", thinkLv)      // cyan for high
      : t.fg("muted", thinkLv);    // muted for others

  // ── Token usage ──
  const tokens = `↑${fmtTokens(usage.input)} ↓${fmtTokens(usage.output)}`;

  // ── Cost ──
  const costStr = usage.cost > 0 ? t.fg("warning", `$${usage.cost.toFixed(4)}`) : t.fg("muted", "—");

  // ── Build rows ──
  const row1 = [
    t.fg("accent", " Model"),
    t.fg("dim", " "), t.fg("text", model),
    t.fg("dim", "  │"),
    t.fg("accent", " Think"),
    t.fg("dim", " "), thinkDisplay,
  ].join("");

  const row2 = [
    t.fg("accent", " Ctx"),
    t.fg("dim", " "), bar,
    ctxPct,
    t.fg("dim", "  │"),
    t.fg("accent", " Tokens"),
    t.fg("dim", " "), t.fg("muted", tokens),
  ].join("");

  const row3 = [
    t.fg("accent", " Cost"),
    t.fg("dim", " "), costStr,
    t.fg("dim", "  │"),
    t.fg("accent", " Git"),
    t.fg("dim", " "), t.fg("muted", branch || "—"),
  ].join("");

  ctx.ui.setWidget("pixel-sidebar", [row1, row2, row3]);
}
