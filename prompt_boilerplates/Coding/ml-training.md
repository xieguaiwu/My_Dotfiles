---
name: ml-training
version: 1.4.0
description: 在远程服务器上进行机器学习训练任务的完整方法论——从环境检查、烟雾测试、看门狗自动化、训练监控、可视化诊断到结果验证的全流程
triggers:
  - "训练模型"
  - "跑训练"
  - "远程训练"
  - "ML训练"
  - "GPU训练"
  - "启动训练"
  - "模型训练"
  - "看门狗"
  - "watchdog"
  - "自动化训练"
  - "多领域训练"
  - "并行训练"
  - "训练可视化"
  - "训练图"
  - "loss曲线"
  - "plot"
  - "可视化诊断"
  - "训练仪表板"
  - "dashboard"
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

## 第零步：了解项目（训练前必须完成）

**在动手做任何事之前，先搞清楚项目当前处于什么状态。**

很多训练事故的根因不是技术问题，而是 Agent 不了解项目背景就动手——
重复已完成的训练、用已推翻的结论做决策、在已关闭的方向上浪费时间。

### 0.1 阅读哪些文档

进入新项目后，按以下顺序阅读：

| 顺序 | 文档 | 获取的信息 |
|:---:|:---|---|
| 1 | **CONTEXT_FOR_NEXT_AGENT.md**（如存在） | 项目当前状态、最后完成的训练、待办问题、服务器信息 |
| 2 | **FALSIFICATION_SUMMARY.md**（如存在） | 哪些方向/结论已被推翻，哪些不可信，哪些不必再试 |
| 3 | **FINAL_HONEST_ASSESSMENT.md**（如存在） | 诚实评估——哪个方向是真实的、哪个是疑似噪音 |
| 4 | **GOAL.md**（如存在） | 项目目标和当前 Phase |
| 5 | **ASSET_INVENTORY.md**（如存在） | 目录结构、文件用途、服务器列表 |
| 6 | 最近的 daily log / scratchpad | 上一个 Agent 在做什么、是否还有训练在运行 |

**如果你不知道项目当前在哪，后面的所有决策都是盲目的。**

### 0.2 检查服务器状态

阅读本地文档后，立即检查服务器实际状态——文档可能过期：

```bash
# 1. 服务器还能登录吗？密码和端口是否变了？
ssh user@server "echo OK"

# 2. GPU 上有什么在跑？
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader

# 3. 有没有训练还在运行？
ps aux | grep -E 'python.*train|python.*watchdog' | grep -v grep

# 4. 结果目录里有什么？
ls -lt /path/to/results/ | head -20
```

**文档说的 ≠ 服务器实际有的。** 服务器可能重启过、进程可能崩溃过、
其他用户可能占了 GPU。永远用 SSH 确认实际状态。

### 0.3 确定当前行动优先级

阅读文档和检查服务器后，确定你该做什么：

| 情形 | 优先级行动 |
|:---|---|
| 有训练在运行 | 先等它完成，不要抢 GPU |
| 文档说了待办清单 | 按优先级从高到低执行 |
| 文档和服务器状态不一致 | 先验证再动手——密码/端口可能已变 |
| 文档说某方向已关闭 | **不要重复测试**——先看 FALSIFICATION_SUMMARY 确认关闭原因 |
| 文档说某结论已被推翻 | 说明之前有错误，需要全面理解后才行动 |

### 0.4 常见陷阱

- **陷阱 1**：读了 CONTEXT_FOR_NEXT_AGENT.md 但没读 FALSIFICATION_SUMMARY.md → 在已推翻的结论上浪费时间
- **陷阱 2**：文档写的密码无法登录 → 立即检查服务器实际状态，更新文档
- **陷阱 3**：假设 GPU 是空闲的 → 登录服务器确认（`nvidia-smi`），文档可能几小时前写的
- **陷阱 4**：假设上一个 Agent 都做对了 → 验证关键结果（IC 值、置换检验、成本模型）
- **陷阱 5**：直接开始训练而不先检查数据 → 数据路径可能变了、文件可能被删了

### 0.5 输出：执行摘要

完成以上所有步骤后，在执行任何训练之前，先输出一份简短的执行摘要：

```
━━━ 项目状态摘要（训练前）━━━
服务器: user@host:port（密码已验证 ✅）
GPU:    0 (空闲) / 1 (空闲)
文档最后更新: YYYY-MM-DD

项目当前方向（按优先级）:
  P0: SGX Z74 — 信噪比最高，最接近实盘
  P1: 期货 AlphaGPT — 信号真但需 walkforward
  ❌ 已推翻: 美股 35 特征选股、SGX 配对交易

本次计划:
  1. 检查 Z74 RL 训练结果
  2. 如果已完成：读取 results.json，更新文档
  3. 如果未完成：等待或排查问题
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**读完文档、查完服务器、确定优先级之后，才能进入前置检查清单。**

---

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

### Step 7：文档更新（强制）

训练**不是**终点。结果被记录在项目文档中才算一次完整的训练循环。**不更新文档的训练等于没跑**——后续 Agent 无从知晓你的发现。

#### 7.1 必须更新的文档

训练完成后，根据改动范围更新以下文档：

| 文档 | 更新条件 | 更新内容 |
|:---|:---|---|
| **CONTEXT_FOR_NEXT_AGENT.md** | **每次训练后** | 最新结果、服务器状态、修复列表、未完成问题 |
| **实验记录/训练日志** | **每次训练后** | 配置、IC、耗时、最佳公式（追加到表格） |
| **ASSET_INVENTORY.md** | 新增/删除模块 | 目录变动、数据文件、服务器信息 |
| **特征文档** | 特征增删改 | 特征名、定义、计算方式 |
| **证伪文档**（FALSIFICATION_SUMMARY.md） | 结论变更 | 修正过时结论、添加新证伪 |

#### 7.2 文档漂移检测

训练过程中经常发现代码 bug 或文档错误。每次训练后，检查**文档声明 vs 实际代码**的一致性：

```bash
# 检查特征数是否一致
DOC_FEATURES=24
CODE_FEATURES=$(grep -c 'F\[.*,\s*[0-9]' features.py)
echo "文档声称: $DOC_FEATURES, 代码实际: $CODE_FEATURES"

# 检查 IC 值是否匹配
cat results/latest.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('实际IC:', d['true_ic']['mean'])"
```

#### 7.3 常见文档漂移模式

| 模式 | 表现 | 修复 |
|:---|:---|---|
| **特征数撒谎** | docstring 写 24，实际 feats.append 只有 22 | 导入生产特征函数，删重复代码 |
| **IC 值过期** | 文档写着 IC=0.160，服务器 json 是 0.090 | 每次重跑后更新文档 |
| **结论过度概括** | "所有方向均已证伪"（实际期货有信号） | 区分市场、区分模型精准表述 |
| **密码过期** | 文档密码无法登录服务器 | 使用前 SSH 验证密码 |
| **代码声称已修复** | "✅ P0 已修复"但实际还是旧代码 | 修复后 md5sum 验证服务器文件 |

#### 7.4 更新频率

```yaml
每次单次训练后:
  - 追加一行到实验记录表（配置、IC、耗时）
  - 更新 CONTEXT_FOR_NEXT_AGENT.md 的训练状态

每次多次训练/修复后:
  - 全部重写 CONTEXT_FOR_NEXT_AGENT.md（替换旧结果）
  - 更新 ASSET_INVENTORY.md（如目录变动）
  - 更新 FALSIFICATION_SUMMARY.md（如结论变动）

每次架构变更后:
  - 全部核心文档审查
  - 运行文档 vs 代码一致性检查
```

---

## 常见训练事故模式

> 下面每个模式都有对应的 **视觉故障签名**（见 §【训练可视化】 → “四、常见视觉故障签名”）。
> 看图配文字诊断效果远优于单看日志。例如模式 A“永久沉默” → `gpu_timeline_final.png` 上表现为“GPU 心电图”（util 紧贴 0 后过田上升）。使用时先看日志找模式号、再以对应图符号快速定位。

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

## 训练生命周期完整性检查（新增）

每次训练循环结束后，必须对三个维度进行完整性检查，确保训练闭环没有漏洞：

```
训练循环完整性:
  ✅ 环境检查 ← 烟雾测试 ← 训练执行 ← 结果保存
  ↓                                            ↓
  ✅ 文档更新 ← 结果验证 ← 跨方法复现 ← 幻觉检测
  ↓
  ✅ 下一位 Agent 可以无缝接手
```

### 维度一：训练数据真实性验证

训练数据中的常见"幻觉"不是 AI 编造——而是代码 bug 静默地制造了虚假信号：

| 虚假信号类型 | 表现 | 检测方法 |
|:---|---|:---|
| **特征复制** | `feature[i]` = `feature[j].copy()`，r=1.000 | 特征相关矩阵检查 |
| **前瞻特征** | 用 `np.roll()` 代替 `shift()`，未来数据回绕到位置 0 | 检查首行是否是最后一个样本 |
| **泄漏特征** | `basis_proxy` = `sma_20_bias.copy()` 但被称为"基差" | 特征名 vs 定义一致性检查 |
| **停牌填充** | 停牌日向前填充价格 → 人为制造零收益预测信号 | 检查连续 N 天收益完全相同的股票 |
| **update-before-fuse** | 融合前用当日收益更新权重 | `grep -n 'update.*fuse\|fuse.*update'` 顺序检查 |

**防火墙：代码定义 vs 文档声明一致性检查**

```bash
# 检查特征数是否一致
DOC_FEATURES=24
CODE_FEATURES=$(grep -c 'feats\.append\|F\[.*,[0-9]' features.py)
echo "⚠️  文档: $DOC_FEATURES 特征, 代码: $CODE_FEATURES 特征"

# 检查特征相关矩阵是否有 r>0.999 的完美复制
python3 -c '
import numpy as np; from scipy.stats import spearmanr
for i in range(F.shape[-1]):
    for j in range(i+1, F.shape[-1]):
        r, _ = spearmanr(F[..., i].ravel(), F[..., j].ravel())
        if abs(r) > 0.999: print(f"🔥 复制品: feature[{i}] vs [{j}], r={r:.6f}")
'

# 检查 np.roll 回绕（每行第一个元素 = 最后一个样本）
for fname, expr in [("momentum_5d", "np.roll(c, 5)"), ("oi_change", "np.roll(oi, 1)")]:
    first_val = ...  # X[0, feat_idx]
    last_val  = ...  # X[-1, feat_idx]
    if abs(first_val - last_val) < 1e-6:
        print(f"🔥 前瞻污染: {fname} 首行=末行（np.roll 回绕）")
```

### 维度二：训练结果幻觉检测

训练结果可能被多种因素污染。训练完成后必须逐项检查：

#### 2.1 过拟合间隙检查

```python
# Quick score vs Full IC 的差距是过拟合的量化指标
gap = best_quick_score - best_full_ic
if gap > 0.5 * best_full_ic:
    print(f"🔥 严重过拟合: quick={best_quick_score:.3f}, full={best_full_ic:.3f}, 退化率={gap/best_quick_score:.1%}")
elif gap > 0.3 * best_full_ic:
    print(f"⚠️  中度过拟合: 退化率={gap/best_quick_score:.1%}")
else:
    print(f"✅ 泛化良好: 退化率={gap/best_quick_score:.1%}")
```

**经验阈值**（基于 2026-07-12 期货三版实验）：

| 退化率 | 含义 | 示例 |
|:---:|---|---|
| < 35% | 泛化良好 | v2 (500步) 退化率 33% |
| 35-60% | 中度过拟合，仍可接受 | v1 (200步) 退化率 48% |
| > 60% | **严重模式坍塌** | v3 (1000步) 退化率 77% |

#### 2.2 模式坍塌检测

当训练步数过长时，策略可能收敛到单一特征家族的等价变体：

```python
# 检查 top-K 公式是否有数学等价的变体
def detect_collapse(formulas, ic_threshold=0.0):
    """检测 top 公式是否被同一特征家族主导。"""
    # 提取每个公式中出现的特征名
    feature_sets = {}
    for f in formulas:
        features = set(re.findall(r'[a-z_]+\d*[a-z_]*', f.get('formula_str', '')))
        # 过滤掉算子名
        features -= {'add', 'sub', 'mul', 'div', 'gate', 'sign', 'neg', 'abs', 'delay1', 'decay', 'jump', 'max3'}
        key = frozenset(features)
        if key not in feature_sets:
            feature_sets[key] = []
        feature_sets[key].append(f)
    
    # 如果 80%+ 的 top 公式共享同一特征集 → 坍塌
    max_cluster = max(len(v) for v in feature_sets.values())
    collapse_ratio = max_cluster / len(formulas)
    if collapse_ratio > 0.6:
        print(f"🔥 模式坍塌: {collapse_ratio:.0%} 的公式聚焦于同一特征家族")
        print(f"  主导特征: {list(max(feature_sets, key=lambda k: len(feature_sets[k])))}")
    return collapse_ratio
```

**坍塌模式示例**（来自期货 v3 实战）：
- 20 个 top 公式中 12 个是 `SIGN(close_vs_range)` 的等价变体
- `SIGN(SIGN(SIGN(x)))` = `SIGN(x)`，但策略用嵌套刷分
- 检测方法：唯一 IC 签名数 < top_K 的 50%

#### 2.3 GPU 隔离验证

训练后验证确实跑在了正确的 GPU 上：

```bash
# 验证 GPU 分配正确
TRAIN_GPU=$(grep 'Device: cuda' train.log | head -1 | grep -oP 'cuda:\\.+')
PHYSICAL_GPU=$(nvidia-smi --query-gpu=index,memory.used --format=csv,noheader | \
  awk -v mem=1300 '$2+0 > mem {print $1}' | head -1)
echo "训练声称: $TRAIN_GPU, 实际显存增加: GPU $PHYSICAL_GPU"
if [ "$TRAIN_GPU" != "cuda:0" ] || [ "$PHYSICAL_GPU" != "$EXPECTED_GPU" ]; then
    echo "🔥 GPU 分配异常: 可能用错了卡"
fi
```

### 维度三：跨方法结果复现

单一显著性检验（即使是非重叠置换检验）不足以完全排除方法偏差。对关键结论，额外用以下方法交叉验证：

| 方法 | 适用场景 | 与主方法的差异 |
|:---|---|:---|
| **不同窗口参数** | 任何 | 改变 `TRAIN_LEN/PURGE_LEN/VAL_LEN`，IC 应保持同号 |
| **不同模型** | Ridge 基线 | 用 RandomForest 或 Lasso 替代 Ridge |
| **不同种子** | RL 公式 | 不同随机种子跑 3-5 次，取 IC 中位数而非单次结果 |
| **真实交易仿真** | 任何信号 | 加交易成本、滑点、最小交易单位，看是否仍盈利 |

```python
# 跨参数稳定性检查示例
def cross_validate_stability(X, y, window_configs):
    """用多种窗口参数验证 IC 是否稳定。"""
    results = {}
    for name, config in window_configs.items():
        ics = run_walkforward(X, y, **config)
        results[name] = {
            'mean_ic': np.mean(ics),
            'win_rate': np.mean([i > 0 for i in ics]),
            'n_windows': len(ics),
        }
        print(f"  {name}: IC={results[name]['mean_ic']:+.4f}, 胜率={results[name]['win_rate']:.0%}")
    
    # 检查所有窗口配置的 IC 是否同号
    signs = set(np.sign([r['mean_ic'] for r in results.values()]))
    if len(signs) == 1:
        print(f"✅ 跨参数稳定: 所有配置均 {'正' if 1 in signs else '负'} IC")
    else:
        print(f"⚠️  跨参数不一致: IC 符号因窗口配置改变")
    return results
```

---

## 扩展：看门狗 (Watchdog) 自动化训练

训练多个领域时，**绝不手动依次启动每个训练**。必须使用看门狗脚本自动化执行整个训练流程。

看门狗提供以下能力：
- 自动按顺序/并行执行所有训练任务
- 进程存活监控 + 崩溃自动重试（最多 3 次）
- 状态持久化到 JSON，随时 `--status` 查看进度
- 诊断结果自动解析（diag 通过/失败标记）
- 全部完成后生成跨领域对比摘要
- SSH 断开后继续运行（`nohup` 后台模式）

### 看门狗架构选择

| 场景 | 推荐 | 说明 |
|:---|---|:---|
| 单 GPU 服务器 | `watchdog.py` | 顺序执行，每任务用同一 GPU |
| 多 GPU 服务器（2×） | `parallel_watchdog.py` | 分批量并行，每批 2 任务各占一卡 |
| 单任务快速验证 | `run_*.py` 直接跑 | 不用看门狗，跑完即止 |
| 单 GPU + 6 领域 | `watchdog.py` | 从 1h 到 6h 依次跑 |
| 2×GPU + 6 领域 | `parallel_watchdog.py` | 分 3 批，每批 2 并行，~2h 跑完 |

**核心原则**：只要 >= 2 个训练任务就必须用看门狗。禁止手动依次启动每个任务。

### 部署流程

#### 1. 在看门狗脚本中定义训练任务

```python
# 在 watchdog.py / parallel_watchdog.py 的 TASKS 列表中定义
TASKS = [
    {
        "name": "ashare_clean",          # 唯一名称
        "script": "scripts/run_ashare.py",  # 训练入口脚本
        # 参数（注意 --output 在 args[-1]）
        "args": ["--variant", "clean", "--steps", "500", "--batch-size", "256",
                 "--quick-windows", "5", "--output", "results/ashare_clean"],
        "timeout": 3600,  # 超时秒数
    },
    # ... 更多任务
]
```

**parallel_watchdog.py 额外字段**：
```python
{
    "name": "ashare_clean",
    # ... 同上 ...
    "gpu": 0,       # 指定 GPU 编号
}
```

**任务定义规则**：
- `name` 唯一且简短（作为状态文件主键）
- 确保 `--output` 在 `args[-1]`，看门狗据此定位结果文件
- `timeout` 必须根据任务特点合理设置（保守估计 x 2）
  - 单资产时序：~30 分钟 → timeout=1800
  - 多资产截面：~1–2 小时 → timeout=7200

#### 2. 上传到服务器

```bash
# 看门狗脚本放在项目根目录
scp watchdog.py user@server:/root/VERSION2.5/
scp parallel_watchdog.py user@server:/root/VERSION2.5/
```

#### 3. 启动看门狗

```bash
# 登录服务器
ssh user@server

# 检查 GPU 空闲
nvidia-smi

# 🔴 必须：先跑一次烟雾测试确保训练脚本可用
# （看门狗不会帮你做烟雾测试——那是前置条件）
cd /root/VERSION2.5
CUDA_VISIBLE_DEVICES=0 python3 scripts/run_ashare.py --steps 10 --batch-size 256 \
  --quick-windows 5 --output /tmp/smoke_ashare

# 如果烟雾测试通过，启动看门狗
# 单 GPU：
bash start_watchdog.sh --bg

# 双 GPU 并行：
bash start_parallel.sh
# 或手动：
nohup python3 parallel_watchdog.py > parallel_watchdog.log 2>&1 &
```

#### 4. 监控进度

```bash
# 查看实时日志
tail -f watchdog.log

# 查看结构化进度（推荐）
bash start_watchdog.sh --status
# 或
cat watchdog_status.json | python3 -m json.tool

# 并行版本
cat parallel_status.json | python3 -m json.tool
```

#### 5. 停止看门狗

```bash
bash start_watchdog.sh --kill
# 或手动
kill $(cat watchdog.pid)
```

### 看门狗核心设计模式

#### 模式 W1：状态持久化 + 可恢复性

看门狗用 JSON 文件记录每个任务的状态，即使 SSH 断开或进程崩溃，重新启动后可以知道哪些已完成的（跳过）哪些需要重试：

```python
status = {
    "tasks": {
        "ashare_clean": {
            "status": "completed",       # completed / failed / timeout / crashed
            "retries": 1,
            "elapsed_s": 3420,
            "completed_at": "2026-07-12T10:30:00",
            "best_ic": 0.0571,
            "best_sharpe": 1.234,
            "n_valid_formulas": 12,
            "gpu": 0,
        },
        "futures_ic0": {
            "status": "failed",
            "retries": 3,               # 3 次都失败 → 放弃
            "gpu": 1,
        },
    },
    "started_at": "2026-07-12T08:00:00",
    "completed_at": None,               # 还在运行
    "running": True,
    "pid": 12345,
}
```

**已完成的自动跳过**：
```python
if task_status.get("status") == "completed":
    log(f"  ⏭️  {name} 已完成，跳过")
    return True
