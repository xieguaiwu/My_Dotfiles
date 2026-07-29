---
name: quant-ml-falsification
version: 1.1.0
description: 量化投资模型训练的防幻觉方法论——教高幻觉模型如何辨别假 alpha、诚实完成训练、在方向饱和后找到新方向
triggers:
  - "量化训练"
  - "quant训练"
  - "alpha幻觉"
  - "Sharpe证伪"
  - "信号饱和"
  - "因子失效"
  - "模型不显著"
  - "找新方向"
inputs:
  - name: market
    description: 目标市场（sgx / ashare / futures / jp / us 等）
    required: false
    default: ""
  - name: claimed_sharpe
    description: 当前声称的 Sharpe 值，用于判断是否需要进入证伪流程
    required: false
    default: ""
  - name: model_type
    description: 模型类型（ridge / xgboost / rl / lstm / ctm / mamba 等）
    required: false
    default: ""
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - subagent
  - memory_search
  - todo_create
---

# 量化投资模型训练防幻觉方法论

> **本 skill 是认知框架，不是操作手册。** 操作细节（烟雾测试、看门狗、GPU 隔离、输出缓冲）见 `ml-training.md`。本 skill 专注于：高幻觉模型（DeepSeek V4 Pro / Flash 等）在量化训练中如何**不骗自己、不骗用户、在信号不存在时承认不存在、在方向饱和后找到正确出路**。

> **核心信念**：在量化投资模型训练中，**默认状态是「无信号」**。日频 OHLCV 衍生特征的 OOS IC 典型值是 0.00--0.03，net Sharpe 在交易成本后通常为负或可忽略。这不是失败——这是金融 ML 的统计天花板。每一个声称的正面结果**必须经过证伪才能被采信**。

---

## 任务目标

教高幻觉模型完成量化训练的三项核心能力：（1）辨别——识别 25 种常见的假 alpha 模式（含数据泄露），在报告前自行证伪；（2）训练——用种子协议、基线协议、止损协议完成可复现的诚实训练；（3）找方向——在当前方向信号饱和时，用决策树找到正确的新方向而非无意义地刷参数。

---

## 执行流程

### 第一支柱：辨别问题——假 Alpha 检测协议

> **黄金法则**：如果你报告了一个正 Sharpe，先问自己「这个 Sharpe 能不能在加种子后存活？」如果不能，它就是幻觉。

#### 1.1 默认假设：你的正面结果是假的

高幻觉模型的本能是**过度乐观地解读结果**——看到 Sharpe > 0 就兴奋，看到 IC > 0 就宣布成功。在量化训练中，这个本能是致命的。正确的心态是：

| 看到 | 高幻觉模型的反应 | 正确反应 |
|:---|:---|:---|
| Sharpe = +0.9 | "成功了！统计显著！" | "这太高了。日频 return prediction 的合理 Sharpe 是 0.0--0.3。什么通胀机制在起作用？" |
| IC = +0.05 | "有信号！" | "和随机基线比呢？基线 IC 是多少？加种子后中位数是多少？" |
| 胜率 = 53% | "过半了，有效" | "随机选股的胜率是多少？53% vs 50% 在 n=300 下显著吗？" |
| 总回报 = +113% | "策略盈利" | "生存偏差估了多少？退市股排除了吗？止损设置是多少？" |
| maxDD = -19.8% | "回撤可控" | "这是止损截断后的还是真实路径？无止损的 maxDD 是多少？" |

#### 1.2 二十五种假 Alpha 模式——逐项排查清单

以下每种模式都来自真实训练事故（F1-F15 为信号/统计假象，F16-F25 为数据泄露）。训练完成后，**逐项过一遍**：

