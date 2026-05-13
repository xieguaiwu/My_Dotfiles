---
name: git-safety-net
version: 1.0.0
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

本规范适用于所有涉及 `write`/`edit` 等文件修改操作的 skill。
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

# 临时文件
*.swp
*.swo
*~
```

### 3. 首次快照

```bash
git add -A && git commit -m "init: checkpoint before starting work"
```

### 4. 每次 `write`/`edit` 前（快照当前状态）

```bash
git add -A && git commit -m "snapshot: before $(basename $PWD) modification" --allow-empty
```

### 5. 每次 `write`/`edit` 后（记录具体变更）

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
# 查看历史
git log --oneline

# 撤销最近一次提交（保留修改在工作区）
git reset --soft HEAD~1

# 完全回滚到某个历史版本（推荐）
git revert HEAD
```

---

## 注意事项

1. **HOME 目录保护**：绝不 init git 仓库在 `~` 下。如果工作目录是 HOME，报错退出。
2. **已有 git 仓库**：自动检测并跳过 init，直接用已有的仓库。
3. **敏感信息**：不要 commit API key、token、密码、`.env` 等。
4. **commit 信息清晰**：每次描述具体的修改内容，方便日后回滚。
5. **批量操作**：如果连续多次 `write`/`edit`，可以在最后一次统一 commit，减少历史噪音。
6. **`--allow-empty`**：用于提交快照时即使无变更也记录时间点。
