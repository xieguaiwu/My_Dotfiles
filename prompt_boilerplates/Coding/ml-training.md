---
name: ml-training
version: 1.2.0
description: 在远程服务器上进行机器学习训练任务的完整方法论——从环境检查、烟雾测试、看门狗自动化、训练监控到结果验证的全流程
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