| # | 模式名 | 表现 | 根因 | 检测方法 | 真实案例 |
|:--|:---|:---|:---|:---|:---|
| F1 | **未种子基线走运** | model α 很高但不可复现 | `np.random.choice` 无 `random_state`，基线一次走运 | 加 `seed=42` 显式重跑，α 是否跨零 | SGX: α +0.675 → +0.020 |
| F2 | **止损截断通胀** | STOP_LOSS=0.05 使 Sharpe 翻倍 | 左尾截断成正好 -5%，均值上 + 方差下 → Sharpe 非线性放大 | 跑 `--stop-loss none` 对照，Sharpe 跌多少 | SGX: 0.49→0.91，真实 0.27 |
| F3 | **策略构造伪 Sharpe** | Sharpe 高但 IC ≈ 0 | sign-based long/short 在 mean-reverting 尾巴上制造正 Sharpe | 检查 IC 与 Sharpe 是否同号；IC ≈ 0 但 Sharpe > 0 = 伪迹 | HK: Sharpe +0.62, IC -0.004 |
| F4 | **WF 过拟合** | walk-forward IC 0.04--0.14 但 test IC ≈ 0 | 训练窗口内拟合，OOS 崩溃 | 检查 WF IC vs held-out test IC 的 gap | Glaubenskrieg: WF 0.04-0.14, test ≈ 0 |
| F5 | **文档幻觉** | README 声称的数值与结果文件不符 | agent 编写文档时凭记忆而非读文件 | `grep` 结果文件中的实际值，与文档逐一比对 | CTM: 10 个 test Sharpe 全部不匹配 |
| F6 | **特征复制** | 两个特征 r = 1.000 | `F[:, j] = F[:, i].copy()` 别名 bug | 特征相关矩阵检查，找 r > 0.999 的列对 | 期货: basis_proxy = sma_20_bias |
| F7 | **np.roll 回绕** | 首行 = 末行 | `np.roll()` 代替 `shift()`，未来数据回绕到位置 0 | 检查 X[0, feat_idx] ≈ X[-1, feat_idx] | 多项目通用 |
| F8 | **update-before-fuse** | 胜率 100%，所有窗口正 IC | 用当日收益更新权重再融合当日预测 | `grep -n 'update.*fuse\|fuse.*update'` 检查顺序 | 期货: IC 虚高 30-75% |
| F9 | **单种子 = 显著** | 声称统计显著但只跑了一次 | 单次抽运 ≠ 统计检验 | 要求 ≥ 3 种子 median + 95% CI | SGX: 单抽运 α=+0.675 |
| F10 | **Sharpe-IC 悖论** | 高 Sharpe regime 但 IC ≈ 0 或负 | regime-selection alpha（低波→小 std→高 Sharpe），非选股能力 | per-regime 随机基线对照 | SGX: lowHiD IC=-0.0037, Sharpe=+1.598 |
| F11 | **R² on 价格水平** | R² 很高但无用 | 预测价格水平（自相关 ~0.99）而非收益率 | 检查 target 是 price 还是 return | MambaStock: R²=-4.70 |
| F12 | **重叠窗口膨胀** | t 值很高，p 值很小 | walk-forward 窗口重叠 → IC 非独立 → t 值高估 ~6× | 检查窗口 step ≥ val_len（非重叠） | 期货: t-test 误用 |
| F13 | **置换检验偷换对象** | p 值显著但检验的不是目标模型 | Ridge 的 permutation test 结果被用于声称 RL 显著 | 确认 p 值的检验对象 = 被报告的模型 | 期货: p=0.40 跨模型引用 |
| F14 | **全序列 z-score 前瞻** | 回测回报极高，实盘亏损 | 归一化统计量用了全序列（含未来） | 检查 `np.nanmean`/`np.nanstd` 是否在交易循环外一次性计算 | 实盘: +70% → -10% |
| F15 | **生存偏差** | 回报高估 2-5% | 仅含存续至末日的股票，退市股被排除 | 检查股票列表是否含已知退市股 | SGX: 34 只存续股 |
| F16 | **Train/Test 时间重叠** | walk-forward 训练集含测试期数据，t 值虚高 | window step < val_len，相邻验证窗口重叠 | 检查 step ≥ val_len，确保非重叠；或用 Purge | 期货: t 值高估 6× |
| F17 | **标签时间穿越** | Sharpe 虚高 0.5-2.0，模型「预知未来」 | 用 t+i (i>0) 的未来数据构造 t 时刻的 label | 对每个 t 验证 label[t] 仅使用 ≤t 的数据 | 多项目通用 |
| F18 | **全局预处理泄露** | IC 虚高 0.01-0.03 | StandardScaler/Imputer 在全数据集上 fit（含测试集） | 每个 walk-forward 窗口独立 fit(train)→transform(test) | 多项目通用 |
| F19 | **截面随机分割** | IC 虚高 0.02-0.08，同股票记忆被过拟合 | `train_test_split` 随机分割 panel 数据，同股票分散 train/test | `grep train_test_split`，改为纯时间分割 | 多项目通用 |
| F20 | **滚动窗口边界泄露** | IC 虚高 0.01-0.05 | `rolling(20).mean()` 或 `shift(0)` 窗口含未来值 | 检查 `shift(1)` vs `shift(0)`，确认 rolling 不含未来 | 多项目通用 |
| F21 | **Purge/Embargo 缺失** | t 值高估 2-6×，IC 略高 | 未清除标签重叠样本，未设禁运期（label 窗口跨越 train/test 边界） | 确保 train_end + embargo ≤ test_start，purge 重叠 | 期货: t-test 误用 |
| F22 | **多重测试未校正** | p 值虚低，假阳性泛滥 | 同一测试集反复测试 N 个模型变体，未做 Bonferroni/Holm 校正 | 计数测试次数，≥5 需多重比较校正 | 多项目通用 |
| F23 | **同股票跨集泄露** | Sharpe 虚高 0.1-0.3 | 同一股票的不同时间段分散在 train 和 test，模型记住股票特性 | 对每个 split 检查 train 和 test 的 stock ID 交集应为空 | 多项目通用 |
| F24 | **全序列统计量特征** | IC 虚高 0.01-0.10 | 用全序列 mean/std/quantile 构造特征（全局 z-score、全局分位数） | 检查每个特征计算是否仅使用 ≤t 的数据 | 实盘: +70% → −10% |
| F25 | **测试集特征/超参选择** | IC 虚高 0.005-0.02 | 用测试集性能做特征选择或超参调优（双重 dipping） | grep 特征选择代码，确认仅用 train 做选择 | 多项目通用 |

#### 1.3 三列对照法——证伪的标配操作

对任何声称的正面结果，跑三列对照：

```text
列 A (原声称)    : 原始配置，原始种子（或未种子）
列 B (诚实复现)  : 完全相同配置，但显式 seed=42
列 C (去添加剂)  : 显式 seed=42 + 去掉止损/去重/等所有「优化」
```

**判定规则**：

| A → B 变化 | A → C 变化 | 判定 |
|:---|:---|:---|
| α 跨零（如 +0.675 → +0.020） | — | **F1 确认**：原结果是种子走运，假的 |
| α 不变 | α 大幅下降 | **F2 确认**：止损/优化在通胀，真实 α 更低 |
| α 不变 | α 不变 | 结果可能真实（但仍需 ≥ 3 种子验证） |
| α 跨零 | α 跨零 | **多重通胀**：种子 + 优化共同制造，完全假的 |

#### 1.4 诊断必须由批判性子代理执行

证伪诊断**不能由施工 agent 自诊自修**（它有确认偏误）。按 `ml-training.md` §11.3，诊断必须由 `deep` / `momus` / `oracle` 等**只读批判性 agent** 执行：

```python
subagent({
  agent: "deep",
  task: "只读诊断：审查 SGX 结果 JSON + 训练脚本，逐项排查 F1-F15，输出 P0-P3 结构化报告",
  timeoutMs: 900000
})
```

诊断 agent **只读不写**，唯一产出是诊断报告 + 施工清单。

---

### 第二支柱：完成训练——诚实训练协议

