---
name: translate-assist
version: 1.0.0
description: 翻译英文论文至中文Markdown文档
triggers:
  - "翻译论文"
  - "translate paper"
  - "英文翻译"
inputs:
  - name: source
    description: 源文件路径
    required: true
  - name: output
    description: 输出文件路径
    required: false
    default: AI中译*.md
tools:
  - read_file
  - write_file
---

# 翻译辅助

请深入分析这个问题，提供详细的推理过程，考虑多种可能的方案并比较优劣。
1. 阅读并翻译目录下的英文论文至中文
2. 输出中文翻译至@AI中译（论文原名）.md，如果目录当前不存在这个文件，则创建一个
3. 保证所有的数学表达式都以markdown内嵌latex的形式出现
3. 省略参考文献列表
