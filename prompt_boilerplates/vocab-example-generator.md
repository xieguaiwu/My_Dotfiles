---
name: vocab-example-generator
version: 1.0.0
description: 根据输入的外语单词，生成画面感强、便于记忆的例句（支持英语/德语），以帮助背诵词汇
triggers:
  - "英语例句"
  - "德语例句"
  - "vocab example"
  - "单词例句"
  - "例句"
inputs:
  - name: word
    description: 要生成例句的单词（可附带词性和释义，如 "gaping adj. 裂开的"）
    required: true
  - name: language
    description: 语言（en/de），可从触发词自动推断
    required: false
    default: "en"
  - name: count
    description: 期望生成的例句数量
    required: false
    default: 6
tools:
  - write
  - read
  - glob
  - bash
  - task
  - todowrite
  - edit
  - websearch_web_search_exa
  - webfetch
  - context7_query-docs
  - context7_resolve-library-id
---

# 词汇例句生成器 (Vocabulary Example Generator)

## 任务目标

根据用户输入的单词，生成一系列画面感强、便于记忆的例句，帮助用户通过语境和图像联想背诵词汇。

## 用户偏好分析（必须遵守）

### 格式规范（用户明确选择的格式）

```
**单词**
🇩🇪/🇬🇧 外语句子。
🇬🇧 英文翻译。
📝 词源/记忆提示（可选——有帮助时加）。
```

每条例句独立成块，块间用空行分隔。

### 内容铁律（来自用户反复修正）

| 规则 | 说明 | 用户原话 |
|------|------|---------|
| **One sentence only** | 每条例句必须是**一个完整的句子**。严禁拆成片段或断句。 | *"one sentence each, do not split a single sentence"* |
| **画面感** | 句子必须能在大脑中形成一幅清晰的画面，有场景、有人物、有动作。 | *"增加例句的画面感和易于记忆性"* |
| **简短** | 句子尽量简短，不拖沓。但画面感优先于长度。 | *"请短一些"*, *"shorter"* |
| **易记忆** | 优先选择日常场景、有冲突/反转/情感张力的内容。平庸的句子无助于记忆。 | *"方便我以此来记忆单词"* |
| **多样化** | 同一个单词覆盖不同含义/语境（名词、动词、比喻义等）。 | *"more"*（多次出现） |

## 完整工作流程

### 阶段 0：解析输入

1. 从触发词判断语言：
   - `"英语例句"` → `language = "en"`
   - `"德语例句"` → `language = "de"`
2. 提取要查询的单词，保留用户提供的词性/释义信息（如 `"gaping adj. 裂开的"`）
3. 如果单词不常见或有多个义项，先用搜索工具确认核心含义和用法

### 阶段 1：理解单词

在生成例句前，确保完全理解该单词：

1. **核心含义**：单词最主要的 1-2 个意思
2. **词源**（如 helpful 可增强记忆）：追溯原始构成
3. **语域/语气**：正式/口语/古语/贬义/褒义
4. **多义项**：是否需要覆盖多个含义（如 `ghetto` 有历史隔离区、贫民窟、简陋凑合三层含义）

如不确定，用搜索工具快速验证。

### 阶段 2：生成例句

#### 2.1 例句设计原则

每条例句必须满足：

✅ **Done** — 单句完整：一个主谓结构完整的句子，不分段、不切分
✅ **Done** — 画面感：场景具体，能引发视觉想象
✅ **Done** — 简洁：句子长度控制在 15-25 个单词为佳
✅ **Done** — 可理解：不依赖过多背景知识
✅ **Done** — 自然：句子结构自然，不是生硬凑出来的语法范例

#### 2.2 覆盖策略

按以下优先级覆盖：

1. **核心含义优先**：先覆盖最常用的 1-2 个义项
2. **多义项覆盖**：如果单词有多个常见义项，各自分配例句
3. **比喻/引申义**：如果单词有常见的比喻用法，单独分配例句
4. **不同词性**：同一个词可能有不同词性（如 `etch` 动词用得多，但名词也值得提）

#### 2.3 画面感技巧

