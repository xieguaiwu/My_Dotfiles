---
name: clash-verge-diagnose-and-fix
version: 2.5.0
description: 诊断并修复 Clash Verge Rev 代理不工作问题（模式错误、Profile 增强格式错误、远程订阅失败、Hysteria2 DNS 死锁、导入 Profile 编辑不生效、AuthServer 拒绝连接、DoT fallback 被墙导致全代理 DNS 解析失败、单节点 IP 被墙/被干扰等）
triggers:
  - "clash verge 不工作"
  - "代理用不了"
  - "翻墙失败"
  - "梯子挂了"
  - "verge 代理失效"
  - "clash 配置问题"
  - "mihomo 代理"
  - "hysteria2 不通"
  - "hy2 连不上"
  - "profile 导入失败"
  - "clash-verge diagnose"
  - "auth 拒绝"
  - "密码错误连不上"
  - "账号被禁用"
  - "免费代理失效"
  - "免费池更新"
  - "代理测试"
  - "dns resolve failed"
  - "侧车日志解析失败"
  - "全代理超时"
  - "DoT fallback"
  - "节点被墙"
  - "IP 被墙"
  - "banner exchange"
  - "单节点超时"
inputs:
  - name: data_dir
    description: Clash Verge 数据目录路径
    required: false
    default: "$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
  - name: backup_dir
    description: 代理配置备份仓库路径（如有）
    required: false
    default: "$HOME/Desktop/recovery_and_token/proxy_bkup"
tools:
  - bash
  - read
  - write
  - edit
  - grep
  - subagent
---

# Clash Verge Rev 诊断与修复

## 任务目标

诊断并修复 Clash Verge Rev 中代理不工作的各类问题，涵盖：

1. **模式错误**：`mode: global` 且 GLOBAL 选择器为 DIRECT
2. **Profile 增强格式错误**：groups enhancement 格式错误导致整个 profile 合并静默失败
3. **远程订阅 URL 失效**：上游 URL 变更导致 404
4. **Hysteria2 UDP 协议 DNS 死锁**：DoH 在 Hysteria2 链路上不可用
5. **导入 Profile 编辑不生效**：拖入导入后 Verge 创建内部副本，原始文件修改无效
6. **profiles.yaml 编辑被覆盖**：Verge 启动时从内部状态重写，运行时编辑在下次启动丢失
7. **AuthServer 拒绝连接**：用户禁用/到期/超流量/密码不匹配导致 Hysteria2 认证失败
8. **DoT fallback 被墙**：DNS fallback 使用 `tls://8.8.8.8` 等 DoT（853 端口）在大陆被墙，导致所有非 CN 域名 DNS 解析失败、全代理瘫痪

---

## 背景知识：Clash Verge Rev 架构

### 版本差异（重要）

| 行为 | 2.4.7（旧） | 2.5.2（新） |
|---|---|---|
| `mode` 设置 | 默认 `global`，需手动切换 | 可持久化 `rule` |
| GLOBAL 选择器 | 启动后可能重置为 DIRECT | 持久化上次选择 |
| 验证失败处理 | 静默丢弃 profile | 同上 |
| profiles.yaml 运行时编辑 | 被周期性覆盖 | **运行时持久化**，启动时仍会覆盖 |
| Profile 增强格式容错 | 严格 | 更宽松（空 groups 不报错） |

### 文件结构与数据流

```text
~/.local/share/io.github.clash-verge-rev.clash-verge-rev/
├── profiles.yaml           # ⚠️ 启动时被 Verge 从内部状态重写！运行时编辑可持久
├── verge.yaml              # Verge GUI 设置（不影响代理路由）
├── clash-verge.yaml        # 生成文件——Verge 合并所有 profile 后生成
├── profiles/               # Profile 缓存 + 增强文件
│   ├── {uid}.yaml          # 远程订阅缓存 或 导入后的内部副本
│   └── {uid}.yaml          # Profile Enhancement
├── logs/
│   ├── latest.log          # Verge 应用日志（验证错误在这里）
│   └── sidecar/            # mihomo 内核日志（连接错误在这里）
├── cache.db                # BoltDB——仅存 selected 状态，非 profile 数据源
└── localstorage/           # WebKit localStorage（前端 UI 状态）
```

### 关键规则

