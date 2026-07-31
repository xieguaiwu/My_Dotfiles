---
name: piagent-search-pipeline-fix
version: 1.0.0
description: 诊断并修复 Pi-agent 搜索管道问题，包括 web_search 配置错误、ByteString 编码崩溃、provider 不可用、内容检索失败等。
triggers:
  - "搜索失败"
  - "search failed"
  - "ByteString error"
  - "Cannot convert argument to a ByteString"
  - "web_search 报错"
  - "get_search_content 找不到"
  - "No stored results"
  - "搜索配置问题"
  - "搜索provider不可用"
  - "Brave API key placeholder"
  - "fix search pipeline"
inputs:
  - name: mode
    description: "check-only: 只诊断不修复 | auto: 自动修复（默认）"
    required: false
    default: "auto"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
---

# Pi-agent 搜索管道诊断与修复

## 任务目标

诊断并修复 Pi-agent 的 `web_search` / `fetch_content` / `get_search_content` 工具链中的所有常见配置和运行时问题，包括：

1. **ByteString 编码崩溃**：API key 含非 Latin-1 字符（如中文占位符）被用作 HTTP Header 时 Bun 抛出 `Cannot convert argument to a ByteString`
2. **Provider 假阳性可用**：占位符 API key 使 `isXxxAvailable()` 返回 `true`，但实际调用失败
3. **内容检索失败**：`get_search_content` 返回 `No stored results`，因 responseId 与内部 searchId/fetchId 不匹配
4. **Provider 级联回退失效**：config 中 provider 指向不可用服务时无自动回退

## 背景知识：完整调用链

```
web_search 工具 (pi-web-access/index.ts)
  ↓
search() 路由 (pi-web-access/gemini-search.ts)
  ↓ provider 分发
  ├── searchWithOpenAI()  → openai-search.ts  → Codex / OpenAI API
  ├── searchWithBrave()   → brave.ts         → api.search.brave.com
  ├── searchWithExa()     → exa.ts           → api.exa.ai
  ├── searchWithTavily()  → tavily.ts        → api.tavily.com
  ├── searchWithParallel()→ parallel.ts      → api.parallel.ai
  ├── searchWithPerplexity() → perplexity.ts
  └── searchWithGemini()  → gemini-api.ts / gemini-web.ts

内容存储层 (pi-web-access/storage.ts)
  ↓ 内存 Map + session 恢复
  ├── search 结果 → searchId
  └── fetch 结果  → fetchId / responseId

配置入口
  ~/.pi/web-search.json       ← ALL provider keys + workflow + provider 默认值
  ~/.pi/agent/auth.json       ← opencode-go / openrouter keys
  ~/.pi/agent/models.json     ← 模型注册，影响 isOpenAISearchAvailable()
```

## 受影响文件

| 文件 | 角色 |
|------|------|
| `~/.pi/web-search.json` | **配置入口** — provider 选择、各 API key、workflow |
| `~/.pi/agent/npm/node_modules/pi-web-access/credential-source.ts` | **统一凭证入口** — 所有 provider 的 key 均经 `resolveCredential()` → `normalize()` 返回（Latin-1 防御应加在此处） |
| `~/.pi/agent/npm/node_modules/pi-web-access/brave.ts` | Brave provider + API key 校验 |
| `~/.pi/agent/npm/node_modules/pi-web-access/openai-search.ts` | OpenAI/Codex provider |
| `~/.pi/agent/npm/node_modules/pi-web-access/gemini-search.ts` | Provider 路由 + 级联回退逻辑 |
| `~/.pi/agent/npm/node_modules/pi-web-access/index.ts` | web_search / fetch_content / get_search_content 工具定义 |
| `~/.pi/agent/npm/node_modules/pi-web-access/storage.ts` | 搜索结果内存存储 |
| `~/.pi/agent/npm/node_modules/pi-web-access/exa.ts` | Exa provider + API key 校验 |
| `~/.pi/agent/npm/node_modules/pi-web-access/tavily.ts` | Tavily provider |
| `~/.pi/agent/npm/node_modules/pi-web-access/parallel.ts` | Parallel provider |
| `~/.pi/agent/npm/node_modules/pi-web-access/perplexity.ts` | Perplexity provider |
| `~/.pi/agent/npm/node_modules/pi-web-access/gemini-api.ts` | Gemini API provider |

## 执行流程

### Phase 1：诊断（并行采集）

以下命令可全部并行执行。

#### 1.1 检查 web-search.json 配置

