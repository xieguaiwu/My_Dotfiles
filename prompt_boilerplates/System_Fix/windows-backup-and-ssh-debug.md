---
name: windows-backup-and-ssh-debug
version: 1.8.1
description: Windows ⇄ Linux 双机备份与 OpenSSH 远程排障——BOOKS 电子书双机同步日常运维（books-sync.py 四步流程/差异语义/排除规则/快照策略/内容哈希预检/快照清理/远端体积审计/输出编码坑）为第一要务；SSH 链路故障（KEXINIT reset 排除链、黑盒三测试、前台 vs 服务差异、ACL/TEMP 判别器、看门狗自愈、脚本化协作闭环）为排障支撑；Windows 脚本编写规范已拆至 Coding/windows-powershell-scripting.md
triggers:
  - "SSH 连不上 Windows"
  - "KEXINIT"
  - "Connection reset"
  - "Windows OpenSSH"
  - "火绒拦截 SSH"
  - "OpenSSH 拒绝访问"
  - "sshd 无法运行"
  - "服务未安装"
  - "同步电子书"
  - "BOOKS 备份"
  - "电子书同步"
  - "备份windows"
  - "双机备份"
  - "快照清理"
  - "备份体积"
  - "backup 清理"
inputs:
  - name: target_host
    description: 目标 Windows 主机 IP
    required: false
    default: "auto-detect"
  - name: symptom
    description: 故障症状（reset / 拒绝连接 / 解压失败 等）
    required: false
    default: "auto-detect"
tools:
  - bash
  - read
  - write
  - edit
  - grep
  - ask_user
---

# Windows 脚本编写与 OpenSSH 远程排障 Skill

Windows 端 **OpenSSH 远程排障**。Linux 主机不能直接执行 Windows 脚本——一切操作经「用户双击脚本 + 回传输出」闭环完成。2026-08-16 win-ssh-setup 实战（KEXINIT reset 五日排障、rsync 解压失败、语法检查器误报）沉淀于此。

> **脚本编写规范（.bat/.ps1 编码、提权、PS5.1 语法、单文件交付、退出码、Transcript、内容门禁、输出规范、测试函数、上下文切换、看门狗、远端 PS 引号坑等）已拆至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md)（Windows 专精独立 skill）。** 写/改 .bat/.ps1 前加载该 skill 自查，本文仅保留 SSH 排障链路直接依赖的条目。

## 任务目标

1. Windows OpenSSH "Connection reset after KEXINIT" 类故障，按排除链由外至内定位
2. 每个排查步骤脚本化，用户双击即跑，输出回传，逐步收敛
3. 编写/审查 SSH 排障脚本时，遵循 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) 的 Windows 脚本编写规范

## 执行流程

### 1. 脚本编写规范自查（写/改 .bat/.ps1 前必过）

**Windows 脚本编写规范（编码/提权/PS5.1 语法/错误处理/退出码/自包含门禁/Transcript/单文件交付/输出规范/测试函数/上下文切换/看门狗/远端 PS 引号坑等，原 A-Q 共 17 条）已拆至独立 skill：[Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md)（v1.0.0，Windows 端 .bat/.ps1 专精）。** 写/改 .bat/.ps1 前加载该 skill 自查。

SSH 排障链路中直接依赖的三条，保留摘要（详见新 skill 对应节）：

- **G. 测试命令防挂起**：ssh 测试一律 `-o BatchMode=yes -o ConnectTimeout=5`。注意 `Permission denied (publickey)` **不是故障**——KEX 已通、仅未配公钥；`Connection reset`/`timeout` 才是故障。（新 skill §4）
- **H. tar 盘符陷阱**：Windows bsdtar 归档绝对路径保留盘符（`D:\ebooks` → 条目 `D:/ebooks/...`），Linux 端解压出 `D:` 子目录。修复：`pushd "%SRC%" && tar cf - . | ssh ... && popd`。（新 skill §14）
- **I. bsdtar 解压 .tar.xz 需外部 xz**：Windows 10 自带 bsdtar 不内置 xz 解压器，报 `Can't initialize filter; unable to run program "xz -d -qq"`。修复：下载官方 `xz-5.8.3-windows.zip`（tukaani.org / GitHub 双源）→ `Expand-Archive` → 复制 `xz.exe` 到 `System32`。（新 skill §14）

### 2. 环境预检（远程黑盒画像）

```bash
ip neigh show                      # 邻居 MAC + 状态
for p in 22 135 139 445 3389 5985; do timeout 2 bash -c "echo > /dev/tcp/$IP/$p" 2>/dev/null && echo "$p OPEN"; done
timeout 5 bash -c "exec 3<>/dev/tcp/$IP/22; head -1 <&3"   # SSH banner
nmap -Pn -sV -p 22,135,139,445,3389,5985 $IP
```

MAC 厂商识别（`api.macvendors.com`）区分设备类型：光猫/路由器（Fiberhome 等网络设备厂）、物理机（Intel/Realtek 网卡）、虚拟机（本地管理 MAC，如 `ca:xx:xx`）。脚本注释里的目标 IP 与实测不符时，以用户确认为准（本次 192.168.1.3 → 实际 192.168.1.4）。

方向性验证：Windows→Linux 通而 Linux→Windows 不通 = 单向问题，备份主方向（Windows 推送）可能已可用，先确认用户核心需求再排障。

### 3. 黑盒三测试（定位 sshd 状态，无需 Windows 端操作）

Python socket 直连 22 端口，三种 payload：

| 测试 | 发送内容 | 响应含义 |
|---|---|---|
| 垃圾数据 | `b'\x00\x01...'` | `Invalid SSH identification string.` = sshd 进程活着、连接处理正常 |
| 合法版本串 | `b'SSH-2.0-Test\r\n'` | **Connection reset** = 版本交换后、KEX 准备阶段失败（密钥/上下文） |
| 裸 KEXINIT | `b'\x14' + ...`（无版本串） | `Invalid...` = 正常等待版本串 |