```

#### 模式 W2：自动重试（最多 3 次）

```python
MAX_RETRIES = 3

while retries < MAX_RETRIES:
    try:
        result = subprocess.run(cmd, timeout=timeout)
        if success:
            return True
    except (subprocess.TimeoutExpired, Exception) as e:
        log(f"  ⏰/💥 {name} 失败: {e}")
        retries += 1
        if retries < MAX_RETRIES:
            time.sleep(30)  # 冷却后重试

log(f"  ❌ {name} 放弃 ({MAX_RETRIES}次失败)")
return False
```

**重试不重置**：
- 超时 → 等 30s 重试
- 崩溃 → 等 30s 重试
- OOM → 等 30s 重试（GPU 显存可能已被其他进程释放）
- 3 次全失败 → 标记失败，继续下一个任务

#### 模式 W3：诊断结果自动解析

看门狗自动检测每个任务的 `diagnostics.json`，提取测试通过率和判定结论：

```python
diag_file = Path(output_dir) / "diagnostics.json"
if diag_file.exists():
    # 聚合所有 top 公式的测试结果
    total_passed / total_tests → "3/15 tests passed"
    verdicts → "REJECT | REJECT | ACCEPT"
    
    if total_passed < total_tests:
        status = "completed_but_failed_diag"  # 训练完成但诊断未通过
```

状态等级：
| 状态 | 含义 |
|:---|---|
| `completed` | 训练完成 + 所有诊断通过 |
| `completed_but_failed_diag` | 训练完成但诊断未通过 → 需要人工审查 |
| `failed` | 训练脚本报错退出 |
| `timeout` | 超过 timeout 限制 |
| `crashed` | 异常崩溃（OOM、段错误等） |

#### 模式 W4：跨领域对比摘要

所有任务完成后看门狗自动生成摘要：

```
════════════════════════════════════════════════════
  跨领域公式发现 — 最终摘要
════════════════════════════════════════════════════
  任务                      Best IC   Sharpe  有效    耗时
  ──────────────────────────────────────────────────
  ashare_clean              +0.05710  +1.234  12/20  3420s
  ashare_full               +0.04380  +0.987   6/20  4560s
  ashare_margin             +0.03820  +0.876   8/20  3890s
  futures_ic0               +0.09050  +1.736  14/20  1280s
  etf_512880                +0.06210  +1.234  10/20   960s
  etf_510300                +0.05530  +1.102  11/20   920s
════════════════════════════════════════════════════
```

摘要也保存为 JSON：`results/cross_domain_summary.json`

### 并行看门狗的特殊考量

#### 分批策略

```python
# 6 个任务分 3 批，每批 2 个任务在不同 GPU 并行
batches = [
    [TASKS[0], TASKS[1]],   # ashare_clean (GPU0) + futures_ic0 (GPU1)
    [TASKS[2], TASKS[3]],   # ashare_full (GPU0) + etf_512880 (GPU1)
    [TASKS[4], TASKS[5]],   # ashare_margin (GPU0) + etf_510300 (GPU1)
]
```

**分批原则**：
- 每批均衡 GPU 负载（一个短任务 + 一个长任务不要配一对）
- 重计算任务（多资产截面）放 GPU0，轻计算（时序）放 GPU1
- 批间加 10s 冷却，防止显存残留导致 OOM

#### 线程安全

在并行看门狗中，多个线程同时写 `status` 字典和 `save_status()`，必须加锁：

```python
from threading import Lock
STATUS_LOCK = Lock()

def save_status(status: dict):
    with STATUS_LOCK:
        with open(STATUS_FILE, "w") as f:
            json.dump(status, f, indent=2)
```

### Agent 在看门狗训练中的职责

当 Agent 使用看门狗启动训练后，应当：

| 职责 | 具体操作 |
|:---|---|
| **检查** | 确认烟雾测试已通过（Agent 必须自己做，看门狗不负责） |
| **启动** | 在服务器上启动看门狗（后台模式） |
| **记录 PID** | 在 scratchpad 中记录看门狗 PID 和服务器信息 |
| **初步监控** | 等待 60-120s 确认看门狗已开始训练（日志有 Step 1/500 输出） |
| **保存查询命令** | 将 `--status` 和 `tail` 命令写入 scratchpad 供下次 Agent 使用 |
| **结果处理** | 下次会话中读取 `cross_domain_summary.json` 处理结果 |

```bash
# Agent 在 scratchpad 中记录的命令模板
# 查看训练进度:
ssh user@server "tail -5 /path/watchdog.log"
# 查看结构化状态:
ssh user@server "cat /path/watchdog_status.json"
# 查看 GPU 使用:
ssh user@server "nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader"
```

### 看门狗模式 vs 传统手动训练

| 维度 | 传统手动 | 看门狗自动 |
|:---|---|:---|
| 启动 | 一条一条 `ssh` + `nohup` | 一个命令启动全部 |
| 监控 | 反复 `ssh` + `tail` 检查 | `--status` 查看 JSON 状态 |
| 重试 | 手动检查失败 + 手动重启 | 自动重试 3 次 |
| 摘要 | 手动汇总所有结果 | 自动生成 `cross_domain_summary.json` |
| 诊断 | 需要手动检查 `diagnostics.json` | 自动解析并标记状态 |
| 可恢复 | 进程崩溃 → 从头重来 | 跳过已完成任务继续 |
| GPU 利用率 | 大部分 GPU 闲置时间 | 并行看门狗 2×GPU 满载 |

### 常见看门狗失败模式

#### 模式 W-A：看门狗活着但训练进程死了

**表现**：`watchdog_status.json` 显示 running，但 `ps aux` 无训练进程，GPU 显存无变化。

**原因**：训练脚本自身崩溃，看门狗日志最后一行是 `▶️ task_name (尝试 1/3)` 后无后续输出。

**修复**：
1. `tail -20 watchdog.log` 查看具体错误
2. 修复 bug 后重新启动看门狗（已完成的任务会跳过）

#### 模式 W-B：GPU OOM 导致反复重试耗尽

**表现**：某任务重试 3 次全部 OOM 崩溃。

**原因**：batch_size 太大、模型太大（d_model 翻倍后显存不够）、或前一个任务残留未清理。

**修复**：
1. 减小 batch_size（如 256→128）
2. 批间加更长的冷却（30s+）
3. 手动 `fuser -v /dev/nvidia*` 杀死残留进程

#### 模式 W-C：看门狗被 SSH 断开杀死

**表现**：SSH 重连后 `cat watchdog_status.json` 显示 running，但 `ps -p PID` 显示 DEAD。

**原因**：启动时用了 `python3 watchdog.py &` 而不是 `nohup python3 ... &`。

**修复**：永远用 `nohup ... &` 或 `bash start_watchdog.sh --bg`。

#### 模式 W-D：看门狗日志大量缓冲

**表现**：看门狗自身日志延迟。

**原因**：重定向到文件时 Python 缓冲 stdout。

**修复**：启动时加 `PYTHONUNBUFFERED=1`：
```bash
PYTHONUNBUFFERED=1 nohup python3 watchdog.py > watchdog.log 2>&1 &
```
（参考模式 H：Python 输出缓冲的三重陷阱）

### 何时不用看门狗

- **单个训练任务**：直接用 `run_*.py` 跑，不需要看门狗
- **调试新脚本**：先用 `--steps 10` 烟雾测试，看门狗不参与调试阶段
- **交互式开发**：Jupyter / 本地测试不需要看门狗
- **训练 < 5 分钟**：如果总耗时小于 5 分钟，不值得启动看门狗

### 看门狗 checklist（Agent 使用前逐项确认）

- [ ] 烟雾测试已通过（`--steps 10 无 NaN/Inf/overflow`）
- [ ] 训练脚本路径正确（`script` 在 TASKS 中存在）
- [ ] `args[-1]` 是 `--output` 路径（看门狗据此定位结果）
- [ ] `timeout` 合理（保守估计 × 2）
- [ ] 目标 GPU 空闲（`nvidia-smi` 确认）
- [ ] 磁盘空间充足（`df -h` > 10GB）
- [ ] 启动模式正确（单 GPU→`watchdog.py`；2×GPU→`parallel_watchdog.py`）
- [ ] 后台运行（`nohup` 或 `--bg`）
- [ ] PID 已记录到 scratchpad + 查询命令已保存

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

> **上述文本报告必须同时附带可视化报告**——训练结束后输出目录下按下表生成三张核心图，无图等于未报告：
>
> | 图名 | 文件 | 对应文本字段 |
> |:---|:---|:---|
> | Loss / IC 曲线 | `plots/loss_curve_final.png` | “耗时” 与 “Best” |
> | Walkforward IC 面板 | `plots/walkforward_panel_final.png` | “窗口均值 IC”、“胜率” |
> | GPU 资源时间线 | `plots/gpu_timeline_final.png` | “设备”、“耗时” |
>
> 详见 §【训练可视化】的 “零、最小可行可视化” 与 “七、快速验收流程”。Agent 不看图下的 ✅/🔥 判定不可接受。

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

---

## RL 公式发现的适用性边界

基于多市场实践，总结强化学习公式发现方法论的有效边界。

### 核心条件：特征多样性决定 RL 有效性

RL 公式发现的核心能力是挖掘**不同特征族之间的非线性交互**。当满足以下条件时它才有显著增量价值：

| 条件 | 说明 | 检测方法 |
|:---|:---|---:|
| 特征来源多样性 ≥ 2 | 特征来自多个独立数据源（价格 + 成交量 + OI + 基本面） | 计算特征相关矩阵，跨族平均 |r| < 0.3 |
| 跨截面维度 ≥ 5 | 有多个可比较的实体（多股票/多合约/多板块） | panel 维度检查 |
| 单特征 IC 方向分歧 | 部分特征正 IC、部分负 IC | 遍历单特征 Spearman IC，检查符号分布 |
| Ridge 基线 IC < 0.10 | 线性模型未饱和 | Ridge WF 均值 IC |

**经验法则**：如果 Ridge 基线 IC 与 AlphaGPT top-1 IC 差距 < 0.05，且 top-5 公式中 >80% 是单特征变体，说明 RL 在该领域没有优势，退化到线性模型。

### 决策树

```
特征维度数 < 3 且全部来自同一数据源? ── 是 ──→ ❌ RL 退化风险高，先用 Ridge
    否
    ↓
有跨截面实体（≥5个可比较单位）? ── 是 ──→ ✅ 优先用 RL 横截面 panel
    否
    ↓
单时序 Ridge IC > 0.10? ── 是 ──→ ⚠️ Ridge 已够好，RL 提升空间有限
    否
    ↓
可以引入独立数据源（非 OHLCV 衍生）? ── 是 ──→ ✅ 加入后评估
    否
    ↓
❌ 不建议用 RL 公式发现。单时序 OHLCV-only 数据的最优解是线性模型。
```

### 当 RL 不可行时的替代路径

如果 RL 公式发现在某领域不可行（决策树指向 ❌），以下策略可以扭转：

#### 策略 1：添加跨截面维度
```
问题：单实体所有特征高度相关 → RL 无交互可发现
方案：将训练数据从 (D, N) 扩展为 (D, S, N) 横截面 panel
      S ≥ 5 个可比实体
      → 不同实体同一特征值不同 → 创造天然分歧
      → RL 可以学相对价值信号
验证：CS Ridge IC 是否 > 0
```

#### 策略 2：注入独立数据源
```python
# 当所有特征来自同一数据源时：
# 特征互相关矩阵中位 r > 0.5 → RL 退化
# 注入一个与现有特征 |r| < 0.3 的新数据源
# 候选：汇率、利率、波动率指数、行业相对指标、基本面数据
# → 新数据源提供 RL 需要的跨族交互机会
```

#### 策略 3：Ridge + 体制条件过滤
```
有时最佳策略不是 RL 公式，而是 Ridge 基线 + 风控：
1. 识别信号显著的体制子集（波动率高低、趋势/震荡）
2. 只在有利体制下激活信号
3. 加止损、持仓上限
验证：修正后的 Ridge IC 在不同体制下的差异
```

#### 策略 4：构造代理特征
```
当成功经验依赖特定数据源（如期货的 OI），而目标市场无此数据时：
- 寻找概念等价物："持仓变化"→"成交量份额变化"
- 用代理特征复制已被验证的交互结构
验证：代理特征与原始目标的 Spearman 相关性
```

---

## 方法论完备性检查——回测与部署的六大陷阱

### 陷阱 1：Z-score 前瞻偏误——归一化统计量用了未来数据

```python
# ❌ 全序列归一化——每个决策点看见了未来分布
vals = [pred_dict[i] for i in all_idxs]  # 所有预测值
mu = np.nanmean(vals)                     # 包含了未来数据
sig = max(np.nanstd(vals), 1e-10)         # 包含了未来数据
z = (pred - mu) / sig                     # z-score 有前瞻偏误

# ✅ Expanding window——只用历史数据
seen = [pred_dict[i] for i in idxs if i <= current_day]
mu = np.nanmean(seen)
sig = max(np.nanstd(seen), 1e-10)
z = (pred - mu) / sig
```

**诊断**：检查回测脚本中 `np.nanmean` / `np.nanstd` 是否在交易循环外部一次性计算。如果是，一定有前瞻偏误。

**修复**：确保每个交易决策点的归一化统计量只基于该点之前的历史数据。回测与实盘的统计量计算方法必须完全一致。

**影响量级**：实盘案例中，全序列 z-score 声称 +70% 回报、Sharpe 1.47；expanding window 修正后变为 -10%、Sharpe -0.07。整个策略的回测结论从「可部署」变为「不可部署」，仅因一行统计量计算的位置错误。

### 陷阱 2：RL 符号无关评分导致的部署方向错误

```python
# RL 用 Ridge 回归评分：Ridge 是符号无关的，负系数也能产生正预测 IC
# RL 报告 "formula IC=+0.168" ——实际是 Ridge 预测 IC，不是公式裸 IC
# 公式裸 IC 可能是 -0.199（符号完全相反）

# ❌ 部署时用了公式的原始符号（方向可能反了）
signal = 2.0 * feature             # 裸 IC 为负 → 做多就是反向交易

# ✅ 必须验证 RS（Ridge Sign）并翻转
# 检查 Ridge 系数在多数窗口中的符号
# 如果多数窗口系数为负 → 部署时加负号
signal = -2.0 * feature            # 翻转后裸 IC 为正
```

**根源**：RL 用 Ridge（符号无关）评分，存储的 `full_mean_ic` 是 Ridge 预测 IC，不是公式裸 IC。部署端无法知道是否需要翻转符号。

**修复**：RL 训练完成后，对每个 top 公式额外计算裸 IC 的符号，存储为 `deploy_sign`（+1 或 -1）。部署时乘以该符号：`最终信号 = deploy_sign × 公式值`。

**检测**：比较 RL 报告的 `full_mean_ic` 与裸公式的 Spearman IC。如果符号相反或差距 >50%，说明 Ridge 学了负系数，部署时必须翻转。

### 陷阱 3：过拟合到单一时序——RL在单实体时序上的退化

当 RL 公式发现应用在**单个实体**的时间序列时，容易出现退化：

```原因链：
1. 单实体的所有特征来自同一数据源 → 特征高度相关（|r| > 0.5 常见）
2. 所有特征指向同一方向（全正或全负 IC）
3. RL explorer 找不到真正的跨族交互
4. 收敛到单特征非线性变换（如一特征立方）→ 等价于线性模型
```

**适用性判断**：

| 场景 | RL 适用性 | 条件 |
|:---|:---:|---|
| 多实体横截面 | ✅ 高 | 不同实体特征值不同 → 天然多样性 |
| 多合约/多资产 | ✅ 中高 | 不同合约间的交互结构 |
| 单实体时序 | ❌ 低 | Ridge 往往同水平或更优 |
| 指数/ETF 时序 | ⚠️ 中 | 需要 F5 等跨维度高级特征 |

**经验法则**：如果 Ridge 基线 IC 与 RL top-1 IC 差距 < 0.05，且 top-5 中 >80% 是单特征变体，说明 RL 在该领域已退化，直接用 Ridge。

### 陷阱 4：小样本统计显著性幻觉

```python
# ❌ 7 笔交易、6 胜 1 负 → 报告 Sharpe=1.47
# 二项式检验：P(≥6胜 | p=0.5) = 0.0625 → 不显著！

# ✅ 正确做法：报告 Sharpe 置信区间
from scipy.stats import norm
sharpe = 1.47
n = 7
se = np.sqrt((1 + 0.5 * sharpe**2) / n)
ci = (sharpe - 1.96 * se, sharpe + 1.96 * se)  # 95% CI
```

**交易数阈值**：

| 交易数 | 最小可报告的 Sharpe | 说明 |
|:---:|:---:|---|
| < 10 | 不报告 | 二项式检验不显著，任何 Sharpe 都不可靠 |
| 10–30 | > 0.5 | 需加 Bonferroni 校正（乘测试公式数）|
| > 30 | > 0.3 | 常规显著性 |

**经验教训**：OOS 交易次数 < 30 的 paper-trading 结果不应作为 deploy 决策依据。

### 陷阱 5：回测与实盘的方法论差异

**最隐蔽的回测错误：回测使用的方法与实盘不完全一致**

常见差异：
| 维度 | 回测（错误） | 实盘（正确） | 后果 |
|:---|:---|---:|
| 归一化 | 全序列统计量 | Expanding window | 前瞻偏误，虚高回报 |
| 信号方向 | RL 报告的正 IC | 裸公式验证 | 可能反向交易一整期 |
| 交易成本 | 固定比例 | 最小佣金 + 滑点 + 汇率 | 低估成本 30-70% |
| 持仓周期 | 固定持有 | 信号触发退出 | 回测与实盘的交易集不同 |

**验证方法**：回测完成后，写一段独立的「实盘模拟器」——用与实盘完全相同的逻辑（仅历史数据、逐步决策）重跑一遍。如果结果与回测不同，说明回测方法有问题。

### 陷阱 6：成功经验的错误迁移

从高信噪比市场（期货、美股）学到的经验不能直接迁移到低信噪比市场（单股票、新兴市场）：

```
期货成功经验：
  - 24 特征 + AlphaGPT → 多特征交互公式 (IC=0.260)
  - 关键驱动：OI x 波动率（跨族交互）

迁移到 SGX 单股票：
  - 20 特征（无 OI）→ RL 退化到单特征
  - 原因：所有特征来自同一数据源 + 无跨截面维度
  - 结论：经验迁移失败，因为缺失的前提条件（OI/多合约）被忽略
```

**检查清单**：迁移经验前确认——原方案成功的关键前提条件在新市场是否也成立？如果条件不满足，需要先改造条件而非直接复制方案。

### 陷阱 7：文档过期污染——新旧结论混用

```
当项目积累了多轮结论，且每轮可能推翻上一轮时（如 Session 5 推翻了 Session 4 的结论），
新旧文档混在一起会导致后续 Agent 引用错误信息。
```

**症状**：
- 目录下同时存在过时和当前的结论文档，文件名没有区分标记
- 后续 Agent 随机引用其中一份，有时用旧结论做决策
- 项目根目录下堆积了大量 `*_v1.py`、`*_v2.py`、`*_old.py` 文件

**规范**：
```
docs/
├── current.md          ← 唯一有效的当前结论
├── roadmap.md           ← 当前路线图
└── archive/             ← 历史记录集中存放
    ├── 2026-07-05_analysis_report.md
    └── 2026-07-06_PLAN_RL_FIXES.md