> **核心原则**：训练不是终点。结果被诚实地记录、可复现、带完整上下文，才算一次完整的训练循环。

#### 2.1 种子协议（防 F1 / F9）

```python
# ❌ 错误：未种子的随机基线
random_indices = np.random.choice(len(stocks), size=n_long, replace=False)

# ✅ 正确：显式种子
rng = np.random.default_rng(args.seed)
random_indices = rng.choice(len(stocks), size=n_long, replace=False)
```

**规则**：
- 所有随机源（`np.random`、`torch.manual_seed`、`rng`）必须在 `main()` 开头统一播种
- 随机基线必须与模型用**同一管线**（同止损、同非重叠、同 n_long、同 cost）
- 最终报告必须给 **≥ 3 种子的 median** 而非单次抽运
- 单种子结果只能用于快速验证，**不可作为最终结论**

#### 2.2 基线协议（防 F3 / F10）

每个声称的 model α 必须有**同口径随机基线**对照：

| 要素 | 模型 | 随机基线 | 必须一致 |
|:---|:---|:---|:---|
| 选股 | top-20% by prediction | `rng.choice` 同 n_long | n_long 数量 |
| 止损 | `_effective_return(sl=0.05)` | **同一函数同一 sl** | sl 设置 |
| 持仓 | horizon=5, 非重叠 | **同一 next_trade_day** | horizon |
| 成本 | 0.2% round-trip | **同一 cost** | cost |
| 体制 | 仅 high-dispersion regime | **同一 regime 过滤** | regime 条件 |

**per-regime 基线**：聚合基线不够。必须报告**每个 regime 的模型 Sharpe vs 随机基线 Sharpe**，才能区分 regime-selection α 与 stock-picking α。

```python
# 必须输出的 per-regime 对照表
for regime in ['lowVol_highDisp', 'highVol_highDisp']:
    model_sh = compute_sharpe(model_trades[regime])
    base_sh = compute_sharpe(random_trades[regime])
    alpha = model_sh - base_sh
    print(f"{regime}: model={model_sh:.3f} base={base_sh:.3f} α={alpha:.3f}")
```

#### 2.3 止损协议（防 F2）

| 步骤 | 操作 | 目的 |
|:---|:---|:---|
| 1 | 报告 stop-loss 设置（0.05 / none / 其他） | 让读者知道 Sharpe 在什么假设下计算 |
| 2 | 跑 `--stop-loss none` 对照 | 测量止损对 Sharpe 的通胀量 |
| 3 | 跑止损敏感性 sweep（`{none, 0.03, 0.05, 0.10, 0.20}`） | 证明 Sharpe 不依赖某个特定止损值 |
| 4 | 报告无止损的真实 maxDD | 让读者看到真实下行风险 |

**止损通胀的量化经验**：
- sl=0.05 vs sl=none：Sharpe 差 +0.2 ~ +0.4（5 天持仓期）
- sl=0.05 vs sl=none：maxDD 差 +10 ~ +15pp（真实回撤更深）
- 对低波动 regime 的通胀更严重（低波股止损触发少 → 更受益于截断）

#### 2.4 诚实报告格式

训练完成后，**必须**输出以下完整报告，缺一不可：

```text
━━━ 诚实训练报告 ━━━
模型: {model_type}
市场: {market}, {n_stocks} stocks, {n_days} days, {date_range}
因子: {n_factors} 个去重因子（{n_raw} raw → {n_final} final）
窗口: {n_windows} non-overlapping, train={train_len}, val={val_len}, step={step}
种子: {seed_list}（≥3 个），报告中位数
止损: {stop_loss_setting}（含 none 对照）

信号质量（中位数 ± IQR）:
  窗口均值 IC:  {median_ic:+.4f} [{q25:.4f}, {q75:.4f}]
  Pooled IC:    {pooled_ic:+.4f}
  IC Sharpe:    {ic_sharpe:.2f}
  胜率:         {win_rate:.1%}

交易模拟（中位数）:
  模型 Sharpe:      {model_sh:.3f} [{model_ci_low:.3f}, {model_ci_high:.3f}]
  随机基线 Sharpe:  {base_sh:.3f} [{base_ci_low:.3f}, {base_ci_high:.3f}]
  Model α (Δ):      {alpha:.3f}
  CI 是否重叠:      {overlap}  ← 重叠 = 不显著
  真实 maxDD:       {max_dd:.1%}（无止损）
  年化回报:         {ann_ret:.1%}
  资本利用率:       {cap_util:.0%}

Per-regime 对照:
  {regime}: model={m_sh:.3f} base={b_sh:.3f} α={a:.3f} n={n_trades}

证伪检查（逐项）:
  F1 未种子基线:     {pass/fail}
  F2 止损通胀:       {pass/fail}（sl=none 对照已跑）
  F3 策略构造伪迹:   {pass/fail}（IC 与 Sharpe 同号？）
  F9 单种子:         {pass/fail}（≥3 种子？）
  F10 regime 悖论:   {pass/fail}（per-regime 基线？）
  F15 生存偏差:      {pass/fail}（含退市股？）

判定: {通过 / 有风险 / 需重训 / 方向饱和}
━━━━━━━━━━━━━━━━━━━━
```

#### 2.5 文档 vs 代码一致性检查（防 F5）

训练完成后，**强制**验证文档声称与结果文件一致：

```bash
# 检查文档声称的 Sharpe 是否与 JSON 一致
DOC_SHARPE=$(grep -oP 'Sharpe.*?[\d.]+' CONTEXT.md | head -1 | grep -oP '[\d.]+')
JSON_SHARPE=$(python3 -c "import json; print(json.load(open('results/sgx/sgx_results.json'))['trading']['annualized_sharpe'])")
echo "文档: $DOC_SHARPE, JSON: $JSON_SHARPE"
[ "$DOC_SHARPE" != "$JSON_SHARPE" ] && echo "🔥 文档幻觉！" || echo "✅ 一致"
```

---

### 第三支柱：找方向——方向饱和后的正确出路

