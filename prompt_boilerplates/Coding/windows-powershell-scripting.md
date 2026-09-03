---
name: windows-powershell-scripting
version: 1.0.0
description: Windows 端 .bat/.ps1 脚本编写规范自查——ASCII+CRLF 编码、提权三件套、PS 5.1 语法陷阱、单文件内嵌交付、外部 exe 退出码、Transcript 落盘、依赖内容门禁、测试函数与上下文切换、看门狗自愈、远端 PS 引号坑（自 windows-backup-and-ssh-debug 拆分，Windows 专精）
triggers:
  - "Windows 脚本"
  - "PowerShell 脚本"
  - "bat 脚本"
  - "ps1 脚本"
  - "提权脚本"
  - "内嵌 ps1"
  - "脚本编码"
inputs:
  - name: script_path
    description: 待编写/审查的 Windows 脚本路径
    required: true
  - name: purpose
    description: 脚本用途（修复/诊断/同步/交付）
    required: false
    default: "auto-detect"
tools:
  - read
  - bash
  - grep
  - edit
  - write
---

# Windows 脚本编写规范（.bat/.ps1）

Windows 端工具（.bat/.ps1）之编写、审查与交付规范。Linux 主机不能直接执行 Windows 脚本——一切操作经「用户双击脚本 + 回传输出」闭环完成。经验源：2026-08-16 win-ssh-setup 实战（KEXINIT reset 五日排障、rsync 解压失败、语法检查器误报）与 books-sync 双机同步；OpenSSH 远程排障本体见 [windows-backup-and-ssh-debug.md](../System_Fix/windows-backup-and-ssh-debug.md)。

## 任务目标

1. 编写/审查 Windows 脚本时，规避编码、语法、权限、上下文四类陷阱
2. 交付单文件可双击脚本，用户零门槛执行，输出可回传
3. 每个排查/修复步骤脚本化，证据落盘，逐步收敛

## 执行流程

### 1. 编码与行尾自检（写/改 .bat 前必过）

- **.bat 必须纯 ASCII**：cmd 用 OEM 代码页（中文 Windows = GBK）解析，非 ASCII 字节变乱码，UTF-8 中文直接解析失败。自查：`LC_ALL=C grep -qP '[\x80-\xFF]' file.bat`
- **.bat 必须 CRLF**：LF-only 在多行括号块下解析不稳。判据：`file x.bat` 输出 `ASCII text, with CRLF line terminators`。能跑的历史文件（diag-svc / fix-sshd-v7 / push-backup）全是纯 ASCII——用户提示信息用英文（配合 ASD-STE100）
- **UAC 提权失败分支必须停留**（goto :eof 前 echo + pause），不能闪退，否则表现为「双击没反应」
- **PS 5.1 `-Encoding UTF8` 写文件带 BOM**——pacman mirrorlist 等解析类文件首行会告警，内容 ASCII 时用 `-Encoding ASCII`

### 2. 提权三件套（双击自动弹 UAC）

```bat
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)
```

`%~f0` 绝对路径保证目录含空格也安全；RunAs 后工作目录变化不影响后续 `%~dp0` 调用。

### 3. PowerShell 5.1 语法陷阱（朴素括号/引号检查器会误报，须用 PS 感知检查器）

| 构造 | 说明 | 误报场景 |
|---|---|---|
| `${...}` | 变量界定符（如 `${env:TEMP}`），**不是**花括号块 | 朴素检查器报「花括号不匹配」 |
| `''` | 单引号串内转义单引号 | 检查器误判字符串提前结束 |
| `@'...'@` / `@"..."@` | here-string | 检查器漏处理 |
| `` ` `` | 反引号转义（`` `" ``、`` `n ``） | 双引号串内误判 |
| `-f "…{0}…{1}…"` | 格式串内 `{}` 非块 | 同上 |

验证法：Python 写 PS 感知检查器（处理注释 `#`、三种字符串、here-string、`${}` 跳过），跑通再交付。

### 4. 权限与错误处理

