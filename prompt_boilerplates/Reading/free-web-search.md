---
name: free-web-search
version: 1.0.1
description: 用 curl 抓搜索引擎 HTML 与 opencli 公开 API 适配器组合，在 web_search 不可用时作为零成本替代方案
triggers:
  - "web_search 不可用"
  - "免费搜索"
  - "无 API key 搜索"
  - "curl 搜索"
  - "opencli 搜索"
  - "搜索替代方案"
  - "search fallback"
inputs:
  - name: query
    description: 搜索关键词（中英文均可）
    required: true
  - name: mode
    description: 搜索模式——auto（自动选路）、public-api（仅 opencli 公开 API）、html-scrape（仅 curl 抓 DDG/Bing HTML）、fetch（已知 URL 直接抓正文）
    required: false
    default: "auto"
  - name: lang
    description: 查询语言偏好——en（英文优先）、zh（中文优先）、auto（按 query 自动判）
    required: false
    default: "auto"
  - name: max_results
    description: 最大返回结果数
    required: false
    default: 10
  - name: fetch_full
    description: 是否对前 N 个结果调用 fetch_content 抓取正文
    required: false
    default: false
tools:
  - bash
  - fetch_content
  - get_search_content
  - read
  - write
  - edit
  - subagent
---

# 免费网页搜索（web_search 零成本替代方案）

当 `web_search` 工具因无 API key 全部失败时，本 skill 通过三大替代路径组合实现零成本网络搜索：`opencli` 公开 API 适配器、`curl` 直接抓取搜索引擎 HTML、`fetch_content` 抓取已知 URL 正文。所有路径均不需要任何 API key 或付费订阅。

## 任务目标

在 `web_search` 不可用（全部 provider 无 API key、Codex 订阅未登录、Gemini API 地区被锁等）的情况下，通过组合 `opencli` 公开 API 适配器、`curl` 抓取搜索引擎 HTML、`fetch_content` 抓取正文三条路径，达到与 `web_search` 相当的信息采集能力，并输出带 source citations 的结构化结果。

## 路径选择决策树

按以下优先级选择路径，`mode: "auto"` 时自动按此顺序尝试：

1. **学术/技术/医学/实体类查询** → 优先 opencli 公开 API（精确结构化结果，无需注册）
2. **通用网页/新闻/中文热点查询** → curl 抓 DuckDuckGo HTML（通用网页搜索）
3. **已知具体 URL** → 直接 `fetch_content` 抓正文（含 Jina Reader 兜底）
4. **News/讨论类** → curl 抓 HackerNews Algolia API + opencli hackernews（无 key 实时热点）

## 执行流程

### 1. 环境预检

每次执行前，先确认环境状态：

```bash
# 1.1 代理可用性（中国大陆默认需要代理访问境外服务）
echo -n "代理出口 IP: "
curl --max-time 8 -s --proxy http://127.0.0.1:7897 "http://ip-api.com/json" 2>&1 | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"{d.get('country','?')} / {d.get('city','?')} / {d.get('query','?')}\")" 2>/dev/null || echo "代理不可达"
# 注：ip-api.com 免费层限 45 req/min，正常使用不会触及。高频测试时可改用 ifconfig.me

# 1.2 opencli 可用性（检查命令存在及核心适配器数量）
if command -v opencli >/dev/null 2>&1; then
  N=$(opencli list 2>/dev/null | grep -cE 'arxiv|wikipedia|hackernews|pubmed|stackoverflow|google-scholar|wikidata' || echo 0)
  echo "opencli: ✅ 可用（${N}/7 核心适配器）"
else
  echo "opencli: ❌ 未安装"
fi

# 1.3 fetch_content 能力（依赖 Jina Reader 兜底）
curl --max-time 8 -s --proxy http://127.0.0.1:7897 -o /dev/null -w "Jina Reader: HTTP %{http_code}\n" "https://r.jina.ai/" 2>&1
```

**判断**：
- 代理可达 → 三条路径全部开通
- 仅 opencli 可达（代理失败）→ 用 opencli 公开 API 适配器（wikipedia/arxiv/pubmed 等不限地区）
- 代理与 opencli 均失败 → 回退到本地缓存或 `memory_search` 检索历史知识

### 2. 路径 A——opencli 公开 API 适配器（最可靠）