> **核心原则**：方向饱和不是失败，是诚实的测量结果。在错误的方向上刷参数是浪费时间。

#### 3.1 信号饱和诊断——何时该放弃当前方向

当以下条件**全部满足**时，当前方向已饱和，应停止在该数据/特征集上优化：

| 条件 | 检测方法 | 阈值 |
|:---|:---|:---|
| OOS IC < 0.03 且 IC Sharpe < 0.10 | walk-forward 均值 | IC < 0.03 |
| 随机基线 CI 与模型 CI 完全重叠 | 三列对照法 | CI 重叠 |
| ≥ 3 种子 median α ≈ 0（跨零） | 种子协议 | α ∈ [-0.05, +0.05] |
| Ridge 基线 ≈ XGBoost ≈ RL | 多模型对比 | 差距 < 0.05 |
| 复杂模型不优于线性模型 | RL/XGB vs Ridge | ΔIC < 0.02 |

**黄金法则**（来自 `ml-training.md` §11.13）：

> 自优化循环修复的是**实现缺陷**，不是**方法论天花板**。如果信号在当前特征池中已耗尽，刷参数、调超参、换模型架构都不会让 α 从 0 变正——因为没有信号可挖。

#### 3.2 RL 适用性边界决策树

在考虑是否用 RL 公式发现之前，先过这棵决策树：

```text
特征来源多样性 ≥ 2（特征来自多个独立数据源）?
  ├── 否 ──→ ❌ RL 退化风险高，先用 Ridge
  └── 是
      ↓
跨截面维度 ≥ 5（有多个可比较实体）?
  ├── 否 ──→ ❌ 单时序 RL 无交互可发现
  └── 是
      ↓
单时序 Ridge IC > 0.10?
  ├── 是 ──→ ⚠️ Ridge 已够好，RL 提升空间有限
      └── 否
          ↓
可以引入独立数据源（非 OHLCV 衍生）?
  ├── 是 ──→ ✅ 加入后评估
  └── 否 ──→ ❌ 不建议 RL，单时序 OHLCV-only 最优解是线性模型
```

#### 3.3 方向饱和后的五条出路

当当前方向饱和时，**不要在原数据上刷参数**。按以下优先级寻找新方向：

| 优先级 | 出路 | 适用场景 | 操作 |
|:---:|:---|:---|:---|
| P0 | **注入独立数据源** | 所有特征来自同一源（OHLCV） | 加入与现有特征 \|r\| < 0.3 的新维度 |
| P1 | **换预测目标** | return IC ≈ 0 但有二阶信号 | 从 return prediction 转向 volatility prediction |
| P2 | **换频率** | 日频信号耗尽 | 转向分钟级 / tick 级，或周频 / 月频 |
| P3 | **换市场** | 当前市场效率太高 | 从发达市场转向新兴市场，或从股票转向期货 / ETF |
| P4 | **横截面扩展** | 单时序信号弱 | 从单资产扩展为 (D, S, N) 横截面 panel，S ≥ 5 |

#### 3.4 独立数据源注入策略（P0 详解）

这是最常见也最有效的方向转换。当所有特征来自 OHLCV 同一数据源时，特征间中位 \|r\| > 0.5，RL 无交互可发现。注入一个与现有特征 \|r\| < 0.3 的新数据源：

| 市场类型 | 候选独立数据源 | 预期 \|r\| 与 OHLCV |
|:---|:---|:---|
| SGX（新加坡） | 港交所/STI 成分相对强弱、新加坡 REIT 利率敏感度、机构持仓披露换手 | < 0.3 |
| A 股 | 北向资金流向、融资融券余额变化、龙虎榜机构席位、大宗交易折价 | < 0.3 |
| 期货 | 持仓量（OI）变化、期限结构基差、会员席位净持仓、仓单变化 | < 0.3 |
| 美股 | 期权隐含波动率偏度、卖空利息、内部人交易、13F 持仓变化 | < 0.3 |
| 通用 | 宏观指标（利率、汇率、VIX）、另类数据（卫星、信用卡、舆情） | < 0.3 |

**验证方法**：注入新特征后，重新计算特征相关矩阵。如果跨族平均 \|r\| < 0.3 → RL 有增量价值。如果仍 > 0.5 → 继续找更独立的数据源。

#### 3.5 换预测目标策略（P1 详解）

当 return prediction IC ≈ 0 但存在二阶信号时，转向 volatility prediction：

| 预测目标 | 典型 OOS 表现 | 检测方法 |
|:---|:---|:---|
| 日收益率（return） | IC ≈ 0.00--0.03，R² ≤ 1% | 已饱和 |
| 已实现波动率（volatility） | QLIKE 显著改善（p < 10⁻¹⁴） | GARCH 基线 + ML 对照 |
| 尾部风险（VaR / ES） | 条件概率 ≥ 3× 基准 | 分位数回归 |
| 跨资产相关性 | 动态相关矩阵预测 | DCC-GARCH 基线 |
| 方向准确性（direction） | DirAcc ≈ 50% = 无信号 | sign-based IC |

**经验教训**：Glaubenskrieg 项目中，6 种范式全部在 return prediction 上 IC ≈ 0，但 volatility prediction 一致显著（QLIKE -6.42 到 -7.10，5 种子 std = 0.001）。**二阶矩信号是真实存在的，一阶矩信号在日频 OHLCV 上已耗尽。**

#### 3.6 方向饱和终态报告

确认方向饱和后，**必须**输出终态报告并更新证伪文档：

