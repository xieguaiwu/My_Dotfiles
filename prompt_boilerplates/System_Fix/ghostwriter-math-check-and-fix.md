---
name: ghostwriter-math-check-and-fix
version: 1.1.0
description: 检查并修复 ghostwriter（flatpak 26.04+）实时预览数学公式不渲染——三层自愈（pandoc wrapper、flatpak override、导出器配置），幂等可重复，附全链验证与健康报告
triggers:
  - "ghostwriter数学不渲染"
  - "ghostwriter公式不渲染"
  - "数学公式显示源码"
  - "公式不渲染"
  - "ghostwriter预览修复"
  - "markdown公式渲染"
inputs:
  - name: app_id
    description: flatpak 应用 ID
    required: false
    default: "org.kde.ghostwriter"
  - name: dry_run
    description: 仅检查不修复，输出报告即止
    required: false
    default: false
tools:
  - read
  - bash
  - grep
  - edit
  - write
---

# Ghostwriter 数学渲染检查与修复 Skill

ghostwriter 26.04（flatpak）实时预览之数学渲染依赖三层易碎状态，任一断裂即公式不渲染。本 skill 逐层检查、修复、验证，幂等可重复，供手动巡检与升级后适配。

## 任务目标

1. 诊断实时预览数学公式不渲染（公式显示为源码、预览报错或空白）之根因
2. 三层自愈：pandoc wrapper、flatpak override、导出器配置
3. 全链验证渲染命令，产出健康报告；可重复执行，无副作用

## 背景机制（三层易碎点）

| 层 | 位置 | 作用 | 失效表现 |
|---|---|---|---|
| 第一层 pandoc wrapper | `~/.local/bin/pandoc` | pandoc 3.x 不认独立 `+smart`（当作输入文件）；wrapper 合并为 `-f markdown+smart` | 预览报 `withBinaryFile`、空白 |
| 第二层 flatpak override | `~/.local/share/flatpak/overrides/{app_id}` | 挂载 `~/.local/bin` 至沙箱 + PATH 前置 | wrapper 沙箱内不可达 |
| 第三层 导出器配置 | `~/.var/app/{app_id}/config/kde.org/ghostwriter.conf` | `lastUsedExporter=Pandoc`（惟 Pandoc 系 supportsMath） | cmark-gfm 下公式原样显示 |

根因记忆：ghostwriter 26.04 预览数学渲染完全由导出器决定，惟 Pandoc 导出器 `supportsMath()=true`；且其命令 `pandoc -f markdown +smart -t html --mathjax` 在 pandoc 3.x 下失效。详见 2026-07-31 daily log 与 `~/My_Dotfiles/ghostwriter/README.md`。

## 执行流程

### 0. 前置检查

1. 确认应用在：`flatpak info {app_id}`，不在则止
2. 检测 ghostwriter 是否运行：
   ```bash
   pgrep -x ghostwriter
   pgrep -f "bwrap.*{app_id}"
   ```
   **禁裸用 `pgrep -f ghostwriter`**——会匹配含该串的自身命令，误判运行中
3. 运行中 → 第三层（配置）**暂缓**，先修第一、二层，示用户关闭应用后重跑
4. `dry_run=true` → 惟检查，输出报告即止，不做任何写操作

### 1. 第一层 — pandoc wrapper 检查与恢复

```bash
ls -l ~/.local/bin/pandoc
cmp -s ~/.local/bin/pandoc ~/My_Dotfiles/ghostwriter/bin/pandoc && echo "一致" || echo "漂移或缺失"
```

- 缺失或漂移 → 从 dotfiles 源副本恢复：
  ```bash
  cp ~/My_Dotfiles/ghostwriter/bin/pandoc ~/.local/bin/pandoc
  chmod +x ~/.local/bin/pandoc
  ```
- 恢复后冒烟验证 + 关键逻辑抽查（防 dotfiles 副本本身被污染，cmp 盲区）：
  ```bash
  ~/.local/bin/pandoc --version | head -1   # 可执行性
  grep -q '+smart' ~/.local/bin/pandoc && echo "合并逻辑在" || echo "⚠ wrapper 缺 +smart 逻辑，源副本已污染"
  ```
- wrapper 语义：仅把独立 `+smart` 合并至前邻 `-f` 值，其余透传；沙箱内 exec `/app/bin/pandoc`，宿主 exec `/usr/bin/pandoc`。透明，不影响其它 pandoc 调用
- 源副本缺失 → 报警示，检查 `~/My_Dotfiles` 仓库是否完好

### 2. 第二层 — flatpak override 检查与重建

```bash
flatpak override --user --show {app_id} | grep -E "filesystems=|PATH="
```

判定：输出须含 `filesystems=~/.local/bin;` 与 `PATH=/home/xieguiawu/.local/bin:` 前缀。任缺 → 重建：
```bash
flatpak override --user --filesystem=~/.local/bin {app_id}
flatpak override --user --env=PATH=/home/xieguiawu/.local/bin:/app/bin:/usr/bin:/bin {app_id}
```

### 3. 第三层 — 导出器配置检查与修正（仅应用未运行时）

```bash
grep '^lastUsedExporter=' ~/.var/app/{app_id}/config/kde.org/ghostwriter.conf
```

