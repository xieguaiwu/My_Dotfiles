---
name: bluetooth-pairing-troubleshoot
version: 1.2.0
description: 排查蓝牙耳机扫描不到、配对失败、连上无声音问题，覆盖适配器判活、USB 自动挂起修复、长扫描捕获配对窗口、非 tty 配对坑
triggers:
  - "蓝牙耳机连不上"
  - "蓝牙扫描不到"
  - "蓝牙配对失败"
  - "耳机连接电脑"
  - "蓝牙没声音"
  - "bluetoothctl"
inputs:
  - name: device_name
    description: 目标设备名称，如 HUAWEI FreeArc、AirPods Pro
    required: false
    default: ""
  - name: symptom
    description: '症状：扫描不到、配对失败、连上无声音'
    required: false
    default: "auto-detect"
tools:
  - bash
  - read
  - grep
  - ask_user
  - web_search
---

# 蓝牙设备连接排查与修复

## 任务目标

排查本机蓝牙适配器问题与目标设备配对失败，直至设备连接成功且音频链路可用。适用于「扫描不到耳机」「配对失败」「连上无声音」三类症状。2026-08-22 华为 FreeArc 配对实战沉淀。

## 执行流程

### 1. 适配器判活

先查服务与硬件，排除适配器层故障：

```bash
systemctl status bluetooth --no-pager | head -5
rfkill list
bluetoothctl list
lsusb | grep -i blue
```

判活标准：
- 服务 active、rfkill 无 blocked、控制器 Powered: yes → 适配器正常，进入步骤 2
- 任一不满足 → 按 system_diagnostics_and_repair.md 1.8 节处理

### 2. 检查 USB 自动挂起（Intel 蓝牙高发）

```bash
journalctl -k --grep='bluetooth|hci' -b --no-pager 2>/dev/null | grep -i 'fail\|error' | tail -10
lsusb | grep -i blue
for d in /sys/bus/usb/devices/*/; do
  grep -q 8087 "$d/idVendor" 2>/dev/null && { echo "$d"; cat "$d/power/control"; cat "$d/power/runtime_status"; }
done
```

判定：`power/control: auto` + `runtime_status: suspended` + 日志含 `Reading supported features failed (-16)` → USB 自动挂起故障。

修复（需 root）：

```bash
echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
sudo modprobe -r btusb && sudo modprobe btusb
```

注意：`usbcore` 参数重载 btusb 不回溯，**彻底生效须重启**；btusb 重载已可恢复扫描。agent 环境无 passwordless sudo 时，打包脚本交用户手动执行（参考 system_diagnostics_and_repair.md Phase 4）。

### 3. 确认目标设备进入配对模式

设备连接着手机/其他主机时**不会广播**，须先断开：
- 手机端：蓝牙设置中断开该设备，或直接关手机蓝牙
- 耳机端：查官方配对姿势（`web_search`「{品牌} {型号} 进入配对模式 指示灯」）。华为 FreeArc 实测：**双耳入盒 + 保持开盖 + 长按盒内功能键 2-5 秒 → 盒身白灯闪烁**（非长按耳机触控区）
- 配对窗口通常 1-2 分钟，超时自动退出

### 4. 长扫描捕获（关键）

短扫描（12-20 秒）极易错过配对窗口。用 60-100 秒长扫描：

```bash
timeout 100 bluetoothctl --timeout 100 scan on > /tmp/bt_scan.log 2>&1
grep -iE "NEW.*Device" /tmp/bt_scan.log | grep -i "目标名关键词"
```

要点：
- 启动扫描与提示用户按键**同时进行**——先启动扫描再发消息，用户操作耗时已计入窗口
- 目标名含空格（如 HUAWEI FreeArc）时，grep 用品牌关键词即可
- 华为 TWS 耳机用**随机 MAC**，OUI 查询无意义；名字是唯一线索

### 5. 缓存设备兜底检索

长扫描后仍无果，遍历缓存设备找音频类（Class 0x24xxxx）：

```bash
for mac in $(bluetoothctl devices | awk '{print $2}'); do
  info=$(bluetoothctl info "$mac" 2>/dev/null)
  echo "$info" | grep -qi "Class: 0x24" && echo "$mac $(echo "$info" | grep 'Name:' | head -1)"
done
```

### 6. 配对与连接

```bash
MAC=目标设备MAC
bluetoothctl pair "$MAC"        # 无 PIN 耳机自动完成
bluetoothctl trust "$MAC"
bluetoothctl connect "$MAC"
bluetoothctl info "$MAC" | grep -E "Paired|Trusted|Connected"
```

非 tty 坑：bluetoothctl 交互输出会被大量设备事件（[NEW]/[DEL]/[CHG]）刷屏，命令看似挂起。对策：
- 每条命令包 `timeout`（pair 30s / connect 30s）
- 输出经 `grep -vE "^\["` 过滤事件行
- 状态以 `bluetoothctl info` 为准，不以命令回显为准

