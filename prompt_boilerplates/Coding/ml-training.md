---
name: ml-training
version: 1.0.0
description: 在远程服务器上进行机器学习训练任务的完整方法论——从环境检查、烟雾测试、训练监控到结果验证的全流程
triggers:
  - "训练模型"
  - "跑训练"
  - "远程训练"
  - "ML训练"
  - "GPU训练"
  - "启动训练"
  - "模型训练"
inputs:
  - name: server
    description: 服务器地址 (user@host:port 或 ssh alias)
    required: false
    default: "从上下文推断"
  - name: train_command
    description: 训练命令或脚本路径
    required: false
    default: "从上下文推断"
  - name: gpu_id
    description: 指定GPU编号 (0/1/2...)
    required: false
    default: "0"
  - name: steps
    description: 目标训练步数
    required: false
    default: "500"
tools:
  - bash
  - read
  - write
  - edit
  - web_search
---

# ML 训练方法论

## 任务目标

在远程服务器上可靠地执行机器学习训练任务，避免资源竞争、静默失败、输出缓冲、NaN爆炸等常见陷阱。本 skill 总结了实际项目中反复遇到的训练事故及修复方法。

## 前置检查清单（训练前必须完成）

在启动任何训练之前，逐项检查：

### 1. 服务器资源检查

```bash
# 必须检查的项目
ssh user@server "
  echo '=== GPU ===' && nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader
  echo '=== RAM ===' && free -h | head -2
  echo '=== DISK ===' && df -h / | tail -2
  echo '=== RUNNING TRAINING ===' && ps aux | grep -E 'python.*train|python.*watchdog' | grep -v grep | head -10
"
```

**判断标准**：
- 目标 GPU 显存占用 < 2GB 且利用率 < 30% → 可用
- 该 GPU 上无其他用户的训练进程 → 可用
- RAM 空闲 > 数据集大小 × 3 → 安全
- 磁盘空闲 > 10GB → 安全

### 2. 环境验证

```bash
# 验证 Python 和关键包
ssh user@server "
  CUDA_VISIBLE_DEVICES={gpu_id} python3 -c '
import torch; print(f\"GPU: {torch.cuda.is_available()}, device: {torch.cuda.get_device_name(0)}\")
import numpy; print(f\"NumPy: {numpy.__version__}\")
import sklearn; print(f\"sklearn: {sklearn.__version__}\")
'
"
```

### 3. 数据验证

```bash
# 检查数据是否存在、形状是否合理、是否有 NaN/Inf
ssh user@server "
  python3 -c '
import numpy as np
data = np.load(\"/path/to/data.npz\")
for k in data.files:
    arr = data[k]
    nan_cnt = np.isnan(arr).sum()
    inf_cnt = np.isinf(arr).sum()
    print(f\"{k}: shape={arr.shape}, NaN={nan_cnt}, Inf={inf_cnt}, range=[{np.nanmin(arr):.4f}, {np.nanmax(arr):.4f}]\")
'
"
```

### 4. 特征完整性检查

```bash
# 检查特征之间是否存在完全重复（相关系数=1.0）——这是常见bug
python3 -c '
import numpy as np
from scipy.stats import spearmanr
feats = data["features"]  # (D, S, N) or (D, N)
for i in range(feats.shape[-1]):
    for j in range(i+1, feats.shape[-1]):
        fi = feats[..., i].ravel()
        fj = feats[..., j].ravel()
        valid = ~(np.isnan(fi) | np.isnan(fj))
        if valid.sum() > 100:
            corr = spearmanr(fi[valid], fj[valid])[0]
            if abs(corr) > 0.999:
                print(f"⚠️  DUPLICATE: feature[{i}] vs feature[{j}], corr={corr:.6f}")
'
```

---

## 执行流程

### Step 1：烟雾测试（10 步，强制）

**绝不跳过这一步。** 完整训练前必须先跑 10 步验证：

```bash
ssh user@server "
  cd /path/to/project
  CUDA_VISIBLE_DEVICES={gpu_id} PYTHONUNBUFFERED=1 python3 -u train_script.py \
    --steps 10 --device cuda:0 --output /tmp/smoke_test 2>&1 | tee /tmp/smoke.log
"
```

**烟雾测试通过标准**：
- [ ] 所有 10 步均完成（日志中有完整 Step 1/10 → Step 10/10）
- [ ] 无 `All-NaN slice` 警告（如果有，说明数据有问题）
- [ ] 无 `overflow in multiply` 警告（如果有，说明特征值域异常）
- [ ] 无 `ConstantInputWarning`（如果有，说明某些特征全是常数）
- [ ] Best score 在合理范围内（非 NaN、非 -inf）
- [ ] 单步耗时 < 预期值 × 3（如果通常 10s/步，烟雾测试应 < 30s/步）

