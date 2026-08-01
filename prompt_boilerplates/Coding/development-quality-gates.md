---
name: development-quality-gates
version: 1.2.0
description: 编码时必须遵守的质量关卡——来自实际项目的教训沉淀，编码时逐条对照防止引入可避免的缺陷
triggers:
  - "开发规范"
  - "编码要求"
  - "质量标准"
  - "编码时注意"
  - "工作经验"
  - "开发经验"
  - "干活守则"
  - "quality gates"
  - "coding standards"
  - "development requirements"
  - "写代码时"
inputs:
  - name: project_language
    description: 项目语言（go / python / ts / rust 等），用于加载对应的语言专有规则
    required: false
    default: ""
  - name: strictness
    description: 严格程度（"strict" 全部对照，"normal" 重点关注 P0-P1，"light" 只检查关键项）
    required: false
    default: "normal"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
---

# Development Quality Gates — 开发质量关卡

## 核心理念
**预防优于检测。** 每一处缺陷在写代码时就能避免，不需要靠事后审查来找。

这不是代码审查 checklist，而是**写每一行代码时心里要过的关卡**。每次新增/修改功能，逐条核对：

---

## 关卡总览

```
▶ 关卡 1：跨模块契约        —— 改 A 时，A 的调用者知道吗？
▶ 关卡 2：前置条件可达性     —— 这个条件在运行时真的可能成立吗？
▶ 关卡 3：边界与溢出         —— 边界值测试过了吗？int64 会溢吗？
▶ 关卡 4：状态一致性         —— 每次状态变更，所有相关字段都更新了吗？
▶ 关卡 5：文档同步           —— 改完代码，README / DEVELOPMENT.md 更新了吗？
▶ 关卡 6：测试同步           —— 新功能有测试吗？测试的断言是真的断言吗？
▶ 关卡 7：值域约束           —— 这个值会被外部逻辑限制到一个更小的范围吗？
▶ 关卡 8：中英双语文档       —— 公开项目有中英双语 README 吗？
▶ 关卡 9：安全与密钥         —— 代码里有没有硬编码 key / token？
▶ 关卡 10：代码知识图谱       —— graphify 查阅过了吗？God Nodes 确认了吗？
```

---

## 关卡 1：跨模块契约

**在修改/新增一个函数、字段、常量时，先确认所有调用者/引用者的假设仍成立。**

```
┌─────────────────────────────────────────────────────────┐
│  改前必问：谁在用我？                                    │
│                                                         │
│  grep -rn "FunctionName" --include="*.go"               │
│  grep -rn "FieldName"   --include="*.go"                │
│  grep -rn "ConstantName" --include="*.go"               │
└─────────────────────────────────────────────────────────┘
```

### 典型违规

| 场景 | 后果 |
|------|------|
| 函数返回值类型改了，调用者还在按旧类型解包 | 编译不通过（好的），或静默截断（坏的） |
| 常量值变了，另一个模块还在用旧值做 magic number | 逻辑错位 |
| 字段语义变了（如从「总量」改成「剩余量」），所有 reader 的解读都错 | 数据流污染 |
| 函数新增了一个隐含前置条件（如"调用前必须初始化 X"），调用者不知道 | 运行时 panic |

### 作业要求

1. 改前 grep 所有引用
2. 改后 grep 确认所有引用仍合理
3. 如果函数语义变了（不仅仅是修 bug），在整个调用链中加注释标明新契约

### 进阶工具：graphify 知识图谱

对于中大型项目（≥10 个源文件），纯文本 grep 可能遗漏接口实现、跨包调用或配置引用的依赖关系。使用 graphify 获取更全面的跨模块影响分析：

```bash
# 构建/更新项目知识图谱
graphify update .

# 查询某个函数/模块被哪些节点引用
graphify query "FunctionName" --graph graphify-out/graph.json

# 查看两个模块之间的最短依赖路径
graphify path "ModuleA" "ModuleB" --graph graphify-out/graph.json

# 获取核心节点的详细描述及其邻居
graphify explain "CoreStruct" --graph graphify-out/graph.json
```

在修改代码前，先通过 graphify 了解被修改节点在整个图中的位置和依赖关系，
尤其关注 GRAPH_REPORT.md 中的 God Nodes 标注——它们是修改风险最高的核心模块。

---

## 关卡 2：前置条件可达性

**每一个 if 条件、switch case、prerequisite check，都要问：这个条件在运行时真的可能成立吗？**

这是从 universal-paperclips 项目中挖出的最深的一类 bug。表面上看条件合理：
```go
case "wire cost of $125":
    return s.WireCost >= 125.0
```
但实际上 `WireCost` 每 8 秒被 clamp 到 `[12, 40]`，125 永远不可达。