三测组合可区分「进程崩溃」vs「KEX 准备失败」vs「主动拦截」。另注：客户端日志出现 `Warning: Permanently added ... to the list of known hosts` = **KEX 成功信号**（known_hosts 只在密钥交换完成后写入）。

### 4. KEXINIT reset 排除链（由外至内，成本递增）

```
0. 存在性     → sc qc / Get-Service（1060「服务未安装」= 服务从未注册成功，
                 别急着排杀软/密钥）+ netstat :22 分开看：
                 服务在/监听不在、进程在/服务不在，各是不同路
1. 杀软进程   → tasklist 匹配 Hips/wsctrl/sysdiag(火绒)、360、kxescore、QQPCTray、
                 Rav、kav、avp、bdagent、cis、mbam、MsMpEng、Norton、Symantec
                 注：进程名子串匹配会误命中（IntelCpHeciSvc 含 "cis"），人工确认
2. 防火墙     → localhost 测试区分：回环也 reset = 本机层问题（非防火墙）；
                 仅外部 reset = 防火墙/网络（banner 能收到则 22 已放行）
3. 密钥权限   → icacls 私钥仅 SYSTEM/Administrators (F)；目录 ACL 过宽会继承
4. 密钥内容   → ssh-keygen -l -f 验证；损坏/格式错则 sshd 拒绝加载
5. 重建密钥   → 停服务 → 删除 ssh_host_*_key → 重启（自动生成）→ 重测
6. 算法矩阵   → 4 种 KexAlgorithms 全试（排除协议兼容）
7. 前台 vs 服务 → sshd -ddd 前台调试（脚本自动：停服务→起调试→测试→恢复→抓日志）
                 前台正常 + 服务 reset = 服务上下文问题（残留注入/驱动）
8. 重启机器   → 清除残留注入 DLL / 未卸载驱动（成本最低的有效手段）
9. 重注册服务 → sc.exe stop/delete sshd → 重跑便携版 install-sshd.ps1 → start
10. 换内置    → sc.exe delete → Add-WindowsCapability 'OpenSSH.Server~~~~0.0.1.0'
                 （0x800f0954 = WSUS 策略，改 UseWUServer=0 + 重启 wuauserv 重试）
```

**日志源三处勿混**：System 日志（服务控制）、Application 日志（sshd.exe 崩溃/WER）、`OpenSSH/Operational` 事件源（sshd 自身错误，未启用时查询报「找不到匹配事件」）。诊断脚本必须覆盖全部三处。

**TEMP 隔离试跑判别器**：把嫌疑 exe 复制到 `%TEMP%` 再试运行——TEMP 能跑而原位置拒绝访问 = 路径性拦截（目录 ACL/路径策略）；TEMP 也拒绝 = 内容级拦截（按哈希/签名的策略）。一次复制区分两大方向。

**火绒暴力破解防护**：多次连接失败 + nmap 扫描会触发源 IP 临时拉黑（症状：localhost PASS 但外部持续 reset，等待数分钟无效）——排障时减少无谓重试，先查火绒安全日志。

### 5. 脚本化协作闭环

**交付模式（bat 启动器 + ps1 逻辑、多位置写入、每轮一脚本等）已移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §15。** 本文保留版本演进链：diag-sshd → diag-sshd2（补日志源/ACL）→ diag-sshd3（前台调试）——每版修复上一版盲区，保留演进链可追溯。

## 输出格式

- **诊断脚本**：8 段检查（服务详情/事件日志/崩溃记录/密钥 ACL/日志文件/端口监听/配置激活行/防火墙）→ 多位置保存 `sshd-diagN.txt`
- **修复脚本**：5 步（验证→修复→重启→自测→提示），自测区分 `[PASS]`/`[FAIL]` 并给下一步指引
- **综合修复**：阶梯式（当前状态→重注册→换内置→配公钥→最终报告），失败时明确提示「重启后重跑」
- **回传格式**：用户贴窗口输出或放 ~/Downloads/agony.md，分析后给出精确结论与下一脚本

## 注意事项

- **勿猜 Windows 密码**：无凭据时走 SMB/RPC 匿名探测（`NT_STATUS_ACCESS_DENIED` 即止），不爆破（锁账户风险）
- **known_hosts 变化**：重建密钥/换 sshd 后指纹改变，Linux 端先 `ssh-keygen -R <ip>` 再测，勿被「REMOTE HOST IDENTIFICATION HAS CHANGED」误导
- **管理员公钥路径**：Administrators 组用户登录，AuthorizedKeysFile 被 `Match Group administrators` 重定向到 `__PROGRAMDATA__/ssh/administrators_authorized_keys`（普通 `authorized_keys` 无效），ACL 必须 `Administrators:F + SYSTEM:F`
- **脚本注释与事实核对**：注释里的假设（如「Windows 自带 xz 支持」）必须实测验证——本次错误假设导致解压失败一轮
- **诊断脚本权限**：涉及 `C:\ProgramData` 的读取须管理员，脚本头部明示
- **超时保护**：所有 ssh/curl/nmap 远程操作加 timeout，防挂起整个排障循环

## 实战补充（2026-08-16 win-ssh-setup 第 2-10 轮教训）

### 1. 测试函数必须输出原始错误，PASS/FAIL 是诊断盲区

修复脚本的验证函数若只返回 PASS/FAIL 而不显示原始输出，无法区分
`Connection refused`（服务没监听）vs `Connection reset`（服务在监听但握手崩）vs
`timeout`（防火墙丢包）——三者修复方向完全不同。**验证函数 FAIL 时打印 $out 前 300 字符**。
（完整测试函数规范见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §10）

### 2. 测试客户端必须用绝对路径，勿依赖 PATH

`& ssh` 依赖 PATH 解析：提权后当前目录是 System32，PATH 可能指向被移动/损坏/被拦的
ssh.exe → `ApplicationFailedException 拒绝访问` → 所有阶段假 FAIL。
**修**：优先 `C:\Windows\System32\OpenSSH\ssh.exe`（内置客户端，微软签名），
再 `C:\Program Files\OpenSSH\ssh.exe`，用绝对路径调用。
（完整规范见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §10）

