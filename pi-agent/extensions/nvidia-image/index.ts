/**
 * nvidia-image — NVIDIA NIM Image Generation Extension
 *
 * 提供图像生成工具，支持两种模式：
 *
 * Mode 1: Self-hosted NIM（默认，需配置 NIM_BASE_URL）
 *   运行 qwen-image / qwen-image-edit / flux.* 等 NIM 容器后使用。
 *   - OpenAI-compatible API: /v1/images/generations
 *   - 安装: docker run ... nvcr.io/nim/qwen/qwen-image:latest -p 8000:8000
 *   - 设置: export NIM_BASE_URL="http://localhost:8000"
 *
 * Mode 2: OpenRouter Cloud（备选，设 OPENROUTER_API_KEY）
 *   通过 pi-agent 内置的 openrouter-images API 使用 Flux / Recraft 等模型。
 *   受限于 pi-agent 框架，image 模型暂不能直接用于聊天，此工具层解决了该问题。
 *
 * 工具：
 *   nvidia_generate_image — 文生图（prompt → image file）
 *   nvidia_edit_image     — 图编辑（image + prompt → edited file，仅自托管 NIM）
 *
 * 前置条件：
 *   模式      | 环境变量           | 必须 | 说明
 *   ---------|-------------------|------|-------------------------------
 *   NIM      | NIM_BASE_URL      |  是  | 自托管 NIM 地址
 *   NIM      | NVIDIA_API_KEY    |  否  | 部分 NIM 需要 API key
 *   OpenRouter| OPENROUTER_API_KEY |  是  | OpenRouter API key
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import * as fs from "node:fs";
import * as path from "node:path";

// ─── Helpers ───────────────────────────────────────────────────────

function resolveNimUrl(): string | null {
  const url = process.env.NIM_BASE_URL;
  return url?.trim() || null;
}

function resolveMode(): "nim" | "openrouter" {
  return resolveNimUrl() ? "nim" : "openrouter";
}

function defaultOutputDir(): string {
  const home = process.env.HOME || process.env.USERPROFILE || "";
  if (home) {
    const dl = path.join(home, "Downloads");
    if (fs.existsSync(dl)) return dl;
  }
  return process.cwd();
}

function makeOutputPath(
  outputDir: string | undefined,
  baseFilename: string | undefined,
  index: number,
): string {
  const dir = outputDir ?? defaultOutputDir();
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const ts = Date.now();
  const base = baseFilename ?? "nvidia_generated";
  return path.join(dir, `${base}_${ts}_${index}.png`);
}

function guessMimeType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case ".png":  return "image/png";
    case ".jpg": case ".jpeg": return "image/jpeg";
    case ".webp": return "image/webp";
    case ".gif":  return "image/gif";
    default:      return "image/png";
  }
}

// ─── NIM (Self-hosted) API ────────────────────────────────────────

async function nimGenerate(
  baseUrl: string, model: string, prompt: string,
  size: string, n: number, apiKey: string | undefined,
): Promise<Buffer[]> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;

  const response = await fetch(`${baseUrl}/v1/images/generations`, {
    method: "POST",
    headers,
    body: JSON.stringify({ model, prompt, n, size, response_format: "b64_json" }),
  });
  if (!response.ok) {
    const err = await response.text().catch(() => "");
    throw new Error(`NIM API ${response.status}: ${err.slice(0, 400)}`);
  }
  const data = (await response.json()) as { data?: Array<{ b64_json?: string }> };
  return (data.data ?? [])
    .filter((img): img is { b64_json: string } => !!img.b64_json)
    .map((img) => Buffer.from(img.b64_json, "base64"));
}

async function nimEdit(
  baseUrl: string, model: string, prompt: string,
  imageBuffer: Buffer, imagePath: string,
  maskBuffer: Buffer | null, maskPath: string | null,
  size: string | undefined, apiKey: string | undefined,
): Promise<Buffer[]> {
  const formData = new FormData();
  formData.append("image", new Blob([imageBuffer], { type: guessMimeType(imagePath) }), path.basename(imagePath));
  formData.append("prompt", prompt);
  formData.append("model", model);
  formData.append("response_format", "b64_json");
  if (size) formData.append("size", size);
  if (maskBuffer && maskPath) {
    formData.append("mask", new Blob([maskBuffer], { type: guessMimeType(maskPath) }), path.basename(maskPath));
  }

  const headers: Record<string, string> = {};
  if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;

  const response = await fetch(`${baseUrl}/v1/images/edits`, { method: "POST", headers, body: formData });
  if (!response.ok) {
    const err = await response.text().catch(() => "");
    throw new Error(`NIM API ${response.status}: ${err.slice(0, 400)}`);
  }
  const data = (await response.json()) as { data?: Array<{ b64_json?: string }> };
  return (data.data ?? [])
    .filter((img): img is { b64_json: string } => !!img.b64_json)
    .map((img) => Buffer.from(img.b64_json, "base64"));
}

// ─── OpenRouter Image API ────────────────────────────────────────

async function openrouterGenerate(
  model: string, prompt: string, apiKey: string,
): Promise<Buffer> {
  const response = await fetch("https://openrouter.ai/api/v1/images/generations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, prompt, response_format: "b64_json" }),
  });
  if (!response.ok) {
    const err = await response.text().catch(() => "");
    throw new Error(`OpenRouter API ${response.status}: ${err.slice(0, 400)}`);
  }
  const data = (await response.json()) as { data?: Array<{ b64_json?: string }> };
  const b64 = data.data?.[0]?.b64_json;
  if (!b64) throw new Error("OpenRouter returned no image data");
  return Buffer.from(b64, "base64");
}

// ─── Extension Entry ──────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // ────────────────────────────────────────────────────────────────
  // Tool 1: nvidia_generate_image
  // ────────────────────────────────────────────────────────────────

  pi.registerTool({
    name: "nvidia_generate_image",
    label: "Generate Image (NVIDIA NIM)",
    description:
      "Generate an image from a text prompt.\n\n" +
      "=== Mode 1: Self-hosted NIM (qwen-image) ===\n" +
      'Set NIM_BASE_URL env var, e.g. NIM_BASE_URL="http://localhost:8000"\n' +
      "Runs qwen-image, flux.* or any NIM with /v1/images/generations.\n" +
      'Model options: "qwen-image" (default), "qwen-image-2512", "flux.1-dev", etc.\n\n' +
      "=== Mode 2: OpenRouter Cloud ===\n" +
      "Set OPENROUTER_API_KEY env var. Uses hosted image models.\n" +
      'Models: "black-forest-labs/flux.2-klein-4b" (default), "black-forest-labs/flux.1-dev",\n' +
      '  "recraft/recraft-v4", "openai/gpt-5-image", etc.\n\n' +
      "Saves the result as PNG and returns the file path.",
    promptSnippet: "Generate images from text prompts",
    promptGuidelines: [
      "Use nvidia_generate_image when the user asks to generate/create/draw an image from a text description.",
      "Use nvidia_edit_image when the user asks to edit/modify an existing image file.",
    ],
    parameters: Type.Object({
      prompt: Type.String({ description: "Text description of the image to generate." }),
      model: Type.Optional(Type.String({
        description: 'NIM: "qwen-image" (default), "qwen-image-2512", "flux.1-dev". OpenRouter: "black-forest-labs/flux.2-klein-4b" (default), "black-forest-labs/flux.1-schnell", "recraft/recraft-v4".',
      })),
      size: Type.Optional(Type.String({
        description: 'Image size. NIM: "1024x1024" (default), "1024x768", etc. OpenRouter: varies by model.',
      })),
      n: Type.Optional(Type.Number({
        description: "Number of images (default: 1, max: 4). Only supported in NIM mode.",
      })),
      output_dir: Type.Optional(Type.String({ description: "Output directory. Default: ~/Downloads." })),
      filename: Type.Optional(Type.String({ description: "Base filename. Default: nvidia_generated." })),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, _ctx) {
      const mode = resolveMode();

      if (mode === "openrouter") {
        const apiKey = process.env.OPENROUTER_API_KEY;
        if (!apiKey) {
          throw new Error(
            "Neither NIM_BASE_URL nor OPENROUTER_API_KEY is set.\n\n" +
            'Option 1 — Self-hosted NIM (qwen-image):\n' +
            '  export NIM_BASE_URL="http://localhost:8000"\n' +
            '  Then run: docker run ... nvcr.io/nim/qwen/qwen-image:latest -p 8000:8000\n\n' +
            'Option 2 — OpenRouter Cloud:\n' +
            '  export OPENROUTER_API_KEY="sk-or-..."\n' +
            "  Uses hosted models like Flux, Recraft, etc.",
          );
        }

        const model = params.model ?? "black-forest-labs/flux.2-klein-4b";

        onUpdate?.({ content: [{ type: "text", text: `🎨 Generating via OpenRouter (${model})…` }] });

        const imageBuffer = await openrouterGenerate(model, params.prompt, apiKey);
        const filePath = makeOutputPath(params.output_dir, params.filename, 0);
        fs.writeFileSync(filePath, imageBuffer);

        return {
          content: [{ type: "text", text: `✅ Image saved to: ${filePath}` }],
          details: { files: [filePath], prompt: params.prompt, model, mode: "openrouter" },
        };
      }

      // ── NIM (self-hosted) mode ──
      const baseUrl = resolveNimUrl()!;
      const model = params.model ?? "qwen-image";
      const size = params.size ?? "1024x1024";
      const n = Math.min(params.n ?? 1, 4);
      const apiKey = process.env.NVIDIA_API_KEY;

      onUpdate?.({ content: [{ type: "text", text: `🎨 Generating via NIM (${baseUrl}, ${model})…` }] });

      const buffers = await nimGenerate(baseUrl, model, params.prompt, size, n, apiKey);
      const savedPaths: string[] = [];
      for (let i = 0; i < buffers.length; i++) {
        const filePath = makeOutputPath(params.output_dir, params.filename, i);
        fs.writeFileSync(filePath, buffers[i]);
        savedPaths.push(filePath);
      }

      const summary = savedPaths.length === 1
        ? `✅ Image saved to: ${savedPaths[0]}`
        : `✅ ${savedPaths.length} images saved:\n${savedPaths.join("\n")}`;

      return {
        content: [{ type: "text", text: summary }],
        details: { files: savedPaths, prompt: params.prompt, model, mode: "nim" },
      };
    },
  });

  // ────────────────────────────────────────────────────────────────
  // Tool 2: nvidia_edit_image
  // ────────────────────────────────────────────────────────────────

  pi.registerTool({
    name: "nvidia_edit_image",
    label: "Edit Image (NVIDIA NIM)",
    description:
      "Edit an existing image. NIM mode only (requires NIM_BASE_URL).\n" +
      "Uses qwen-image-edit NIM container with /v1/images/edits endpoint.\n" +
      "Accepts optional mask image (white=keep, black=edit area).\n" +
      "Saves the result as PNG and returns the file path.",
    promptSnippet: "Edit existing images via NVIDIA NIM",
    promptGuidelines: [
      "Use nvidia_edit_image when the user wants to modify an existing image file.",
      "For generating new images from text, use nvidia_generate_image instead.",
    ],
    parameters: Type.Object({
      prompt: Type.String({ description: "Text instruction describing how to edit the image." }),
      image_path: Type.String({ description: "Path to the existing image file to edit." }),
      mask_path: Type.Optional(Type.String({ description: "Optional mask image (white=keep, black=edit area)." })),
      model: Type.Optional(Type.String({ description: 'Model ID. Default: "qwen-image-edit".' })),
      size: Type.Optional(Type.String({ description: "Output image size." })),
      output_dir: Type.Optional(Type.String({ description: "Output directory. Default: ~/Downloads." })),
      filename: Type.Optional(Type.String({ description: "Base filename. Default: nvidia_edited." })),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, _ctx) {
      const baseUrl = resolveNimUrl();
      if (!baseUrl) {
        throw new Error(
          "Image editing requires a self-hosted NIM.\n\n" +
          'Set NIM_BASE_URL, e.g. NIM_BASE_URL="http://localhost:8000"\n' +
          "Then run: docker run ... nvcr.io/nim/qwen/qwen-image-edit:latest -p 8000:8000",
        );
      }

      const imagePath = path.resolve(params.image_path);
      if (!fs.existsSync(imagePath)) throw new Error(`Image file not found: ${imagePath}`);

      const model = params.model ?? "qwen-image-edit";
      const imageBuffer = fs.readFileSync(imagePath);
      let maskBuffer: Buffer | null = null;
      let maskPath: string | null = null;

      if (params.mask_path) {
        maskPath = path.resolve(params.mask_path);
        if (!fs.existsSync(maskPath)) throw new Error(`Mask file not found: ${maskPath}`);
        maskBuffer = fs.readFileSync(maskPath);
      }

      const apiKey = process.env.NVIDIA_API_KEY;

      onUpdate?.({ content: [{ type: "text", text: `🖼️ Editing via NIM (${baseUrl}, ${model})…` }] });

      const buffers = await nimEdit(
        baseUrl, model, params.prompt, imageBuffer, imagePath,
        maskBuffer, maskPath, params.size, apiKey,
      );

      const savedPaths: string[] = [];
      for (let i = 0; i < buffers.length; i++) {
        const filePath = makeOutputPath(params.output_dir, params.filename ?? "nvidia_edited", i);
        fs.writeFileSync(filePath, buffers[i]);
        savedPaths.push(filePath);
      }

      const summary = savedPaths.length === 1
        ? `✅ Edited image saved to: ${savedPaths[0]}`
        : `✅ ${savedPaths.length} edited images saved:\n${savedPaths.join("\n")}`;

      return {
        content: [{ type: "text", text: summary }],
        details: { files: savedPaths, source: imagePath, prompt: params.prompt, model, mode: "nim" },
      };
    },
  });
}
