---
name: paper-assist
version: 1.0.0
description: 论文草稿审查与改进建议
triggers:
  - "论文审查"
  - "论文改进"
  - "paper review"
  - "论文助手"
inputs:
  - name: paper_file
    description: 论文LaTeX文件路径
    required: true
  - name: bib_file
    description: 参考文献.bib文件路径
    required: true
tools:
  - read_file
  - write_file
  - web_search
  - web_fetch
---

# 论文辅助

请深入分析这个问题，提供详细的推理过程，考虑多种可能的方案并比较优劣。
1. 重新阅读@paper_name.tex ，修改其语法错误，考虑其已有部分的改进空间，不要修改开头有特殊标注（例如'之后修改'等）的段落
2. 重新阅读@references.bib ，查阅公开信息，补充引用中缺失的信息，保证其格式保持一致，且令文件按照首字母顺序依次排列
3. 创建一个新的md文档，在其中包含以下内容：
    - 阅读当前目录下论文的草稿，考虑当前论文在论证、严谨性、引文的完备性和行文组织等方面可能有何为题，给出改进方案
    - 考虑如何最终完成论文或如何进一步完善论文，不要修改任何文件
