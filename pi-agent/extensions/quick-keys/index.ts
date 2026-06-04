/**
 * quick-keys — opencode 风格快捷键扩展
 *
 * Alt+T → 循环切换思考模式 (off → medium → max → off → ...)
 * /think → 手动设置思考级别
 *
 * 完全遵循 opencode 键位体系 + pi ExtensionAPI。
 */

import type { ExtensionAPI, ThinkingLevel } from "@mariozechner/pi-coding-agent";

const THINKING_CYCLE: ThinkingLevel[] = ["off", "medium", "high"];

const LEVEL_LABELS: Record<string, string> = {
  off: "OFF",
  medium: "medium",
  high: "max",
  xhigh: "max",
  low: "low (unsupported on DeepSeek)",
  minimal: "minimal (unsupported on DeepSeek)",
};

function nextThinking(current: ThinkingLevel): ThinkingLevel {
  const idx = THINKING_CYCLE.indexOf(current);
  // xhigh / low / minimal 等不在循环中的值 → 从 medium 开始
  if (idx === -1) return THINKING_CYCLE[1]; // medium
  // 到达 high(max) 后 → 回到 off 而不是跳过
  if (idx >= THINKING_CYCLE.length - 1) return THINKING_CYCLE[0];
  return THINKING_CYCLE[idx + 1];
}

export default function (pi: ExtensionAPI) {
  // ── Alt+T: 循环切换思考模式（ctrl+t 被 pi 内置占用）──

  pi.registerShortcut("alt+t", {
    description: "Toggle thinking level: off → medium → max → off",
    handler: async (ctx) => {
      const current = pi.getThinkingLevel?.() ?? "off";
      const next = nextThinking(current);
      pi.setThinkingLevel?.(next);
      ctx.ui.notify(`💭 Thinking: ${LEVEL_LABELS[next] ?? next}`, "info");
    },
  });

  // ── 斜杠命令：手动切换 ──

  pi.registerCommand("think", {
    description: "Set thinking level: /think off|low|medium|high|xhigh",
    handler: async (args, ctx) => {
      const level = args.trim().toLowerCase();
      const valid: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh"];
      if (!valid.includes(level as ThinkingLevel)) {
        ctx.ui.notify(`Usage: /think ${valid.join("|")}`, "warning");
        return;
      }
      pi.setThinkingLevel?.(level as ThinkingLevel);
      const label = LEVEL_LABELS[level] ?? level;
      ctx.ui.notify(`💭 Thinking: ${label}`, "info");

      // 对 DeepSeek 不支持的值给出额外警告
      if (level === "low" || level === "minimal") {
        ctx.ui.notify(
          "⚠️ 当前 DeepSeek V4 模型不支持此级别，可能被 clamp 到默认值",
          "warning",
        );
      }
    },
  });
}