**烟雾测试失败的处理**：

| 警告类型 | 含义 | 修复 |
|:---|:---|:---|
| `All-NaN slice` | 某个维度全部为 NaN，中位数无法计算 | 检查 `np.nanmedian(tgt_np, axis=1)` ——目标的 axis=1 方向是否全 NaN |
| `overflow in multiply` | 特征值域极大（>1e15），平方后溢出 | 对特征做 `np.clip(x, -10, 10)` 或 winsorize |
| `ConstantInputWarning` | spearmanr 输入全是同一个值 | 对特征加 1e-8 微小噪声，或过滤掉常数特征 |
| 单步耗时暴涨（>3×） | 模型陷入超长公式生成（GATE 嵌套过多） | 限制最大 token 数、惩罚 GATE 数量 |

### Step 2：GPU 隔离（防止资源竞争）

```bash
# 绝对不要用默认 GPU。始终显式指定：
CUDA_VISIBLE_DEVICES={gpu_id} python3 -u train.py --device cuda:0
#                                                           ^^^^^^^^
# 注意: --device 中的编号是 CUDA_VISIBLE_DEVICES 过滤后的编号
# CUDA_VISIBLE_DEVICES=1 python3 --device cuda:0 → 实际使用物理 GPU 1
```

**验证隔离生效**：

```bash
# 训练启动后立即验证
ssh user@server "
  sleep 10
  nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
  # 目标GPU的显存应该增加了，utilization应该上升
"
```

### Step 3：监控双通道

只靠 nohup 日志是不够的——输出缓冲会导致日志延迟数小时。必须建立双通道监控：

**通道 1：日志尾部（看进度）**

```bash
ssh user@server "tail -5 /path/to/train.log"
```

**通道 2：进程状态（看死活）**

```bash
ssh user@server "ps -p {pid} -o pid,etime,pcpu,pmem,comm= 2>/dev/null || echo 'DEAD'"
```

**判断训练卡死的信号**（三者全部满足=进程卡死）：
- CPU 使用率 > 50% 但已运行时间远超预期（如预期 30 分钟但运行 2 小时）
- 日志 30 分钟以上无新输出
- 日志尾部始终是同一行警告反复打印

### Step 4：输出缓冲强制关闭

Python 默认会缓冲 piped/file 输出。在服务器训练中**必须**强制关闭：

```bash
# ✅ 正确：三重防护
PYTHONUNBUFFERED=1 python3 -u train.py > log.txt 2>&1

# 或者
stdbuf -oL python3 train.py > log.txt 2>&1

# ❌ 错误：默认缓冲，日志可能延迟数小时
python3 train.py > log.txt 2>&1
nohup python3 train.py &  # nohup 不解决缓冲问题！
```

### Step 5：日志频率

**开发/调试阶段**：每步打印
```python
print(f"Step {step+1}/{total} | reward={reward:.4f} | time={elapsed:.1f}s")
```

**生产阶段**：每 50 步 + 关键事件打印
```python
if step % 50 == 0 or step == 0 or (best_score - prev_best) > 0.01:
    print(f"Step {step:4d}/{total} | Best: {best_score:.4f}")
```

### Step 6：训练异常恢复

当训练卡死时，不要无限等待。按以下流程处理：

1. **记录卡死位置**：最后一行日志在哪个 Step
2. **检查 GPU 显存**：是否有内存泄漏（显存持续增长）
3. **检查系统日志**：`dmesg | tail -20` 看是否有 OOM killer
4. **清理残留**：`kill -9 {pid}` 确保进程完全终止
5. **缩小规模重试**：batch_size 减半、steps 减半、或改用 CPU

---

## 常见训练事故模式

### 模式 A：Step 1 完成后永久沉默

```
Step    1/500  |  AvgRew: -1.7882  ...  |  9.1s
（30分钟后仍无 Step 2 输出）
```

**根因**：Step 2 的模型生成了极端长公式（大量 GATE 嵌套），StackVM 执行时间指数级增长；或者 scorer 在特定形状的 factor 上陷入死循环。

**修复**：
1. 杀掉进程，限制 `--max-tokens 15`
2. 在 scorer 中加入超时保护：`if time.time() - t0 > 30: return -1.0`
3. 对 Step 2 加保护：前几步用更小的 batch_size

### 模式 B：GPU 跑了但用错卡

```
nvidia-smi:
  0, 5540 MiB, 94%   ← 训练跑到了别人占用的卡上
  1, 1301 MiB, 17%   ← 目标卡空闲
```

**根因**：`--device cuda:0` 没配合 `CUDA_VISIBLE_DEVICES` 一起用。

**修复**：
```bash
CUDA_VISIBLE_DEVICES=1 python3 train.py --device cuda:0
```