### 3. MOTW 理论陷阱：Expand-Archive 不传播 Mark-of-the-Web

下载 zip 带 MOTW（Zone.Identifier ADS），但 **Expand-Archive 解压出的文件不带 ADS**——
「解压 exe 被 SmartScreen 拦」是错误假设。若解压后 exe 执行拒绝访问，另找原因
（ACL/Defender 实时保护锁文件/占用），勿在 Unblock-File 上浪费轮次。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) 注意事项）

### 4. 杀软接力：第三方 AV 卸载后 Windows Defender 自动启用

火绒压制 Defender 期间（WinDefend Stopped），排障证据会互相矛盾：
- 火绒停止瞬间 PASS（火绒拦服务流量）
- 火绒卸载后 MsMpEng 复活 → 服务模式继续 reset（Defender 网络检查/实时保护接管）
**修**：每次快照必须查 `Get-Process MsMpEng` + `Get-Service WinDefend`；怀疑 Defender 时
`Add-MpPreference -ExclusionPath`（程序目录+数据目录）并尝试
`Set-MpPreference -DisableRealtimeMonitoring $true` + `-EnableNetworkProtection Disabled`。

### 5. 「SCM 能启动服务、用户 Start-Process 同 exe 拒绝访问」的排查方向

服务管理器与用户上下文启动同一 exe 结果不同：
1. **服务进程是否真的监听**（`netstat -ano | findstr :22` + 进程名）——服务可能
   Running 但内部初始化失败，测试显示 refused
2. **文件是否被占用**（服务持有 exe 句柄时二次启动可能拒绝）
3. **ACL 是否允许当前用户执行**（icacls 查具体文件，勿只看目录）
4. **杀软实时保护锁文件**（Defender 扫描中新下载 exe）
5. 测试前 `taskkill /F /IM sshd.exe` 杀干净旧实例，避免端口占用假象
（完整排查方向见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §11）

### 6. 修复脚本切换运行上下文（服务→任务→Run 键）前必须杀旧进程

兜底链（服务→schtasks→Startup）切换时，旧实例若仍占端口，新实例绑定失败、
测试连到旧实例 → 假 FAIL。每阶段切换前 `taskkill /F /IM` 杀干净旧实例。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §11）

### 7. HKCU Run 键写入「拒绝访问」用 Startup 文件夹快捷方式绕过

注册表 Run 键可能被第三方防护 ACL 锁（Owner 异常为 SYSTEM）；自启动改用
`[Environment]::GetFolderPath('Startup')` + WScript.Shell 快捷方式，不依赖注册表。
schtasks /sc onlogon 需密码会在提权窗口卡住——勿用。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §11）

### 8. 排障协作的收敛节奏

- 每轮只给「1 个脚本 + 用户双击 + 输出回传」，勿让用户跑多条命令
- 脚本输出全部诊断（where ssh/ACL/Run 键/AV 进程/残留注册表）——一次回传解决一轮
- 用户贴回的文件（agony.md）每次 md5 变化，先 diff 再分析，勿重复读旧结论

## 实战补充 2（2026-08-17 第 11-13 轮：diag v2 定位、v5 误诊、v6）

背景：v4 修复脚本跑了五轮全部失败。diag v2 终于看清：服务从未注册成功（sc qc 1060），
磁盘上 sshd.exe 全部「拒绝访问」，唯一能跑的是第一个 .bak 里的 v10。

### 9. `-ErrorAction SilentlyContinue` + `2>&1` = 吞错组合拳

diag v1 的 Start-Service 用了这对组合，把最需要的真实报错吞得干干净净（只看到
StartType 不动）。要真实报错：`try { Start-Service x -ErrorAction Stop } catch {
$_.Exception.Message }`。与 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §4（'Stop' + stderr 陷阱）合参：诊断路径
'Continue' + 显式 catch，修复路径按需。

### 10. 空 FileVersion 是症状不是证据（v5 误诊教训）

当前 sshd.exe FileVersion 为空 → 我推断「非官方构建、二进制损坏」，据此写了整套
「验证式安装」。实际：文件 1343920B 与官方 v9.5 完全一致，版本资源读不出来
本身可能就是访问被拒的连带症状。**身份鉴定三件套：字节数、SHA256、试运行**
（官方 v9.5 sshd.exe = 1343920B，SHA256 6F31CF7A11189C683D8455180B4EE6A6078
1D2E3F3AADF3ECC86F578D480CFA9，Linux 侧 strings 可验证版本资源存在）。
单一属性异常 → 先找第二证据再下结论。

### 11. 全盘 A/B 试运行：昨天的可用工件就是救援源

已知可用工件往往还躺在磁盘上——**下载/重装前先枚举试跑全部现存工件**（含 .bak 目录），
rescue-before-download。代价为零，还能白得 A/B 对照组。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) 注意事项）

### 12. 「拒绝访问」与 `/inheritance:r` 强相关：剥继承只用于密钥类

六个目录里唯一能跑的，恰是唯一没经过 v4 [4/9] `icacls /inheritance:r` 处理的
（它在加固前就被挪成了 .bak）。规则：**`/inheritance:r` 只用于主机密钥/
administrators_authorized_keys（sshd 强制严格权限）；二进制安装目录保持继承**
（`/reset` 恢复父继承 + 增量 grant）。最终定性待 v6 icacls 对比 + TEMP 隔离验证。

### 13. Defender 归责先查证据日志

怀疑 Defender 前先查 Defender/Operational：1116/1117（检测/处置）、1121/1122
（ASR 拦截）。两处全空 = Defender 从未盯上这个文件 → 停止怀疑、换方向
（v5 的「Defender 篡改二进制」假设因此被否，节约了安全模式弯路）。

### 14. 版本门禁 fail-closed

