---
name: windows-scripting-and-ssh-debug
version: 1.2.0
description: Windows 端 .bat/.ps1 脚本编写规范自查与 OpenSSH 远程排障——KEXINIT reset 排除链、黑盒三测试、前台 vs 服务模式差异定位、脚本化协作闭环
triggers:
  - "Windows 脚本"
  - "bat 脚本"
  - "PowerShell 脚本"
  - "SSH 连不上 Windows"
  - "KEXINIT"
  - "Connection reset"
  - "Windows OpenSSH"
  - "火绒拦截 SSH"
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

Windows 端工具（.bat/.ps1）之编写、审查与远程排障，皆本 skill 范围。Linux 主机不能直接执行 Windows 脚本——一切操作经「用户双击脚本 + 回传输出」闭环完成。2026-08-16 win-ssh-setup 实战（KEXINIT reset 五日排障、rsync 解压失败、语法检查器误报）沉淀于此。

## 任务目标

1. 编写/审查 Windows 端脚本时，规避编码、语法、权限、上下文四类陷阱
2. Windows OpenSSH "Connection reset after KEXINIT" 类故障，按排除链由外至内定位
3. 每个排查步骤脚本化，用户双击即跑，输出回传，逐步收敛

## 执行流程

### 1. 脚本编写规范自查（写/改 .bat/.ps1 前必过）

**A. .bat 编码**：批处理文件必须纯 ASCII（cmd 用 OEM 代码页解析，非 ASCII 字节变乱码）。自查：`LC_ALL=C grep -qP '[\x80-\xFF]' file.bat`。

**B. 提权三件套**（双击自动弹 UAC）：

```bat
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)
```

`%~f0` 绝对路径保证目录含空格也安全；RunAs 后工作目录变化不影响后续 `%~dp0` 调用。

**C. PowerShell 5.1 语法陷阱**（朴素括号/引号检查器会误报，须用 PS 感知检查器）：

| 构造 | 说明 | 误报场景 |
|---|---|---|
| `${...}` | 变量界定符（如 `${env:TEMP}`），**不是**花括号块 | 朴素检查器报「花括号不匹配」 |
| `''` | 单引号串内转义单引号 | 检查器误判字符串提前结束 |
| `@'...'@` / `@"..."@` | here-string | 检查器漏处理 |
| `` ` `` | 反引号转义（`` `" ``、`` `n ``） | 双引号串内误判 |
| `-f "…{0}…{1}…"` | 格式串内 `{}` 非块 | 同上 |

验证法：Python 写 PS 感知检查器（处理注释 `#`、三种字符串、here-string、`${}` 跳过），跑通再交付。

**D. 编码**：PS 5.1 `-Encoding UTF8` 写文件**带 BOM**——pacman mirrorlist 等解析类文件首行会告警，内容 ASCII 时用 `-Encoding ASCII`。

**E. 权限**：`Get-Acl`/`icacls` 读 `C:\ProgramData\ssh` 等受保护目录，非管理员直接 `UnauthorizedAccessException`——诊断脚本须提示管理员运行或自动提权。

**F. 原生命令 stderr 陷阱**：`$ErrorActionPreference='Stop'` + ssh.exe 写 stderr（如 `Warning: Permanently added...`）→ `NativeCommandError` **中止整个脚本**（服务恢复等后续步骤丢失）。诊断类脚本用 `'Continue'`，命令加 `2>&1 | Out-String`。

**G. 测试命令防挂起**：ssh 测试一律 `-o BatchMode=yes -o ConnectTimeout=5`。注意 `Permission denied (publickey)` **不是故障**——KEX 已通、仅未配公钥；`Connection reset`/`timeout` 才是故障。

**H. tar 盘符陷阱**：Windows bsdtar 归档绝对路径保留盘符（`D:\ebooks` → 条目 `D:/ebooks/...`），Linux 端解压出 `D:` 子目录。修复：`pushd "%SRC%" && tar cf - . | ssh ... && popd`。

**I. bsdtar 解压 .tar.xz 需外部 xz**：Windows 10 自带 bsdtar 不内置 xz 解压器，报 `Can't initialize filter; unable to run program "xz -d -qq"`。修复：下载官方 `xz-5.8.3-windows.zip`（tukaani.org / GitHub 双源）→ `Expand-Archive` → 复制 `xz.exe` 到 `System32`。

**J. 脚本自包含**：补丁/修复脚本的常量、变量、函数、import 必须完整（「apply 模式」才有意义），交付前 grep 核对关键标识符都在文档内。

**K. 外部资源预检**：脚本引用的下载 URL 先 `curl -sIL` 验证 200，版本号硬编码需确认当前有效。

**L. 输出消息规范（ASD-STE100）**

脚本与用户的自动化文字交互（echo / Write-Host / 错误提示 / 交互询问）遵守 ASD-STE100（简化技术英语，国际标准）：

