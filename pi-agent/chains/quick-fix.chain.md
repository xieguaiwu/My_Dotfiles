---
name: quick-fix
description: 快速诊断 → 修复 → 审查的轻量链
---

## explore
phase: Diagnosis
label: 问题诊断
as: context
output: context.md

定位问题根因：{task}

## hephaestus
phase: Fix
label: 修复
reads: context.md

修复上述问题。最小改动，不改周边代码。

## momus
phase: Review
label: 审查

确认修复正确，无引入新问题。
