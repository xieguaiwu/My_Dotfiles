---
name: fcitx5-punctuation-fix
version: 1.0.0
description: 排查并修复 fcitx5 输入法中文标点符号问题（半角标点、无法打出顿号书名号等）
triggers:
  - "fcitx5标点问题"
  - "输入法标点符号"
  - "中文标点打不出来"
  - "顿号书名号"
  - "输入法是半角标点"
  - "fcitx5 punctuation"
inputs:
  - name: config_dir
    description: fcitx5 配置目录路径
    required: false
    default: "$HOME/.config/fcitx5"
tools:
  - bash
  - read
  - write
  - edit
  - grep
---

# Fcitx5 中文标点符号修复 Skill

## 任务目标

诊断并修复 fcitx5 输入法的中文标点符号问题，包括：
- 中文模式下标点为半角（如逗号 `.` 而非 `，`）
- 全角模式只出全宽英文而非中文标点
- 打不出顿号（`、`）、书名号（`《》`）、省略号（`……`）等常见中文标点
- 标点映射混乱或缺失

## 执行流程

### Phase 1: 诊断 — 收集 fcitx5 配置

并行执行以下命令收集关键配置。

#### 1.1 确认 fcitx5 正在运行
```bash
ps aux | grep -E '[f]citx5'
fcitx5 --version 2>/dev/null || echo "fcitx5 not found"
```

#### 1.2 定位配置目录
```bash
ls -la ~/.config/fcitx5/conf/
```

#### 1.3 检查 punctuation 配置
```bash
cat ~/.config/fcitx5/conf/punctuation.conf
```

#### 1.4 检查标点映射表
```bash
cat ~/.local/share/fcitx5/punctuation/punc.mb.zh_CN
```

#### 1.5 检查输入法 profile
```bash
cat ~/.config/fcitx5/profile
```

#### 1.6 检查环境变量
```bash
env | grep -iE 'fcitx|ibus|gtk.*im|qt.*im|xmodifier' | sort
```

#### 1.7 检查全角配置
```bash
cat ~/.config/fcitx5/conf/fullwidth.conf
```

### Phase 2: 分析并识别问题

#### 2.1 标点映射禁用（最常见问题）

**检查方式**：`punctuation.conf` 中 `Enabled=False`

**症状**：
- 中文模式下所有标点都是半角（英文）
- 按 `,` 出 `,` 而非 `，`
- 按 `\` 出 `\` 而非 `、`

**根因**：fcitx5 的 punctuation 模块负责将 ASCII 标点映射为中文标点，禁用后没有自动映射。

#### 2.2 标点映射表缺失或损坏

**检查方式**：
- 检查 `~/.local/share/fcitx5/punctuation/punc.mb.zh_CN` 是否存在
- 检查文件内容是否包含常用映射，如：
  ```
  \ 、
  , ，
  < 《
  > 》
  . 。
  ```

**症状**：标点映射启用后部分符号仍不出正确中文标点。

#### 2.3 全角模式误解

**检查方式**：`fullwidth.conf` 中 `Enabled=True`（通常 Shift+Space 切换）

**症状**：用户使用全角模式试图输入中文标点，但全角只将字母数字转为全宽（`a`→`ａ`），**不进行中文标点映射**。

**解释**：全角 ≠ 中文标点。中文标点靠的是 punctuation 映射，而非全角模式。

#### 2.4 环境中缺少 fcitx5 输入法模块

**检查方式**：
```bash
env | grep GTK_IM_MODULE  # 应为 fcitx
env | grep QT_IM_MODULE   # 应为 fcitx
env | grep XMODIFIERS     # 应为 @im=fcitx
```

**症状**：fcitx5 已启动但无法正常输入，或只在部分应用中生效。

#### 2.5 缺少中文标点数据包

**检查方式**：
```bash
# 验证数据文件存在
test -f ~/.local/share/fcitx5/punctuation/punc.mb.zh_CN && echo "FOUND" || echo "MISSING"
# 对于 Fedora，检查是否安装 fcitx5-chinese-addons 或 fcitx5-pinyin
rpm -q fcitx5-chinese-addons 2>/dev/null
```

### Phase 3: 修复方案

#### 3.1 启用标点映射（最常见修复）

```bash
# 方法 1: 直接修改文件
sed -i 's/^Enabled=False/Enabled=True/' ~/.config/fcitx5/conf/punctuation.conf