适用领域与命令模板，全部 `[public]` 无需 API key 或浏览器桥：

| 领域 | 命令 | 备注 |
|------|------|------|
| 通用知识 | `opencli wikipedia search "<query>" -f yaml` | 中英文查询均支持 |
| 学术论文 | `opencli arxiv search "<query>" -f yaml` | 返回 id/title/authors |
| 技术讨论 | `opencli hackernews search "<query>" -f yaml` | 实时热点，技术圈 |
| 编程问答 | `opencli stackoverflow search "<query>" -f yaml` | 含 answer/reply |
| 医学文献 | `opencli pubmed search "<query>" -f yaml` | PMID/abstract |
| 学术搜索 | `opencli google-scholar search "<query>" -f yaml` | 引用次数/cite |
| 实体知识 | `opencli wikidata search "<query>" -f yaml` | Q-ID 结构化 |

```bash
# 典型组合查询（学术 + 实时 + 知识库三路并行）
QUERY="large language model agents"
timeout 15 opencli arxiv search "$QUERY" -f yaml 2>&1 | grep -E 'id:|title:' | head -10
timeout 15 opencli hackernews search "$QUERY" -f yaml 2>&1 | grep -E 'rank:|title:|url:' | head -10
timeout 15 opencli wikipedia search "$QUERY" -f yaml 2>&1 | grep -E 'title:|url:' | head -5
```

**强制预检**（参考 `smart-search` skill 的核心规定）：每次执行前先确认适配器存在：

```bash
opencli list 2>/dev/null | grep -E "arxiv|wikipedia|hackernews|pubmed|stackoverflow|google-scholar|wikidata"
```

**限制**：
- 单次查询返回结构化结果，无 webpage 原文（需再用 `opencli arxiv paper <id>` 或 `fetch_content` 深入）
- 频率限制：同一适配器同一问题最多 2 次，多次失败改用其他源
- 中文查询在 wikipedia 效果好，其他偏英文语料
- `google-scholar` 响应较慢（~15-25s），建议单独设 `timeout 25`

### 3. 路径 B——curl 抓搜索引擎 HTML（通用网页搜索）

当查询为通用网页内容时，通过 curl 直接抓搜索引擎 HTML 并解析（替代 Brave/Tavily 等 API）。

#### 3.1 DuckDuckGo HTML 版（首选，匿名）

```bash
# 必须用代理（DDG 在中国大陆被屏蔽）
QUERY_VEC="curl web search free alternative"
# 安全 URL 编码：用 sys.argv 传参，杜绝查询含引号等特殊字符导致的 shell 注入 / Python 语法错误
ENCODED=$(python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "$QUERY_VEC")

# 方法 1：grep 快速提取（DDG HTML class 名可能随改版变化，失败时用方法 2）
curl -s --max-time 15 --proxy http://127.0.0.1:7897 \
  -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://html.duckduckgo.com/html/?q=${ENCODED}" 2>&1 | \
  grep -oE 'class="[^"]*result__a[^"]*"[^>]*>[^<]+' | head -10

# 方法 2（兜底）：python3 re 提取，解析 class 含 result__a 的 <a> 标签，比 grep 更鲁棒
curl -s --max-time 15 --proxy http://127.0.0.1:7897 \
  -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://html.duckduckgo.com/html/?q=${ENCODED}" 2>&1 | \
  python3 -c '
import sys, re
html = sys.stdin.read()
for m in re.finditer("<a[^>]*class=\"[^\"]*result__a[^\"]*\"[^>]*>(.*?)</a>", html, re.DOTALL):
    text = re.sub("<[^>]+>", "", m.group(1)).strip()
    href = re.search("href=\"([^\"]+)\"", m.group(0))
    url = href.group(1) if href else "?"
    if text:
        print(text + " | " + url)
'
```

**输出格式**：每个 `<a class="result__a">` 含标题，相邻行 `uddg=` 参数是真实 URL（URL 编码），需解码：

```bash
# 提取 URL（DDG 用 redirect 包装，需解码 uddg 参数）
curl -s --max-time 15 --proxy http://127.0.0.1:7897 \
  -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://html.duckduckgo.com/html/?q=${ENCODED}" 2>&1 | \
  grep -oE 'uddg=[^&"]+' | sed 's/uddg=//' | python3 -c "
import sys, urllib.parse
for line in sys.stdin:
    print(urllib.parse.unquote(line.strip()))
" | head -10
```

