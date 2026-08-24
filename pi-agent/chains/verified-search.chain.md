---
name: verified-search
description: "可靠搜索链。使用 verified-search agent 进行确认真实搜索能力的搜索，避免不可验证的 AI 聊天源 (grok/doubao/gemini ask)。返回结构化搜索摘要和置信度标注。"
---

## verified-search
phase: Research
label: 可靠搜索

搜索并综合结果：{task}

返回结构化结果，包含搜索摘要（源、查询词、结果数）和每条结果的置信度标注（✅ PUBLIC API / 🟡 BROWSER SEARCH / ⚠️ AI CHAT）。
