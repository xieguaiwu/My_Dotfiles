# sat-ocr-pipeline — 扫描版 SAT 题库 → LaTeX 全流程脚本

配套 `sat-exercise-splitter.md`（同目录）的**可执行实现**。2026-08-19 实战沉淀：
阅读 160 题 + 语法 100 题（iScanner 扫描版，无文本层）全流程跑通，答案 260/260 与答案键 0 差异。

## 流程总览

```
源 PDF (扫描版)
   │ ① pdftoppm 渲染 (200 DPI, 1页/图)
   ▼
raw_{book}.json ── ② 多路转录 ── transcribe_worker.py (云端链)
                  │              local_3b_worker.py (本地 GPU 兜底, 无限量)
                  ▼
answers_key_final.json ── ③ 答案键 ── answer_key_transcribe.py (整页)
                                   answer_key_strip.py (密排表格: 条带裁剪)
                  ▼
                  └── ④ repair.py (漏题/坏页补扫, 覆盖写)
                  ▼
build_latex.py ── ⑤ 解析→清洗→分节→tex
                  ▼
tectonic ── ⑥ 编译验证 → *_questions.pdf / *_answers.pdf
```

## 脚本说明

| 脚本 | 用途 | 关键参数 |
|---|---|---|
| `transcribe_worker.py` | 逐页转录主 worker：zhipu→omni→nano-vl→gemma 链，增量保存 raw_{book}.json，TOC 预期题数校验，断点续跑 | `python3 transcribe_worker.py reading [start end]`；环境变量 `SAT_OCR_BASE`(默认 /tmp/sat_ocr) `ZHIPU_API_KEY` `OPENROUTER_API_KEY` |
| `local_3b_worker.py` | 本地 Qwen2.5-VL-3B GPU lane（免费无限量，15s/页；需 transformers + 本地模型路径 /root/liuji/qwen-vl-3b 可改） | `python3 local_3b_worker.py reading`；**串行单进程防 OOM**；图像 1024px + max_new 5200（1280px+6000 会 CUDA OOM） |
| `answer_key_transcribe.py` | 答案键整页转录（omni 链），输出 answers_key_{book}.json | 自动跳过已完成页；zhipu 余额 1113 自动跳过 |
| `answer_key_strip.py` | **密排答案表正解**：页面横切 4 条 + 放大 + nano-vl 逐条读 | prompt 必须极简（"Transcribe this table."）；复杂 prompt 会触发 'choices' 空响应或幻觉循环 |
| `repair.py` | 指定页重转录并覆盖（漏题/坏页修复轮） | `python3 repair.py jobs.json`，jobs 格式 `[{"book","pg","expect"}]` |
| `build_latex.py` | 转录→结构化→LaTeX：专题分节、题号节内自 1、UL/BLANK/表格/notes 处理、答案键比对 | 模块级 `BASE`（数据目录）/`OUTDIR`（输出目录）需在 import 后设置 |
| `final_build.sh` | 一键收尾：同步服务器→构建→编译→验证→复制交付 | 服务器地址/密码需按环境修改（**勿提交真实凭据**） |
| `watchdog_cron.sh` | cron 看门狗：3 路 worker + 本地 3B 保活（每 3 分钟） | 注意 pgrep 自匹配坑（`[w]orker.py` 方括号）与 cron 环境 PATH（用绝对 python 路径） |
| `probe_providers.py` | 探测 zhipu/kimi/nvidia/openrouter 可用性，可用则写 PROBE_OK | 配合 probe_run.sh 定时唤醒任务 |

## 环境变量

```bash
export SAT_OCR_BASE=/tmp/sat_ocr          # 工作目录 (pages/, raw_*.json)
export ZHIPU_API_KEY=...                  # open.bigmodel.cn (glm-4.5v)
export OPENROUTER_API_KEY=...             # openrouter.ai (免费:free 模型)
export KIMI_API_KEY=... NVIDIA_API_KEY=... # 备用探测
```

**API key 一律走环境变量/密钥文件，禁止硬编码进脚本**（遵 `../git_safety_net.md` 与偏好 ⑨）。

## 数据文件格式

- `raw_{book}.json`：`{"{book}_{pdf_page}": {"book","pdf_page","text","model","count","expect"}}`，text 为转录原文（HEADER/PASSAGE/QUESTION/OPTIONS/FOOTER/COUNT 结构）
- `raw_local_{book}.json`：本地 3B lane 的输出（与 raw_*.json 合并时**非 local 优先**，见 build_latex.py load_book）
- `expect_{book}.json`：`{"pdf_page": 预期题数}`，由目录(TOC)探针生成（见 make_expect_map.py）
- `answers_key_final.json`：`{"reading": {"1": "A", ...}, "grammar": {...}}`
- `final_jobs.json`：修复轮任务清单（漏题页 + UL 缺失页）

## 2026-08-19 实战教训（务必阅读）

1. **转录数据实时同步本地**：服务器凌晨可能被重建/停用（/tmp 全清、凭据变更、host key 更换）。每完成一批就 `scp` 回本地，别只信任服务器磁盘。
2. **openrouter 免费配额 = 50 请求/日/账号**（`free-models-per-day`，北京时间 08:00 重置；充值 $10 → 1000/日）。超限后所有 :free 模型 429，只能等或换源。zhipu 余额 1113 死、kimi 账号可能被 suspend、nvidia 免费 key 会 403——**probe_providers.py 先探再用**。
3. **密排答案表**：整页直读必幻觉（nano-vl 输出 Q1-5 ABCDE 循环）。正解 = 条带裁剪（`answer_key_strip.py`）。
4. **页内完全重复题 = 幻觉回声**：同题干+同选项只留一个（build_latex.py 已内置按 (q, options) 签名去重）。但**同题干不同选项是真双题页**（SAT 词汇/过渡题常见），不能误删——阈值是选项组是否完全相同。
5. **双题同干页**（如阅读 p43）：omni 常把两题选项合并成一堆 A-D 重复块。repair 后需人工检查：`QUESTION 标记数 == 选项组数`。
6. **本地 3B 参数红线**：1024px 缩放 + max_new_tokens 5200（1280px 或 6000 tokens 即 CUDA OOM）；显存不足时 `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`。
7. **UL 划线检测**：下划线在降采样后消失，3B/omni 专注检测都不可靠（20/20 全 NO_UNDERLINE）。有下划线题需在修复轮 prompt 中要求 `*[UL_START]*`，且不保证成功——失败就作为已知限制上报。
8. **fail2ban/服务器重建 vs SSH 拒绝**：先查凭据是否变更（host key changed = 重建了），再怀疑封禁。

## 关联 skill

- `sat-exercise-splitter.md` — 本目录的指导文档（拆分、排版、验证规范）
- `exam-paper-cloner.md` §0.3a — 服务器端 OCR / vision 模型选择 / SSH 不稳应对
- 下游：`sat-error-note-generator.md`（错题笔记）、`mistake-practice-generation.md`（AI 练习卷）