# 方法 2: 手动确认后再改
# 编辑 ~/.config/fcitx5/conf/punctuation.conf
# 将 Enabled=False 改为 Enabled=True
```

#### 3.2 重新生成标点映射表

如果 `punc.mb.zh_CN` 不存在或损坏，需要安装或重建。

**Fedora**：
```bash
sudo dnf reinstall fcitx5-chinese-addons
```

**Arch**：
```bash
sudo pacman -S fcitx5-chinese-addons
```

**Debian/Ubuntu**：
```bash
sudo apt install --reinstall fcitx5-chinese-addons
```

#### 3.3 配置全角模式的正确用法

```bash
# 确保 fullwidth.conf 开启（通常默认）
# Enabled=True
```

同时向用户解释：
- **Shift+空格**：全角模式，仅改变字符宽度（`a`→`ａ`）
- **中文标点**：在 pinyin 模式下直接按对应按键：
  - `,` → `，`（逗号）
  - `.` → `。`（句号）
  - `\` → `、`（顿号）
  - `<` → `《`（左书名号）
  - `>` → `》`（右书名号）
  - `^` → `……`（省略号）
  - `_` → `——`（破折号）
  - `$` → `￥`（人民币符号）
- **Ctrl+.**：临时切换标点映射开关

#### 3.4 重载配置

修改配置后无需重启，发送 dbus 信号让 fcitx5 重载：

```bash
dbus-send --session --dest=org.fcitx.Fcitx5 --type=method_call \
  /controller org.fcitx.Fcitx5.Controller1.ReloadConfig
```

或重启 fcitx5：

```bash
pkill fcitx5
# systemd user service 会自动重启
```

### Phase 4: 验证修复

| 验证项 | 方法 | 预期结果 |
|--------|------|----------|
| 配置文件已启用 | `grep Enabled ~/.config/fcitx5/conf/punctuation.conf` | `Enabled=True` |
| 标点映射生效 | 在任意输入框切换 pinyin，按 `,\` | `，、` |
| 书名号 | 按 `<>` | `《》` |
| 句号 | 按 `.` | `。` |
| 问号 | 按 `?` | `？` |
| 环境变量 | `echo $GTK_IM_MODULE` | `fcitx` |
| fcitx5 运行中 | `pgrep fcitx5` | 返回 PID |

## 输出格式

```
## Fcitx5 标点问题诊断报告

### 发现的问题
- [问题 A]: [症状描述] → [修复操作]

### 已执行的修复
- [修复项] → [状态: ✓/✗]

### 验证结果
| 按键 | 预期 | 是否正常 |
|------|------|----------|
| `,` | `，` | ✓/✗ |
| `\` | `、` | ✓/✗ |
| `<` | `《` | ✓/✗ |
| `>` | `》` | ✓/✗ |
| `.` | `。` | ✓/✗ |

### 正确使用方法
在拼音模式下直接按键，不需要切全角模式。
```

## 常见问题清单

#### Q: 为什么全角模式下还是打不出顿号？
A: 全角模式（Shift+Space）只改变字符宽度（`a`→`ａ`），**不进行中文标点映射**。中文标点需要在拼音模式下，通过 punctuation 模块自动映射。在拼音模式下按 `\` 即可打出顿号。

#### Q: 为什么标点时而中文时而英文？
A: 检查 `punctuation.conf` 中 `HalfWidthPuncAfterLetterOrNumber=True`。这个选项让跟在字母或数字后的标点保持半角（例如输入 `1.` 时点号是半角），是正常行为。如需关闭可设为 `False`。

#### Q: 修改配置后需要重启吗？
A: 不需要重启桌面。运行以下命令重载即可：
```bash
dbus-send --session --dest=org.fcitx.Fcitx5 --type=method_call /controller org.fcitx.Fcitx5.Controller1.ReloadConfig
# 或直接 pkill fcitx5（systemd 会自动重启）
```

#### Q: 标点映射表在哪里？
A: `~/.local/share/fcitx5/punctuation/punc.mb.zh_CN`。如果文件被删除或损坏，重新安装 `fcitx5-chinese-addons` 包恢复。

#### Q: pinyin 和 keyboard-us 之间切换时标点表现不同？
A: 正常。`keyboard-us` 模式下（英文输入）标点是原生半角；`pinyin` 模式下 punctuation 模块将标点映射为中文标点。如果想在英文模式下也用中文标点，可以启用全角模式。

## 注意事项

1. **全角 ≠ 中文标点**：全角模式只改字符宽度，中文标点靠 punctuation 映射。不要混用。
2. **半角标点可能正常行为**：`HalfWidthPuncAfterLetterOrNumber=True` 时，数字/字母后的标点保持半角。如果不适应可关闭。
3. **标点映射热键**：`Ctrl+.`（Control+句号）可以随时开关标点映射，方便临时输入英文标点。
4. **环境变量**：在 Wayland 下某些应用可能不读取 `GTK_IM_MODULE`/`QT_IM_MODULE`。如果 fcitx5 在某些应用无效，检查应用启动方式。
5. **不需要 root**：所有配置在 `~/.config/fcitx5/` 下，修改配置无需 sudo。