- **权限**：`Get-Acl`/`icacls` 读 `C:\ProgramData\ssh` 等受保护目录，非管理员直接 `UnauthorizedAccessException`——诊断脚本须提示管理员运行或自动提权（§2）
- **原生命令 stderr 陷阱**：`$ErrorActionPreference='Stop'` + ssh.exe 写 stderr（如 `Warning: Permanently added...`）→ `NativeCommandError` **中止整个脚本**（服务恢复等后续步骤丢失）。诊断类脚本用 `'Continue'`，命令加 `2>&1 | Out-String`
- **吞错组合拳**：`-ErrorAction SilentlyContinue` + `2>&1` = 把最需要的真实报错吞得干干净净（只看到 StartType 不动）。要真实报错：`try { Start-Service x -ErrorAction Stop } catch { $_.Exception.Message }`
- **测试命令防挂起**：ssh 测试一律 `-o BatchMode=yes -o ConnectTimeout=5`。注意 `Permission denied (publickey)` **不是故障**——KEX 已通、仅未配公钥；`Connection reset`/`timeout` 才是故障

### 5. 外部 exe 试运行必须取退出码，勿信「无输出」

`& $exe -t 2>&1` 在 exe 根本无法启动时（拒绝访问）抛 `NativeCommandFailed`，且 `$out` 保持 null → 后续 `.Trim()` 连环崩（实况：57/60 行双报错）。**无输出 ≠ 成功**。

**修**：`Start-Process -Wait -PassThru -RedirectStandardError <tmpfile>` 取 `$p.ExitCode`（负数格式化 `0x{0:X8}` 便于认 NTSTATUS，-1=0xFFFFFFFF）。成功判据用 Start-Process + RedirectStandardOutput/Error 双文件，勿用 `& exe 2>&1`——Windows ssh.exe 的 `Warning: Permanently added` 走 stderr 会产生错误记录对象污染 `$out`，match 失败。

### 6. 脚本自包含与依赖内容门禁

