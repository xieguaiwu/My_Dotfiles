---
name: vps-operations
version: 2.2.0
description: 从零部署和管理 VPS 服务器，含 OS 加固、Hysteria2 代理搭建、服务部署、监控备份、排错恢复的全流程运维手册
triggers:
  - "搭建私人代理"
  - "新建 VPS"
  - "服务器运维"
  - "部署代理服务器"
  - "vps 设置"
  - "服务器加固"
  - "生产环境部署"
  - "hysteria2 搭建"
inputs:
  - name: project_dir
    description: vpn-check 项目目录（含 vpscap + authserver 源码，代理场景使用）
    required: false
    default: "~/Desktop/go-projects/vpn-check"
  - name: vps_host
    description: VPS IP 地址
    required: false
    default: ""
  - name: vps_password
    description: VPS root 密码（首次 SSH 用，后续应禁用密码登录）
    required: false
    default: ""
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
  - web_search
  - subagent
  - ask_user
---

# VPS 运维全流程手册

## 任务目标

覆盖一台 VPS 从购买到生产运行的全部生命周期：OS 加固、防火墙配置、服务部署（含 Hysteria2 代理）、监控告警、备份恢复、故障排错。适用于单台 VPS 也适用于管理多台服务器的场景。

每个章节可独立执行——代理搭建直接跳到「四、Hysteria2 代理」，加固直接跳到「二、OS 安全加固」。

## 执行流程

### 一、拿到 VPS 的第一件事（10 分钟黄金窗口）

VPS 暴露公网后平均 **5 分钟内**就会被扫描。必须立即加固。

```bash
# 1. 更新系统
ssh root@<IP>
apt update && apt upgrade -y

# 2. 创建非 root 用户
adduser deploy
usermod -aG sudo deploy

# 3. 配置 SSH 密钥（本机）
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@<IP>

# 4. 测试密钥登录成功后立即禁用密码登录和 root 登录
sudo nano /etc/ssh/sshd_config
```

```ini
# /etc/ssh/sshd_config — 关键改动
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
# 可选：改端口
Port 2022
```

```bash
# 如果有 cloud-init 覆盖配置（Ubuntu 24.04 常见），同步修改
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sshd -t && sudo systemctl restart sshd

# 5. 防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2022/tcp      # SSH（如果改了端口）
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp        # Hysteria2 QUIC
sudo ufw enable

# 6. fail2ban
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

**⚠️ 先别关当前 SSH 会话**——另开终端验证密钥登录成功后再关。

### 二、OS 安全加固（完整清单）

以下按优先级排列，标注「必须」的漏一个都可能出事故。

| 项目 | 命令/操作 | 必要度 |
|---|---|---|
| 禁用 root SSH | `PermitRootLogin no` | **必须** |
| 禁用密码登录 | `PasswordAuthentication no` | **必须** |
| 防火墙默认拒绝入站 | `ufw default deny incoming` | **必须** |
| fail2ban | `apt install fail2ban` | **必须** |
| 安全更新自动安装 | `apt install unattended-upgrades` | **必须** |
| 时间同步 | `apt install chrony` | 推荐 |
| 关闭 THP | `echo never > /sys/kernel/mm/transparent_hugepage/enabled` | 推荐（数据库场景） |
| swappiness=1 | `sysctl vm.swappiness=1` | 推荐 |
| fd 上限 | 在 systemd 服务中设 `LimitNOFILE=64000` | 推荐 |
| SSH 改端口 | `Port 2022` | 可选（减少噪音） |
| 文件系统 noatime | mount 加 `noatime,lazytime` | 可选（NVMe 性能） |

### 三、systemd 服务部署（通用模板）

单 Go/Rust 二进制的最佳实践：

```ini
[Unit]
Description=My Service
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/server
Restart=always
RestartSec=5

# 安全加固（Go 二进制不需要大部分 systemd 的沙箱，但以下无副作用）
ProtectSystem=full
ReadWritePaths=/opt/myapp /var/log/myapp
LimitNOFILE=64000

# Go 程序内存上限（防止 OOM）
Environment=GOMEMLIMIT=500MiB

[Install]
WantedBy=multi-user.target
```

**不要 double-wrap**：systemd 或 PM2 选一个。Go/Rust 用 systemd；Node.js 如果用集群零停机重启才考虑 PM2。

部署后验证：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
sudo systemctl status myapp
sudo journalctl -u myapp -f
```