1. **`clash-verge.yaml` 是生成文件**。手动编辑仅当前会话有效，重启 / 切换 profile 后覆盖。
2. **`profiles.yaml` 运行时编辑会持久，但启动时被重写**。在 Verge 运行期间修改可存活数小时，但下次启动恢复原状。
3. **拖入导入 Profile 时 Verge 创建内部副本**（新 UID + 新文件名如 `Lt3Ic0l85eT1.yaml`），原始文件的后续编辑**不会传递到副本**。
4. **Profile 增强格式错误 → 整个 profile 静默丢弃**。错误信息在 `logs/latest.log`。
5. **`cache.db` 是 BoltDB 格式**（非 SQLite），仅存 selected 代理状态，与 profile 列表无关。
6. **Hysteria2 等 UDP 协议不能使用 DoH 作为 DNS**——连接建立前 DNS 不可达。

### Mihomo Unix Socket API

```bash
# 查询所有代理 / 选择器状态
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/proxies

# 查询单个代理组
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/proxies/GLOBAL

# 切换选择器
curl -s --unix-socket /tmp/verge/verge-mihomo.sock -X PUT \
  http://localhost/proxies/{groupName} \
  -H "Content-Type: application/json" -d '{"name":"{proxyName}"}'

# 强制重载配置（需配合已写好的 clash-verge.yaml）
curl -s --unix-socket /tmp/verge/verge-mihomo.sock -X PUT \
  "http://localhost/configs?force=true" \
  -H "Content-Type: application/json" \
  -d '{"path":"/path/to/clash-verge.yaml"}'
```

---

## 执行流程

### Phase 1：快速诊断

```bash
# 1.1 mihomo 状态（最关键）
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/proxies 2>/dev/null | \
  python3 -c "
import json, sys
d = json.load(sys.stdin)
proxies = d.get('proxies', {})
for k, v in sorted(proxies.items()):
    t = v.get('type', '?')
    if t in ('Selector', 'URLTest', 'Fallback'):
        all_list = v.get('all', [])
        print(f'  [{t}] {k}: now={v.get(\"now\",\"?\")}  all({len(all_list)})')
print(f'Total proxies: {len(proxies)}')
"

# 1.2 验证日志 + mihomo 内核日志
grep -i "error\|fail\|test failed\|duplicate" {data_dir}/logs/latest.log 2>/dev/null | tail -5
tail -5 {data_dir}/logs/sidecar/sidecar_latest.log 2>/dev/null

# 1.3 端口 + 系统代理
ss -tlnp | grep -E "7897|7890" | head -3
env | grep -i proxy | sort | head -5

# 1.4 连通性
curl -x http://127.0.0.1:7897 -so /dev/null -w "Google: %{http_code} %{time_total}s\n" --connect-timeout 10 https://www.google.com
```

### Phase 2：根据诊断分类修复

#### 场景 A：GLOBAL→DIRECT，代理总数 < 10

**症状**：`GLOBAL: now=DIRECT, all=['DIRECT', 'REJECT']`，Google 超时。

**修复**（立即生效）：
```bash
# API 切换 GLOBAL
curl -s --unix-socket /tmp/verge/verge-mihomo.sock -X PUT \
  http://localhost/proxies/GLOBAL \
  -H "Content-Type: application/json" -d '{"name":"你的代理组名"}'
```

**永久修复**：Verge UI → 设置 → 代理模式 → 切换为「规则」。

#### 场景 B：Profile 验证失败，代理组完全丢失

**症状**：日志有 `test failed`、`unset fields: type`、`duplicate group name`。

**根因**：Profile Enhancement（特别是 groups）格式错误。

**修复**：
1. 清空出错的 enhancement 文件
2. 从订阅缓存直接构建 clash-verge.yaml（见 Phase 3 紧急修复）
3. 通过 API 强制重载

**常见格式错误**：
- Groups 缺少 `type` → `unset fields: type`
- Groups 有 `type` 但同名 → `duplicate group name`
- 结论：在 2.4.7 和 2.5.2 中 groups enhancement 格式均不可靠，**不要使用 groups enhancement 注入自定义代理**。改为创建独立 local profile。

#### 场景 C：远程订阅 404

**症状**：`failed to fetch remote profile with status 404 Not Found`。