```

| 角色 | 文件 | 规则 |
|:---|:---|---|
| 当前结论 | `CONTEXT_FOR_NEXT_AGENT.md` | 只有一份，每次重写 |
| 历史记录 | `docs/archive/*.md` | 只追加不修改，按日期前缀 |
| 方法论文档 | `ml-training.md` | 持续积累，不删除 |

**实施步骤**：
1. 每轮 Session 结束时：将旧的结论文档移入 `archive/` 目录
2. 按日期重命名：`YYYY-MM-DD_original_name.md`
3. 根目录下只保留当前有效的文档
4. 如果需要引用旧结论，明确说明"参见 archive/YYYY-MM-DD_xxx.md"

**经验教训**：Agent 容易随机引用目录中任意一份文档。只有"唯一当前文档"的模式才能保证结论一致性。

---

## 深度学习训练方法论（PyTorch）

> 来源：Gehirnskrieg（2026-07-24）及其他 Transformer 训练项目
> 目标：将 Agent 培养为能自主诊断模型训练问题的专家

### Rule Zero：每次训练结束后吸收教训

**无论成功或失败，在训练结束后必须执行：**

> 0.x 关键依赖：§【训练可视化】三张核心图是“教训是否被看出”的原始证据。在以下流程的步骤 1“抽取 3-5 条可转移教训”时，必须先调出三张核心图、仅针对图上可见的曲线形态与诊断信号归纳教训（说不出在图上哪个形态 = 未看图，不能入表）。
> 训练结束后同时输出（1）三张图 + `training_metrics.json` + （2）本表与看图逆向归纳的“教训表”。两者闭环。详见 §【训练可视化】 → “Rule Zero 闭环”。

1. 抽取 3-5 条**跨项目通用的教训**（非特定项目的 bug fix）
2. 若本文件已有类似条目，追加 `#例证` 或 `#反例` 标签
3. 若为新教训，追加到对应小节下方，标注 `#新增` 和日期
4. 更新本节底部的【启动前检查清单】

这能将一次性调 bug 转化为累积性专家能力。当前本文件在执行此规则。

---

### 环境与依赖

#### PyTorch ↔ Transformers 兼容矩阵

| PyTorch | Transformers Max | 特征 |
|---------|-----------------|------|
| 2.2.x   | ≤4.40.x | 无 `nn.RMSNorm`，`autocast` 无 `device_type` 参数 |
| 2.3.x   | ≤4.45.x | 引入 `TransformGetItemToIndex` |
| 2.5+    | latest | 完整 API 兼容 |

诊断指令：若见 `ImportError: cannot import TransformGetItemToIndex` 或 `AttributeError: nn.RMSNorm` → transformers 版本过新，应降级。
```bash
pip install 'transformers>=4.38,<4.41'  # 适配 PyTorch 2.2.x
```

#### pip install 可能静默升级 PyTorch

`pip install transformers` 可能将 PyTorch 作为依赖升级（例如 2.2.2 → 2.13.0），导致 CUDA 不兼容。每次 pip 操作后必须验证：
```bash
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

#### CUDA 驱动 vs PyTorch 编译版本不匹配

症状：`torch.cuda.is_available() → False` + warning "driver too old (found version 12040)"。
解决：安装与驱动匹配的 PyTorch（`nvidia-smi` 顶部查看 CUDA 版本）。
```bash
pip install torch==2.2.2 --index-url https://download.pytorch.org/whl/cu121
```

#### Conda 包缓存恢复

当下载很慢（国内 → 海外）且 PyTorch 被破坏时，从 conda 本地缓存恢复：
```bash
PKG_DIR=/root/anaconda3/pkgs/pytorch-2.2.2-py3.11_cuda12.1_cudnn8.9.2_0
SITE=/root/anaconda3/lib/python3.11/site-packages
for pkg in $PKG_DIR/lib/python3.11/site-packages/*/; do
    cp -a "$pkg" "$SITE/$(basename $pkg)"
done
# 同时恢复 cuDNN（常被遗漏）
cp -a $PKG_DIR/lib/python*/site-packages/torch/lib/libcudnn* $SITE/torch/lib/
```

#### 自定义 RMSNorm（PyTorch < 2.4）

```python
class RMSNorm(nn.Module):
    def __init__(self, d, eps=1e-6):
        super().__init__()
        self.gain = nn.Parameter(torch.ones(d))
        self.bias = nn.Parameter(torch.zeros(d))
        self.eps = eps
    def forward(self, x):
        return x / torch.sqrt(x.pow(2).mean(-1, keepdim=True) + self.eps) * self.gain + self.bias
```

---

### 架构 Bug 识别

#### 分块处理破坏因果性（Critical）

症状：训练 loss 正常下降、但推理生成纯 token 重复产出（"the the the..."）。

根因：序列按 K-token 分块处理，每块内 `is_causal=True` 只遮罩块内 token。Token 32 无法看到 Token 5（它们在不同块中）。

测试方法：
```python
x1 = torch.randn(1, 16, d); x2 = x1.clone(); x2[:, 0] += 10
out1, out2 = model(x1), model(x2)
diff_at_15 = (out1[0, 15] - out2[0, 15]).abs().mean()
assert diff_at_15 > 1e-4  # 若分块处理则此处失败
```

修复：整条序列一次通过 attention，不拆块。慢变量（增益 g）按前向调用更新，不按块内。

#### 有状态 Module 的跨步梯度累积

症状：第二个训练步报 `RuntimeError: Trying to backward through the graph a second time`。

根因：`self.g = compute(self.g, inputs)` 中旧 `self.g` 有 grad_fn，新 `self.g` 通过旧 `self.g` → 旧反向图 → 无限链。

修复：
```python
old = self.g.detach()  # 打断跨步梯度
self.g = compute(old, inputs)  # 梯度只通过 inputs 流
```

#### Buffer 的 inplace 操作破坏 autograd

症状：`one of the variables needed for gradient computation has been modified by an inplace operation`。

修复：所有 buffer 累积操作包在 `torch.no_grad()` 内：
```python
with torch.no_grad():
    self.pooled += new_value
    self.pooled.zero_()
```

---

### 训练动力学诊断

#### Loss → 0、PPL → 1.0、生成重复 Token

模式分类：

| 现象 | 诊断 | 修复 |
|------|------|------|
| Loss 500 步内 10→0.001 | 模型记住了小数据集 | 增大数据集、减小 batch / 增大模型、正则化 |
| PPL=1.00 + 生成重复 token | 曝光偏差 — 训练用 GT token、推理用自身输出 | Top-p sampling、更高温度 |
| 所有层增益熵=0 | 复制器过早坍缩到单峰 | 减小 η、增大 T、熵正则化 |

**Token 数 / 参数数 经验法则**：Transformer LM 至少需要 **20 token 每参数** 才能稳定训练。低于 5:1 则必然过拟合。

| 模型大小 | 最少 Token 数 |
|----------|-------------|
| 20M | 400M |
| 85M | 1.7B |
| 1B   | 20B |

#### Loss 变成负数

数学上纯交叉熵不可能为负。若出现负数，说明有加性正则项在主导。

校验公式：`|reg_weight × reg_value| < 0.01 × CE_loss`。
例如增益熵正则化：`ent_reg * ln(L)` 在 CE_loss ≈ 3、L=64 时应 < 0.03。建议从 0.0001 起步，按需调大。

#### 增益/状态熵作为实时健康指标

对任何含可学习概率分布的架构（复制器、MoE routing、attention gating），周期性记 log 分布熵：

- 熵 = ln(L)：均匀分布，系统在探索中。
- 熵缓慢下降：健康专精化。
- 熵在 100 步内归零：过早坍缩 → 提高 temperature / 降低学习率 / 添加熵正则化。
- 熵剧烈振荡：训练不稳定 → 检查梯度截断、学习率。

#### 熵正则化调度策略

不使用恒定权重，改用分阶段调度：
```python
if step < warmup:
    ent_weight = +0.01   # 鼓励均匀（探索期）
else:
    ent_weight = -0.001  # 鼓励集中（精专期），或直接设 0
```

---

### 远程 GPU 训练工作流

#### 后台进程启动

以下模式可靠地脱离 SSH 会话：
```bash
# ✅ 可行——无 fd 继承
bash -c 'cd /path && exec python -u train.py </dev/null >log 2>&1 &' &

# ❌ 不行——SSH 挂起
nohup python train.py > log 2>&1 &    # fd 继承
setsid bash train.sh > log 2>&1 &     # fd 继承
```

关键：`exec` 替换 shell 进程，`< /dev/null` 关闭 stdin。

#### 训练前快速验证

```bash
# 1. GPU 空闲？
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# 2. CUDA 可用？
python -c "import torch; print(torch.cuda.is_available())"

# 3. 目标 batch+seq 能跑通？
python -c "
from model import create_model
m = create_model().cuda()
x = torch.randint(0, V, (B, S)).cuda()
out = m(x, labels=x); out['loss'].backward()
print(f'VRAM peak: {torch.cuda.max_memory_allocated()/1e9:.2f}GB')
"
```

---

### 蒸馏策略备忘

#### API 蒸馏（廉价、实用）

当教师模型过大无法本地加载时：
1. 通过 API 用多样化 prompt 生成教师完成文本。
2. 将生成的文本保存为 JSONL。
3. 用标准 LM loss 训练学生模型。

用 `ThreadPoolExecutor(8)` 做并发 API 调用 → 8 倍加速。

#### 流式数据集训练

```python
from datasets import load_dataset
ds = load_dataset("allenai/c4", "en", split="train", streaming=True)
it = iter(ds)
batch = [next(it) for _ in range(batch_size)]
```

注意：从国内访问 HuggingFace 流式 C4 很慢。可先预 tokenize 一批到本地缓存。

---

---

## 数据管线陷阱

> 来源：Angriffskrieg CTM Prover（2026-07-24）

### BPE Tokenizer 版本兼容性

症状：`Tokenizer.from_file()` 报 `Exception: data did not match any variant of untagged enum ModelWrapper`。

根因：`tokenizers` 库版本升级后 JSON 格式要求变化。常见不兼容：

| 版本 | model.type 要求 | merges 格式 |
|------|----------------|-------------|
| <0.15 | `"BPE"` (大写) | `[["a", "b"], ...]` (list) |
| 0.19+ | `"bpe"` (小写) | `[("a", "b"), ...]` (tuple) |

修复流程：
```python
import json
with open('tokenizer.json') as f:
    d = json.load(f)
# 1. 改小写
d['model']['type'] = 'bpe'
# 2. 转 tuple
d['model']['merges'] = [tuple(m) for m in d['model']['merges']]
# 3. 用 tokenizers 库重建（处理 None/unset 字段）
from tokenizers import Tokenizer, models
bpe = models.BPE(vocab=d['model']['vocab'], merges=d['model']['merges'])
tok = Tokenizer(bpe)
tok.save('tokenizer_fixed.json')  # 保存为当前版本兼容格式
```

`#预防`：训练脚本启动时必须调用 `tokenizer.encode(smoke_text)` 验证 tokenizer 可用。

### BPE 格式检测的缓冲区陷阱

症状：tokenizer 文件存在但 `_is_bpe_format()` 返回 False，导致回退到错误加载路径。

根因：检测函数只读文件前 64KB。BPE tokenizer JSON 的 `model.type` 字段在文件深部（~1500 行后），64KB 不够。

修复：读全文并 case-insensitive 匹配：
```python
def _is_bpe_format(path):
    with open(path) as f:
        content = f.read()  # 全文
    import re
    return bool(re.search(r'"type"\s*:\s*"(BPE|bpe)"', content))
```

### Shard 文件传输完整性

症状：`PytorchStreamReader failed reading zip archive: failed finding central directory`。

根因：`scp` 传输 `.pt` shard 文件被中断，不完整文件有非零字节数但内部损坏。

修复：传输后用 `md5sum` 或 `stat -c%s` 对比两端文件。
```bash
# 最简单的验证：对比文件大小
ssh server-a "stat -c%s /path/shard.pt"
ssh server-b "stat -c%s /path/shard.pt"  # 必须完全一致
```

`#预防`：用 `rsync --partial` 代替 `scp` 传输大文件，支持断点续传。

### Shard 压缩传输

预 tokenize 的 shard `.pt` 文件（token IDs + 大量 padding）**高度可压缩**。
实测：2GB（6 shards）→ **63MB（tar.gz）**，压缩比 ~32:1。

跨服务器同步时优先 `tar czf` + 传输单个压缩包，而非逐个传原始文件。

---

## GPU 显存冲突

> 来源：Angriffskrieg 与 Gehirnskrieg 并行（2026-07-24）

### 其他项目进程占用显存

症状：训练 OOM，错误显示 `Process <pid> has X GiB memory in use`，PID 非当前项目。

根因：同服务器其他项目的残留进程占用显存。

排查与清理：
```bash
# 启动训练前必须执行
fuser -v /dev/nvidia0          # 列出所有 GPU 进程
ps aux | grep python3 | grep -v grep  # 审查每个进程
pkill -f 'train_quick'         # 杀非当前项目进程
# 重新确认
nvidia-smi --query-gpu=memory.used --format=csv,noheader  # 应 <500 MiB
```

`#预防`：每次启动训练前在「前置检查清单」中增加此项。

---

## 模型容量与扩展性

> 来源：Angriffskrieg CTM — 200K vs 1M 对比（2026-07-24）

### 模型容量饱和诊断

当 **5× 数据量仅带来边际改善**（val_loss 0.0065→0.0051，改善 22%），说明模型容量已饱和——当前参数量无法利用更多数据。

诊断信号：
- 最佳 val_loss 不随数据量线性改善
- 训练 loss 持续快速下降但验证 loss 早停
- 增大 batch_size 无帮助

经验法则：参数/样本比 < 3:1 时，**优先增大模型而非增大数据**。

修复：增大模型（D=256→512，2.5M→6.6M 参数），加 dropout/weight decay。

---

## 跨数据集评估

> 来源：Angriffskrieg Goedel → Leandojo（2026-07-24）

### 非自回归 CTM 的 Adaptive Stop 陷阱

症状：OOD 数据评估时模型仅预测 1 token（`tick_used=1`），CE 异常高。

根因：adaptive stop 在 OOD 数据上提前触发（encoder 输出极端值 → 核心循环放大 → 第 1 tick 置信度超过阈值）。

修复：评估时关闭 adaptive stop——**必须改 `core_loop` 实例属性，不能只改 config**：
```python
model.core.use_adaptive_stop = False  # ✅ core_loop 的属性
# model.config.use_adaptive_stop = False  # ❌ config 改了但 core_loop 已用 init 时的值
```

`#预防`：评估脚本必须显式禁用 adaptive stop。若 `tick_used` 均值 < T_max × 0.5 则仍有问题。

### 跨数据集 Logits 爆炸

症状：源域 val_loss≈0.005，跨数据集时 logits 范围 [-1300, 270]，CE 远超 ln(V)≈9。

根因：encoder + 递归核心循环在 OOD 数据上放大数值。

诊断：
```python
logits = model(inputs)['tactic_logits']
print(f'logits: [{logits.min():.1f}, {logits.max():.1f}]')
# 正常: [-10, 10]；异常: < -100 或 > 100
```

`#预防`：评估前用 1 个 batch 检查 logits 范围。异常时对 logits 做 `torch.clamp(logits, -50, 50)`。

---

## 多服务器并行

> 来源：Angriffskrieg 两台 RTX 3080（2026-07-24）

### 同主机不同端口 VM 间传文件

两台 VM 共享公网 IP、不同 SSH 端口时，用公网 IP 回环传输（流量不出物理机）：
```bash
# 在源服务器上：用 sshpass + scp 直接推到目标
sshpass -p 'pw_dst' scp -P <port_dst> /path/files root@<PUBLIC_IP>:/dest/
```

不要从本地做中继（下载→上传），慢一倍。

### 并行训练分配

两台各 1×GPU 时，并行不同实验：
- Server A：不同数据集（Leandojo V1）
- Server B：不同模型（D=512 Goedel）

互补推进，不竞争 GPU。

---

## 启动前检查清单（已合并可视化：2026-07-24）

### 环境 / CUDA
- [ ] `torch.cuda.is_available()` 返回 True
- [ ] `torch.version.cuda` 与 `nvidia-smi` 驱动版本一致
- [ ] **`ps aux | grep python3` 无其他项目进程占用 GPU**
- [ ] `nvidia-smi` 显示 Memory-Used < 500 MiB（非当前进程者）
- [ ] GPU 空闲显存 ≥ 模型大小 × 2
- [ ] 模型在 target batch+seq 下 forward+backward 无 OOM

### Tokenizer / Shard
- [ ] **Tokenizers 版本兼容：`tokenizer.encode('test')` 无报错**
- [ ] **Shard 文件完整性：`md5sum` 或文件大小与源一致**

### 架构 / 正确性
- [ ] 无分块处理（通过 causality 测试验证）
- [ ] 有状态 buffer 已 detach（无跨步梯度）
- [ ] Buffer 累积在 `torch.no_grad()` 内
- [ ] Loss 不为负（检查正则化系数）
- [ ] 增益/状态熵每 N 步记日志
- [ ] Checkpoint 可正常保存（先用小 step 测试）

### 运行 / 监控
- [ ] 后台进程以 `exec ... </dev/null >log 2>&1 &` 启动
- [ ] Train log 中 `grep 'step '` 有持续输出（缓冲已关）

### 可视化（由下方可视清单合并而来，详见 §【训练可视化】）
- [ ] `matplotlib.use('Agg')` 已设置在 import pyplot 之前（远程无头训练必须）
- [ ] **中文字体已配置**（图标题/标签不是方框）←新增
- [ ] 输出目录包含 `plots/` 子目录（`mkdir -p results/xxx/plots`）
- [ ] **`TrainingLogger`/`create_training_hooks` 已初始化并挂载到训练循环**
- [ ] `nvidia-smi` 可执行（GPU 可视化需要；不可用时不阻塞训练，仅跳过 GPU 图）
- [ ] 烟雾测试（10步）也输出了三张核心图到 `/tmp/smoke_test/plots/`
- [ ] 训练结束后 `training_metrics.json` 存在且非空（`test -s results/xxx/training_metrics.json`）
- [ ] 看门狗模式：每个任务完成后 `<task>/plots/` 下至少 2 张图

---

## 市场结构性诊断：κ(Σ_r) 共移性指数

> 来源：Marktkrieg 项目（2026-07-24），基于金观涛系统论的形式化探索转为实用工具

### 是什么

κ(Σ_r) = λ_max / λ_min，取自 N 只股票日收益率的滚动协方差矩阵。

当所有股票齐涨齐跌时，协方差矩阵接近秩亏，κ 飙升。
它告诉你市场何时正在**失去内部多样性**——如同森林中的树种减少，一场火灾就能烧毁全部。

κ 不预测涨跌方向。它测量的是市场的**结构性脆弱程度**。

### 实证结论（SPY+9大市值股，2012–2026，3564天，6个月滚动窗口）

| 指标 | low κ (<q33) | high κ (>q67) | 差异 |
|------|-------------|--------------|------|
| SPY 日波动率 | 0.85% | **1.36%** | 1.59x |
| 未来60日实现波动率 | 0.136 | **0.183** | 1.35x |
| SPY 日收益率 | +0.059% | +0.084% | 无差异 |
| Momentum 63d IC | 0.032 | 0.024 | 无差异 (p=0.67) |

**t-test for forward vol: t=13.3, p<0.000001** — κ 是极度显著的结构性信息。

### 关键洞察：κ 是 regime indicator，不是交易信号

κ 告诉你的不是「该买什么」，而是「现在处在什么市场状态」：

| κ 范围 | 市场状态 | 建议策略 |
|--------|---------|---------|
| < q33（低共移性） | 个股分化，因子有效 | 截面因子（momentum, value, quality）| 
| q33–q67（正常） | 正常市场 | 维持现有策略 |
| > q67（高共移性） | 系统性风险上升，未来 vol 显著更高 | 降低仓位，切换防御因子 |
| > q90（极端） | 2008/2020/2022 级别的危机环境 | 仅做波动率/对冲策略 |

κ 的已知危机峰值（2020=2.77, 2022=2.86）与真实市场事件精确对齐。

### 如何用于因子发现（AlphaGPT）

κ(Σ_r) 可以作为 **AlphaGPT / RL 公式发现** 的特征输入或 regime 条件器：

**方案 A：将 κ 作为第 N+1 个特征加入 StackVM 词汇表**

```python
# 在 data/domain.py 的 FEATURES 末尾追加
FEATURES = (
    # ... 现有的 OHLCV 特征 ...
    'kappa_log10',        # 市场共移性（全局特征，所有股票同日同值）
    'kappa_delta_21d',    # κ 的 21 天变化（方向敏感）
)
```