### 检查方法

```
1. 变量值从哪里来？          —— 赋值/修改路径有哪些？
2. 有没有 clamp / cap / min/max 限制？   —— 当前值的合法范围是什么？
3. 有没有定时器/后台协程会重置？         —— 会不会在下一 tick 被复位？
4. 要同时满足两个条件，它们各自的取值范围有交集吗？
```

### 作业要求

- 写任何一个判断条件时，在脑中模拟一遍变量的完整生命周期
- 尤其警惕「这个值用户能手动推高」但「另一条路径会周期性 clamp」的场景
- 如果条件涉及两个以上变量的组合，写测试验证

---

## 关卡 3：边界与溢出

| 要检查的 | 为什么 |
|----------|--------|
| int64 运算结果可能溢出吗？ | `1e18 * 1e6` 在 int64 里会绕回负数 |
| float64 → int64 截断？ | `int64(1.9e18)` 可能 ≠ `1.9e18` |
| 循环边界 off-by-one？ | `for i < len` vs `for i <= len` |
| 除以零？ | `price / 0` |
| nil map/slice 写入？ | 未 make 的 map 直接赋值会 panic |
| 负数作为数组下标？ | 来自用户输入或计算 |
| clamp 的上界/下界合理吗？ | 会不会 clamp 得太紧导致后续条件永远无法满足（关卡 2） |

### 作业要求

- 涉及乘法/幂运算的地方，估算最大值是否超 int64 范围
- 所有 `int64(x)` 转换，确认 x 不会超出 int64 安全范围
- 所有 clamp/fence，确认上下界没有"杀死"合法的业务路径

---

## 关卡 4：状态一致性

**当修改一个状态字段时，所有依赖它的字段是否同步更新？**

典型场景：
```go
// Bug: 更新了 FieldA，但忘记更新 FieldB
s.AutoTourney = true
// 忘记 s.research("AutoTourney")
```

玩家发现「AutoTourney」项目还在研究列表里，花 50K 创造力 + 90 信任值研究了一个已经解锁的功能——零收益。

### 需要同步更新的模式

| 变更 | 必须同步 |
|------|----------|
| 解锁 Boolean 设为 true | 标记对应项目为已研究：`s.research("ProjectName")` |
| 数值字段变更 | 更新派生字段（如 total、count、sum） |
| stage 切换 | 重置/初始化新 stage 所需的全部字段 |
| 资源扣除 | 确认扣减逻辑只发生一次，不被重复执行 |

### 作业要求

写状态变更代码时，脑中列一张「牵一发而动全身」的清单——这个变更还应该影响什么？

---

## 关卡 5：文档同步

**改完代码后的第一件事不是测，而是更新文档。** 因为当时你记得改了哪里，5 分钟后可能就忘了。

| 改了 | 必须同步 |
|------|----------|
| 新增/删除功能 | README 功能列表、Quick Start |
| 修改快捷键/操作 | README 键位表 |
| 修改架构/流程 | DEVELOPMENT.md 架构描述 |
| 修复旧文档错误 | 顺手改掉 |
| 修改测试数量 | DEVELOPMENT.md 测试统计 |
| 修改构建流程/依赖 | go.mod、Makefile、spec 版本号 |

### 作业要求

```
改代码 → 更新文档 → 提交（同一 commit，不许分开）
```

> **详细文档更新流程**：参见 `project-documentation-protocol.md` §阶段B——包含完整的更新清单、graphify 重建、文档漂移检测和结论归档规范。本关卡只是提醒「不要忘记」，完整执行步骤在那边。

---

## 关卡 6：测试同步

**写测试时，确认每一个断言都在真正地断言。** 不要有空的 if-body、不要有总是通过的宽松断言。

```go
// ❌ 伪断言——if 体为空，不管条件真假都不报错
if s.Yomi <= yomiBefore && s.Ops >= 50000 {
    // 可能没积累够进度……
}

// ✅ 真实断言
if s.Ops >= opsBefore {
    t.Errorf("tournament should consume ops: was %.0f, now %.0f", opsBefore, s.Ops)
}
if s.Yomi <= yomiBefore {
    t.Errorf("yomi should increase: was %.0f, now %.0f", yomiBefore, s.Yomi)
}
```

### 测试质量标准

- [ ] 每个 `if` + `t.Errorf` 必须有明确的失败信息，包括预期值和实际值
- [ ] 没有空的 if-body 或注释替代断言
- [ ] happy path + 至少一个 error path（没钱、没资源、越界、为空）
- [ ] 测试次数与文档声明的数字一致
- [ ] mock/stub 的返回值覆盖了生产代码的所有调用路径

