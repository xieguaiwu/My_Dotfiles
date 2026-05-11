---
name: screenshot-task-solver
version: 1.0.0
description: 识别并完成截图中的题目或任务，支持复杂图像的智能分析
triggers:
  - "完成截图任务"
  - "解决截图题目"
  - "分析截图"
  - "截图解题"
inputs:
  - name: screenshot_path
    description: 截图文件路径（必需）
    required: true
  - name: task_type
    description: 任务类型（auto/math/physics/chemistry/coding/reading/general）
    required: false
    default: "auto"
  - name: detail_level
    description: 解答详细程度（brief/standard/detailed）
    required: false
    default: "standard"
  - name: use_agent
    description: 是否对复杂图像使用information-collector agent
    required: false
    default: "auto"
tools:
  - look_at
  - task
---

# 截图任务解题器

## 任务目标
识别截图中的题目或任务，并提供完整的解答或解决方案。

## 执行流程

### 1. 图像复杂度评估
MCP工具读取截图，评估图像复杂度：

**简单图像特征**：
- 单一题目，文字清晰
- 图表/图形较少
- 结构简单明了

**复杂图像特征**：
- 多个题目或大段文字
- 包含复杂图表、图形、公式
- 需要提取多个信息点
- 图像质量较差或手写内容

### 2. 信息提取策略

#### 简单图像处理
MCP工具，配合以下 prompt：

```
请仔细分析这张截图，识别并提取以下信息：
1. 题目/任务的完整内容
2. 相关的图表、数据
3. 任何限制条件或特殊要求

请逐字转录所有文字内容，保持原有格式和符号的准确性。
```

#### 复杂图像处理
当检测到复杂图像特征时，调用 `information-collector` agent：

使用 task 工具，subagent_type 设为 "information-collector"，prompt 包含：
```
请深入分析截图文件：{screenshot_path}

需要完成以下任务：
1. 识别并提取所有题目/任务内容
2. 转录所有文字信息（保持原样）
3. 描述图表、图形的详细信息
4. 标注关键数据和参数
5. 识别数学公式和符号

请按照结构化格式返回所有提取的信息。
```

### 3. 任务类型识别

根据提取的内容自动识别任务类型：

- **math**: 数学题目（公式、计算、证明）
- **physics**: 物理题目（力学、电磁学等）
- **chemistry**: 化学题目（反应式、分子结构）
- **coding**: 编程任务（代码截图、算法题）
- **reading**: 阅读理解（文章、文档）
- **general**: 通用任务

### 4. 解答生成

根据任务类型和 detail_level 生成解答：

#### brief 模式
- 直接给出答案
- 简要说明关键步骤

#### standard 模式
- 完整解答过程
- 关键公式和定理
- 中间计算步骤
- 最终答案

#### detailed 模式
- 详细背景知识
- 完整推导过程
- 多种解法（如适用）
- 相关知识点扩展
- 常见错误提醒

### 5. 输出格式

```markdown
## 任务识别
- **类型**: {task_type}
- **复杂度**: {简单/复杂}

## 题目内容
{完整题目转录}

## 解答过程
{详细解答}

## 答案
{最终答案或结论}

## 补充说明
{如有必要，添加相关知识点或注意事项}
```

## 特殊处理

### 数学公式
- 使用标准 LaTeX 格式
- 行内公式: `$...$`
- 独立公式: `$$...$$`
- 确保符号准确性

### 图表分析
对于包含图表的截图：
1. 先描述图表类型和结构
2. 提取图表中的数据
3. 分析图表趋势或关系
4. 结合题目要求给出解答

### 多题目处理
如果截图包含多道题目：
1. 按题号顺序逐一解答
2. 每道题独立成节
3. 标注题目之间的关联（如有）

## 注意事项

1. **准确性优先**: 确保题目内容和符号转录准确无误
2. **公式规范**: 数学公式必须使用正确的 LaTeX 语法
3. **步骤清晰**: 解答过程要逻辑清晰，步骤完整
4. **复杂图像**: 当 use_agent 为 "auto" 且图像复杂时，主动调用 information-collector agent
5. **交互确认**: 如果题目内容不清晰或有歧义，向用户确认后再解答
