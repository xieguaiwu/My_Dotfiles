---
name: opencode-health-check
version: 1.0.0
description: 全面检查 opencode 配置状态，验证所有插件、扩展、MCP、provider、agent 定义是否正确加载
triggers:
  - "检查opencode"
  - "opencode状态"
  - "健康检查"
  - "配置审计"
  - "opencode health"
inputs:
  - name: config_dir
    description: opencode 配置目录
    required: false
    default: "~/.config/opencode"
  - name: project_dir
    description: 当前项目目录（检查项目级覆盖配置）
    required: false
    default: "."
tools:
  - read
  - write
  - bash
  - glob
  - grep
  - task
  - todowrite
---

# OpenCode 健康检查

## 任务目标

全面审计 opencode 配置，检查所有组件是否被正确加载，包括：

- `opencode.json` 主配置文件的结构完整性
- 插件的注册状态与依赖安装
- MCP 服务器的配置与可执行性
- Provider（模型提供商）的 API key 配置
- Agent 子代理的定义与模型指向
- 项目级配置与全局配置的叠加关系
- 引用的指令文件是否存在

## 执行流程

### 1. 读取配置目录结构

```
~/.config/opencode/          # 全局配置
  ├── opencode.json           # 主配置文件
  ├── dcp.jsonc               # DCP 动态上下文修剪插件配置
  ├── oh-my-openagent.jsonc   # oh-my-openagent 插件（子系统代理+任务分类定义）
  ├── package.json            # npm 依赖列表
  ├── node_modules/           # 依赖安装目录
  ├── .opencode/              # opencode 内部插件
  └── .sisyphus/              # Sisyphus 工作流状态
```

检查各核心文件是否存在。

### 2. 验证 opencode.json

按以下维度逐一检查：

#### 2.1 指令文件（instructions）

检查 `instructions` 数组中列出的所有文件是否实际存在：

```bash
ls <project_dir>/<指令文件> 2>/dev/null
```

如果不存在，报 **CRITICAL** 级别的警告：引用丢失文件可能导致 opencode 加载时静默失败或丢失系统提示。

#### 2.2 插件列表（plugin）

逐项验证：
- 插件是否已安装到 `node_modules/`
- 插件是否有可用的二进制入口（`bin/` 目录或 `dist/` 编译产物）
- 插件是否拼写正确（大小写敏感）
- **额外检查**：`package.json` 中安装的依赖是否全部注册在 `opencode.json` 的 `plugin` 数组中，反之亦然

#### 2.3 Provider 配置

检查每个 provider：

| 检查项 | 说明 |
|--------|------|
| `npm` 包 | `@ai-sdk/openai-compatible` 是否已安装 |
| `baseURL` | URL 格式是否正确、可访问 |
| `apiKey` | 是否使用 `YOUR_*` 占位符（未配置） |
| `models` | 列出的模型名是否在服务商端可用 |
| `context` | 上下文窗口大小配置是否合理 |

#### 2.4 权限设置

检查 `permission`：
- `websearch` 和 `webfetch` 是否显式设为 `"allow"`
- 是否有未记录但实际使用的外部工具

#### 2.5 MCP 服务器（mcp）

检查每个 MCP 服务器配置：
- `type` 是否为 `"local"`（本地运行）
- `command` 指向的 npx 包名是否正确
- `command` 中的参数是否完整
- 检查该 npx 包是否可执行

#### 2.6 压缩/上下文管理（compaction）

确认 `auto` 启用且 `strategy` 为预期策略。

### 3. 验证 DCP 配置 (`dcp.jsonc`)

- `enabled` 是否为 `true`
- 压缩模式（`compress.mode`）
- 权限控制（`compress.permission`）
- 保护工具列表（`protectedTools`）是否覆盖了关键工具（`lsp_*`, `mcp_*`）
- 自动修剪策略的配置完整性

### 4. 验证 Agent 配置 (`oh-my-openagent.jsonc`)

#### 4.1 子系统代理定义

检查每个 agent 的 `model` 是否指向一个真实可用的模型：