---

## 关卡 7：值域约束

**一个变量的"逻辑上的取值范围"和"运行时实际取值范围"往往是两回事。**

| 变量 | 理论范围 | 实际受限于 | 陷阱 |
|------|----------|-----------|------|
| `WireCost` | `[0, +∞)` | clamp `[12, 40]`（修复后 `[12, 200]`） | 120 美元的检查永远过不了 |
| `ProbeHazard` | `[0, ...]` | clampInt `[1, 10]` | 超过 10 的赋值会静默截断 |
| `TournamentProg` | `[0, +∞)` | 每次完成减 cost | 可能无限积累但永不触发 |
| `Ops` | `[0, +∞)` | `OpsCapacity` cap | 生成超出上限的全部浪费 |

### 作业要求

对每一个写操作（赋值、计算、用户输入），自问：
- 这个值最终会落到哪个函数里？
- 那个函数对它做了什么限制？
- 如果外部逻辑加了 clamp，我这边的条件还能满足吗？

---

## 真实案例对照表

以下每个案例都是从实际项目中挖出的 bug 和事故，对应违反的关卡：

| # | 发现 | 违反的关卡 | 根因 |
|---|------|-----------|------|
| 1 | Quantum Foam 要求 wire cost ≥ $125，但被 clamp [12,40] | **关卡 2**（前置条件不可达）+ **关卡 7**（值域约束） | 写前置条件时没检查变量完整生命周期 |
| 2 | AutoTourney 自动解锁但未标记已研究 | **关卡 4**（状态一致性） | 改了一个 boolean 忘了同步 project 状态 |
| 3 | 测试数量文档写 39 实际 37 | **关卡 5**（文档同步） | 删了测试后没更新数字 |
| 4 | Yomi 标签页显示 15000 但实际成本 12000/24000 | **关卡 1**（跨模块契约） | 用了从不更新的字段而不是实时计算 |
| 5 | 锦标赛测试 if-body 为空 | **关卡 6**（测试同步） | 留了占位代码当测试 |
| 6 | 移植游戏时与原版的 clamp 范围不同 | **关卡 7**（值域约束） | 没确认原版 clamp 值就直接抄了 |
| 7 | Unlock conditions 使用 project name string 而非 flag | **关卡 4**（状态一致性） | 两套解锁机制不同步 |
| 8 | codewhale config.toml 含明文 DeepSeek key 上传 GitHub | **关卡 9**（安全与密钥） | 未检查 diff 就 git push |
| 9 | opencode.json 历史中含 4 个 API key | **关卡 9**（安全与密钥） | `.gitignore` 覆盖不全，敏感文件未排除 |

---

## 关卡 8：中英双语文档

**任何公开项目（GitHub public repo）必须提供中英双语 README，并支持语言切换。**

### 规范

1. **文件命名**：`README.md`（英文，默认） + `README_zh.md`（中文）
2. **语言切换**：两个文件顶部互相链接
   ```markdown
   [**中文版**](README_zh.md) | [**English**](#)     ← README.md 顶部
   [**English**](README.md) | [**中文版**](#)       ← README_zh.md 顶部
   ```
3. **内容对应**：两个文件结构一致，非逐字翻译而是各自自然表达
4. **内部文档**（DEVELOPMENT.md / ARCHITECTURE.md）：主语言与项目一致，不强制双语

### 适用判断

| 项目类型 | 必须双语 README |
|----------|:---:|
| GitHub public repo | ✅ |
| GitHub private repo | 推荐但不强制 |
| 内部工具 / 一次性脚本 | 不强制 |

### 作业要求

- 新建 public repo 时同时创建 `README.md` 和 `README_zh.md`
- 改代码导致 README 需要更新时，**两个文件一起更新**
- 提交时 README 修改与代码修改在同一 commit

---

## 关卡 9：安全与密钥

**代码中绝对禁止硬编码任何 API key、token、密码、secret。**

这是从真实泄露事故（codewhale DeepSeek key → GitHub、opencode.json 含 4 个 key、url.txt 代理 token）中沉淀的教训。

### 检查方法

```bash
# 提交前检查
git diff --cached | grep -E 'sk-|nvapi-|ghp_|gho_|github_pat_|xox[baprs]-|[a-z0-9]{20,}'
```

### 安全规则

| 规则 | 说明 |
|------|------|
| 绝不硬编码 | 所有 key/token/secret 用环境变量或配置文件（入 `.gitignore`） |
| 备份配置占位 | dotfiles 中用 `<your-key>` 或 `{file:}` 引用 |
| `.gitignore` 覆盖 | 确保 `*.env`、`secrets/`、`auth.json` 等入 `.gitignore` |
| 泄露后立即轮换 | key 一旦泄露，立即在服务端 revoke + 轮换，然后用 BFG/git filter-branch 清理历史 |
| 提交前 grep | 每次 `git commit` 前检查 diff 中是否包含疑似 key 的字符串 |

