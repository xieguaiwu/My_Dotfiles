# 会话上下文记录

## 1. AP Physics 1 历年真题下载

### 已下载资源

**FRQ真题 + 评分标准**（2015-2025年）：

| 年份 | FRQ | 评分标准 |
|------|-----|----------|
| 2015 | FRQ.pdf (288K) | Scoring_Guidelines.pdf (665K) |
| 2016 | FRQ.pdf (287K) | Scoring_Guidelines.pdf (191K) |
| 2017 | FRQ.pdf (531K) | Scoring_Guidelines.pdf (363K) |
| 2018 | FRQ.pdf (555K) | Scoring_Guidelines.pdf (677K) |
| 2019 | FRQ.pdf (396K) | Scoring_Guidelines.pdf (488K) |
| 2021 | FRQ.pdf (551K) | Scoring_Guidelines.pdf (680K) |
| 2022 | FRQ.pdf (473K) | Scoring_Guidelines.pdf (4.1M) |
| 2023 | FRQ.pdf (625K) | Scoring_Guidelines.pdf (681K) |
| 2024 | FRQ.pdf (4.6M) | Scoring_Guidelines.pdf (459K) |
| 2025 | FRQ.pdf (390K) | Scoring_Guidelines.pdf (446K) |

**MCQ资源**：

| 文件 | 大小 | 说明 |
|------|------|------|
| 2017/Practice_Exam_MCQ.pdf | 2.8M | 2017年完整Practice Exam（含MCQ+答案） |
| 2022/Practice_Exam_1_MCQ.pdf | 4.3M | 2022年Practice Exam #1 |
| Sample_Questions_MCQ_FRQ.pdf | 1019K | College Board官方样题 |
| Practice_Exam_Complete.pdf | 3.6M | 官方Practice Exam |
| Practice_Workbook_1_MCQ.pdf | 56M | MIT整理的MCQ练习题库 |
| 500_AP_Physics1_Questions.pdf | 2.9M | 500道AP Physics 1题目 |
| Practice_Test_4_MCQ.pdf | 2.5M | Princeton Review练习测试 |

**说明**：
- 2020年因COVID-19考试形式特殊，College Board未公开PDF版本
- College Board官方不公开完整MCQ试卷（除Practice Exam外）

---

## 2. 数学分析学科介绍

### 学科树位置

```
数学
├── 分析学
│   ├── 微积分
│   ├── 实分析
│   ├── 复分析
│   ├── 泛函分析
│   ├── 调和分析
│   └── 偏微分方程
```

### 三大分析学科对比

| 学科 | 研究对象 | 核心空间 | 典型问题 |
|------|----------|----------|----------|
| 实分析 | 实数集上的函数与极限 | L^p(ℝ) | 积分何时可换序？ |
| 复分析 | 复平面上的解析函数 | 全纯函数 | 积分如何计算？ |
| 泛函分析 | 无穷维空间上的线性算子 | Banach/Hilbert | 算子是否有逆？谱是什么？ |

---

## 3. GLM-5 模型信息

### 定价（2026年）

| 版本 | Input价格 | Output价格 |
|------|-----------|------------|
| 海外版 | $1.0/百万tokens | $3.2/百万tokens |
| 国内版 | ¥4-8/百万tokens | - |

### 2亿 Input Token 花费

- 海外版：$200 USD（≈¥1,440）
- 国内版：¥800 - ¥1,600 RMB

### 免费/廉价使用方式

1. **NVIDIA NIM**：https://build.nvidia.com/z-ai/glm5/deploy
   - 完全免费，需注册NVIDIA账号
   - 限制：约40 RPM

2. **智谱清言**：https://chatglm.cn/
   - 官方网页端，有免费额度

3. **智谱API平台**：https://open.bigmodel.cn/
   - 新用户注册送2500万tokens免费额度

4. **OpenRouter**：https://openrouter.ai/z-ai/glm-5

---

## 4. OpenCode 配置

### 当前配置文件

**位置**：`~/.config/opencode/opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "websearch": "allow",
    "webfetch": "allow"
  },
  "plugin": [
    "oh-my-opencode@latest",
    "@tarquinen/opencode-dcp",
    "opencode-worktree",
    "opencode-pty",
    "opencode-browser",
    "opencode-notificator"
  ],
  "provider": {
    "zhipuai": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "智谱AI",
      "options": {
        "baseURL": "https://open.bigmodel.cn/api/paas/v4",
        "apiKey": "YOUR_API_KEY"
      },
      "models": {
        "glm-5": {
          "name": "GLM-5",
          "limit": { "context": 202752, "output": 8192 }
        },
        "glm-4.7": {
          "name": "GLM-4.7",
          "limit": { "context": 128000, "output": 4096 }
        },
        "glm-4.7-flash": {
          "name": "GLM-4.7 Flash",
          "limit": { "context": 128000, "output": 4096 }
        }
      }
    }
  },
  "compaction": {
    "auto": true,
    "strategy": "summarize",
    "threshold": 0.8,
    "prune_tool_outputs": true
  }
}
```

### oh-my-opencode.json

**位置**：`~/.config/opencode/oh-my-opencode.json`

当前配置使用智谱API：
- 核心Agent（sisyphus, prometheus, oracle, atlas）→ `glm-5`
- 辅助Agent（metis, momus, librarian）→ `glm-4.7`
- 快速任务（explore, quick）→ `glm-4.7-flash`

### 推荐插件

| 插件 | 功能 |
|------|------|
| oh-my-opencode | 多智能体协作系统 |
| @tarquinen/opencode-dcp | 动态上下文裁剪 |
| opencode-worktree | Git Worktree保护 |
| opencode-pty | 交互式终端支持 |
| opencode-browser | Playwright浏览器 |
| opencode-notificator | 桌面通知 |

### 插件安装方式

插件通过修改配置文件的 `plugin` 数组安装，而非命令行。OpenCode启动时自动用Bun安装npm包。

---

## 5. iFlow CLI vs OpenCode 对比

### 缓存/历史记录差异

| 工具 | 存储方式 | 说明 |
|------|----------|------|
| iFlow CLI | Git仓库存储历史 | 使用Git管理对话历史，产生大量tmp_pack文件 |
| OpenCode | JSON文件存储 | 会话存储在 `~/.local/share/opencode/storage/sessions` |

iFlow CLI通过Git仓库存储对话历史，导致产生大量缓存文件；OpenCode使用轻量级JSON存储，更节省空间。

---

## 6. NVIDIA NIM API Key 获取

1. 访问 https://build.nvidia.com/
2. 点击右上角 **Login** 注册账号
3. 访问 https://build.nvidia.com/settings/api-keys
4. 点击 **生成 API Key**
5. 复制并保存（只显示一次）

**使用方式**：
```
base-url: https://integrate.api.nvidia.com/v1
model: z-ai/glm-5
```

---

*文档生成时间：2026-03-23*
