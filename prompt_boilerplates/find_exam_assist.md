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
  - websearch_web_search_exa
  - webfetch
  - bash
  - write
---

# 真题查找辅助

## 任务目标
查找并下载 AP 考试真题资源，包括选择题(MCQ)和简答题(FRQ)及其答案。

## 执行流程

### 1. 确定搜索范围
根据 `subject`、`year_start`、`year_end` 确定需要查找的年份范围。

**常见AP科目**：
- AP Calculus AB/BC
- AP Physics 1/2/C
- AP Chemistry
- AP Biology
- AP Statistics
- AP Computer Science A

### 2. 搜索MCQ资源

**搜索策略**：
```
site:apcentral.collegeboard.org [subject] MCQ practice exam
site:apstudents.collegeboard.org [subject] multiple choice
"[subject]" "practice exam" MCQ pdf
```

**MCQ来源**：
- College Board 官方 Practice Exam
- AP Central 的 Sample Questions
- 第三方资源（Princeton Review, Barron's等）

**注意事项**：
- College Board 官方不公开完整MCQ试卷（除Practice Exam外）
- 部分年份可能没有公开MCQ资源

### 3. 搜索FRQ资源

**搜索策略**：
```
site:apcentral.collegeboard.org [subject] FRQ [year]
"[subject]" "free response" [year] pdf
"[subject]" "scoring guidelines" [year]
```

**FRQ来源**：
- AP Central 官方发布（每年都会公开）
- 包含题目和评分标准(Scoring Guidelines)

### 4. 下载并组织文件

**目录结构**：
```
{output_dir}/
├── {year}/
│   ├── FRQ.pdf
│   ├── Scoring_Guidelines.pdf
│   ├── MCQ.pdf (如有)
│   └── MCQ_Answers.pdf (如有)
├── {year+1}/
│   └── ...
```

**下载命令**：
```bash
wget -O {output_dir}/{year}/FRQ.pdf "{url}"
```

### 5. 验证完整性

**检查清单**：
- [ ] 每年都有FRQ.pdf
- [ ] 每年都有Scoring_Guidelines.pdf
- [ ] MCQ资源（如有）已下载
- [ ] 文件大小合理（非空文件）
- [ ] PDF可正常打开

### 6. 生成汇总报告

在 `{output_dir}/README.md` 中记录：
- 已下载的资源列表
- 缺失的资源
- 文件大小信息
- 来源链接

## 输出格式

```markdown
## AP [Subject] 真题下载报告

### 已下载资源

| 年份 | FRQ | 评分标准 | MCQ | MCQ答案 |
|------|-----|----------|-----|---------|
| 2015 | ✓ | ✓ | ✓ | ✓ |
| 2016 | ✓ | ✓ | - | - |
| ... | ... | ... | ... | ... |

### 缺失资源
- 2016年 MCQ: College Board未公开
- 2020年: 因COVID-19考试形式特殊，无完整试卷

### 文件位置
{output_dir}/
```

## 注意事项
1. **版权问题**: 仅供个人学习使用
2. **官方来源优先**: 优先从 College Board 官方下载
3. **网络问题**: 如下载失败，尝试更换镜像源或重试
4. **特殊年份**: 2020年因疫情考试形式特殊，资源可能不完整
