---
name: sparrow-wallet-backup-test
version: 1.1.0
description: Sparrow 钱包备份完整性体检——自动定位钱包文件、验证 rbw 条目存在与 bw 附件哈希一致性，输出通过/失败报告
triggers:
  - "钱包备份"
  - "备份验证"
  - "sparrow"
  - "恢复演练"
  - "bitwarden 附件"
  - "rbw 检查"
  - "助记词备份"
  - "备份完整性"
inputs: []
tools:
  - read
  - bash
---

# Sparrow 钱包备份完整性体检

## 任务目标

定期验证 Sparrow BTC 钱包备份链之完整性——纸备份（主）+ Bitwarden 数字备份（次）。检测两类静默失败：上传损坏或中断、钱包文件更新后备份过期。产出逐步骤通过/失败报告，发现缺口时附 GUI 恢复演练指引。

## 执行流程

以 `bash` 工具运行体检脚本，操作之先解锁密码管理器：

```bash
rbw unlock              # 步骤 5 所需
export BW_SESSION=$(bw unlock --raw)  # 步骤 6 所需（可选）
bash ~/prompt_boilerplates/System_Fix/sparrow-wallet-backup-test.sh
```

脚本内部共 5 步功能（定位/明文检查/本地哈希/rbw 条目/bw 附件）加恢复指引，如下分述：

### 1. 校验脚本完整性（bash）

运行前以 `sha256sum` 比对哈希，防脚本遭篡改后给出假阳性：

```bash
sha256sum ~/prompt_boilerplates/System_Fix/sparrow-wallet-backup-test.sh
# 期望值: 48bef013c4ad6fba23cca54db38d982f8c542f5a5a859fc53369b679a9ec6b47
```

哈希不匹配则**立刻中止**，勿继续执行。

### 2. 定位钱包文件（bash、read）

脚本从 Sparrow config 读取 `recentWalletFiles`，若不可得则扫描 `~/.sparrow/wallets/*.mv.db|*.json` 兜底。

本机实测（Sparrow 2.5.3，无 `-d` 覆盖参数）：
- 钱包文件：`~/.sparrow/wallets/new1.mv.db`（**H2 MVStore 数据库格式**，Sparrow 2.5.x 起默认，非传统 JSON）
- 桌面启动器 `~/.local/share/applications/sparrow.desktop` 无 `-d` 覆盖

### 3. 明文种子启发式检查（bash）

以 `strings` 命令搜索钱包文件中 BIP39 关键词，布尔判断是否存在明文种子。

**局限**：H2 MVStore 为分块压缩存储，`strings` 仅能启发式检测，**存在假阴性**——加密与否之最终确认靠「打开钱包需输密码」。

### 4. 计算本地哈希指纹（bash）

```bash
sha256sum ~/.sparrow/wallets/new1.mv.db
```

此指纹为步骤 6 bw 附件比对之基准。

### 5. 检查 rbw 备份条目（bash）

验证 rbw 中备份条目之存在性——**惟查名称，禁读内容**，绝不输出种子/密码/xpub/指纹。

条目列表（自动探测 `wallet/` 前缀，可用 `RBW_PREFIX` 环境变量覆盖）：
- `wallet/new1`
- `wallet/new1-fingerprint`
- `wallet/new1-pwd`
- `wallet/new1-xpub`

### 6. 比对 bw 附件哈希（bash）

仅当 bw 已解锁时执行（`BW_SESSION` 存在且有效）。下载 bw 中加密钱包文件附件至 `mktemp` 临时目录，与本地 sha256 比对，比对毕自动清理（trap 保证）。

### 7. GUI 恢复演练指引（bash、read）

打印 Sparrow GUI 恢复演练操作步骤：沙箱启动 `-d /tmp/recovery-test`，从种子恢复钱包，验证 fingerprint 与首地址一致性。此步骤不自动执行，仅指引用户手动操作。

### 8. 解读输出（read）

