---
name: literature-reading-assist
version: 1.0.0
description: 阅读文献并找到引用内容的原始出处
triggers:
  - "查找引文"
  - "文献出处"
  - "找到原文"
  - "citation source"
inputs:
  - name: literature_files
    description: 文献文件路径列表
    required: true
  - name: target_content
    description: 需要查找出处的内容描述
    required: true
tools:
  - read_file
  - web_search
  - web_fetch
---

# 文献阅读辅助

请深入分析这个问题，提供详细的推理过程，考虑多种可能的方案并比较优劣。
1. 阅读已经提及的文献，找到我所提到的内容的关键出处
2. 给出相关引文原文和对应的详细页码，以方便引用和验证
3. 用中文大致解释这些原文的意义，说明其作用
