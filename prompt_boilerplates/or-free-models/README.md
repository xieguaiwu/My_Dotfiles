# or-free-models — OpenRouter 免费模型扫描器

> 创建：2026-08-24 · 备份位置：`~/prompt_boilerplates/or-free-models/`
> 部署位置：`~/.local/bin/or-free-models`（chmod +x，Python3 标准库，零依赖）

## 用途
30 秒扫一遍 OpenRouter 的免费模型区，按性能代理指标排序。解决两个痛点：
① 22+ 个 `:free` 模型人工逐个看太慢；② API 不给跑分，需要启发式评分。

## 用法

```bash
or-free-models                # 全部免费模型按综合分降序
or-free-models --top 10       # 只看前 10
or-free-models --live         # +实时在线率/吞吐（逐模型请求 /endpoints，慢 ~20s）
or-free-models --min-ctx 128000 --json   # 过滤 + JSON 导出
```

## 评分构成

| 维度 | 权重 | 来源 |
|---|---|---|
| 参数量线索 | 35% | 从模型名正则解析（`550b-a55b` → 总参；对数缩放到 600B 封顶） |
| 档位关键词 | 25% | ultra/pro/max/large > super/reasoning > mini/small > nano/light/tiny |
| 上下文长度 | 15% | log10 缩放，2M ctx 封顶 |
| 能力广度 | 25% | 多模态输入（image/video/audio 加分）+ supported_parameters 数量 |

`--live` 时吞吐量(t/s, 对数)以 20% 权重重算总分。

## 已知局限与教训

1. **名称启发式低估 stealth/低调命名模型**——ox-alpha 无参数量线索排第 10，但社区证据指向近前沿水平。工具是初筛，最终优先级人工覆盖。
2. **端点陷阱**：实时 provider 数据在 `/api/v1/models/{id}/endpoints`（要去掉 `:free` 后缀再请求）；文档旧路径 `/providers` 已 404。
3. `throughput_last_30m` / `latency_last_30m` 多数 provider 返回 null（无近期统计时），只有 `uptime_last_30m` 稳定可得——live 模式优雅降级。
4. `/endpoints` 返回**付费+免费所有 provider**，必须按 `pricing.prompt=="0" && pricing.completion=="0"` 过滤才是真实免费供给。

## 实测可用性（2026-08-24 真实调用验证，非纸面数据）

22 个双零定价模型逐个发真实请求的结果：**仅 15 个真正可用**。

| 实测结果 | 模型 | 说明 |
|---|---|---|
| ✅ 可用 (15) | openrouter/free、nemotron 全系(ultra/super/nano×4/lightning/content-safety)、cohere-north、ox-alpha、dots-3-note、lfm-2.5、laguna-s/xs、nano-omni* | *nano-omni 需 max_tokens≥1000（reasoning 先耗尽预算则 content 为空但 finish_reason=stop） |
| ⚠️ 高峰拥堵 | gemma-4-31b/26b:free、glm-5.2:free | 上游 provider 返 429，间隔重试无效；免费道饱和是常态，低谷时段可用 |
| 🔒 白名单门槛 | thinkingmachines/inkling(-small):free | 裸 API 403 "only available on agentic harnesses"；加 X-Title/Referer 也不过——OpenRouter 按注册应用白名单判定 |
| 💰 假免费 | google/lyria-3-pro/clip-preview | 标价 $0 但要求账户有充值记录（402 Insufficient credits）——已从 models.json 移除 |

**方法论**：判断“能不能用”必须发真实 chat/completions 请求——模型列表存在≠可调用；定价为0≠无前置条件。

## 免费 ≠ 永久：三类免费模型（2026-08-24 快照）

| 类型 | 判别 | 例 |
|---|---|---|
| 长期免费档 | 名称带 `:free`、厂商常规免费策略（限速不限时） | deepseek/gemma/nemotron 系列 :free 变体 |
| 限时预览 | 描述含 preview / 上线即免费的 stealth 模型 | stealth/ox-alpha（8-20 起 ~1 周 → ~08-27 截止） |
| 路由聚合桶 | `openrouter/free`（轮换池，随时变） | openrouter/free |

⚠️ 所有"截止日期"均为社区报道口径，官方很少公布精确时刻——用本工具复查定价是否仍为双零即可判断是否过期。

## 免费额度与截止日期（2026-08-24 调研快照）

### 平台级限额（OpenRouter 官方 FAQ/Zendesk 确认）

| 账户状态 | 每日免费请求数 | 频率 |
|---|---|---|
| 未充值 | **50 次/天**（全平台共享，非每模型） | 20 次/min |
| 累计充值 ≥$10 | **1000 次/天** | 20 次/min |

⚠️ 多账号/多 key 不绕开限制（全局容量治理）；不同模型有独立限速，可分散负载。

### 截止日期分档

| 档位 | 模型 | 判断依据 | 可信度 |
|---|---|---|---|
| 🔴 明确限时 | stealth/ox-alpha | 8-20 上线+官方"一周免费"→ **~08-27** | 高（多源一致） |
| 🟠 预览期随时撤 | dots-studio/dots-3-note-preview、google/lyria-3-pro/clip-preview、thinkingmachines/inkling(-small) | 名称带 preview / 官方页明示 non-permanent；inkling 还限 agentic harness 且数据用于训练 | 中 |
| 🟡 新上线观察期 | poolside/laguna-s/xs-2.1、cohere/north-mini-code、liquid/lfm-2.5 | `:free` 但厂商页声明可能用输入输出训练；无公布期限 | 低-中 |
| 🟢 长期免费惯例 | nvidia/nemotron 全家（2025-09 起陆续上线至今）、google/gemma-4 系列、z-ai/glm-5.2:free | 存活 2-11 个月的 `:free` 变体，历史稳定；但厂商可随时撤（glm-5.2:free 由第三方 Decart 供给，非 Z.ai 官方） | 中 |
| ⚪ 聚合桶 | openrouter/free | 轮换池，内容随时变 | — |

**复查方法**：无需信任何文章——`or-free-models` 重跑一次，双零定价消失即视为过期。

## 相关记忆锚点

- ox-alpha 渠道矩阵与渠道决策见 MEMORY.md §㉚/㉛
- pi-agent models.json 的 fallback 链维护时先跑本工具确认存活