**修复**：
1. 确认新 URL：`curl -so /dev/null -w "%{http_code}" "新URL"`
2. 编辑 `profiles.yaml`（Verge 运行时进行，存活到下次重启）
3. **最终需在 Verge UI 中修改**才能持久化：右键订阅 → Edit → 改 URL + Name

#### 场景 D：节点不可用

**症状**：HTTP 正常但 HTTPS 超时。

**诊断**：
```bash
for host in "hk1.jiedian.stream" "sg1.jiedian.stream"; do
  echo "--- $host ---"
  timeout 3 bash -c "echo | openssl s_client -connect ${host}:443 -servername gw.alicdn.com 2>&1" | \
    grep -E "Connecting|CONNECTED|error" | head -2
done
```

#### 场景 E：Hysteria2 / UDP 协议代理不通（新增）

**症状**：Hysteria2 profile 已加载、GLOBAL 正确，但所有站点超时。sidecar 日志显示 `dns resolve failed: couldn't find ip`。

**根因**：Hysteria2 是 UDP 协议。使用 DoH（`https://doh.pub/dns-query`）时，DNS 查询走代理，但代理需要 DNS 才能建立 QUIC 连接 → **DNS 死锁**。

**修复**：将 DNS 从 DoH 改为 UDP 直连：
```yaml
dns:
  enable: true
  enhanced-mode: fake-ip
  default-nameserver:
    - 223.5.5.5       # AliDNS，不走代理
    - 119.29.29.29
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1
```

**不要使用** `https://doh.pub/dns-query` 或 `tls://dot.pub` 作为 Hysteria2 profile 的 nameserver。

#### 场景 F：导入的 Profile 文件编辑不生效（新增）

**症状**：拖入导入 HY2 profile 后，编辑原始 `.yaml` 文件，但 Verge 仍使用旧配置。

**根因**：Verge 导入时创建内部副本（新 UID + 新文件名如 `Lt3Ic0l85eT1.yaml`），后续读取的是副本而非原始文件。

**诊断**：
```bash
# 找到导入后的实际文件
grep "hy2\|HY2" {data_dir}/profiles.yaml
# 输出类似: - uid: Lt3Ic0l85eT1
#           file: Lt3Ic0l85eT1.yaml   ← 这是实际生效的文件

# 检查实际文件内容
cat {data_dir}/profiles/Lt3Ic0l85eT1.yaml
```

**修复**：编辑副本文件（`{uid}.yaml`）而非原始文件。或删除后重新导入正确版本。

**最佳实践**：在导入前确保源文件完全正确，因为导入后修改需要找到 Verge 分配的随机 UID。

#### 场景 G：服务器配置变更导致过时备份失效（新增）

**症状**：使用备份仓库中的配置，代理不通。检查后发现端口、混淆等参数不匹配。

**教训**：
- 备份文件可能是历史版本，不代表当前服务器配置
- **始终先查阅权威配置文档**（如 `~/works/记录/vpn-setup-*.md`）
- HY2-LA-5TB 案例：备份中是端口 20000 + Salamander + 端口跳跃，服务器实际是端口 443 + 无混淆
- 修复方法：以服务器端配置文件（`/etc/hysteria/config.yaml`）为准，更新所有客户端配置

#### 场景 H：AuthServer 拒绝连接 — 密码/账号已失效

**症状**：Hysteria2 profile 已加载、GLOBAL 正确、DNS 未死锁，但所有站点超时。

**诊断（最快）**：
```bash
vpscap users    # 一行看到所有账户状态：active/expired/bw
```
多数"代理不通"运行这条命令就清楚原因——账户被禁用或到期。USERS.md 也会同步刷新到 `~/.local/share/vpscap/`。

**VPS 端诊断**：
```bash
# 检查 VPS 上 AuthServer 日志
ssh root@192.3.247.117 'journalctl -u hysteria-authserver --no-pager -n 20 | grep AUTH'
```

**典型日志与修复**：

| 日志关键词 | 含义 | 修复 |
|---|---|---|
| `is disabled` | 用户在 users.json 中 `active: false`（欠费/禁用） | `vpscap users toggle <id>` 重新启用 |
| `expired at` | 用户已到期 | `vpscap users renew <id> <date>` 续期 |
| `exceeded bandwidth limit` | 月流量用完 | `vpscap users reset-bw <id>` 重置 |
| `unknown password` | 密码不匹配——可能服务器已迁移到 HTTP auth 而你还在用旧共享密码 | **检查 YAML 中的 password 是否匹配当前分配的个人密码** |

