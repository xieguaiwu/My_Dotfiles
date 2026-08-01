---
name: nethack-save-manager
version: 1.0.0
description: 备份或恢复 NetHack 存档（save file），处理存档路径、权限、压缩格式
triggers:
  - "备份nethack"
  - "恢复nethack"
  - "nethack存档"
  - "nethack save"
inputs:
  - name: action
    description: "操作类型：backup（备份）或 restore（恢复）"
    required: true
  - name: backup_dir
    description: 备份文件存放目录
    required: false
    default: "$HOME"
  - name: target_save
    description: 要恢复的备份文件路径
    required: false
    default: ""
tools:
  - bash
  - read
  - ls
---

# NetHack Save Manager

## 任务目标
快速备份或恢复 NetHack 游戏存档，处理权限、路径、压缩格式等细节。

## 环境约定

| 项目 | 值 |
|------|-----|
| nethack 版本 | 3.6.7 (Fedora package) |
| 角色名 | xieguiawu |
| UID | 1000 |
| HACKDIR | `/usr/games/nethack` |
| SAVEDIR | `/var/games/nethack/save/` |
| 存档文件名 | `{UID}{角色名}` = `1000xieguiawu` |
| 存档文件路径 | `/var/games/nethack/save/1000xieguiawu.gz` |
| 存档格式 | gzip 压缩二进制（nethack 自动压缩） |
| 存档文件权限 | `660`（属主 `xieguiawu:games`）|
| 存档目录权限 | `775`（属主 `root:games`，用户可写文件但不可删除）|
| 备份命名格式 | `~/nethack_backup_{YYYYMMDD_HHMMSS}.gz` |

## 权限要点
- 用户 `xieguiawu` **不在** `games` 组，不能直接新建/删除 `/var/games/nethack/save/` 下的文件
- 但 nethack 二进制是 `setgid games`，运行时可以写
- **可以覆写已有的存档文件**（因为文件属主为 xieguiawu）
- **不能删除**存档文件或目录内的其他文件

---

## 执行流程

### 备份操作

1. **确认当前存档存在**
   ```bash
   ls -la /var/games/nethack/save/1000xieguiawu.gz
   ```

2. **复制存档到备份目录**
   ```bash
   cp /var/games/nethack/save/1000xieguiawu.gz \
      ~/nethack_backup_$(date +%Y%m%d_%H%M%S).gz
   ```

3. **验证备份创建成功**
   ```bash
   ls -la ~/nethack_backup_*.gz
   ```

### 恢复操作

1. **确认备份文件存在**
   ```bash
   ls -la {target_save}
   ```
   若不指定 `target_save`，自动使用最新的备份：
   ```bash
   ls -1t ~/nethack_backup_*.gz | head -1
   ```

2. **标记 nethack 存档文件为可写**（仅运行 nethack 后才可写）
   如果 `/var/games/nethack/save/1000xieguiawu.gz` 不存在，需要先运行一次 nethack 让游戏创建存档：
   ```bash
   timeout 3 nethack <<< "" 2>/dev/null
   ```
   （然后立刻退出新游戏，生成的存档文件属主为 xieguiawu，即可覆写）

3. **覆写存档文件**
   ```bash
   cat {target_save} > /var/games/nethack/save/1000xieguiawu.gz
   ```
   ⚠️ 使用 `cat >` 而非 `cp`，因为 `cp` 会尝试新建文件（无目录写权限），`cat >` 仅覆写内容（有文件写权限）。

4. **验证恢复**
   ```bash
   ls -la /var/games/nethack/save/1000xieguiawu.gz
   ```
   检查文件大小是否与备份一致。

5. **测试存档可加载**
   ```bash
   echo "y" | timeout 3 /usr/games/nethack/nethack -u xieguiawu 2>&1 | strings | grep "welcome back"
   ```
   若输出包含 `welcome back` 则恢复成功。

### 清理旧备份

只保留最新备份：
```bash
ls -1t ~/nethack_backup_*.gz | tail -n +2 | xargs rm -f
```

---

## 注意事项
1. **备份前确保游戏已存档**（已在 nethack 内保存或退出）。运行时直接 `cp` 即可。
2. **恢复前确保游戏没在运行**，否则存档可能被覆盖。
3. **恢复后会丢失备份后的游戏进度**。建议恢复前先备份当前存档。
4. 恢复后角色名/职业/等级等信息会回到备份时的状态。可通过 `strings` 快速查看角色信息：
   ```bash
   zcat ~/nethack_backup_*.gz | strings | grep -E "^[A-Z]" | head -5
   ```
5. nethack 存档是版本相关的。跨版本恢复可能失败（当前版本 3.6.7）。
6. **Bones 文件**（`/var/games/nethack/bonD*.gz`）记录死亡数据，删除无影响，不涉及进度恢复。

---

## 快速参考

```bash
# 备份
cp /var/games/nethack/save/1000xieguiawu.gz ~/nethack_backup_$(date +%Y%m%d_%H%M%S).gz

# 恢复（使用最新备份）
cat ~/nethack_backup_20260626_091744.gz > /var/games/nethack/save/1000xieguiawu.gz

# 查看角色信息
zcat ~/nethack_backup_*.gz | strings | grep -iE "^(Val|Mon|Kni|Wiz|Sam)" | head -3
```
