# TLP 使用说明（ThinkPad X1 Carbon 5th / Fedora）

> 2026-08-02 备份。TLP = Linux 笔记本电源管理守护进程（省电 + 电池保护）。
> 本机 /etc/tlp.conf 为出厂默认（580 行全注释），如日后定制请同步更新本目录备份。

## 一、安装与启用

```bash
sudo dnf install tlp tlp-rdw
sudo systemctl enable --now tlp
sudo systemctl disable tuned    # 与 tuned 二选一（两者都管 CPU governor，会打架）
```

## 二、常用命令

| 命令 | 用途 |
|---|---|
| `tlp-stat -s` | 状态（enabled / 当前模式 AC或BAT） |
| `tlp-stat -p` | CPU 调频/EPP/boost 生效值 |
| `sudo tlp-stat -b` | 电池健康 + 充电阈值 |
| `sudo tlp start` | 手动重应用配置 |
| `/usr/sbin/tlp` | TLP 主程序（在 /usr/sbin，普通 PATH 找不到） |

## 三、调 performance（性能模式）——可以，推荐 AC/电池分离

TLP 支持插电/电池两套策略，在 `/etc/tlp.conf` 中取消注释并修改：

```ini
# 插电用性能（全速），电池用省电 —— 最优折中
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# 插电开 turbo，电池关 turbo（省电）
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# EPP：插电性能优先，电池省电
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
```

改完执行 `sudo tlp start` 生效。验证：`tlp-stat -p`。

- 临时手动切（会被 TLP 事件覆盖）：`sudo cpupower frequency-set -g performance`
- TLP 默认已允许插电 boost，电池模式自动限制 —— 不配置也不会损失插电性能

## 四、充电阈值（替代 scripts/setup_charging_threshold.sh）

ThinkPad 原生支持，`/etc/tlp.conf`：

```ini
START_CHARGE_THRESH_BAT0=40    # 低于 40% 开始充
STOP_CHARGE_THRESH_BAT0=80     # 充到 80% 停止（延长电池寿命）
```

验证：`sudo tlp-stat -b`。日常通勤 80% 停充即可，长途出行前临时改回 100%。

## 五、注意事项

- 已知兼容坑：个别 USB 声卡/DAC 掉线、蓝牙鼠标延迟 → 用 TLP 配置项排除
- 出问题回滚：`sudo systemctl enable --now tuned && sudo systemctl disable --now tlp`
- 2026-08-02 实测：启用后 governor 从 performance(3500MHz 恒满) → powersave(900MHz idle)，风扇 5000+ RPM → 0，温度 72°C → ~50°C 区间
