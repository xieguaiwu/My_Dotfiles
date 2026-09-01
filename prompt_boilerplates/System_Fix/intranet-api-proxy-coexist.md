---
name: intranet-api-proxy-coexist
version: 1.0.0
description: 排查并修复店内/局域网 API 与本地代理冲突——内网域名被代理劫持、no_proxy 小写坑、clash DNS hosts 映射、LiteLLM 参数剥离网关
triggers:
  - "店内 API 连不上"
  - "内网 API 走代理"
  - "token.agi.bar"
  - "API 请求超时 代理"
  - "reasoning_effort 不支持"
  - "UnsupportedParamsError"
  - "LiteLLM 400"
inputs:
  - name: upstream_host
    description: 内网 API 主机名（解析到局域网 IP 的域名）
    required: false
    default: "token.agi.bar"
  - name: upstream_key
    description: 上游 API key（网关转发时使用）
    required: false
    default: ""
  - name: gateway_port
    description: 本地网关监听端口
    required: false
    default: 8010
  - name: gateway_path
    description: 网关脚本保存路径
    required: false
    default: "$HOME/.local/bin/agi-bar-gateway.py"
tools:
  - bash
  - read
  - edit
  - write
  - grep
---

# 局域网 API 与本地代理共存修复

## 任务目标

排查并修复「店内/局域网私有 API 与本地代理（Clash Verge）同时使用」的冲突，涵盖四层：

1. **路由劫持**：内网域名（如 `token.agi.bar` → 172.18.7.11）被 clash 规则发往海外节点，连接超时
2. **DNS 盲区**：clash fake-ip 模式用公网 DNS 解析，拿不到店内内网记录，仅加 DIRECT 规则无效
3. **环境变量坑**：curl 等工具小写 `no_proxy` 优先，只设大写 `NO_PROXY` 不生效
4. **参数拒绝**：LiteLLM 网关 400 `UnsupportedParamsError`（`reasoning_effort`/`thinking` 未放行），需本地网关剥离

## 背景知识：冲突机制三层

| 层面 | 机制 | 症状 |
|------|------|------|
| 路由/应用层 | clash 规则 `MATCH,PROXY` 捕获非 .cn 域名，内网目标从海外节点不可达 | 连接超时（`context deadline exceeded`） |
| DNS 层 | fake-ip 模式 + 公网 DoH nameserver，无法解析店内内网记录 | 直连也不通（TUN 模式下尤甚） |
| 环境变量层 | curl/Go/Node 优先读小写 `no_proxy`；大写 `NO_PROXY` 单独设置无效 | 应用仍走代理，请求超时 |

另有认证与参数两关：`401 LiteLLM Virtual Key expected`（key 须 `sk-` 开头）与 `400 UnsupportedParamsError`（客户端默认参数未放行）。

## 执行流程

### 1. 判定场景与复现

先问/确认三事：目标域名、当前 Wi-Fi（店内公共网？）、失败报错（超时/401/400）。复现命令：

```bash
# 直连（跳过代理）与走代理各测一次，对比即知是否被代理劫持
curl --noproxy '*' -sS -o /dev/null -w "直连: %{http_code} %{time_total}s\n" --connect-timeout 8 https://<upstream_host>/v1
curl -x http://127.0.0.1:7897 -sS -o /dev/null -w "代理: %{http_code} %{time_total}s\n" --connect-timeout 8 https://<upstream_host>/v1
```

直连秒回而代理超时 → 路由劫持确认。

### 2. DNS 定位：确认内网 IP

```bash
getent hosts <upstream_host>        # 返回 172.18.x.x 之类私网段 = 店内内网服务
```

若系统 DNS 已返回私网 IP，而 mihomo（公网 DoH）解析不同/失败 → DNS 层冲突成立。公网对照：

```bash
curl --noproxy '*' -sS "https://doh.aliyuncs.com/dns-query?name=<upstream_host>&type=A" -H "accept: application/dns-json"
```

### 3. 修复环境变量 no_proxy（应用层，覆盖 CLI 工具）

小写优先，大小写**必须同时设**：

```fish
set -gx no_proxy  "<upstream_host>,<父域>,localhost,127.0.0.1,::1"
set -gx NO_PROXY  "<upstream_host>,<父域>,localhost,127.0.0.1,::1"
```

持久化位置：`~/.config/fish/config.fish`（代理设置区）。⚠️ 验证须用交互模式——config.fish 首行常有 `if not status is-interactive; return`，`fish -c` 非交互会跳过全部配置，产生假阴性：