```yaml
终态: 方向饱和
方向: {market} {model_type} on {n_features} features × {n_stocks} stocks
证据:
  - OOS IC = {ic} < 0.03 阈值
  - 随机基线 CI 与模型 CI 完全重叠
  - ≥ 3 种子 median α = {alpha} ∈ [-0.05, +0.05]
  - Ridge ≈ XGBoost ≈ RL（差距 < 0.05）
结论: 信号在当前特征池中已耗尽
不再尝试:
  - 在原 {n_features} 特征上刷 XGBoost 超参
  - 在原 {n_features} 特征上跑 RL 公式发现
  - 在原 {n_stocks} 股票上调 regime 参数
复启条件（任一满足即可重新评估）:
  - 注入与现有特征 |r| < 0.3 的独立数据源
  - 补全退市股消除生存偏差后 IC 仍 > 0.03
  - 换预测目标（return → volatility / tail risk）
  - 换频率（日频 → 分钟级 / 周频）
```

更新以下文档（按 `ml-training.md` §11.7）：
- `FALSIFICATION_SUMMARY.md`：列出已证伪的结论（F1--Fn），后续 agent 不得在无新证据下重启
- `CONTEXT_FOR_NEXT_AGENT.md`：当前 Phase 标记为「方向饱和」，写明复启条件
- 迭代日志：iter0 → iter1 的指标对比表

---

### 第四支柱：防泄露——时间序列数据隔离协议

> **核心原则**：在金融时间序列中，数据泄露不是「可能有问题」——它是**「默认就存在」**。随机分割、全局归一化、滚动窗口边界不清、标签构造顺序错误，每一项都在制造看似显著实则虚假的 alpha。防泄露不是附加步骤，是训练的基础设施。**数据泄露是最隐蔽的假 alpha 来源**——它让无信号的模型看起来像有信号，但实盘必定崩溃。

> **与前三支柱的关系**：前三支柱教你辨别假 alpha、诚实训练、找新方向。但如果数据泄露存在，这些都可能是徒劳——泄露会让一个完全无效的模型看起来显著。**在你开始辨别假 alpha 之前，先确保数据本身是干净的。**

#### 4.1 金融时间序列的四条数据隔离铁律

| 铁律 | 说明 | 违反后果 |
|:---|:---|:---|
| **时间不可穿越** | t 时刻的模型只能使用 ≤ t 时刻的信息 | Sharpe 虚高 0.3-1.0，IC 翻倍 |
| **标的不可穿越** | 同一股票/合约不能在同一时间段的 train 和 test 中同时出现 | 过拟合被掩盖，OOS 虚高 |
| **统计量不可穿越** | 归一化/标准化/填充的统计量必须仅从训练集计算 | IC 虚高 0.01-0.05 |
| **标签不可穿越** | 标签（y）必须在特征（X）的时间点之后，且不能与训练集 label 窗口重叠 | 模型「预测」已经知道的结果 |

#### 4.2 时间感知分割方法

金融数据**绝对禁止**随机分割（`sklearn.model_selection.train_test_split`）。必须使用时间感知分割。

**4.2.1 纯时间分割 (Walk-Forward)**

```python
# ❌ 绝对禁止
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=True)

# ✅ 正确：按时间顺序分割，训练集全在测试集之前
for i in range(n_splits):
    train_end = start + train_len + i * step
    test_start = train_end + embargo        # ← 禁运期！
    test_end = test_start + test_len

    X_train = df[df.date < train_end]
    X_test  = df[(df.date >= test_start) & (df.date < test_end)]
```

**4.2.2 Purge 协议（清除标签重叠）**

当 label 跨越时间窗口（如 horizon=5 天收益），训练集末尾样本的 label 会「看到」测试集的数据：

```
时间线:  ... |--- train ---|  |--- test ---|
label:      [t  .... t+5]   [t' ... t'+5]
                        ↑
              训练集最后 5 天的 label 和测试集第一天重叠！
```

```python
def purge_overlap(train_dates, test_dates, purge_days):
    """
    清除训练集中 label 与测试集重叠的样本。
    purge_days: label 跨越的天数（如 horizon=5 → purge_days=5）
    """
    test_start = test_dates.min()
    purge_boundary = test_start - purge_days
    clean_train = train_dates[train_dates < purge_boundary]
    return clean_train
```

**4.2.3 Embargo 协议（禁运期）**

在训练集结束和测试集开始之间留出禁运期：

```python
# 场景：horizon=5, train_end = 2024-01-15
# train 最后一天的 label = 2024-01-15 到 2024-01-22 的收益
# 如果 test_start = 2024-01-16 → 测试集第一天和训练集最后一天的 label 有 6 天重叠！

# ✅ 正确：加上 embargo
embargo = horizon + 1  # horizon=5 → embargo=6
test_start = train_end + embargo  # 而非 train_end + 1
```

**4.2.4 步长与窗口关系（防重叠）**

| 配置 | train_len | val_len | step | 重叠率 | 影响 |
|:---|:---|:---|:---|:---|:---|
| ❌ 严重重叠 | 500 | 100 | 20 | 80% | t 值高估 5-6×，IC 相关性虚高 |
| ❌ 中度重叠 | 500 | 100 | 50 | 50% | t 值高估 2-3× |
| ✅ 非重叠 | 500 | 100 | 100 | 0% | 独立验证窗口，可做 t-test |
| ✅ 有间距 | 500 | 100 | 150 | 0% | 验证窗口之间有 gap，最保守 |

```python
# ✅ 推荐：非重叠 walk-forward
step = val_len  # 或更大
# 如果业务需要高频验证，用 Combinatorial Purged CV (CPCV) 替代重叠 walk-forward
```

**4.2.5 截面时间双重隔离 (Panel Data)**

```python
# ❌ 错误：随机选 80% 的行 → 同一股票分散在 train 和 test
import numpy as np
train_idx = np.random.choice(len(df), size=int(0.8 * len(df)), replace=False)
test_idx = np.setdiff1d(np.arange(len(df)), train_idx)

# ✅ 正确：按时间切，同一时间点的所有股票一起划分
split_date = pd.Timestamp('2024-06-30')
train_mask = df['date'] < split_date
test_mask  = df['date'] >= split_date + pd.Timedelta(days=embargo)

# 更严格（推荐）：按 (时间, 股票) 双重隔离
# 如果一只股票在 train 期出现了，test 期不包含该股票的任何数据
train_stocks = set(df[train_mask]['stock_id'].unique())
test_mask = test_mask & ~df['stock_id'].isin(train_stocks)
```