Agent 会自动发现「当 kappa 高时应切换因子种类」的 pattern。
无需外部 rules。

**方案 B：Regime 分桶训练（更稳健）**

```python
# 按 κ 分桶，每个 regime 独立训练 AlphaGPT
kappa_low_mask = kappa_series < kappa_series.quantile(0.33)
kappa_high_mask = kappa_series >= kappa_series.quantile(0.67)

# 训练两个模型
alpha_low = train_alphagpt(features[kappa_low_mask], targets[kappa_low_mask])
alpha_high = train_alphagpt(features[kappa_high_mask], targets[kappa_high_mask])

# 运行时根据 κ 选择模型
if current_kappa > kappa_threshold:
    formula = alpha_high.generate()
else:
    formula = alpha_low.generate()
```

**方案 C：κ 作为仓位规模动态调节器**

```python
# 高 κ 时降低整体仓位
position_scale = 1.0 / (1.0 + kappa_zscore)
final_position = base_position * np.clip(position_scale, 0.2, 1.0)
```

### F7 假说（已测试）

> 当 κ 处于 expanding-percentile 前 10% 且连续 ≥5 个周期时，未来 60 日实现波动率超过无条件 90 分位的条件概率 ≥ 3× 基线（10%）。

**结果（SPY+30，2000–2026，252天窗口，6426个有效日）：28 个触发事件，3 次成功，条件概率 = 10.7%，基线比 = 1.07x。**

**假说未被验证（1.07x 远低于 3x 目标），但 κ 作为连续变量的 vol 预测能力（前面表格）仍然成立。**

机械的阈值触发不适合 κ 的慢变化特性。应用方式应是连续变量的 regime conditioning，而非二元阈值信号。

### 实现代码

```python
import pandas as pd, numpy as np

def compute_kappa(prices: pd.DataFrame, window: int = 252) -> pd.Series:
    """Compute log10(κ) from aligned close prices."""
    returns = np.log(prices / prices.shift(1)).iloc[1:]
    kappa_vals = pd.Series(np.nan, index=prices.index)
    
    for i in range(window, len(returns) + 1):
        chunk = returns.iloc[i-window:i].dropna(axis=1, how='any')
        if chunk.shape[1] < 5:
            continue
        cov = chunk.cov().values
        eigvals = np.linalg.eigvalsh(cov)
        # 相对 eigenvalue floor：防止近奇异矩阵产生数值伪影
        floor = max(eigvals[-1] * 1e-10, 1e-15)
        eigvals = np.maximum(eigvals, floor)
        kappa_vals.iloc[i] = np.log10(eigvals[-1] / eigvals[0])
    
    return kappa_vals
```

### 已知限制

- 需要 ≥5 只股票（越多越好），相关性检验需要 ≥10 只
- 滚动窗口需要 > 股票数（252 天 × N 只股票）
- 对停牌股票用前向填充会产生人为零收益 → 虚低 κ。停牌期间应排除该股票
- 无 Fama-French 因子校正——κ 同时捕获因子共移和特质共移
- 跨市场比较时需要相同的股票数和窗口长

### 数据需求

| 数据 | 来源 | 最低要求 |
|------|------|---------|
| 日收盘价 | yfinance / AKShare / 本地 CSV | ≥5 只股票，≥252 天 |
| 股票池 | S&P 500 / CSI300 / 自选 | ≥10 只（越多越可靠） |

### 相关项目

- 完整实现：`/home/xieguiawu/Desktop/ML/Marktkrieg/signals/kappa.py`
- 数据加载：`/home/xieguiawu/Desktop/ML/Marktkrieg/data/loader.py`
- F7 测试：`/home/xieguiawu/Desktop/ML/Marktkrieg/signals/test_f7.py`
- 理论背景（已归档）：`/home/xieguiawu/Desktop/ML/Marktkrieg/archive/formalization_v1/`

---

## 训练可视化

> 来源：多次训练事故的事后复盘（2026-07-24 整理）
> 核心原则：**可视化不是事后美化，而是训练中的实时诊断工具**。80% 的训练事故在损失曲线 / 指标图上有提前信号——只是没人画图。

### 零、最小可行可视化（任何训练都必须有）

每个训练任务至少输出以下三张图到 `{output_dir}/plots/`：

| 序号 | 图名 | 诊断目标 | 文件名 |
|:---:|------|---------|--------|
| 1 | Loss / IC 曲线 | 收敛状态、过拟合拐点、NaN 爆炸 | `loss_curve.png` |
| 2 | GPU 资源时间线 | 显存泄漏、利用率低下、资源竞争 | `gpu_timeline.png` |
| 3 | Walkforward 面板 | 窗口间 IC 稳定性、胜率分布 | `walkforward_panel.png` |

**烟雾测试（10步）也必须输出这三张图。** 如果 10 步内就有 NaN / 异常 spike，说明数据和代码有问题，不应进入完整训练。

### 一、核心可视化类型与诊断信号

#### 1.1 Loss / 奖励曲线

```python
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import MaxNLocator

def plot_loss_curve(step_values, step_numbers=None, window=50, title="Training Dynamics"):
    """绘制 Loss/IC 曲线，带滑动平均和异常标注。
    
    Args:
        step_values: 每步的 loss 或 IC 值
        step_numbers: 对应的步编号（None 则用 range）
        window: 滑动平均窗口大小
    """
    if step_numbers is None:
        step_numbers = np.arange(len(step_values))
    
    step_values = np.array(step_values, dtype=float)
    valid = ~np.isnan(step_values)
    
    fig, axes = plt.subplots(2, 1, figsize=(14, 8), sharex=True,
                             gridspec_kw={'height_ratios': [3, 1]})
    
    # 上子图：主曲线 + 滑动平均
    ax = axes[0]
    ax.plot(step_numbers[valid], step_values[valid], alpha=0.3, 
            color='steelblue', linewidth=0.5, label='Raw (per-step)')
    
    if len(step_values[valid]) >= window:
        sma = np.convolve(step_values[valid], np.ones(window)/window, mode='valid')
        sma_steps = step_numbers[valid][window-1:]
        ax.plot(sma_steps, sma, color='darkorange', linewidth=1.5, 
                label=f'SMA-{window}')
    
    ax.set_ylabel('Value')
    ax.set_title(title)
    ax.legend(loc='best', fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5)
    
    # 标注 best score
    if len(step_values[valid]) > 0:
        best_idx = np.nanargmax(step_values) if 'IC' in title or 'Sharpe' in title else np.nanargmin(step_values)
        ax.axvline(x=step_numbers[best_idx], color='green', linestyle=':', linewidth=1,
                  label=f'Best@{step_numbers[best_idx]}')
    
    # 下子图：残差（检测异常跳动）
    ax = axes[1]
    if len(step_values[valid]) > 1:
        residual = np.abs(np.diff(step_values[valid]))
        residual_steps = step_numbers[valid][1:]
        ax.fill_between(residual_steps, residual, alpha=0.4, color='coral')
        # 标注异常跳动（>3σ）
        threshold = np.nanmean(residual) + 3 * np.nanstd(residual)
        spikes = residual > threshold
        if spikes.any():
            ax.scatter(residual_steps[spikes], residual[spikes], 
                      color='red', s=20, zorder=5, marker='x')
        ax.axhline(y=threshold, color='red', linestyle='--', linewidth=0.5, 
                  label=f'3σ threshold')
    ax.set_xlabel('Step')
    ax.set_ylabel('|Δ|')
    ax.legend(loc='best', fontsize=9)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig
```

**诊断信号表**：

| 曲线形态 | 诊断 | 行动 |
|---------|------|------|
| Loss 单调下降 + 平滑 | ✅ 健康训练 | 继续 |
| Loss 突然跳变到 0 / NaN | 数值爆炸 | 检查学习率、梯度裁剪、数据 NaNs |
| Loss 不变（平台期） | 学习率过低 / 模型容量不足 | 提高 LR、增大模型 |
| Loss 下降后反弹 | 过拟合开始 | 记录反弹点步数，该点之前 checkpoint 为最佳 |
| IC 剧烈振荡（±0.3） | 信号不稳定，RL explorer 随机游走 | 减小 entropy coeff、增大 batch |
| IC 缓慢退化（每 100 步 -0.02） | 模式坍塌进行中 | 检查公式多样性、增加探索噪声 |

#### 1.2 梯度诊断面板

```python
def plot_gradient_diagnostics(grad_norms_per_step, param_names=None):
    """梯度范数分布 + Layer-wise 梯度比。探测梯度消失/爆炸。"""
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    
    # 1. 梯度范数时间序列
    ax = axes[0]
    if isinstance(grad_norms_per_step, dict):
        # 多个层的梯度分别绘制
        for name, norms in grad_norms_per_step.items():
            ax.plot(norms, alpha=0.7, linewidth=0.8, label=name[:20])
        ax.legend(fontsize=7, loc='upper right')
    else:
        ax.plot(grad_norms_per_step, color='steelblue', linewidth=0.8)
    ax.set_xlabel('Step')
    ax.set_ylabel('Gradient Norm (log10)')
    ax.set_yscale('log')
    ax.set_title('Gradient Norm over Steps')
    ax.grid(True, alpha=0.3)
    ax.axhline(y=1e-3, color='red', linestyle='--', linewidth=0.5, label='Vanishing')
    ax.axhline(y=1e3, color='darkred', linestyle='--', linewidth=0.5, label='Exploding')
    
    # 2. 最终梯度范数分布
    ax = axes[1]
    if isinstance(grad_norms_per_step, dict):
        final_norms = [norms[-1] for norms in grad_norms_per_step.values() 
                      if len(norms) > 0]
        names = list(grad_norms_per_step.keys())
        colors = plt.cm.tab20(np.linspace(0, 1, len(final_norms)))
        bars = ax.barh(range(len(final_norms)), np.log10(np.maximum(final_norms, 1e-10)), 
                      color=colors)
        ax.set_yticks(range(len(final_norms)))
        ax.set_yticklabels([n[:25] for n in names], fontsize=7)
    ax.set_xlabel('log10(Gradient Norm)')
    ax.set_title('Final Gradient Norm by Layer')
    ax.axvline(x=-3, color='red', linestyle='--', linewidth=0.5)
    ax.axvline(x=3, color='darkred', linestyle='--', linewidth=0.5)
    ax.grid(True, alpha=0.3, axis='x')
    
    # 3. 梯度信噪比
    ax = axes[2]
    if isinstance(grad_norms_per_step, dict) and len(grad_norms_per_step) > 0:
        # 计算每层梯度的变异系数
        cv_per_layer = {}
        for name, norms in grad_norms_per_step.items():
            if len(norms) > 1:
                cv_per_layer[name] = np.std(norms) / (np.mean(np.abs(norms)) + 1e-10)
        if cv_per_layer:
            names, cvs = zip(*sorted(cv_per_layer.items(), key=lambda x: -x[1]))
            ax.bar(range(len(cvs)), cvs, color='mediumpurple', alpha=0.8)
            ax.set_xticks(range(len(cvs)))
            ax.set_xticklabels([n[:15] for n in names], rotation=45, ha='right', fontsize=7)
    ax.set_ylabel('CV (σ/|μ|)')
    ax.set_title('Gradient Signal-to-Noise (CV)')
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    return fig
```

**诊断信号**：
- 某层梯度范数 < 1e-4 持续 50+ 步 → 梯度消失，检查激活函数 / 初始化
- 某层梯度范数 > 1e3 反复出现 → 梯度爆炸，降低 LR 或增加 clip
- CV > 10（高噪声梯度）→ 训练不稳定，增大 batch size

#### 1.3 GPU 资源监控

```python
def plot_gpu_timeline(gpu_history, output_path=None):
    """从训练中周期性采集的 GPU 指标绘制资源面板。
    
    gpu_history: list of dict, 每项包含:
        {'step': int, 'timestamp': float, 'gpu_util': float, 
         'vram_used_mb': float, 'vram_total_mb': float}
    """
    steps = [h['step'] for h in gpu_history]
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 8))
    
    # 1. VRAM 使用量
    ax = axes[0, 0]
    vram = [h['vram_used_mb'] for h in gpu_history]
    ax.fill_between(steps, 0, vram, alpha=0.4, color='steelblue')
    ax.plot(steps, vram, color='steelblue', linewidth=1)
    if gpu_history:
        total = gpu_history[0].get('vram_total_mb', max(vram) * 1.2 if vram else 8192)
        ax.axhline(y=total, color='gray', linestyle='--', linewidth=0.5, label=f'Total ({total:.0f}MB)')
    ax.set_ylabel('VRAM (MB)')
    ax.set_title('GPU Memory Usage')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    
    # 2. GPU 利用率
    ax = axes[0, 1]
    util = [h.get('gpu_util', 0) for h in gpu_history]
    ax.fill_between(steps, 0, util, alpha=0.4, color='darkorange')
    ax.plot(steps, util, color='darkorange', linewidth=1)
    ax.set_ylabel('Utilization (%)')
    ax.set_title('GPU Utilization')
    ax.set_ylim(0, 105)
    ax.grid(True, alpha=0.3)
    
    # 3. VRAM 变化率（检测泄漏）
    ax = axes[1, 0]
    if len(vram) > 1:
        dvram = np.diff(vram)
        ax.bar(steps[1:], dvram, color=['green' if d >= 0 else 'red' for d in dvram], 
               alpha=0.6, width=1)
        # 线性拟合检测趋势性增长（泄漏信号）
        if len(steps) > 10:
            z = np.polyfit(steps, vram, 1)
            trend = z[0]  # MB/step
            ax.plot(steps, np.polyval(z, steps), 'r--', linewidth=1, 
                   label=f'Trend: {trend:+.2f} MB/step')
            ax.legend(fontsize=8)
    ax.set_xlabel('Step')
    ax.set_ylabel('Δ VRAM (MB)')
    ax.set_title('VRAM Change per Step (Leak Detection)')
    ax.grid(True, alpha=0.3)
    
    # 4. 每步耗时
    ax = axes[1, 1]
    if len(gpu_history) > 1:
        timestamps = [h['timestamp'] for h in gpu_history]
        step_times = np.diff(timestamps)
        ax.bar(steps[1:], step_times, alpha=0.6, color='mediumpurple', width=1)
        ax.axhline(y=np.mean(step_times), color='red', linestyle='--', linewidth=0.8,
                  label=f'Mean: {np.mean(step_times):.1f}s')
        ax.legend(fontsize=8)
    ax.set_xlabel('Step')
    ax.set_ylabel('Time (s)')
    ax.set_title('Step Duration')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig
```

**诊断信号**：
- VRAM 趋势性增长 > 10 MB/step → **显存泄漏**，检查 tensor 缓存 / `torch.cuda.empty_cache()`
- VRAM 突然跳跃 > 500 MB → 可能触发了新分配（大 batch / 动态图扩展）
- GPU 利用率 < 30% 持续 → CPU 瓶颈（数据加载慢）或 batch size 过小
- 每步耗时趋势性增长 → 模型生成越来越长（RL 公式 GATE 嵌套），限制 max_tokens

#### 1.4 Walkforward IC 诊断面板

```python
def plot_walkforward_panel(ic_per_window, window_labels=None, 
                           benchmark_ic=None, title="Walkforward IC"):
    """Walkforward 窗口 IC 面板：单窗口 IC + 分布 + 累积。"""
    ic_per_window = np.array(ic_per_window, dtype=float)
    n_windows = len(ic_per_window)
    
    if window_labels is None:
        window_labels = [f'W{i+1}' for i in range(n_windows)]
    
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(2, 3, hspace=0.35, wspace=0.3)
    
    # 1. 每个窗口的 IC 柱状图
    ax = fig.add_subplot(gs[0, :2])
    colors = ['#2ecc71' if ic > 0 else '#e74c3c' for ic in ic_per_window]
    bars = ax.bar(range(n_windows), ic_per_window, color=colors, alpha=0.8, width=0.7)
    ax.axhline(y=0, color='black', linewidth=0.5)
    ax.axhline(y=np.mean(ic_per_window), color='steelblue', linestyle='--', linewidth=1.5,
              label=f'Mean IC={np.mean(ic_per_window):+.4f}')
    if benchmark_ic is not None:
        ax.axhline(y=benchmark_ic, color='orange', linestyle=':', linewidth=1.5,
                  label=f'Benchmark IC={benchmark_ic:+.4f}')
    ax.set_xticks(range(n_windows))
    ax.set_xticklabels(window_labels, rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('IC')
    ax.set_title(title)
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3, axis='y')
    
    # 2. IC 分布直方图
    ax = fig.add_subplot(gs[0, 2])
    valid_ic = ic_per_window[~np.isnan(ic_per_window)]
    ax.hist(valid_ic, bins=max(8, n_windows//3), color='steelblue', alpha=0.7, 
            edgecolor='white')
    ax.axvline(x=0, color='red', linestyle='--', linewidth=1)
    ax.axvline(x=np.mean(valid_ic), color='green', linestyle='-', linewidth=1.5,
              label=f'Mean={np.mean(valid_ic):+.4f}')
    ax.set_xlabel('IC')
    ax.set_ylabel('Frequency')
    ax.set_title(f'IC Distribution (n={len(valid_ic)})')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3, axis='y')
    
    # 3. 累积 IC 曲线
    ax = fig.add_subplot(gs[1, :2])
    cum_ic = np.cumsum(np.nan_to_num(ic_per_window, 0))
    ax.fill_between(range(n_windows), 0, cum_ic, alpha=0.3, color='steelblue')
    ax.plot(range(n_windows), cum_ic, color='steelblue', linewidth=1.5, marker='o', 
            markersize=3)
    ax.set_xlabel('Window')
    ax.set_ylabel('Cumulative IC')
    ax.set_title('Cumulative IC over Walkforward Windows')
    ax.grid(True, alpha=0.3)
    
    # 4. 胜率 / Sharpe 摘要
    ax = fig.add_subplot(gs[1, 2])
    ax.axis('off')
    win_rate = np.mean(valid_ic > 0)
    sharpe = np.mean(valid_ic) / (np.std(valid_ic) + 1e-10)
    summary_text = f"""
Summary Statistics
━━━━━━━━━━━━━━━━━━
Windows:        {len(valid_ic)}
Mean IC:        {np.mean(valid_ic):+.4f}
Median IC:      {np.median(valid_ic):+.4f}
Std IC:         {np.std(valid_ic):.4f}
IC Sharpe:      {sharpe:.2f}
Win Rate:       {win_rate:.1%}
Positive Wins:  {np.sum(valid_ic > 0)}

Best Window:    W{np.argmax(ic_per_window)+1} ({np.max(ic_per_window):+.4f})
Worst Window:   W{np.argmin(ic_per_window)+1} ({np.min(ic_per_window):+.4f})
"""
    ax.text(0.1, 0.9, summary_text, transform=ax.transAxes, fontsize=9,
            fontfamily='monospace', verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    return fig
```

**诊断信号**：
- IC 集中在少数窗口（如 W3 贡献 80% 累积 IC）→ 信号不稳定，过度依赖特定时段
- 累积 IC 后半段走平或下降 → 信号衰减，检查数据漂移
- Win rate < 55% → 信号弱，考虑是否值得部署
- 首尾窗口 IC 符号相反 → 市场 regime 变化，信号已失效

#### 1.5 置换检验分布