**最常见场景**：服务器从固定密码模式（`auth.type: password`）迁移到 HTTP AuthServer 模式后，旧共享密码对应的用户被设为 `active: false`。此时：
1. 运行 `vpscap users` 确认你的用户状态
2. 检查 `~/.local/share/vpscap/USERS.md` 或 VPS `/etc/hysteria/users.json` 中你的用户密码
3. 更新本地 Clash Verge YAML 中的 `password` 字段为你的个人密码
4. 如果是导入的 Profile，记得编辑 Verge 生成的副本文件（`{uid}.yaml`），而非原始文件

**密码冲突（多用户同密码）**：
如果两个用户密码相同（如 yuyue 和 heyouxi 都是 `12345`），Hysteria2 的 legacy 认证模式下 AuthServer 返回第一个匹配用户，导致流量误计。**解决方案**：YAML 中使用 `userid:password` 协议格式（如 `yuyue:12345`）。AuthServer 会按 userid 精确匹配，确保流量正确归属。运行 `vpscap users` 时会自动检查密码唯一性。

#### 场景 I：免费代理池失效 — 批量测试与重新抓取

**症状**：免费代理池（`comprehensive-pool.yaml` / `l3Wief5Rt1cY.yaml`）中所有或大部分代理不可用。

**根因**：免费代理来源（snakem982/proxypool、ermaozi 等）的代理存活时间极短，通常在数小时到数天内失效。代理测试更新不及时，导致连接全部失败。

**测试方法**（50 并发 TCP 检测，~10 秒完成）：

```bash
# === 批量测试代理池连通性 ===
python3 << 'PYEOF'
import yaml, socket, ssl, concurrent.futures, time, os
from collections import Counter

POOL_PATH = os.path.expanduser("~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/comprehensive-pool.yaml")

with open(POOL_PATH) as f:
    data = yaml.safe_load(f)
proxies = data.get('proxies', [])

def test_proxy(p):
    server = p.get('server', '')
    port = int(p.get('port', 80))
    ptype = p.get('type', '?')
    tls_needed = p.get('tls', False) or ptype in ('trojan', 'anytls')
    sni = p.get('sni', server)
    # TCP 检测
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        if sock.connect_ex((server, port)) != 0:
            sock.close()
            return (False, "TCP closed", ptype)
        sock.close()
    except Exception as e:
        return (False, f"TCP err: {str(e)[:40]}", ptype)
    # TLS 检测（如需）
    if tls_needed:
        try:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            sock2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock2.settimeout(5)
            ssock = ctx.wrap_socket(sock2, server_hostname=sni)
            ssock.connect((server, port))
            ssock.close()
            return (True, "TLS OK", ptype)
        except Exception as e:
            return (False, f"TLS fail: {str(e)[:50]}", ptype)
    return (True, "TCP OK", ptype)

# 50 并发批量测试
results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
    fut_map = {executor.submit(test_proxy, p): p for p in proxies}
    for fut in concurrent.futures.as_completed(fut_map):
        results.append((fut_map[fut], fut.result()))

alive = [(p, r) for p, r in results if r[0]]
dead = [(p, r) for p, r in results if not r[0]]

print(f"Total: {len(proxies)} | Alive: {len(alive)} | Dead: {len(dead)}")
print(f"Alive by type: {dict(Counter(r[2] for _,r in alive).most_common())}")
PYEOF
```

**备份 & 更新流程**：

