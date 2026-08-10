---
name: tor-browser-check-and-fix
version: 1.0.0
description: 检查 Tor Browser 配置与连通性，定位 bootstrap 失败根因（IPv6 bridge、代理类型、直连封锁），修复 torrc 并经真实 tor 内核实测验证至 100%
triggers:
  - "tor浏览器用不了"
  - "tor无法连接"
  - "tor bootstrap失败"
  - "tor连不上网络"
  - "tor修复"
  - "tor bridge"
  - "tor检查"
inputs:
  - name: tor_browser_dir
    description: Tor Browser 安装目录
    required: false
    default: ~/tor-browser
  - name: proxy_addr
    description: 本地代理地址（Clash/mihomo 混合端口）
    required: false
    default: 127.0.0.1:7897
  - name: fix_mode
    description: 修复模式: ask（先问后改）, auto（直接修复）, report（仅诊断不改）
    required: false
    default: "ask"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
  - ls
  - ask_user
---

# Tor 浏览器检查与修复 Skill

本 skill 基于 2026-08-05 实测结论（tor 0.4.9.11 + Clash Verge mihomo 组合，封锁网络环境）。核心发现：**`HTTPSProxy` + IPv4 obfs4 bridge 可用（30 秒 bootstrap 100%）；IPv6 bridge 与 `Socks5Proxy` 均实测失败**。

## 任务目标

检查 Tor Browser 安装与 torrc 配置，诊断 bootstrap 失败根因，修复配置并经真实 tor 内核实测验证至 100%。验证全程用临时 DataDirectory，不改动用户数据目录。

## 遵守的偏好

- **⑧ 永不覆写** — torrc 修改用 `edit`；改前必备份（`cp torrc torrc.bak.$(date +%Y%m%d_%H%M%S)`）
- **ask_user 高优先级** — 凡写操作之前，先示变更摘要，征求明确同意；`fix_mode: auto` 者除外

## 执行流程

以下命令中 `$TOR_BROWSER_DIR` 取 inputs 之 `tor_browser_dir`，`{proxy_addr}` 取 `proxy_addr`，`{fix_mode}` 取 `fix_mode`。

### 1. 收集现状（无写操作）

并行执行以下检查：

```bash
# 安装与进程
ls "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/" 2>/dev/null
pgrep -af "tor-browser|Tor/tor" | grep -v grep
# 代理状态
env | grep -i -E "proxy|socks"
ss -tlnp 2>/dev/null | grep -E "7897|9050"
# 系统 tor 服务
systemctl status tor --no-pager 2>/dev/null | head -5
```

读关键文件：

```bash
read "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc"
read "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc.bak"   # 若存在
```

### 2. 诊断根因

按判定表逐项核对：

| 现象 | 判定 | 处置 |
|---|---|---|
| `DisableNetwork 1` | 正常（浏览器退出时写入，启动时清零） | 勿动 |
| bridge 行皆为 `[IPv6地址]` | **死因 #1**：本机无 IPv6 直连，mihomo 拒 IPv6 目标 | 换 IPv4 bridges |
| 代理行为 `Socks5Proxy` | **死因 #2**：实测 Socks5Proxy 经 mihomo 全失败 | 改回 `HTTPSProxy` |
| 无 `HTTPSProxy` 行 | **死因 #3**：Tor 不认系统代理环境变量，直连被墙 | 增 `HTTPSProxy {proxy_addr}` |
| 直连超时 | `curl --noproxy '*' --connect-timeout 8 https://{bridge_ip}:{port}` 返回 000 超时 → 被墙属常态 | 须经代理 |
| 代理可达 | `curl -x http://{proxy_addr} --connect-timeout 8 https://{bridge_ip}:{port}` 见 `Connection established` → 代理通 | 可继续 |

IPv6 bridge 检测：

```bash
grep -E "^Bridge" "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc" | grep -cE "\[[0-9a-fA-F:]+\]"
# 输出 > 0 即存在 IPv6 bridge
```

### 3. 修复 torrc

1. 备份：

```bash
cp "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc" "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc.bak.$(date +%Y%m%d_%H%M%S)"
```

2. 取可用 IPv4 obfs4 bridge（依序）：
   - `torrc.bak` 内历史 IPv4 bridge（先验证可达）
   - 经代理自 `https://bridges.torproject.org/bridges?transport=obfs4` 申请新 bridge
3. 用 `edit` 将 IPv6 bridge 行替换为 IPv4 bridge 行；保留 `UseBridges 1` 与 `HTTPSProxy {proxy_addr}`
4. 若缺 `HTTPSProxy` 行，追加 `HTTPSProxy {proxy_addr}`（**禁加 `Socks5Proxy`**）
5. `fix_mode: ask` 时先示 diff 摘要，ask_user 确认后生效；`auto` 直接执行