```bash
echo "=== web-search.json ==="
cat ~/.pi/web-search.json

echo ""
echo "=== 检查可能的占位符 ==="
grep -E '填入|your-key|placeholder|changeme|replace.*key' ~/.pi/web-search.json 2>/dev/null && \
  echo "❌ 发现疑似占位符文本" || echo "✅ 未发现中文/英文占位符"
```

#### 1.2 检查 API key 是否含非 ASCII 字符（ByteString 根因）

```bash
echo "=== 检查各 API key 是否含非 Latin-1 字符 ==="
python3 -c "
import json, sys
with open('$HOME/.pi/web-search.json') as f:
    config = json.load(f)
for key in ['braveApiKey','openaiApiKey','exaApiKey','tavilyApiKey','parallelApiKey','perplexityApiKey','geminiApiKey','cloudflareApiKey']:
    val = config.get(key, '')
    if isinstance(val, str) and len(val) > 0:
        non_latin1 = [c for c in val if ord(c) > 255]
        if non_latin1:
            print(f'❌ {key}: 含 {len(non_latin1)} 个非 Latin-1 字符（U+{ord(non_latin1[0]):04X}），将导致 ByteString 错误')
        else:
            print(f'✅ {key}: 全部 ASCII 安全')
    elif isinstance(val, str):
        print(f'⚪ {key}: 空（provider 不可用）')
    else:
        print(f'⚪ {key}: 未配置')
"
```

**判断标准**：任何 key 包含 `ord(c) > 255` 的字符 → ❌ 必须修复。此类 key 被用作 HTTP Header 时 Bun 会抛 ByteString 错误。

#### 1.3 验证 provider 配置状态

> 新版 pi-web-access 的 `.ts` 源文件无法被 node 直接 import（需要 loader），因此这里只做配置层检查；**运行时可用性以 Phase 3 实网测试为准**。

```bash
echo "=== provider 配置检查 ==="
python3 - "$HOME/.pi/web-search.json" "$HOME/.pi/agent/auth.json" << 'PYCHECK'
import json, sys, os

cfg_path, auth_path = sys.argv[1], sys.argv[2]
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
auth = json.load(open(auth_path)) if os.path.exists(auth_path) else {}

def show(name, val):
    if isinstance(val, str) and val:
        print(f"  {name}: {'✅ 已配置 (ASCII 安全)' if val.isascii() else '❌ 含非 ASCII 字符'}")
    elif isinstance(val, dict) and val:
        print(f"  {name}: ✅ 已配置 (嵌套对象，如 auth.json 中的来源)")
    else:
        print(f"  {name}: ⚪ 未配置/为空")

print("- web-search.json keys:")
for k in ['braveApiKey','openaiApiKey','exaApiKey','tavilyApiKey','parallelApiKey','perplexityApiKey','geminiApiKey','cloudflareApiKey']:
    if k in cfg:
        show(k, cfg[k])
print("- auth.json 顶层来源:", ', '.join(auth.keys()) if auth else '(空)')
PYCHECK
```

#### 1.4 验证 Latin-1 编码防御

> 检测用 `grep -Fq` 匹配固定注释文本 `Reject non-Latin-1 chars`（**不要**用 `[^\\x00-\\xFF]` 正则：GNU grep 3.5+ 将 `\xNN` 解析为 hex 转义，`[^\x00-\xFF]` 补集为空永远不匹配，会误判）。

```bash
echo "=== 检查 Latin-1 编码防御 ==="
PI_WEB="$HOME/.pi/agent/npm/node_modules/pi-web-access"
# 统一入口：所有 provider 的 key 最终都经 credential-source.ts 的 normalize() 返回
if grep -Fq 'Reject non-Latin-1 chars' "$PI_WEB/credential-source.ts" 2>/dev/null; then
  echo "✅ credential-source.ts: 已有 Latin-1 校验（统一入口，覆盖全部 provider）"
else
  echo "❌ credential-source.ts: 缺少 Latin-1 校验（必须修复）"
fi
# 各 provider 文件（新版多数已无内联 normalizeApiKey，走统一入口即可）
for f in brave exa gemini-api openai-search parallel perplexity tavily; do
  path="$PI_WEB/${f}.ts"
  if grep -Fq 'Reject non-Latin-1 chars' "$path" 2>/dev/null; then
    echo "✅ ${f}.ts: 已有内联 Latin-1 校验"
  else
    echo "⚪ ${f}.ts: 无内联校验（经 resolveCredential 时由统一入口覆盖）"
  fi
done
```

#### 1.5 验证 config provider 配置不会导致直接跳转到假阳性 provider

