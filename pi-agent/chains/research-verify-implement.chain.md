---
name: research-implement
description: 调研 → Oracle 验证 → 实现 → 审查（含决策验证环节）
---

## explore
phase: Research
label: 代码调研
as: context
output: context.md

调研代码库：{task}

## oracle
phase: Verification
label: 方案验证
reads: context.md

检查方案可行性。挑战假设，指出盲点。如果方案有问题，给出修正方向。

## hephaestus
phase: Implementation
label: 实现
reads: context.md

执行已验证的方案。

## momus
phase: Review
label: 审查

审查变更。