```bash
# 1. 备份原始文件
mkdir -p ~/Desktop/recovery_and_token/proxy_bkup/proxypool/
timestamp=$(date +%Y%m%d_%H%M%S)
cp ~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/comprehensive-pool.yaml \
  ~/Desktop/recovery_and_token/proxy_bkup/proxypool/comprehensive-pool_${timestamp}.yaml
cp ~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/l3Wief5Rt1cY.yaml \
  ~/Desktop/recovery_and_token/proxy_bkup/proxypool/l3Wief5Rt1cY_${timestamp}.yaml

# 2. 写入过滤后的（仅存活代理）YAML
# （接上面的 Python 脚本，使用 yaml.dump 写回）
new_data['proxies'] = [p for p, r in alive]
with open(POOL_PATH, 'w') as f:
    yaml.dump(new_data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

# 3. 同步更新 l3Wief5Rt1cY.yaml（同一池的两个副本）
L3_PATH = os.path.expanduser("~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/l3Wief5Rt1cY.yaml")
with open(L3_PATH) as f:
    l3data = yaml.safe_load(f)
l3data['proxies'] = [p for p, r in alive]
with open(L3_PATH, 'w') as f:
    yaml.dump(l3data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
```

**重新抓取免费代理池**（从上游来源下载最新代理）：

免费代理的来源通常是公共爬虫池，主要有两个更新方式：

**方式 A：从已知上游 URL 重新下载**

```bash
# snakem982/proxypool 的最新 clash-meta 格式代理
curl -sL https://raw.githubusercontent.com/snakem982/proxypool/main/source/clash-meta.yaml \
  -o ~/Desktop/recovery_and_token/proxy_bkup/proxypool/source/clash-meta-2.yaml

# ermaozi 的免费代理
curl -sL https://raw.githubusercontent.com/ermaozi/get_subscribe/main/output/clash.meta.yml \
  -o ~/Downloads/ermaozi_clash_meta.yaml
```

**方式 B：使用 proxypool 本地爬虫（如果源码完整）**

```bash
cd ~/Desktop/recovery_and_token/proxy_bkup/proxypool/
# 检查 spider 目录中的爬虫脚本
ls spider/
# 执行爬虫（如果有可执行脚本）
bash spider/fetch.sh 2>/dev/null || python3 spider/fetch.py 2>/dev/null
```

**方式 C：使用 opencli 适配器从公共 API 获取**

```bash
# 示例：通过 opencli 获取公开代理列表
opencli proxypool search "free" -f yaml 2>/dev/null
```

**组装新池**：下载到新文件后，用脚本合并去重：

```bash
python3 << 'PYEOF'
import yaml, glob

home = os.path.expanduser("~")
merge_dir = f"{home}/Downloads"
all_proxies = []
seen = set()

# 从多个来源文件合并
for f in glob.glob(f"{merge_dir}/*.yaml") + glob.glob(f"{merge_dir}/*.yml"):
    if 'ermaozi' in f or 'clash-meta' in f:
        with open(f) as fh:
            data = yaml.safe_load(fh)
            for p in data.get('proxies', []):
                key = f"{p.get('server','')}:{p.get('port','')}:{p.get('type','')}"
                if key not in seen:
                    seen.add(key)
                    all_proxies.append(p)

print(f"Merged: {len(all_proxies)} unique proxies")

# 写入 comprehensive-pool.yaml（保留原有 config）
pool_path = f"{home}/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/comprehensive-pool.yaml"
with open(pool_path) as f:
    pool = yaml.safe_load(f)
pool['proxies'] = all_proxies
with open(pool_path, 'w') as f:
    yaml.dump(pool, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
print(f"Written to {pool_path}")
PYEOF
```

**注意事项**：
1. 免费代理的特点就是**来得快、死得快**，定期测试 + 更新是常态。建议设置 cron 或看门狗每周自动更新。
2. 合并后的新池**强烈建议立刻跑一次连通性测试**（见上方 50 并发脚本），否则大量死代理会影响自动选择器的判断。
3. 如果某个付费机场服务可用，**优先用付费服务**——稳定性不在一个量级。
4. `comprehensive-pool.yaml` 和 `l3Wief5Rt1cY.yaml` 实质上是同一个池的两个副本，修改时要同步更新。

#### 场景 K：单节点 IP 被墙/被干扰 — 选择器正常但全连接超时（新增）

**症状**：GLOBAL/PROXY 选择正确、DNS 无 deadlock（无 `dns resolve failed`），但所有走代理的连接 `context deadline exceeded`（Google/B.AI 等全超时）；直连国内正常。

**根因**：代理节点服务器 IP 被 GFW 干扰/封锁（2026-09-02 HY2-LA-5TB/192.3.247.117 实战）。单节点（尤其 Hysteria2 UDP 单端口）抗封锁能力为零。

