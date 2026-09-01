---
name: sway-resume-ebusy-ime-crash
version: 1.0.3
description: sway 桌面「S3 唤醒后显示管线 EBUSY 风暴」+「IME 候选窗空指针崩溃（constrain_popup / 上游 issue #8541）」两级故障链的诊断、止血、fork 编译根治、级联会话损失清点
triggers:
  - "sway 崩溃"
  - "桌面回到登录界面"
  - "被踢回登录"
  - "屏幕不刷新"
  - "画面卡住"
  - "Atomic commit failed"
  - "Page-flip failed"
  - "Device or resource busy"
  - "constrain_popup"
  - "输入法崩溃"
  - "fcitx5 崩溃"
  - "合成器挂了"
  - "终端全没了"
  - "pi session 丢失"
  - "唤醒后花屏"
  - "合盖"
inputs:
  - name: symptom
    description: 症状描述（如「刚才桌面突然回到登录界面」）
    required: false
    default: "auto-detect"
tools:
  - read
  - bash
  - grep
  - find
  - subagent
---

# sway 唤醒后 EBUSY 风暴 + IME 空指针崩溃（两级故障链）

> 实战来源：2026-08-29 13:15:49 本机 sway SIGSEGV，整个 GUI 会话被拆，6 个终端里的 pi 会话与微信同时阵亡。

## 核心认知

这是**两个独立故障叠成一条因果链**，必须分开治：