```python
def plot_permutation_test(true_ic, perm_ics, n_perm=2000, title="Permutation Test"):
    """绘制置换检验的零分布 vs 真实 IC。"""
    perm_ics = np.array(perm_ics, dtype=float)
    perm_ics = perm_ics[~np.isnan(perm_ics)]
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # 零分布直方图
    ax.hist(perm_ics, bins=min(50, len(perm_ics)//10), color='lightgray', 
            edgecolor='gray', alpha=0.8, density=True, label='Null Distribution')
    
    # 真实 IC 竖线
    ax.axvline(x=true_ic, color='red', linewidth=2.5, linestyle='-', 
              label=f'True IC={true_ic:+.4f}')
    
    # 95% 置信区间
    p95 = np.percentile(np.abs(perm_ics), 95)
    ax.axvline(x=p95, color='darkorange', linewidth=1.5, linestyle='--', 
              label=f'95% Null={p95:.4f}')
    ax.axvline(x=-p95, color='darkorange', linewidth=1.5, linestyle='--')
    ax.fill_betweenx([0, ax.get_ylim()[1]], -p95, p95, alpha=0.05, color='orange')
    
    # p-value 标注
    from scipy.stats import percentileofscore
    pct = percentileofscore(np.abs(perm_ics), np.abs(true_ic))
    p_value = 1.0 - pct / 100.0
    verdict = '✅ SIGNIFICANT' if p_value < 0.05 else '❌ NOT SIGNIFICANT'
    
    ax.set_xlabel('IC')
    ax.set_ylabel('Density')
    ax.set_title(f'{title}\n{n_perm} permutations | p={p_value:.4f} | {verdict}')
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3, axis='y')
    
    return fig, p_value
```

#### 1.6 RL 公式演化与多样性

```python
def plot_formula_evolution(formula_history):
    """可视化 RL 公式发现的演化过程。
    
    formula_history: list of dict, 每步包含:
        {'step': int, 'best_ic': float, 'n_unique_formulas': int,
         'top_feature_families': list[str], 'avg_formula_len': float}
    """
    steps = [h['step'] for h in formula_history]
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    
    # 1. Best IC 演化
    ax = axes[0, 0]
    best_ics = [h['best_ic'] for h in formula_history]
    ax.plot(steps, best_ics, color='steelblue', linewidth=1.5, marker='.', markersize=2)
    ax.set_xlabel('Step')
    ax.set_ylabel('Best IC')
    ax.set_title('Best Formula IC over Training')
    ax.grid(True, alpha=0.3)
    
    # 2. 公式多样性（去重数量）
    ax = axes[0, 1]
    n_unique = [h.get('n_unique_formulas', 0) for h in formula_history]
    ax.fill_between(steps, 0, n_unique, alpha=0.4, color='mediumseagreen')
    ax.plot(steps, n_unique, color='mediumseagreen', linewidth=1)
    ax.set_xlabel('Step')
    ax.set_ylabel('Unique Formulas')
    ax.set_title('Formula Diversity (Higher = Less Collapse)')
    ax.grid(True, alpha=0.3)
    
    # 3. 平均公式长度
    ax = axes[1, 0]
    lengths = [h.get('avg_formula_len', 0) for h in formula_history]
    ax.plot(steps, lengths, color='purple', linewidth=1)
    ax.set_xlabel('Step')
    ax.set_ylabel('Avg Tokens')
    ax.set_title('Average Formula Length')
    ax.grid(True, alpha=0.3)
    
    # 4. 特征家族使用分布（取最后一步）
    ax = axes[1, 1]
    if formula_history:
        last = formula_history[-1]
        families = last.get('top_feature_families', [])
        if families:
            # 统计各家族出现频次
            from collections import Counter
            family_counts = Counter()
            for h in formula_history[-min(50, len(formula_history)):]:
                for fam in h.get('top_feature_families', []):
                    family_counts[fam] += 1
            if family_counts:
                names, counts = zip(*family_counts.most_common(15))
                ax.barh(range(len(names)), counts, color='steelblue', alpha=0.7)
                ax.set_yticks(range(len(names)))
                ax.set_yticklabels(names, fontsize=7)
                ax.invert_yaxis()
    ax.set_xlabel('Occurrences (last 50 steps)')
    ax.set_title('Feature Family Usage')
    ax.grid(True, alpha=0.3, axis='x')
    
    plt.tight_layout()
    return fig
```

**诊断信号**：
- n_unique 从 100+ 骤降到 < 20 且不恢复 → **模式坍塌**，停止训练
- avg_formula_len 单调增长 > 50 tokens → explorer 在堆砌 GATE 嵌套刷分
- 单一特征家族占比 > 80% → 退化到线性模型

#### 1.7 DL 专用：增益 / 熵 / 注意力诊断

```python
def plot_dl_health(entropy_history, gain_history=None, attn_history=None):
    """深度学习特有的健康指标面板。
    
    entropy_history: dict[str, list[float]] — 每层的分布熵
    gain_history: dict[str, list[float]] — 每层的增益值（如星形胶质细胞）
    attn_history: list[dict] — 注意力模式
    """
    n_layers = len(entropy_history) if entropy_history else 0
    
    fig = plt.figure(figsize=(16, 4 + 3 * n_layers))
    
    row_idx = 0
    
    # 1. 熵热力图
    if entropy_history:
        ax = fig.add_subplot(n_layers + 1, 2, 1)
        layer_names = list(entropy_history.keys())
        n_steps = min([len(v) for v in entropy_history.values()]) if entropy_history else 0
        if n_steps > 0:
            entropy_matrix = np.array([entropy_history[name][:n_steps] for name in layer_names])
            im = ax.imshow(entropy_matrix, aspect='auto', cmap='RdYlGn', 
                          interpolation='nearest')
            ax.set_yticks(range(len(layer_names)))
            ax.set_yticklabels(layer_names, fontsize=7)
            ax.set_xlabel('Step')
            ax.set_title('Entropy Heatmap (Green=High/Diverse, Red=Low/Collapsed)')
            plt.colorbar(im, ax=ax)
    
    # 2. 增益分布
    if gain_history:
        ax = fig.add_subplot(n_layers + 1, 2, 2)
        for name, gains in gain_history.items():
            ax.plot(gains, alpha=0.7, linewidth=0.8, label=name[:20])
        ax.set_xlabel('Step')
        ax.set_ylabel('Gain')
        ax.set_title('Gain per Layer')
        ax.legend(fontsize=7)
        ax.grid(True, alpha=0.3)
    
    # 3. 每层详细熵曲线
    for i, (name, entropies) in enumerate(entropy_history.items()):
        ax = fig.add_subplot(n_layers + 1, 2, 3 + i * 2)
        ax.plot(entropies, color='steelblue', linewidth=0.8)
        max_ent = np.log(len(entropies)) if len(entropies) > 0 else 1  # 均匀分布熵上限
        if max_ent > 0:
            ax.axhline(y=max_ent, color='green', linestyle=':', linewidth=0.5, 
                      label=f'Max (uniform)={max_ent:.2f}')
        ax.axhline(y=0, color='red', linestyle=':', linewidth=0.5, label='Collapse')
        ax.set_ylabel('Entropy')
        ax.set_title(f'{name} Entropy')
        ax.legend(fontsize=7)
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig
```

#### 1.8 κ 共移性仪表板

```python
def plot_kappa_dashboard(kappa_series, spy_returns=None, event_dates=None,
                         window=252):
    """市场共移性 κ 的全景仪表板。"""
    fig, axes = plt.subplots(3, 1, figsize=(18, 12), sharex=True,
                             gridspec_kw={'height_ratios': [2, 1, 1]})
    
    # 1. κ 曲线 + 阈值带
    ax = axes[0]
    ax.plot(kappa_series.index, kappa_series.values, color='steelblue', linewidth=0.8)
    q33 = kappa_series.quantile(0.33)
    q67 = kappa_series.quantile(0.67)
    q90 = kappa_series.quantile(0.90)
    ax.fill_between(kappa_series.index, 0, q33, alpha=0.1, color='green', label='Low κ (分化)')
    ax.fill_between(kappa_series.index, q33, q67, alpha=0.1, color='gray', label='Normal')
    ax.fill_between(kappa_series.index, q67, kappa_series.max(), alpha=0.1, color='red', 
                    label='High κ (共移)')
    ax.axhline(y=q90, color='darkred', linestyle='--', linewidth=0.8, label=f'q90={q90:.2f}')
    ax.set_ylabel('log10(κ)')
    ax.set_title(f'Market Co-movement Index κ(Σr) — {window}d Rolling')
    ax.legend(fontsize=8, loc='upper left')
    ax.grid(True, alpha=0.3)
    
    # 标注事件
    if event_dates:
        for date, label in event_dates.items():
            if date in kappa_series.index:
                ax.axvline(x=date, color='purple', linestyle=':', linewidth=0.8)
                ax.text(date, ax.get_ylim()[1] * 0.95, label, rotation=90, 
                       fontsize=7, verticalalignment='top')
    
    # 2. SPY 收益叠加
    if spy_returns is not None:
        ax = axes[1]
        cum_ret = (1 + spy_returns).cumprod()
        ax.plot(cum_ret.index, cum_ret.values, color='darkgreen', linewidth=0.8)
        ax.set_ylabel('Cumulative Return')
        ax.set_title('SPY Cumulative Return')
        ax.grid(True, alpha=0.3)
    
    # 3. 未来波动率 vs κ 散点图
    ax = axes[2]
    fwd_vol = kappa_series.shift(-60).rolling(60).std() * np.sqrt(252)
    valid = ~(kappa_series.isna() | fwd_vol.isna())
    if valid.sum() > 10:
        ax.scatter(kappa_series[valid], fwd_vol[valid], alpha=0.3, s=2, 
                  color='steelblue')
        # 线性拟合
        z = np.polyfit(kappa_series[valid].values, fwd_vol[valid].values, 1)
        x_line = np.linspace(kappa_series[valid].min(), kappa_series[valid].max(), 100)
        ax.plot(x_line, np.polyval(z, x_line), 'r--', linewidth=1.5,
               label=f'Slope={z[0]:.3f}')
        ax.legend(fontsize=8)
    ax.set_xlabel('κ (log10)')
    ax.set_ylabel('Forward 60d Realized Vol (annualized)')
    ax.set_title('κ vs Forward Volatility')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig
```

#### 1.9 多实验对比面板

```python
def plot_experiment_comparison(experiments):
    """对比多个训练实验的关键指标。
    
    experiments: dict[str, dict], key=实验名, value=指标字典
        包含: 'mean_ic', 'std_ic', 'sharpe', 'win_rate', 'n_formulas', 'duration_s'
    """
    names = list(experiments.keys())
    n = len(names)
    
    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    
    metrics = [
        ('mean_ic', 'Mean IC', 'bar', 'steelblue'),
        ('std_ic', 'IC Std', 'bar', 'coral'),
        ('sharpe', 'IC Sharpe', 'bar', 'mediumseagreen'),
        ('win_rate', 'Win Rate', 'barh', 'mediumpurple'),
        ('n_formulas', 'Valid Formulas', 'bar', 'darkorange'),
        ('duration_s', 'Duration (min)', 'bar', 'gray'),
    ]
    
    for idx, (key, title, kind, color) in enumerate(metrics):
        ax = axes[idx // 3, idx % 3]
        values = [experiments[name].get(key, 0) for name in names]
        if key == 'duration_s':
            values = [v / 60 for v in values]
        
        if kind == 'bar':
            ax.bar(range(n), values, color=color, alpha=0.8, width=0.6)
        else:
            ax.barh(range(n), values, color=color, alpha=0.8, height=0.6)
        
        ax.set_title(title)
        if kind == 'bar':
            ax.set_xticks(range(n))
            ax.set_xticklabels([n[:12] for n in names], rotation=45, ha='right', fontsize=8)
        else:
            ax.set_yticks(range(n))
            ax.set_yticklabels([n[:12] for n in names], fontsize=8)
        ax.grid(True, alpha=0.3, axis='y' if kind == 'bar' else 'x')
    
    plt.suptitle('Cross-Experiment Comparison', fontsize=14, fontweight='bold')
    plt.tight_layout()
    return fig
```

---

### 二、实现方案

#### 方案 A：Matplotlib 静态报告（推荐用于远程训练）

远程服务器无显示器，用 Agg 后端渲染 PNG：

```python
import matplotlib
matplotlib.use('Agg')  # 无头模式，必须在 import pyplot 之前
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import time
from pathlib import Path

# C1 中文字体配置：远程服务器无 Noto 时回退 DejaVu Sans（中文显示为方框则升级服务器字体包）
# Fedora: dnf install google-noto-sans-cjk-sc-fonts    Ubuntu: apt install fonts-noto-cjk
for _f in ['Noto Sans CJK SC', 'Noto Sans SC', 'Source Han Sans SC',
           'WenQuanYi Zen Hei', 'Microsoft YaHei', 'SimHei']:
    try:
        fm.findfont(_f, fallback_to_default=False)
        plt.rcParams['font.sans-serif'] = [_f, 'DejaVu Sans']
        plt.rcParams['axes.unicode_minus'] = False
        break
    except Exception:
        continue
# 字体检测通过性检查（可选、不列报错）
_ok = any(font.get_name() in plt.rcParams['font.sans-serif']
          for font in fm.fontManager.ttflist)
if not _ok:
    print('⚠️  未找到中文字体，图中的中文标题/标签将显示为方框。'
          'Fedora: dnf install google-noto-sans-cjk-sc-fonts')

# 训练循环内记录指标
class TrainingLogger:
    """轻量级训练指标记录器，不依赖外部库。"""
    
    def __init__(self, output_dir, plot_every=50):
        self.output_dir = Path(output_dir)
        self.plot_dir = self.output_dir / 'plots'
        self.plot_dir.mkdir(parents=True, exist_ok=True)
        self.plot_every = plot_every
        
        # 时间序列指标
        self.steps = []
        self.step_rewards = []      # loss / IC / reward
        self.best_scores = []       # 历史最佳
        self.step_times = []        # 每步耗时
        self.gpu_vram = []          # GPU 显存
        self.gpu_util = []          # GPU 利用率
        
        # Walkforward 指标
        self.wf_ics = []            # 每个窗口的 IC
        
        # RL 公式指标
        self.n_unique_formulas = []
        self.avg_formula_lengths = []
        self.feature_families = []
        
        # DL 指标
        self.grad_norms = {}        # {layer_name: [norms]}
        self.entropy_history = {}   # {layer_name: [entropies]}
        
        self.start_time = time.time()
    
    def log_step(self, step, reward, best_so_far=None, step_time=None,
                 gpu_vram=None, gpu_util=None, n_unique=None, 
                 avg_len=None, feature_fams=None):
        self.steps.append(step)
        self.step_rewards.append(reward)
        self.best_scores.append(best_so_far if best_so_far is not None else reward)
        self.step_times.append(step_time or (time.time() - self.start_time))
        if gpu_vram is not None:
            self.gpu_vram.append(gpu_vram)
        if gpu_util is not None:
            self.gpu_util.append(gpu_util)
        if n_unique is not None:
            self.n_unique_formulas.append(n_unique)
        if avg_len is not None:
            self.avg_formula_lengths.append(avg_len)
        if feature_fams is not None:
            self.feature_families.append(feature_fams)
        
        # 定期生成中间报告
        if step % self.plot_every == 0 and step > 0:
            self._save_interim_report(step)
    
    def log_wf_ic(self, ics):
        self.wf_ics = list(ics)
    
    def log_grad_norm(self, layer_name, norm):
        if layer_name not in self.grad_norms:
            self.grad_norms[layer_name] = []
        self.grad_norms[layer_name].append(norm)
    
    def log_entropy(self, layer_name, entropy):
        if layer_name not in self.entropy_history:
            self.entropy_history[layer_name] = []
        self.entropy_history[layer_name].append(entropy)
    
    def _save_interim_report(self, step):
        """训练中间生成报告，便于远程监控。"""
        save_all_plots(
            output_dir=str(self.plot_dir),
            logger=self,
            suffix=f'_step{step}'
        )
    
    def save_final_report(self):
        """训练结束后生成完整报告。"""
        return save_all_plots(
            output_dir=str(self.plot_dir),
            logger=self,
            suffix='_final'
        )
    
    def to_dict(self):
        """导出为 JSON 可序列化格式。"""
        return {
            'steps': self.steps,
            'step_rewards': self.step_rewards,
            'best_scores': self.best_scores,
            'step_times': self.step_times,
            'gpu_vram': self.gpu_vram,
            'gpu_util': self.gpu_util,
            'wf_ics': self.wf_ics,
            'n_unique_formulas': self.n_unique_formulas,
            'avg_formula_lengths': self.avg_formula_lengths,
            'feature_families': self.feature_families[-50:] if self.feature_families else [],
        }


def save_all_plots(output_dir, logger, suffix=''):
    """生成全部标准可视化图片。返回生成的文件路径列表。"""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    files = []
    
    # 1. Loss / IC 曲线
    if logger.step_rewards:
        fig = plot_loss_curve(logger.step_rewards, logger.steps)
        path = out / f'loss_curve{suffix}.png'
        fig.savefig(path, dpi=100, bbox_inches='tight')
        plt.close(fig)
        files.append(str(path))
    
    # 2. GPU 资源时间线
    if logger.gpu_vram or logger.step_times:
        # 构造 gpu_history 兼容格式
        gpu_history = []
        for i in range(len(logger.steps)):
            gpu_history.append({
                'step': logger.steps[i],
                'timestamp': logger.step_times[i] if i < len(logger.step_times) else 0,
                'gpu_util': logger.gpu_util[i] if i < len(logger.gpu_util) else 0,
                'vram_used_mb': logger.gpu_vram[i] if i < len(logger.gpu_vram) else 0,
            })
        if gpu_history:
            fig = plot_gpu_timeline(gpu_history)
            path = out / f'gpu_timeline{suffix}.png'
            fig.savefig(path, dpi=100, bbox_inches='tight')
            plt.close(fig)
            files.append(str(path))
    
    # 3. Walkforward IC 面板
    if logger.wf_ics:
        fig = plot_walkforward_panel(logger.wf_ics)
        path = out / f'walkforward_panel{suffix}.png'
        fig.savefig(path, dpi=100, bbox_inches='tight')
        plt.close(fig)
        files.append(str(path))
    
    # 4. 公式演化（RL 专用）
    if logger.n_unique_formulas:
        formula_history = []
        for i in range(len(logger.steps)):
            formula_history.append({
                'step': logger.steps[i],
                'best_ic': logger.best_scores[i] if i < len(logger.best_scores) else 0,
                'n_unique_formulas': logger.n_unique_formulas[i] if i < len(logger.n_unique_formulas) else 0,
                'avg_formula_len': logger.avg_formula_lengths[i] if i < len(logger.avg_formula_lengths) else 0,
                'top_feature_families': logger.feature_families[i] if i < len(logger.feature_families) else [],
            })
        if formula_history:
            fig = plot_formula_evolution(formula_history)
            path = out / f'formula_evolution{suffix}.png'
            fig.savefig(path, dpi=100, bbox_inches='tight')
            plt.close(fig)
            files.append(str(path))
    
    # 5. DL 健康指标（熵 / 增益 / 注意力）——只传函数实际接受的参数
    if logger.entropy_history:
        fig = plot_dl_health(
            logger.entropy_history,
            gain_history=getattr(logger, 'gain_history', None),
            attn_history=getattr(logger, 'attn_history', None),
        )
        path = out / f'dl_health{suffix}.png'
        fig.savefig(path, dpi=100, bbox_inches='tight')
        plt.close(fig)
        files.append(str(path))
    # 6. 梯度诊断单列一图，避免与“增益”语义混淆
    if getattr(logger, 'grad_norms', None):
        fig = plot_gradient_diagnostics(logger.grad_norms)
        path = out / f'gradient_diagnostics{suffix}.png'
        fig.savefig(path, dpi=100, bbox_inches='tight')
        plt.close(fig)
        files.append(str(path))
    
    return files
```

#### 方案 B：TensorBoard / W&B 集成

```python
# 可选：TensorBoard 集成（需 pip install tensorboard）
def setup_tensorboard(log_dir):
    """设置 TensorBoard 日志记录器。"""
    try:
        from torch.utils.tensorboard import SummaryWriter
        writer = SummaryWriter(log_dir)
        return writer
    except ImportError:
        print("⚠️  tensorboard 未安装，回退到 Matplotlib 方案")
        return None

# 在训练循环中使用
if writer:
    writer.add_scalar('Loss/train', loss, step)
    writer.add_scalar('IC/mean', mean_ic, step)
    writer.add_scalar('GPU/vram_mb', vram, step)
    writer.add_scalar('GPU/utilization', gpu_util, step)
    writer.add_histogram('Gradients/layer_0', grads[0], step)
```