```bash
fish --interactive -c 'source ~/.config/fish/config.fish; echo $no_proxy'
```

### 4. 修复 clash 全局扩展配置（代理层，覆盖 GUI 应用与 TUN）

`profiles/Merge.yaml`（全局扩展配置）追加，**dns.hosts 与规则缺一不可**——fake-ip 模式下仅加 DIRECT 规则，mihomo 用公网 DNS 解析到错误 IP，依然不通：

```yaml
dns:
  hosts:
    <upstream_host>: <内网IP>
prepend-rules:
  - DOMAIN-SUFFIX,<父域>,DIRECT
```

改毕在 clash-verge GUI「配置」页重新激活 Merge（或重启 clash-verge），再查运行时配置确认。

### 5. 认证排查（401）

`401 LiteLLM Virtual Key expected. Received=****, expected to start with 'sk-'` → key 必须以 `sk-` 开头。媒体流传的裸名 key（如 `agi_bar`）无效；店内 key 属线下分发（店员/二维码/小程序），无自助端点时勿盲目探测。

### 6. 参数兼容修复（400 UnsupportedParamsError → 本地网关）

客户端（Claude Code/Codex/Cursor）默认发送 `reasoning_effort`/`thinking`，LiteLLM 未配置 `allowed_openai_params` 时 400 拒绝。改不了店内配置时，本地起剥离网关（脚本见「输出格式」），客户端 BASE_URL 指向本地：

```text
BASE_URL = http://127.0.0.1:8010/v1
API_KEY  = 任意值（网关自带上游 key）
```

### 7. 验证闭环

```bash
# 1) 无代理直连店内 API
curl --noproxy '*' <upstream>/v1/models -H "Authorization: Bearer <key>"
# 2) no_proxy 生效（模拟真实应用环境）
no_proxy="<父域>,localhost,127.0.0.1,::1" HTTPS_PROXY="http://127.0.0.1:7897" ALL_PROXY="socks5://127.0.0.1:7897" \
  curl -sS <upstream>/v1/chat/completions -H "Content-Type: application/json" \
  -H "Authorization: Bearer <key>" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"OK"}],"max_tokens":200,"reasoning_effort":"high","thinking":{"type":"disabled"}}'
# 3) 网关链路（本地 8010 → 店内）
curl -sS http://127.0.0.1:8010/v1/models
# 4) 代理仍可用（外网不受影响）
curl -sS -o /dev/null -w "%{http_code}\n" --connect-timeout 6 https://github.com
```

四项全过 → 共存成立。

## 输出格式

**网关脚本**（保存至 `gateway_path`，`nohup python3 <gateway_path> &` 启动，日志 /tmp/agi-bar-gateway.log）：

