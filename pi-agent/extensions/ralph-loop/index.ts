/**
 * ralph-loop — Ralph Wiggum 持续迭代循环 for pi-agent
 *
 * v2.0 — Added oracle review gate: when agent claims completion, loop
 *         automatically routes through `oracle` subagent for verification.
 *         Only passes if oracle outputs <verdict>PASS</verdict>.
 *
 * 移植自 opencode 生态的 ralph-loop / ulw-loop。
 *
 * 核心概念：一次任务，持续循环直到完成。
 * 每次 assistant 回复结束后，如果没输出 completion promise，
 * 就把相同的 prompt 重新喂回去，让 agent 看到之前的输出和文件状态后继续改进。
 *
 * 命令：
 *   /ralph-loop <prompt> --promise <text> --max <N>  — 启动循环
 *   /ulw-loop  <prompt> --promise <text> --max <N>  — 启动循环 + ultrawork 模式
 *   /ralph-status     — 查看当前循环状态
 *   /cancel-ralph     — 取消循环
 *
 * 快捷键：
 *   Alt+R → 显示状态
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

// ─── Types ────────────────────────────────────────────────────────

type RalphPhase = "work" | "review";

interface RalphState {
  active: boolean;
  prompt: string;
  completionPromise: string | null;
  iterations: number;
  maxIterations: number;
  ultrawork: boolean;
  startedAt: string;
  lastAssistantText: string;
  /** @since 2.0 — 循环阶段: work=正常工作, review=等待oracle审查 */
  phase: RalphPhase;
  /** @since 2.0 — oracle 反馈的原始文本 */
  oracleFeedback: string;
  /** @since 2.0 — 当前审查尝试次数 */
  reviewAttempt: number;
}

// ─── Constants ────────────────────────────────────────────────────

const STATE_DIR = () => process.env.PI_RALPH_DIR || path.join(os.homedir(), ".pi", "agent", "ralph");
const STATE_FILE = "ralph-state.json";

const MAX_REVIEW_ATTEMPTS = 3;

const ULTRWORK_SYSTEM_PROMPT = `You are in ULTRAWORK mode. This means:

1. **Quality first** — Write production-quality code. No shortcuts, no stubs.
2. **Self-review** — After each change, verify it works. Run tests, check types.
3. **Exhaustive** — Handle edge cases, errors, and state properly.
4. **Document** — Add comments for non-obvious logic.
5. **Persist** — If something fails, read the error and fix it. Do not give up.
6. **Complete** — Only output the completion promise when the task is TRULY done.`;

// ─── State Management ─────────────────────────────────────────────

function stateFilePath(): string {
  const dir = STATE_DIR();
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, STATE_FILE);
}

function loadState(): RalphState | null {
  try {
    const file = stateFilePath();
    if (!fs.existsSync(file)) return null;
    return JSON.parse(fs.readFileSync(file, "utf-8"));
  } catch { return null; }
}

function saveState(state: RalphState): void {
  fs.writeFileSync(stateFilePath(), JSON.stringify(state, null, 2), "utf-8");
}

function clearState(): void {
  try { fs.unlinkSync(stateFilePath()); } catch { /* ignore */ }
}

// ─── Core Logic ───────────────────────────────────────────────────

function checkCompletion(text: string, promise: string | null): boolean {
  if (!promise) return false;
  // 支持 <promise>DONE</promise> 和纯文本匹配
  const tagMatch = text.match(/<promise>([\s\S]*?)<\/promise>/);
  if (tagMatch) return tagMatch[1].trim() === promise;
  return text.includes(promise);
}

function checkVerdict(text: string): "pass" | "fail" | null {
  const match = text.match(/<verdict>(\w+)<\/verdict>/);
  if (!match) return null;
  return match[1].toUpperCase() === "PASS" ? "pass" : "fail";
}