**方案选择**：
| 场景 | 推荐 | 原因 |
|------|------|------|
| 远程服务器无显示器 | 方案 A (Matplotlib PNG) | 直接 scp 图片到本地查看 |
| 本地开发 + 实时监控 | 方案 B (TensorBoard) | tensorboard --logdir runs/ |
| 需要团队共享链接 | W&B / MLflow | 提供远程 dashboard 链接 |
| 快速验收判断（Agent 用） | 方案 C (ASCII 仪表板) | 一条 SSH 命令看完所有关键指标 |

#### 方案 C：终端 ASCII 仪表板（零依赖）

```python
def print_ascii_dashboard(logger):
    """在终端中打印 ASCII 训练状态仪表板。SSH 友好的轻量方案。
    不需要 matplotlib，不需要显示器。"""
    
    if not logger.steps:
        print("No training data yet.")
        return
    
    rewards = np.array(logger.step_rewards)
    n = len(rewards)
    
    # Sparkline 生成（迷你趋势线）
    def sparkline(values, width=40, symbol='▁▂▃▄▅▆▇█'):
        if len(values) < 2:
            return ''
        valid = values[~np.isnan(values)]
        if len(valid) == 0:
            return ''
        vmin, vmax = valid.min(), valid.max()
        if vmax == vmin:
            return '─' * min(width, len(values))
        # 降采样到 width
        step = max(1, len(values) // width)
        sampled = values[::step][:width]
        chars = []
        for v in sampled:
            if np.isnan(v):
                chars.append(' ')
            else:
                idx = min(len(symbol) - 1, int((v - vmin) / (vmax - vmin) * (len(symbol) - 1)))
                chars.append(symbol[idx])
        return ''.join(chars)
    
    # 进度条
    def bar(value, max_val, width=20, char='█'):
        ratio = min(1.0, max(0.0, value / max_val)) if max_val > 0 else 0
        filled = int(ratio * width)
        return f"{char * filled}{'░' * (width - filled)} {ratio:.0%}"
    
    print("\n" + "=" * 60)
    print("  📊 TRAINING DASHBOARD")
    print("=" * 60)
    
    # 进度
    last_step = logger.steps[-1]
    total_expected = getattr(logger, 'total_steps', last_step)
    print(f"\n  Progress:    Step {last_step}/{total_expected} {bar(last_step, total_expected)}")
    
    # 指标摘要
    last_10 = rewards[-min(10, n):]
    last_50 = rewards[-min(50, n):]
    print(f"\n  {'Metric':<15} {'Last':>8} {'Last 10':>8} {'Last 50':>8} {'Best':>8}")
    print(f"  {'─'*15} {'─'*8} {'─'*8} {'─'*8} {'─'*8}")
    print(f"  {'Value':<15} {rewards[-1]:>+8.4f} {np.mean(last_10):>+8.4f} "
          f"{np.mean(last_50):>+8.4f} {np.max(rewards):>+8.4f}")
    
    # Sparkline
    if n > 1:
        print(f"\n  Trend: {sparkline(rewards)}")
    
    # GPU 信息（如果有）
    if logger.gpu_vram:
        vram = logger.gpu_vram[-1]
        util = logger.gpu_util[-1] if logger.gpu_util else 0
        print(f"\n  GPU:        VRAM={vram:.0f}MB {bar(vram, 10240)}  Util={util:.1f}% {bar(util, 100)}")
    
    # Walkforward（如果有）
    if logger.wf_ics:
        ics = np.array(logger.wf_ics)
        print(f"\n  Walkforward: IC={np.mean(ics):+.4f}±{np.std(ics):.4f}  "
              f"WinRate={np.mean(ics>0):.0%}  n={len(ics)}")
    
    # 公式多样性（RL 专用）
    if logger.n_unique_formulas:
        n_uniq = logger.n_unique_formulas[-1]
        avg_len = logger.avg_formula_lengths[-1] if logger.avg_formula_lengths else 0
        print(f"\n  Formulas:    Unique={n_uniq}  AvgLen={avg_len:.1f} tokens")
    
    # 耗时
    elapsed = time.time() - logger.start_time
    if last_step > 0:
        time_per_step = elapsed / last_step
        remaining_steps = total_expected - last_step
        eta = remaining_steps * time_per_step
        print(f"\n  Time:        Elapsed={elapsed/60:.1f}min  "
              f"PerStep={time_per_step:.1f}s  ETA={eta/60:.1f}min")
    
    # 警告
    warnings = []
    if logger.step_rewards and len(logger.step_rewards) > 20:
        last_20 = np.array(logger.step_rewards[-20:])
        if np.all(last_20 == last_20[0]):
            warnings.append("⚠️  Loss plateaued (last 20 steps unchanged)")
        if np.any(np.isnan(last_20)):
            warnings.append("🔥 NaN detected in last 20 steps!")
    if logger.n_unique_formulas and len(logger.n_unique_formulas) > 20:
        if np.mean(logger.n_unique_formulas[-20:]) < 5:
            warnings.append("🔥 Formula collapse (<5 unique)")
    if warnings:
        print(f"\n  {'─'*50}")
        for w in warnings:
            print(f"  {w}")
    
    print("\n" + "=" * 60 + "\n")
```

---

### 三、自动化脚本

#### 3.1 训练内联日志 + 可视化钩子

```python
# training_utils/viz_hooks.py
# 在训练脚本中引入的轻量钩子，自动记录并周期性生成可视化

import time
import json
import numpy as np
from pathlib import Path

def create_training_hooks(output_dir, plot_interval=50, log_interval=10):
    """创建训练可视化钩子。
    
    用法：
        hooks = create_training_hooks('./results/my_experiment')
        
        for step in range(total_steps):
            loss, metrics = train_one_step()
            hooks['log'](step, loss, **metrics)
            
            if step % plot_interval == 0:
                hooks['plot']()
        
        hooks['finalize']()  # 训练结束生成完整报告
    """
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    
    state = {
        'steps': [],
        'values': [],
        'best_values': [],
        'gpu_vram': [],
        'gpu_util': [],
        'step_times': [],
        'wf_ics': [],
        'n_unique': [],
        'avg_len': [],
        'start_time': time.time(),
    }
    
    def try_get_gpu():
        """尝试获取 GPU 信息，失败则返回 None。"""
        try:
            import subprocess
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.used,utilization.gpu',
                 '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                parts = result.stdout.strip().split(',')
                return float(parts[0].strip()), float(parts[1].strip())
        except Exception:
            pass
        return None, None
    
    def log_step(step, value, best_value=None, n_unique=None, avg_len=None):
        state['steps'].append(step)
        state['values'].append(float(value) if not np.isnan(value) else 0.0)
        state['best_values'].append(float(best_value) if best_value is not None else value)
        state['step_times'].append(time.time())
        
        vram, util = try_get_gpu()
        if vram is not None:
            state['gpu_vram'].append(vram)
            state['gpu_util'].append(util)
        if n_unique is not None:
            state['n_unique'].append(n_unique)
        if avg_len is not None:
            state['avg_len'].append(avg_len)
        
        # 终端日志（每 log_interval 步）
        if step % log_interval == 0:
            elapsed = time.time() - state['start_time']
            gpu_str = f" | GPU:{vram:.0f}MB/{util:.0f}%" if vram else ""
            formula_str = f" | Uniq:{n_unique}" if n_unique else ""
            print(f"Step {step:5d} | Value={value:+.4f} | Best={state['best_values'][-1]:+.4f} "
                  f"| {elapsed:.0f}s{gpu_str}{formula_str}")
    
    def generate_plots(suffix=''):
        """生成当前所有可视化。"""
        if len(state['steps']) < 2:
            return []
        
        # 构造临时 logger 对象
        class TempLogger:
            pass
        logger = TempLogger()
        logger.steps = state['steps']
        logger.step_rewards = state['values']
        logger.best_scores = state['best_values']
        logger.step_times = state['step_times']
        logger.gpu_vram = state['gpu_vram']
        logger.gpu_util = state['gpu_util']
        logger.wf_ics = state['wf_ics']
        logger.n_unique_formulas = state['n_unique']
        logger.avg_formula_lengths = state['avg_len']
        logger.feature_families = []
        logger.grad_norms = {}
        logger.entropy_history = {}
        
        return save_all_plots(str(out / 'plots'), logger, suffix)
    
    def finalize(wf_ics=None):
        """训练结束：生成最终报告 + 保存 metrics JSON。"""
        if wf_ics:
            state['wf_ics'] = list(wf_ics)
        
        # 生成最终图
        files = generate_plots('_final')
        
        # 保存 metrics JSON
        metrics = {
            'total_steps': len(state['steps']),
            'best_value': float(np.max(state['values'])) if state['values'] else 0,
            'final_value': float(state['values'][-1]) if state['values'] else 0,
            'mean_last_50': float(np.mean(state['values'][-50:])) if len(state['values']) >= 50 else 0,
            'duration_s': time.time() - state['start_time'],
            'wf_mean_ic': float(np.mean(state['wf_ics'])) if state['wf_ics'] else None,
            'wf_std_ic': float(np.std(state['wf_ics'])) if state['wf_ics'] else None,
            'wf_wins': int(np.sum(np.array(state['wf_ics']) > 0)) if state['wf_ics'] else 0,
        }
        with open(out / 'training_metrics.json', 'w') as f:
            json.dump(metrics, f, indent=2)
        
        # 终端输出最终摘要
        print_ascii_dashboard_mock(state)
        
        return files, metrics
    
    def print_ascii_dashboard_mock(st):
        """简化版 ASCII 仪表板。"""
        values = np.array(st['values'])
        n = len(values)
        print("\n" + "=" * 55)
        print("  📊 FINAL TRAINING SUMMARY")
        print("=" * 55)
        print(f"  Steps: {n}  |  Duration: {(time.time() - st['start_time'])/60:.1f} min")
        if n > 0:
            print(f"  Best:  {np.max(values):+.4f}  |  Final: {values[-1]:+.4f}  |  Last 50 mean: {np.mean(values[-min(50,n):]):+.4f}")
        if st['wf_ics']:
            ics = np.array(st['wf_ics'])
            print(f"  WF IC: {np.mean(ics):+.4f} ± {np.std(ics):.4f}  |  WinRate: {np.mean(ics>0):.0%}  |  n={len(ics)}")
        if st['n_unique']:
            print(f"  Formulas: Unique={st['n_unique'][-1]}  |  AvgLen={st['avg_len'][-1]:.1f}" if st['avg_len'] else f"  Formulas: Unique={st['n_unique'][-1]}")
        print("=" * 55 + "\n")
    
    return {
        'log': log_step,
        'plot': generate_plots,
        'finalize': finalize,
        'state': state,
    }
```

#### 3.2 训练后离线报告生成器

```bash
# 独立脚本：从 training_metrics.json 生成可视化报告
# 位置：项目根目录/scripts/generate_training_report.py

# 用法：
# python scripts/generate_training_report.py results/my_experiment/
# 
# 输出：
#   results/my_experiment/plots/   — 所有 PNG 图
#   results/my_experiment/report.html  — 单页 HTML 报告（可选）
```

```python
#!/usr/bin/env python3
"""独立训练报告生成器。从 metrics.json 重新生成可视化，不依赖训练代码。"""
import sys, json, argparse
from pathlib import Path


def generate_html_report(result_dir: Path, metrics: dict):
    """生成单页 HTML 报告，把所有 PNG 图嵌入并附指标摘要。"""
    plots_dir = result_dir / 'plots'
    img_html = ""
    if plots_dir.exists():
        for img in sorted(plots_dir.glob('*.png')):
            rel = img.relative_to(result_dir)
            caption = img.stem.replace('_', ' ').title()
            img_html += (
                f'    <figure>\n'
                f'      <img src="{rel}" alt="{caption}" loading="lazy">\n'
                f'      <figcaption>{caption}</figcaption>\n'
                f'    </figure>\n'
            )
    metric_rows = "\n".join(
        f"    <tr><td>{k}</td><td>{v!r}</td></tr>"
        for k, v in metrics.items()
    )
    html = f"""<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="utf-8">
  <title>Training Report - {result_dir.name}</title>
  <style>
    body {{ font-family: 'Noto Sans CJK SC', 'DejaVu Sans', sans-serif; margin: 2em; background: #f7f7f7; }}
    h1 {{ color: #2c3e50; }}
    table {{ border-collapse: collapse; margin-bottom: 2em; }}
    td, th {{ border: 1px solid #ccc; padding: 6px 12px; }}
    th {{ background: #ecf0f1; }}
    figure {{ display: inline-block; margin: 1em; }}
    figcaption {{ font-size: 0.85em; color: #555; text-align: center; }}
  </style>
</head>
<body>
  <h1>Training Report</h1>
  <h2>Metrics</h2>
  <table>
    <tr><th>Metric</th><th>Value</th></tr>
{metric_rows}
  </table>
  <h2>Plots</h2>
{img_html}
</body>
</html>
"""
    out_path = result_dir / 'report.html'
    out_path.write_text(html, encoding='utf-8')
    print(f"   HTML report written to: {out_path}")


def main():
    parser = argparse.ArgumentParser(description='Generate training visualization report')
    parser.add_argument('result_dir', help='Path to training output directory')
    parser.add_argument('--html', action='store_true', help='Also generate HTML report')
    args = parser.parse_args()
    
    result_dir = Path(args.result_dir)
    metrics_file = result_dir / 'training_metrics.json'
    
    if not metrics_file.exists():
        print(f"❌ {metrics_file} not found. Run training first.")
        sys.exit(1)
    
    with open(metrics_file) as f:
        metrics = json.load(f)
    
    # 从 metrics 重建 plot
    # （简化版——扩展时补全从 state 恢复的代码）
    print(f"✅ Metrics loaded: {metrics['total_steps']} steps, best={metrics['best_value']:.4f}")
    print(f"   Plots saved to: {result_dir / 'plots'}/")
    
    if args.html:
        generate_html_report(result_dir, metrics)

if __name__ == '__main__':
    main()
```

---

### 四、常见视觉故障签名

训练图上的异常模式往往是 bug 的第一信号。以下签名及对应诊断：

| 视觉签名 | 图上表现 | 根因 | 优先检查 |
|---------|---------|------|---------|
| **死亡心电图** | Loss = 常数，完全不变（一条水平线） | 学习率 = 0 / 梯度为 0 / 优化器未 step | `optimizer.zero_grad()` 和 `optimizer.step()` 是否都在循环内 |
| **NaN 深渊** | Loss 突然跳到 NaN 且不再恢复 | 数值溢出 / 除零 / log(0) | 检查输入是否有极端值、loss 计算中有无 `log(0)`、`x/0` |
| **锯齿振荡** | Loss 每 2 步大幅摆动 | 学习率过高 / batch 过小 | 降低 LR 至 1/10、增大 batch size 至 2× |
| **水平反弹** | Loss 下降到某点后反弹上升 | 过拟合 | 在反弹点前取 checkpoint，加正则化 |
| **阶梯下降** | Loss 在某个步数突然跳降 | LR scheduler 生效 / 数据 pipeline 切换 | 正常现象——确认跳降点与 scheduler 步数对齐 |
| **IC 彩虹** | Walkforward IC 正负交替，颜色红绿交替 | 信号 = 噪声，模型在拟合 0 | 检查置换检验 p 值，大概率不显著 |
| **VRAM 斜坡** | VRAM 持续线性增长（>5 MB/step） | 显存泄漏——tensor 未释放 | 检查 `loss.backward()` 后是否 `del loss`；动态图是否有 `torch.cat` 累积 |
| **GPU 心电图** | GPU 利用率从 0 跳到 100 来回 | CPU 瓶颈：数据加载慢 | 增加 DataLoader workers、预加载数据到 GPU |
| **熵雪崩** | 某层熵从高值骤降到 0 | 复制器/路由器坍缩到单峰 | 降低 learning rate、提高 temperature、添加熵正则 |
| **公式克隆大军** | n_unique 从 200 降到 5 | RL 模式坍塌 | 增大 exploration noise、减小 exploitation weight |

---

### 五、看门狗集成

在 watchdog 状态 JSON 中，每个任务的完成状态应包含可视化报告路径：

```python
# 看门狗保存状态时追加
status["tasks"][task_name]["plots"] = [
    f"results/{task_name}/plots/loss_curve_final.png",
    f"results/{task_name}/plots/gpu_timeline_final.png",
    f"results/{task_name}/plots/walkforward_panel_final.png",
]
status["tasks"][task_name]["metrics_json"] = f"results/{task_name}/training_metrics.json"
```

Agent 拉取可视化报告的命令模板（记录在 scratchpad 中）：

```bash
# 从远程服务器拉取所有训练的可视化报告
RSYNC_CMD="rsync -avz --partial -e 'ssh -p PORT' user@server:/path/results/*/plots/ ./local_reports/"

# 或在远程服务器上直接用 ASCII 仪表板查看
ssh user@server "cd /path && python3 -c \"
import json
from pathlib import Path
for d in Path('results').iterdir():
    mf = d / 'training_metrics.json'
    if mf.exists():
        m = json.load(open(mf))
        print(f'{d.name}: best={m[\"best_value\"]:+.4f}  wf_ic={m.get(\"wf_mean_ic\",\"N/A\")}')
\""
```

---

### 六、可视化启动前清单（已并入主清单）

可视化相关的启动前检查项已全部并入 §【启动前检查清单】的“可视化”分组下——不再重复维护第二份清单。

---

### 七、快速验收流程（Agent 视角）

当 Agent 被要求检查训练结果时，按以下顺序验收：

```
1. 拉取 training_metrics.json
   → 按 “量化验收阈表” 逐项判别（见下）

2. 拉取三张核心图
   → loss_curve_final.png：有无 NaN 深渊 / 水平反弹
   → walkforward_panel_final.png：IC 是否稳定 / 窗口是否全正或全负
   → gpu_timeline_final.png：有无 VRAM 泄漏 / GPU 利用率低下

3. 如果需要深入诊断
   → formula_evolution_final.png（RL 训练）：有无模式坍塌
   → dl_health_final.png（DL 训练）：有无熵雪崩 / 梯度消失
   → lr_schedule.png / calibration.png / attention_map.png / formula_hof.png（按需补充，见 §八）

4. 结论输出格式
   ✅ 通过 / ⚠️ 有风险 / 🔥 需重新训练
   附关键图路径 + 偏离阈表的具体数值（不能只写“看起来不错”）
```

**不需要拉取所有图。三张核心图中的信息已经覆盖 90% 的训练问题。**

### 量化验收阈表（2026-07-24，跨领域经验总结）

下表为 ✅/⚠️/🔥 判定的量化依据。任一核心指标落入 ⚠️ 列即记一个风险点；
任一指标落入 🔥 列、或触发底表硬故障任何一项，，则直接判 🔥 需重训。
阈值为经验值，可按项目 baseline 上调不以下调。

| 指标 | ✅ 通过 | ⚠️ 有风险 | 🔥 需重训 | 来源 |
|:---|:---|:---|:---|:---|
| 窗口均值 IC（量化因子） | ≥ +0.050 | +0.030 ~ +0.050 | < +0.030 或负 | 期货 IC=0.077 反馈 |
| Walkforward 胜率 | ≥ 60% | 50–60% | < 50% | 二项检验临界 |
| IC 退化率（quick vs full IC） | < 35% | 35–60% | > 60% | v1=48%, v3=77% |
| 公式多样性 `n_unique` | ≥ 30 | 10–30 | < 10 | RL 坍塌典型 200→5 |
| 单一特征家族占比 | < 30% | 30–80% | ≥ 80% | 期货 v3 坍塌 |
| Token / 参数比（DL） | ≥ 20:1 | 5–20:1 | < 5:1 | Transformer LM 经验 |
| Loss 末步与 best 差距 | ≤ best×10% | 10%–50% | > 50% 或 NaN | “水平反弹”量化 |
| VRAM 趋势性增长 | < +1 MB/step | +1~+5 MB/step | ≥ +10 MB/step | RTX 3080 泄漏案例 |
| GPU 平均利用率 | > 70% 持续 | 30–70% | < 30% 或随机跳变 | “GPU 心电图”信号 |
| 末层熵（DL复制器/路由器） | ≥ 0.5×ln(L) | 0.1~0.5×ln(L) | < 0.1×ln(L) | “熵雪崩” ⇒ “复制器坍缩” |
| 目标步数完成率 | ≥ 95% | 80–95% | < 80%或重试 3 次全败 | 看门狗极限 |
| 置换检验 p 值 | < 0.05 | 0.05–0.5 | ≥ 0.5 | 金标准：n_perm≥2000 |