**判别特征（多证据组合，缺一不可）**：
```bash
# 1. ICMP 通（GFW 对 ICMP 放行）——排除服务器宕机
ping -c 3 -W 2 <VPS_IP>        # 通且 RTT 正常 = 服务器活着
# 2. TCP 采样不稳定——多采样必有通有不通
for i in 1 2 3; do timeout 4 bash -c "echo > /dev/tcp/<IP>/22" && echo 通 || echo 不通; done
# 3. SSH banner exchange timeout = GFW 对 SSH 主动干扰的经典特征
ssh -v root@<IP> 2>&1 | grep -E "banner|timed out"
# 4. UDP 无响应（HY2 主协议）
# 5. 对照测试：其他国外 IP（如 104.16.132.229:443 Cloudflare）能通 = 网络整体可用，单 IP 被墙
```

**注意**：TCP 443 `Connection refused` **不是**服务器挂掉的证据——HY2 只监听 UDP 443，TCP 无服务回 RST 是正常响应，恰好证明路径可达。

**修复**：不要试图在服务器端折腾（SSH 都不稳）——**切换备用订阅/节点**：
1. 盘点可用资源：其他 remote 订阅（`profiles.yaml` 里 type: remote）、免费池、本地 profile
2. 优先选**多节点订阅**（如性价比机场 12 节点）——url-test 自动选择天然抗单 IP 被墙
3. 按 Phase 3 直接构建 clash-verge.yaml（节点取订阅缓存 `profiles/{uid}.yaml`）+ API 强制重载，立即生效
4. 验证：节点 delay 测速 + curl Google/B.AI（网络层恢复的判据：B.AI 从 timeout 变为 401/403 即时响应）

**持久化**：改 `profiles.yaml` 的 `current` 字段运行时**不会被 Verge 响应**（实测 2.5.2 不 watch 文件，重启后从内部状态重写回旧值）→ 必须 UI 切换 profile 才能持久。

**教训**：单节点单点依赖风险高——主代理应保持一个多节点机场订阅兜底，节点 IP 被墙时立即切换，比等解封/换 IP 快得多。

#### 场景 J：DoT fallback 被墙 — 全代理 DNS 解析失败（新增）

**症状**：所有走代理的站点全部超时（Google/YouTube/github.com/B.AI 等），但国内站点（dashscope、百度）直连正常。mihomo 侧显示 GLOBAL/PROXY 选择正确，节点测速却 Timeout。

**根因**：clash-verge.yaml 的 `dns.fallback` 配置了 DoT（`tls://8.8.8.8` / `tls://1.1.1.1`，853 端口）。在大陆 853 端口被墙 → fake-ip 模式下非 CN 域名（nameserver 返回非 CN IP 触发 fallback-filter）全部 `dns resolve failed: couldn't find ip` → 代理链路 DNS 死锁。

**诊断**（sidecar 日志是关键）：
```bash
# 1. sidecar 日志——大量 "couldn't find ip" 而非连接错误
grep "dns resolve failed" {data_dir}/logs/sidecar/sidecar_latest.log | tail -10
# 2. 确认 DoT 被墙
timeout 5 bash -c "echo > /dev/tcp/8.8.8.8/853" && echo 通 || echo 不通
timeout 5 bash -c "echo > /dev/tcp/1.1.1.1/853" && echo 通 || echo 不通
# 3. UDP 53 通常可达
timeout 5 bash -c "echo -n x | nc -u -w 3 8.8.8.8 53" && echo 通 || echo 不通
```

**修复**（fallback 从 DoT 改为 UDP 53）：
```yaml
dns:
  ...
  fallback:
    - 8.8.8.8
    - 1.1.1.1
```

1. 紧急：改 `clash-verge.yaml`（生成文件，仅当前会话）+ API 强制重载
2. 持久化：同步修改 profile 源文件（`profiles/hy2-standalone.yaml`、导入的副本 `{uid}.yaml`），否则 Verge 重启后回退
3. 验证：`/proxies/{node}/delay` 测速 + curl Google