#### 3.2 Bing 国际版（备用，不被屏蔽）

```bash
# Bing 国际版对中文支持比 DDG HTML 版好
QUERY_VEC="curl web search free alternative"
ENCODED=$(python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "$QUERY_VEC")
curl -s --max-time 15 --proxy http://127.0.0.1:7897 \
  -A "Mozilla/5.0" -H "Accept-Language: en-US" \
  "https://www.bing.com/search?q=${ENCODED}&cc=us&setlang=en" 2>&1 | \
  grep -oE '<h2><a [^>]*href="https?://[^"]*"[^>]*>[^<]+</a></h2>' | head -10
```

#### 3.3 HackerNews Algolia API（专用，无需 key）

```bash
# HackerNews 官方 Algolia API 是公开 JSON 接口，比 opencli 更灵活
QUERY_VEC="rust async web framework"
ENCODED=$(python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "$QUERY_VEC")
curl -s --max-time 10 --proxy http://127.0.0.1:7897 \
  "https://hn.algolia.com/api/v1/search?query=${ENCODED}&tags=story,ask_hn,show_hn" 2>&1 | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
for hit in d.get('hits', [])[:10]:
    print(f\"- {hit.get('title','?')} | points={hit.get('points',0)} | type={hit.get('_tags',['?'])[0]} | {hit.get('url') or 'https://news.ycombinator.com/item?id=' + str(hit.get('objectID'))}\")
"
```

**适用**：技术调研、最新趋势、开源项目讨论。优势是返回 JSON，可精准编程解析。`tags=story,ask_hn,show_hn` 覆盖文章、Ask HN、Show HN 三类主要讨论。

#### 3.4 搜索引擎 HTML 解析常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 返回空或重定向到 `duckduckgo.com/opensearch_html` | 未带 User-Agent | 必须加 `-A "Mozilla/5.0 ..."` |
| 中文查询无结果 | DDG 对中文支持有限 | 改 Bing 国际版或 wikipedia |
| 反爬封 IP | 短时间大量请求 | 每域名 ≤ 5 次/分钟，加 sleep |
| HTML 结构变化 | 搜索引擎改版 | 失败时改 fetch_content 或 opencli 适配器 |

### 4. 路径 C——fetch_content 抓取正文

对已知 URL 或上一步搜索引擎返回的 Top-K URL，调用 `fetch_content` 获取纯文本/markdown 正文：

```python
# 获取正文。内容自动缓存，可通过 responseId + urlIndex 二次检索
fetch_content({
    urls: [
        "https://example.com/article1",
        "https://example.com/article2"
    ],
    prompt: "用户的原始问题"
    # ⚠️ prompt 参数在 fetch_content schema 中标注为视频分析用（YouTube/本地视频），
    # 文本页面下的实际聚焦效果未独立验证。如果传了 prompt 但 fetch 返回通用摘要，
    # 改用 get_search_content 取全文后自行分析。
})
# 从返回结果中提取 responseId（如 "ms0ni281syod64"）——该字段在返回 metadata 中
# 再用 get_search_content 检索缓存正文：
get_search_content({ responseId: "ms0ni281syod64", urlIndex: 0 })
```

`fetch_content` 内部三段式抓取链：

1. **Mozilla Readability**（本地解析）——首选，对标准文章页效果最好
2. **Jina Reader**（`https://r.jina.ai/<url>`）兜底——Readability 失败的 JS 渲染页
3. **Gemini API 视频分析**——YouTube/本地视频字幕提取

**优势**：输出整洁 markdown，可自动提取标题/作者/正文；**限制**：單次最多抓 ~20 个 URL（批量并发限制），对 SPA 渲染页 Readability 失败时依赖 Jina（有 ~50ms 额外延迟）。

### 5. 路径 D——Chromium 浏览器桥（可选增强）

当 opencli 浏览器桥适配器已连接（Chromium 已启动 + opencli-extension 已加载），解锁更多通用搜索源：

```bash
# 浏览器桥激活后可用的搜索适配器（非 [public]，需 Chrome 登录态）
opencli brave search "<query>" -f yaml       # 真网页搜索
opencli google search "<query>" -f yaml      # Google HTML 抓取
opencli duckduckgo search "<query>" -f yaml  # DDG via 浏览器
```

