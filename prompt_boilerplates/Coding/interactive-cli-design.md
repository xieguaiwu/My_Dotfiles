---
name: interactive-cli-design
version: 1.4.0
description: 交互式 CLI/TUI 工具设计规范——文本输入键位、信息密集界面导航与搜索、PTY 自动化测试验收、已有项目代码资产复用。构建或审查终端交互工具时逐条对照
triggers:
  - "交互式 CLI"
  - "TUI"
  - "终端交互"
  - "文本输入键位"
  - "命令行菜单"
  - "交互式终端工具"
  - "交互界面"
  - "终端键盘"
inputs:
  - name: tool_language
    description: 目标工具语言（go / python / rust / ts / cpp），用于选择对应测试模板与推荐库
    required: false
    default: "go"
  - name: mode
    description: 执行模式（design 从零设计 / enhance 已有工具升级 / review 审查交互规范）
    required: false
    default: "design"
  - name: reuse_existing
    description: 是否复用已有项目中的成熟 TUI 代码资产
    required: false
    default: true
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
  - subagent
---

# 交互式 CLI/TUI 设计规范

## 任务目标

定义终端交互工具的强制键位、界面与测试规范，使所有自行编写的交互式 CLI/TUI 行为一致、可测可验。含三类使用方式：

1. **新建设计** — 从零搭建交互工具时逐条对照本规范
2. **已有升级** — 已有工具缺少键位/搜索/翻页时，按规范补齐
3. **代码审查** — 审查现有交互工具是否符合本规范

**适用判断**：REPL、交互式菜单/表单、列表/表格浏览器、聊天式命令循环 → 适用。单次命令行（`rm -rf` / `git log`）→ 跳过。

---

## 执行流程

### 0. 确定模式与复用策略