**注意**：
- **Hysteria2 是 UDP 协议**——用 `echo > /dev/tcp/host/443` 测 TCP 443 不通是正常的（预期），别误判服务器挂了。检查服务器监听用 `ss -ulnp`（UDP 监听），不是 `ss -tlnp`。
- 服务器侧诊断：`sshpass -p '<pwd>' ssh root@<vps> 'ss -ulnp | grep hysteria'`（vpscap config.json 里有密码），hysteria-server systemd 服务 active 且 UDP 监听 = 服务器正常，问题在本机 DNS。
- 现象迷惑性：国内域名直连正常（走 223.5.5.5），易误判为"国内没事、只是国外/代理的问题"。

### Phase 3：紧急修复 — 直接构建 clash-verge.yaml

当 profile 合并失败且不能重启 Verge 时：

```python
import yaml, subprocess

data_dir = '{data_dir}'
profile_uid = 'Lt3Ic0l85eT1'   # 要加载的 profile 的 UID
# 对于远程订阅，用订阅缓存文件；对于 local profile，用副本文件

config = {
    'mode': 'rule',
    'mixed-port': 7897,
    'allow-lan': False,
    'log-level': 'info',
    'ipv6': True,
    'external-controller': '',
    'bind-address': '*',
    'external-controller-unix': '/tmp/verge/verge-mihomo.sock',
    'profile': {'store-selected': True},
    'dns': {
        'enable': True, 'ipv6': False,
        'enhanced-mode': 'fake-ip',
        'fake-ip-range': '198.18.0.1/16',
        'default-nameserver': ['223.5.5.5', '119.29.29.29'],
        'nameserver': ['223.5.5.5', '119.29.29.29'],
        'fallback': ['8.8.8.8', '1.1.1.1'],
        'fallback-filter': {'geoip': True}
    }
}

# 从 profile 文件读取代理数据
with open(f'{data_dir}/profiles/{profile_uid}.yaml') as f:
    sub = yaml.safe_load(f)

config['proxies'] = sub.get('proxies', [])
config['proxy-groups'] = sub.get('proxy-groups', [])
config['rules'] = sub.get('rules', [])

# 写回
with open(f'{data_dir}/clash-verge.yaml', 'w') as f:
    yaml.dump(config, f, allow_unicode=True, default_flow_style=False, sort_keys=False, width=1000)

# 强制重载
subprocess.run([
    'curl', '-s', '--unix-socket', '/tmp/verge/verge-mihomo.sock',
    '-X', 'PUT', 'http://localhost/configs?force=true',
    '-H', 'Content-Type: application/json',
    '-d', f'{{"path":"{data_dir}/clash-verge.yaml"}}'
])
```

然后切换 GLOBAL：
```bash
curl -s --unix-socket /tmp/verge/verge-mihomo.sock -X PUT \
  http://localhost/proxies/GLOBAL \
  -H "Content-Type: application/json" -d '{"name":"PROXY"}'
```

---

## 输出格式

```markdown
## 诊断结果
### API 状态
- GLOBAL: {当前选择}
- 代理组数: {N}，代理总数: {M}
### 验证日志
{最近错误或"无"}
### 连通性
- Google: {状态码} {耗时}
### 根因
{一句话}
### 修复
{操作 + 结果}
### 重启后注意事项
{需要 UI 操作的项}
```

---

## 注意事项

1. **不要 `pkill` Verge**——用户可能通过代理连接 AI，杀进程会导致连接中断。
2. **`clash-verge.yaml` 是生成文件**——紧急修复可手写，但重启后覆盖。
3. **Groups enhancement 格式在多个版本中均不可靠**——不要使用它注入自定义代理。改为创建独立 local profile。
4. **导入 Profile 后 Verge 创建内部副本**——编辑原始文件无效，需编辑 `{uid}.yaml` 副本。
5. **`profiles.yaml` 运行时编辑持久，启动时被重写**——URL 修正等持久修改必须通过 Verge UI。
6. **`gstatic.com/generate_204` 国内可直连**——不能用它验证代理是否可用，必须用 Google/Bing/YouTube。
7. **Hysteria2 / UDP 代理不要用 DoH**——必须用 UDP 直连 DNS（223.5.5.5 / 119.29.29.29）。
8. **备份文件可能过时**——始终以服务器端实际配置和权威文档为准。
9. **BoltDB `cache.db` 不是 profile 数据源**——搜索 profile 定义时应直接看 `profiles.yaml`。
10. **备份仓库及时 commit + push**——包含 profiles.yaml、profile 副本、enhancement 文件。
11. **Hysteria2 是 UDP 协议**——检查服务器监听用 `ss -ulnp`，测端口用 UDP 工具；TCP 443 不通不代表服务器挂了。
12. **DNS fallback 不要用 DoT（`tls://8.8.8.8` / `tls://1.1.1.1`，853 端口）**——大陆被墙，会导致所有非 CN 域名解析失败、全代理瘫痪。改用 UDP 53（`8.8.8.8` / `1.1.1.1` 或 `223.5.5.5` / `119.29.29.29`）。