| 级别 | 故障 | 表现 | 性质 | 治法 |
|:---|:---|:---|:---|:---|
| **① 慢性** | S3（合盖深睡）唤醒后 i915/KMS 状态机卡死 | 每一帧 `Atomic commit failed: Device or resource busy` + `Page-flip failed on output eDP-1`，刷屏数十小时；画面不刷新、输入延迟，但进程活着 | 内核/驱动态，**重启 sway 无效**（实测） | 不睡（改 `HandleLidSwitch`）／重启机器／重绑 i915 |
| **② 急性** | sway 1.10 IME 候选窗空指针（上游 [swaywm/sway#8541](https://github.com/swaywm/sway/issues/8541)，**至今未修**） | `sway[PID]: segfault at 8 … error 4`，帧 `#0 constrain_popup` → 合成器死 → logind 拆掉整个 session scope → **所有 GUI 客户端同秒成片 core**（终端、pi、微信、portal） | 用户态 bug，有 3 行补丁 | 用本地 fork 编译带补丁的 sway |

**链条关系**：①让画面失灵的十几小时里，人反复敲键盘/关窗/试输入法（fcitx5 候选窗来回开关），而 ②正好是「窗口被 kill 时 IME 候选窗还在提交帧」的空指针 —— ①是背景噪音，②是扳机。崩前日志里几乎必有这一对指纹：

```
[ERROR] [wlr] [types/wlr_input_method_v2.c:322] failed to mmap() 0 bytes
[ERROR] [wlr] [types/wlr_input_method_v2.c:388] Failed to send keymap for input-method keyboard grab
```
本次出现在 13:14:07，崩溃在 13:15:49（**约 1.7 分钟的提前量**）。

**与 ③OOM 死机区分**：`freeze-oom-protection.md` 管的是内存 thrash 冻结（日志有 `Purging GPU memory`/`oom-kill`）。本次该类关键字 **0 条**、earlyoom 未介入、内存 5.9/15G、swap 3.9/8G ⇒ 纯合成器崩溃。先做这一步排除，别去调 earlyoom。

---

## Phase 1：判别（30 秒）

```bash
# 可执行版：本目录 sway-crash-diag.sh（只读，无 sudo）
bash ~/prompt_boilerplates/System_Fix/sway-crash-diag.sh
```

手工四连：

```bash
last -x | head -6                       # 同一分钟「logged out + login screen + still logged in」= GUI 会话被拆
coredumpctl list --no-pager | tail -8   # sway 与一批 GUI 客户端同一秒 core = 合成器之死（客户端是连坐）
journalctl --since "-2 hour" --no-pager -q | grep -iE 'segfault at' | tail   # 找 sway 那行
journalctl --since "-2 hour" --no-pager -q | grep -icE 'oom-kill|out of memory|Purging GPU'   # 必须 0，否则转 freeze-oom-protection.md
```

## Phase 2：取证（确认是 constrain_popup 那一类）

```bash
T='2026-08-29 13:15:49'          # ← 换成 Phase 1 得到的时刻
PID=$(coredumpctl list --no-pager 2>/dev/null | awk '/\/usr\/bin\/sway/{p=$3} END{print p}')

# 回溯帧（journal 里自带，无需 core 文件可读）
journalctl --since "$T" --until "$T" --no-pager -q -o cat \
  | sed -n "/Process $PID (sway) of user 1000 dumped core/,/ELF object/p" \
  | grep -E '^ *#[0-9]' | head -12

# 包与 wlroots 对应关系（sway 1.10.x ↔ wlroots 0.18，包名不是 wlroots 而是 wlroots0.18）
rpm -q sway; rpm -qa | grep -i wlroots; ldd /usr/bin/sway | grep wlroots
```

判读（本次实证回溯）：

```
#0  constrain_popup (/usr/bin/sway + 0x2d385)          ← 扳机确认
#1  wl_signal_emit_mutable (libwayland-server.so.0)
#2  surface_commit_state (libwlroots-0.18.so)          ← IME popup 的 surface.commit 信号
#3-#6 ffi_call / wl_closure_invoke
#7  wl_client_connection_data → wl_event_loop_dispatch → wl_display_run → server_run
kernel: sway[588882]: segfault at 8 ... error 4        ← NULL+0x8，即 view->container==NULL 后读 ->pending.content_x
```

源码位置 `sway/input/text_input.c: constrain_popup()`：

```c
if (popup->desc.view) {
        struct sway_view *view = popup->desc.view;
        output = wlr_output_layout_output_at(root->output_layout,
                view->container->pending.content_x + view->geometry.x,   // ← container 已随 view unmap 释放
```

**根因**：view unmap → `container_begin_destroy()` 把 container 释放，但 IME popup 仍通过 `popup->desc.view` 持有该 view；IME 再提交一帧 → `handle_im_popup_surface_commit()` → `constrain_popup()` 踩空。

若帧 `#0` 不是 `constrain_popup` 而是：
- `input_popup_set_focus` / `wlr_scene_node_destroy`（双释放）
- `arrange_popups` / `wlr_scene_node_coords (node=0x91)`

→ **同族但本补丁不覆盖**，见 Phase 4 末尾「补丁边界」。

## Phase 3：治①——唤醒后 EBUSY 风暴（止血 + 断根）

### 3.1 确认风暴与唤醒 1:1 相关

```bash
# 每小时风暴计数
journalctl --since "-3d" --no-pager -q 2>/dev/null | grep "Atomic commit failed" \
  | awk '{split($3,a,":"); print $1,$2,a[1]}' | uniq -c | awk '{printf "%s %s %s  %6d\n",$2,$3,$4,$1}'

# 唤醒时刻（三种任一等价：mei_hdcp 重绑 / Lid opened / suspend exit）
journalctl --since "-3d" --no-pager -q 2>/dev/null | grep -iE 'Lid opened|PM: suspend exit' | awk '{print $1,$2,substr($3,1,8)}'

# 变体必须只有一种：本次全部是 EBUSY（Device or resource busy），说明与老 PSR 风暴不同
journalctl --since "-14d" --no-pager -q 2>/dev/null | grep -oE 'Atomic commit failed[: ].{0,30}' | sort | uniq -c | sort -rn
```

本次实测：**近 7 天 153,461 条，全部同一变体 EBUSY**；18 次唤醒逐一对应风暴小时（Aug 28 13:12 唤醒 → 该小时 8590 条；Aug 29 00:02/00:33/01:42 → 1597/4352/4794；Aug 29 04:55 合盖睡到 12:26 → 期间 0 条，醒来立刻复燃）。

**风暴密度判级（08-29 重启后实测新增）**：稠密（>10 条/分钟）= KMS 卡死，画面不可信，按 3.3 恢复；零星（<5 条/分钟，每隔几十秒几条）= i915 瞬时提交争用——**全新开机、从未睡眠的会话也有 ~2-4 条/分的基线噪声，画面正常、无需处置**。本次重启验证：风暴密度 30-38 条/分 → 2-4 条/分，显示恢复正常；即 S3 唤醒把零星噪声放大成持续风暴，零星噪声本身无害。

**同时确认老修复仍生效**（否则走 `freeze-oom-protection.md` 的 PSR 章节）：
```bash
cat /proc/cmdline | tr ' ' '\n' | grep i915        # 期望 i915.enable_psr=0
```

### 3.2 先救数据（风暴=屏幕状态不可信，随时再崩）

立刻 `git commit`、导出未落盘工作、把 pi 会话记录导出。**别指望重启 sway 能恢复显示**——本次新 sway 从启动第一帧继续 EBUSY（近 3 分钟 115 条 ≈ 38/分钟），证明卡在内核 KMS 态。

### 3.3 恢复显示（三档，从轻到重）

```bash
# 档 1（30 秒，成功率低但零成本）：DPMS 强制重训链路
swaymsg 'output * dpms off'; sleep 3; swaymsg 'output * dpms on'

# 档 2（无需重启机器，会瞬时黑屏并杀掉合成器 → 先把 GUI 里的活挪到 tmux）
sudo systemctl stop gdm
echo 0000:00:02.0 | sudo tee /sys/bus/pci/drivers/i915/unbind
sleep 2
echo 0000:00:02.0 | sudo tee /sys/bus/pci/drivers/i915/bind
sudo systemctl start gdm

# 档 3：重启（顺手做 3.4，一次解决；本机每周重启纪律本来 ~09-01 到期）
```

### 3.4 断根：让合盖不再进 S3

```bash
# 本机现状：/etc/systemd/logind.conf 不存在（全默认）→ 默认 HandleLidSwitch=suspend，且 /sys/power/mem_sleep = s2idle [deep]
sudo mkdir -p /etc/systemd/logind.conf.d
printf '%s\n' '[Login]' 'HandleLidSwitch=lock' 'HandleLidSwitchExternalPower=lock' 'IdleAction=ignore' \
  | sudo tee /etc/systemd/logind.conf.d/10-no-lid-suspend.conf
sudo systemctl restart systemd-logind
loginctl show | grep -i handle           # 复核；或 systemctl show -p HandleLidSwitch systemd-logind
```

- `lock`（推荐）：合盖只锁屏不睡，出门带着仍靠 `swaylock`；本会话继续存活，训练 SSH 不断
- 若要省电但避开 S3 路径：`mem_sleep_default=s2idle` 内核参数（`sudo grubby --update-kernel=ALL --args="mem_sleep_default=s2idle"`），代价是合盖耗电快
- 核弹选项：`sudo systemctl mask suspend.target hibernate.target hybrid-suspend.target suspend-then-hibernate.target`
- 检查自己的 swayidle 不要挂起（本机 `swayidle -w timeout 600 'swaylock -f' before-sleep 'swaylock -f'` 是干净的，挂起全来自 logind）

## Phase 4：治②——用本地 fork 编译带补丁的 sway

### 4.0 资产与上游状态（2026-08-29 实测）

| 项 | 值 |
|:---|:---|
| fork 仓库 | `~/sway`，`origin=https://github.com/xieguaiwu/sway.git`，`upstream=https://github.com/swaywm/sway.git` |
| 补丁分支 | `fix/constrain-popup-null-container`（commit `3024142f`，**+3/−0**，1 文件，2026-07-01） |
| 上游 PR | [swaywm/sway#9206](https://github.com/swaywm/sway/pull/9206) **仍 OPEN**：emersion 2026-07-01 要求 rebase → 2026-07-03 已 rebase 并 /cc，至今无 review、无合并 |
| 上游 issue | #8541 OPEN（19 评论，含多种同族回溯） |
| 上游各分支是否自带修复 | **全部没有**：`for r in upstream/v1.10 upstream/v1.11 upstream/v1.12 upstream/master; do git show $r:sway/input/text_input.c \| sed -n '/if (popup->desc.view)/,+3p'; done` 逐条确认无 NULL 检查 |
| 本机实装 | `sway-1.10.1-1.fc42` + `wlroots0.18-0.18.3`（`ldd /usr/bin/sway` → `libwlroots-0.18.so`） |

**版本选择铁律（wlroots 硬绑定，选错就编译不出来）**：

| sway ref | 需要 wlroots | Fedora 42 是否有包 | 结论 |
|:---|:---|:---|:---|
| `upstream/v1.10`（=实装系） | **0.18** | `wlroots0.18-devel-0.18.3` ✓ | ✅ **首选**：与现有系统完全同构，最小 delta |
| `upstream/v1.11` | 0.19 | 有 `wlroots 0.19.2`（`wlroots0.19-devel` 需自查） | ⚠️ 需连 wlroots 一起升 |
| `upstream/v1.12` | 0.20 | ✗ | ❌ 得自己编 wlroots |
| fork `master`（1.13-dev） | 0.21 | ✗ | ❌ 同上，别顺手 `git checkout master` 编译 |

补丁在 `upstream/v1.10` 上 `git apply --check` **实测干净通过**。

### 4.1 一键脚本（推荐）

```bash
# 只读演练：打印将执行的依赖清单、worktree、补丁校验、meson 参数
bash ~/prompt_boilerplates/System_Fix/sway-ime-fix-build.sh --dry

# 真跑：第 1 步依赖需你亲自 sudo（脚本会把命令原样打印），随后自动 worktree→apply→meson→ninja
bash ~/prompt_boilerplates/System_Fix/sway-ime-fix-build.sh --deps      # 只打印 dnf 命令
bash ~/prompt_boilerplates/System_Fix/sway-ime-fix-build.sh --build     # 编译（~2 分钟，装到 ~/sway-build/build）

# 安装（写 /usr/local，需 sudo；脚本再次给出确切命令）
bash ~/prompt_boilerplates/System_Fix/sway-ime-fix-build.sh --install   # 打印 sudo 命令
```

### 4.2 手工等价步骤（脚本失败时逐步排错）

```bash
# 1) 依赖（本机缺失，仓库全有；tray 走 libsystemd 免 basu，man 页免 scdoc）
sudo dnf install -y gcc meson ninja pkgconf-pkg-config git \
  wayland-devel wayland-protocols-devel libxkbcommon-devel json-c-devel \
  libevdev-devel libinput-devel mesa-libGLES-devel xcb-util-wm-devel \
  wlroots0.18-devel pango-devel cairo-devel pixman-devel libdrm-devel systemd-devel

# 2) 干净 worktree（⚠️ 不要在 ~/sway 里 checkout，会打断你自己的 IDE/历史）
#    本地无 v1.10.1 tag（git tag | grep '^v1\.1' 为空）→ 用分支 upstream/v1.10
git -C ~/sway worktree add -b local/1.10-ime-fix /tmp/sway-ime-fix upstream/v1.10
git -C ~/sway show fix/constrain-popup-null-container -- sway/input/text_input.c > /tmp/ime-fix.patch
cd /tmp/sway-ime-fix && git apply --check /tmp/ime-fix.patch && git apply /tmp/ime-fix.patch
git -C /tmp/sway-ime-fix diff --stat          # 必须显示 1 file changed, 3 insertions(+)

# 3) 编译
cd /tmp/sway-ime-fix
meson setup build --prefix=/usr/local --buildtype=plain \
  -Dsd-bus-provider=libsystemd -Dman-pages=disabled -Ddefault-wallpaper=false
ninja -C build
./build/sway/sway --version                   # 期望 sway version 1.10.1（打了补丁，版本号不变，别以为没生效）

# 4) 安装 + GDM 入口
sudo ninja -C build install                   # → /usr/local/bin/sway 等
sudo mkdir -p /usr/local/share/wayland-sessions
printf '%s\n' '[Desktop Entry]' 'Name=Sway (IME fix)' \
  'Comment=An i3-compatible Wayland compositor (constrain_popup NULL guard)' \
  'Type=Application' 'Exec=/usr/local/bin/sway' \
  | sudo tee /usr/local/share/wayland-sessions/sway-imefix.desktop
```

**为什么 `Exec=/usr/local/bin/sway` 要写绝对路径**：Fedora 的入口是 `/usr/libexec/gdm-wayland-session --register-session sway`（本次日志实证），它**按 PATH 找 sway**，而 `/usr/local/bin` 在 `/usr/bin` 之前 ⇒ 装完后连原来那个「Sway」菜单项也会用新二进制。两条路都通，但必须记住：**以后 `dnf update sway` 不会覆盖 /usr/local/bin/sway，系统里会长期留着自编译版**（见 4.4）。

### 4.3 验证闭环（不可跳）

```bash
/usr/local/bin/sway --version
# 注销 → GDM 齿轮选 "Sway (IME fix)" → 登录后：
swaymsg -t get_version                        # 期望 {"version":"1.10.1"}
strings $(readlink -f /usr/local/bin/sway) | grep -c 'constrain_popup'   # ≥1（符号表在即可）
journalctl --since "-10 min" --no-pager -q | grep -c 'Atomic commit failed'   # 关键：应 0（不睡了就不会再卡）
```

**复现测试**（原崩溃路径，打补丁前必崩）：
1. 开一个有输入框的窗口（foot/gedit/Chromium 皆可，本次是 wechat + fcitx5）
2. 激活 fcitx5 让候选窗弹出（打中文）
3. 候选窗还开着就 `Ctrl+q`（本机 kill 绑定）关窗
4. 通过判据：sway **不崩**，`coredumpctl list | tail -3` 无新 sway 条目
   —— 上游 issue #8541 的复现配方与此一致（"close a window while the IME candidate popup is still active"）

### 4.4 回滚与升级纪律

```bash
sudo ninja -C /tmp/sway-ime-fix/build uninstall    # 或 sudo rm -f /usr/local/bin/sway{bar,nag,msg,icongit,unit}
rm -rf /tmp/sway-ime-fix && git -C ~/sway worktree remove --force /tmp/sway-ime-fix
# 回滚后 /usr/bin/sway（1.10.1-1.fc42）继续用，行为回到「会崩」状态
```

- 每次 `dnf update sway` 后**必须**在新版本上重打补丁并重装，否则 /usr/local 的旧自编译版继续抢 PATH
- 补丁跟踪上游：若 #9206 被合入或 #8541 关闭，改从含修复的 tag 编译，删掉本地 worktree 与 /usr/local 覆盖

### 4.5 补丁边界 + 不编译也能立刻降概率

- 本补丁只挡 `constrain_popup()` 一条路径。#8541 里另有两类同族回溯（`input_popup_set_focus`/`wlr_scene_node_destroy` 双释放、`arrange_popups`/`wlr_scene_node_coords node=0x91`）**不被覆盖**。若之后崩在那些帧：把守卫扩到 `input_popup_set_focus()` 入口（`popup->desc.view` 及其 container 有效性检查），或整体升到 sway 1.11 + wlroots 0.19 再打同一补丁。
- 临时缓解（上游报告者自己的做法：切窗/关窗时先把 IME 进程/候选窗干掉）：
  ```
  # 本机 kill 绑定是 bindsym Ctrl+q kill，改为先收掉候选窗再 kill
  bindsym Ctrl+q exec --no-startup-id sh -c 'fcitx5-remote -c >/dev/null 2>&1; sleep 0.1; swaymsg "[con_id=__focused__] kill"'
  ```
  `fcitx5-remote` 本机已装（`/usr/bin/fcitx5-remote`）。改完 `swaymsg 'reload'`。

## Phase 5：级联损失清点——桌面崩了之后有哪些 pi 会话没了

> **磁盘上无法区分「空闲但开着」与「早已关闭」**：pi 的 session jsonl 只有 `session/model_change/thinking_level_change/message/custom/custom_message/session_info` 这些 type，**没有正常退出标记**。所以结论分「确证被杀」与「待人工回忆」两档。

```bash
bash ~/prompt_boilerplates/System_Fix/sway-crash-diag.sh --sessions      # 直接出表
```

方法（脚本已实现，手工版）：

```bash
T='2026-08-29 13:15:49'; PID=588882

# a) 确证被杀：崩溃瞬间正在写盘
find ~/.pi/agent/sessions -name '*.jsonl' -newermt "$T - 2 min" ! -newermt "$T + 2 sec"

# b) 哪些 session 已经活回来了：现存 pi 进程的 cwd
for p in $(pgrep -x pi); do readlink /proc/$p/cwd; done | sort | uniq -c
#    子代理归属：tr '\0' '\n' < /proc/$p/environ | grep PI_SUBAGENT_ORCHESTRATOR_SESSION_ID

# c) 判定规则
#    mtime > T+20s            → 崩溃后仍在写 = 已恢复，别再动
#    T-6s < mtime <= T+2s     → 崩溃瞬间正在工作 = 被杀（最该救）
#    今天有写入 & mtime < T    → 崩前停笔：cwd 有活进程=已恢复 / cwd 无活进程=待人工回忆
#    总条数与首条 timestamp     → 1K 左右、只有 header 的 = 起坏了的空壳，可弃
```

**恢复命令模板**（cwd 必须先进对，session id 用短前缀即可）：

```bash
cd ~/Desktop/go-projects/LLM-api-check && pi --session 01a04bf0-44c4-73a3-a3db-5575073bbaa5
# 或在该目录下 `pi -r` 取最近一条
```

**子代理 run 是否被腰斩**（必须逐个查，否则会把半截结论当真）：

```bash
D=~/.pi/agent/sessions/<项目目录编码>/<日期Z>_<orchestrator-id>
for r in $D/*/run-0/session.jsonl; do
  printf '%s  行%s  末条:' "$(date -r $r +%H:%M:%S)" "$(wc -l < $r)"
  tail -1 "$r" | python3 -c "import sys,json;d=json.load(sys.stdin);print(' ',d.get('type'),d.get('timestamp'))"
done
# mtime == 崩溃时刻 且末条不是 final 输出 ⇒ 结果丢失，恢复后重跑；不要读 subagent-artifacts/*_transcript.jsonl 的半截内容当结论
```

### 本次（2026-08-29 13:15:49）清点结果

| 档 | session | cwd | 最后写 | 现状 |
|:---|:---|:---|:---|:---|
| ★确证被杀 | `01a04bf0-44c4-73a3-a3db-5575073bbaa5` | `~/Desktop/go-projects/LLM-api-check` | 13:15:48（崩前 1 秒，正在派子代理查百炼 Token Plan 用量 API） | **未恢复** |
| 待回忆 | `01a04129-…`（1.45M 旧卷） | VERSION2.5 | 02:41 | 已被 `01a04bdc` 取代 |
| 待回忆 | `01a0484d-…`（861K） | Downloads/schmitt-article-Rosenkranz | 02:25 | 无活进程 |
| 待回忆 | `01a0493c-…`（1.17M） | Downloads/white-book-paper/The Price of Human Capital | 01:28 | 无活进程 |
| 待回忆 | `01a04943-…`（448K） | Desktop/android-projects/Roar | 00:53 | 无活进程 |
| 空壳可弃 | `01a04bdb-…`（1K） | VERSION2.5 | 12:51 | 起坏了 |
| ✔已恢复 | `01a04bdc-…` | VERSION2.5（编排，4 子代理在跑） | 崩后持续 | 活 |
| ✔已恢复 | `01a04bed-…` | works/记录 | 崩后持续 | 活 |
| 腰斩子代理 run | `a9583903`(ultrabrain) / `d814df3a`(ultrabrain) / `dbde7847`(hephaestus) / `72a73ac6`(ultrabrain) | 属 `01a04bdc` | 13:15:43/49/50/51 各断在半途 | 已由新 run `feaa6f7c/9c489e8f/767cbd55/50f104ae` 重放 |

**最重要的运维教训**：pi 会话跑在 GUI 终端里 = 合成器一死全灭。长活会话放 tmux（本机已装 `/usr/bin/tmux`），并让 tmux server 脱离 GUI：

```bash
# 会话开在 tmux 里，且 tmux server 用 systemd-run --user 拉活（logind session scope 之外）
systemd-run --user --unit=pi-tmux --remain-after-exit tmux new -s pi
# 之后任意终端：tmux attach -t pi     （sway 崩了 tmux server 与其中的 pi 照样活着）
```

## 预防清单

1. **合盖不进 S3**（`HandleLidSwitch=lock`）——这是 EBUSY 风暴的唯一入口，做了它就不再有风暴，也就失去 ②的扳机场景
2. **装带补丁的 sway**（Phase 4）——即便误睡，也不会再把整会话带走
3. 长活 pi/训练前端会话放 **tmux + systemd-run --user**（Phase 5 末尾）
4. kill 绑定改成先 `fcitx5-remote -c` 再 kill（Phase 4.5）——零成本的同族保险
5. 风暴告警（可选，接进现有 cron 体系）：
   ```bash
   @hourly n=$(journalctl --since "-1 hour" -q --no-pager | grep -c 'Atomic commit failed'); [ "$n" -gt 600 ] && notify-send "sway 显示管线风暴 $n 条（S3 唤醒后遗症复发）"
   ```
6. 每周重启纪律（下次 ~09-01）：重启是清 EBUSY 最便宜的手段，别攒

## 注意事项 / 血泪坑

1. **`git worktree add <不存在的 ref>` 失败后，同一行 `&&` 链外的命令会在主仓库跑**——我第一次把 `cd /tmp/sway-v1101 && git apply --check` 写成两条命令，worktree 建失败、`cd` 失败，`git apply --check` 却在 `~/sway`（master）上打出 "APPLIES CLEAN" 的**假阳性**。凡 worktree/checkout 之后的动作，必须 `&&` 串起来并单独 `git -C <dir> rev-parse --short HEAD` 自证。
2. `~/sway` 里 **没有 v1.10.1 tag**（`git tag | grep '^v1\.1'` 为空，只有 1.5~1.9 老 tag），要用分支 `upstream/v1.10`；本地 `git describe` 还停在 `1.11-rc2-153`，别拿它当版本号。
3. sway 1.10.x 配 **wlroots 0.18**，`rpm -q wlroots` 查不到会误判「没装 wlroots」——真名 `wlroots0.18`（同仓库还有 `wlroots0.15/0.16/0.17/0.18-devel` 各版本并行包）。
4. 回溯里 **wlroots 帧不带符号**（`libwlroots-0.18.so + 0x689cc`），分类靠 `#0` 落在 `/usr/bin/sway` 的符号名，别在 wlroots 帧上找函数。
5. sway 死后**同一秒成片 core 是连坐**（本次 wechat SIGSEGV 13:15:50/54、xdg-desktop-portal-gtk FAILURE、GDM greeter 的 gnome-shell 起了又拆）。给应用崩溃计数时要先剔除这类「合成器之死」，否则微信/浏览器的崩溃统计全被污染。
6. `i915.enable_psr=0` 已持久生效（`/proc/cmdline` 可查），所以本次 EBUSY **不是**老 PSR 风暴复发（那条日均从 50 万降到 3.1 万，见 `freeze-oom-protection.md`）——两套变体文案要分清：老的是 `Atomic commit failed: -16`（含 PSR 字样），新的是 `: Device or resource busy`。
7. 崩后遗物：`df` 报 `/run/user/1000/gvfs: Transport endpoint is not connected`；旧 `session-1238.scope` 仍 `active (abandoned)`，48 tasks / 3.6G（peak 11.4G）挂着 2× `dbus-daemon --session`、opencli daemon、`rbw-agent`、gradle daemon(`-Xmx3g`)、`gpg-agent`。**清理顺序**：`gradle --stop` → kill 旧 dbus/opencli → `rbw-agent`/`gpg-agent` 留着（新会话还在连）→ 整机重启才会消净 gvfs 与 scope。
8. sway 配置里 **`;` 是 sway 命令分隔符，不是 shell 的**。本机第 109/110 行 `exec --no-startup-id pkill -x wl-paste; wl-paste --type text --watch clipman store` 的后半被当成 sway 指令解析，报 `Unknown/invalid command 'wl-paste'`（clipman 剪贴板历史实际一直没起）。正确写法整条加引号：`exec --no-startup-id "pkill -x wl-paste; wl-paste --type text --watch clipman store"`，且需 `sudo dnf install wl-clipboard`（本机未装）。
9. 新 sway 一起来就继续刷 EBUSY ⇒ **不要浪费时间去重装 sway 找显示问题**，那是内核态；重装 sway 只解决 ②。
10. `journalctl -p err` 的 `-p err` 会把 sway 的 wlr ERROR 行一起吞掉（它走 stderr→journal 但不是 err 优先级），本次靠无优先级过滤才看到；诊断时**别加 `-p err`**。
11. **meson 双版本坑**（本机实测）：`~/.local/lib/python3.13/site-packages` 里的 pip meson 1.11.1 遮蔽了 rpm 版 1.7.2 —— 用户态 `meson --version` 永远报 1.11.1（连 `/usr/bin/meson` 包装器都被 user-site 遮蔽），root/sudo 下才暴露 1.7.2 → `sudo ninja install` 报 "build directory generated with Meson X, incompatible with Y"。`sway-ime-fix-build.sh --install` 已内置解法（注入用户 PYTHONPATH 重放同一 meson，失败则 reconfigure 兑底）；手工操作时用 `PYTHONPATH=$(python3 -c 'import site;print(site.getusersitepackages())') sudo -E meson install -C build` 或干脆 `sudo meson setup --reconfigure build && sudo meson install -C build`。

---

## 附录：本次配套脚本的编程问题自审（2026-08-29）

> 生成 `sway-crash-diag.sh` 与 `sway-ime-fix-build.sh` 过程中暴露的自身 bug 清单，全部已修复并沉淀为反面教材。

### A. 诊断脚本 `sway-crash-diag.sh`

| # | 问题 | 根因 | 影响 | 修复 |
|:--|:--|:--|:--|:--|
| A1 | `coredumpctl list -o json` 解析为空 | systemd 257 **不支持** `-o json`，静默回退表格输出 | 崩溃时刻定位失败 | 改按表格正则解析 |
| A2 | `date -d "@$EPOCH -3 min"` 报 invalid date | GNU date 的 `-d` 不接受"epoch + 偏移"混合表达式 | 崩溃窗口取证失效 | 改 `@$((EPOCH-180))` 纯算术 |
| A3 | cwd 归属用 `startswith` 前缀匹配 | 想省事匹配"同目录树" | **父目录有活 pi（/home/xieguiawu）→ 所有子目录 session 被误判"已恢复"而隐藏** | 改精确相等 `cwd in live` |
| A4 | 连坐 core 过滤只按日期字符串 | 用 `${CRASH_TS% *}` 取日期 | 把当天早先无关 core 也列为"连坐" | 改按 `%F %H:%M` 分钟级匹配 |
| A5 | `${LID:-默认值}` 里放 `'` + 全角括号 | 参数展开默认值内引号处理想当然 | bash -n 直接 EOF 报错；且 patch 后没重跑 `bash -n`，报错在 stderr 被误读为"语法 OK" | 拆开赋值 + 默认值去特殊字符；**验证看退出码/输出归属，别肉眼排输出顺序** |
| A6 | 孤儿检测初版写了嵌套 `ps -q "$(systemctl ... ; for p in /proc...)"` 怪物一行 | 想一行搞定 | 不可读、难调试 | 重写为"读 ControlGroup → 扫 /proc/*/cgroup"两步 |
| A7 | awk 三目 `print ... $0 ~ /Lid/ ? "x" : "y"` 优先级想当然 | awk 里 `?:` 与字符串拼接优先级 | 输出不确定 | 弃用 awk 改 python |

### B. 构建脚本 `sway-ime-fix-build.sh`（含用户实测踩中的两个）

| # | 问题 | 根因 | 影响 | 修复 |
|:--|:--|:--|:--|:--|
| B1 | `sudo bash --build` → 找不到 fork 仓库 /root/sway | 默认 `REPO=$HOME/sway`，sudo 下 `$HOME=/root` | 用户第一次 --build 直接失败 | `getent passwd ${SUDO_USER:-$USER}` 解析真实 HOME；root 下自动 `exec sudo -u 真实用户` 降权重跑 |
| B2 | `sudo --install` → meson 版本不兼容 | pip meson 1.11.1 在 user-site-packages，`/usr/bin/meson`（rpm 1.7.2）用户态被遮蔽显示 1.11.1，root 看不到用户 site → 回落 1.7.2 | 用户第二次 --install 在 `[312/313] Installing files` 后 abort | install 时从 `coredata.dat` 读出生成版本 → 给 root **注入用户 PYTHONPATH** 重放同一 meson → 仍不匹配则 reconfigure 兑底 |
| B3 | `--install` 初版只打印不执行 | 设计为"安全提示" | 用户 sudo 跑完以为装好了 | EUID==0 时直接执行（deps 同理） |
| B4 | `--check` 里 `rpm -q ... || echo` 输出两行、devel 缺失未置 fail | 没想清楚 stderr/stdout 与退出码 | 输出脏 + 校验继续跑 | `rpm -q --quiet` + `fail=1` |
| B5 | dry 模式 `do_build_fake(){...}; do_build_fake` | 图省事 | 可读性差（无功能 bug） | 记下待重构 |

### C. 流程性失误

| # | 问题 | 教训 |
|:--|:--|:--|
| C1 | `git worktree add <不存在的 v1.10.1 tag>` 失败后，同串 `git apply --check` 在**主仓库 master** 上打出 "APPLIES CLEAN" 假阳性 | worktree/checkout 后动作必须 `&&` 串联 + `rev-parse` 自证（见坑 #1） |
| C2 | 变更日志写 "triggers 14 个" 实际 13 个 | 数字写完要数一遍 |
| C3 | index.md 的 3.8 行一度插到 3.7 前面 | 改完要检查表格顺序 |

**核心共性**：①工具输出格式先验证再写解析器（A1/A7）；②同一路径/命令在不同身份（sudo、login shell、user-site）下行为不同（B1/B2）；③bash 引号/参数展开宁简勿繁（A5）；④`bash -n` 只验语法，行为验证必须实跑 + 看退出码（A5/C1）。

---

*最后更新: 2026-08-29（1.0.3：重启后验证新增「风暴密度判级」——稠密 >10/分=KMS 卡死需恢复，零星 <5/分=基线噪声无害；S3 唤醒把零星噪声放大成持续风暴）*
