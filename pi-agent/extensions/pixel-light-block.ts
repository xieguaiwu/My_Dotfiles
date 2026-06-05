import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { visibleWidth, truncateToWidth } from "@earendil-works/pi-tui";
import fs from "node:fs";
import path from "node:path";

export default function (pi: ExtensionAPI) {
  let ctx: ExtensionContext | undefined;
  let tuiRef: any; // stored from widget callback to request re-renders

  pi.on("session_start", async (_event, context) => {
    ctx = context;
    setupSidebarWidget(context, pi);
  });

  // Trigger widget re-render on relevant events
  pi.on("agent_start", async () => tuiRef?.requestRender());
  pi.on("agent_end", async () => tuiRef?.requestRender());
  pi.on("message_update", async () => tuiRef?.requestRender());
  pi.on("thinking_level_select", async () => tuiRef?.requestRender());
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

function getThinkingLevel(pi: ExtensionAPI): string {
  return (pi as any).getThinkingLevel?.() || "—";
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

// ── Sidebar widget ───────────────────────────────────────────────

function setupSidebarWidget(ctx: ExtensionContext, pi: ExtensionAPI) {
  const placement = "belowEditor";

  ctx.ui.setWidget("pixel-sidebar", (tui: any, theme: any) => {
    tuiRef = tui;
    return {
      render: (width: number) => renderSidebar(width, ctx, theme, pi),
      invalidate: () => {},
    };
  }, { placement } as any);
}

function renderSidebar(width: number, ctx: ExtensionContext, theme: any, pi: ExtensionAPI): string[] {
  const usage = collectUsage(ctx);
  const pct = getContextPct(ctx);
  const model = getModelLabel(ctx);
  const thinkLv = getThinkingLevel(pi);
  const branch = getGitBranch(ctx.cwd || ".");

  // ── Context bar ──
  const barW = Math.max(4, Math.min(16, width - 55));
  const filled = Math.round((pct / 100) * barW);
  const barStr = theme.fg(pct > 90 ? "error" : pct > 70 ? "warning" : "success",
    "█".repeat(filled)) +
    theme.fg("dim", "░".repeat(Math.max(0, barW - filled)));

  // ── Build content lines (flex layout, shrink to fit) ──
  const sep = theme.fg("dim", " │ ");

  const sections = [
    { label: "Model", value: model, minW: 15 },
    { label: "Ctx", value: barStr + " " + theme.fg("muted", `${Math.round(pct)}%`), minW: 10 },
    { label: "Tokens", value: theme.fg("muted", `↑${fmtTokens(usage.input)} ↓${fmtTokens(usage.output)}`), minW: 12 },
    { label: "Cost", value: theme.fg("muted", usage.cost > 0 ? `$${usage.cost.toFixed(4)}` : "—"), minW: 8 },
    { label: "Git", value: theme.fg("muted", branch || "—"), minW: 8 },
  ];

  // Measure available width for widget
  const usableW = Math.max(20, width - 4);

  // Try full layout first, then drop least-important sections
  const buildLine = (items: typeof sections) => {
    const parts = items.flatMap((s, i) => [
      theme.fg("accent", s.label),
      theme.fg("dim", " "),
      s.value,
      i < items.length - 1 ? sep : "",
    ]);
    const line = parts.join("");
    return visibleWidth(line) <= usableW ? line : null;
  };

  let line1 = buildLine(sections);
  if (!line1) line1 = buildLine(sections.filter((_, i) => i !== 3)); // drop cost
  if (!line1) line1 = buildLine(sections.filter((_, i) => i !== 3 && i !== 4)); // drop cost + git
  if (!line1) {
    // Minimum: model + ctx
    const min = sections.slice(0, 2).flatMap((s, i) => [
      theme.fg("accent", s.label), theme.fg("dim", " "), s.value,
      i < 1 ? sep : "",
    ]).join("");
    line1 = visibleWidth(min) <= usableW ? min : truncateToWidth(min, usableW);
  }

  // ── Build panel ──
  const contentW = visibleWidth(line1);
  const padW = Math.max(1, usableW - contentW);

  const topBorder = theme.fg("borderMuted", "╭─") +
    theme.fg("accent", " ◆ ") +
    theme.fg("borderMuted", "─".repeat(Math.max(1, contentW + padW - 6))) +
    theme.fg("borderMuted", "╮");

  const botBorder = theme.fg("borderMuted", "╰") +
    theme.fg("dim", "─".repeat(Math.max(1, contentW + padW - 2))) +
    theme.fg("borderMuted", "╯");

  return [
    topBorder,
    theme.fg("dim", " ") + line1 + " ".repeat(padW),
    botBorder,
  ].map((l) => truncateToWidth(l, width));
}
