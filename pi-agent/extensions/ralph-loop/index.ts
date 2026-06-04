/**
 * ralph-loop — Ralph Wiggum 持续迭代循环 for pi-agent
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

interface RalphState {
  active: boolean;
  prompt: string;
  completionPromise: string | null;
  iterations: number;
  maxIterations: number;
  ultrawork: boolean;
  startedAt: string;
  lastAssistantText: string;
}

// ─── Constants ────────────────────────────────────────────────────

const STATE_DIR = () => process.env.PI_RALPH_DIR || path.join(os.homedir(), ".pi", "agent", "ralph");
const STATE_FILE = "ralph-state.json";

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

// ─── Loop: Turn End Hook ──────────────────────────────────────────

/** 检查最近一条 user 消息是否由 ralph-loop 触发 */
function wasLastUserMessageFromRalph(branch: readonly any[]): boolean {
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type === "message" && entry.message?.role === "user") {
      const content = entry.message.content;
      const text = Array.isArray(content)
        ? content.filter((p: any) => p.type === "text").map((p: any) => p.text).join("\n")
        : typeof content === "string" ? content : "";
      return text.startsWith("[Ralph loop iteration");
    }
  }
  return false;
}

function setupLoopHook(pi: ExtensionAPI): void {
  // 在 turn_end 检查是否需要继续循环
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

    // 获取最近一次 assistant 消息内容
    let assistantText = "";
    try {
      const branch = ctx.sessionManager.getBranch();
      for (let i = branch.length - 1; i >= 0; i--) {
        const entry = branch[i];
        if (entry.type === "message" && entry.message.role === "assistant") {
          const content = entry.message.content;
          if (Array.isArray(content)) {
            assistantText = content
              .filter((p: any) => p.type === "text")
              .map((p: any) => p.text)
              .join("\n");
          } else if (typeof content === "string") {
            assistantText = content;
          }
          break;
        }
      }
    } catch { /* 静默失败，继续循环 */ }

    // 检查是否完成了
    if (assistantText && checkCompletion(assistantText, state.completionPromise)) {
      clearState();
      ctx.ui.notify("🎯 Ralph loop: task completed!", "info");
      return;
    }

    // 检查迭代次数上限
    if (state.maxIterations > 0 && state.iterations >= state.maxIterations) {
      clearState();
      ctx.ui.notify(`⏹ Ralph loop: max iterations (${state.maxIterations}) reached`, "warning");
      return;
    }

    // 继续循环
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
      {
        customType: "ralph_loop",
        content: continuationPrompt,
        display: false,
      },
      { triggerTurn: true },
    );
  });
}

// ─── Extension Entry ──────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // 注册循环钩子
  setupLoopHook(pi);

  // ── /ralph-loop ──

  pi.registerCommand("ralph-loop", {
    description: "Start a Ralph loop: auto-continues until completion promise",
    handler: async (args, ctx) => {
      if (!args.trim()) {
        ctx.ui.notify("Usage: /ralph-loop <task> --promise \"DONE\" --max 25", "warning");
        return;
      }

      const { prompt, promise, max } = parseArgs(args);
      const state: RalphState = {
        active: true,
        prompt,
        completionPromise: promise,
        iterations: 0,
        maxIterations: max,
        ultrawork: false,
        startedAt: new Date().toISOString(),
        lastAssistantText: "",
      };
      saveState(state);

      const promiseNote = promise ? `promise: "${promise}"` : "no completion promise";
      ctx.ui.notify(
        `🔄 Ralph loop started (max ${max}, ${promiseNote})`,
        "info",
      );

      // 触发第一轮 — 检查 wasLastUserMessageFromRalph
      const firstPrompt = `[Ralph loop iteration 1/${max}]
Complete the following task:
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}

Task: ${prompt}`;

      pi.sendMessage(
        {
          customType: "ralph_loop",
          content: firstPrompt,
          display: false,
        },
        { triggerTurn: true },
      );
    },
  });

  // ── /ulw-loop ──

  pi.registerCommand("ulw-loop", {
    description: "Start a Ralph loop with ULTRAWORK mode (higher quality, slower)",
    handler: async (args, ctx) => {
      if (!args.trim()) {
        ctx.ui.notify("Usage: /ulw-loop <task> --promise \"DONE\" --max 25", "warning");
        return;
      }

      const { prompt, promise, max } = parseArgs(args);
      const state: RalphState = {
        active: true,
        prompt,
        completionPromise: promise,
        iterations: 0,
        maxIterations: max,
        ultrawork: true,
        startedAt: new Date().toISOString(),
        lastAssistantText: "",
      };
      saveState(state);

      const promiseNote = promise ? `promise: "${promise}"` : "no completion promise";
      ctx.ui.notify(
        `⚡ ULW loop started (ultrawork, max ${max}, ${promiseNote})`,
        "info",
      );

      const firstPrompt = `[Ralph loop iteration 1/${max}] [ULTRAWORK]

${ULTRWORK_SYSTEM_PROMPT}

Task: ${prompt}
${state.completionPromise ? `\nWhen COMPLETELY done, output: <promise>${state.completionPromise}</promise>` : ""}`;

      pi.sendMessage(
        {
          customType: "ralph_loop",
          content: firstPrompt,
          display: false,
        },
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
      ctx.ui.notify(
        `🔄 Ralph ${mode}: ${state.iterations}/${state.maxIterations} iterations, ${elapsed}s elapsed`,
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
        `⏹ Ralph loop cancelled after ${state.iterations} iterations`,
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
      ctx.ui.notify(
        `${mode} ${state.iterations}/${state.maxIterations} iterations | promise: ${state.completionPromise ?? "none"}`,
        "info",
      );
    },
  });
}