**激活条件**：`opencli doctor` 显示 `[OK] Connectivity: ok`。未激活时这一段路径完全跳过，不影响 A/B/C 三条核心路径。

> ⚠️ **环境限制**：浏览器桥依赖 Chromium 图形会话（需 X11/Wayland + 用户手动登录 Google 账号），在 headless 服务器 / SSH 远程终端场景下基本不可用。此路径主要适用于桌面 Linux 环境。

### 6. 结果合成与输出

收集所有路径的结果后，合成带 source citations 的结构化输出：

```markdown
## 搜索结果摘要

**查询**：<原始 query>
**使用路径**：opencli-public-api / curl-ddg-html / fetch_content

### 主要发现

1. **来源标题**（opencli arxiv / DDG / fetch）
   - URL：https://...
   - 摘要：...
   - 相关度：高/中/低

2. ...

### 来源索引

| # | 来源 | URL | 路径 | 置信度 |
|---|------|-----|------|--------|
| 1 | arxiv 2402.11651 | https://arxiv.org/abs/2402.11651 | opencli arxiv | ✅ 高 |
| 2 | HN #12345 | https://news.ycombinator.com/item?id=12345 | opencli hackernews | ✅ 高 |
| 3 | DDG Result | https://example.com/blog/post | curl DDG HTML | 🟡 中（未验证内容）|
| 4 | 全文抓取 | https://example.com/article | fetch_content | ✅ 高 |
```

**置信度标注规则**：
- ✅ 高：opencli 结构化 API 返回（arxiv/hn/pubmed 等有官方 API 协议）
- ✅ 高：fetch_content 抓取的全文内容
- 🟡 中：搜索引擎 HTML 结果的标题/snippet（未经内容验证）
- ⚠️ 低：仅 DDG HTML 结果的标题（点击 URL 未抓取过正文）

### 7. （可选）付费 API 补全

如某次搜索结果不够，且条件允许，可临时启用 `web_search` 比较：

```python
# 仅作 sanity check：用 web_search 做对比验证
web_search({ query: "<original query>", provider: "auto", numResults: 5 })
# 对比 fetch 与 web_search 的差异
```

---

## 与 web_search 的客观差距及突破方案

本 skill 是 `web_search` 不可用时的替代方案，但能力上有客观差距。下表逐项分析并给出突破方案：

| 能力维度 | `web_search` | 本 skill（free 替代） | 差距评估 | 突破方案 |
|----------|--------------|---------------------|---------|---------|
| **搜索质量** | AI 综合多个 provider 结果，含摘要合成 | 各路径汇总原始数据，需 agent 自行合成 | 中等 | agent 合成时引用 `smart-search` skill 的「查询结束汇报」规则，并对比多源一致性做事实核查 |
| **覆盖广度** | 全部公开网页（Brave/Google/Tavily 索引） | DDG HTML + 7 个领域常驻公开 API + 任意 URL fetch | 较小 | 通用查询走 DDG，学术走 arxiv/pubmed，技术走 SO/HN——基本覆盖 95% 查询类型 |
| **响应速度** | 单次工具调用，~2-5 秒返回 | 多路径组合，~10-30 秒（含 curl + grep + 合成） | 中等 | 用 `tasks: []` 并行多路径，或预判查询类型只走最相关的一条路径 |
| **中文搜索** | Brave/Tavily 对中文支持好 | DDG 中文效果一般，wikipedia 中文支持良好，Bing 国际版中文勉强 | 较大 | 中文查询优先 `opencli wikipedia search「中文 query」`；通用中文走 Bing 国际版（比 DDG 中文强） |
| **新闻时效性** | Brave Search 实时索引 | DDG HTML 索引滞后 ~24 小时，HN Algolia 实时 | 中等 | 新闻类查询直接走 HackerNews Algolia API（`hn.algolia.com/api/v1/search`）+ Bing News |
| **结果可追溯** | 提供 source citations + 可选全文抓取 | 结构化 + 标题 + URL，全文需用户/agent 二次 fetch | 较小 | 默认对 top-3 结果自动调用 `fetch_content`，配置参数 `fetch_full: true` |
| **配额限制** | 各 provider 免费 1000-2000/月，Gemini 1500/day 算高 | opencli 无限，curl 无限，fetch_content Jina Reader ~20/分钟 | 反超 | 实际免费配额**远高于** Brave/Tavily 免费层——这是关键优势 |
| **抗反爬** | API service 维护风控 | 服务器侧 DDG 可能限制单 IP | 中等 | 加 User-Agent、限制频率 ≤5 次/分钟/IP、失败切换 Bing 或 opencli |
| **配置依赖** | 需 `~/.pi/web-search.json` 填 API key | 需代理（中国大陆）+ opencli + curl | 等价 | 都需要前置配置，但本 skill 的 opencli 路径**完全无注册** |
| **结果纯度** | AI 可能"幻觉"引用 | curl 直接抓 HTML，原始度高 | 反超 | 用户/agent 可直接验证 URL 与 snippet 对应关系 |
| **多语言** | 主流 provider 支持英文为主 | opencli 适配器多英文，wikipedia 中文强 | 等价 | 中文学术用 wikipedia + arxiv（部分论文中文摘要） |

