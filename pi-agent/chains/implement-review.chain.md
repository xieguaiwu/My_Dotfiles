---
name: implement-review
description: 调研 → 规划 → 实现 → 审查的标准工作流
---

## explore
phase: Research
label: 代码调研
as: context
output: context.md

分析代码库：{task}

## prometheus
phase: Planning
label: 制定方案
reads: context.md

根据以上调研结果，制定实现计划。输出包含：架构设计、文件变更清单、实现步骤。

## hephaestus
phase: Implementation
label: 实现
reads: context.md

按计划实现。完成所有文件修改和测试。

## momus
phase: Review
label: 审查

审查以上实现的正确性、安全性、代码风格。指出必须修复的问题。
