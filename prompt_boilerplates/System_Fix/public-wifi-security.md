---
name: public-wifi-security
version: 1.0.0
description: 公共 WiFi（机场等）三合一：验证页弹不出排查（Clash 代理劫持根因）、网络安全调查（加密/DNS/暴露面/证书/evil twin）、加固与恢复双脚本（airport-harden.sh / airport-restore.sh）
triggers:
  - "机场wifi"
  - "公共wifi"
  - "验证页弹不出"
  - "captive portal"
  - "公共网络加固"
  - "wifi安全调查"
inputs:
  - name: symptom
    description: 用户描述的症状（连不上、验证页不弹、网络可疑等）
    required: false
    default: "auto-detect"
  - name: operation
    description: '执行模式: survey（调查）, harden（加固）, restore（恢复）'
    required: false
    default: "auto"
tools:
  - read
  - bash
  - grep
---

# 公共 WiFi 安全 Skill

## 任务目标

公共 WiFi（机场等）场景三合一：

1. **验证页弹不出** — 排查并打开 captive portal（根因多为 Clash 类代理劫持浏览器流量）
2. **网络安全调查** — 加密、DNS、网关身份、本机暴露面、证书链、evil twin
3. **加固与恢复** — 执行 `airport-harden.sh` / `airport-restore.sh`（入站 SSH / Samba / LLMNR）

## 遵守的偏好

- **⑦ 永不覆写**：脚本已存在时用 `edit` 更新，禁 `write` 覆写
- **出站 SSH 不受影响**：加固仅封入站；执行前确认用户无入站 SSH 依赖，必要时先加白名单 rich rule（见脚本注释）

## 执行流程

### 1. 确认当前网络身份

用 `nmcli` / `iw` 确认 SSID、加密、IP、网关、DNS：

```bash
nmcli -t -f DEVICE,STATE,CONNECTION device status
iw dev wlp4s0 info | grep -E "ssid|channel"
ip route; ip neigh
resolvectl status wlp4s0 | grep -E "Current DNS|DNS Server|DNSSEC"
```

**注意**：`nmcli connection show` 显示保存的配置，当前连接以 `iw` + `ip route` 为准（机场网与热点切换时易误判）。

### 2. 验证页弹不出 → 查代理（最常见根因）

若连接状态为 portal 但浏览器不弹验证页，先查代理：

```bash
ss -tlnp | grep -E "7890|7897"        # Clash 类代理监听?
grep -i "network.proxy" ~/.mozilla/firefox/*/prefs.js   # Firefox 手动代理?
env | grep -i proxy                   # 环境变量代理?
gsettings get org.gnome.system.proxy mode
```

**根因**：浏览器流量走代理隧道，门户劫持到不了浏览器。方案：

- **方案 A（关代理）**：Clash 关系统代理 → Firefox 网络设置改「不使用代理」并重启 → 访问 `http://example.com`（必为 http，https 不被劫持）→ 自动跳验证页；验证毕恢复
- **方案 B（免代理直连，零残留）**：`curl --noproxy '*' -s -m 15 -L -o /dev/null -w "%{url_effective}" http://example.com` 抓验证页地址，再 `chromium --no-proxy-server "$URL"` 打开（Chromium 未运行时才生效，运行中会复用旧实例忽略参数）

### 3. 网络安全调查

| 检查 | 命令 | 判读 |
|---|---|---|
| 加密 | `nmcli -f SSID,SECURITY device wifi list` | 开放网络（SECURITY=--）→ 空中链路明文 |
| 网关身份 | `ip neigh` 取网关 MAC → macvendors API 查 OUI | 企业设备（Palo Alto/HUAWEI 等）正常；未知 OUI 存疑 |
| DNS 劫持 | `getent ahostsv4 <域>` vs `dig +short A <域> @223.5.5.5` / `@1.1.1.1` | 不一致 → 劫持嫌疑 |
| 本机暴露面 | `ss -tlnp` 找 0.0.0.0 监听 + `firewall-cmd --get-active-zones` / `--list-services` | 22/139/445/5355 对全网开放为高危 |
| 证书/中间人 | `openssl s_client -connect <域>:443 -servername <域> \| issuer`；`ls /usr/local/share/ca-certificates ~/.local/share/ca-certificates` | 自装 CA + 非官方 issuer → MITM 嫌疑 |
| evil twin | 同 SSID 各 BSSID 前 3 字节 OUI 一致性 | 混入异厂商 BSSID → 克隆嫌疑 |

### 4. 加固与恢复（公共网络期间）

脚本位置：`~/prompt_boilerplates/System_Fix/airport-harden.sh`、`airport-restore.sh`：

```bash
sudo ~/prompt_boilerplates/System_Fix/airport-harden.sh    # 加固: 防火墙移除入站SSH + 停Samba + 关LLMNR
sudo ~/prompt_boilerplates/System_Fix/airport-restore.sh   # 离开后恢复
```

要点：

- **出站 SSH 不受影响**——加固仅封入站（firewalld zone 只管入站流量；已建立连接亦不断）
- 若需保留特定来源入站 SSH，先加白名单 rich rule 再移除通用放行（规则见 `airport-restore.sh` 注释）
- 脚本幂等；restore 自动清理机场临时白名单 rich rule，其他 ssh rich rule 只提示不删

## 输出格式

- **验证页场景**：给出验证页 URL 或浏览器操作步骤
- **调查场景**：输出安全调查表（网络身份 / DNS / 暴露面 / 证书 / 邻居，各列结论 + 风险等级）
- **加固场景**：脚本 `[OK]/[SKIP]/[FAIL]` 输出 + 验证结论

## 注意事项

- 加固脚本需 sudo（本机 sudo 要密码，无法代跑；让用户执行后回贴输出核验）
- 开放网络明文流量可被同网嗅探——敏感操作保持 HTTPS / 代理隧道
- `sshpass -p` 明文密码留在进程列表（ps 可见），公共场合留意
- 机场免费 WiFi 会话通常限时（30-60 分钟），注意重新验证
- 调查命令勿扫非网关的外部主机（公共网络边界），仅测网关与自身

## 变更日志

### 1.0.0 (2026-08-22)
- 初始发布：2026-08-22 香港机场实战沉淀——验证页弹不出根因为 Clash 代理劫持；安全调查四步法；附带 `airport-harden.sh` / `airport-restore.sh` 双脚本（幂等、可 --revert 恢复）