- **自包含**：补丁/修复脚本的常量、变量、函数、import 必须完整（「apply 模式」才有意义），交付前 grep 核对关键标识符都在文档内
- **外部资源预检**：脚本引用的下载 URL 先 `curl -sIL` 验证 200，版本号硬编码需确认当前有效
- **依赖搜索路径** = 给用户的指令路径 ∪ 脚本目录 ∪ Downloads。发布前把用户指令里每个路径对着脚本搜索清单核一遍（实况：让用户把 zip 放 `D:\Downloads\`，脚本却只搜 `$PSScriptRoot` → 白跑一轮）
- **内容寻址**：zip 解压后先试运行 + SHA256 对官方指纹，装完再比一次哈希（当场抓 AV 篡改）
- **版本门禁 fail-closed**：`$ver -match '^10\.'` 在 FileVersion 为空时静默放行——门禁逻辑必须拒绝空/未知；更稳的做法是直接拿哈希当门禁

### 7. 修复脚本必须 Start-Transcript

五轮修复不落盘日志，全部证据丢失、只能重跑诊断。`Start-Transcript -Path <桌面>\xxx-log.txt` + 退出前 `Stop-Transcript`，原生命令输出也捕获；用户关窗/闪退仍有全量日志可回传。

### 8. 单文件自包含交付（bat 内嵌 ps1）

需要用户在 Windows 侧双击一个文件搞定一切时，把 ps1 逐行 echo 进 `%TEMP%\x.ps1` 再执行（`>>"%PS%" echo <line>`，空行用 `echo.`）：

- **重定向前置**：`>>"%PS%" echo xxx`——内容以数字结尾（如 `exit 1`）时后置写法会把尾数当句柄（`1>>`）
- **内嵌内容禁用 cmd 元字符** `| & % < > ^ !`（含注释）——`grep -nE '[|&%<>^!`]'` 验证
- **生成后必须回验**：awk/sed 从 bat 提取内嵌段 diff 源 ps1，`ROUND-TRIP OK` 才算数
- 单文件 = 用户只传一次，杜绝多文件散落/编码被改的二次故障源

### 9. 输出消息规范（ASD-STE100）

脚本与用户的自动化文字交互（echo / Write-Host / 错误提示 / 交互询问）遵守 ASD-STE100（简化技术英语，国际标准）：

- **短句**：一条消息 ≤ 20 词（中文 ≤ 40 字），一句一个信息
- **指令祈使**：提示操作直接说「要做什么」（"Press Enter to continue."）
- **术语一致**：同一脚本内同一概念同一措辞，不换同义词
- **状态消息**：用固定前缀模板（[OK] / [FAIL] / [WARN]），与测试函数的 PASS/FAIL 输出风格统一
- **错误消息**：先说原因再说动作，附可执行建议
- **中文脚本**：避免混用中英文标点，全角/半角统一

完整规范见 [technical-writing-standard.md](../Writing/technical-writing-standard.md) 第 7 节。

### 10. 测试函数规范

- **必须输出原始错误**：验证函数若只返回 PASS/FAIL 而不显示原始输出，无法区分 `Connection refused`（服务没监听）vs `Connection reset`（服务在监听但握手崩）vs `timeout`（防火墙丢包）——三者修复方向完全不同。**验证函数 FAIL 时打印 $out 前 300 字符**
- **客户端必须用绝对路径，勿依赖 PATH**：提权后当前目录是 System32，PATH 可能指向被移动/损坏/被拦的 exe → `ApplicationFailedException 拒绝访问` → 假 FAIL。**修**：优先 `C:\Windows\System32\OpenSSH\ssh.exe`（内置客户端，微软签名），再 `C:\Program Files\OpenSSH\ssh.exe`，用绝对路径调用
- **审计自己的脚本 bug**：用户回传日志时先 diff「预期输出 vs 实际输出」，把「上一版脚本的 bug」列为排障对象——脚本的 bug 会伪装成系统的故障

### 11. 运行上下文切换

- **SCM 能启动服务、用户 Start-Process 同 exe 拒绝访问**的排查方向：①服务进程是否真的监听（`netstat -ano | findstr :22` + 进程名）——服务可能 Running 但内部初始化失败（配置/绑定） ②文件是否被占用（服务持有句柄时二次启动可能拒绝） ③ACL 是否允许当前用户执行（icacls 查具体文件，勿只看目录） ④杀软实时保护锁文件（Defender 扫描中新下载 exe） ⑤测试前 `taskkill /F /IM` 杀干净旧实例，避免端口占用假象
- **切换上下文前必须杀旧进程**：兜底链（服务→任务→Run 键）切换时，旧实例若仍占端口，新实例绑定失败、测试连到旧实例 → 假 FAIL。每阶段切换前 `taskkill /F /IM`
- **HKCU Run 键写入「拒绝访问」**用 Startup 文件夹快捷方式绕过：注册表 Run 键可能被第三方防护 ACL 锁（Owner 异常为 SYSTEM）；自启动改用 `[Environment]::GetFolderPath('Startup')` + WScript.Shell 快捷方式，不依赖注册表。schtasks /sc onlogon 需密码会在提权窗口卡住——勿用
- **清理代码只在确认失败后执行**：成功判据函数被 stderr 噪音弄崩误判失败 → 清理代码把刚拉起的进程杀掉 = 「修好了又被我关掉」。kill/Stop-Process 类清理只在判据**明确失败**分支执行

### 12. 周期看门狗脚本（自愈兜底）

`/sc onstart` 开机任务重启后**不可靠**——开机任务在系统/网络/Defender 就绪前运行，失败后**无重试**（实测 22 关闭，手动 /run 成功但重启后未拉起）。

**修**（install-keepalive.bat）：SYSTEM 计划任务 = AtStartup 触发 + Once/RepetitionInterval 5 分钟 + RepetitionDuration 3650 天（`[TimeSpan]::MaxValue` 在部分 PS 版本报错，用 10 年等效）+ `StartWhenAvailable`（睡眠唤醒后补跑）+ 电池策略 + `ExecutionTimeLimit 2 分钟`（防卡死挡住下次触发）。

看门狗逻辑 = netstat 查端口 → 没监听则杀残留进程 + 清 pid + `Start-Process` 重启 + 记 keepalive.log。**任何断连（重启/睡眠/崩溃）5 分钟内自愈**，Linux 侧 `-w` 等待即可。

### 13. 远端 PowerShell 调用（引号与噪音）

- `-EncodedCommand`（UTF-16LE base64）是绕三层引号地狱的基线
- **CLIXML 噪音**：输出带「正在准备首次使用模块」进度对象 → 脚本首行加 `$ProgressPreference='SilentlyContinue'`
- **过滤器内引号被吞**：`Get-CimInstance Win32_LogicalDisk -Filter "DeviceID=\"C:\""` 经 bash heredoc 引号被吞 → FreeSpace=null 显示 0.00GB——**绕开过滤器内引号**，用 `-Filter "DriveType=3"` 或直接查对象属性

### 14. 传输与归档（tar/盘符/xz）

- **tar 盘符陷阱**：Windows bsdtar 归档绝对路径保留盘符（`D:\ebooks` → 条目 `D:/ebooks/...`），Linux 端解压出 `D:` 子目录。修复：`pushd "%SRC%" && tar cf - . | ssh ... && popd`
- **bsdtar 解压 .tar.xz 需外部 xz**：Windows 10 自带 bsdtar 不内置 xz 解压器，报 `Can't initialize filter; unable to run program "xz -d -qq"`。修复：下载官方 `xz-5.8.3-windows.zip`（tukaani.org / GitHub 双源）→ `Expand-Archive` → 复制 `xz.exe` 到 `System32`