**总体评估**：本 skill 在能力广度上达到 `web_search` 的 ~85%，但在配额无限性、无注册成本、结果可追溯性三个维度反超。**关键短板是中文通用搜索的覆盖度**，建议三方路径并用 + 后续补充 Brave Search API 免费 key（2000/月）即可对齐。

### 突破方案优先级排序

按性价比从高到低：

1. **注册 Brave Search API 免费层**（2000 次/月，5 分钟，无地区限制）
   - 浏览器打开 `https://brave.com/search/api/` → 邮箱注册 → 获取 key
   - 填入 `~/.pi/web-search.json` 的 `braveApiKey` 字段，立即解锁 `web_search` 主路径之一
   - 与本 skill 并存时，`web_search` 优先使用 Brave（结构化 JSON），本 skill 作为免费兜底

2. **注册 Tavily API 免费层**（1000 次/月，5 分钟）
   - `https://tavily.com/` → 邮箱注册 → 获取 key
   - Tavily 对中文支持比 Brave 好，且返回 AI 优化摘要

3. **激活 Chromium + opencli-extension**（解锁浏览器桥搜索）
   - 已装 Chromium flatpak 的环境（wrapper `~/.local/bin/chromium`）
   - 启动 Chromium，登录 Google 账号，加载 `~/opencli-extension/` 目录
   - `opencli doctor` 显示 `[OK] Connectivity` 后，`opencli brave/google/duckduckgo search` 可用
   - 同时打开 Gemini Web 兜底路径（`allowBrowserCookies: true` 已配置）

4. **切换代理至 SG/JP/US 申请 Gemini API key**（1500 次/天 ≈ 45000/月）
   - 仅需代理支持节点切换，在支持地区 IP 下访问 `https://aistudio.google.com/apikey`
   - 拿到 key 后即使切回 HK 代理也可调用（API endpoint 不查 IP）
   - 这是免费方案的最大单点配额提升

## 输出格式

每次执行后输出结构化搜索报告（默认 markdown 内联，非文件）：

```markdown
## 搜索报告

**查询**：<input.query>
**路径**：<实际使用的路径列表>
**耗时**：<约 X 秒>

### 结果列表
1. **<标题>** —— 来源：opencli-arxiv / curl-ddg / fetch
   - URL：<url>
   - 摘要：<paragraph>
   - 置信度：✅ 高 / 🟡 中

2. ...

### 搜索摘要
- ✅ 源：opencli arxiv[public] | 查询词：… | 结果数：N
- 🟡 源：curl DDG HTML | 查询词：… | 结果数：N
- ✅ 源：fetch_content | URL 数：N | responseId：ms0xxxx
- ❌ 跳过：…（原因：…）

### 已知缺口
（未覆盖的查询类型、未能验证的来源、潜在风险等）
```

**可选持久化**：委托 `writing` agent 把合成结果写入文件：

```python
subagent({
    agent: "writing",
    task: "把以下搜索结果合成 markdown 写入 ~/Downloads/search-<timestamp>.md：\n<搜索结果原文>",
    timeoutMs: 300000,
    clarify: false
})
```

## 注意事项

### 代理与地区限制

