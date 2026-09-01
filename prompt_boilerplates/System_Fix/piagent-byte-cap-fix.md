---
name: piagent-byte-cap-fix
version: 1.0.0
description: 诊断修复 pi-agent 模型请求 400 网关字节错误（read body failed / Exceeded limit on max bytes），根因图片 token/byte 计量错配，方案为 before_provider_request 字节守卫扩展
triggers:
  - "read body failed"
  - "Exceeded limit on max bytes"
  - "400001"
  - "请求体超限"
  - "字节上限"
  - "图片请求 400"
  - "模型请求 400"
inputs:
  - name: mode
    description: '执行范围: check-only（只诊断）, auto（诊断+修复，默认）'
    required: false
    default: "auto"
tools:
  - read
  - bash
  - write
  - edit
  - grep
  - glob
---

# Pi-agent 请求体字节上限修复

## 任务目标

诊断并修复 pi-agent 模型调用之 400 网关字节错误。症状两类：

- **确定性**：`400 {"type":"invalid_request_error","code":"400001","message":"Exceeded limit on max bytes to request body : 6291456"}`——超硬上限。
- **间歇性**：`400 {"type":"gateway_error","code":"400001","message":"The request is invalid: read body failed..."}`——读体超时，同尺寸有时成功有时失败。

根因：pi 按 token 预算对话、网关按字节限流，**计量单位错配**。base64 图片被 pi 计 1,200 token/图而实耗约 720 KB，工具图片每回合重复上传，累积撑爆字节上限，contextWindow 压缩判定对此完全失灵。2026-09-01 实测于 B.AI（api.b.ai），方法通用于一切按字节限流之 provider。

## 背景知识

**pi 图像计量**：`ESTIMATED_IMAGE_CHARS=4800` → 每图 1,200 token（`estimateTextAndImageContentChars` 按常量计，与实际 base64 字节无关）。

**累积路径**：工具结果图片每回合重复上传（`normalizeToolResultImages`），7 张截图 = 5.0 MB。

**压缩失效**：`shouldCompact: contextTokens > contextWindow - reserveTokens(16384)`。失败时上下文仅 123k token，pi 以为尚有 87% 余量，字节已顶到 91% 上限。

**网关硬上限**：B.AI 实测 6,291,456 B（6 MiB）。超限确定性 400；接近上限时经代理链路读体超时 → 间歇 400 "read body failed"。

**不重试**：该错误串在 pi `RETRYABLE_PROVIDER_ERROR_PATTERN` 零命中 → 400 不重试 → 一次抖动直接中断回合（用户只能手动切模型）。

## 执行流程

### 1. 先辨症状（会话日志定位）

```bash
grep -rl 'read body failed\|Exceeded limit on max bytes' ~/.pi/agent/sessions/*/*.jsonl
```

- 特征：`"stopReason":"error"`、usage 全 0、errorMessage 含 `gateway_error`/`invalid_request_error` 与 `400001`。
- **两种形态必须区分**：`Exceeded limit on max bytes` = 确定性超限；`read body failed` = 间歇性读超时。修复同一，但判据与验证口径不同。

### 2. curl 尺寸探针（确定网关字节上限）

首验链路通（200 得 usage 即通），再以不同尺寸 body 二分探上限：

```bash
# 生成尺寸档位 body（勿命令行内联——>2 MB 即 Argument list too long，必须文件）
python3 - <<'PY'
import json
for KB in (1000, 5000, 5500, 6200, 7000):
    pad = 'x' * (KB * 1024)
    open(f'/tmp/bai_{KB}.json', 'w').write(json.dumps(
        {"model": "deepseek-v4-flash", "messages": [{"role": "user", "content": "say ok"},
         {"role": "user", "content": pad}], "max_tokens": 8, "stream": False}))
PY
# 逐档打（本机 B.AI 需代理）
curl -sS --proxy http://127.0.0.1:7897 --max-time 180 -X POST \
  https://api.b.ai/v1/chat/completions -H "Authorization: Bearer $BAI_API_KEY" \
  -H "Content-Type: application/json" --data-binary @/tmp/bai_7000.json -w "|HTTP:%{http_code}"
```

- 超限档位返回 `Exceeded limit on max bytes to request body : NNNN` → 上限数值坐实（B.AI 为 6291456）。
- 接近上限档位多打数次，观察间歇 `read body failed`（同尺寸时有时无即读超时）。
- 上传耗时同步记录：代理链路 ~200-500 KB/s 时，5 MB 需 20-35 s，读超时窗口随体积放大。

### 3. 确认模型画像（vision vs text-only）

```bash
python3 -c "
import json; d = json.load(open('$HOME/.pi/agent/models.json'))
for pn, p in d['providers'].items():
    for m in p.get('models', []):
        print(f\"{pn}/{m['id']}\", m.get('input'))
"
```

- `input` 含 `"image"` 之模型才携带图片（`provider-composer.js:70 input: definition.input ?? ["text"]`）；无 `input` 键者默认 `["text"]`，pi 自动将图片替换为文字提示 → **天然免疫**。
- **报错模型名须核对**：用户报 `deepseek-v4-flash` 实为 `deepseek-v4-flash-vision-exp`——纯文本变体不中招，勿在其上浪费时间。

### 4. 核验计量错配（读源码常量）

```bash
grep -o 'ESTIMATED_IMAGE_CHARS=[0-9]*' \
  ~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/chunks/*.js
# → ESTIMATED_IMAGE_CHARS=4800（= 1,200 token/图，与字节无关）
```

