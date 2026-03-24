---
name: find-exam-assist
version: 1.0.0
description: 查找AP考试真题资源(MCQ和FRQ)
triggers:
  - "查找真题"
  - "下载真题"
  - "past exam"
  - "AP真题"
inputs:
  - name: subject
    description: 考试科目(如AP Calculus BC, AP Physics 1)
    required: true
  - name: year_start
    description: 起始年份
    required: false
    default: 2015
  - name: year_end
    description: 结束年份
    required: false
    default: 2025
  - name: output_dir
    description: 输出目录
    required: false
    default: past_exam/
tools:
  - web_search
  - web_fetch
  - run_shell_command
  - write_file
---

# 真题查找辅助

请深入分析这个问题，提供详细的推理过程，考虑多种可能的方案并比较优劣。

1. 查找2015-2025 AP Calculus BC的所有考试真题，包括MCQ+MCQ答案，以及FRQ+FRQ答案
2. 输出它们至目录past_exam/ ，每年考试单独建立文件夹
3. 重新确认是否已经按照要求收集完毕：1. MCQ+MCQ答案 2. FRQ+FRQ答案
