---
name: piagent-connection-error-fix
version: 1.0.0
description: 诊断修复 pi-agent 的 Connection error——首查 ~/.pi/web-search.json 完整性（fetch 包装器每次调用解析之，坏文件致全量调用抛错），次查代理重启后连接池失效，终验网络与密钥，附验证闭环
triggers:
  - "pi-agent 连接错误"
  - "pi Connection error"
  - "连接错误"
  - "web-search.json"
  - "pi 无法调用模型"
  - "模型调用秒失败"
  - "pi 连不上模型"
  - "pi 报错 Connection"
inputs:
  - name: mode
    description: '执行范围: check-only（只诊断）, auto（诊断+修复，默认）'
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

# Pi-agent Connection error 修复

## 任务目标

诊断并修复 pi-agent 的 Connection error。症状：全部模型调用秒失败、usage 归零、会话日志仅记 `"Connection error."` 而真因被吞。2026-08-27 实测根因为 `~/.pi/web-search.json` 被并发写坏（尾逗号），致 fetch 包装器每次调用抛错；次因为代理重启后连接池失效。

## 背景知识

pi-web-access 扩展包装全局 fetch（`utils.ts` 之 `installGlobalProxyFetch`）：每次调用先解析 `~/.pi/web-search.json` 取代理配置（`loadConfiguredProxy`），解析失败即抛错，包装器无 try/catch。OpenAI SDK 将其包装为 `Connection error.`，cause 不入会话日志。

**关键认知**：
- 包装器每次调用重读该文件——修好文件即时生效，无需重启 pi。
- 网络实测正常 ≠ pi 正常——测试须过包装器之路径，或直接排除之。
- 错误形态为秒失败 + usage 0，与网络抖动（慢而不断）不同。

## 执行流程

### 1. 先辨症状

读会话日志，确认错误形态：

```bash
grep -l 'Connection error' ~/.pi/agent/sessions/*/*.jsonl 2>/dev/null | tail -3
```

特征：`"stopReason":"error"`、`errorMessage:"Connection error."`、usage 全 0、重试 2/4/8/16/32 秒全败。若 errorMessage 含 "undici dispatcher" 长文，系 fetch 实现与代理 dispatcher 版本不匹配，直接跳步骤 5。

### 2. 速验网络层（勿先动代理）

```bash
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' --max-time 8 -x http://127.0.0.1:7897 https://api.deepseek.com/
```

得 401 即链路通（无 key 之预期响应）。再以 pi 同款栈做流式实测：node + undici EnvHttpProxyAgent + 同 key + `stream: true`（脚本见附录），六连皆通则网络无碍。**勿 kill clash-verge**——本机出网依赖之，杀之则 pi 自身断连（2026-08-27 连环故障教训）。

### 3. 查验 web-search.json（第一嫌疑）

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" ~/.pi/web-search.json
```

坏则见解析报错（常见：尾逗号 `,\n}`、字段间缺逗号）。同时查 watchdog 是否已自动修复：

```bash
tail -5 ~/.local/share/clash-watchdog/watchdog.log 2>/dev/null
```

若已记 "web-search.json 已修复"，则直接进步骤 6 验证。

### 4. 修复 web-search.json

尾逗号类损坏可安全修复：

```bash
python3 -c "
import json, re
p = '$HOME/.pi/web-search.json'
raw = open(p).read()
for _ in range(3):
    nf = re.sub(r',(\s*[}\]])', r'\1', raw)
    if nf == raw: break
    raw = nf