#### 4.3 特征工程的时点一致性 (Point-in-Time / PIT)

特征构造必须在每个时间点**只用该时间点及之前的信息**：

| 操作 | ❌ 泄露做法 | ✅ 正确做法 |
|:---|:---|:---|
| 标准化 (Z-score) | `scaler.fit(X_all)` 全数据集 | 每个训练窗口独立 `scaler.fit(X_train)` → `transform(X_test)` |
| 缺失值填充 | `df.fillna(df.mean())` 全局均值 | 每个窗口独立 `imputer.fit(X_train)` → `transform(X_test)` 或 `groupby('date').transform(lambda x: x.fillna(x.mean()))` |
| 横截面排名 | 不按日期分组的全局排名 | `df.groupby('date')['factor'].rank(pct=True)` |
| 行业中性化 | 全序列回归取残差 | 每个时间截面独立回归 `df.groupby('date').apply(neutralize)` |
| PCA / 因子降维 | `PCA().fit(X_all)` 全数据 | 每个训练窗口独立 `PCA().fit(X_train)` → `transform(X)` |
| 滚动统计 | `df['factor'].rolling(20).mean()` | 确认 `rolling` 不含未来（pandas 默认前向正确，但需验证 `shift` 方向） |
| Winsorize / 去极值 | 全序列分位数截断 | 每个时间截面独立 winsorize 或使用 expanding 分位数 |

**时点一致性自动验证**：

```python
def verify_point_in_time(df, feature_col, date_col='date'):
    """
    验证特征不含未来信息。
    对每个日期 t，用 ≤t 的数据重新计算特征，与原始值对比。
    差异 > 1e-8 即为泄露。
    """
    violations = []
    dates_sorted = sorted(df[date_col].unique())

    for t in dates_sorted:
        past_df = df[df[date_col] <= t].copy()
        try:
            recomputed = compute_feature_pit(past_df, feature_col)
            original = df.loc[df[date_col] == t, feature_col].values
            if len(recomputed) == len(original):
                max_diff = np.nanmax(np.abs(
                    original - recomputed[-len(original):]
                ))
                if max_diff > 1e-8:
                    violations.append((t, max_diff))
        except Exception:
            pass  # 特征可能依赖 ≥2 行数据，跳过边界情况

    if violations:
        print(f"🔥 时点泄露！{len(violations)} 个日期异常")
        for t, diff in violations[:5]:
            print(f"  date={t}, max_diff={diff:.6f}")
    return violations
```

#### 4.4 预处理隔离的代码模式

**4.4.1 标准化隔离**

```python
class WalkForwardPreprocessor:
    """时间感知的预处理管道：每个 walk-forward 窗口独立 fit"""
    def __init__(self, steps=None):
        if steps is None:
            from sklearn.preprocessing import StandardScaler
            from sklearn.impute import SimpleImputer
            steps = [StandardScaler(), SimpleImputer(strategy='median')]
        self.steps = steps

    def fit_transform_window(self, X, train_mask):
        """仅在训练集上 fit，然后 transform 整个数据集"""
        import copy
        X_train = X[train_mask].copy()
        X_out = X.copy()
        fitted = []

        for step in self.steps:
            fitted_step = copy.deepcopy(step)
            fitted_step.fit(X_train)
            X_out = fitted_step.transform(X_out)
            X_train = fitted_step.transform(X_train)
            fitted.append(fitted_step)

        return X_out, fitted
```

**4.4.2 特征选择隔离**

```python
# ❌ 错误：用全数据集做特征选择 → 测试集信息泄露到特征子集
from sklearn.feature_selection import SelectKBest, f_regression
selector = SelectKBest(f_regression, k=20)
selector.fit(X_all, y_all)  # 看到了测试集！

# ✅ 正确：仅用训练集做特征选择
for train_mask, test_mask in walk_forward_splits:
    selector = SelectKBest(f_regression, k=20)
    selector.fit(X[train_mask], y[train_mask])  # 只看训练集
    X_train_sel = selector.transform(X[train_mask])
    X_test_sel = selector.transform(X[test_mask])
```

**4.4.3 超参搜索隔离**

```python
# ❌ 错误：GridSearchCV 默认 KFold → 随机分割 → 泄露
from sklearn.model_selection import GridSearchCV

# ✅ 正确：使用时间序列交叉验证
from sklearn.model_selection import TimeSeriesSplit
tscv = TimeSeriesSplit(n_splits=5)
grid = GridSearchCV(estimator, param_grid, cv=tscv)
grid.fit(X_train, y_train)  # 仅在训练集上搜索
```

#### 4.5 泄露严重程度与修复成本

| 级别 | 泄露类型 | 典型 Sharpe 通胀 | 典型 IC 通胀 | 检测难度 | 修复成本 | 对应模式 |
|:---|:---|:---|:---|:---|:---|:---|
| 🔴 P0 | 标签时间穿越 | +0.5 ~ +2.0 | +0.05 ~ +0.15 | 低 | 低（纠正 label 计算顺序） | F17 |
| 🔴 P0 | 截面随机分割 | +0.3 ~ +0.8 | +0.02 ~ +0.08 | 低（grep 即发现） | 低（改为时间分割） | F19 |
| 🟠 P1 | 全局标准化 | +0.1 ~ +0.3 | +0.01 ~ +0.03 | 中 | 低（移到循环内） | F18 |
| 🟠 P1 | 全序列排名/分位数 | +0.1 ~ +0.3 | +0.02 ~ +0.05 | 中 | 低（加 groupby date） | F24 |
| 🟡 P2 | 缺失值填充泄露 | +0.05 ~ +0.1 | +0.005 ~ +0.02 | 中 | 中 | F18 |
| 🟡 P2 | 特征选择泄露 | +0.05 ~ +0.1 | +0.005 ~ +0.02 | 中 | 中（移到循环内） | F25 |
| 🟢 P3 | Purge 缺失 | +0.02 ~ +0.05 | 小（t 值方面更严重） | 高 | 高（需正确 purge 逻辑） | F21 |
| 🟢 P3 | 小步长重叠窗口 | +0.01 ~ +0.03 | 小（t 值高估 2-6×） | 中 | 低（调大 step） | F16 |