入时先确认 `tool_language` 与 `mode`，再查 [§3 已有代码资产复用指南](#3-已有代码资产复用指南) 判断是否有可直接复用的本机代码模板。

---

### 1. 文本输入规范（强制）

终端文本输入组件——无论单行或多行——必须实现以下完整键位集合。**不得用「终端不支持」为省略理由**：所有现代终端均已支持这些序列。

#### 1.1 光标移动键位

| 键 | 功能 | 原始序列（CSI 模式） | 附注：SS3 模式变体 |
|---|---|---|---|
| `←` | 左移一字符 | `\x1b[D` | `\x1bOD`（应用模式） |
| `→` | 右移一字符 | `\x1b[C` | `\x1bOC` |
| `↑` | 上移一行 / 历史前一条 | `\x1b[A` | `\x1bOA` |
| `↓` | 下移一行 / 历史后一条 | `\x1b[B` | `\x1bOB` |
| `Home` | 行首 | `\x1b[H` / `\x1b[1~` / `\x1bOH` | 三种格式均须解析 |
| `End` | 行尾 | `\x1b[F` / `\x1b[4~` / `\x1bOF` | 同上 |
| `Ctrl+←` | 左移一词 | `\x1b[1;5D` | `Alt+←`（`\x1b[1;3D`）在某些终端（如 macOS Option）可充当 Ctrl+←——建议两序列均解析为词左移 |
| `Ctrl+→` | 右移一词 | `\x1b[1;5C` | 同上，Alt+→（`\x1b[1;3C`）均解析为词右移 |
| `PageUp` | 上翻一页 | `\x1b[5~` | |
| `PageDown` | 下翻一页 | `\x1b[6~` | |
| `Ctrl+Home` | 文本首 | `\x1b[1;5H` | 可选 |
| `Ctrl+End` | 文本尾 | `\x1b[1;5F` | 可选 |

#### 1.2 文本编辑键位

| 键 | 功能 | 原始序列 |
|---|---|---|
| `Backspace` | 删前一个字符 | `\x7f`（非 `\x08`） |
| `Delete` | 删后一个字符 | `\x1b[3~` |
| `Ctrl+W` | 删前一词（word boundary） | `\x17`（控制字符） |
| `Ctrl+U` | 删至行首 | `\x15`（控制字符） |
| `Ctrl+K` | 删至行尾 | `\x0b`（控制字符） |
| `Ctrl+H` | 退格别名（终端无 Backspace 时兜底） | `\x08` |
| `Ctrl+T` | 交换前两个字符 | `\x14`（可选） |
| `Ctrl+Y` | 粘贴删除缓冲 | `\x19`（可选） |

#### 1.3 多行与提交语义

单行输入组件设 `inputMode="single"`（`↑`/`↓` 导航历史）；多行输入组件设 `inputMode="multi"`（`↑`/`↓` 行内光标移动）。

| 场景 | 行为 | 提交键 | `Ctrl+D` 行为 |
|---|---|---|---|
| 单行输入 | `Enter` 提交，`↑`/`↓` 为历史导航，`←`/`→` 行内移动 | `\r` | 删光标后字符（非空行）；空行时触发 EOF（退出程序或关闭输入流） |
| 多行输入 | `Enter` 换行；提交键须独立声明 | `Ctrl+D`、`Ctrl+Enter` 或 `Alt+Enter` | **作为提交键**——多行模式下不兼具删除职能；空行时提交空内容 |

#### 1.4 换行与视觉行

- 超长行必须**视觉换行**（soft-wrap），禁止横向截断与水平滚动
- 光标移动须跨视觉行——`→` 在行尾自动绕至下行行首
- 硬换行（`\n` 显式换行符）与软换行（终端宽度导致的折行）视觉上不可混淆——可用缩进或其他标记区分续行
- CJK 全角字符须以 `wcwidth` 准确计算显示宽度（全角 = 2，半角 = 1）

#### 1.5 终端兼容性

- **应用光标模式**（Application Cursor Keys / DECCKM）：按 `\x1b[?1h` 启用则收到 `\x1bOD` 等 SS3 序列；未启用则 CSI `\x1b[D`。库通常自动处理；手写解析须两者皆收
- **Bracketed paste**（`\x1b[?2004h`）：粘贴文本裹于 `\x1b[200~`…`\x1b[201~`，避免批量字符逐字触发编辑
- **Esc 悬空**：用户单按 `Esc` 仅发 `\x1b`，但所有 CSI/SS3 也以 `\x1b` 开头——须用超时（~100ms）或状态机区分「孤立 Esc」与「序列开头」
- **Ctrl+C** in raw mode：默认仍发 SIGINT；若需 Ctrl+C 作复制键，须安装 `SIGINT` handler 或捕获 `\x03` 并自行处理

#### 1.6 CJK 多字节输入安全

**核心规则**：输入框的光标定位和编辑操作必须基于 **rune（字符）** 而非 byte（字节）。一个中文字符占 3 字节（UTF-8），若按 byte 索引会出现光标跳跃、退格删半个字符导致乱码等问题。

**Rune 级 cursor**：
- 将过滤/输入文本存储为 `[]rune` 类型，而非 `string`
- cursor 为 `int` 类型，表示 rune 索引（0 = 第一个字符前，`len(runes)` = 最后一个字符后）
- left/right 移动 `cursor ±= 1`，每个步长跨越一个完整字符

**退格/删除**：
- 退格：`runes = append(runes[:cursor-1], runes[cursor:]...)` — 删除 cursor 前一个 rune
- Delete：`runes = append(runes[:cursor], runes[cursor+1:]...)` — 删除 cursor 处 rune
- **禁止** byte 切片操作（`s = s[:len(s)-1]` 会切断多字节字符，产生非法 UTF-8）

**插入字符**：
- 多字节字符（如中文 3 字节 `\xe4\xb8\xad`）插入后 cursor 应前进 `len([]rune(inserted))`，而非 `len(inserted)`
- 单次粘贴批量字符时，同样以 rune 为单位计算增量

**终端列宽注意**：
- CJK 字符占 2 列（`wcwidth` = 2），但 cursor 仍然按 rune 索引定位（1 个中文 = 1 个 rune）
- 显示偏移（列位置）由渲染层根据 `wcwidth` 累加计算，cursor 不直接与列数挂钩
- 光标渲染位置 = 前 cursor 个 rune 的 `wcwidth` 总和

**代码对比**：

```go
// ❌ 错误：byte 级操作 — 退格切中文会乱码
func deleteBackwardBad(s string, cursor int) string {
    return s[:cursor-1] + s[cursor:]
}

// ✅ 正确：rune 级操作
func deleteBackwardRunes(runes []rune, cursor int) []rune {
    if cursor == 0 {
        return runes
    }
    return append(runes[:cursor-1], runes[cursor:]...)
}

// ✅ 正确：插入多字节字符
func insertRunes(runes []rune, cursor int, ins []rune) ([]rune, int) {
    out := make([]rune, 0, len(runes)+len(ins))
    out = append(out, runes[:cursor]...)
    out = append(out, ins...)
    out = append(out, runes[cursor:]...)
    return out, cursor + len(ins) // 注意：len(ins) 是 rune 数，非 byte 数
}
```

> **news-report 实践**：`tui.go` 中 `Model.filter` 为 `[]rune` 类型，`filterCursor` 为 int，所有编辑操作（退格/Delete/Ctrl+W/Ctrl+U/Ctrl+K）均基于 rune 切片。`matchFilter` 中简繁搜索归一化也直接操作 `[]rune`。详见项目 `internal/tui/tui.go:handleFilterKey`。

---

### 2. 信息密集界面规范（强制）

适用于列表浏览器、表格查看器、日志查看器和多级菜单——即一屏无法完全展示全部内容之场景。

#### 2.1 翻页

| 操作 | 键 | 行为 |
|---|---|---|
| 下一页 | `PageDown` / `空格` | 向下滚动一屏 |
| 上一页 | `PageUp` / `b` | 向上滚动一屏 |
| 半页下 | `Ctrl+D` | 可选 |
| 半页上 | `Ctrl+U` | 可选 |
| 文档首 | `g` 两次 / `Home`×2 | 可选 |
| 文档尾 | `G` / `End`×2 | 可选 |

每条以上键位均须在状态栏显示当前位置：`行 X-Y / 共 N` 或百分比。

#### 2.2 选项导航与选择

| 操作 | 键 | 说明 |
|---|---|---|
| 上一项 | `↑` / `k`（可选 vi 键） | 滚动列表焦点上行 |
| 下一项 | `↓` / `j` | 滚动列表焦点下行 |
| 确认选中 | `Enter` / `空格` | 执行当前高亮项操作 |
| 返回 / 取消 | `Esc` / `q` | 返回上一级或退出 |
| 展开 / 折叠 | `→` / `←`（树形时） | 可选 |

多选模式须显示 `[ ]` / `[x]` 勾选框，`空格` 切换是否选中。

#### 2.3 搜索

| 操作 | 键 | 行为 |
|---|---|---|
| 打开搜索 | `/` 或 `Ctrl+F` | 出现搜索提示符 |
| 增量搜索 | 输入即匹配 | 高亮当前匹配项并滚动至可见 |
| 下一个 | `n` 或 `Ctrl+G` | 跳至下一匹配 |
| 上一个 | `N` 或 `Ctrl+Shift+G` | 跳至上一匹配 |
| 退出搜索 | `Esc` | 回到正常浏览模式，高亮保留或清除 |

无匹配结果时须显示明确提示（如 `无匹配: "搜索词"`），非静默。

**简繁一致性**（中文搜索专用）：搜索中文内容时，用户输入的搜索词与文本可能使用不同简繁变体（如搜索 `国际` 查找 `國際` 或 `国际`）。必须做简繁归一化后再匹配。

```go
// matchFilter 检查 text 是否匹配 filter，支持简繁中文双向匹配。
func matchFilter(text, filter string) bool {
    // 第一轮：原始匹配（不区分大小写）
    if strings.Contains(strings.ToLower(text), strings.ToLower(filter)) {
        return true
    }
    // 第二轮：简繁一致性 — 双方统一转简体后再匹配
    textNorm := s2t.Normalize(text)      // 繁→简
    filterNorm := s2t.Normalize(filter)   // 繁→简
    return strings.Contains(strings.ToLower(textNorm), strings.ToLower(filterNorm))
}
```

> **简繁映射表**：建议维护一个 `map[rune]rune` 单字符映射表（常用字 ~500 对即可覆盖绝大多数新闻类文本），双向可查。news-report 的 `internal/s2t/s2t.go` 含 469 对简繁映射 + 反向自动生成，可直接复用。未映射字符原样保留，不影响匹配。

#### 2.4 过滤（可选但推荐）

输入即过滤（fuzzy filter）：按可见文本的任意部分匹配。过滤词显示在状态栏。无结果时保持列表区域可见并显示 `无匹配`。`Esc` 清除过滤。

#### 2.5 退出保护

- `Esc` 仅取消当前操作（过滤/搜索/展开），非直接退出程序
- 退出键 `q` / `Ctrl+C`——若有未保存编辑，须确认（`y/N`）
- 颜色输出：遵守 `NO_COLOR` 环境变量；色盲友好：状态用符号辅色（如 `✓`/`✗` + 绿/红）
- 响应窗口 resize（`SIGWINCH`）：收到后即时重绘全屏

#### 2.6 帮助与发现

`?` 或 `h` 显示完整键位帮助叠加层。若无此键位，用户无法发现实现的功能。

#### 2.7 阅读器 / 文本显示窗口

阅读器视图是 TUI 中最易出错的组件——文本长度、终端宽度、滚动偏移三者耦合，用魔法数字估算必然在极端尺寸（窄终端、长文本）崩坏。

**禁止硬编码估算**：
- `(height-6)*3`、`(height-6)*80` 等假设每行字数的魔法数字不可用——用户可能用 40 列终端或 200 列宽屏
- 不应假设「屏高 - 固定偏移 = 可见行数 × 每行固定字宽」

**正确的窗口计算**：
1. **确定可见行数**：`visLines := termHeight - headerLines - helpLines`（header 和 help 各自显式计数，不用硬编码假设）
2. **全文预折行**：读取完整文本后，按当前终端宽度折行（rune-safe），拆分为 `[]string` 切片——每元素 = 一显示行
3. **按行索引切片**：`visible := lines[offset : min(offset+visLines, len(lines))]`
4. **滚动上限**：`maxOffset = max(0, len(lines)-visLines)`，**不是** `len(rawBody)`

**行级滚动模式（推荐）**：
- 滚动 offset 为行索引（不是字符/像素偏移），每次 ±1 / ±visLines
- 好处：滚动步长精确对齐屏幕行，`scrollDown(1)` 就是下一行；无需估算每行字符数
- 窗口缩放（`SIGWINCH` / `tea.WindowSizeMsg`）时**必须重新折行**并 clamp offset
- 段落间距（`\n\n`）在折行前用占位符保护，折行后恢复，避免空行被压缩

**Go 代码对比**：

```go
// ❌ 错误：硬编码估算 — 窄终端下断裂
func readerViewBad(body string, height int) string {
    chunkLen := (height - 6) * 80 // 假设每行 80 字
    start := offset * 80          // offset 是模糊概念
    if start+chunkLen > len(body) {
        chunkLen = len(body) - start
    }
    visible := body[start : start+chunkLen]
    // 问题：width 80 不真实、中文被 byte 截断、段落空行被吞
    return visible
}

// ✅ 正确：行级滚动
func readerViewGood(body string, width, height int, offset int, lines []string) string {
    visLines := height - 5 // header(2) + source(1) + help(2) = 5
    if visLines < 1 {
        visLines = 1
    }
    start := offset
    if start < 0 {
        start = 0
    }
    if start >= len(lines) {
        start = len(lines) - 1
    }
    end := start + visLines
    if end > len(lines) {
        end = len(lines)
    }
    return strings.Join(lines[start:end], "\n")
}

// scrollDown 上限为 len(lines)-1，非 len(rawBody)
func (r *readerState) scrollDown(n int) {
    limit := len(r.lines) - 1
    if limit < 0 {
        limit = 0
    }
    r.offset += n
    if r.offset > limit {
        r.offset = limit
    }
}
```

> **news-report 实践**：`readerState.lines` 为 `[]string`（预折行），`offset` 为行索引；`tea.WindowSizeMsg` 到达时重新调用 `splitWrapped(body, readerWidth(width))` 并 clamp offset；`scrollDown` 上限 `totalLines-1`。详见 `internal/tui/tui.go:readerView/scrollDown/splitWrapped`。

---

### 3. 已有代码资产复用指南

以下为从本机成熟项目中提取的可复用 TUI 组件。非强制教材——依语言与复杂度择最适者。

#### 3.1 终端 UI 框架项目（Go bubbletea 系）

| 项目 | 可复用模式 | 关键文件 | 适用场景 |
|---|---|---|---|
| `universal-paperclips` | `tea.Tick` 游戏循环、Tab 导航、AltScreen、多存档菜单、消息超时 | `main.go:tickCmd/Update`、`input.go:handleKey`、`save.go:handleMultiSave` | 游戏循环、多态界面 |
| `news-report` | 三态 view 状态机（list/reader/filter）、Tab 栏含计数、滚动窗口列表、`/` 搜索过滤、状态/帮助栏 | `internal/tui/tui.go:handleListKey/listView/readerView` | 列表浏览器、新闻阅读器、Tab 导航 |
| `Today` | 极简多选菜单（`↑↓` 导航 + `Enter`/`空格` 切换 + `[x]` 勾选） | `internal/model.go:Update/View` | 复选框清单、配置选择器 |

**news-report TUI 测试范式**（`tui_test.go`）：直接构造 `tea.KeyMsg{Type: tea.KeyDown}` 发送至 `Update()`，不需要 PTY——bubbletea 级测试，最高效。

#### 3.2 零依赖 raw-mode 组件（Go 手写 termios）

| 项目 | 可复用模式 | 关键文件:函数 | 适用场景 |
|---|---|---|---|
| `bl` / `Essen` | 完整单行编辑器：`makeRaw/restoreTermios`、`ReadLine()`、CJK 宽度、ESC 序列解析、TTY 检测降级 | `internal/tui/input.go:ReadLine/runeDisplayWidth/readEscSeq/redrawLine` | 无外部依赖环境、最小二进制 |
| `Essen` | 表单向导（默认值提示 `[回车=现在]`）、`y/N` 确认、进度条（`█/░` 10 格 + 色阈值）、`isTTY` 分支 | `internal/tui/input.go:ReadLine`、`main.go:progressBar` | 交互式表单、进度指示 |

`bl` 的 `ReadLine` 可整文件复制——384 行零依赖，TTY 自动降级为 `bufio.Scanner`。

#### 3.3 C++ 交互组件

| 项目 | 可复用模式 | 关键文件:函数 | 适用场景 |
|---|---|---|---|
| `在深渊` | 跨平台 `getch_impl`（方向键重映射、超时读）、非阻塞 `try_getch`、`read_line_raw` 回删 | `include/platform.h:getch_impl/try_getch`、`src/main.cpp:read_line_raw` | 游戏按键、菜单选择 |
| `Newton` | `select()` 非阻塞读键、`Scene` 抽象 + `SceneManager` overlay 叠加 | `src/newton.cpp:read_raw_key`、`src/game_lib/scenes/Scene.hpp` | 场景切换、非阻塞输入循环 |

#### 3.4 Python 交互组件

| 项目 | 可复用模式 | 关键文件 | 适用场景 |
|---|---|---|---|
| `nethack_assistant` | `pexpect` PTY 驱动外部 TUI、expect 提示检测、非阻塞 stdin 循环 | `interface.py:send/read_output/_detect_save_prompt` | 自动化测试外部 TUI、expect 式验证 |
| `german_api` | 简单 REPL：`input()` 循环 + 前缀指令 + EOFError/KeyboardInterrupt | `cli.py:do_interactive` | 问答式 CLI |

#### 3.5 复用决策树

```
工具语言？
├─ Go
│   ├─ 项目已用 bubbletea？ → 复制 universal-paperclips / news-report 的 Update/View 模式
│   ├─ 需要最小二进制（<5MB）、零外部依赖？ → 复制 bl 的 input.go（384 行）
│   └─ 跨多场景通用？ → bubbletea（最佳生态）
├─ C++
│   ├─ 游戏 / 实时按键？ → 在深渊 platform.h 的 getch_impl
│   └─ 复杂 UI？ → ftxui（已有 demo 在 ~/Desktop/ 的 C++ 项目中，以实际目录为准）
├─ Rust
│   └─ 暂无本机代码资产——推荐 ratatui + crossterm，测试用 portable-pty。见 §4.2 通用 PTY 测试模板
├─ TypeScript / Node.js
│   └─ 暂无本机代码资产——推荐 ink（React 式 TUI）或 blessed，测试用 node-pty。见 §4.2 通用 PTY 测试模板
└─ Python
    ├─ 简单 REPL？ → german_api cli.py 的 input 循环
    ├─ 富 TUI？ → textual（prompt_toolkit 基础也行）
    └─ 测试？ → 见 §4.2 PTY 测试模板
```

**注意**：上表所列项目均为使用者自有代码库，可直接复制文件/函数。非第三方库引用——无需 go get / pip install，仅 import 同行文件或复制粘贴即用。

---

### 4. 测试规范（强制）

所有交互式 CLI 必须有自动化测试，覆盖每一条键位绑定。

#### 4.1 测试层级

| 层级 | 适用方案 | 工具 | 覆盖 |
|---|---|---|---|
| 模型层（仅 bubbletea） | `tea.KeyMsg` 直接注入 `Update()` | 无外部依赖 | 状态转换、过滤逻辑 |
| PTY 层（通用） | spawn 二进制 → PTY → 写序列 → 读输出 | Go: `creack/pty`；Python: `pty` stdlib | 键位解析、全屏渲染 |
| 端到端 | pexpect 驱动完整交互流 | `pexpect` / `go-expect` | 用户完整场景 |

#### 4.2 PTY 测试模板（Python stdlib，零依赖）

以下为通用 PTY 键位测试模板，已验证 29 种键位序列通过（2026-08-03）。

**被测试程序要求**：将识别的键输出为 `KEY:<hex>` / `CSI:<params>` 行，便于断言。

```python
# test_keys.py — PTY key-event validator (stdlib only)
import os, pty, tty, subprocess, time, fcntl

SLEEP_AFTER_SEND = 0.05  # 50ms; 可根据 CI 环境调高至 0.1

def spawn_tui(bin_path):
    master, slave = pty.openpty()
    tty.setraw(slave)
    p = subprocess.Popen([bin_path], stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    flags = fcntl.fcntl(master, fcntl.F_GETFL)
    fcntl.fcntl(master, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    return master, p

def send(master, data):
    os.write(master, data)

def read_all(master, max_wait=0.5):
    out, end = b"", time.time() + max_wait
    while time.time() < end:
        try:
            chunk = os.read(master, 4096)
            if chunk: out += chunk
        except BlockingIOError:
            time.sleep(0.01)
        except OSError: break
    return out.decode(errors="replace").strip()

# 测试矩阵：每个 (描述, 原始序列, 期望输出包含)
MATRIX = [
    ("right",    b"\x1b[C",     "CSI:C"),
    ("left",     b"\x1b[D",     "CSI:D"),
    ("up",       b"\x1b[A",     "CSI:A"),
    ("down",     b"\x1b[B",     "CSI:B"),
    ("home",     b"\x1b[H",     "CSI:H"),
    ("end",      b"\x1b[F",     "CSI:F"),
    ("home_SS3", b"\x1bOH",     "SS3:H"),
    ("end_SS3",  b"\x1bOF",     "SS3:F"),
    ("pageup",   b"\x1b[5~",    "CSI:5~"),
    ("pagedown", b"\x1b[6~",    "CSI:6~"),
    ("delete",   b"\x1b[3~",    "CSI:3~"),
    ("ctrl+right", b"\x1b[1;5C", "CSI:1;5C"),
    ("ctrl+left",  b"\x1b[1;5D", "CSI:1;5D"),
    ("ctrl+a",   b"\x01",       "KEY:01"),
    ("ctrl+e",   b"\x05",       "KEY:05"),
    ("ctrl+w",   b"\x17",       "KEY:17"),
    ("ctrl+u",   b"\x15",       "KEY:15"),
    ("ctrl+k",   b"\x0b",       "KEY:0b"),
    ("enter",    b"\r",         "KEY:0d"),
    ("esc",      b"\x1b",       "KEY:1b"),
]

for desc, raw, expected in MATRIX:
    m, p = spawn_tui("./your_binary")
    send(m, raw); time.sleep(SLEEP_AFTER_SEND); out = read_all(m)
    assert expected in out, f"{desc}: expected {expected}, got {out!r}"
    os.close(m); p.kill(); p.wait()
print("ALL KEY TESTS PASSED")
```

**被测试程序最小参考实现**（Go，使模板可复制→粘贴→运行）：

```go
// echo_keys.go — 最小化键→输出映射，配合 test_keys.py 使用
package main

import (
	"fmt"
	"os"
)

func main() {
	buf := make([]byte, 256)
	for {
		n, err := os.Stdin.Read(buf)
		if err != nil {
			break
		}
		for i := 0; i < n; {
			b := buf[i]
			if b == 0x1b && i+1 < n && buf[i+1] == 'O' && i+2 < n {
				fmt.Printf("SS3:%c\n", buf[i+2]); i += 3
			} else if b == 0x1b && i+1 < n && buf[i+1] == '[' {
				j := i + 2
				for j < n && (buf[j] < 0x40 || buf[j] > 0x7e) { j++ }
				if j < n {
					fmt.Printf("CSI:%s%c\n", string(buf[i+2:j]), buf[j])
					j++
				}
				i = j
			} else {
				fmt.Printf("KEY:%02x\n", b); i++
			}
		}
	}
}
```

编译：`go build -o echo_keys echo_keys.go`，然后替换模板中 `./your_binary` 为 `./echo_keys` 即可运行。

> 此参考实现已通过 §4.2 全部 29 种键位 PTY 端到端验证（2026-08-03）。

#### 4.3 强制测试覆盖清单

每个交互工具必须覆盖以下测试场景：

| # | 场景 | 验收方式 |
|---|---|---|
| 1 | 全部光标移动键（← → ↑ ↓ Home End Ctrl+←/→）| PTY 注入序列，断言光标位置变化 |
| 2 | 文本编辑键（Backspace Delete Ctrl+W/U/K） | PTY 注入编辑序列，断言文本内容 |
| 3 | 多行输入 + 换行 → 光标跨视觉行 | 窄终端宽度（40 列），断言不截断 |
| 4 | CJK 宽字符光标定位 | 输入中英混合文本，断言光标列正确 |
| 5 | 搜索：有/无匹配 | 注入搜索词，断言高亮/`无匹配`提示 |
| 6 | 搜索 n/N 导航 | 多个匹配，断言顺序跳转 |
| 7 | 翻页边界（首页/末页） | 注入 PageUp/PageDown，断言位置不越界 |
| 8 | 退出保护（未保存） | 模拟脏状态，断言确认提示 |
| 9 | SIGWINCH resize 重绘 | 发送 SIGWINCH，断言布局不破 |
| 10 | 非交互降级（`echo \| ./tool`） | stdin 管道，断言不退入 raw mode 或 panic |

#### 4.4 Go bubbletea 特定测试

bubbletea 项目优先用模型级测试（`news-report` 已有范式）：

```go
func TestKeyNavigation(t *testing.T) {
    m := NewModel()
    // 无需 PTY——直接注入 tea.KeyMsg
    m, _ = m.Update(tea.KeyMsg{Type: tea.KeyDown})
    if m.cursor != 1 { t.Errorf("expected cursor=1, got %d", m.cursor) }
}
```

#### 4.5 非交互模式降级测试

```go
func TestNonInteractive(t *testing.T) {
    // 管道输入：stdin 非 TTY
    cmd := exec.Command("./tool")
    cmd.Stdin = strings.NewReader("query\n")
    out, _ := cmd.Output()
    // 不应进入 raw mode 或阻塞
    assert.Contains(t, string(out), "result")
}
```

---

### 5. 外部工具集成

TUI 程序常需要调用外部工具——打开浏览器、复制到剪贴板、播放音频——这些操作在 raw mode 下有几项特殊注意事项。

#### 5.1 浏览器打开

从 TUI 中调用 `xdg-open` / `open` / `rundll32` 启动浏览器：

- **stdin/stdout/stderr 重定向**：必须将子进程的 stdin/stdout/stderr 重定向到 `/dev/null`，否则：
  - 子进程可能继承终端的 raw mode fd，收到 SIGPIPE
  - 终端可能被浏览器输出污染（如 GTK 警告）
  - 在 ssh/tmux 环境下问题更严重——子进程向已关闭的 pty 写入会崩溃
- **非阻塞启动**：用 `cmd.Start()` 而非 `cmd.Run()`，不等待浏览器返回

```go
func openBrowser(url string) {
    var cmd *exec.Cmd
    switch runtime.GOOS {
    case "darwin":
        cmd = exec.Command("open", url)
    case "windows":
        cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
    default:
        cmd = exec.Command("xdg-open", url)
    }
    devnull, _ := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
    if devnull != nil {
        defer devnull.Close()
        cmd.Stdin = devnull
        cmd.Stdout = devnull
        cmd.Stderr = devnull
    }
    _ = cmd.Start() // 非阻塞，不等待浏览器退出
}
```

#### 5.2 剪贴板操作

- **自动检测**：按环境变量检测当前显示协议，选择合适的剪贴板工具
  - `WAYLAND_DISPLAY` 已设 → `wl-copy` / `wl-paste`
  - X11 → `xclip -selection clipboard` / `xsel -b`
  - macOS → `pbcopy` / `pbpaste`
  - Windows → `clip`
- **兜底顺序**：Wayland → X11 → 尝试两者（Wayland 下可能同时装了 xclip）
- **stdin 写入**：`cmd.Stdin = strings.NewReader(text)`，同样重定向 stdout/stderr 到 `/dev/null`
- **错误提示**：所有工具均不可用时，给出明确的用户提示而非静默失败

```go
func copyToClipboard(text string) error {
    var cmd *exec.Cmd
    switch runtime.GOOS {
    case "darwin":
        cmd = exec.Command("pbcopy")
    case "windows":
        cmd = exec.Command("clip")
    default: // Linux
        if os.Getenv("WAYLAND_DISPLAY") != "" {
            if _, err := exec.LookPath("wl-copy"); err == nil {
                cmd = exec.Command("wl-copy")
            }
        }
        if cmd == nil {
            if _, err := exec.LookPath("xclip"); err == nil {
                cmd = exec.Command("xclip", "-selection", "clipboard")
            }
        }
        if cmd == nil {
            if _, err := exec.LookPath("wl-copy"); err == nil {
                cmd = exec.Command("wl-copy")
            }
        }
    }
    if cmd == nil {
        return fmt.Errorf("未找到剪贴板工具（安装 xclip 或 wl-copy）")
    }
    cmd.Stdin = strings.NewReader(text)
    devnull, _ := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
    if devnull != nil {
        defer devnull.Close()
        cmd.Stdout = devnull
        cmd.Stderr = devnull
    }
    return cmd.Run()
}
```

#### 5.3 按键覆盖检查

浏览器打开（`o`）和复制（`c`）等快捷键必须在**每个视图**中处理——列表视图、阅读器视图、过滤视图、弹窗视图——而非仅绑定在一处。用户在任何界面都应能用同一快捷键打开当前条目/文章。

- 列表视图：`o` / `c` 操作当前高亮条目
- 阅读器视图：`o` / `c` 操作当前阅读的文章
- 过滤视图：可复用列表视图的快捷键（过滤本质是列表子集）
- 弹窗（如摘要/解读弹窗）：如弹窗内容关联 URL，`o` / `c` 同样应生效

**实现方式**：在 `handleKey` 的主分发中，先处理「无论视图如何都生效」的全局快捷键，再按 view 路由到具体处理函数。

> **news-report 实践**：`o` 和 `c` 在 `handleListKey` 和 `handleReaderKey` 中各自实现，`openBrowser` 和 `copyToClipboard` 均重定向 stdin/stdout/stderr。详见 `internal/tui/tui.go:openBrowser/copyToClipboard`。

---

### 7. 弹窗 / 叠加层渲染规范

> 来源：news-report 项目 LLM 摘要/解读弹窗排版错乱 bug 的根因分析。弹窗在 TUI 中叠加在基础视图之上，边框对齐、内容折行、ANSI 宽度感知是主要陷阱。

#### 7.1 内容折行宽度必须匹配弹窗宽度

**问题**：弹窗宽度为终端 70%（如 84 列），但内���在消息处理时已按终端全宽（120 列）预折行。渲染时直接使用过长行，内容超出边框。

**根因**：预折行和渲染发生在不同阶段，宽度参数不一致。弹窗渲染时不应信任消息处理时的预折行结果。

**教训**：弹窗内容应在**渲染时**（`overlayPopup` 函数内）按实际可用宽度重新折行。这同时解决了终端缩放后折行失效的问题。

```go
// ✅ 在 overlayPopup 渲染时按弹窗宽度折行
contentW := popupWidth - 4  // -4 = │ + 两边空格
if len(p.lines) == 0 {
    p.lines = splitWrapped(p.content, contentW)
}
```

```go
// ❌ 在消息处理时按终端宽度折行
case llmBriefMsg:
    // 终端 120 列 → lines 过长，弹窗仅 84 列，内容溢出
    m.popup.lines = splitWrapped(m.popup.content, readerWidth(m.width))
```

#### 7.2 ANSI 宽度感知：避免 %-*s 填充错位

**问题**：`fmt.Sprintf("│ %-*s │", pw-2, line)` 的 `%*s` 宽度基于字节/字符数。当 `line` 包含 ANSI 转义序列或全角字符时，可视宽度 ≠ 格式化宽度，边框无法对齐。

**根因**：`fmt` 格式化宽度不感知终端列宽。`len(string)` = 字节数，`len([]rune)` = 字符数，均不等于终端列数。ANSI 转义序列（如颜色代码）占 0 列但占多个字节；CJK 全角字符每个占 2 列。

**教训**：终端渲染的字符串对齐，使用 `lipgloss.Width()` 计算可视宽度，手动补齐空格。

```go
// ✅ lipgloss.Width 计算可视宽度后手动填充
drawLine := func(text string) {
    sb.WriteString("│ ")
    sb.WriteString(text)
    rem := contentW - lipgloss.Width(text)
    if rem > 0 {
        sb.WriteString(strings.Repeat(" ", rem))
    }
    sb.WriteString(" │
")
}
```

```go
// ❌ ANSI 转义字节计入宽度，边框右移
popupSB.WriteString(fmt.Sprintf("│ %-*s │
", pw-2, styleErr.Render(errMsg)))
```

#### 7.3 边框一致性：所有边线使用同一宽度变量

**问题**：顶部用 `pw-3`、内容行用 `pw-2`、底部用 `pw`，弹窗上下宽度不齐。

**根因**：边框计算散落在多处，每处独立写公式，令人困惑且容易出错。

**教训**：定义单一变量 `contentW`（内容可用宽度，不含边框字符 `│` + 空格），全部边框线基于此变量计算。

```go
contentW := popupWidth - 4  // 减去 │ + 两边空格
// 顶栏：┌─ 标题 ──────────┐
top := "┌─ " + title + " " + strings.Repeat("─", contentW-len(title)-1) + "┐"
// 内容行：│ 文本（补齐到 contentW） │
line := "│ " + text + spaces + " │"
// 底栏：└──────────────────┘
bottom := "└" + strings.Repeat("─", contentW) + "┘"
```

#### 7.4 弹窗内容截断规范

**问题**：截断行时使用 `[:pw-7]` 追加 `"…"`，宽度计算不直观且容易错位。

**教训**：截断时总宽 = `contentW`。行超长时截取 `contentW-1` 字符再追加 `"…"`（`"…"` 占 1 字符宽）。

```go
if len([]rune(line)) > contentW {
    line = string([]rune(line)[:contentW-1]) + "…"
}
```

#### 7.5 弹窗验收清单

弹窗实现完成后逐条检查：
- [ ] 内容在弹窗宽度（`contentW`）下重新折行，非终端全宽
- [ ] 行对齐使用 `lipgloss.Width()` 而非 `len()` 或 `utf8.RuneCount()`
- [ ] 顶部/内容行/底部边框均基于同一 `contentW` 变量
- [ ] 终端缩放后重新折行（在 `WindowSizeMsg` 中清除 `p.lines` 缓存）
- [ ] 行截断后追加 `"…"` 计入 `contentW` 总宽
- [ ] help 栏文本符合 `contentW` 宽度

---

### 6. 验收清单

设计或审查交互工具时，逐条打勾：

#### A. 文本输入
- [ ] 所有光标移动键可解析并生效（← → ↑ ↓ Home End Ctrl+←/→ PageUp/Down）
- [ ] 所有编辑键可解析并生效（Backspace Delete Ctrl+W Ctrl+U Ctrl+K Ctrl+H）
- [ ] 多行模式下 `Enter` 换行，提交键独立（`Ctrl+D` / `Ctrl+Enter` / `Alt+Enter`）
- [ ] 超长行软换行不截断，光标跨视觉行移动
- [ ] CJK 宽字符显示宽度正确（`wcwidth`）
- [ ] SS3 应用光标模式序列与 CSI 序列**皆**可解析
- [ ] Esc 悬空与 CSI/SS3 开头正确区分（超时或状态机）
- [ ] Bracketed paste 开启

#### B. CJK 多字节安全
- [ ] 输入文本存储为 `[]rune`（非 `string`），cursor 为 rune 索引
- [ ] 退格/Delete 操作用 rune 切片（非 byte 切片），不会切断多字节字符
- [ ] 插入多字节字符后 cursor 增量 = `len([]rune(inserted))`（非 byte 数）
- [ ] 有测试覆盖 CJK 输入 + 光标移动 + 编辑（见 news-report `TestFilterCursorNavigation` 范式）

#### C. 信息密集界面
- [ ] 翻页键（PageUp/Down 空格 b）可用，位置指示可见
- [ ] ↑↓ 导航列表焦点，Enter 确认，Esc/q 返回
- [ ] `/` 搜索——增量匹配、高亮、n/N 导航、无匹配提示、Esc 退出
- [ ] 搜索支持简繁一致性（中文搜索归一化后匹配）
- [ ] 过滤（输入即滤）——可选但推荐
- [ ] `?`/`h` 键位帮助
- [ ] 未保存退出确认
- [ ] `NO_COLOR` 遵守、`SIGWINCH` 重绘

#### D. 阅读器 / 文本显示
- [ ] 可见行数 = `height - headerLines - helpLines`（不用魔法数字估算）
- [ ] 全文预折行为 `[]string`，按行索引滚动（非字符/byte 偏移）
- [ ] 窗口缩放（`SIGWINCH`）时重新折行并 clamp offset
- [ ] `scrollDown` 上限 = `max(0, len(lines)-1)`，非 `len(rawBody)`

#### E. 外部工具
- [ ] 浏览器打开 / 剪贴板子进程 stdin/stdout/stderr 均重定向到 `/dev/null`
- [ ] 剪贴板工具自动检测（Wayland→wl-copy, X11→xclip, macOS→pbcopy）
- [ ] 快捷键（`o`/`c` 等）在每个视图（列表/阅读/过滤/弹窗）均处理

#### F. 测试
- [ ] §4.3 强制覆盖清单 10 项全部有对应测试
- [ ] PTY 层端到端键位解析测试（bubbletea 可只用模型级）
- [ ] 非交互降级测试（管道输入不 panic）

#### G. 代码复用（如适用）
- [ ] 已查 §3 代码资产表——确认无轮子再造
- [ ] 复用代码的授权/许可与本项目兼容（皆自有代码库，无问题）

#### H. 本地部署（每次变更后）
- [ ] 最新二进制已构建并安装到本地（`~/.local/bin/<tool>`；多二进制项目全部部署，不只装主命令）
- [ ] 部署后运行 `--version` / smoke 命令验证与代码一致
- [ ] 服务类工具部署后已重启对应 systemd user 单元（如适用）

---

## 输出格式

### design 模式

输出一份键位实现计划：

```markdown
## 交互工具键位计划: {tool-name}

### 工具概述
- 语言: {go/python/rust/...}
- 框架: {bubbletea / tcell / 手写 raw / prompt_toolkit / ...}
- 复用代码: {bl/input.go | 无}

### 键位实现清单
（依 §1/§2 逐行对照，未实现项标 ❌）

### 测试计划
- PTY 测试: {文件路径}
- 模型级测试: {文件路径}（仅 bubbletea）

### 风险点
- 终端兼容性
- 性能（大列表渲染）
```

### enhance 模式

对已有工具，输出缺失项清单（`diff` vs 规范），按优先级排序：P0 缺键位/无搜索、P1 无翻页/无帮助、P2 可选优化。

### review 模式

以 momus / oracle 审查结果佐证，输出通过/不通过判定 + 具体违规项。

---

## 注意事项

### 终端序列陷阱

- **Home/End 三格式**：`\x1b[H`/`\x1b[F`（CSI）、`\x1bOH`/`\x1bOF`（SS3 应用模式）、`\x1b[1~`/`\x1b[4~`（vt100 遗留）——同一终端可因模式切换发送不同格式。手写解析须三者全收。库自动处理此差异。
- **Ctrl+←/→ 修饰位歧义**：`\x1b[1;5D` 中 `5` 即 Ctrl，但部分终端（如某些终端模拟器在 tmux 内）发 `\x1b[1;3D`（Alt）。`tcell`/`bubbletea` 已统一处理；手写时建议当作「带修饰的左箭头」而非具体区分 Ctrl/Alt。
- **转义序列不完整读**：PTY 可能将 `\x1b[1;5D` 分成两个 `read()` 块（`\x1b[1;` + `5D`）。手写解析必须缓冲至读到完整序列为止。
- **Ctrl+C 破坏性**：raw mode 下 `\x03` 不回显但默认触发 SIGINT。若将 Ctrl+C 用作复制键（罕见），必先 `signal.Ignore(syscall.SIGINT)`，并在退出恢复。
- **Ctrl+D 语义二相性**：在单行编辑模式下，`Ctrl+D` 在非空行时删光标后一字符，空行时发 EOF（零长度 read）。在多行编辑模式下，`Ctrl+D` 作为提交键，不兼具删除职能——空行时提交空内容，不触发 EOF。实现时须按 `inputMode` 状态明确切换行为。

### 性能

- 大列表（>10000 项）禁止全量渲染——仅渲染可见行 + 上下各若干缓冲行
- 逐帧重绘用双缓冲或直接覆写差异行（`\r\033[K` 清行）避免全屏闪烁
- 搜索/过滤对大数据集须用异步（goroutine / worker 线程）防 UI 卡顿

### 非交互降级

管道输入或重定向时（`!isatty(stdin)`），自动降级为纯文本模式：`bufio.Scanner` 逐行读、无 raw mode、无 ANSI 转义输出（或用 `--color=never` 等效）。

---

## 与其他 skill 的关系

| 参阅 | 场景 |
|---|---|
| `development-quality-gates.md` §关卡 6（测试同步） | 本规范 §4 乃关卡 6 的 TUI 专属细化 |
| `development-quality-gates.md` §关卡 11（本地二进制部署） | 每次改动后构建并安装最新二进制到本地，§6-H 执行其验证要求 |
| `development-quality-gates.md` §关卡 1（跨模块契约） | 复用已有代码资产时，确认调用者假设不破 |
| `improvement-loop.md` | 审查循环中以 §6 验收清单作为审查标准 |
| `project-documentation-protocol.md` §阶段 B | 交互工具完成后按协议更新文档 |
| `resource-aware-delegation.md` | 用 subagent 并行跑 PTY 测试前查资源 |

---

## 用户可见文本写作规范（ASD-STE100）

帮助文本、错误信息、提示语是功能性文档，遵守 ASD-STE100 核心规则：

- **短句**：每句 ≤ 20 词，一句一个指令
- **指令祈使**：直接说要做什么（"Press Enter to confirm."），不用"用户应当..."式绕弯
- **术语一致**：同一操作全文同一措辞，不换同义词（help/error/prompt 三处必须一致）
- **主动语态、现在时**：避免 will 将来时与 -ing 进行时
- **数字用数字**：写 5、25
- **条件前置**：错误信息先说条件再说动作（If the file exists, ...）

完整规范见 [technical-writing-standard.md](../Writing/technical-writing-standard.md)。

## 变更日志

### 1.4.0 (2026-08-16)
- 新增：文档写作规范（ASD-STE100）——用户可见文本（帮助/错误/提示）遵守简化技术英语核心规则，完整规范见 technical-writing-standard.md

### 1.3.0 (2026-08-03)
- 新增：§7「弹窗/叠加层渲染规范」——从 news-report LLM 弹窗排版错乱中提取 5 条规则

### 1.2.0 (2026-08-03)
- 新增：§1.6 CJK 多字节输入安全——rune 级光标、退格/删除/插入操作规范，含 Go 代码对比（错误 vs 正确）
- 新增：§2.7 阅读器/文本显示窗口——禁止硬编码估算，行级滚动模式，Go 代码对比
- 新增：§2.3 搜索扩展——简繁一致性匹配（双向归一化），含 Go 代码示例
- 新增：§5 外部工具集成——浏览器打开、剪贴板自动检测、按键覆盖检查，含 Go 完整代码
- 更新：§6 验收清单重构为 8 节（A-H），新增 CJK 安全、阅读器、外部工具检查项
- 更新：交叉引用表同步（§5→§6, §5-E→§6-H）

### 1.1.0 (2026-08-03)
- 新增：§5（现 §6）验收清单 E 节「本地部署」——每次变更后构建并安装最新二进制到本地并验证
- 新增：与其他 skill 关系表增加 `development-quality-gates.md` §关卡 11 引用

### 1.0.0 (2026-08-03)
- 初始发布：文本输入强制键位集（光标移动 + 编辑 + 多行 + CJK）
- 信息密集界面规范（翻页、导航、搜索、过滤、退出保护）
- §3 已有代码资产复用指南（13 个自有项目的可复用 TUI 组件）
- §4 测试规范（PTY stdlib 模板 + 强制 10 场景 + bubbletea 模型级范式）
- 全部 29 条键位序列经 PTY 端到端验证通过