function parseArgs(args: string): { prompt: string; promise: string | null; max: number } {
  let prompt = args.trim();
  let promise: string | null = null;
  let max = 25;

  // 解析 --promise 参数
  const promiseMatch = prompt.match(/--promise\s+"([^"]+)"|--promise\s+'([^']+)'|--promise\s+(\S+)/);
  if (promiseMatch) {
    promise = promiseMatch[1] || promiseMatch[2] || promiseMatch[3];
    prompt = prompt.replace(/--promise\s+"[^"]+"|--promise\s+'[^']+'|--promise\s+\S+/, "").trim();
  }

  // 解析 --max 参数
  const maxMatch = prompt.match(/--max\s+(\d+)/);
  if (maxMatch) {
    max = parseInt(maxMatch[1], 10);
    prompt = prompt.replace(/--max\s+\d+/, "").trim();
  }

  return { prompt, promise, max };
}

// ─── Helper: Extract Latest Assistant Text ────────────────────────

function getLatestAssistantText(ctx: ExtensionContext): string {
  try {
    const branch = ctx.sessionManager.getBranch();
    for (let i = branch.length - 1; i >= 0; i--) {
      const entry = branch[i];
      if (entry.type === "message" && entry.message.role === "assistant") {
        const content = entry.message.content;
        if (Array.isArray(content)) {
          return content
            .filter((p: any) => p.type === "text")
            .map((p: any) => p.text)
            .join("\n");
        } else if (typeof content === "string") {
          return content;
        }
        return "";
      }
    }
  } catch { /* silent */ }
  return "";
}

// ─── Helper: Check if Last User Message is Ralph-Originated ───────

const RALPH_MESSAGE_PREFIXES = [
  "[Ralph loop iteration",
  "[Ralph oracle review",
  "[Ralph fix iteration",
];

function wasLastUserMessageFromRalph(branch: readonly any[]): boolean {
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type === "message" && entry.message?.role === "user") {
      const content = entry.message.content;
      const text = Array.isArray(content)
        ? content.filter((p: any) => p.type === "text").map((p: any) => p.text).join("\n")
        : typeof content === "string" ? content : "";
      return RALPH_MESSAGE_PREFIXES.some((prefix) => text.trim().startsWith(prefix));
    }
  }
  return false;
}

// ─── Loop: Turn End Hook ──────────────────────────────────────────