### 四、Hysteria2 代理专项

#### 4.1 安装 Hysteria2

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

前提：域名已 A 记录解析到 VPS IP（`dig +short <域名>` 验证）。ACME 自动签发证书依赖此步骤。

#### 4.2 部署 AuthServer（订阅控制）

AuthServer 让每人有独立密码、到期管控、流量上限。源码在 `{project_dir}/authserver/main.go`。

```bash
cd {project_dir}/authserver
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o authserver .
scp authserver root@<IP>:/etc/hysteria/authserver
scp users.json.sample root@<IP>:/etc/hysteria/users.json
```

在 VPS 上创建 `/etc/systemd/system/hysteria-authserver.service`（参考第三章模板），然后：

```bash
systemctl daemon-reload
systemctl enable --now hysteria-authserver
```

修改 `/etc/hysteria/config.yaml`：

```yaml
auth:
  type: http
  http:
    url: http://127.0.0.1:8080/auth

trafficStats:
  listen: 127.0.0.1:9999
```

重启：`systemctl restart hysteria-server`

**⚠️ 安全红线**：Admin API 只监听 127.0.0.1，绝不暴露公网。Admin Key 只存在 VPS `/etc/hysteria/.admin_api_key`（chmod 600）。

#### 4.3 部署后即刻操作

##### 方式 A：vpscap CLI（推荐）

```bash
# 1. 创建 VIP 账户
vpscap users add admin <24位随机密码> --name "Admin VIP" --bw 0 --expires 2099-12-31

# 2. 禁用默认共享密码
vpscap users toggle default

# 3. 查看所有用户
vpscap users
```

##### 方式 B：直接 curl（VPS 上执行）

```bash
# 1. 创建 VIP 账户
API_KEY=$(cat /etc/hysteria/.admin_api_key)
curl -s -X POST http://127.0.0.1:8080/admin/users \
  -H "Authorization: Bearer $API_KEY" \
  -H 'Content-Type: application/json' -d '{
    "id": "admin", "name": "Admin VIP", "password": "<24位随机>",
    "bandwidth_limit_gb": 0, "expires_at": "2099-12-31T00:00:00Z"
  }'

# 2. 禁用默认共享密码
curl -s -X PUT http://127.0.0.1:8080/admin/users/default \
  -H "Authorization: Bearer $API_KEY" \
  -H 'Content-Type: application/json' -d '{"active": false}'
```

#### 4.4 Clash Verge YAML 配置要点（踩坑记录）

- **`tls: true` 必须显式设置**：Hysteria2 类型不会自动启用 TLS
- **DNS 不能用 DoH**：Hysteria2 是 UDP 协议，DoH over HTTPS 会死锁。只能用 UDP 直连 DNS（223.5.5.5、119.29.29.29）
- **`ipv6: false`**：统一关闭避免双栈通性问题
- **Verge 陷阱**：导入 Profile 后创建随机 UID 副本，编辑原文件不生效
- **`password` 协议格式**：AuthServer 支持 `userid:password` 格式精确匹配用户。当多人密码相同时必须使用此格式，否则流量会计入第一个匹配用户。`gen-user-yaml.py` 默认生成此格式。

#### 4.5 用户 YAML 分发流程

```bash
# 1. 添加用户
vpscap users add friend_id <密码> --name 朋友名 --bw 100 --expires 2026-09-30

# 2. 生成 YAML（协议格式：userid:password）
python3 {project_dir}/gen-user-yaml.py /etc/hysteria/users.json friend_id \
  --output ~/Downloads/shit/hy2-friend_id.yaml

# 3. 局域网分发
cd ~/Downloads/shit && python3 -m http.server 9999
# 另一台电脑浏览器打开 http://<本机IP>:9999/ 下载
```

`~/Downloads/shit/` 仅用于临时分发 YAML，不存放持久文档。用户管理文档在 `~/.local/share/vpscap/USERS.md`（`vpscap users` 自动刷新）。

### 五、监控 — 不要等用户告诉你服务器挂了

**最小可行方案**（1 分钟部署）：

```bash
# 资源监控
apt install htop iotop -y

# 外部存活监控（免费）
# 注册 UptimeRobot → 加监控项 https://<域名>/health → 告警推送到 Telegram/邮件
```

**进阶方案**：Prometheus + node_exporter + Grafana（单 VPS 即可跑）。