### 作业要求

- 新建项目时，第一步就写好 `.gitignore`，涵盖所有敏感文件类型
- 提交前执行 `git diff --cached | grep -E '<key-pattern>'`
- 发现泄露：立即轮换 key → 清理 git 历史 → force push

---

## 关卡 10：代码知识图谱

**在修改代码前，通过 graphify 知识图谱了解被修改节点的架构位置和依赖关系。**

### 动机

在中大型项目中，一个函数的修改可能影响多个模块。纯文本 grep 可能遗漏：
- 通过接口/抽象类调用的间接引用
- 跨包/跨目录的深层调用链
- 配置文件中通过字符串引用的函数名

graphify 通过代码结构分析生成项目的知识图谱，明确标注：
- God Nodes（核心节点，修改风险最高）
- 模块之间的依赖方向
- 社区/模块边界划分
- 跨模块调用链

### 作业要求

1. 进入项目后先执行 `graphify update .` 构建/更新图谱（若无 graphify-out）
2. 修改前用 `graphify query` / `graphify explain` / `graphify path` 确认受影响范围
3. 修改后重新运行 `graphify update .` 确认图谱一致性
4. 如果 graphify-out/GRAPH_REPORT.md 中的 God Nodes 标注了要修改的模块，则必须逐条审查所有下游依赖

> **graphify 完整生命周期**：本关卡聚焦"修改前查阅"。进入项目时的构建、工作完成后的重建、时效性检测等完整流程见 `project-documentation-protocol.md` §A2（阅读时）和 §B3（更新时）。

### 适用场景

| 场景 | 必选 |
|------|:---:|
| 新进入一个中大型项目（≥10 个源文件） | ✅ |
| 修改核心模块/基础设施代码 | ✅ |
| 重构涉及跨包/跨目录改动 | ✅ |
| 修复某个模块但不确定谁在使用它 | ✅ |
| 小项目（<10 个源文件），改动明确 | 可选 |

---

## 严格程度选择

| 级别 | 适用场景 | 强制检查的关卡 |
|------|---------|---------------|
| `strict` | 新项目启动、大型重构、上线前 | 1–10 全部逐条通过 |
| `normal` | 日常功能开发 | 1–4（契约/前置条件/边界/状态一致性）+ 6（测试同步）+ 9–10（安全与密钥 + 知识图谱） |
| `light` | 紧急修复、小改动 | 1（跨模块契约）+ 2（前置条件可达性）+ 9（安全与密钥）+ 10（知识图谱） |

---

## 编码前自检（30 秒速查）

```
□ 关卡 1：谁在用我改的东西？            grep 确认所有调用者
□ 关卡 2：这个条件真能成立吗？          追踪变量完整生命周期
□ 关卡 3：边界值/溢出/nil/零？         脑中过一遍极端值
□ 关卡 4：还有别的字段需要同步吗？      列出受影响的全部字段
□ 关卡 5：文档更新了吗？               同 commit 同一行
□ 关卡 6：测试有真正在断言吗？          if-body 不为空 + 有 error/fatal
□ 关卡 7：这个值会被外部逻辑限制吗？    检查 clamp/cap/filter
□ 关卡 8：两个 README 都更新了吗？      中英双语同步
□ 关卡 9：有硬编码的 key 吗？           git diff --cached grep key-pattern
□ 关卡 10：知识图谱查阅了吗？           graphify query 确认跨模块影响范围
```

---

## 变更日志

### 1.2.0 (2026-07-29)
- 新增：关卡 10「代码知识图谱」——改代码前通过 graphify 了解架构，用 graphify query/path/explain 分析跨模块影响
- 新增：Gate 1 增加 graphify 进阶工具章节，弥补纯文本 grep 的遗漏
- 修改：`strict`/`normal`/`light` 均增加关卡 10
- 修改：30 秒自检清单增加关卡 10

### 1.1.0 (2026-07-26)
- 新增：关卡 8「中英双语文档」——公开项目强制中英双语 README，含语言切换规范
- 新增：关卡 9「安全与密钥」——禁止硬编码 API key / token / secret，含泄露应急流程
- 新增：2 个安全泄露真实案例（codewhale + opencode）
- 修改：`strict` 级别改为 1–9 全部通过，`normal` 和 `light` 增加关卡 9

### 1.0.0 (初始版本)
- 初始发布
- 7 个质量关卡 + 真实案例对照表 + 严格程度分级 + 30 秒速查