function setupLoopHook(pi: ExtensionAPI): void {
  pi.on("turn_end", (_event, ctx) => {
    const state = loadState();
    if (!state || !state.active) return;

    // 只有 ralph 自己触发的轮次才自动继续（避免劫持用户手动输入）
    if (state.iterations > 0) {
      try {
        const branch = ctx.sessionManager.getBranch();
        if (!wasLastUserMessageFromRalph(branch)) return;
      } catch { return; }
    }

    const assistantText = getLatestAssistantText(ctx);

    // ── Phase: REVIEW — oracle 审查阶段 ──
    if (state.phase === "review") {
      const verdict = checkVerdict(assistantText);

      if (verdict === "pass") {
        // Oracle 核准 → 任务完成
        clearState();
        ctx.ui.notify("🎯 Ralph loop: oracle verified — task completed!", "info");
        return;
      }

      if (verdict === "fail") {
        // Oracle 发现问题 → 回到 work 阶段，附带 oracle 反馈
        state.phase = "work";
        state.oracleFeedback = assistantText.slice(0, 3000);
        state.iterations++;
        state.lastAssistantText = assistantText.slice(0, 500);
        saveState(state);

        const ultraworkNote = state.ultrawork ? " [ULTRAWORK]" : "";
        const fixPrompt = `[Ralph fix iteration ${state.iterations}/${state.maxIterations}${ultraworkNote}]
${state.ultrawork ? "\n--- ULTRAWORK MODE ---\nProduce the highest quality output. Verify your work.\n---\n" : ""}

Oracle review found issues that need fixing. Continue working on the task.

=== Oracle Review Feedback ===
${state.oracleFeedback}
=== End Oracle Feedback ===

Fix all issues above, then re-run oracle verification.
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}

Task: ${state.prompt}`;

        pi.sendMessage(
          { customType: "ralph_loop", content: fixPrompt, display: false },
          { triggerTurn: true },
        );
        return;
      }

      // 既无 PASS 也无 FAIL — agent 可能还没调用 oracle
      if (state.reviewAttempt >= MAX_REVIEW_ATTEMPTS) {
        clearState();
        ctx.ui.notify(`⏹ Ralph loop: oracle unreachable after ${MAX_REVIEW_ATTEMPTS} attempts`, "warning");
        return;
      }

      state.reviewAttempt++;
      saveState(state);

      const retryPrompt = `[Ralph oracle review ${state.reviewAttempt}/${MAX_REVIEW_ATTEMPTS}]

The task claims completion but needs independent verification via oracle.

You MUST call the following, then relay oracle's exact <verdict> and full response:

\`\`\`
subagent { agent: "oracle", task: "Verify all work done in the conversation above. Check correctness, completeness, edge cases, and quality. Output <verdict>PASS</verdict> only if everything is truly correct and complete. Output <verdict>FAIL</verdict> with specific issues that need fixing (include file paths and line numbers where relevant)." }
\`\`\``;

      pi.sendMessage(
        { customType: "ralph_loop", content: retryPrompt, display: false },
        { triggerTurn: true },
      );
      return;
    }

    // ── Phase: WORK — 正常工作阶段 ──

    // 检查 agent 是否声称完成
    if (assistantText && checkCompletion(assistantText, state.completionPromise)) {
      // 不立即停止，切换到审查阶段
      state.phase = "review";
      state.reviewAttempt = 0;
      state.oracleFeedback = "";
      saveState(state);

      const reviewPrompt = `[Ralph oracle review 1/${MAX_REVIEW_ATTEMPTS}]

You claim the task is complete. Before the loop accepts this, independently verify with oracle:

\`\`\`
subagent { agent: "oracle", task: "Verify all work done in the conversation above. Check correctness, completeness, edge cases, and quality. Output <verdict>PASS</verdict> only if everything is truly correct and complete. Output <verdict>FAIL</verdict> with specific issues that need fixing (include file paths and line numbers where relevant)." }
\`\`\`

Then relay oracle's exact <verdict> and full response here.`;

      pi.sendMessage(
        { customType: "ralph_loop", content: reviewPrompt, display: false },
        { triggerTurn: true },
      );
      return;
    }

    // 检查迭代次数上限
    if (state.maxIterations > 0 && state.iterations >= state.maxIterations) {
      clearState();
      ctx.ui.notify(`⏹ Ralph loop: max iterations (${state.maxIterations}) reached`, "warning");
      return;
    }

    // 继续工作
    state.iterations++;
    state.lastAssistantText = assistantText.slice(0, 500);
    saveState(state);

    const ultraworkNote = state.ultrawork ? " [ULTRAWORK]" : "";
    const continuationPrompt = `[Ralph loop iteration ${state.iterations}/${state.maxIterations}${ultraworkNote}]
${state.ultrawork ? "\n--- ULTRAWORK MODE ---\nProduce the highest quality output. Verify your work.\n---\n" : ""}

Continue the task. Previous output is above.
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}

Task: ${state.prompt}`;

    pi.sendMessage(
      { customType: "ralph_loop", content: continuationPrompt, display: false },
      { triggerTurn: true },
    );
  });
}

// ─── State Factory ────────────────────────────────────────────────

function makeState(
  prompt: string,
  promise: string | null,
  max: number,
  ultrawork: boolean,
): RalphState {
  return {
    active: true,
    prompt,
    completionPromise: promise,
    iterations: 0,
    maxIterations: max,
    ultrawork,
    startedAt: new Date().toISOString(),
    lastAssistantText: "",
    phase: "work",
    oracleFeedback: "",
    reviewAttempt: 0,
  };
}

