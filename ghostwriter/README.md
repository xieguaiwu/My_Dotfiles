# Ghostwriter 数学渲染修复（flatpak 26.04.3 + pandoc 3.x）

## 问题背景
ghostwriter 26.04 起，预览数学渲染完全由 HTML 导出器决定：只有 Pandoc 系 `supportsMath()=true`，
cmark-gfm 不支持。且官方拼出的命令 `pandoc -f markdown +smart -t html --mathjax` 在 pandoc 3.x 下
失败（独立 `+smart` 被当作输入文件）。详见 2026-07-31 daily log。

## 组成（3 层，均被自愈脚本监控）

| 层 | 文件 | 作用 |
|---|---|---|
| wrapper | `~/.local/bin/pandoc` | 把 `-f markdown +smart` 合并为 `-f markdown+smart`，其余透传 |
| flatpak override | `~/.local/share/flatpak/overrides/org.kde.ghostwriter` | `--filesystem=~/.local/bin` + PATH 前置 |
| 配置 | `~/.var/app/org.kde.ghostwriter/config/kde.org/ghostwriter.conf` | `lastUsedExporter=Pandoc` |

## 自愈机制
- 脚本：`~/.local/bin/fix-ghostwriter-math.sh`（本目录为源副本，幂等，任意时刻可跑）
- systemd user timer：`ghostwriter-math-fix.timer`（开机 3 分钟后 + 每 24h，Persistent）
- 安全设计：ghostwriter 运行中**不碰配置**（应用退出时会覆盖配置文件，避免写坏）
- 日志：`~/.cache/ghostwriter-math-fix.log`

## 解除（还原默认）
```bash
systemctl --user disable --now ghostwriter-math-fix.timer
rm ~/.local/bin/fix-ghostwriter-math.sh
rm ~/.local/bin/pandoc
flatpak override --user --reset org.kde.ghostwriter
# 可选：配置文件里 lastUsedExporter 改回 cmark-gfm
```

## 已知权衡
- Pandoc 渲染比 cmark-gfm 慢，长文档实时预览略卡（数学渲染的代价）
- 若未来 ghostwriter 官方修复 +smart 问题或支持 cmark-gfm 数学，可删除 wrapper
  与 override 后，仅保留 `lastUsedExporter=Pandoc` 即可