v4 的防 v10 检查 `$ver -match '^10\.'` 在 FileVersion 为空时静默放行。门禁逻辑
必须拒绝空/未知（fail-closed）；更稳的做法是直接拿哈希当门禁（见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §6 内容门禁）。

### 15. Windows 10 自带 ssh.exe/scp = 现成双向传输通道

System32\OpenSSH 里的客户端无需安装任何东西：用户 `scp` 从 Linux 拉 zip、
推回日志，全程只要 Linux 密码。当 Linux 防火墙开新端口需要 sudo 密码、
SMB 共享不可用时，这是唯一通路——排障第一天就该建立它。

### 15b. 无效用户名 = KEX 后 reset（不是 Permission denied）

Win10 家庭版内置 Administrator 账户默认禁用/不存在；Win32-OpenSSH 对无效用户
的行为是 KEX 完成后直接 reset 连接——极易误判为「握手层/密钥层故障」（本项目
曾在 Administrator@ 上反复测 reset）。known_hosts 已写入 = KEX 已成功；此时
reset 应首先怀疑用户名/账户有效性。**正确用户名 = Windows 登录名（whoami）**，
含空格要加引号。

### 16. 用户回传的日志同时审计我自己的脚本 bug

v5 日志暴露两处我的 bug：zip 搜索路径与用户指令不符（见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §6 依赖搜索路径）、Test-Sshd 的
null 连环崩（见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §5 exe 退出码）。发下一版前先 diff「预期输出 vs 实际输出」，把「上一版
脚本的 bug」列为排障对象——脚本的 bug 会伪装成系统的故障。

### 17. 修复脚本的清理代码只在确认失败后执行（v7 误杀教训）

v7 成功拉起 sshd（22 LISTENING + KEX 通），但成功判据函数被 stderr 噪音弄崩
误判失败，随后清理代码把刚拉起的 sshd 杀掉——「修好了又被我关掉」。规则：
（a）kill/Stop-Process 类清理只在判据**明确失败**分支执行；（b）成功判据用
Start-Process + RedirectStandardOutput/Error 双文件，勿用 `& exe 2>&1`——
Windows ssh.exe 的 `Warning: Permanently added` 走 stderr 会产生错误记录对象
污染 `$out`，match 失败（[Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §5 的再验证）。

### 17b. Windows sftp-server 路径语法 = /盘符:/，无 cygdrive；scp 下载拒带空格用户名

Win32-OpenSSH sftp-server：绝对路径写 `/D:/Epub/...`（正斜杠盘符冒号）；`/cygdrive/d/...`
不存在（那是 MSYS 语法）；`D:/path`（不带前导斜杠）会被拼接到 HOME。**先 `ls /D:/` 验证
语法再批量传输**。scp 上传方向容忍带空格用户名，**下载方向报 `invalid user name`**——
带空格 user 一律走 sftp batch（get/put 均可靠，UTF-8 文件名安全）。

### 18. PowerShell 方法参数中逗号优先级高于 -f（格式化必须加括号）

`$sw.WriteLine('{0}|{1}' -f $a,$b)` 被解析为 WriteLine(format, $a, $b) 多参数 →
命中 WriteLine(String, params Object[]) 重载 → String.Format 参数越界运行时异常
（且藏在 catch 里表现为「全部跳过」）。**修**：`$line = ('{0}|{1}' -f $a,$b); $sw.WriteLine($line)`。
同场加映：foreach 内 FileInfo 对超长路径抛异常会中断整个循环——每文件级 try/catch。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) 注意事项）

### 18b. NTFS 非法字符与跨平台同步

Linux 文件名可含 `:`（NTFS 禁）→ 推送时映射为全角 `：`；长路径 >260 需
LongPathsEnabled=1（Win32-OpenSSH sftp-server 清单已声明 longPathAware）。
跨平台同步的清单比对用 .NET EnumerateFiles 而非 Get-ChildItem -Recurse
（后者对特殊字符目录树有通配符语义漏文件风险，且两者结果要互相验证）。

### 18. SCM 服务起不来但 exe 能跑 → SYSTEM 开机任务等效兜底

服务模式 7034 意外停止（SCM 拉起即死）而 sshd.exe 手动/任务方式完全正常时：
`schtasks /create /tn OpenSSH-Server-Task /tr "\"C:\...\sshd.exe\"" /sc onstart
/ru SYSTEM /rl HIGHEST` 即可开机自启+立即可用，先恢复服务再慢慢查 SCM。
本项组合最终就是靠它打通的（服务问题原因至今未深挖，P2 遗留）。

## 实战补充 3（2026-08-17 第 14-17 轮：看门狗一劳永逸交付 + bat 编码修坑）

### 19. onstart 开机任务不可靠 → 周期看门狗兜底

`/sc onstart` 开机任务重启后**未可靠拉起 sshd**——开机任务在系统/网络/Defender 就绪前运行，失败后**无重试**。一劳永逸解法（install-keepalive.bat）：SYSTEM 计划任务 = AtStartup 触发 + 5 分钟周期重复（10 年等效时长）+ `StartWhenAvailable` + `ExecutionTimeLimit 2 分钟`；看门狗逻辑 = netstat 查端口 → 没监听则杀残留 + 清 pid + `Start-Process` 重启 + 记 keepalive.log。**任何断连 5 分钟内自愈，Linux 侧 `ssh -w` 等待即可**。
（完整编写规范见 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §12）

### 20. 远端 PowerShell 输出噪音与引号坑

`-EncodedCommand`（UTF-16LE base64）是绕三层引号地狱的基线，但还有两坑：①输出带 CLIXML 噪音（「正在准备首次使用模块」进度对象）→ 脚本首行加 `$ProgressPreference='SilentlyContinue'`；②`Get-CimInstance Win32_LogicalDisk -Filter "DeviceID=\"C:\""` 经 bash heredoc 引号被吞 → FreeSpace=null 显示 0.00GB——**绕开过滤器内引号**，用 `-Filter "DriveType=3"` 或直接查对象属性。
（移至 [Coding/windows-powershell-scripting.md](../Coding/windows-powershell-scripting.md) §13）