**血的教训**：GCH 公司因没有监控，一个挖矿脚本在服务器上跑了 5 天才被发现，损失 $1,400 超额账单 + 客户流失。设资源阈值告警，CPU 持续 >80% 超过 5 分钟必须通知。

### 六、备份 — 3-2-1 铁律

**3 份数据、2 种介质、1 份异地**。

GCH 的教训：备份和源文件存在同一台机器上，磁盘损坏后全部丢失，花了 12 小时手工重建，损失 $4,500。

**最小可行方案**：

```bash
#!/bin/bash
# /opt/backup.sh — 每日凌晨 2 点
DATE=$(date +%Y%m%d)
tar -czf /tmp/backup_$DATE.tar.gz /etc/hysteria/ /etc/systemd/system/
# 上传异地（Backblaze B2 前 10GB 免费）
b2 upload-file my-bucket /tmp/backup_$DATE.tar.gz vps-backup-$DATE.tar.gz
rm /tmp/backup_$DATE.tar.gz
# 只保留最近 7 天本地
find /var/backups/ -mtime +7 -delete
```

cron：`0 2 * * * /opt/backup.sh`

**关键**：定期测试恢复——不能恢复的备份不是备份。

### 七、排错速查

#### SSH 不通

| 症状 | 根因 | 修复 |
|---|---|---|
| `Connection refused` | SSH 服务未启动 | VNC 登录 `systemctl restart ssh`（注意：Ubuntu 24.04 服务名是 `ssh` 不是 `sshd`） |
| `Connection timed out` | 防火墙/网络阻断 | SolusVM API 重启；检查 ufw |
| `timed out during banner exchange` | SSH 服务挂死 | VNC `systemctl restart ssh` |
| 所有端口通但 SSH 连不上 | iptables 残留规则 | VNC `iptables -F && iptables -P INPUT ACCEPT` |
| fail2ban 误封自己 | 输错密码太多次 | VNC `fail2ban-client set sshd unbanip <你的IP>` |

**⚠️ iptables 自爆陷阱**：部署绑定 127.0.0.1 的服务（如 AuthServer）后，不要设全局 `INPUT DROP`。本地服务不需要防火墙规则保护。如果必须设，至少保留 `ACCEPT` SSH 端口和已用服务端口。修复命令：`iptables -F && iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT`。

#### VPS 挂死 → SolusVM API 救命

```bash
# 不需要 SSH，直接 HTTP API
API="https://nerdvm.racknerd.com/api/client/command.php"
curl -s "$API?key=<KEY>&hash=<HASH>&action=status"
curl -s "$API?key=<KEY>&hash=<HASH>&action=reboot"
```

**⚠️ 注意**：SolusVM 网页登录频繁调用会触发 Cloudflare 429 限流。用上面的 API 而非模拟浏览器。

#### 服务起不来

```bash
sudo journalctl -u <service> --no-pager -n 50   # 看最后 50 行日志
sudo systemctl status <service>                   # 看状态
sudo ss -tlnp | grep <port>                      # 看端口是否被占用
df -h                                             # 磁盘满了？
free -h                                           # 内存耗尽？(dmesg | grep -i oom)
```

#### 内存耗尽排查

```bash
dmesg | grep -i "out of memory"                   # OOM killer 记录
ps aux --sort=-%mem | head -10                     # 内存大户排行
journalctl -u <service> | grep -i "memory"        # 应用层日志
```

**预防**：Go 程序设 `GOMEMLIMIT=500MiB`；Node.js 设 `--max-old-space-size=512`；2GB VPS 预留至少 200MB 给系统。

### 八、多台 VPS 管理

超过 3 台时必须规范化：

- `~/.ssh/config` 别名化每台服务器，统一密钥
- 命名规范：`<角色>-<环境>-<地区>-<编号>`（如 `web-prod-nyc-01`）
- 配置管理：Ansible playbook 统一推送（替代手动 scp 文件）
- 密码和 API Key 统一在密码管理器，不存本地明文
- 备份策略和更新策略全量统一
- 灾备演习至少一季度一次

#### 8.1 多服务器训练协同 — train-watch CLI（2026-08-10 落地，2026-08-10 加固版）

> ML 训练多服务器场景的现成工具链，**优先于手写 ssh 命令**。任何涉及远程训练服务器的操作先看这里。