#### 4.6 数据泄露审计清单

训练完成后，**先过 L1-L12（数据泄露），再过 F1-F25（假 alpha 信号）。** 两者配合，逐项检查：

| # | 检查项 | 检测命令 / 方法 | 若违规 | 对应模式 |
|:--|:---|:---|:---|:---|
| L1 | 是否用了 `train_test_split` | `grep -rn 'train_test_split' *.py` | 改用时间分割 | F19 |
| L2 | 标准化是否在循环外 fit | `grep -n 'StandardScaler.*fit' *.py`，确认在 `for` 循环内 | 移到循环内 | F18 |
| L3 | 缺失值填充是否用全局统计量 | `grep -n 'fillna.*mean\|SimpleImputer.*fit' *.py`，确认在循环内 | 移到循环内 | F18 |
| L4 | label 是否用了未来数据 | 对 horizon=5，验证 `label[t]` 的原始数据范围是 `[t, t+5]` | 纠正偏移方向 | F17 |
| L5 | rolling/shift 窗口方向 | `grep -n 'shift(0)\|shift(-' *.py` | 改为 `shift(1)` 或正向 | F20 |
| L6 | 特征是否含全序列统计量 | `grep -n '\.mean()\|\.std()' *.py`，确认无全局计算 | 改为 expanding 或 PIT | F24 |
| L7 | step ≥ val_len？ | 检查 walk-forward 参数 | 增大 step 或加 Purge | F16, F21 |
| L8 | 同股票跨 train/test？ | `set(train_stocks) & set(test_stocks)` | 加截面隔离 | F23 |
| L9 | 特征选择是否仅用 train | `grep -A5 'SelectKBest\|feature_importance' *.py`，确认在循环内 | 移到循环内 | F25 |
| L10 | 超参搜索是否仅用 train | `grep -A5 'GridSearchCV\|RandomizedSearchCV' *.py`，确认 cv 是 TimeSeriesSplit | 改用 TSCV | — |
| L11 | 是否每个截面独立排名 | `grep 'rank.*pct' *.py`，确认有 `groupby('date')` | 加 groupby | F24 |
| L12 | 是否跑过 `verify_point_in_time` | 运行 §4.3 的验证函数，检查输出 | 逐一修复违规 | F24 |

#### 4.7 常见「看起来没问题」的泄露案例

**案例 1：按日期 groupby 的 z-score —— 看似安全，实际泄露**

```python
# ❌ 看似正确但泄露：先算全局 mean，再 groupby 做 z-score
global_mean = df['factor'].mean()  # 全序列均值 —— 泄露！
df['zscore'] = df.groupby('date')['factor'].transform(
    lambda x: (x - global_mean) / x.std()  # global_mean 含未来信息
)

# ✅ 正确：每个截面独立计算均值
# 方案 A：完全独立
df['zscore'] = df.groupby('date')['factor'].transform(
    lambda x: (x - x.mean()) / x.std()
)
# 方案 B：expanding 窗口（使用截止当前日期的历史均值和标准差）
df['zscore'] = (df['factor'] - df.groupby('stock')['factor'].expanding().mean().droplevel(0)) \
                / df.groupby('stock')['factor'].expanding().std().droplevel(0)
```

**案例 2：复权因子含未来除权除息信息**

```python
# ❌ 泄露：后复权因子可能基于全序列计算
# 如果价格数据是「后复权」，复权因子可能用到未来除权除息日期
# → 检查你的数据是「前复权」还是「后复权」
# → 前复权：当前价格已修正，历史价格不变 → 安全
# → 后复权：历史价格被修正 → 复权因子不能基于全序列计算

# ✅ 验证：价格序列在已知除权日前后是否有跳跃
# 后复权会在除权日产生 prices[t] / prices[t-1] 的异常跳跃
```

**案例 3：填充 NaN 用了「行业均值」—— 含测试集股票信息**

```python
# ❌ 泄露：行业均值含未来和测试集股票
sector_mean = df.groupby('sector')['factor'].transform('mean')  # 含未来
df['factor'] = df['factor'].fillna(sector_mean)

# ✅ 正确：每个时间截面独立计算（不含未来、不含测试集）
df['factor'] = df.groupby(['date', 'sector'])['factor'].transform(
    lambda x: x.fillna(x.mean())
)
```

**案例 4：MACD / 布林带等常用指标的天生安全性**

```python
# ✅ pandas 的 .rolling() / .ewm() 默认前向正确
# .rolling(20).mean() 使用当前行及之前 19 行 → 不含未来
# .ewm(span=20).mean() 同样前向
# .shift(1) 滞后一期，安全

# ❌ 但注意：.shift(-1) 是前瞻！
# df['future_return'] = df['close'].pct_change().shift(-1)  # 用到了明天
# → 只能用于 label 构造，绝对不能用于特征！
```

---

## 输出格式

本 skill 不生成独立文件，而是**指导 agent 在训练过程中遵循的思考框架**。最终产出为：

1. **诚实训练报告**（§2.4 格式）——每次训练后必须输出
2. **证伪检查清单**（§1.2 的 F1--F25 逐项 pass/fail）——报告前必须过一遍
3. **三列对照表**（§1.3）——对任何声称的正面结果必须跑
4. **方向饱和终态报告**（§3.6）——确认饱和时必须输出
5. **FALSIFICATION_SUMMARY.md 更新**——方向饱和时必须更新

---

## 注意事项

### 高幻觉模型的三大致命本能