### 模式 C：特征名误导——"基差"实为均价偏离的复制品

```python
# ❌ 假特征：basis_proxy 是 sma_20_bias 的复制品
F[:, 23] = F[:, 3].copy()  # alias of sma_20_bias as basis proxy

# ✅ 真特征：从期货价格和标的指数计算真实基差
F[:, 23] = futures_close / index_close - 1.0
```

**检测方法**：特征相关性矩阵中 r=1.000 的列对——必有一个是复制品。

### 模式 D：时序泄漏——update 先于 fuse

```python
# ❌ 泄漏：用今天实际收益更新权重，再融合今天预测
mg.update(ep, actual)    # 15% 权重来自同一天未来信息
fused = mg.fuse(ep)

# ✅ 正确：先用旧权重融合，再更新
fused = mg.fuse(ep)
mg.update(ep, actual)
```

**影响**：IC 虚高 30-75%，胜率虚高至不可能值（100%）。检测方法：如果某模型声称 34/34 窗口全部正 IC，一定是泄漏。

### 模式 E：scp 传输截断

```bash
# scp 在慢/不稳定连接中可能静默截断大文件
sshpass -p 'pwd' scp server:/large_file.tar.gz .
ls -lh large_file.tar.gz  # 显示 428MB，但服务器上是 2.1GB！
```

**修复**：
```bash
# 用 rsync 替代，支持断点续传
rsync -avz --partial -e 'ssh -p PORT' server:/large_file.tar.gz .
# 传输完成后验证
ssh server "md5sum /large_file.tar.gz" && md5sum large_file.tar.gz
```

---

## 显著性检验规范

训练完成后，验证信号显著性**必须**使用以下方法（按可信度排序）：

### 1. 非重叠全局置换检验（金标准）

```python
# 正确做法
def permutation_test(X, y, n_perm=2000):
    rng = np.random.default_rng(42)
    perm_means = []
    for _ in range(n_perm):
        y_perm = rng.permutation(y)  # 全局打乱目标
        # 用和真实训练完全相同的 walk-forward pipeline 重跑
        perm_ics = []
        for train, val in non_overlapping_windows:
            model = Ridge(alpha=1.0).fit(X[train], y_perm[train])
            pred = model.predict(X[val])
            perm_ics.append(spearmanr(pred, y_perm[val])[0])
        perm_means.append(np.mean(perm_ics))
    pctile = percentileofscore(np.abs(perm_means), np.abs(true_mean))
    return 1.0 - pctile / 100.0  # p-value
```

### 2. 要求

- **窗口数 ≥ 15**：非重叠 (STEP = VAL_LEN)，避免重叠窗口膨胀 p 值
- **置换次数 ≥ 2000**：p < 0.0005 是最小分辨率
- **报告两个 IC**：窗口均值 IC（用于统计检验）**和** pooled IC（用于经济评估），缺一不可

### 3. 不可用的检验

| 方法 | 问题 |
|:---|:---|
| t-test（窗口 IC） | 训练窗口重叠 → 窗口 IC 非独立 → t 值被高估 ~6× |
| binomial test | 同上，独立性假设不成立 |
| block-bootstrap（单因子） | 测试因子稳定性，不是模型 OOS 性能 |
| p=0.40 用于 Ridge 基线 | 该 p 值测的可能是另一个模型（RL 公式），不是 Ridge |

---

## 输出格式

训练完成后，必须报告以下指标：

```
━━━ 训练结果 ━━━
模型: {model_name}
数据: {dataset_shape}, {n_stocks} stocks, {n_days} days
窗口: {n_windows} non-overlapping, STEP={step}, VAL={val_len}
设备: {device}, 耗时: {total_time}

信号质量:
  窗口均值 IC: {mean_ic:+.4f} ± {std_ic:.4f} (中位数: {median_ic:+.4f})
  Pooled IC:   {pooled_ic:+.4f}
  IC Sharpe:   {ic_sharpe:.2f}
  胜率:        {win_rate:.1%} ({n_pos}/{n_total})
  
显著性检验 ({n_perm} 次置换):
  真实 IC:     {true_ic:+.4f}
  零分布均值:  {null_mean:+.4f} ± {null_std:.4f}
  零分布 95%:  {null_p95:.4f}
  p-value:     {p_value:.4f}
  判定:        {verdict}

行动建议:
  {recommendation}
```

---

## 注意事项