// ─── Extension Entry ──────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  setupLoopHook(pi);

  // ── /ralph-loop ──

  pi.registerCommand("ralph-loop", {
    description: "Start a Ralph loop: auto-continues until completion promise (with oracle gate)",
    handler: async (args, ctx) => {
      if (!args.trim()) {
        ctx.ui.notify("Usage: /ralph-loop <task> --promise \"DONE\" --max 25", "warning");
        return;
      }

      const { prompt, promise, max } = parseArgs(args);
      const state = makeState(prompt, promise, max, false);
      saveState(state);

      const promiseNote = promise ? `promise: "${promise}"` : "no completion promise";
      ctx.ui.notify(
        `🔄 Ralph loop started (max ${max}, ${promiseNote})`,
        "info",
      );

      const firstPrompt = `[Ralph loop iteration 1/${max}]
Complete the following task:
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}

Task: ${prompt}`;

      pi.sendMessage(
        { customType: "ralph_loop", content: firstPrompt, display: false },
        { triggerTurn: true },
      );
    },
  });

  // ── /ulw-loop ──

  pi.registerCommand("ulw-loop", {
    description: "Start a ULW loop: ultrawork mode with oracle verification gate",
    handler: async (args, ctx) => {
      if (!args.trim()) {
        ctx.ui.notify("Usage: /ulw-loop <task> --promise \"DONE\" --max 25", "warning");
        return;
      }

      const { prompt, promise, max } = parseArgs(args);
      const state = makeState(prompt, promise, max, true);
      saveState(state);

      const promiseNote = promise ? `promise: "${promise}"` : "no completion promise";
      ctx.ui.notify(
        `⚡ ULW loop started (ultrawork, max ${max}, ${promiseNote}, oracle gate enabled)`,
        "info",
      );

      const firstPrompt = `[Ralph loop iteration 1/${max}] [ULTRAWORK]

${ULTRWORK_SYSTEM_PROMPT}

Task: ${prompt}
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}`;

      pi.sendMessage(
        { customType: "ralph_loop", content: firstPrompt, display: false },
        { triggerTurn: true },
      );
    },
  });

  // ── /ralph-status ──

  pi.registerCommand("ralph-status", {
    description: "Show current Ralph loop status",
    handler: async (_args, ctx) => {
      const state = loadState();
      if (!state || !state.active) {
        ctx.ui.notify("No active Ralph loop", "info");
        return;
      }
      const elapsed = Math.floor((Date.now() - new Date(state.startedAt).getTime()) / 1000);
      const mode = state.ultrawork ? "ULTRAWORK" : "normal";
      const phase = state.phase === "review" ? "🔍oracle-review" : "⚙️work";
      ctx.ui.notify(
        `🔄 Ralph ${mode} [${phase}]: ${state.iterations}/${state.maxIterations} iterations, ${elapsed}s elapsed`,
        "info",
      );
    },
  });

  // ── /cancel-ralph ──

  pi.registerCommand("cancel-ralph", {
    description: "Cancel the active Ralph loop",
    handler: async (_args, ctx) => {
      const state = loadState();
      if (!state?.active) {
        ctx.ui.notify("No active Ralph loop to cancel", "info");
        return;
      }
      clearState();
      ctx.ui.notify(
        `⏹ Ralph loop cancelled after ${state.iterations} iterations (phase: ${state.phase})`,
        "info",
      );
    },
  });

  // ── Alt+R: 查看状态 ──

  pi.registerShortcut("alt+r", {
    description: "Show Ralph loop status",
    handler: async (ctx) => {
      const state = loadState();
      if (!state?.active) {
        ctx.ui.notify("No active Ralph loop", "info");
        return;
      }
      const mode = state.ultrawork ? "⚡ULTRAWORK" : "🔄";
      const phase = state.phase === "review" ? "🔍" : "⚙️";
      ctx.ui.notify(
        `${phase}${mode} ${state.iterations}/${state.maxIterations} | phase: ${state.phase} | promise: ${state.completionPromise ?? "none"}`,
        "info",
      );
    },
  });
}