```python
#!/usr/bin/env python3
"""
局域网 API 本地网关 — 剥掉 LiteLLM 不支持参数后转发上游。

背景：LiteLLM 网关未配置 allowed_openai_params 时，Claude Code / Codex / Cursor
默认发送 reasoning_effort / thinking → 400。本网关剥离二者（并默认注入
chat_template_kwargs.thinking=false 关闭深度思考，避免思考吃光 max_tokens）。

环境变量：
    AGI_BAR_HOST  上游主机（默认 token.agi.bar）
    AGI_BAR_KEY   上游 key（默认 sk-agi_bar-static）
    AGI_BAR_PORT  本地端口（默认 8010）
    AGI_NO_THINK  0 保留深度思考（默认 1 关闭）
"""
import json
import os
import http.client
import http.server

UPSTREAM_HOST = os.environ.get("AGI_BAR_HOST", "token.agi.bar")
UPSTREAM_PORT = 443
UPSTREAM_KEY = os.environ.get("AGI_BAR_KEY", "sk-agi_bar-static")
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("AGI_BAR_PORT", "8010"))
NO_THINK = os.environ.get("AGI_NO_THINK", "1") != "0"

DROP_PARAMS = ("reasoning_effort", "thinking")


def upstream_request(method, path, headers, body):
    conn = http.client.HTTPSConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=600)
    fwd = {k: v for k, v in headers.items()
           if k.lower() not in ("host", "connection", "content-length",
                                "transfer-encoding", "accept-encoding", "proxy-connection")}
    fwd["Authorization"] = f"Bearer {UPSTREAM_KEY}"
    if body is not None:
        fwd["Content-Length"] = str(len(body))
    conn.request(method, path, body=body, headers=fwd)
    return conn.getresponse()


def scrub_body(data):
    changed = False
    for p in DROP_PARAMS:
        if p in data:
            data.pop(p)
            changed = True
    if NO_THINK:
        ctk = data.get("chat_template_kwargs")
        if not isinstance(ctk, dict):
            ctk = {}
            data["chat_template_kwargs"] = ctk
        if "thinking" not in ctk:
            ctk["thinking"] = False
            changed = True
    return changed


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def _handle(self, method):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else None
        body = raw
        if raw and "/chat/completions" in self.path:
            try:
                data = json.loads(raw)
                if scrub_body(data):
                    body = json.dumps(data, ensure_ascii=False).encode()
            except (ValueError, TypeError):
                pass
        try:
            upstream = upstream_request(method, self.path, dict(self.headers), body)
        except Exception as exc:
            payload = json.dumps(
                {"error": {"message": f"gateway upstream error: {exc}",
                           "type": "connection_error"}}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        te_chunked = any(h.lower() == "transfer-encoding" for h, _ in upstream.getheaders())

        def _send_headers():
            self.send_response(upstream.status)
            for k, v in upstream.getheaders():
                if k.lower() in ("connection", "transfer-encoding", "content-length"):
                    continue
                self.send_header(k, v)

        try:
            if te_chunked:
                # 流式：chunked 逐块转发（SSE 场景，Claude Code/Codex 必用）
                _send_headers()
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                while True:
                    chunk = upstream.read(65536)
                    if not chunk:
                        break
                    self.wfile.write(f"{len(chunk):X}\r\n".encode() + chunk + b"\r\n")
                    self.wfile.flush()
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            else:
                buf = b""
                while True:
                    chunk = upstream.read(65536)
                    if not chunk:
                        break
                    buf += chunk
                _send_headers()
                self.send_header("Content-Length", str(len(buf)))
                self.end_headers()
                self.wfile.write(buf)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            upstream.close()

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_PUT(self):
        self._handle("PUT")

    def do_DELETE(self):
        self._handle("DELETE")


if __name__ == "__main__":
    srv = http.server.ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    print(f"gateway: http://{LISTEN_HOST}:{LISTEN_PORT}/v1  "
          f"(upstream={UPSTREAM_HOST}, no_think={NO_THINK})", flush=True)
    srv.serve_forever()
```

**客户端配置示例**（Claude Code/Codex/Cursor/Cherry Studio 通用）：

```text
BASE_URL = http://127.0.0.1:8010/v1
API_KEY  = <任意值>
MODEL    = <上游模型 ID>
```

## 注意事项

- **no_proxy 小写优先**：curl 8.x 实测只设大写 `NO_PROXY` 无效；大小写必须同步设（见步骤 3）
- **验证用交互模式**：config.fish 首行 `if not status is-interactive; return` 会令 `fish -c` 跳过配置，须用 `fish --interactive -c`
- **Merge 规则与 DNS hosts 成对**：fake-ip 模式下仅加 `DOMAIN-SUFFIX,DIRECT` 会解析到公网错误 IP；`dns.hosts` 静态映射是直连的前提
- **TUN 模式失效面**：开启 TUN（增强模式）后所有流量与 DNS 被 mihomo 接管，`no_proxy` 无效，只能依赖 Merge 方案
- **网关坑**：HTTP/1.1 转发必须正确处理 `Transfer-Encoding: chunked`（SSE 场景），否则客户端挂起等响应；非流式分支须在 `end_headers()` 前写 `Content-Length`
- **默认关思考**：店内模型默认深度思考会吃光小 `max_tokens` 预算，出现 `content: null` + `finish_reason: length`；网关默认注入 `chat_template_kwargs.thinking=false`
- **离店无副作用**：`no_proxy` 与 Merge 规则在家/他处保留无害（内网域名本就连不上，无干扰）
- **共享 key 无速率限制**：背后单机/双机并发低，人多时降速属正常物理上限

## 变更日志

### 1.0.0 (2026-08-25)
- 初始发布：2026-08-25 AGI Bar 店内实测沉淀——token.agi.bar 内网 API 与 clash 代理共存全流程（路由劫持诊断、no_proxy 小写坑、Merge dns.hosts+prepend-rules、LiteLLM 400 参数剥离网关、SSE chunked 转发）