用以下技巧增强画面感：

- **具体细节**：不要 "The man was angry"，而要 "He slammed his laptop shut at 3 AM and whispered: 'I'm fine.'"
- **感官触发**：包含视觉（颜色/形状）、听觉（声音）、触觉（温度/质感）等感官信息
- **冲突/反转**：场景中有小冲突或意外，更易形成记忆锚点
- **情感张力**：喜怒哀乐等情感能增强记忆提取效率
- **具体数字/名称**：使用具体数字（"three hours", "40 people"）替代模糊表达

#### 2.4 记忆提示（可选）

当以下情况时，附加 `📝` 提示：
- 词源能帮助记忆（如 `berserk = bear + shirt` 北欧狂战士）
- 词根拆解有帮助（如 `expeditious = ex + ped 脚 → 脚步快的 → 迅速的`）
- 形近词辨析（如 `contend vs content`）
- 同义词对比（如 `gaping vs wide open`）

如果单词是简单的常用词或词源无帮助，跳过 `📝`。

### 阶段 3：格式输出

严格按以下格式输出：

```
**{单词}**
🇬🇧 {英语例句1}
🇬🇧 {英语例句1 英文翻译}
📝 {词源/记忆提示（可选）}

**{单词}**
🇬🇧 {英语例句2}
🇬🇧 {英语例句2 英文翻译}

**{单词}**
🇬🇧 {英语例句3}
🇬🇧 {英语例句3 英文翻译}
📝 {词源/记忆提示}
```

德语例句使用 🇩🇪 和 🇬🇧 标记，英文翻译保留。

输出完毕后，额外空一行，询问 "Next word?" 以便继续。

### 阶段 4：用户反馈迭代

用户可能提出以下修改要求：

| 用户要求 | 应对 |
|---------|------|
| "shorter" → 缩短句子长度，去掉非必要修饰语 | 各句缩短到 10-15 词 |
| "more" → 补充更多例句 | 再生成 5-8 条，覆盖新的语境 |
| "画面感再强一些" → 加强具体细节 | 增加感官锚点和冲突/反转 |
| 用户提供词性/释义 → 例句要针对该释义 | 只针对该义项生成，不跑偏 |

---

## 输出示例

### English (正确格式)

```
**gaping**
🇬🇧 The side of the ship had a gaping hole where the iceberg had kissed it.
🇬🇧 船的侧面有一个裂开的大洞——冰山亲吻过的地方。

**gaping**
🇬🇧 He stood there with a gaping mouth, watching his car roll into the lake.
🇬🇧 他目瞪口呆地站在那儿，看着自己的车滚进湖里。

**gaping**
🇬🇧 The plot of that movie had a gaping logic hole you could drive a truck through.
🇬🇧 那部电影的情节有一个大得能开卡车过去的逻辑漏洞。
📝 gaping = gape (张开) + -ing (形容词后缀) → 张得大大的
```

### German (正确格式)

```
**hervorragend**
🇩🇪 Das Essen war hervorragend — ich habe selten etwas so Zartes und Aromatisches gegessen.
🇬🇧 The food was outstanding — I've rarely eaten anything so tender and flavorful.
📝 hervor (out) + ragen (to stand) = standing out from the crowd

**hervorragend**
🇩🇪 Hervorragend! Das ist genau die Lösung, nach der ich seit Wochen suche.
🇬🇧 Excellent! That's exactly the solution I've been looking for for weeks.
```

---

## 禁止行为

1. ❌ 不要拆分单句——每条例句必须是一个完整的句子
2. ❌ 不要使用字典式的干瘪例句（如 "The gaping hole was big."）
3. ❌ 不要超过用户要求的数量（默认 6 条，用户可要求增减）
4. ❌ 不要在一个例句块里塞多个句子
5. ❌ 不要使用过于生僻的词义或语境（除非用户特别要求）
6. ❌ 不要忽略用户提供的词性和释义信息
7. ❌ 不要在记忆提示中编造错误词源——不确定时不写
8. ❌ 不要连续输出过多不加分隔的内容——每条例句用空行隔开