## 变更日志

### 2.5.0 (2026-09-02)
- 新增：场景 K — 单节点 IP 被墙/被干扰（HY2-LA-5TB/192.3.247.117 实战：所有走代理连接超时，bai provider 连带不可用）：判别特征五件套（ICMP 通 + TCP 间歇不通 + SSH banner timeout + UDP 无响应 + 对照国外 IP 通）、TCP 443 refused 是正常响应非服务器宕机、修复 = 切换多节点机场订阅（Phase 3 重建 + API 重载立即生效）、profiles.yaml current 运行时改动不被 Verge 响应须 UI 切换
- 新增：triggers `节点被墙`、`IP 被墙`、`banner exchange`、`单节点超时`

### 2.4.0 (2026-09-01)
- 新增：场景 J — DoT fallback 被墙导致全代理 DNS 解析失败（sidecar 日志 `dns resolve failed` 判别、DoT/UDP 53 测试、fallback 改 UDP 修复、持久化到 profile 源文件）
- 新增：Hysteria2 UDP 协议说明（`ss -ulnp` 而非 `ss -tlnp`）
- 新增：注意事项 #11/#12 — Hysteria2 是 UDP 协议；DNS fallback 禁用 DoT
- 新增：triggers `dns resolve failed`、`侧车日志解析失败`、`全代理超时`、`DoT fallback`
- 修改：描述更新，覆盖场景 J

### 2.3.0 (2026-07-28)
- 重构：场景 H — 首推 `vpscap users` 自检（取代 raw SSH）
- 新增：密码冲突诊断 — 多用户同密码导致流量误计
- 新增：`userid:password` 协议格式说明（AuthServer 精确匹配方案）
- 新增：`~/.local/share/vpscap/USERS.md` 本地文档引用
- 整理：移除场景 H 旧版重复内容，精简为单一段落

### 2.1.0 (2026-07-28)
- 新增：场景 H — AuthServer 拒绝连接（用户禁用/到期/超流量/密码不匹配）
- 新增：AuthServer 日志诊断命令
- 新增：密码迁移场景（固定密码 → HTTP Auth）的快速修复脚本
- 新增：triggers `auth 拒绝`、`密码错误连不上`、`账号被禁用`

### 2.2.0 (2026-07-28)
- 新增：场景 I — 免费代理池失效，批量 TCP 并发测试（50 路并行，~10 秒完成 217 个代理）
- 新增：免费代理池备份与存活过滤流程
- 新增：重新抓取免费代理的三种方式（上游 URL、本地爬虫、opencli）
- 新增：多来源合并去重脚本

### 2.0.0 (2026-07-27)
- 新增：场景 E — Hysteria2 UDP 协议 DNS 死锁诊断与修复
- 新增：场景 F — 导入 Profile 编辑不生效（Verge 内部副本机制）
- 新增：场景 G — 服务器配置变更导致过时备份失效
- 新增：Verge 2.4.7 vs 2.5.2 版本差异对照表
- 新增：BoltDB cache.db 说明（非 profile 数据源）
- 新增：profiles.yaml 编辑行为详细说明（运行时持久 vs 启动时覆盖）
- 新增：mihomo sidecar 日志位置（`logs/sidecar/`）
- 修改：Phase 1 诊断命令加入 sidecar 日志检查
- 修改：Phase 3 紧急修复增加 profile UID 参数（适配导入后副本场景）
- 修改：注意事项扩展到 10 条，增加 Hysteria2 和导入相关条目

### 1.0.0 (2026-07-27)
- 初始发布：覆盖模式错误、Profile 增强失败、远程订阅 404、紧急绕过合并等 4 大场景