```bash
echo "=== provider 路由逻辑检查 ==="
python3 -c "
import json
with open('$HOME/.pi/web-search.json') as f:
    config = json.load(f)
provider = config.get('provider', 'auto')
provider_str = str(provider) if provider else '(未设置，默认 auto)'
print(f'config.provider = {provider_str}')

# 如果 provider 指向一个 key 为空或有占位符的 provider，发出警告
key_map = {
    'openai': 'openaiApiKey',
    'brave': 'braveApiKey',
    'exa': 'exaApiKey',
    'tavily': 'tavilyApiKey',
    'parallel': 'parallelApiKey',
    'perplexity': 'perplexityApiKey',
    'gemini': 'geminiApiKey',
}
if provider in key_map:
    key_name = key_map[provider]
    key_val = config.get(key_name, '')
    if not key_val or not isinstance(key_val, str) or len(key_val.strip()) == 0:
        print(f'❌ 危险: provider={provider} 但 {key_name} 为空或未设置！')
        print(f'   该 provider 将直接失败，且无自动回退。建议改为 \"auto\"。')
    elif any(ord(c) > 255 for c in str(key_val)):
        print(f'❌ 危险: provider={provider} 但 {key_name} 含非 ASCII 字符（占位符）！')
        print(f'   将导致 ByteString 错误。建议改为 \"auto\" 或提供真实 key。')
    else:
        print(f'✅ provider={provider} 且 {key_name} 已配置')
elif provider == 'auto':
    print('✅ provider=auto，将自动选择最优可用 provider')
else:
    print(f'⚠️ 未知 provider: {provider}')
"
```

### Phase 2：修复

#### 2.1 修复 web-search.json 配置（最优先）

如果 Phase 1 发现任何问题，执行以下修复：

**情况 A**：`braveApiKey` 等字段含中文占位符或空字符串
→ 将占位符替换为空字符串 `""`，将 `provider` 改为 `"auto"`

```bash
# 使用 Python 安全修改 JSON
python3 -c "
import json, os
path = os.path.expanduser('~/.pi/web-search.json')
with open(path) as f:
    config = json.load(f)

modified = False

# 1. 清空含非 ASCII 字符的 API key（ByteString 风险）
for key in ['braveApiKey','openaiApiKey','exaApiKey','tavilyApiKey','parallelApiKey','perplexityApiKey','geminiApiKey','cloudflareApiKey']:
    val = config.get(key, '')
    if isinstance(val, str) and any(ord(c) > 255 for c in val):
        config[key] = ''
        modified = True
        print(f'[FIX] {key}: 清空含非 ASCII 字符的占位符')

# 2. 如果 provider 指向 key 为空的 provider，改为 auto
provider = config.get('provider', 'auto')
key_map = {
    'openai': 'openaiApiKey', 'brave': 'braveApiKey', 'exa': 'exaApiKey',
    'tavily': 'tavilyApiKey', 'parallel': 'parallelApiKey',
    'perplexity': 'perplexityApiKey', 'gemini': 'geminiApiKey',
}
if provider in key_map:
    key_val = config.get(key_map[provider], '')
    if not isinstance(key_val, str) or len(key_val.strip()) == 0:
        config['provider'] = 'auto'
        modified = True
        print(f'[FIX] provider: {provider} → auto (原 provider key 为空)')

if modified:
    with open(path, 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'[✓] 已更新 {path}')
else:
    print('[✓] 配置无需修改')
"
```

**情况 B**：`allowBrowserCookies` 为 false 且无其他可用 provider
→ 如果用户需要 Gemini Web，设为 `true`。但通常保持 `false` 更安全（避免浏览器 cookie 依赖）。

#### 2.2 为统一凭证入口添加 Latin-1 编码防御

如果 Phase 1.4 发现缺少防御，执行批量修复。

**新版架构说明**：pi-web-access 新版本中所有 provider 的 key 统一经 `credential-source.ts` 的 `resolveCredential()` → `normalize()` 返回（7 个 provider 文件中多数已无内联 `normalizeApiKey`）。防御策略：**统一入口（credential-source.ts）必须修**；残留 `normalizeApiKey` 的文件（如 gemini-api.ts、parallel.ts）一并修复。

**目标替换模式**（`normalizeApiKey` / `normalize` 函数）：

```typescript
// 修复前
function normalizeApiKey(value: unknown): string | null {
	if (typeof value !== "string") return null;
	const normalized = value.trim();
	return normalized.length > 0 ? normalized : null;
}

// 修复后
function normalizeApiKey(value: unknown): string | null {
	if (typeof value !== "string") return null;
	const normalized = value.trim();
	if (normalized.length === 0) return null;
	// Reject non-Latin-1 chars (prevent ByteString errors in HTTP headers)
	if (/[^\x00-\xFF]/.test(normalized)) return null;
	return normalized;
}
```