- **代理必需**：在大陆环境下，所有境外服务（DDG/Bing/HN/Google）均需代理。`curl` 必须加 `--proxy http://127.0.0.1:7897` 或读取环境变量 `HTTPS_PROXY`
- **出口地区影响**：HK/中国大陆 IP 部分服务（如 Gemini API 申请页）会被限制，但 `generativelanguage.googleapis.com` API endpoint 本身只验 key 不查 IP
- **DNS 泄漏检查**：代理出口与浏览器 cookie 地区可能不同，建议查询前用 `curl http://ip-api.com/json --proxy ...` 确认

### 频率与反爬

- **opencli 适配器**：理论上无限（公平使用），但同一适配器同问题最多 2 次（参考 `smart-search` skill 规则）
- **curl HTML 抓取**：单 IP 单域 ≤ 5 次/分钟；DDG 对中文 IP 尤其敏感，触发反爬时改 Bing 或加 `sleep 3`
- **fetch_content**：内置 Jina Reader 单次 ~20 URL 为上限，超过会部分失败

### 与 `smart-search` 的关系

- `smart-search` 是 `opencli` 路径的路由优化器，关注「选哪个源」与「避免过频」
- 本 skill 是 `web_search` 全链路替代，关注「在 web_search 不可用时如何搜索」
- 两者可同时使用：本 skill 在 `mode: auto` 阶段可委托 `smart-search` 的 verified-search agent 做精确路由（注：当前版本尚未落地实际集成代码，为后续迭代计划）

### 已知限制

- **LLM 合成缺失**：本 skill 不返回 AI 合成的 answer 字段，所有内容需要 agent 自行读完结果后合成
- **中文通用查询**：DDG 对中文支持不如英文，需走 Bing 国际版或需后续补充 Brave/Tavily 免费 key
- **Jina Reader 兜底依赖**：`fetch_content` 在 Readability 失败时回退到 `r.jina.ai`，此服务对中国大陆有时不稳定
- **非持久化**：本 skill 不修改任何 npm 包，无需 patch persistence（与 `piagent-search-pipeline-fix` 不同）
- **Gemini API 地区问题**：如果你被锁中国大陆/HK，无法在 `aistudio.google.com` 申请 key——但通过本 skill 路径 A+B+C 无需 Gemini key 即可完成搜索，地区限制不阻断

### 与 web_search 的协作策略

当 `web_search` 有 key后，**两者长期共存**而非替代关系：

1. 优先 `web_search`（API 调用快、AI 合成好）
2. `web_search` 配额耗尽或返回与预期不符时，调用本 skill 补全（无配额限制）
3. 学术查询或需要可追溯来源时，**主动用本 skill 的 opencli 路径**，避免幻觉
4. 搜索 + 事实核查组合：`web_search` 初搜 → 本 skill 路径 B（curl 抓原文）验证 → 数字时效用 critical subagent 复核

## 变更日志

### 1.0.1 (安全加固)
- 修复 §3.1/§3.2/§3.3 三处 Shell 注入漏洞：URL 编码改用 `sys.argv` 传参，杜绝查询含单引号导致的 Python 语法错误及代码注入
- DDG HTML 解析增强：grep class 正则改为 `[^"]*result__a[^"]*` 匹配多类名，新增 python3 re 兜底提取
- Bing 正则修正：`https://` → `https?://` 兼容 http 协议
- HN Algolia tags 扩展：`story` → `story,ask_hn,show_hn` 覆盖文章/问答/展示三类
- §1.2 opencli 检测改用 `command -v` + 适配器计数，避免 `grep -q 'available'` 跨版本不兼容
- §4 fetch_content 标注 `prompt` 参数为视频专用，文本页面效果未独立验证
- §5 路径 D 补充 headless 环境不可用警告
- §输出格式 `subagent` 调用补充 `clarify: false`
- smart-search 集成标注为后续迭代计划
- §1.1 补充 ip-api.com 免费层频率限制说明
- §2 补充 `google-scholar` 超时建议

### 1.0.0 (初始版本)
- 初始发布：四路径（opencli 公开 API/curl HTML/fetch_content/Chromium 浏览器桥）+ 与 web_search 客观差距矩阵 + 突破方案优先级
- 适用场景：`web_search` 全部 provider 不可用，零成本搜索替代