- 非 `Pandoc` → 备份后修正：
  ```bash
  CONF=~/.var/app/{app_id}/config/kde.org/ghostwriter.conf
  cp "$CONF" "$CONF.bak-$(date +%Y%m%d%H%M%S)"
  sed -i 's/^lastUsedExporter=.*/lastUsedExporter=Pandoc/' "$CONF"
  ```
- **无输出（键缺失，旧版配置升级场景）** → 插入键：
  ```bash
  CONF=~/.var/app/{app_id}/config/kde.org/ghostwriter.conf
  cp "$CONF" "$CONF.bak-$(date +%Y%m%d%H%M%S)"
  if grep -q '^\[Preview\]' "$CONF"; then
    sed -i '/^\[Preview\]/a lastUsedExporter=Pandoc' "$CONF"
  else
    printf '\n[Preview]\nlastUsedExporter=Pandoc\n' >> "$CONF"
  fi
  ```
  配置文件不存在（应用从未运行）→ 无需处理，先启动一次 ghostwriter 再重跑
- 修正后确认：`grep '^lastUsedExporter=' "$CONF"`
- 同步修正备份副本 `~/My_Dotfiles/ghostwriter/ghostwriter.conf`（同 sed）
- 应用运行中 → 跳过本层，报告中注明"待应用退出后重跑"

### 4. 全链验证

沙箱内实测渲染命令（**stdin 管道传入**，沙箱 $HOME 为空壳，禁引用沙箱不可见路径）：

```bash
printf '测试：$x^2$\n\n$$\\Delta = b^2 - 4ac$$\n' | flatpak run --command=sh {app_id} -c 'pandoc -f markdown +smart -t html --mathjax'
```

- 预期输出含 `<span class="math inline">\(x^2\)</span>` 与 `<span class="math display">` 之标记
- 报 `withBinaryFile` → wrapper 失效，回第一层
- 验讫 → 重启 ghostwriter，开含 `$...$` 之 md 文件察预览
- 自愈系统健康检查（timer 失效时本 skill 即人工介入路径）：
  ```bash
  systemctl --user is-active ghostwriter-math-fix.timer   # 非 active → 重建
  tail -3 ~/.cache/ghostwriter-math-fix.log
  ```
  timer 失效 → `systemctl --user enable --now ghostwriter-math-fix.timer`，再查日志是否记录自愈

### 5. 生成报告

按「输出格式」汇总三层状态、动作、验证结果。

## 输出格式

报告模板：

```text
━━━━━ Ghostwriter 数学渲染健康报告 ━━━━━
[dry-run 仅检查] / [已执行修复]
🟢/🔴 第一层 pandoc wrapper  — 存在/恢复（源: My_Dotfiles）
🟢/🔴 第二层 flatpak override — filesystem + PATH 齐备/已重建
🟢/🔴 第三层 导出器配置       — lastUsedExporter=Pandoc/已修正（应用未运行）/待退出后重跑
✅/❌ 全链验证               — 数学标记输出/报错摘要
🟢/🔴 自愈 timer             — active/失效（已重建）
💡 建议                     — 重启 ghostwriter；或 解除方法见 README
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

报告后示用户：重启应用验证预览；若仍异常，查 `~/.cache/ghostwriter-math-fix.log` 与每日 timer 状态。

## 注意事项

1. **配置层必待应用退出** — ghostwriter 退出时写回配置，运行中修改会被覆盖
2. **pgrep 陷阱** — 裸 `pgrep -f ghostwriter` 匹配自身命令串；用 `pgrep -x` 或 `bwrap.*{app_id}` 模式
3. **沙箱 $HOME 空壳** — flatpak 无 `filesystem=home`，验证输入走 stdin，输出经 stdout
4. **wrapper 勿删** — 透明透传，宿主其它 pandoc 调用不受影响；删除则沙箱内失修，预览回归
5. **版本演进判据** — 若 ghostwriter 官方修复 `+smart` 或 cmark-gfm 支持数学：删 wrapper 与 override，惟留 `lastUsedExporter=Pandoc`；届时本 skill 升 2.0，移除相应检查层
6. **timer 已每日自愈** — `ghostwriter-math-fix.timer` 开机 3 分钟 + 每 24 小时自检；本 skill 用于手动巡检、升级后适配、timer 失效时人工介入
7. **备份文件属正常** — `conf.bak-*` 为修复前快照，可留作回滚
8. **解除方法** — 见 `~/My_Dotfiles/ghostwriter/README.md`（禁 timer + 删 wrapper/override + 配置回退）

## 变更日志

### 1.1.0 (2026-07-31)
- 精进：第一层加恢复后冒烟验证 + `+smart` 逻辑抽查（防 dotfiles 副本污染）
- 精进：第二层加 override 检测命令（grep 过滤）
- 修复：第三层补「键缺失」分支（旧版配置升级场景）+ 修正后确认
- 新增：第四层 timer 健康检查（is-active + 日志尾查 + 重建命令）
- 精进：报告模板加 dry-run 标注与 timer 状态行；注意事项 4 表述精简

### 1.0.0 (2026-07-31)
- 初始发布：三层检查+修复流程（wrapper / override / 导出器配置），附全链验证与健康报告