**硬故障（任一项出现即判 🔥，无视上表）：**

- 训练中途出现 NaN 且下一轮未自愈
- 任一 Walkforward 窗口 IC > +0.30 但其他窗口全部 < 0 → 单窗奇点，奇点不是信号
- OOM / 段错误 / OOM killer 启动
- 检验对象偏误（§模式 F）：p 值贴在对象上与报告对象不一致
- 前瞻偏误（§模式 D / §陷阱 1）：`update-before-fuse` 或全序列 z-score
- 部署方向偏误（§陷阱 2）：RL `deploy_sign` 未验证即部署
- 特征复制（§模式 C）或 dup corr > 0.999

**验收输出示例：**
`IC=+0.054 (阈 +0.050 → ✅); 胜率=67% (≥60 → ✅); VRAM 趋势=+0.3 MB/step (<+1 → ✅); 三图无异常 → ✅ 通过`。
不要输出“看起来不错”这种无数字结论。
---

## 八、扩展可视化（第二部分）

> 本节补充 §一 / §二、三未覆盖的专用图与运维类准则。代码块均为可复制、互不依赖。
> §五的 announcement（"§VIII Rule Zero 闭环"）指的是 §8.9。

### 8.1 学习率调度可视化（C8）

LR 是最高频人工调节项。LR 走势凌乱会在 loss 曲线上表现为"锯齿振荡 / 阶梯下降"，但只看 loss 反推 LR 的因果链很弱——必须单独画 LR。

```python
def plot_lr_schedule(lr_history, loss_history=None, milestone_steps=None):
    """学习率随训练步数的曲线，可叠加 loss 与 LR milestone（warmup、decay 阶段分界）。

    lr_history:     list[float] 每步 LR
    loss_history:   可选 list[float]，叠加到右侧 secondary y 轴
    milestone_steps: dict[int, str] 标注 LR 变速的关键步（即 scheduler.milestone）
    """
    import numpy as np, matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(14, 5))
    steps = np.arange(len(lr_history))
    ax.plot(steps, lr_history, color="#d35400", linewidth=1.5, label="LR")
    ax.set_xlabel("Step"); ax.set_ylabel("Learning Rate")
    ax.set_yscale("log")
    ax.grid(True, alpha=0.3)
    if loss_history is not None:
        ax2 = ax.twinx()
        ax2.plot(steps, loss_history, alpha=0.4, color="steelblue", linewidth=0.5, label="Loss")
        ax2.set_ylabel("Loss", color="steelblue")
    if milestone_steps:
        for st, label in milestone_steps.items():
            if st < len(lr_history):
                ax.axvline(x=st, color="purple", linestyle=":", linewidth=0.8)
                ax.text(st, lr_history[st], f" {label}", rotation=90,
                        fontsize=7, verticalalignment="top", color="purple")
    ax.legend(loc="upper right"); ax.set_title("LR Schedule" + (" + Loss" if loss_history is not None else ""))
    return fig
```

| 诊断信号 | 根因 |
|---------|------|
| LR 平台期 vs' Loss 振荡同步 | scheduler 未激活；检查 `scheduler.step()` 调用频率是否与 step 一致 |
| LR 单调下降后 loss 仍全走平 | LR 衰减过快，温度太高使模型进入"深冻" → 尝试 cosine 衰减而非指数 |
| LR warmup 末 步点 突跳 | warmup 倾为 LR×10 ↑ → 用 gradient clip、分阶段 warmup |
| LR 突然归零 | `ReduceLROnPlateau` 在 plateau 后可能一路隇到极小值；加 LR_min 额阈值下项 |

### 8.2 预测校准可视化（C9，回归模型专用）

IC 表示秩相关 ≠ 预测的准确性。一个模型可能 IC=0.07 但预测偏度高却项实际弯曲，上一个模型 IC=0.06 但预测压平等。预测 vs 实际散点图与 Rank Calibration 曲线刻画了除 IC 以外的预测质量。

```python
def plot_calibration_scatter(predictions, actuals, n_buckets=10, title="Calibration"):
    """预测与实际散点 + 压分桶（按预测分位厚度）均值-\u0000竖线更多。

    predictions: (N,) 模型预测标量分位
    actuals:    (N,) 实际未来收益 / 标签
    """
    import numpy as np, matplotlib.pyplot as plt
    preds = np.asarray(predictions, dtype=float)
    acts = np.asarray(actuals, dtype=float)
    mask = np.isfinite(preds) & np.isfinite(acts)
    preds, acts = preds[mask], acts[mask]

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    # 左：散点图（-alpha 密度 设偏/a重 pl<=0.7 凸视角）
    ax = axes[0]
    ax.scatter(preds, acts, s=3, alpha=0.25, color="steelblue")
    # 主极岭回归拟合线
    if len(preds) > 2:
        m, b = np.polyfit(preds, acts, 1)
        xs = np.linspace(preds.min(), preds.max(), 100)
        ax.plot(xs, m * xs + b, color="red", linewidth=1.5, label=f"y={m:.3f}x+{b:.4f}")
        ax.legend(fontsize=9)
    ax.axhline(0, color="gray", linestyle="--", linewidth=0.5)
    ax.axvline(0, color="gray", linestyle="--", linewidth=0.5)
    ax.set_xlabel("Predicted"); ax.set_ylabel("Actual")
    ax.set_title(f"Scatter (n={len(preds)}, r={np.corrcoef(preds, acts)[0,1]:+.3f})")
    ax.grid(True, alpha=0.3)

    # 右：按预测分桶，计算每桶预测均值 / 实际均值 / SE
    ax = axes[1]
    if len(preds) >= n_buckets:
        order = np.argsort(preds)
        bucket = np.array_split(order, n_buckets)
        b_mean_pred = [np.mean(preds[b]) for b in bucket]
        b_mean_act = [np.mean(acts[b]) for b in bucket]
        b_std_act = [np.std(acts[b]) / max(np.sqrt(len(b)), 1) for b in bucket]
        ax.errorbar(b_mean_pred, b_mean_act, yerr=b_std_act, marker="o", color="steelblue",
                    ecolor="lightgray", capsize=3, label="Bucketed mean ± SE")
        xs = np.linspace(min(b_mean_pred), max(b_mean_pred), 100)
        ax.plot(xs, xs, color="black", linestyle=":", linewidth=0.8, label="Ideal (45°)")
        ax.legend(fontsize=9)
    ax.set_xlabel("Mean Predicted (per bucket)"); ax.set_ylabel("Mean Actual (per bucket)")
    ax.set_title(f"{title} — Calibration Curve")
    ax.grid(True, alpha=0.3)
    return fig
```

**诊断信号**：

| 形态 | 含义 | 行动 |
|---|---|---|
| 拟合线斜率 < 0 | 信号方向反了 | 先验证 RL 的 `deploy_sign` 符号（§陷阱 2），修复后再对比 |
| 斜率绝对值很小（例如 \|m\| < 0.05） | IC 弱，预测幅度与实际不对应 | 检查数据归一化、窗口是否有前瞻统计偏误（§陷阱 1） |
| 校准曲线明显弯曲（S/凹/凸） | 信号非线性，线性 Ridge 不足 | RL 公式表达时保留；极值段过多偏移则在公式内 winsorize |
| 散点存在孤立远点 | 个别样本不遵信号，拉偏全局拟合 | 检查停牌 / 涨跌停覆盖不足样本 |

### 8.3 RL 公式 Hall of Fame（C10）

公式发现最重要的输出是“公式本身”，而非仅看多样性数字。这张图直接在图面文本渲染 Top-K 公式。

```python
def plot_formula_hall_of_fame(top_formulas, n=10, title="Top K Formulas"):
    """RL 训练过程中按 IC 排名的 Top-K 公式，在图上直接渲染公式字符串。
    top_formulas: list[dict] 每项含 ('ic', 'formula_str', 可选 'n_tokens')
    """
    import matplotlib.pyplot as plt, numpy as np
    n = min(n, len(top_formulas))
    fig, ax = plt.subplots(figsize=(14, max(6, 0.8 * n)))
    formulas = top_formulas[:n]
    ics = [f.get("ic", 0) for f in formulas]
    texts = [f.get("formula_str", "?") for f in formulas]
    toks = [f.get("n_tokens", len(f.get("formula_str", "")) // 5) for f in formulas]
    colors = ["#27ae60" if v < 0 else "#2ecc71" for v in ics]
    bars = ax.barh(np.arange(n)[::-1], ics, color=colors, alpha=0.7)
    ax.set_yticks(np.arange(n)[::-1])
    ax.set_yticklabels([f"#{i+1}" for i in range(n)], fontsize=10)
    ax.axvline(0, color="black", linewidth=0.5)
    for i, (ic, txt, tk) in enumerate(zip(ics, texts, toks)):
        ax.text(ic + 0.002 * max(1, abs(ics[0])), n - i - 1, f" {txt}", va="center",
                ha="left", fontsize=8, fontfamily="monospace", color="#2c3e50")
    ax.set_xlabel("IC"); ax.set_title(title)
    return fig
```

**诊断信号**：

- Top-K 中 > 80% 是同一特征家族变体（如 `SIGN(close_vs_range)`、`SIGN(SIGN(close_vs_range))`）→ 模式坍塌。参见 §"常见视觉故障签名"中"公式克隆大军"。
- 同一段公式串出现在多个 rank（多个 rank `formula_str` 完全相同）→ RL 去重逻辑被击穿，检查 `FormulaRegistry` lifecycle 去重。
- 公式单调变长（n_tokens 持续增长）→ RL 在堆 GATE 刷分，限 `max_tokens` 并抑制 GATE 嵌套奖励。

### 8.4 多种子聚合阴影图（C11）

单一种子结果可能是运气。关键结论必须用 3-5 个种子复跑，画均值 ± std 的阴影曲线，而非单条线。

```python
def plot_multi_seed_curves(seed_results, title, agg="mean"):
    """seed_results: dict[seed_name, list[float]] 多个种子的指标序列。
    agg: 'mean'（默认）或 'median'
    """
    import numpy as np, matplotlib.pyplot as plt
    names = list(seed_results.keys())
    n_steps = max(len(v) for v in seed_results.values())
    matrix = []
    for nm in names:
        vals = np.array(seed_results[nm], dtype=float)
        vals = np.concatenate([vals, [np.nan] * (n_steps - len(vals))])
        matrix.append(vals)
    matrix = np.array(matrix)
    steps = np.arange(n_steps)
    center = (agg == "median") and np.nanmedian(matrix, axis=0) or np.nanmean(matrix, axis=0)
    sigma = np.nanstd(matrix, axis=0)

    fig, axes = plt.subplots(1, 2, figsize=(16, 5))
    ax = axes[0]
    ax.fill_between(steps, center - sigma, center + sigma, alpha=0.25,
                    color="steelblue", label="mean ± σ")
    ax.plot(steps, center, color="steelblue", linewidth=1.5, label="mean")
    for nm in names:
        ax.plot(seed_results[nm], alpha=0.3, linewidth=0.5,
                linestyle="--", color="gray")
    ax.axhline(0, color="black", linestyle="--", linewidth=0.5)
    ax.set_xlabel("Step"); ax.set_ylabel(title)
    ax.set_title(f"Multi-Seed ({len(names)} runs)")
    ax.legend(fontsize=9); ax.grid(True, alpha=0.3)

    ax = axes[1]
    bests = [np.nanmax(seed_results[s]) for s in names]
    ax.bar(range(len(names)), bests, color="steelblue", alpha=0.7)
    ax.axhline(np.nanmean(bests), color="red", linestyle="--", linewidth=1,
              label=f"Best mean = {np.nanmean(bests):+.4f} ± {np.nanstd(bests):.4f}")
    ax.set_xticks(range(len(names)))
    ax.set_xticklabels(names, fontsize=9)
    ax.set_ylabel("Best IC (per seed)")
    ax.set_title("Per-seed best IC")
    ax.legend(fontsize=9); ax.grid(True, alpha=0.3, axis="y")
    return fig
```

| 形态 | 含义 | 行动 |
|---|---|---|
| 阴影带宽 > average 的 30% | 种子间波动过大，单种子不可信 | 增加种子数至 5+；检查探索噪声 / 评估方差 |
| 多颗种子稳定落在阈值上方 | robust | 不需再补跑 |
| 一两颗种子突破阈值、其余未达 | 种子选择偏误 | 报告均值 + 区间，不可单挑最好种子 |

### 8.5 Transformer Attention 可视化（C12, DL 专用）

专为 Gehirnskrieg 等模型设计：注意力不能再只看 loss 曲线，需要看信息流。

```python
def plot_attention_map(attn_weights, tokens=None, head_indices=None, step=None):
    """attn_weights: [H, Tq, Tkv] — head, query, kv 维度。
    head_indices: 显示哪几个 head；None 取前 4 个。
    """
    import numpy as np, matplotlib.pyplot as plt
    H, Tq, Tkv = attn_weights.shape
    if head_indices is None:
        head_indices = list(range(min(4, H)))
    n = len(head_indices)
    fig, axes = plt.subplots(1, n, figsize=(n * 4 + 1, 4))
    if n == 1: axes = [axes]
    for idx, h in enumerate(head_indices):
        ax = axes[idx]
        m = attn_weights[h]
        if hasattr(m, "cpu"): m = m.cpu().numpy()
        else: m = np.array(m)
        im = ax.imshow(m, aspect="auto", cmap="viridis")
        ax.set_title(f"Head {h}")
        ax.set_xlabel("KV position"); ax.set_ylabel("Query position")
        if tokens is not None:
            step_tk = max(1, len(tokens) // 8)
            if len(tokens) == m.shape[0]:
                ax.set_yticks(range(0, len(tokens), step_tk))
                ax.set_yticklabels(tokens[::step_tk], fontsize=6)
            if len(tokens) == m.shape[1]:
                ax.set_xticks(range(0, len(tokens), step_tk))
                ax.set_xticklabels(tokens[::step_tk], rotation=90, fontsize=6)
        plt.colorbar(im, ax=ax)
    if step is not None:
        fig.suptitle(f"Step {step}")
    plt.tight_layout()
    return fig
```

| 形态 | 含义 | 行动 |
|---|---|---|
| 多个 head 都呈对角线（位置只看自己） | 注意力未扩散，模型只看自己位置 | 检查 causal mask 是否被误用、位置编码是否生效 |
| 注意力全部集中在前几个 KV（如 BOS / EOS） | padding token 变成了 focal point | 检查 padding mask，但 attention 不允许计算 padding 行 |
| 不同 head 在热图形态几乎一致 | head 缺乏多样性，等价合并 | 评估是否可以剪掉冗余 head；检查 attention 分散度 |

### 8.6 可视化误导陷阱（C13）

图本身也会骗人。以下陷阱会让 Agent 从正确的图中得出错误结论：

| 陷阱 | 表现 | 后果 | 防御 |
|:---|:---|:---|:---|
| **SMA 过宽抹平拐点** | window=200 时把 loss 突变抹成平滑曲线 | 误判"训练稳定"实则有过 spike | 永远同时看 raw + SMA；SMA window 不超过总步数的 10% |
| **y 轴自动缩放掩盖异常** | IC 图 y 轴 [-0.5, +0.5] vs [-0.05, +0.05] 看起来趋势一样 | 量级差 10× 的信号在缩放后看起来"差不多" | 固定 y 轴范围或标注 y 轴实际值域 |
| **相关≠因果** | κ 与 forward vol 散点正相关 → 声称"κ 预测 vol" | 可能是第三个变量（如 VIX）同时驱动两者 | 画偏相关图、加控制变量 |
| **幸存者偏差图** | 只画"最好种子"的曲线 | 多种子阴影图（§8.4）揭示其余种子全负 | 永远画 multi-seed，不挑最好 |
| **颜色误导** | 热图 colormap 从蓝到红但中点不对应零 | 正负 IC 混在一起看不出符号 | 用 `RdBu_r` colormap + `center=0`（imshow 时 `vmin=-vmax`） |
| **时间轴不等距** | checkpoint 保存间隔不等（前密后疏）但仍画成等距 x 轴 | 前期密看起来"变化剧烈"是假象 | x 轴用实际 step 编号而非序号 |
| **单窗 IC 放大全局** | bar chart 中 W3 IC=+0.30 高高竖起 | 该窗奇点而非全域信号（§量化验收阈表硬故障行 2） | 标注 mean IC 线 + 置换检验 p 值 |

**自检规则**：每张图生成后，先问三个问题——

1. y 轴范围是多少？是否掩盖了量级差异？
2. 平滑窗口是否过宽，把真实的 spike 抹掉了？
3. 这是单次结果还是多种子聚合？如果是单次，标注 `⚠️ single seed`。

### 8.7 自动告警阈值与主动 kill（C14）

当前可视化仅由人观看；无人时训练在 NV 损失 / VRAM 泄漏 / 熵坍塌下静默跑完全程浪费时间。以下阈值触发后由监控守护进程主动 kill 并报告：

```python
# 以下阈值与 §量化验收阈表的 🔥 列严格对齐
ALERT_THRESHOLDS = {
    "vram_slope_mb_per_step": +10,    # VRAM 趋势 > 10 MB/step → 泄漏
    "loss_nan_consecutive":    3,     # 连续 3 步 NaN → kill
    "entropy_collapse_ratio":  0.1,    # 熵 < 0.1×ln(L) → 坍塌
    "formula_unique_floor":    5,     # n_unique < 5 持续 20 步 → 坍塌
    "gpu_util_floor_pct":     10,     # GPU util < 10% 持续 60 步 → CPU 瓶颈或死锁
    "step_time_blowup_x":       5,     # 单步耗时 > 历史均值×5 → 无限循环风险
}

def should_alert_kill(logger, thresholds=ALERT_THRESHOLDS):
    """返回 (bool kill, str reason)。在每步 log 后调用。"""
    import numpy as np
    n = len(logger.step_rewards)
    if n < 20:
        return False, ""

    vals = np.array(logger.step_rewards[-20:], dtype=float)

    # 1. 连续 NaN
    if np.isnan(vals[-3:]).all():
        return True, f"loss NaN x3 consecutive at step {logger.steps[-1]}"

    # 2. VRAM 趋势
    if len(logger.gpu_vram) > 20:
        recent = logger.gpu_vram[-20:]
        slope = np.polyfit(range(20), recent, 1)[0]
        if slope > thresholds["vram_slope_mb_per_step"]:
            return True, f"VRAM leak: {slope:+.1f} MB/step (>{thresholds['vram_slope_mb_per_step']})"

    # 3. 熵坍塌
    for name, ents in logger.entropy_history.items():
        if len(ents) > 10:
            last_10 = ents[-10:]
            max_ent = np.log(len(last_10)) if len(last_10) > 1 else 1
            if max_ent > 0 and np.mean(last_10) < thresholds["entropy_collapse_ratio"] * max_ent:
                return True, f"Entropy collapse: {name} mean={np.mean(last_10):.3f} (<{thresholds['entropy_collapse_ratio']:.1f}×ln(L)={max_ent:.3f})"

    # 4. 公式坍塌
    if len(logger.n_unique_formulas) > 20:
        if np.mean(logger.n_unique_formulas[-20:]) < thresholds["formula_unique_floor"]:
            return True, f"Formula collapse: n_unique <{thresholds['formula_unique_floor']} for 20 steps"

    # 5. GPU 死锁
    if len(logger.gpu_util) > 60:
        if np.mean(logger.gpu_util[-60:]) < thresholds["gpu_util_floor_pct"]:
            return True, f"GPU dead: util <{thresholds['gpu_util_floor_pct']}% for 60 steps"

    # 6. 单步耗时暴涨
    if len(logger.step_times) > 20:
        step_durs = np.diff(logger.step_times[-21:])
        if len(step_durs) > 0:
            mean_dur = np.mean(step_durs[:-3])
            if mean_dur > 0 and step_durs[-1] > mean_dur * thresholds["step_time_blowup_x"]:
                return True, f"Step blowup: {step_durs[-1]:.1f}s > {thresholds['step_time_blowup_x']}× mean {mean_dur:.1f}s"

    return False, ""
```