1. **GPU 训练前永远先跑 10 步烟雾测试**。跳过此步导致的问题占所有训练事故的 80%。
2. **永远报告两个 IC**：窗口均值 IC 和 pooled IC。只报一个 = 选择性报告。
3. **服务器文件传输后用 md5sum 验证**。scp 静默截断是最常见的静默数据损坏。
4. **CUDA_VISIBLE_DEVICES + --device 一起用**。只用其中一个 = 可能在错误 GPU 上跑。
5. **时间序列数据绝不用全局随机 split**。只用 walk-forward 时序分割。
6. **检查特征间相关系数 > 0.999**。如果有，必有一个是复制品 bug。
7. **mg.update() 必须在 mg.fuse() 之后调用**。顺序反了 = 前瞻泄漏。
8. **Python 训练脚本必须加 -u 标志 + PYTHONUNBUFFERED=1**。否则日志延迟数小时。
9. **前向填充停牌股价格 = 人为制造可预测零收益**。用 NaN + is_suspended 标记代替。
10. **`nohup` 不解决缓冲问题**。`nohup` 只是防止 hangup signal，和输出缓冲无关。

---

## 补充模式（2026-07-12 训练事故总结）

### 模式 F：显著性检验用错模型

```python
# ❌ p=0.40 是对 RL 公式做的 block-bootstrap 检验
# 但报告说"期货 Ridge 基线 p=0.40 不显著"——偷换了检验对象

# ✅ 正确的显著性检验必须对目标模型本身做
# Ridge 基线的 permutation test：全局 y-shuffle + 重跑 walk-forward
# 结果：p<0.0005（18 非重叠窗，2000 次置换）
```

**核心教训**：永远确认 p 值的检验对象和被报告的模型是同一个。跨模型引用 p 值是常见的论证错误。

### 模式 G：update-before-fuse 前瞻泄漏

```python
# ❌ 泄漏：用今天实际收益更新权重，再融合今天预测
mg.update(ep, actual)    # EMA_ic = 0.15 * IC_today + 0.85 * EMA_ic
fused = mg.fuse(ep)      # 15% 的融合权重来自同一天未来信息

# ✅ 正确：先用旧权重融合，再更新
fused = mg.fuse(ep)       # 权重不含今天信息
mg.update(ep, actual)     # 更新权重，供明天使用
```

**影响量化**：IC 被虚高 30-75%，胜率可达到不可信的 100%（34/34 窗）。检测方法：如果某个 ensemble 声称所有窗口 IC 为正（p < 10⁻¹⁰），一定是泄漏。一行代码顺序的代价。

### 模式 H：Python 输出缓冲的三重陷阱

```bash
# ❌ 仅 nohup 不够——nohup 防止 SIGHUP，但输出仍被缓冲
nohup python3 train.py > log &  # 日志可能延迟数小时

# ✅ 正确：三重防护
PYTHONUNBUFFERED=1 nohup python3 -u train.py > log 2>&1 &
# ^^^^^^^^^^^^^^^^^ 环境变量      ^^ 二进制无缓冲
```

**诊断流程**：进程 CPU 高但日志无输出 → 先检查是否缓冲，而非假设代码卡死。80% 的"训练卡死"报警其实是缓冲延迟。

### 模式 I：per-sample 重计算——共享计算未提取

```python
# ❌ 每个公式独立做相同的 1D reduction
for formula in batch:  # 200 次
    r_1d = np.nanmedian(tgt_np, axis=1)  # 2782×498 矩阵, 每公式重复

# ✅ 提取到循环外，只做一次
r_1d = np.nanmedian(tgt_np, axis=1)  # 每步 1 次
for formula in batch:
    # 只做公式自己的 f_1d + 3 次 spearmanr
```

**影响量化**：200 个公式 × 2782×498 nanmedian = ~280M 次无效计算，导致每步耗时从 9s 暴涨到 >60s。

### 模式 J：特征定义假——三个子类型

| 子类型 | 例子 | 检测 |
|:---|:---|:---|
| 名称假 | `basis_proxy` = `sma_20_bias.copy()` | 特征相关矩阵 r=1.000 |
| 定义假 | 停牌股前向填充 → 人为零收益 | 连续 N 天收益为 0 |
| 范围假 | ST 股涨跌停用 10% 代替 5% | 接近限制的分布偏斜 |

### 模式 K：GPU 用错卡

```bash
# ❌ --device cuda:0 没配合 CUDA_VISIBLE_DEVICES
python3 train.py --device cuda:0  # 跑到了物理 GPU 0（别人占用的）

# ✅ 必须成对使用
CUDA_VISIBLE_DEVICES=1 python3 train.py --device cuda:0  # 跑物理 GPU 1
```

**验证**：训练启动后立即 `nvidia-smi` 确认目标 GPU 显存增加。

### 模式 L：scp 静默截断

```bash
# scp 超时后留下不完整文件，无任何警告
-rw-r--r-- 428M large.tar.gz  # 本地显示 428MB
-rw-r--r-- 2.1G large.tar.gz  # 服务器实际 2.1GB
```

**修复**：永远用 `rsync --partial` + 事后 md5 验证。