再以会话 usage 佐证：失败点上下文 ~123k token vs body 5.44 MB，`contextWindow=1000000` 令压缩阈值在 983,616 token——pi 视野 87% 余量 vs 字节 91% 顶格，错配坐实。

### 5. 安装字节守卫扩展（修复主体）

扩展位置：`~/.pi/agent/extensions/image-byte-guard/index.ts`，挂 `before_provider_request`（pi 经 `onPayload` 接线，可整体替换 payload）：

1. 序列化 payload 计字节；超预算（默认 4 MiB）则继续。
2. 用 pi 自带 `resizeImage()` 重编码超大图——PNG 截图转 JPEG 同分辨率约 4x 压缩（970x2000 之 708 KB → 192 KB，视觉无损）。
3. 重编码后仍超预算 → 丢最旧图（永远保留最新一张），留 `[image omitted...]` 文字标记。
4. **只改出站 wire payload，不动 session 记录**——会话历史仍显原图。

配置项：

| 变量 | 默认 | 作用 |
|---|---|---|
| `PI_MAX_REQUEST_BYTES` | 4194304 (4 MiB) | 请求体预算，超则触发压缩 |
| `PI_MAX_REQUEST_HARD_BYTES` | 6291456 (6 MiB) | 纯文本超限告警阈值 |
| `PI_IMAGE_BYTE_GUARD` | （开） | `off`/`0` 禁用 |
| `PI_DEBUG_IMAGE_GUARD` | （关） | `1` 输出压缩日志 |

### 6. 记录字节约束（models.json）

在受影响的 provider 加自定义注释键（不破坏 schema，实测安全）：

```json
"_byte_limit_note": "⚠️ 网关按【字节】限流，不是按 token：硬上限 6,291,456 B..."
```

改前备份：`cp models.json backups/models.json.byteguard-$(date +%Y%m%d-%H%M%S)`。

### 7. 验证闭环

- **缩放测试**：1/7/15/30/60 张图 → 均收敛 ≤ 4 MB 且全保留（60 张 42.6 → 3.82 MB）。
- **对抗样本**：30 图 + 3.5 MB 文本 → 24.5 → 4.11 MB，丢 29 保 1（正确降级）。
- **视觉保持**：压缩后答案与未压缩基线逐字一致（实测 `00:03`）。
- **降级路径**：强制 `resizeImage` 不可用 → 丢最旧图兜底，5.3 → 3.87 MB 仍在上限内。
- **真机**：`pi --provider bai --model deepseek-v4-flash-vision-exp --no-session -p "@/tmp/shot.png" "首行文字?"`——压缩后正确回答且日志含 `image(s) recompressed`。
- **副作用为正**：上传耗时 8.5 s → 3.8 s（2.3x），读超时窗口同步缩短。

## 输出格式

诊断报告，含四节：

1. 症状确认（错误形态 `gateway_error` vs `invalid_request_error` + 起始时间线）
2. 探针结果（curl 各尺寸档位 HTTP 码 + 硬上限数值 + 间歇档位）
3. 模型画像（哪些 provider/model 带图、报错名核对）
4. 修复动作与验证（扩展文件 + models.json 改动 + 缩放/降级/视觉保持证据）

## 注意事项

- **勿调小 contextWindow**：1M 是真的（768k prompt tokens 实测可过）。为字节问题砍 token 额度是错误权衡——字节防线交给守卫扩展。
- **纯文本超限守卫处理不了**（截断毁对话），已改为告警。当前不可达（1M token × 4 chars ≈ 3.9 MB < 6 MiB，压缩先触发）；**若把字节限流 provider 的 contextWindow 调 >1.5M，此不变量即破**。
- **扩展整体加载失败 = 静默失效**（最薄一环）：`before_provider_request`/`resizeImage` 属 pi 内部接口，升级可能改名。只丢 `resizeImage` 会降级并弹警告；整个扩展加载失败则无告警无保护。
- **其他 provider 字节上限未测**：4 MiB 预算按 BAI 6 MiB 调；本机 10 provider 全 `openai-completions`、17 个图片模型，上限更低者仍会撞，须按 provider 设 `PI_MAX_REQUEST_BYTES`。
- **PNG→JPEG 重编码仅 BAI 验证**：其他模型对 JPEG 的接受度未验。
- **compaction 不带图片字节**：`serializeConversation` 只取 text block，压缩请求本身无溢出风险，勿在此排查。
- 扩展内 `import type { ExtensionAPI } from "@mariozechner/pi-coding-agent"` 可编译因 type-only 擦除——该包磁盘上不存在，运行时经 jiti `VIRTUAL_MODULES` 映射到 pi 自身 dist；运行时导入须走动态 `import()` + try/catch。
- **测降级路径勿用 `Module._load` 拦截**——动态 `import()` 不走它，得假绿。改法：复制扩展、loader 短路 `return null` 再测。
- `tsx -e` 内联脚本带 top-level await 报 CJS 输出错误——写成 `.ts` 文件跑。
- curl 大 body 用文件 `--data-binary @file`；命令行内联 >2 MB 即 `Argument list too long`。

## 变更日志

### 1.0.0 (2026-09-01)
- 初始发布：2026-08-31 深夜故障沉淀——B.AI 网关字节上限（6 MiB）撞穿：token/byte 计量错配（`ESTIMATED_IMAGE_CHARS=4800` ≈ 1,200 token vs 实耗 720 KB/图）、工具图片累积重复上传、contextWindow 压缩判定失效、400 不重试；修复 = `image-byte-guard` 扩展（resizeImage 重编码 + 丢最旧兜底）+ models.json 字节约束记录；含 curl 探针、缩放/降级/视觉保持验证闭环与六条残留风险边界