- **短句**：一条消息 ≤ 20 词（中文 ≤ 40 字），一句一个信息
- **指令祈使**：提示操作直接说"要做什么"（"Press Enter to continue."）
- **术语一致**：同一脚本内同一概念同一措辞，不换同义词
- **状态消息**：用固定前缀模板（[OK] / [FAIL] / [WARN]），与测试函数的 PASS/FAIL 输出风格统一
- **错误消息**：先说原因再说动作，附可执行建议（本条与本文件「测试函数必须输出原始错误」经验协同）
- **中文脚本**：避免混用中英文标点，全角/半角统一

完整规范见 [technical-writing-standard.md](../technical-writing-standard.md) 第 7 节。

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

**火绒暴力破解防护**：多次连接失败 + nmap 扫描会触发源 IP 临时拉黑（症状：localhost PASS 但外部持续 reset，等待数分钟无效）——排障时减少无谓重试，先查火绒安全日志。

### 5. 脚本化协作闭环

每个排查步骤产出一个可双击脚本（.bat 启动器 + .ps1 逻辑），模式：

```text
.bat: 提权检查 → powershell -ExecutionPolicy Bypass -File "%~dp0xxx.ps1" → pause
.ps1: 分阶段输出 [N/M] → 每步 try/catch 容错 → 结果多位置写入
      （桌面 + $PSScriptRoot + %TEMP%，防 OneDrive 桌面重定向）
```

用户跑完 → 输出贴回（文件放 ~/Downloads/agony.md 或直接贴文本）→ 分析 → 下一步脚本。版本演进：diag-sshd → diag-sshd2（补日志源/ACL）→ diag-sshd3（前台调试）——每版修复上一版盲区，保留演进链可追溯。

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

修复脚本的验证函数若只返回 PASS/FAIL 而不显示原始输出，Linux 侧无法区分
`Connection refused`（服务没监听）vs `Connection reset`（服务在监听但握手崩）vs
`timeout`（防火墙丢包）——三者修复方向完全不同。**验证函数 FAIL 时打印 $out 前 300 字符**。

### 2. 测试客户端必须用绝对路径，勿依赖 PATH

`& ssh` 依赖 PATH 解析：提权后当前目录是 System32，PATH 可能指向被移动/损坏/被拦的
ssh.exe → `ApplicationFailedException 拒绝访问` → 所有阶段假 FAIL。
**修**：`Get-SshClient` 优先 `C:\Windows\System32\OpenSSH\ssh.exe`（内置客户端，微软签名），
再 `C:\Program Files\OpenSSH\ssh.exe`，用绝对路径调用。

### 3. MOTW 理论陷阱：Expand-Archive 不传播 Mark-of-the-Web

下载 zip 带 MOTW（Zone.Identifier ADS），但 **Expand-Archive 解压出的文件不带 ADS**——
「解压 exe 被 SmartScreen 拦」是错误假设。若解压后 exe 执行拒绝访问，另找原因
（ACL/Defender 实时保护锁文件/占用），勿在 Unblock-File 上浪费轮次。

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
   Running 但 sshd 内部初始化失败（配置/绑定），测试显示 refused
2. **文件是否被占用**（服务持有 exe 句柄时二次启动可能拒绝）
3. **ACL 是否允许当前用户执行**（icacls 查具体文件，勿只看目录）
4. **杀软实时保护锁文件**（Defender 扫描中新下载 exe）
5. 测试前 `taskkill /F /IM sshd.exe` 杀干净旧实例，避免端口占用假象

### 6. 修复脚本切换运行上下文（服务→任务→Run 键）前必须杀旧进程

兜底链（服务→schtasks→Startup）切换时，旧实例若仍占 22 端口，新实例绑定失败、
测试连到旧实例 → 假 FAIL。每阶段切换前 `taskkill /F /IM sshd.exe`。

### 7. HKCU Run 键写入「拒绝访问」用 Startup 文件夹快捷方式绕过

注册表 Run 键可能被第三方防护 ACL 锁（Owner 异常为 SYSTEM）；自启动改用
`[Environment]::GetFolderPath('Startup')` + WScript.Shell 快捷方式，不依赖注册表。
schtasks /sc onlogon 需密码会在提权窗口卡住——勿用。

### 8. 排障协作的收敛节奏

- 每轮只给「1 个脚本 + 用户双击 + 输出回传」，勿让用户跑多条命令
- 脚本输出全部诊断（where ssh/ACL/Run 键/AV 进程/残留注册表）——一次回传解决一轮
- 用户贴回的文件（agony.md）每次 md5 变化，先 diff 再分析，勿重复读旧结论

## 变更日志

### 1.2.0 (2026-08-16)
- 新增：脚本输出文本规范（ASD-STE100）——脚本编写规范自查新增「E. 输出消息规范」，echo/Write-Host/错误提示/交互询问遵守简化技术英语的短句/祈使/术语一致/状态前缀规范，详见 technical-writing-standard.md 第 7 节

### 1.1.0 (2026-08-16)
- 新增：实战补充 8 条（测试函数原始输出、绝对路径客户端、MOTW 陷阱、杀软接力、
  SCM vs Start-Process 差异、兜底链杀进程、Startup 快捷方式、协作节奏）
- 新增：Windows Defender 排除/关闭命令（Add-MpPreference / Set-MpPreference）