### 4. 实测验证（不动用户数据）

于 Browser 目录以临时 DataDirectory 启动 bundled tor。注意三点：插件路径相对 Browser 目录（须先 `cd`）、`LD_LIBRARY_PATH` 须指 Tor 目录、`SocksPort` 避开 9050 冲突：

```bash
cd "$TOR_BROWSER_DIR/Browser"
export LD_LIBRARY_PATH="$TOR_BROWSER_DIR/Browser/TorBrowser/Tor"
DEFAULTS="$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc-defaults"
TMPDIR=$(mktemp -d)
timeout 90 ./TorBrowser/Tor/tor --defaults-torrc "$DEFAULTS" \
  -f "$TOR_BROWSER_DIR/Browser/TorBrowser/Data/Tor/torrc" \
  --DataDirectory "$TMPDIR" --DisableNetwork 0 --SocksPort 19150 \
  2>&1 | grep -E "Bootstrapped" | tail -8
rm -rf "$TMPDIR"
```

判定：

| 日志特征 | 结论 |
|---|---|
| `Bootstrapped 100% (done)` | 修复成功 |
| `general SOCKS server failure` 伴 IPv6 地址 | bridge 仍为 IPv6，回第 3 步 |
| `no configured transport called` | 未加载 `torrc-defaults` 或 CWD 错误 |
| `Address already in use` | SocksPort 冲突，换端口 |

（可选）经 mihomo unix socket 确认流量过代理：

```bash
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/connections 2>/dev/null | grep -E "9100|443"
```

### 5. 收尾与总结

1. 确认无残留进程：`pgrep -af "Tor/tor" | grep -v grep || echo clean`
2. 输出报告（见「输出格式」）
3. 告知用户启动方式：`"$TOR_BROWSER_DIR/start-tor-browser.desktop"`

## 输出格式

诊断与修复报告，形如：

```text
━━━━━ Tor 浏览器检查报告 ━━━━━
📋 现状：Tor Browser 15.0.17 @ ~/tor-browser ｜ tor 进程：无 ｜ 代理：7897 正常
🔍 诊断：2 个 IPv6 obfs4 bridge → mihomo 拒 IPv6 目标（general SOCKS server failure）
🔧 修复：换为 IPv4 bridges（144.172.92.216:9100 / 185.85.87.222:443），保留 HTTPSProxy 127.0.0.1:7897
✅ 验证：Bootstrapped 100% (done) 用时 30s
📌 提醒：bridge 可能被周期性封锁，失效时经代理至 bridges.torproject.org 申请新 IPv4 bridge
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 注意事项

1. **IPv6 bridge 禁用** — 本机无 IPv6 直连且 mihomo 拒 IPv6 目标（纵 `ipv6: true`），凡 IPv6 bridge 一律换 IPv4
2. **禁 `Socks5Proxy`** — 实测经 mihomo 混合端口 SOCKS5 通道全失败；惟 `HTTPSProxy` 可用
3. **Tor 不认系统代理** — 环境变量 `ALL_PROXY`/`http_proxy` 对 tor 无效，须 torrc 显式配置
4. **直连必被墙** — 封锁网络下直连 bridge 超时属常态，勿据此判 bridge 死亡
5. **`DisableNetwork 1` 属正常** — 浏览器退出时写入，启动时清零；验证时用 `--DisableNetwork 0` 覆盖
6. **端口冲突** — 系统 `tor.service` 占 9050 时，测试用 `--SocksPort` 换端口
7. **插件路径相对 CWD** — bundled tor 须自 `Browser/` 目录启动，否则 lyrebird 加载失败（`terminated with status code 1`）
8. **隐私权衡** — Tor 经私人代理时，代理方可见「在用 Tor」（节点 IP/流量特征），但不可见内容；介意者须 TUN 模式 + 自建 bridge
9. **系统 tor.service 空转** — 无 bridge 无代理者 0 circuits 纯占资源，可 `sudo systemctl stop tor`
10. **bridge 生命周期** — obfs4 bridge 会被周期性封锁，连不上时先换新 bridge 再查他因
11. **写操作前备份** — 改 torrc 前必 `cp` 备份，遵循偏好 ⑧ 与 ask_user 流程

## 变更日志

### 1.0.0 (2026-08-05)
- 初始发布：基于 2026-08-05 实测（tor 0.4.9.11 + Clash Verge mihomo），固化诊断判定表与验证流程
- 关键实证：`HTTPSProxy` + IPv4 obfs4 bridges → bootstrap 100% 用时 30 秒；IPv6 bridges / `Socks5Proxy` → 失败