**安装/配置**：`train-watch` 已在 PATH（`~/.local/bin/train-watch`，Go 单二进制）；配置 `~/.config/train-watch/servers.json`（0600，含密码）是**服务器唯一事实源**（host/port/password/project/logfile/procPattern/conda_path）。

| 命令 | 用途 |
|:---|:---|
| `train-watch status [--watch] [-s gpu36] [--no-header]` | 多服务器监控：step/GPU/平均ETA/瞬时ETA/最后活动(日志活性)/systemd unit/内存告警（available<1GB → DEGRADED，日志静止>180s → STUCK） |
| `train-watch start <srv> --unit <name> -- <cmd>` | systemd-run 启动训练（自动封装 OMP/OPENBLAS/MKL=1 + PYTHONUNBUFFERED + PATH=anaconda3[conda_path 可配]，unit 冲突预检，--wait 秒数可配） |
| `train-watch stop <srv> --unit <name>` | 停止训练单元 |
| `train-watch sync <srv>` | rsync 部署代码（调 sync_to_server.sh [server_name]，密码经环境变量不落 cmdline） |
| `train-watch exec <srv> -- <cmd>` | 任意远程命令 |
| `train-watch collect <srv>` | 拉取 train.log 到 downloads/<srv>/ |
| `train-watch config show <srv>` | 打印解析后配置（密码脱敏 ***） |

**安全基线（2026-08-10 加固）**：
- SSH TOFU 主机密钥验证（~/.config/train-watch/known_hosts, 0600）— 首次连接记录指纹，后续校验
- 密码仅经 SSHPASS 环境变量传递（sshpass -e），不出现于 /proc/cmdline
- ⚠️ gpu36 与 gpu11-27024 为**克隆镜像**（SSH 主机密钥相同）— 一台被攻破则另一台可被 MITM，长期建议重建其一

**关键背景知识（勿忘）**：
- 训练必须 systemd-run 启动（SSH+setsid+nohup 会在 SSH 断开时被 sshd session 清理连带杀死 — 实测教训）
- systemd-run 必须显式 PATH 含 `/root/anaconda3/bin`（systemd 默认 PATH 无 torch；可用 servers.json conda_path 覆盖）
- CPU-only 模式每任务 RSS ~7.3GB（torch CPU tensor 双份）— 并行任务数 = 内存预算 ÷ 8GB
- 密码集中在 servers.json（0600）后可 `${\VAR}` 环境变量化
- 源码：`~/Desktop/go-projects/train-watch`（README 有完整命令参考）

### 九、生产环境部署 Checklist

每次上生产前逐项确认：

- [ ] 非 root 用户运行服务
- [ ] SSH 密钥认证、禁用密码和 root 登录
- [ ] UFW 只开放必要端口
- [ ] fail2ban 运行中
- [ ] unattended-upgrades 开启（安全更新 24h 内自动装）
- [ ] 时间同步（chrony 或 systemd-timesyncd）
- [ ] SWAP 存在（OOM 缓冲垫，1-2x 内存）
- [ ] 日志轮转（logrotate）配置完成
- [ ] 备份脚本定时运行 + 异地存储
- [ ] 外部存活监控已添加（UptimeRobot 或同类）
- [ ] `.env` 文件 chmod 600，不在 git 仓库中
- [ ] systemd 服务有 `Restart=always` + `RestartSec=5`
- [ ] 恢复流程至少走过一次（不是文档，是真跑过）

## 输出格式

部署完成后应产出以下文件结构：

```text
VPS 端:
  /etc/hysteria/config.yaml               # Hysteria2 配置（如有）
  /etc/hysteria/authserver                 # Go 认证二进制
  /etc/hysteria/users.json                 # 用户数据库（chmod 600）
  /etc/systemd/system/hysteria-authserver.service

本地:
  ~/.ssh/config                            # VPS 别名（含密钥路径）
  ~/.config/vpscap/config.json             # vpscap 配置（chmod 600）
  ~/.local/bin/vpscap                      # CLI 工具
  {project_dir}/docs/DEPLOYMENT.md         # 部署记录（含校验和）
```

## 注意事项

> **文档更新**：VPS 配置变更后，按 `project-documentation-protocol.md` §阶段B 更新项目文档（CONTEXT_FOR_NEXT_AGENT.md、ASSET_INVENTORY.md 中的服务器密码/端口）。服务器信息过期是最常见的 Agent 阻塞原因。

### 五个最贵的错误（来自公开技术分享）