高幻觉模型（DeepSeek V4 Pro / Flash 等）在量化训练中有三个本能反应，**每个都必须对抗**：

| 本能 | 表现 | 对抗方法 |
|:---|:---|:---|
| **过度乐观** | 看到 Sharpe > 0 就宣布成功 | 默认假设正面结果是假的（§1.1） |
| **过度概括** | 一次正面就推广到「策略有效」 | 要求 ≥ 3 种子 median + CI 不重叠 |
| **确认偏误** | 只找支持结论的证据，忽略反证 | 三列对照法（§1.3）+ 批判性子代理诊断 |

### 不可越界的红线

| 红线 | 原因 |
|:---|:---|
| **禁止** 在未跑随机基线的情况下报告 model α | 没有基线的 Sharpe 都是耍流氓 |
| **禁止** 在未固定种子的情况下报告统计显著性 | 未种子的结果不可复现 |
| **禁止** 在未跑 `--stop-loss none` 的情况下报告 Sharpe | 止损可能通胀 +0.2 ~ +0.4 |
| **禁止** 在 OOS IC < 0.03 时声称「有信号」 | IC < 0.03 在噪声内 |
| **禁止** 在方向饱和后继续在原数据上刷参数 | 浪费算力，§11.13 黄金法则 |
| **禁止** 在未更新 FALSIFICATION_SUMMARY.md 的情况下关闭方向 | 后续 agent 会重复已证伪的实验 |

### 与 ml-training.md 的分工

| 本 skill（认知框架） | ml-training.md（操作手册） |
|:---|:---|
| 如何辨别假 alpha（§1） | 如何跑烟雾测试（§Step 1） |
| 如何诚实报告（§2） | 如何用看门狗自动化（§扩展） |
| 如何找新方向（§3） | 如何做自优化循环（§11） |
| 15 种假 alpha 模式 | 训练事故模式 A--L |
| 种子/基线/止损协议 | GPU 隔离 / 输出缓冲 / 监控 |

两个 skill 配合使用：先用本 skill 建立认知框架（怀疑一切、证伪优先），再用 `ml-training.md` 执行具体操作（烟雾测试、看门狗、可视化）。

### 真实案例索引

以下案例均来自 `~/.pi/agent/memory/daily/` 中的真实训练记录：

| 案例 | 日期 | 教训 | 对应模式 |
|:---|:---|:---|:---|
| SGX α +0.675 → +0.020 | 2026-07-29 | 未种子基线走运，一行 seeded RNG 让「显著 alpha」跨零 | F1 |
| SGX Sharpe 0.49 → 0.91 | 2026-07-29 | STOP_LOSS=0.05 截断左尾，Sharpe 翻倍 | F2 |
| HK Sharpe +0.62, IC -0.004 | 2026-07-24 | sign-based 策略构造伪迹，IC ≈ 0 但 Sharpe > 0 | F3 |
| Glaubenskrieg WF IC 0.04-0.14, test ≈ 0 | 2026-07-24 | walk-forward 过拟合，OOS 崩溃 | F4 |
| CTM 10 个 test Sharpe 全错 | 2026-06-10 | 文档凭记忆写数值，与结果文件不符 | F5 |
| 期货 basis_proxy = sma_20_bias | 2026-07-12 | 特征复制 r=1.000 | F6 |
| SGX lowHiD IC=-0.0037, Sharpe=+1.598 | 2026-07-29 | regime-selection alpha，非选股能力 | F10 |
| MambaStock R²=-4.70 | 2026-07-24 | 预测价格水平而非收益率 | F11 |
| 期货 t-test 重叠窗口 | 2026-07-12 | 窗口重叠 → t 值高估 ~6× | F12 |
| 实盘 +70% → -10% | 2026-07-12 | 全序列 z-score 前瞻偏误 | F14 |

---

## 变更日志

### 1.1.0 (2026-07-29)
- **新增第四支柱「防泄露——时间序列数据隔离协议」**：覆盖金融时间序列中所有常见的数据泄露模式
  - 四条数据隔离铁律（§4.1）：时间/标的/统计量/标签不可穿越
  - 时间感知分割方法（§4.2）：Walk-Forward、Purge 协议、Embargo 协议、步长-窗口关系表、截面时间双重隔离
  - 特征工程时点一致性（§4.3）：7 种常见操作的 PIT 正确做法 + `verify_point_in_time()` 自动验证函数
  - 预处理隔离代码模式（§4.4）：标准化、缺失值填充、特征选择、超参搜索的隔离模板
  - 泄露严重程度分级表（§4.5）：P0-P3 四级，含 Sharpe/IC 通胀量和修复成本
  - 数据泄露审计清单（§4.6）：L1-L12 逐项检查，与 F1-F25 集成审计流程（先查泄露再查假 alpha）
  - 4 个「看起来没问题」的泄露案例（§4.7）：groupby z-score、复权因子、行业均值填充、shift 方向
- **假 alpha 模式扩展 F16-F25**：新增 10 种数据泄露专用的假 alpha 模式
  - F16 Train/Test 时间重叠、F17 标签时间穿越、F18 全局预处理泄露、F19 截面随机分割
  - F20 滚动窗口边界泄露、F21 Purge/Embargo 缺失、F22 多重测试未校正
  - F23 同股票跨集泄露、F24 全序列统计量特征、F25 测试集特征/超参选择
- 总模式数：15 → 25
- 各章节计数更新：15 种 → 25 种，F1-F15 → F1-F25

### 1.0.0 (2026-07-29)
- 初始发布
- 基于真实训练历史（2026-06-10 至 2026-07-29，SGX / HK / 期货 / A 股 / JP 多市场）
- 15 种假 alpha 模式来自 `~/.pi/agent/memory/daily/` 真实事故记录
- 三支柱结构：辨别问题（§1）→ 完成训练（§2）→ 找方向（§3）
- 与 `ml-training.md` 互补：认知框架 vs 操作手册