### 7. 音频链路验证与切换

```bash
pactl list sinks short | grep bluez
```

- 出现 `bluez_output.<MAC>.1` 即链路就绪
- State: SUSPENDED 属正常（无播放时挂起），播放时自动转 RUNNING

**连接成功 ≠ 声音从耳机出**：默认输出仍可能是内置扬声器。须显式切换：

```bash
BT=bluez_output.30_96_10_FD_B6_88.1
pactl set-default-sink $BT        # 设默认输出为耳机
for id in $(pactl list sink-inputs short | awk '{print $1}'); do
  pactl move-sink-input $id $BT   # 现有播放流移至耳机
done
pactl get-default-sink            # 验证
```

切换后确认流路由：`pactl list sink-inputs` 的 Sink 编号应等于 `pactl list sinks short` 中 bluez 行首编号。

## 输出格式

按状态汇报：

```
## 蓝牙排查结果
- 适配器：正常 / 已修复（描述）
- 目标设备：已找到（MAC、名称）/ 未找到（原因）
- 配对状态：Paired / Trusted / Connected
- 音频链路：bluez_output.<MAC>.1 就绪
- 默认输出：已切换至耳机（pactl get-default-sink 验证）
- 遗留事项：如「usbcore 修复需重启彻底生效」
```

## 注意事项

1. **root 限制**：agent 环境无 passwordless sudo 时，root 命令打包脚本（存 ~/Downloads/）交用户手动执行
2. **配对窗口短暂**：先启动长扫描再让用户按键，勿先问后扫——问答往返耗时已超窗口
3. **设备连着手机必不广播**：先断手机再配对
4. **配对姿势因型号而异**：不确定时 web_search 官方说明，勿凭经验指导（FreeArc 是盒内功能键，非耳机触控区）
5. **usbcore 参数重启生效**：modprobe.d 写入后当前会话仅 btusb 重载有效，建议用户近期重启
6. **勿误判适配器故障**：扫描能看到大量其他设备 ≠ 适配器坏，问题在目标设备未广播
7. **排除其他系统残留**：若扫描始终无果且步骤 4/5 均失败，检查手机端是否仍连着该设备（回连竞态）
8. **默认输出未切**：连接成功但播放仍走扬声器是最高频现象，步骤 7 的 set-default-sink + move-sink-input 必须执行，勿只验证链路存在

## 日常使用与维护

连接成功后的日常操作要点（2026-08-22 本机实测）：

### 自动重连
- Trusted 设备开机/唤醒时 bluetoothd 自动重连，通常无需干预
- 未自动连上时手动：`bluetoothctl connect <MAC>`，随后 `pactl list sinks short | grep bluez` 验链路
- 睡眠唤醒后偶发失联：先 connect 再查 sink，勿重配对

### 电量查看
- `bluetoothctl info <MAC>` → Battery Percentage 字段（实测 FreeArc 0x32 = 50%）
- upower 未必暴露蓝牙设备（本机无），勿依赖 upower

### 音质与模式
- 音乐播放：A2DP，AAC 优先（实测 Active Profile: a2dp-sink）
- 通话/麦克风：自动切 HSP/HFP（mSBC），降为单声道低音质，通话结束恢复
- 音质突然变差：先查 Active Profile 是否被切至 headset-head-unit

### 多设备切换
- FreeArc 支持双设备连接；手机连着时电脑可能连接失败或播放无声
- 切换法：手机端断开该设备，或电脑端 `bluetoothctl disconnect <MAC>` 后重新 connect

### GUI 管理
- blueman-applet 托盘（本机常驻）可查设备状态、断开/重连，适合非 CLI 场景

## 变更日志

### 1.2.0 (2026-08-22)
- 新增：「日常使用与维护」章节——自动重连（trusted 开机自动连、唤醒失联先 connect 勿重配对）、电量查看（bluetoothctl info Battery Percentage，upower 本机无）、音质模式（A2DP AAC 优先 vs HSP/HFP mSBC 通话降质）、多设备切换（双连接、手机抢占处理）、blueman GUI
- 背景：本机实测 FreeArc 电量 0x32 = 50%、Active Profile a2dp-sink AAC 优先

### 1.1.0 (2026-08-22)
- 扩充：步骤 7 新增「连接成功 ≠ 声音从耳机出」——默认输出切换（pactl set-default-sink + move-sink-input + 流路由验证），实战中播放流仍指向内置扬声器
- 补充：注意事项第 8 条（默认输出未切为最高频现象）

### 1.0.0 (2026-08-22)
- 初始发布：2026-08-22 华为 FreeArc 配对实战沉淀——适配器正常但 12-20 秒短扫描 4 次全空，100 秒长扫描捕获；Intel 蓝牙 USB autosuspend（-16 EBUSY）修复；随机 MAC 设备以名字为线索；非 tty 下 bluetoothctl 事件刷屏对策