**需要修复的文件列表**（统一入口 + 全部 provider，仅修复未防御的）：

```bash
PI_WEB="$HOME/.pi/agent/npm/node_modules/pi-web-access"
# 统一入口 + 所有 provider 文件（新版多数已无内联 normalizeApiKey，防御集中在统一入口）
FILES=("$PI_WEB/credential-source.ts")
for f in brave exa gemini-api openai-search parallel perplexity tavily; do
  FILES+=("$PI_WEB/${f}.ts")
done

for path in "${FILES[@]}"; do
  if grep -Fq 'Reject non-Latin-1 chars' "$path" 2>/dev/null; then
    echo "  ✅ $(basename "$path") 已防御，跳过"
    continue
  fi
  echo "修复 $path ..."
  python3 - "$path" << 'PYFIX'
import sys
p = sys.argv[1]
with open(p) as fh:
    c = fh.read()

# 1) 优先精确替换 normalizeApiKey 函数块（避免误伤 normalizeBaseUrl 等相似函数）
block_old = (
    'function normalizeApiKey(value: unknown): string | null {\n'
    '\tif (typeof value !== "string") return null;\n'
    '\tconst normalized = value.trim();\n'
    '\treturn normalized.length > 0 ? normalized : null;\n'
    '}'
)
block_new = (
    'function normalizeApiKey(value: unknown): string | null {\n'
    '\tif (typeof value !== "string") return null;\n'
    '\tconst normalized = value.trim();\n'
    '\tif (normalized.length === 0) return null;\n'
    '\t// Reject non-Latin-1 chars (prevent ByteString errors)\n'
    '\tif (/[^\\x00-\\xFF]/.test(normalized)) return null;\n'
    '\treturn normalized;\n'
    '}'
)
# 2) 回退：单行模式（credential-source.ts 的 normalize() 等函数名不同的情况）
plain_old = 'return normalized.length > 0 ? normalized : null;'
plain_new = ('if (normalized.length === 0) return null;\n'
             '\t// Reject non-Latin-1 chars (prevent ByteString errors)\n'
             '\tif (/[^\\x00-\\xFF]/.test(normalized)) return null;\n'
             '\treturn normalized;')

changed = False
if block_old in c:
    c = c.replace(block_old, block_new)
    changed = True
elif plain_old in c:
    c = c.replace(plain_old, plain_new)
    changed = True
if changed:
    with open(p, 'w') as fh:
        fh.write(c)
    print('  ✅ 修复成功')
else:
    print('  ⚠️ 未找到目标模式（可能已修复或版本不同），跳过')
PYFIX
done
```

> **注意**：以上脚本先精确替换 `normalizeApiKey` 函数块，未匹配时回退到单行模式（覆盖 `credential-source.ts` 的 `normalize()`）。若全部跳过，需检查 pi-web-access 升级后的源码变化，手动用 `edit` 工具修复。

#### 2.3 验证修复

```bash
echo "=== 修复后验证 ==="

# 1. 确认无占位符
grep -E '填入|your-key|placeholder' ~/.pi/web-search.json 2>/dev/null && \
  echo "❌ 仍有占位符" || echo "✅ 无占位符"

# 2. 确认 provider 正确
python3 -c "
import json
with open('$HOME/.pi/web-search.json') as f:
    c = json.load(f)
print(f'  provider={c.get(\"provider\",\"未设置\")} | workflow={c.get(\"workflow\",\"未设置\")}')
for k in ['braveApiKey','openaiApiKey']:
    v = c.get(k,'')
    print(f'  {k}={\"***\" if v else \"(空)\"}')
"

# 3. 确认统一入口 + 所有 provider 文件有 Latin-1 防御
missing=0
for path in "$HOME/.pi/agent/npm/node_modules/pi-web-access/credential-source.ts" \
            "$HOME/.pi/agent/npm/node_modules/pi-web-access"/{brave,exa,gemini-api,openai-search,parallel,perplexity,tavily}.ts; do
  if ! grep -Fq 'Reject non-Latin-1 chars' "$path" 2>/dev/null; then
    echo "  ❌ $(basename "$path") 仍缺少 Latin-1 防御"
    missing=$((missing+1))
  fi
done
if [ $missing -eq 0 ]; then
  echo "✅ 统一入口 + 7 个 provider 文件均已防御"
fi
```