### 21. ssh_config 空格用户名必须引号

`User "Wang Ziyan"`——不引号报 `keyword user extra arguments`（config 解析器把空格当分隔）。连接命令同理：`ssh "Wang Ziyan"@host`。验证：`ssh -G win | grep user` 应输出完整用户名。

### 22. 看门狗验证 = 多端口体检脚本

交付自愈方案后配 Linux 侧 `win-check.sh`：ping（机器在不在）→ 22（sshd 活没活）→ 445（SMB 佐证机器在线）→ `ssh -o BatchMode=yes whoami`（认证链）；`-w` 模式循环探测等看门狗自愈（最长 6 分钟 = 看门狗周期 + 裕量）。断连时一图看清卡在哪一环，而不是盲猜。

## 实战补充 4（2026-08-19：books-sync.py v2 双机同步全流程）

### 23. sftp `-mkdir` 对已存在目录报 Failure 但继续执行

batch 里对已存在父目录 `-mkdir` 输出 `remote mkdir ... Failure`（rc=0 不中止）。push 时父目录大多已存在 → 满屏 FAIL 吓人但无害。修：mkdir 前不探测（探测也贵），接受 Failure 但错误计数时排除 mkdir 行，或 `-mkdir` 后忽略。

### 24. NTFS 大小写别名：枚举返回实际名，push 后 scan 永远报"独有"

Windows 端旧目录 `Syntax and the brain...`（小写），本地新文件用大写路径 put 落盘**成功**（NTFS 不区分大小写，实际存入小写目录），但 .NET EnumerateFiles 返回**实际存储名** → 与本地大写路径字符串不一致 → scan 永远报 Linux 独有 2。解法：**本地目录改名对齐 Windows 实际名**（且常恰好命中既有 EXCLUDE_PATHS，语义更一致）。教训：跨平台同步遇到"怎么推都差 N 个"，先怀疑大小写别名而非传输失败。

### 25. Linux `mv src dst` 当 dst 是已存在目录 = 移入内部

`mv A B` 且 B 是已存在目录 → A 被移成 B/A（不是改名）！本次把大写目录改小写名时小写目录已存在 → 变成两层嵌套。修复：先 `ls -d dst` 判断存在性，或 mv 后用 find 验证层级；嵌套目录先 `mv dir/* .` 再 `rmdir dir`。

### 26. 冒号映射变体多代共存：全角 `：` 与 `%3A` 都有历史文件

8/17 同步把 `:` 映射成全角 `：` 和 `%3A` 两种变体，散落多个目录（当代中国/、笔记/ 等），全被 EXCLUDE_PATHS 排除。本次本地 5 个半角冒号文件重命名为**全角**后与 Windows 端同 size → 自动对齐 same。规则：新文件命名直接全角 `：`，不引入 `%3A`。

### 27. 规则化排除优于逐条枚举（版本目录漂移）

EXCLUDE_PATHS 是 8/17 逐条硬编码，`.pi-subagents`（旧）vs `.pi/subagents`（新）目录名漂移导致 96 个工件漏排除。修：rule_excluded() 规则匹配（`.pi-subagents`/`.pi/subagents` 任一命中、`/.git/`、`~$*`、`*.lnk`、Thumbs.db/desktop.ini、顶层 漫画/、摄影 zip、笔记.7z）。硬编码清单保留（用户确认删除语义），规则层兜底新变体。

## 实战补充 5（2026-08-24：BOOKS 电子书双机同步日常运维指南）

电子书备份 = ~/BOOKS（Linux，2026-08-24 实测 40G/7435 文件）⇄ D:\Epub\BOOKS（Windows 46.4GB/7790 文件）双向增量同步，工具 `~/Desktop/win-ssh-setup/books-sync.py`（纯 ssh+sftp，无 rsync）。本节为**日常运维手册**；断连故障排障用上文排除链（第 4 节）与看门狗章节（#19）。

### 28. 日常同步四步（链路通时全流程）

```bash
cd ~/Desktop/win-ssh-setup
./win-check.sh              # ① 链路体检：ping / 22 / 445 / 认证
python3 books-sync.py scan  # ② 只读比对（不传文件），解读四类差异
python3 books-sync.py all   # ③ snapshot → push → pull
python3 books-sync.py scan  # ④ 复扫验证归零（差异只剩冲突与已知排除）
```

- 单方向需要时用 `push` / `pull` / `snapshot` 子命令（见 books-sync.py 头注释）
- 首次全量或大改后，先 `scan` 看预估传输 GB 再决定
- `all` 无独立 verify 步骤，以复扫归零为验证手段

### 29. 差异分类语义（scan 输出解读）

| 类别 | 含义 | all 动作 |
|---|---|---|
| push-only | Linux 独有 | 推 |
| lnx-newer | Linux 更新（mtime 新于 Windows 超 300s） | 推覆盖 |
| win-newer | Windows 更新 | 拉回 |
| pull-only | Windows 独有 | 拉 |
| conflict | 双端近改（mtime 差 ≤300s） | 跳过 + 告警，人工决定 |

mtime 三分类取代旧 size-only：大小不同 + Windows 更新时，旧版 size 比对会反向覆盖损坏数据，此为大忌。

### 30. 排除规则（rule_excluded 语义，双端各自维护）

- 大体积不拉：顶层 `漫画/`（4.85GB）、`薇薇安·迈尔Vivian Maier 摄影集.zip`（1.4GB）、`笔记.7z`
- 双端各自维护：任何 `- 链接` 目录（Linux symlink / Windows junction，互不同步）
- 垃圾/临时：`.pi-subagents`、`.pi/subagents`、`/.git/`、`~$*`、`*.lnk`、Thumbs.db、desktop.ini
- 快照目录 `backup/` 双端排除
- 新排除项：改 `rule_excluded()` 规则优于逐条加 EXCLUDE_PATHS（版本目录漂移教训，见 #27）