**集成位置**：在 `create_training_hooks` 的 `log_step` 末尾调用。

```python
# 在 hooks['log'] 函数末尾追加
kill, reason = should_alert_kill(dummy_logger_from_state(state))
if kill:
    print(f"🔥 AUTO-KILL: {reason}")
    state['kill_reason'] = reason
    generate_plots('_kill')   # 保留最后一张图
    raise SystemExit(1)       # 或发信号给训练进程
```

**与看门狗集成**：看门狗检测到非零退出码 + `kill_reason` 字段时，状态记为 `auto_killed`（而非 `crashed`），不自动重试——因为重试会以同样参数重现同一问题。

### 8.8 图文件管理与磁盘保护（C15）

远程服务器磁盘常 < 100 GB。多实验 × 9 类图 × 多 checkpoint 很快吃满磁盘。

**保留策略**：

```python
def cleanup_plots(output_dir, keep_checkpoints=3, keep_final=True):
    """清理中间 checkpoint 的可视化图，只保留最近 N 份 + final。"""
    from pathlib import Path
    import re
    plot_dir = Path(output_dir) / 'plots'
    if not plot_dir.exists():
        return 0
    # 按 suffix 分组：_step50, _step100, ..., _final, _kill
    groups = {}
    for f in plot_dir.glob('*.png'):
        m = re.search(r'_(step\d+|final|kill)$', f.stem)
        suffix = m.group(1) if m else 'other'
        groups.setdefault(suffix, []).append(f)
    deleted = 0
    for suffix, files in groups.items():
        if suffix == 'final' or suffix == 'kill':
            continue  # 永久保留
        if not suffix.startswith('step'):
            continue
        files.sort(key=lambda f: int(re.search(r'step(\d+)', f.stem).group(1)))
        # 删除旧的，只保留最近 keep_checkpoints 份
        for f in files[:-keep_checkpoints]:
            f.unlink()
            deleted += 1
    return deleted
```

**磁盘占用估算**（单张 PNG ~100 KB @ 100 dpi）：

| 场景 | 实验数 | 图类别 | checkpoint | 总大小 |
|:---|:---|:---|:---|:---|
| 单实验 | 1 | 9 | 10 | ~9 MB |
| 看门狗 6 任务 | 6 | 9 | 10 | ~54 MB |
| 长训练 500 步 × plot_every=50 | 1 | 3 核心 | 10 | ~3 MB |
| 看门狗 6 任务 × 多种子 5 | 30 | 9 | 10 | ~270 MB |

**规则**：
- 烟雾测试图（`/tmp/smoke_test/plots/`）在完整训练启动后删除
- `_kill` 图永久保留（对 bug 复现至关重要）
- 磁盘 < 10 GB 时触发清理（调用 `cleanup_plots`，保留 `keep_checkpoints=1`）
- HTML 报告（`report.html`）总大小 < 1 MB，可忽略

### 8.9 Rule Zero 闭环（C16）

§Rule Zero 要求每次训练结束后提取 3-5 条教训。可视化章节为此提供**逆向看图归纳**的标准化流程：

```
训练结束
  ↓
1. 打开三张核心图（loss_curve / walkforward / gpu_timeline）
  ↓
2. 逐图扫描 §“常见视觉故障签名”表格
   → 命中哪个签名？（如"VRAM 斜坡"、"水平反弹"）
  ↓
3. 命中签名 → 查该行“根因”列
   → 根因是否是跨项目通用模式？（如“显存泄漏”是通用的；“GATE 嵌套”是 RL 专用）
  ↓
4. 通用模式 → 写入 §Rule Zero 教训表
   → 标注 #例证 + 日期 + 哪张图 + 具体数值
  ↓
5. 下一轮训练在启动前检查清单中新增对应检查项
```

**教训记录模板**（直接追加到 §Rule Zero 下方）：

```markdown
<!-- YYYY-MM-DD #例证 -->
- **[教训名]**：[一句话描述]
  - 视觉证据：`plots/xxx_final.png` 中 [具体形态描述]
  - 量化数据：[具体数值与阈表对比]
  - 根因：[§故障签名表 / §训练事故模式 中的模式号]
  - 修复：[一句话]
  - 新增检查项：[追加到启动前检查清单的具体条目]
```

**反向验证**（Agent 自检）：
- 如果写不出"视觉证据"中具体在哪张图的哪个位置 → 说明没看图 → 教训无效
- 如果量化数据与阈表对比无法对号入座 → 说明没用量化阈表 → 教训为定性主观

---

## 九、调试专用可视化——监控≠调试（C19）

在训练日志与 §一 的核心图中，正常的 loss 曲线可以一切平稳，而仍然存在隐错。调试时需要的可视化与监控时完全不同。

### 9.1 Per-feature 分布随时间演化

RF 训练中，若某特征在后续窗口中突然变成常数（全部相同值或 NaN），其 spearmanr 会返回 NaN，导致该公式的 IC 变成 NaN，进而污染整体信号。

```python
def plot_feature_winnow(feature_matrix, feature_names, window_starts=None):
    """每特征、每 walkforward 窗口画一个 boxplot，跨越窗口检测数据漂移。
    feature_matrix: (N_features, D_timesteps) 或 (N_features, N_windows, _)
    """
    import numpy as np, matplotlib.pyplot as plt
    N_feat = len(feature_names)
    fig, axes = plt.subplots(N_feat, 1, figsize=(14, N_feat * 2.5), sharex=True)
    if N_feat == 1:
        axes = [axes]
    for i, ax in enumerate(axes):
        ax.plot(feature_matrix[i], alpha=0.7, linewidth=0.5, color="steelblue")
        ax.set_ylabel(feature_names[i][:12], fontsize=7)
        ax.grid(True, alpha=0.3)
    axes[-1].set_xlabel("Timestep")
    fig.suptitle("Feature Value Evolution Across Walkforward Windows")
    plt.tight_layout()
    return fig
```

### 9.2 Per-sample Loss Distribution（前 % 样本）

正常的 loss 曲线平滑时，后续 per-sample loss 的分布也能揭示内容：
- 尾样本 loss 突然膨胀但均值不大 = 模型对所有样本都大致好、仅少数崩溃 → fine
- 分布双峰 = 模型在不同类型样本上学到两套参数 → fine-tuning / RL 泛化出症候

```python
def plot_loss_histogram(per_sample_losses, step, bins=40):
    """训练中快照分布，与 loss 均值对照。"""
    import numpy as np, matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.hist(per_sample_losses, bins=bins, color="steelblue", alpha=0.7, edgecolor="white")
    ax.axvline(np.mean(per_sample_losses), color="red", linestyle="--", linewidth=1.5,
              label=f'Mean={np.mean(per_sample_losses):.3f}')
    ax.set_xlabel("Loss"); ax.set_ylabel("Count")
    ax.set_title(f"Per-sample Loss Distribution @ Step {step}")
    ax.legend(fontsize=9); ax.grid(True, alpha=0.3, axis="y")
    return fig
```

### 9.3 NaN Root-Cause Trace

每发现 NaN（且未自愈）后，不等待自动 kill — 在发现 NaN 的下一步（或 kill 前立即运行）需要生成一份 **NaN 溯源图**：

```python
def plot_nan_rootcause(values_matrix, step, feature_names=None):
    """values_matrix: (N_samples, N_features) — 每个特征在每个样本的值。"""
    import numpy as np, matplotlib.pyplot as plt
    nan_mask = np.isnan(values_matrix).any(axis=1) if values_matrix.ndim == 2 else np.isnan(values_matrix)
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    ax = axes[0]
    if values_matrix.ndim == 2:
        nan_rows = np.any(np.isnan(values_matrix), axis=1)
        ax.plot(np.arange(values_matrix.shape[0]), nan_rows.astype(int), alpha=0.5, color="red", linewidth=0.5)
        ax.set_xlabel("Sample"); ax.set_ylabel("Has NaN")
        ax.set_title(f"NaN Mask Across Samples @ Step {step}")
        ax.grid(True, alpha=0.3)
    ax = axes[1]
    if feature_names and values_matrix.ndim == 2:
        col_nans = np.isnan(values_matrix).sum(axis=0)
        if col_nans.sum() > 0:
            ax.bar(range(len(feature_names)), col_nans, color="coral", alpha=0.7)
            ax.set_xticks(range(len(feature_names)))
            ax.set_xticklabels(feature_names, rotation=90, fontsize=6)
            ax.set_ylabel("NaN count")
            ax.set_title("NaN Count per Feature")
            ax.grid(True, alpha=0.3)
    plt.tight_layout()
    return fig
```

**优先检查顺序（出现 NaN 时）**：`per-feature` 的 NaN 计数 → `per-sample` 的 NaN 计数 → `data source`（若某窗口数据未下载/损坏）。

---

## 十、子代理协作——多模态视觉验收（C20）

在前面的验收流程中，Agent 需要人工 visual inspection 判断图的状态（✅/⚠️/🔥）。但当前 AI agent 的能力已有突破，一些 subagent 可作为“自动看图器”，加速验收。

### 10.1 集成多模态视觉 Agent

`visual-engineering` 或 `multimodal-looker` 子代理具有对图像的分析能力，可在当前 pi-agent 内调用它们来判断训练图的健康状况。

**模式 1：端到端自动验收（链式）**

```yaml
# 在 subagent chain 中定义
chain:
  - agent: multipodal-looker      # 看图诊断
    task: |
      Read three PNG files:
        results/xxx/plots/loss_curve_final.png
        results/xxx/plots/walkforward_panel_final.png
        results/xxx/plots/gpu_timeline_final.png
      For each, answer:
        - 有无 NaN 深渊或水平反弹？给出图中实际 step 范围
        - walkforward IC 是否所有窗口同号？cumulative IC斜率是否单调？
        - VRAM trends 是否 ≥ +5 MB/step？GPU utilization 有无"心电图"表现？
      Return: verdict with each item: ✅/⚠️/🔥 + 简短理由
  - agent: momus                     # 对照阈表二次审核
    task: |
      Read verdict from previous step. Compare against the quantitative
      thresholds defined in ml-training.md §量化验收阈表. Flag any discrepancy.
```

**模式 2：仅看图（异步任务）**——让视觉代理先行分析，主 agent 做交叉验证

```python
subagent({
    tasks: [
        {
            agent: "multimodal-looker",
            task: f"Analyze {plot_path} for NaN spikes, plateau, VRAM trends. Return structured verdict.",
            output: True        # 保留输出，再由主 agent 进行交叉验证
        }
    ]
})
```

### 10.2 视觉分析的特异性需求

由于训练可视化是高度专业领域图，多模态代理需要一定上下文：

- 提供 §量化验收阈表的 PDF 提取（可用 Tesseract OCR 或提前导入）
- 告知代理："横轴 X 是 step 编号"、"纵轴 Y 含义为 ___"（否则代理可能猜错）
- 相比于看风景图、UI 截图，训练曲线对精确数值不敏感——代理可以识别整体曲线的**形态**（monotonic 下降 vs 反弹），但对 0.001 量级的数值变化不精确

### 10.3 代理验收 vs 人类验收的决策矩阵

| 场景 | 推荐验收方式 | 备注 |
|:---|:---|:---|
| 远程训练长期运行、仅需断际检查 | 多模态代理自动阅图 + 发 alert | 代理看趋势不错，但数值精度低 |
| 关键 final 判断（是否部署 / 重训 / 调整阈值） | 人工看图 + 代理辅助量化 | 数值精确性需求高 |
| 前期超参搜索（20+ 实验） | 代理做初筛（✅/⚠️/🔥），人工仅看 🔥 和边缘 ⚠️ | 削减人工负荷 |
| 多种子 final | 代理看图 + 阴影图均方差对照 | 均值 ± std 是代理擅长的视觉效果 |

```
visual-engineering (看图) → momus (审查) → orchestrator (整合) → 结论
```

---

## 附录 A：本可视化章节的完整文件清单（快速索引）

以下是可以直接复制到项目中的代码模块及其所在章节：

| 模块 | 位置 | 功能 | 文件建议名 |
|:---|:---|:---|:---|
| `plot_loss_curve` | §1.1 | Loss/IC 曲线 + 滑动平均 | `viz_curves.py` |
| `plot_gradient_diagnostics` | §1.2 | 梯度范数 + 信噪比 | `viz_dl.py` |
| `plot_gpu_timeline` | §1.3 | GPU VRAM / util / 泄漏检测 | `viz_gpu.py` |
| `plot_walkforward_panel` | §1.4 | Walkforward IC 面板 | `viz_walkforward.py` |
| `plot_permutation_test` | §1.5 | 置换检验分布 | `viz_perm.py` |
| `plot_formula_evolution` | §1.6 | RL 公式多样性演化 | `viz_formula.py` |
| `plot_dl_health` | §1.7 | DL 熵/增益热力图 | `viz_dl.py` |
| `plot_kappa_dashboard` | §1.8 | κ 共移性仪表板 | `viz_kappa.py` |
| `plot_experiment_comparison` | §1.9 | 多实验对比 | `viz_compare.py` |
| `TrainingLogger` | §三 | 训练日志记录器 | `training_logger.py` |
| `save_all_plots` | §三 | 批量生成全部图 | `viz_save.py` |
| `create_training_hooks` | §3.1 | 训练可视化钩子 | `viz_hooks.py` |
| `plot_lr_schedule` | §8.1 | LR 调度曲线 | `viz_lr.py` |
| `plot_calibration_scatter` | §8.2 | 预测校准散点图 | `viz_calibration.py` |
| `plot_formula_hall_of_fame` | §8.3 | RL 公式 Hall of Fame | `viz_formula.py` |
| `plot_multi_seed_curves` | §8.4 | 多种子聚合阴影图 | `viz_multi_seed.py` |
| `plot_attention_map` | §8.5 | Transformer 注意力图 | `viz_dl.py` |
| `should_alert_kill` | §8.7 | 自动告警 kill 判断 | `auto_alert.py` |
| `cleanup_plots` | §8.8 | 磁盘 cleaned 图文件 | `viz_save.py` |
| `plot_feature_winnow` | §九 | 特征漂移图 | `viz_debug.py` |
| `plot_loss_histogram` | §九 | per-sample loss 直方图 | `viz_debug.py` |
| `plot_nan_rootcause` | §九 | NaN 根因图 | `viz_debug.py` |

> 建议：在项目根目录创建 `training_utils/` 目录，按上表模块建文件，使 §训练可视化 中每个绘图函数都可直接 `from training_utils import plot_xxx` 调用。


### 2.4 事件标注工具（C6）——在已有图上叠加训练事件

任何已生成的 `matplotlib.axes.Axes` 对象都可以在调用 `fig.savefig` 之前通过此函数叠加事件标注线，标明 checkpoint 保存点、LR 调度切换点、OOM 恢复点等。

```python
def annotate_events(ax, events, ymax=None, fontsize=7):
    """在已有 axes 上叠加训练事件标注。

    events: list[dict] 每项含:
        'step': int                 — 事件发生的步编号
        'type': 'checkpoint' | 'lr_change' | 'oom_recovery' | 'data_switch' | 'custom'
        'label': str (可选)           — 标注文本（不超过 15 字符，否则截断）
        'color': str (可选)          — 覆盖 color map 中的默认颜色
    ymax: 标注文本的垂直位置（None 则自动用 ax.get_ylim()[1]）
    fontsize: 标注文本字号

    颜色映射:
        checkpoint   → green  ':'
        lr_change    → purple '--'
        oom_recovery  → red    '-.'
        data_switch  → orange ':'
        custom       → gray   '-'
    """
    import numpy as np

    COLOR_MAP = {
        'checkpoint':   ('#27ae60', ':',  '● Checkpoint'),
        'lr_change':    ('#8e44ad', '--', '◆ LR Change'),
        'oom_recovery':  ('#e74c3c', '-.', '▲ OOM Recovery'),
        'data_switch':  ('#e67e22', ':',  '■ Data Switch'),
        'custom':       ('#7f8c8d', '-',  '▪ Event'),
    }

    if ymax is None:
        ymin, ymax = ax.get_ylim()
    text_height = ymax * 0.97  # 标注文本放在靠近顶部 3% 的位置

    # 去重：相同 type + 相邻 step（<5 步）合并不重复绘制
    seen_types = set()
    for i, ev in enumerate(events):
        step = ev.get('step', 0)
        etype = ev.get('type', 'custom')
        label = ev.get('label', '')
        color, linestyle, legend_label = COLOR_MAP.get(etype, COLOR_MAP['custom'])
        if ev.get('color'):
            color = ev['color']

        # 画竖线
        ax.axvline(x=step, color=color, linestyle=linestyle, linewidth=1.0, alpha=0.8)

        # 为每种 type 只添加一次 legend 条目
        if etype not in seen_types:
            ax.plot([], [], color=color, linestyle=linestyle, linewidth=1.0,
                    label=legend_label if not label else f'{legend_label} ({label})')
            seen_types.add(etype)
        elif label:
            # 同一 type 不同 label：添加带 label 的条目
            ax.plot([], [], color=color, linestyle=linestyle, linewidth=1.0,
                    label=f'{legend_label}: {label[:15]}')

        # 标注文本：在竖线顶部附近
        display_label = label[:15] if label else etype.replace('_', ' ').title()
        # 交错垂直位置防止重叠：偶数行放在 ymax×0.94，奇数行放在 ymax×0.88
        y_offset = text_height * (0.97 if i % 2 == 0 else 0.91)
        ax.text(step + 0.5, y_offset, display_label, fontsize=fontsize,
                color=color, rotation=90, verticalalignment='top',
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', alpha=0.7))

    # 确保 legend 包含事件标注
    handles, labels = ax.get_legend_handles_labels()
    # 去重 legend 条目
    unique = {}
    for h, l in zip(handles, labels):
        if l not in unique:
            unique[l] = h
    if unique:
        ax.legend(list(unique.values()), list(unique.keys()),
                 fontsize=fontsize, loc='upper right',
                 framealpha=0.8, ncol=2)


def build_events_from_checkpoints(checkpoint_steps, lr_milestones=None,
                                   oom_steps=None, data_switch_steps=None):
    """从简单列表构建 events 列表。便捷辅助函数。

    用法:
        events = build_events_from_checkpoints(
            checkpoint_steps=[0, 100, 200, 500],
            lr_milestones={50: 'warmup_end', 300: 'decay'},
            oom_steps=[142],
        )
        annotate_events(ax, events)
    """
    events = []
    for st in (checkpoint_steps or []):
        events.append({'step': st, 'type': 'checkpoint', 'label': f'ckpt@{st}'})
    if lr_milestones:
        for st, desc in lr_milestones.items():
            events.append({'step': st, 'type': 'lr_change', 'label': desc})
    for st in (oom_steps or []):
        events.append({'step': st, 'type': 'oom_recovery', 'label': f'oom@{st}'})
    for st, ds in (data_switch_steps or []):
        events.append({'step': st, 'type': 'data_switch', 'label': ds})
    return events
```

**在现有绘图流程中集成**：

```python
# save_all_plots 中，在每张图的 fig.savefig 之前加上标注
events = build_events_from_checkpoints(
    checkpoint_steps=[0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500],
    lr_milestones={100: 'warmup_end'},
    oom_steps=[],
)
# 在 plot_loss_curve 返回 fig 后，对 fig.axes[0] 调用
fig = plot_loss_curve(logger.step_rewards, logger.steps)
annotate_events(fig.axes[0], events)
fig.savefig(path, dpi=100, bbox_inches='tight')
```

| 事件类型 | 图例图标 | 典型使用场景 |
|:---|:---|:---|
| `checkpoint` | ● 绿色竖线 | 每 N 步保存一次模型权重 |
| `lr_change` | ◆ 紫色虚线 | warmup 结束、cosine decay 启用 |
| `oom_recovery` | ▲ 红色点划线 | OOM kill 后从 checkpoint 重新启动 |
| `data_switch` | ■ 橙色点线 | 训练集从 A 切换到 B（如预训 → 微调） |
| `custom` | ▪ 灰色横线 | 用户自定义事件 |

**注意事项**：
- 事件不会保存在 `TrainingLogger` 中，因为没有事件记录接口
- 如需跨实验追踪事件，在 `training_metrics.json` 中新增 `"events": [...]` 字段