| Agent | 职责 | 检查要点 |
|-------|------|----------|
| `sisyphus` | 主编排者 | 模型是否支持 tool calling + reasoning |
| `prometheus` | 战略规划 | 是否使用最强推理模型 |
| `oracle` | 架构咨询 | 同上 |
| `hephaestus` | 深度实现 | 是否使用高质量代码模型 |
| `explore` | 代码搜索 | 是否为低成本/快速模型 |
| `librarian` | 文档搜索 | 是否为大规模上下文模型 |
| `multimodal-looker` | 视觉分析 | 是否使用多模态模型 |
| `momus` | 计划审查 | 是否使用强逻辑模型 |

对于每个 agent 的 `fallback_models`，检查其 provider 是否已配置且 API key 有效。

#### 4.2 任务分类定义

检查每个 category：
- 模型是否与其任务难度匹配（quick→轻量、ultrabrain→最强推理等）
- fallback 模型是否来自不同 provider（提供冗余）
- `temperature` 是否合理（逻辑型 0.1-0.3，创造型 0.5-0.7）

### 5. 检查项目级配置

寻找以下位置的项目级覆盖：
- `$project_dir/opencode.json`
- `$project_dir/opencode.jsonc`
- `$project_dir/.opencode/opencode.json`

确认全局配置和项目配置的叠加/覆盖关系无误。

### 6. 检查指令文件是否存在

```bash
ls <project_dir>/AGENTS.md 2>/dev/null
ls <project_dir>/.opencodeinstructions 2>/dev/null
```

### 7. 检查 npm 依赖安装状态

```bash
cd <config_dir> && npm ls --depth=0 2>/dev/null
```

确认所有依赖解析成功、没有缺失的 peer dependencies。

## 输出格式

### 摘要报告

```
=== OpenCode 健康检查报告 ===

【配置目录】~/.config/opencode
【项目目录】<project_dir>
【检查时间】<timestamp>

━━━ 状态概览 ━━━
✅ 通过: N
⚠️  警告: N
❌ 严重: N
```

### 详细清单

使用表格或逐项清单，每个大项包含：

```
## 1. opencode.json

| 检查项 | 状态 | 详情 |
|--------|------|------|
| 文件存在 | ✅ | path/to/opencode.json |
| JSON 语法 | ✅ | 格式正确 |
| instructions | ❌ | 引用文件 `AGENTS.md` 不存在 |
| plugins | ✅ | 6/6 插件已安装 |
| ... | | |

### ❌ 严重问题

1. **AGENTS.md 文件缺失**
   - 路径: `<project_dir>/AGENTS.md`
   - 影响: opencode 加载 instructions 时静默失败，丢失系统提示
   - 修复: 创建该文件或从 instructions 数组中移除引用

### ⚠️ 警告

1. **Provider API Key 未配置**
   - Provider: jdcloud
   - 影响: 该 provider 的所有 fallback 模型不可用
   - 修复: 在 opencode.json 中填入有效的 API key
```

## 易犯错误

### 1. 漏掉未注册的已安装插件

`package.json` 中安装了 `opencode-websearch-cited`，但 `plugin` 数组中未注册 → opencode 不会加载它。

### 2. Provider API Key 使用占位符

```json
"apiKey": "YOUR_JDCLOUD_API_KEY"
```

→ 所有 fallback 模型对应该 provider 的都会认证失败。

### 3. 引用的指令文件不存在

`instructions: ["AGENTS.md", ".opencodeinstructions"]` 但项目目录下无这两个文件。
→ opencode 静默忽略缺失文件，但系统提示不完整。

### 4. 项目级配置覆盖全局

项目目录下的 `opencode.json` 可能覆盖全局的 `instructions`、`permission`、`mcp` 等设置。
→ 只检查全局配置会漏掉项目级设置的差异。

### 5. 插件二进制入口缺失

虽然 `node_modules/` 中存在插件目录，但缺少必要的二进制入口（`bin/` 或 `dist/`）。
→ opencode 加载时静默跳过。

### 6. Model 名称格式不匹配

oh-my-openagent 中 agent 的 model 字段格式为 `provider/model-name`，但 `opencode.json` 的 provider 中可能使用不同命名。
→ 模型无法被解析，agent 使用默认模型。