### 31. 快照策略（备份语义）

`all`/`snapshot` 自动把**即将被推覆盖的 Windows 侧旧版**复制到 `D:\Epub\BOOKS\backup\linux-YYYYMMDD\`（同名相对路径）。撤销窗口 = 该快照目录。**拉方向不建本地快照**（拉回覆盖的本地旧版无自动备份）——大操作前手动 `python3 books-sync.py snapshot` 并自行备份本地侧。

### 32. 断连处理（22 关闭时）

1. `./win-check.sh -w` 等待看门狗自愈（最长 6 分钟 = 5 分钟周期 + 裕量）
2. 超时未恢复：看门狗未装或失效 → Windows 侧双击 `install-keepalive.bat`（一次性安装）；应急 `restart-sshd.bat`
3. 已装看门狗仍断：按上文排除链排查（先 `win-check.sh` 看卡在哪一环）

### 33. 已知坑速查（详见实战补充 4 #23-27）

- sftp `-mkdir` 已存在报 Failure 无害（忽略 mkdir 行，勿当传输失败）
- 怎么推都差 N 个 → 先怀疑 NTFS 大小写别名（本地改名对齐 Windows 实际名）
- 新文件命名禁半角冒号 `:`（NTFS 禁），直接全角 `：`，勿引 `%3A` 变体
- Linux `mv` 目标已存在目录 = 移入内部（先 `ls -d` 判存在）
- 清单用 .NET EnumerateFiles（Get-ChildItem -Recurse 通配符漏 `[ ]` 目录树）

### 34. 2026-08-24 实测（链路中断处理记录）

23:47 体检：ping UP / 22 CLOSED / 445 OPEN → `win-check.sh -w` 等满 6 分钟未恢复（看门狗未装或失效，用户侧需确认 install-keepalive.bat 是否已双击）→ 需 Windows 侧人工拉起。结论：**断连先等 5 分钟看门狗；不恢复 = 人肉介入，勿反复重试制造噪音**。

### 35. 内容哈希预检（2026-08-25 新增，v1.6.0）

**问题**：books-sync.py 只按路径比对，无内容交叉匹配——两机并行下载同一本书（不同文件名）时，双向同步会把两份都合并到每侧 = 静默制造重复（实战：食人族 epub 短名版 vs Anna's Archive 长名版同 hash 226,487B）。

**解法**：push/pull 候选跨侧 SHA256 交叉匹配，同内容不同路径 = 「重复合并」预警：
- `scan`：只读报告 ⚠️ 预警对（L/W 路径 + 大小 + hash 前缀），不排除任何传输
- `all`/`push`/`pull`：默认**从传输排除命中对**（双端各留自己那份，不制造新重复；下次 scan 仍可见，迫使用户显式决策）
- `all --allow-dup-merge`：强制照常传输（有意镜像时用）
- 预检失败（远端哈希跑不起来）fail-open 继续旧行为并打 [WARN]

**实现**：本地直接流式 SHA256；远端复用 snapshot 模式（ps1 带 BOM 上传 → `powershell -File` 跑 `Get-FileHash` → 结果写 %TEMP% → sftp get 解析）。测试：`echo` 会带尾随换行、`printf '%s'` 不带——测试数据必须字节级一致，否则预检不命中是测试自己的坑。

## 实战补充 6（2026-09-02：自动备份运维 + 快照清理 + 体积审计）

### 36. 快照策略运维：旧快照必须定期清理（备份瘦身第一刀）

**问题**：backup/linux-YYYYMMDD 快照只增不减——每次 `all` 都会把被覆盖的 Windows 旧版复制进快照目录，长期积累体积可观（本次清理前 5 个快照共 313.8MB，其中 linux-20260817 一个就 298.9MB/198 文件，占绝对大头）。

**清理命令**（保留 backup/ 目录本身，只删旧快照子目录）：

```powershell
$d=Get-ChildItem -LiteralPath D:\Epub\BOOKS\backup -Directory -Force; $d | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
```

**纪律**：
- 快照只保存**被覆盖前**的旧文件，保留最新一次即可满足应急回滚——旧的直接删（本次用户裁定：旧快照全删，其他绝对不动）
- 删除后验证：`Get-ChildItem backup -Force` 应为空（LEFT=0）
- 保留 backup/ 目录本身（books-sync 快照逻辑依赖其存在）；删除只作用于子目录
- 建议纳入日常运维：每次同步后顺手清掉非最新快照（瘦身成本最低、零风险）

### 37. 远端 PowerShell 输出编码坑：CLIXML 噪音吞 grep + UTF-8 中文文件名解码失败

**现象**：`ssh win 'powershell ...'` 列中文文件名/目录体积时：①输出含 CLIXML 进度噪音（UTF-16 编码），`grep -v` 把它当**二进制**吞掉（报 `binary file matches`），整条管道失效只剩 backup 一行；②去除噪音后中文文件名仍可能 GBK/CP936 编码，python `utf-8` 解码直接 `UnicodeDecodeError`（0xb6 等）。

**修复（三件套）**：
1. 脚本首行加 `[Console]::OutputEncoding=[Text.Encoding]::UTF8` + `$ProgressPreference="SilentlyContinue"`（CLIXML 噪音与编码一并解决）
2. 输出解析**不要经 grep 过滤**（grep 遇 UTF-16 即二进制模式、行为不可预测）——直接 `2>/dev/null` 喂给 python3，用 `\t` 分隔解析
3. python 侧以 `line.rstrip('\r\n')` + `rsplit('\t',1)` 解析，数字行才入表，噪音行自然丢弃

**反模式**：①`grep -vE 'CLIXML|Objs Version|...'`（grep 报 binary file matches 后过滤器静默失效）②python 直接 utf-8 读远端输出（中文路径未设 UTF8 前缀时必炸）。

### 38. 远端体积审计：BOOKS 双端体积对照 + 顶层目录排行

**方法**（ssh win + PowerShell 递归求和）：

```powershell
Get-ChildItem -LiteralPath D:\Epub\BOOKS -Directory -Force | ForEach-Object { $s=(Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum; Write-Output ($_.Name + [char]9 + [math]::Round($s/1MB,1)) }
```

**判读**：Windows 48.66GB/8479 文件 vs Linux 41GB/7655 文件——多出 ~7.7GB 的构成 = 排除项（漫画/ 4.5GB + 薇薇安·迈尔摄影集.zip 1.34GB，规则「大体积不拉」指不拉回 Linux，**不代表不占 Windows 磁盘**）+ 快照 0.31GB + 顶层散件差异 ~1.4GB。核心藏书（学术/ 34GB）是真实存量，不可缩。

### 39. 排除项 ≠ 不占空间（思想型，可迁移）

「排除规则」只控制**传输方向**（哪些不拉/不推），不控制**存量占用**。books-sync 的 EXCLUDE_PATHS 排除「大体积不拉」的 漫画/、摄影集.zip 仍完整躺在 Windows 磁盘上——体积审计时若只对比「双端同步清单」会得出「已排除所以不存在」的错误结论。**排除是同步语义，删除是磁盘语义，两者必须分开决策。**（迁移检验：任何同步/备份工具的 exclude 规则都只影响传输，不影响两端既有文件）

### 40. 自动备份主链路与瘦身决策分工（思想型）

本次自动备份的经验沉淀：日常备份主链路 = `win-check.sh` 体检 → `scan` 预估 → `all` 传输 → **复扫归零验证**（差异只剩已知重复对与已知排除）。瘦身是独立决策轴：快照清理（低成本安全）→ 排除项删除（需用户确认，涉及存量删除）→ 核心藏书（不可缩）。**先问「哪些能删」再删，快照以外的删除永远等用户明确指令。**

## 实战补充 7（2026-09-03：日常同步收官 + 内容重复对「对齐路径」消解）

### 41. sftp batch 首条命令失败即中止整批——预检 ls 会杀死 rename

`-b` 批处理里任何**不带 `-` 前缀**的命令返回失败 → sftp 立即退出，后续 rename/put 全部不执行。本次在 rename 前放 `ls -l 目标路径`（本意「确认目标不存在」）→ 目标不存在正是**预期结果**，却触发中止，rename 静默未跑。

**修**：①批内「允许失败」的命令一律加 `-` 前缀（`-ls`、`-mkdir`、`-put`）②或干脆不预检，事后单独验证（本次靠 scan 复扫确认 rename 生效）。与 #23（`-mkdir` 已存在报 Failure 但 rc=0 继续）同源：**sftp batch 的错误处理由 `-` 前缀显式声明，不能指望 rc**。

### 42. 同路径 + 同大小 = 判定「一致」；mtime 只在大小不同时决定方向

books-sync 比对逻辑：路径双端都存在时，**只有 size 不同才进 mtime 三分类**（lnx-newer / win-newer / conflict）；size 相同直接视为一致、不传输。

三条推论：
- **内容重复对（同 hash 不同路径）的最优解是改名对齐路径，不是删除**——双端各留一份 → 对齐后 size 相同 → scan 立即归零、零传输、零快照、零数据风险。比 `--allow-dup-merge`（制造 4 份）和删文件都干净。
- 反之「同路径不同内容」才会触发覆盖 + 快照。
- **sftp put 不保留 mtime**（实测：推过去后 Windows mtime = 传输时刻，与 Linux 源差 20 小时）——刚同步完的文件 mtime 差异大不是故障，只要 size 相同就不会被反向覆盖。

### 43. 远端目录/快照验证的免 PowerShell 通道：cmd dir + iconv GBK

`ssh win 'cmd /c dir /s /a-d <path>'` 输出 GBK，直接 grep 报 `binary file matches`（#37 同坑）。管道接 `| iconv -f GBK -t UTF-8` 后即可 grep「个文件 / File(s)」与文件名，一次拿到「文件数 + 总字节」两级汇总，比起 PowerShell 轻得多。

**反模式**：`ssh win "powershell -NoProfile -Command (Get-ChildItem ...)"` 经 bash 传参时引号极易被吞（本次 rc=255 + 空输出）。**能用 cmd dir 就别起 PS**；必须起 PS 时用 `-EncodedCommand`（UTF-16LE base64）+ 首行 `$ProgressPreference='SilentlyContinue'`（#20）。

### 44. 2026-09-03 实测（四步全绿 + 重复对消解）

win-check 全绿（ping / 22 / 445 / auth）→ scan：push-only 42、lnx-newer 3、pull-only 23、conflict 0（推 0.16GB / 拉 0.10GB）→ all：快照 `linux-20260903`（3 文件 67.0MB，cmd dir 复核）+ 预检排除 4 项 + push rc=0（10 条 mkdir 噪音）+ pull rc=0 → 复扫剩 2+2（已知重复对）→ 按 #42 对齐路径（Linux `mv` 1 个 + Windows `sftp rename` 1 个，零删除）→ 终扫**五类差异全 0，双端各 7369 文件**。

体积：Windows 48.59GB/8326 ⇄ Linux 42GB/7790，差值全为排除项存量（#39）。快照目录仅最新一个（09-02 已清空），本轮无清理动作。

## 变更日志

### 1.8.1 (2026-09-03)
- 新增：实战补充 7（41-44 条）——#41 sftp batch 首条失败即中止整批（预检 ls 杀死 rename，`-` 前缀才是错误声明）、#42 同路径+同大小即判一致（mtime 仅在大小不同时决定方向；内容重复对最优解是改名对齐路径而非删除；sftp put 不保留 mtime）、#43 远端目录验证免 PS 通道（cmd dir /s /a-d + iconv GBK，PS 经 ssh 传参引号被吞 rc=255）、#44 09-03 四步实测与重复对消解记录
- 同步：System_Fix/index.md 条目 16 版本号与描述、变更历史 2.18.0

### 1.8.0 (2026-09-02)
- 改名：`windows-scripting-and-ssh-debug.md` → `windows-backup-and-ssh-debug.md`（主职责为 Windows ⇄ Linux 双机备份；SSH 排障降为支撑）；front matter name/description 同步，triggers 新增 备份windows、双机备份、快照清理、备份体积、backup 清理
- 新增：实战补充 6（36-40 条）——#36 快照清理命令与纪律、#37 远端 PowerShell 输出编码三件套（CLIXML 吞 grep + UTF-8 中文）、#38 远端体积审计方法、#39 排除项≠不占空间、#40 自动备份主链路与瘦身决策分工
- 同步：System_Fix/index.md、Coding/index.md、Coding/windows-powershell-scripting.md 交叉引用改为新文件名

### 1.7.0 (2026-08-31)
- 拆分：脚本编写规范（原第 1 节 A-Q 共 17 条 + 第 5 节协作闭环）移至新 skill `Coding/windows-powershell-scripting.md`（v1.0.0，Windows 端 .bat/.ps1 专精）
- 压缩：实战补充 #1/#2/#3/#5/#6/#7/#9/#11/#14/#16/#17/#18/#19/#20 保留要点 + 指向新 skill 对应节；原 F 条/M 条/O 条内部引用同步更新为指向新 skill
- 保留：SSH 排障本体（黑盒三测试/排除链/ACL/身份鉴定/杀软/兜底任务/sftp/books-sync 运维）以及实战补充 #4/#8/#10/#12/#13/#15/#15b/#17b/#18b/#21/#22/#23-35 不动
- 同步：front matter 描述与 triggers 精简（脚本编写触发词移至新 skill）；System_Fix/index.md 条目同步更新

### 1.6.0 (2026-08-25)
- 新增：实战补充 5 #35 内容哈希预检——push/pull 候选跨侧 SHA256 交叉匹配防静默重复合并；scan 只读报告 / 传输模式默认排除 / `--allow-dup-merge` 强制；远端哈希走 ps1+Get-FileHash 模式
- 更新：books-sync.py 新增 `--allow-dup-merge` flag；#28 四步流程说明不变（scan 现在会显示 ⚠️ 重复合并预警）
- 同步：index.md 条目 16 描述更新（若 index 未变则无）

### 1.5.0 (2026-08-24)
- 新增：实战补充 5（28-34 条）——BOOKS 电子书双机同步日常运维指南：日常四步流程（win-check → scan → all → 复扫）、差异分类语义表（push/lnx-newer/win-newer/pull/conflict）、排除规则语义、快照策略（推方向自动快照 Windows 旧版至 backup/linux-YYYYMMDD；拉方向无自动快照）、断连处理决策（看门狗等待/人肉介入）、已知坑速查、08-24 链路中断实测记录
- 新增：triggers「同步电子书」「BOOKS 备份」「电子书同步」；description 补充运维指南说明
- 同步：index.md 条目 16 描述更新

### 1.4.1 (2026-08-19, 四修)
- 新增：实战补充 4（23-27 条）——sftp mkdir 已存在报 Failure 无害、NTFS 大小写别名（枚举实际名 vs 推送名）、mv 目标已存在目录=移入内部、冒号映射变体全角/%3A 共存、规则化排除 vs 逐条枚举——books-sync.py v2 双机同步实战
- 同步：index.md 条目 16 描述更新

### 1.4.0 (2026-08-17, 三修)
- 新增：编写规范 P（bat 纯 ASCII + CRLF，GBK 代码页 UTF-8 解析失败根因 + file 判据 + UAC 失败分支停留）、Q（bat 内嵌 ps1 单文件交付：重定向前置 echo 防句柄坑、内嵌内容禁 cmd 元字符、生成后 ROUND-TRIP 回验）
- 新增：实战补充 3（19-22 条）——onstart 开机任务不可靠→周期看门狗（AtStartup+5 分钟循环+StartWhenAvailable+ExecutionTimeLimit）、远端 PS 引号/CLIXML 噪音两坑、ssh_config 空格用户名引号、多端口体检脚本验证
- 同步：index.md 条目 16 描述更新

### 1.3.0 (2026-08-17, 同日二修)
- 二修：追加 17b（sftp /盘符:/ 语法+scp 空格用户名+逗号优先级坑+每文件 try/catch）、18b（NTFS 冒号映射/长路径/清单枚举）——books-sync.py 实战（五坑连环）
- 一修：追加 15b（无效用户名=KEX 后 reset，正确用户名=登录名）、17（清理代码只在确认失败后执行+判据双文件方案）、18（SYSTEM 开机任务等效服务兜底）——v7 实战 + 最终打通复盘
- 新增：编写规范 M/N/O——外部 exe 试运行取退出码（Start-Process 方案）、修复脚本 Start-Transcript 落盘、依赖搜索路径覆盖用户指令路径 + SHA256 内容门禁
- 新增：排除链 step 0 存在性检查（sc qc 1060 = 服务从未注册）+ TEMP 隔离试跑判别器（路径拦截 vs 内容拦截）
- 新增：实战补充 2（9-16 条）——吞错组合、空 FileVersion 误诊（身份鉴定三件套）、全盘 A/B 试跑+救援源、/inheritance:r 适用边界、Defender 归责证据化、版本门禁 fail-closed、自带 scp 通道、审计自己的脚本 bug

### 1.2.0 (2026-08-16)
- 新增：脚本输出文本规范（ASD-STE100）——脚本编写规范自查新增「E. 输出消息规范」，echo/Write-Host/错误提示/交互询问遵守简化技术英语的短句/祈使/术语一致/状态前缀规范，详见 technical-writing-standard.md 第 7 节

### 1.1.0 (2026-08-16)
- 新增：实战补充 8 条（测试函数原始输出、绝对路径客户端、MOTW 陷阱、杀软接力、
  SCM vs Start-Process 差异、兜底链杀进程、Startup 快捷方式、协作节奏）
- 新增：Windows Defender 排除/关闭命令（Add-MpPreference / Set-MpPreference）