### 15. 脚本化协作闭环（交付模式）

每个排查步骤产出一个可双击脚本（.bat 启动器 + .ps1 逻辑），模式：

```text
.bat: 提权检查 → powershell -ExecutionPolicy Bypass -File "%~dp0xxx.ps1" → pause
.ps1: 分阶段输出 [N/M] → 每步 try/catch 容错 → 结果多位置写入
      （桌面 + $PSScriptRoot + %TEMP%，防 OneDrive 桌面重定向）
```

用户跑完 → 输出贴回 → 分析 → 下一步脚本。**每轮只给「1 个脚本 + 用户双击 + 输出回传」**，勿让用户跑多条命令；脚本输出全部诊断信息——一次回传解决一轮；用户贴回的文件每次 md5 变化，先 diff 再分析，勿重复读旧结论。版本演进保留（diag-sshd → diag-sshd2 → diag-sshd3），每版修复上一版盲区，可追溯。

## 输出格式

- **修复脚本**：5 步（验证→修复→重启→自测→提示），自测区分 `[PASS]`/`[FAIL]` 并给下一步指引
- **诊断脚本**：分阶段输出 `[N/M]` → 每步 try/catch 容错 → 结果多位置写入（桌面 + `$PSScriptRoot` + `%TEMP%`，防 OneDrive 桌面重定向）
- **日志**：修复脚本必须 Start-Transcript 落盘（§7），用户关窗/闪退仍有全量日志可回传
- **回传格式**：用户贴窗口输出或放 `~/Downloads/agony.md`，分析后给出精确结论与下一脚本

## 注意事项

- **MOTW 理论陷阱**：下载 zip 带 Mark-of-the-Web（Zone.Identifier ADS），但 **Expand-Archive 解压出的文件不带 ADS**——「解压 exe 被 SmartScreen 拦」是错误假设。若解压后 exe 执行拒绝访问，另找原因（ACL/Defender 实时保护锁文件/占用），勿在 Unblock-File 上浪费轮次
- **全盘 A/B 试运行**：已知可用工件往往还躺在磁盘上——**下载/重装前先枚举试跑全部现存工件**（含 .bak 目录），rescue-before-download。代价为零，还白得 A/B 对照组
- **PowerShell 方法参数中逗号优先级高于 -f**：`$sw.WriteLine('{0}|{1}' -f $a,$b)` 被解析为 WriteLine(format, $a, $b) 多参数 → 命中 WriteLine(String, params Object[]) 重载 → String.Format 参数越界运行时异常（藏在 catch 里表现为「全部跳过」）。**修**：`$line = ('{0}|{1}' -f $a,$b); $sw.WriteLine($line)`。同场加映：foreach 内 FileInfo 对超长路径抛异常会中断整个循环——每文件级 try/catch
- **身份鉴定三件套**：字节数、SHA256、试运行；单一属性异常（如空 FileVersion）→ 先找第二证据再下结论
- **`/inheritance:r` 只用于密钥类**：剥继承只用于主机密钥/administrators_authorized_keys（sshd 强制严格权限）；二进制安装目录保持继承（`/reset` 恢复父继承 + 增量 grant）
- **Defender 归责先查证据日志**：Defender/Operational 1116/1117（检测/处置）、1121/1122（ASR 拦截）。两处全空 = Defender 从未盯上 → 停止怀疑、换方向
- **杀软接力**：第三方 AV 卸载后 Windows Defender 自动启用（WinDefend Stopped 期间证据互相矛盾）——快照须查 `Get-Process MsMpEng` + `Get-Service WinDefend`
- **脚本注释与事实核对**：注释里的假设必须实测验证——错误假设（如「Windows 自带 xz 支持」）导致解压失败一轮
- **超时保护**：所有 ssh/curl/nmap 远程操作加 timeout，防挂起整个排障循环
- **待验证**：无实测依据的操作不写入本 skill；新场景首次使用后回填真实经验

## 变更日志

### 1.0.0 (2026-08-31)
- 初始发布：自 windows-backup-and-ssh-debug.md 1.6.0 拆分 PowerShell 脚本编写规范（原第 1 节 A-Q 全条 + 第 5 节协作闭环 + 实战补充脚本类条目 1/2/3/5/6/7/9/11/14/16/17/18/19/20），Windows 端 .bat/.ps1 专精