### Phase 3：功能测试

修复后运行实网搜索测试，验证全链路。

```bash
echo "=== 功能测试：web_search 单查询 ==="
# 使用 pi 的非交互模式运行测试
# 注意：此测试需要 pi-agent 在交互模式下执行，故仅作诊断参考
echo "建议在 pi-agent 会话中运行: web_search({ query: 'test search pipeline', provider: 'auto' })"
```

**成功标准**：
- `web_search` 返回含 source citations 的结果
- 无 `ByteString` 错误
- `fetch_content` 能成功抓取 URL
- `get_search_content` 传入正确的 responseId 能返回完整内容

---

## 故障速查表

| 症状 | 根因 | 修复 |
|------|------|------|
| `Cannot convert argument to a ByteString` (U+586B 等) | API key 含中文占位符用作 HTTP Header | 清空 key + 添加 Latin-1 校验 |
| 所有查询均报错且无回退 | `provider` 指向 key 为空的 provider | 改 `provider` 为 `"auto"` |
| 搜索成功但 `get_search_content` 报 `No stored results` | responseId 不匹配（searchId vs fetchId） | 使用 `fetch_content` 直接抓取，或查找正确的 searchId |
| Brave 总是被选中但调用失败 | `isBraveAvailable()` 对占位符 key 返回 true | 清空 key → `isBraveAvailable()` 返回 false |
| Gemini Web 不可用 | `allowBrowserCookies: false` | 如需用 Gemini Web 则设为 true（需 Chrome 登录） |
| 部分查询成功、部分失败 | provider=brave 时所有查询共享同一无效 key | 改为 auto 让路由选择可用 provider |

## 注意事项

1. **Codex 订阅是隐藏的 OpenAI 搜索入口**：即使用户未在 `models.json` 中显式列出 GPT 模型，`opencode-go` Codex 订阅可通过 `resolveOpenAIAuth()` 提供 OpenAI web_search。只要 `auth.json` 中有 `opencode-go` key，`provider: "auto"` 通常能正常工作。

2. **`get_search_content` 的 responseId 陷阱**：`web_search` 的 details 中返回 `searchId`（查询结果数据），而 `fetch_content` 的 details 中返回 `responseId`（抓取内容）。`get_search_content` 参数名为 `responseId`，但实际接受任意存储 ID。常用方式：先用 `fetch_content` 抓取 URL → 获取其 `responseId` → 再传给 `get_search_content`。

3. **provider 文件的修改不会自动持久化**：pi-web-access 是 npm 包，`npm update` 或 `pi update` 可能覆盖修复。目前不提供 patch 持久化方案（与 CMap fix 不同，这里的修改属于「防御性加固」而非核心缺陷修复）。升级后重新运行 Phase 1 检测即可确认防御是否仍在。

4. **Linux headless 环境的 curator**：`workflow: "auto-summary"` 在 headless 环境下自动生成摘要，无需打开浏览器 curator。`workflow: "summary-review"` 需要浏览器交互，在无 GUI 环境下会超时后自动回退。

5. **优先修复 config、其次代码**：大多数 ByteString 和 provider 问题仅需修改 `~/.pi/web-search.json` 即可解决。代码层 Latin-1 防御是安全网，防止未来再次误配置。

## 输出格式

```markdown
# Pi-agent 搜索管道诊断报告

### 配置状态
| 字段 | 值 | 状态 |
|------|------|------|
| provider | auto | ✅ |
| braveApiKey | (空) | ✅ |
| workflow | auto-summary | ✅ |

### Provider 可用性
| Provider | 状态 |
|----------|------|
| OpenAI (Codex) | ✅ 可用 |
| Brave | ❌ 无 key |
| ... | ... |

### 编码安全
| 文件 | Latin-1 防御 |
|------|-------------|
| brave.ts | ✅ |
| ... | ... |

### 修复摘要
| 修复项 | 状态 |
|--------|------|
| 清空占位符 API key | ✅ |
| provider → auto | ✅ |
| Latin-1 防御 (7 files) | ✅ |
```

## 相关 Skill 文件

| Skill | 路径 | 用途 |
|-------|------|------|
| 系统诊断修复 | `system_diagnostics_and_repair.md` | OS 层面问题（OOM/驱动/服务） |
| CMap PDF 修复 | `piagent-cmap-fix.md` | PDF 提取 CMap 字体加载 |
| 温度链修复 | `subagent-temperature-fix.md` | Subagent 温度控制覆盖 |
| **搜索管道修复** | `piagent-search-pipeline-fix.md` | 本文件 — web_search 全链路 |