json.loads(raw)
open(p, 'w').write(raw)
print('repaired')
"
```

修复毕即时生效，勿先重启 pi。若修复后仍解析失败（语义损坏），则对照备份或默认配置重建，并记入诊断报告。

### 5. 排除连接池与环境因素

- 若 clash-verge 重启于近时（`logs/latest.log` 含 `Starting core`），且 pi 自重启后全败：重启 pi 以重建 undici 连接池；或改任意设置项触发 `configureHttpDispatcher` 重建。
- 查验 NO_PROXY 加固：`grep -c api.deepseek.com ~/.config/environment.d/proxy.conf`——应含 LLM 域名（api.deepseek.com、openrouter.ai 等），使 pi 的 LLM 出网不依赖本地代理。
- 查验 profile 漂移（hy2 场景）：`grep '^current:' ~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles.yaml` 应为 `Lt3Ic0l85eT1`；运行时须含 `HY2-LA-5TB`。

### 6. 验证闭环

修复后于 pi 重发消息，或查最新会话文件：

```bash
ls -t ~/.pi/agent/sessions/*/*.jsonl | head -1
```

出现 `"stopReason":"stop"` 且 usage 非零即成功。勿用 `pi --print` 验证——无头模式启动挂起系独立 bug（2026-08-27 实测，strace 零网络调用），不作准。

## 输出格式

诊断报告，含四节：

1. 症状确认（错误形态 + 起始时间线）
2. 网络层结果（curl 码与耗时 + undici 流式实测）
3. web-search.json 状态（解析结果 + 是否已自动修复）
4. 修复动作与验证（改动文件 + 最终会话证据）

## 注意事项

- **勿 kill clash-verge**：本机代理基础设施，杀之则 pi 自身 LLM 出网中断（2026-08-27 连环故障根因之一）。
- 勿在测试配置副本末尾追加顶层键（如 `log-level`），与原有键冲突致 mihomo fatal（`mapping key "log-level" already defined`）。
- 双 pi 实例并发写配置为 web-search.json 损坏之源；勿在多实例同时改 web-search 相关设置。
- 修复 web-search.json 后即时生效，勿先重启 pi；重启反而无益。
- 会话 errorMessage 含 "undici dispatcher" 长文时，重启 pi 即可，勿查网络。
- watchdog 自 2026-08-27 起含 web-search.json 完整性检查与尾逗号自动修复，故障多发时可先查其日志。
- 排查全程按序：先症状、再文件、后环境；勿跳过步骤 3 直查代理。

## 附录：undici 流式实测脚本

以 pi 同款栈（EnvHttpProxyAgent + 同 key + 流式）测链路，六连验证：

```javascript
import { EnvHttpProxyAgent, setGlobalDispatcher } from 'undici';
import fs from 'node:fs';
const key = JSON.parse(fs.readFileSync(process.env.HOME + '/.pi/agent/auth.json', 'utf8')).deepseek.key;
setGlobalDispatcher(new EnvHttpProxyAgent({ allowH2: false }));
for (let i = 1; i <= 6; i++) {
  const t0 = Date.now();
  try {
    const r = await fetch('https://api.deepseek.com/chat/completions', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: 'Bearer ' + key },
      body: JSON.stringify({ model: 'deepseek-v4-flash', messages: [{ role: 'user', content: 'ping' }], max_tokens: 8, stream: true }),
    });
    if (!r.ok) { console.log(`#${i} HTTP ${r.status}`); continue; }
    const rd = r.body.getReader(); const dec = new TextDecoder(); let n = 0;
    while (true) { const { done, value } = await rd.read(); if (done) break; n += dec.decode(value, { stream: true }).length; }
    console.log(`#${i} OK ${n}B ${Date.now() - t0}ms`);
  } catch (e) { console.log(`#${i} FAIL ${e.name}: ${e.message}`); }
}
```

运行位置：`@earendil-works/pi-coding-agent/node_modules/` 下（undici 解析依赖），或 `~/.pi/agent/npm/node_modules/` 下。

## 变更日志

### 1.0.0 (2026-08-27)
- 初始发布：2026-08-27 故障沉淀——web-search.json 并发写坏（尾逗号）致 fetch 包装器全量抛错，Connection error 真因被 SDK 吞；含快速网络排除、文件修复、连接池排查、验证闭环与防护说明
