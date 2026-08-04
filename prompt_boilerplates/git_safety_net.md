---
name: git-safety-net
version: 1.1.0
description: 为所有涉及文件修改的 skill 提供 git 版本追踪安全网
triggers:
  - "git安全网"
  - "版本控制"
  - "文件回滚"
tools:
  - bash
  - read
  - write
  - edit
---

# Git 安全网规范

本规范适用于产出 `.tex` 等可编译源文件、需要可回滚历史的 skill（如试卷/清单生成类）。
纯笔记整理、资源下载类 skill（产出 `.md` 笔记或下载文件）可不引用本规范，仅使用轻量写入安全规则：检查文件是否已存在 → `edit` 追加 → 覆写前告知用户。

执行文件修改前必须按以下流程执行 git 版本控制，确保每次更改都可追溯、可回滚。

---

## 执行流程

### 1. 初始化 git 仓库（仅首次执行）

在首次执行文件修改前，检查当前工作目录：

```bash
# 检查是否已在 git 仓库中
if git rev-parse --is-inside-work-tree 2>/dev/null; then
    echo "✓ 已在 git 仓库中，跳过初始化"
else
    # 保护 HOME 目录：不在 HOME 下创建 git 仓库
    if [ "$PWD" = "$HOME" ]; then
        echo "⚠️  工作目录是 HOME 目录，不允许在此创建 git 仓库"
        echo "请先 cd 到项目目录再执行"
        exit 1
    fi
    # 初始化 git 仓库
    git init
    echo "✓ git 仓库已初始化"
fi

# 检查 git 身份配置（commit 必需，新环境常缺失）
if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
    echo "⚠️  未配置 git 身份，commit 将失败。请先执行："
    echo "  git config --global user.name \"你的名字\""
    echo "  git config --global user.email \"你的邮箱\""
    exit 1
fi
```

### 2. 创建 `.gitignore`

确保以下内容写入 `.gitignore`（追加到已有文件末尾或创建新文件）：

```
# 编译产物
*.pdf
*.log
*.aux
*.out
*.toc
*.synctex.gz
*.bbl
*.blg
*.fls
*.fdb_latexmk
*.dvi

# 缓存
__pycache__/
*.pyc
node_modules/
.DS_Store

# 二进制/生成文件
*.apkg
*.zip
*.exe

# 敏感文件（禁止入库）
.env
*.pem
*.key
credentials*
secrets*
id_rsa*

# 临时文件
*.swp
*.swo
*~
```

### 3. 首次快照

```bash
# 敏感文件检查：发现疑似密钥/凭据文件即中止，确认排除后再提交
if git status --porcelain | grep -qiE '\.(env|pem|key)$|credential|secret|id_rsa'; then
    echo "⚠️  检测到疑似敏感文件（.env / *.pem / *.key / credentials* / secrets* / id_rsa*）"
    echo "请确认已加入 .gitignore 后再提交"
    exit 1
fi

git add -A && git commit -m "init: checkpoint before starting work"
```

### 4. 任务开始前（快照当前状态）

每个任务/会话开始执行修改前快照**一次**即可；同一任务内多次 `write`/`edit` 不需要每次都快照（避免历史噪音）：

```bash
git add -A && git commit -m "snapshot: before $(basename -- "$PWD") modification" --allow-empty
```

### 5. 修改后提交（记录具体变更）

同一任务内多次修改可在最后一次统一提交（见注意事项 5），不必每次修改都 commit：

```bash
git add <修改的文件路径> && git commit -m "<skill名>: <具体修改描述>"
```

**示例：**
```bash
git add AP_CSA_Mock_Exam.tex && git commit -m "ap-csa-exam-generation: 生成完整模拟试卷 v1"
```

### 6. 回滚方法

如需要撤销修改：

```bash
# 还原单个文件到最近一次提交（最常用：改坏某个文件时）
git restore <文件路径>

# 查看历史
git log --oneline

# 撤销最近一次提交（保留修改在工作区）
git reset --soft HEAD~1

# 完全回滚到某个历史版本（创建反向提交，适用于已推送的仓库）
git revert HEAD
```

---

## 注意事项

1. **HOME 目录保护**：绝不 init git 仓库在 `~` 下。如果工作目录是 HOME，报错退出。
2. **已有 git 仓库**：自动检测并跳过 init，直接用已有的仓库。
3. **敏感信息**：不要 commit API key、token、密码、`.env` 等。`.gitignore` 已内置常见敏感模式（见步骤 2）；每次提交前执行步骤 3 的敏感文件检查。
4. **commit 信息清晰**：每次描述具体的修改内容，方便日后回滚。
5. **批量操作**：同一任务内多次 `write`/`edit` 在最后一次统一 commit（配合步骤 4 的任务开始快照），减少历史噪音。
6. **`--allow-empty`**：用于提交快照时即使无变更也记录时间点。

---

## 变更日志

- **1.1.0**（2026-08-01）：明确适用范围（.tex 等可编译源文件类；纯笔记/下载类可豁免）；init 后检查 git 身份配置；`.gitignore` 内置敏感文件模式；首次快照前加敏感文件检查；步骤 4 改为"任务开始前快照一次"（消除与批量 commit 的矛盾）；回滚新增 `git restore <file>`
- **1.0.0**：初始版本