脚本 stdout/stderr 输出终端文本，逐步骤标记通过/失败/警告，末行输出汇总计数。

## 输出格式

终端 stdout 文本报告，每步骤一行状态。示例：

```text
[0] 定位钱包文件... [OK] ~/.sparrow/wallets/new1.mv.db
[1] 明文种子检查... [OK] 未发现明文种子
[2] 本地哈希...     [OK] sha256=e5d7f...
[3] rbw 条目...    [OK] 4/4 条目存在
[4] bw 附件...     [OK] 哈希一致
[5] 恢复指引...    [OK] 请按以下步骤在沙箱验证
通过=8 失败=0
```

**退出码**：`0` = 全部通过；非零 = 至少一步失败。

**状态标识含义**：

| 标识 | 含义 | 处理 |
|------|------|------|
| `[OK]` | 通过 | 无需处理 |
| `[FAIL]` | 必须处理 | 备份过期/未加密/取回失败 |
| `[WARN]` | 提示性 | bw 未解锁、命名不同、H2 启发式局限——多数不影响安全 |

**建议频率**：每次更新 Bitwarden 备份后及每季度常规体检。

## 注意事项

### 安全属性

经 momus 两轮安全审查闭环（2026-08-11）：
- **第一轮**：2 致命（F1/F2 Python 代码注入，改 `sys.argv` 传参）+ 1 高（H1 `bw status --quiet` 静默跳过，改 JSON 解析）+ 2 中 + 3 低 + 2 建议，全部修复
- **第二轮**：9/9 通过，无安全漏洞；新增修复 N1（多附件匹配 `sys.exit(0)` 防 ID 污染）、N2（空前缀降级保护 + `grep -e`）、N3（open 显式 UTF-8），全部实测验证

脚本对用户文件只读；唯一 `rm -rf` 仅作用于 `mktemp` 临时目录（trap 自动清理）；不输出钱包内容/种子/密码/xpub/指纹；幂等；失败退出码非零。

### 已知限制

- `strings` 对 H2 MVStore（分块压缩）只能启发式检测明文种子，**存在假阴性**——加密最终确认靠「打开钱包需输密码」
- bw 附件比对须 bw 已解锁；rbw 检查须 rbw 已解锁
- rbw 条目命名非 `wallet/` 前缀时须手动设 `RBW_PREFIX` 环境变量
- 旧版 Sparrow（2.5.x 之前）使用 JSON 格式钱包文件，脚本已兼容兜底扫描

### 常见陷阱

- **rbw 未解锁**：步骤 5 静默失败（无条目非备份缺失，乃工具不可达），先执行 `rbw unlock`
- **BW_SESSION 过期**：bw session 有时效，过期后步骤 6 跳过，须重新 `export BW_SESSION=$(bw unlock --raw)`
- **附件名不匹配**：若 bw 附件命名与脚本期望前缀不一致，步骤 6 报 FAIL——非备份缺失，乃命名差异
- **sha256 比对基准错误**：步骤 4 与步骤 6 比对之 sha256 须来自同一钱包文件；若钱包文件已更新而 bw 附件未同步，判定为「备份过期」而非「脚本误报」

## 变更日志

### 1.1.0 (2026-08-11)
- 修改：按 skill_creator.md v2.1.0 重构为四强制章节（任务目标/执行流程/输出格式/注意事项）
- 修改：tools 列表精简为 pi-agent 工具名（`[read, bash]`），rbw/bw/sha256sum/python3 为 bash 子命令
- 新增：`inputs: []` 字段
- 修改：description 压缩为一句
- 修改：正文整体改写为浅文言风格
- 修改：校验与防篡改内容并入执行流程首步，安全设计与已知限制合并入注意事项

### 1.0.0 (2026-08-11)
- 初版：Sparrow 2.5.3 + new1.mv.db 实测通过（通过= 8 失败= 0）；两轮 momus 安全审查闭环（10+3 项问题全部修复验证）；备份至 System_Fix 目录并注册 index