**① 把 VPS 当成共享主机**：VPS 不会自动安全加固、性能调优、打补丁。不配置基线就上线 = 裸奔。

**② 没有实时监控**：依赖手动翻日志。问题总是在没人看的时候发生。GCH 的挖矿脚本跑了 5 天、损失 $1,400。

**③ 备份存在同一台机器上**：磁盘损坏时原始数据和备份一起丢失。3-2-1 铁律不能妥协。GCH 损失 $4,500。

**④ 安全补丁拖延**：能跑就别碰——结果漏洞被利用，网站被挂马、SEO 排名归零、域名进黑名单。GCH 损失 $2,300。安全更新必须在 24h 内完成。

**⑤ 容量规划只看价格**：促销流量高峰时 VPS 反复崩溃，客户直接走人。损失 $2,000+。

### 密码与密钥管理

- sshpass 的 `-p` 参数会被 `ps aux` 看到，改用 `SSHPASS` 环境变量或 `sshpass -f <(echo "密码")`
- API Key 存在于 VPS 文件而非本地 git 仓库
- 密钥按季度轮换

### 关于「0 = 无限」的编码技巧

`bandwidth_limit_gb=0` 表示无限流量。利用 Go 零值语义：`if limit > 0 && used >= limit` 天然跳过 limit=0。避免用 -1 等魔法值。

### 数据竞争防护（Go 并发）

- `findUser` 返回值拷贝而非指针——防止调用方持有切片指针后锁释放、被其他 goroutine 修改
- 数据库写入用 `os.CreateTemp` + `os.Rename` 实现原子替换
- 密码比较用 `subtle.ConstantTimeCompare` 防时序攻击

## 脚本输出文本规范（ASD-STE100）

部署/运维脚本与用户的自动化文字交互（echo、systemd 服务提示、错误消息）遵守 ASD-STE100（简化技术英语，国际标准）规范：

- **短句**：一条消息 ≤ 20 词（中文 ≤ 40 字），一句一个信息
- **指令祈使**：提示操作直接说"要做什么"
- **术语一致**：同一脚本内同一概念同一措辞，不换同义词
- **状态消息**：固定前缀模板（[OK] / [FAIL] / [WARN]）
- **错误消息**：先说原因再说动作，附可执行建议

完整规范见 [technical-writing-standard.md](../technical-writing-standard.md) 第 7 节。

## 变更日志

### 2.2.0 (2026-08-16)
- 新增：脚本输出文本规范（ASD-STE100）——新增「脚本输出文本规范」章节，部署/运维脚本 echo、systemd 服务提示、错误消息遵守简化技术英语的短句/祈使/术语一致/状态前缀规范，详见 technical-writing-standard.md 第 7 节

### 2.1.0 (2026-07-28)
- 新增：4.3 用户管理首选 `vpscap users` CLI（保留 curl 作为 fallback）
- 新增：4.5 用户 YAML 分发流程（`gen-user-yaml.py` → `~/Downloads/shit/` → http.server）
- 新增：4.4 `userid:password` 协议格式说明（AuthServer 精确匹配，解决同密码多用户流量误计）
- 新增：第七章 iptables 自爆陷阱 — 部署 localhost 服务后禁全局 INPUT 导致 SSH 全断
- 修正：第七章 SSH 服务名 `sshd` → `ssh`（Ubuntu 24.04）

### 2.0.0 (2026-07-28)
- 重构为通用 VPS 运维 skill（原名 hysteria2-proxy-setup）
- 新增：第一章「拿到 VPS 第一件事」10 分钟黄金窗口
- 新增：第二章「OS 安全加固完整清单」
- 新增：第三章「systemd 服务部署通用模板含安全加固」
- 新增：第五章「监控方案 + UptimeRobot 最小可行」
- 新增：第六章「3-2-1 备份铁律 + GCH 的血泪教训」
- 新增：第七章「排错速查表」含 fail2ban 误封、OOM 排查
- 新增：第八章「多台 VPS 管理」命名规范 + Ansible
- 新增：第九章「生产 Checklist」13 项逐条核查
- 新增：五个最贵的错误（GCH $10,000 教训总结）
- 保留：第四章 Hysteria2 代理全流程（部署 AuthServer、YAML 陷阱、SolusVM API）
- 保留：数据竞争防护、0=无限编码技巧、密码泄露风险

### 1.0.0 (2026-07-28)
- 初始发布：Hysteria2 代理专项
