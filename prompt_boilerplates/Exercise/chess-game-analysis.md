---
name: chess-game-analysis
version: 1.2.0
description: 国际象棋对局分析全流程——在远程服务器跑 Stockfish 18 深度分析，产出「PGN + 引擎数据表 + 中文分析报告」三件套；双轨模式（棋谱模式逐着评估，analyze_game.py 已重建验证 / 照片模式 FEN 多线深算 + 引擎自走参考续着）、静态攻守实测闭环、PGN 往返校验、引擎部署与 python-chess 踩坑库
triggers:
  - "分析国际象棋棋局"
  - "棋局复盘"
  - "Stockfish 分析"
  - "FEN 局面分析"
  - "棋局三件套"
  - "部署Stockfish"
  - "chess analysis"
inputs:
  - name: game_source
    description: '分析对象，三选一：PGN 文件路径 / SAN 着法串（1. e4 e5 ...） / FEN 快照串'
    required: true
  - name: user_color
    description: '用户执子方（white / black / unknown），决定报告视角与 Result 字段'
    required: false
    default: "unknown"
  - name: mode
    description: '分析模式：game（有走法序列，逐着评估）/ position（仅 FEN 快照）/ auto（按输入自动判定）'
    required: false
    default: "auto"
  - name: depth_profile
    description: '算力档位：light（广扫 20s + 深算 60s，试跑）/ standard（120s + 240s + 线路树，约 14 分钟）/ deep（standard 基础上关键局面 10s 复核）'
    required: false
    default: "standard"
  - name: engine_host
    description: '执行引擎的远程服务器别名（默认取空闲机，凭据走 rbw，勿写明文）'
    required: false
    default: "CPU1"
  - name: output_dir
    description: 三件套产物根目录
    required: false
    default: ~/works/记录/chess
  - name: make_reference_line
    description: 是否额外生成引擎双方最佳的参考续着 PGN（true/false）
    required: false
    default: true
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - find
  - ls
  - ask_user
  - memory_write
---

# 国际象棋对局分析（远程 Stockfish · 三件套产物）

本 skill 由两次实战蒸馏：0814 棋谱模式（一盘 lichess 对局，40 回合将杀）与 0828/0829 照片模式（仅存 FEN 快照）。凡未实跑之项，皆标「待验证」。

## 任务目标

把用户提供的棋局（PGN 或 SAN 着法串）或局面快照（FEN）送至**远程服务器**用 Stockfish 18 深度分析，在 `~/works/记录/chess/<MMDD>game/` 下产出三件套：**PGN 存档 + 引擎原始数据表 + 中文分析报告**；照片模式另加一份可重放的参考续着 PGN。目标有二：存档可复现、结论可核查。

## 前置铁律（三条，不可绕过）

1. **本机禁引擎**。用户机器为 i5-7300U（2C4T/15W），跑引擎即卡死桌面。一切 stockfish 与 python-chess 计算皆在远程执行；本机只准 `read`/`write`/`edit`/纯字符串解析（画盘、拼 PGN、算字段），不得起引擎、不得装棋类库、不得做搜索（2026-08-29 用户明令）。
2. **输入先分类，禁为照片编棋谱**。FEN 是照片、PGN 是录像。同一张照片有多条互异的合法到达路径（实测：0828 快照可由 `1.e3 e6 2.Nf3 Nc6 3.e4 b5 4.d3 h6 5.Bc4 a5 6.Bb3 d6 7.Nc3 Nf6 8.Nd5 e5` 精确复现，而把白方 e2-e3-e4 换成 d2-d4-d3、或把黑方某兵的「两步进一格」挪到 a/b/d/h 任一兵上，得的是**同一个局面**）。故照片模式**只**做单局面深算，绝不虚构中间着法去凑逐着评估曲线。
3. **证据先于断言**。报告里每一个评估数字，必须能在引擎数据文件中 grep 命中；每一条攻守结论，必须用 `Board.attackers()` 实测（本次初稿即因误用 `attacks()` 险些写出错误结论，见步骤 6）。

## 执行流程

### 1. 分类输入并确定视角

1. 判别输入类型：含 `1.` 与空格分隔的 SAN 串或 `.pgn` 文件 → **game 模式**；六字段串 → **position 模式**。
2. 若为 FEN，先逐字段读成硬事实（勿只报「这是局面」）：

   | 字段 | 读法 | 可推出的事实 |
   |---|---|---|
   | 1 摆子 | 8 排由 8→1，大写白、小写黑、数字为空格 | 子力清点与差值 → 吃子发生与否 |
   | 2 行棋方 | `w` / `b` | 谁在该着 |
   | 3 易位权 | `KQkq` 全在 | 双王四车**一次未动**，双方均未易位 |
   | 4 过路兵 | `-` 或格名 | 上一着是否双步兵 |
   | 5 半着时钟 | `0` | 上一着**必为动兵或吃子**；零吃子时即「上一着动兵」 |
   | 6 整回合数 | `N` | 已走半着数 = `(N-1)*2 + (行棋方为 b ? 1 : 0)` |

3. 用 `ask_user` 确认**用户执哪一方、结果如何**（0829 实测：用户仅给 FEN 且说「我是获胜方」，颜色不问即写反视角）。提问须同时给出「有完整棋谱 / 只有照片 / 记不清」三选项，让用户自陈素材边界。
4. 若用户素材只有照片而要求「像上次那样分析」：先讲清两模式差异，再给「能做 / 不能做」清单，勿默默降级或默默扩写。

### 2. 选空闲机并部署引擎（幂等）

1. **选机**：先 `read` 服务器事实源 `~/Desktop/ML/VERSION2.5/ASSET_INVENTORY.md`「服务器列表」，再逐台实测，取 load 低、无训练在跑者：

   ```bash
   # ⚠️ 凭据唯一源 = ~/.config/train-watch/servers.json（rbw 里没有 server/cpu1 条目，勿照抄旧命令）
   # 2026-08-29 换代后端点已变：cpu1=11:28540 / cpu2=11:20812 / gpu=36:13024
   export SSHPASS="$(python3 -c "import json;print([s['password'] for s in json.load(open('/home/xieguiawu/.config/train-watch/servers.json'))['servers'] if s['name']=='cpu1-27024'][0])")"
   timeout 30 sshpass -e ssh -p 28540 -o StrictHostKeyChecking=no root@223.109.239.11 \
     'nproc; uptime; free -g | head -2; df -h / | tail -1; grep -m1 "model name" /proc/cpuinfo; ls /root/chess/ 2>/dev/null || echo NO_CHESS'
   ```

   - 踩坑（2026-08-29）：0814 用的旧容器 `223.109.239.11:27012` 报 host key 变更（`Offending ED25519 key in known_hosts:87`），**即容器已被重建、其上 `/root/stockfish18` 与 `analyze_game.py` 全部不可用**。遇 host key 变更先按「机器已重建」处理，再确认凭据，勿归因 fail2ban。
2. **按 CPU flags 选构建**。Stockfish 18 官方发布含 `sse41-popcnt / bmi2 / avx2 / avx512 / avx512icl / avxvnni` 六档，取机器可用之最高档：

   ```bash
   grep -m1 flags /proc/cpuinfo | tr ' ' '\n' | grep -E '^(avx512_vnni|avx512f|avx2|bmi2|sse4_2)$'
   # 有 avx512_vnni（Ice Lake / SPR 系）→ avx512icl；仅 avx512f → avx512；仅 avx2 → avx2；仅 bmi2 → bmi2；否则 sse41-popcnt
   ```

   - 踩坑：`/proc/cpuinfo` 的标志名**带下划线**（`avx512_vnni`、`avx512_vnni` 非 `avx512vnni`）。首测 `grep avx512vnni` 匹配不到，曾误判该机无 VNNI 而降档。
3. **下载并解包**（须后台，直连 curl 会随 ssh 断开而死）：

   ```bash
   mkdir -p /root/chess/{bin,work} && cd /root/chess/bin
   setsid nohup bash -c 'curl -sSL --retry 5 --retry-all-errors -o sf.tar \
     https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-ubuntu-x86-64-avx512icl.tar \
     && tar -xf sf.tar && rm -f sf.tar && touch .done' >dl.log 2>&1 </dev/null &
   ```

   - 踩坑：前台 `curl` 装进 ssh 一次性命令，客户端超时即静默失败、目录留空（实测首装全空、`ls` 无一物）。判据：轮询 `.done` 与文件字节数。
   - 踩坑：官方 tar 解出为 `bin/stockfish/stockfish-ubuntu-x86-64-avx512icl`，**该文件本身就是引擎二进制**；再拼 `/stockfish` 会得 `NotADirectoryError: [Errno 20]`。
   - 磁盘占用约 110MB，勿放只读或满盘分区。
4. **装依赖并握手校验**：

   ```bash
   pip3 install -q python-chess          # 1.11.2，零依赖，纯 Python
   B=/root/chess/bin/stockfish/stockfish-ubuntu-x86-64-avx512icl; chmod +x $B
   printf "uci\nisready\nquit\n" | timeout 25 $B | grep -E '^(id name|readyok|Loading|[Ll]oading)'
   # 期望：id name Stockfish 18 + readyok；官方发布二进制 NNUE 内嵌，无 "Loading配置 failed" 行
   ```

### 3. 启动前清场（必做）

```bash
ps -eo pid,etime,cmd | grep -E "[a]nalyze_|[s]tockfish-ubuntu"
pkill -f "[a]nalyze_position.py"; pkill -f "[a]nalyze_replay.py"; pkill -f "[s]tockfish-ubuntu-x86-64"
```

- 踩坑（2026-08-29 实测，代价最高的一条）：ssh 客户端被本地 `timeout` 杀掉时，**远端进程变孤儿继续跑**；本次累积 4 个实例挤 8 核，nps 由 3.6M 掉至约 1/4，且 load 长期不降。
- 踩坑：`pkill -f` 的模式串若不含特殊处理会自匹配、把执行命令的 shell 自身杀掉（0814 旧教训）。一律用 `[a]nalyze_` 括号技巧。
- 踩坑：python-chess 的引擎后台线程**非 daemon**，脚本抛异常后进程吊住不退（实测遗留 3 个 `analyze_replay.py`）。修复：脚本入口统一 `try: main() finally: os._exit(0)`；stockfish 子进程因 stdin 管道关闭而自退。

### 4. 三个分析脚本（部署于 `/root/chess/`）

| 脚本 | 模式 | 关键 env | 产出 |
|---|---|---|---|
| `analyze_position.py` | 照片模式（已实跑） | `FEN THREADS HASH MULTIPV MULTIPV_TIME DEEP_TIME TREE_MOVES TREE_TIME OUT` | 三段式文本 |
| `analyze_replay.py` | 参考续着（已实跑） | `FEN THREADS HASH PLIES MOVE_TIME TXT PGN` | 逐着表 + 合法 PGN |
| `analyze_game.py` | 棋谱模式（**2026-09-02 重建并首跑通过**） | `PGN SF THREADS HASH BEFORE_TIME AFTER_TIME KEY_TIME SWING_KEY TXT` | 逐着 before/after 表 + 关键局面复核 + 相邻一致性核对 |

   **`analyze_game.py` 重建规格（2026-09-02，照 0814 数据文件反推，本局首跑验证）**：
   - 逐着两次独立搜索：走前 `BEFORE_TIME`（2.0s）取 `eval_before`+最佳着+PV+depth+nps；推入实际着法后 `AFTER_TIME`（2.5s）取 `eval_after`；`swing = eval_after − eval_before`。
   - 杀棋分映射 ±10000（与 0814 一致），混算 swing 会出现 `±10002.xx` 巨值——报告中须解释成因（本局：18...Rxd3 +10002.25、20.Qxg8 −10005.51 都是杀棋与兵分混算）。
   - 表头列：`# move eval_before eval_after swing depth nps best(before) -> PV`。`best(before)` 是引擎在走子前位置推荐的最佳应着（**未必是实际走法**），用它来对照「引擎想走什么 / 实际走了什么」。
   - 引擎跑完自动追加两段：①**关键局面复核**（`|swing| ≥ SWING_KEY(2.0)` 或含杀棋的着，其走前位置 10s × MultiPV=3 重算）；②**相邻一致性核对**（`eval_after[k] ≈ eval_before[k+1]`，同局两遍搜索差 <0.2 或同为同号杀棋 = OK）。本局 38/40 一致，2 处 0.21/0.23 属搜索噪声，记入数据文件即可。
   - 40 步全表耗时约 3 分钟（40 着 × (2.0+2.5)s + 14 个关键点 × 10s）；**不必开后台**，`timeout 600 ssh ... python3 -u analyze_game.py | tee` 前台等即可。
   - 脚本结构要点：`try: main() finally: os._exit(0)`（防 python-chess 非 daemon 线程吊进程）；`as_list()` 归一 `multipv=1` 返回值；`render_pv()` 白着印 `N.`、黑着裸印（首着 `N...`），复刻 0814 PV 列格式。

1. **`analyze_position.py` 三段**（照片模式，0829 实跑参数 `THREADS=6 HASH=1536 MULTIPV=8 MULTIPV_TIME=120 DEEP_TIME=240 TREE_MOVES=6 TREE_TIME=40`，耗时约 14 分钟）：
   - 阶段 1：MultiPV=N 广扫同一局面，一次搜索得 N 条候选排序（**勿逐着串行搜索**，MultiPV 共享树，效率高数倍）。
   - 阶段 2：单线深算定论（240s → depth 44、8.61 亿节点）。
   - 阶段 3：对前 N 个候选各做「对手最佳三应（MultiPV=3）→ 白方再应（MultiPV=1）」线路树，用来验证阶段 1 的排序是否随深度塌陷（0829 实测 `9.c4` 由 +0.47 跌至 +0.20，即为此类）。
   - 时长预算式：`T_total ≈ T1 + T2 + TREE_MOVES × 2 × TREE_TIME + 20%`。
2. **`analyze_replay.py`**：自快照起引擎双方各走最佳（`PLIES=24 MOVE_TIME=4.0`，约 2.5 分钟），一次产出 0814 同格式逐着表（`ply side move eval_before eval_after swing depth nps PV`）与可重放 PGN。用途是把「慢优势如何转化」变成可复盘的具体着法。
3. **`analyze_game.py`（待验证）**：重建规格须照 0814 反推——逐着「走前 2.0s + 走后 2.5s」两次独立搜索；输出列同 0814 数据文件；**必做相邻一致性核对**：`eval_after[k] ≈ eval_before[k+1]`，不等即流程有 bug（0814 血泪判据）。杀棋分与兵分混算时 swing 会出现 `±10003` 之类巨值，报告须解释，勿当真实波动。
4. **python-chess 1.11.2 API 踩坑（本次逐条踩实）**：
   - `SimpleEngine.analyse()` **无** `timeout=` 关键字，墙钟兜底须自设（或用 `Limit(time=)`）。
   - `configure()` 里设 `MultiPV` / `Ponder` / `UCI_Chess960` 会抛 `EngineError: cannot set ... which is automatically managed`；三者只可由 `analyse(multipv=N)` 等间接管理。
   - `multipv=1` 时返回值**仍是 list**，须 `as_list()` 归一，否则 `list indices must be integers` 或 `'str' object has no attribute 'get'`。
   - `Board` 无 `castling_fen()`，用 `castling_xfen()`。
   - `chess.pgn.Game` **无** `add_move/add_main_move`（1.11 已改），本次改为**手工拼装 PGN 文本**（顺带精确控制「棋号从 N 开始」的编号）。
   - PV 转 SAN：`board.copy().variation_san(pv)`，勿在原 board 上调用。

### 5. 长任务启动与取结果

```bash
cat > /root/chess/run_full.sh <<"EOS"
#!/bin/bash
cd /root/chess
export SF=/root/chess/bin/stockfish/stockfish-ubuntu-x86-64-avx512icl
export THREADS=6 HASH=1536 MULTIPV=8 MULTIPV_TIME=120 DEEP_TIME=240 TREE_MOVES=6 TREE_TIME=40
export OUT=/root/chess/work/pos_analysis.txt
python3 -u analyze_position.py > /root/chess/work/full.log 2>&1
echo "RC=$?" >> /root/chess/work/full.log; touch /root/chess/work/FULL_DONE
EOS
chmod +x run_full.sh; setsid nohup ./run_full.sh >/dev/null 2>&1 </dev/null &
```

- 线程数：8 核机留 2 核（`THREADS=6`）；GPU 训练机与跑批机**一律不去打扰**（先看 ASSET_INVENTORY 状态列，再实测 load）。
- 取结果用 `scp`，勿用 `ssh 'cat file'`：本次 `cat` 回传两次丢输出（0 字节），scp 稳。
- 轮询完成标记（`FULL_DONE` / `RC=0`）而非固定 sleep；未 DONE 前不得声称完成。

### 6. 静态事实核查闭环（防幻觉）

`verify_facts.py` 三段，产出直接附进引擎数据文件（作第三部分）：

1. **A 节 · 攻守实测**：凡「某兵有无根」「某格谁在攻」「象的斜线是否被自家子堵死」一律机器实测：

   ```python
   board.attackers(color, chess.parse_square("b5"))   # 攻击该格的子 = 正确用法
   board.is_attacked_by(chess.WHITE, chess.F7)        # 该格是否被某方攻击
   board.attacks(chess.D5)   # 相反语义：d5 上的子攻击哪些格（勿混用！）
   ```

   - 踩坑：`attacks(sq)` 与「谁攻 sq」语义**正好相反**，混用会得出「b5 被黑方保护 = []」这类看起来对、实际没测的结论。首版核查脚本全部作废重跑。
   - 实例（0829 实测，白先手 FEN）：b5 黑方保护者 `[]`、白方攻击者 `[]` → **无根兵**；走 `a4` 后白攻方 `[a4]`、黑保护者仍 `[]`；`f7` 白攻方 `[]` → 证实 b3 象被自家 d5 马堵死；e5 兵白攻 `[f3]` 黑保 `[c6, d6]` → 当下无得子战术。
2. **B 节 · PGN 往返校验**：见步骤 7 的 PGN 血坑，校验式＝`chess.pgn.read_game()` 后数 `mainline_moves()` 的 ply 数、边推演边取 SAN、终局 FEN 与生成脚本记录值比对。
3. **C 节 · 推断的定向复核**：报告里凡由 MultiPV 排序推出的结论（例：「未进前三的应着评估不低于第三名 +2.38」），须另做针对该着法的定向搜索验证（0829：`9.a4 Be6` 40s 实测 +2.59，推断成立）；未复核者文中显式标「推断」。
4. 同一局面两次独立跑的 PV 次级着法可能漂移（首选同为 +2.59，次佳 +2.40 / +2.51），属搜索次序正常现象；文中写明量级一致即可，勿假装可复现到小数。

### 7. 写三件套

1. **目录与命名**：`~/works/记录/chess/<MMDD>game/`。先 `ls` 看用户既有习惯再定名——0814 用 `0814-stockfish2-1`（日期-对手-局号）；照片模式用 `0828-局面`（无法命名对手）；**0902 快棋对局（对手名未知）用 `0902-otb-1`**（日期-otb-局号，`otb` 取自 lichess over-the-board Site 标识）。若用户已建好空目录（如 `0828game/`），**用之**，勿另起新目录。命名习惯已三次固化：`<MMDD>-<对手或otb>-<局号>` 三件套同前缀。
2. **PGN 规范**：
   - game 模式：标准头（`Event/Site/Date/Round/White/Black/Result/WhiteElo/BlackElo`）+ 逐着 SAN + 末尾结果串。
   - position 模式：加 `[SetUp "1"]` 与 `[FEN "..."]`；**Result 必须与棋谱自洽**：无着法则 `Result "*"`，真实胜负写进注释，**绝不为迁就「你赢了」而写 1-0 造假**。
   - ⚠️ **PGN 空行血坑（本次最隐蔽）**：movetext 内一旦出现**空行**，python-chess **静默截断**后续着法且不报错——实测同一份棋谱，`{注释}` 与首着之间多一个空行 → 24 着解析成 **0 着**；着法中间插空行 → 截成 **13 着**。正确写法：标签块与 movetext 之间只留**一个**空行；注释紧贴首着（同行或次行）；棋着区内绝无空行。手工 wrap 时留意「首 token 超长会先 append 一个空串」这类隐性造空行 bug。
   - 棋号续排：照片模式起点非第 1 回合，手工拼装须 `no = start_fullmove + i//2`，白着才印序号。
3. **引擎数据文件**（`<前缀>-引擎数据.txt`）：banner（起始 FEN / 引擎与构建 / 机器与线程 / 视角声明 / 生成时间）+ 各部分原文逐字存档 + 每部分前置说明（说明该部分的搜索参数与列含义）。表头须自带判读说明（`eval = White POV，+ = 白优`）。**game 模式的标准五段**（0902 首次固化）：①主表（逐着 before/after）②关键局面复核（10s MultiPV=3）③相邻一致性核对④静态事实核查（终局 mate 验证 + PGN 往返 + 定向搜索 C1–C7）⑤杀棋/大 swing 成因注记。
4. **分析报告**（`<前缀>-分析.md`）：固定节（详见「输出格式」，game 模式七节 / position 模式八节）。文首引言块必写引擎版本、构建、机器、线程、分析方式、视角、原始数据文件名。**「对手错过的制胜战术」与「用户本可更快的取胜点」两节须诚实对列**——本局黑方错过 4 次制胜、白方错过 5 次，报告把双方失误都写全，不因用户获胜而美化。
5. **评估曲线由脚本生成，勿手绘**：按数据文件的 `eval_before` 序列算 min/max 后逐格投影（先手绘后改脚本，返工一次）。本机纯字符串解析可画（不涉及引擎计算，不违反禁引擎铁律）；杀棋值（±10000）须先钳制到显示范围（如 ±9.5）再投影。曲线附 x 轴（回合号每 5 标注）与 y 轴（cp 每 2 标注），并在图上注释大 swing 点的回合。
6. 判读标尺先定义再用：Δ = 该着评估 − 最佳着评估；`Δ ≤ 0.15` 同级最佳、`0.15~0.35` 可接受、`0.35~0.6` 稍缓、`> 0.6` 明显缓手或疑问手。未定义即写「失误」属无标尺断言。

### 8. 交付校验（声称完成前必跑）

```bash
# 1) 报告引用的每个数字都要在数据文件里命中
for v in "+0.92" "+0.78" "+0.89" "depth=44" "+2.38"; do printf "%-10s %s\n" "$v" "$(grep -c -- "$v" *-引擎数据.txt)"; done
# 2) PGN 往返（远端跑，本机无 chess 库）：plies / 终局 FEN / 起点回合
# 3) 远端清场复查：ps | grep -cE "[a]nalyze_|[s]tockfish-ubuntu" 应为 0；uptime 回落
# 4) ls -la 产物目录，确认文件数与命名
```

1. 三项全绿方准交付。任何一项不中，先修数据/文案，不得先出报告。
2. 收尾写记忆：`memory_write` daily 记本次结论与产物路径；机器/引擎/偏好有变则更新 MEMORY ㉟（含「引擎一律远程」「三件套格式」两条）。

## 输出格式

### 文件清单

| 文件 | game 模式 | position 模式 | 内容 |
|---|---|---|---|
| `<日期>-<名>.pgn` | ✅ 完整棋谱 | ✅ 快照存档 | 标准头 + 着法 / `[SetUp]`+`[FEN]` |
| `<日期>-<名>-引擎数据.txt` | ✅ 逐着表 | ✅ 深算三段 + 自走表 + 核查 | 原始引擎输出逐字存档 |
| `<日期>-<名>-分析.md` | ✅ 八节报告 | ✅ 八节报告 | 中文分析 |
| `<日期>-参考续着.pgn` | 可选 | ✅（默认出） | 引擎双方最佳自走 |

### 分析报告八节骨架（position 模式实例，2026-08-29）

```text
〇、本报告与上一份的区别（素材边界声明：照片 ≠ 录像，能做 / 不能做）
一、快照或棋谱里能读出的硬事实（FEN 六字段表 + ASCII 棋盘 + 双方子力清点）
二、总判（引擎最终评估 + 深度 + 节点数 + 优势来源，静态可验证项逐条列出）
三、候选排序表（着法 / 广扫值 / 深算校验值 / Δ / 定性 / 引擎主线）
四、首选着法详解（对手前 N 应着各自评估与后果 + 未入选项的推断复核）
五、与人类直觉分歧最大的几步（教训式写法）
六、模型续着与评估轨迹（脚本生成图 + 变现要点）
七、给用户的实战建议（可迁移原则，非本局专有）
八、复现方式与引擎部署（机器 / 路径 / 命令 / 踩坑 / 局限声明）
```

### 分析报告八节骨架（game 模式实例，2026-09-02）

```text
引言块（引擎 / 机器 / 分析方式 / 视角 / 原始数据引用）
一、棋局概况（对局 / 结果 / 开局 / 过程 / 终局描述）
二、评估曲线（脚本生成 ASCII 图 + 特征解读）
三、关键时刻（按 |swing| 排序表：着法 / 走前 / 走后 / 波动 / 判定；先声明判读标尺）
四、对手错过的制胜战术（含「同一个制胜着连错 N 次」的强调）
五、用户亮点（含引擎认为并非最佳但实战有效的思路，注明与引擎分歧）
六、用户本可更快的取胜点（每行：局面 / 引擎推荐 / 实际走 / 后果）
七、跨局连续性复盘（与往局对照：执子颜色 / 风格签名 / 反复错失的战术主题 / 胜负依赖模式 / 开局倾向——见下方详细规范）
八、结论与建议（诚实标注连续性与模式，给出专项训练建议）
```

### 跨局连续性复盘（game 模式必写，2026-09-02 新增）

在写报告前，必须先读 `~/works/记录/chess/*game/*-分析.md` 全部过往报告，提取六维对比表。

#### 六维对照表

| 维度 | 本局 | 往局 1（<MMDD>） | 往局 2（<MMDD>） | 连续性结论 |
|---|---|---|---|---|
| ①执子方与结果 | 例：黑 / 0-1 胜 | 例：黑 / 0-1 胜 | 例：白 / 快照 | 执黑连胜、执白待续 |
| ②对手开局风格 | 例：白 h4/Rh3 车升 | 例：白 h4/g3/c3 侧翼 | — | 对手均走怪异王翼开局 |
| ③用户风格签名 | 皇后侵略性（几着女王） | 后深插攻王（Qf3） | 慢攻磨优势 | 皇后侵略是有效武器 |
| ④反复错失的战术主题 | 错过的具体 motif | 往局同主题 | 往局是否也可 | 连续两局都出现的 motif → 升级为「待改进模式」 |
| ⑤胜负依赖 | 对手未惩罚次数 | 往局对手未惩罚次数 | — | 连续靠对手失误 → 需警惕 |
| ⑥收官力度 | 将杀完成度 | 将杀完成度 | — | 是否总能完成杀棋 |

#### 写法要求

1. **素材**：`ls ~/works/记录/chess/ | grep game` 得到全部过往 game 目录，逐一 `read` 其 `*-分析.md`，提取上表六维数据。
2. **连续性断言必须有证据**：每一条「与上局相同/不同」的结论，必须能在对应往局报告中 grep 命中。禁止凭印象编造。
3. **重复 motif 显式标注**：若本局错失的战术主题与往局重复（如 0814 与 0902 都错过一步杀/两步杀），必须写「与 0814 相同模式——连续两局收官前未检索强制着法」。
4. **连续 N 局出现的弱项 → 专项训练建议**：在结论（八）中给出可执行的训练方向（如「杀棋前检索训练：每天 5 道 mate-in-2/3 题」）。
5. **写法位置**：放在报告七（跨局连续性复盘），独立于六（用户本可更快的取胜点）和八（结论），不承接六的逐条列举，而是从全局视角看用户棋艺的连续性与变化。
6. **引用往局数字**：数字必须从对应报告/数据文件复核，不可直接引用本局数据当往局数据。

#### 实例（0902 对照 0814/0828）

```text
七、跨局连续性复盘（与 0814 / 0828 对照）

| 维度 | 0814 棋谱 | 0828 快照 | 0902 本局 | 连续性结论 |
|---|---|---|---|---|
| 执子方/结果 | 黑 / 胜 0-1 | 白 / 快照 | 黑 / 胜 0-1 | 执黑→两胜，执白→待续 |
| 对手开局 | 白 h4/g3/c3/Bg2 侧翼 | —（第 9 着前） | 白 h4/Rh3!? 车升 | 对手均走 h4 系怪异王翼开局 |
| 用户风格签名 | 后 f3 深插攻王（31...Qf3） | 慢攻磨优势 | 皇后大巡游（7 次皇后着） | 皇后侵略性持续有效，但偏激进 |
| 反复错失主题 | 3 次两步杀未走（Nh2+/Ne3+） | 无战术机会 | 6 次制胜未走（含一步杀+吃后） | 两局都错过收官前强制着法检索 |
| 胜负依赖 | 白方 8 次错失惩罚 | — | 白方 4 次错失（Qf5+连错 2 次） | 两局都靠对手未惩罚获胜 |
| 收官 | Bd6# 教科书配合杀 | — | Qd1# 笼杀教科书 | 两局都以干净将杀收场 |

**连续性结论**：
1. 执黑连胜（两局），对手都走 h4 系怪异开局，用户早得优势。
2. 最醒目的连续性弱项：收官前未检索强制着法——0814 错过 3 次两步杀，0902 错过一步杀与吃后。这不是偶发，是模式：收官时先数步数，再走自然着。
3. 胜负依赖对手未惩罚（0814 白方 8 次错失、0902 白方 4 次错失）——两局都赢在对手手滑；若对手不送，0902 第 18 回合后其实白方已在败势（+2.32）。
4. 正面连续性：两局都以教科书式将杀收官（Bd6# / Qd1#），攻王网一旦织成，完成度很高。
5. 皇后侵略性是有效武器，但 0902 多次皇后着法并非引擎最佳（Qd5/Qd4/Qe5/Qxa2 均非引擎首选）——需平衡侵略与精确。
6. 专项建议：训练「杀棋前检索」（mate-in-2/3 题库）——连续两局都死在同样的检索缺失上。
```

### 关键显示约定

| 情形 | 处理 |
|---|---|
| 杀棋分 | 显示 `#N`（正为白杀、负为黑杀）；混算出的 swing 巨值（如 `+10003.55`）须在文中解释成因 |
| 视角 | 全文统一白方视角，并在引言块声明「+ = 白优」；用户执黑时另注「+ = 对手优」 |
| 棋盘 | ASCII 八行 + 子力清点行，勿用图片 |
| 未复核结论 | 句中标「推断」，并另跑定向深算补证 |

## 注意事项

1. **素材不足的边界**：仅有 FEN 时，「评估曲线 / 失误排名 / 错失战术清单」三节**不写**，改为「候选排序 + 首选详解 + 模型续着」。切勿以反推棋谱充数。
1b. **终局杀法验证的陷阱（0902 血泪）**：终局 `attackers()` 逐格查逃格会漏判「王不能沿将线逃跑」——本局 Qd1# 中 f3 格静态查攻击者为空（因王 e2 正挡在 d1-e2 斜线上），但王一移向 f3 就解除 e2 阻挡、黑后 d1 的斜线贯至 f3。**判杀必须用 `board.is_checkmate()`（或 `legal_moves == []`）做最终裁决**，`attackers()` 逐格只能作辅助说明；报告中解释逃格时须把「移开后解除阻挡、攻击线贯通」这类格写清楚。
2. **不合法或已终局的输入**：`Board(fen).is_valid()` 为假 → 报错并回问用户重贴；局面已 `is_game_over()` → 只出结论与终局判定，不出候选表。
3. **引擎评估 ≠ 人类难度**：SF18 给的 +0.9 属「双方最佳下的理论值」，业余对手未必能兑现；报告中须区分「理论优势」与「实战好下」。
4. **MultiPV 排序即结论**：未进前 N 的应着，其评估不优于第 N 名（同一搜索结果内成立）；跨搜索/跨深度不可直接引用。
5. **安全**：服务器密码只经 `rbw get server/<别名>` 或 `~/.ssh/config` 取用；本文件与产物中**禁出现明文密码**；对外可见仓库（My_Dotfiles）不同步本 skill 之外的凭据字段。
6. **资源**：8 核机 `THREADS≤6`；避开 GPU 训练机与跑批机；单次 standard 档约 14 分钟、参考续着约 2.5 分钟、核查约 1 分钟；引擎目录 110MB，勿重复下载（先 `ls /root/chess/bin/stockfish/`）。
7. **已解待验证项**：`analyze_game.py` 已于 2026-09-02 重建并在 0902 局首跑通过（40 步全表 + 相邻一致性 38/40 + 关键局面复核 + 定向搜索，全部落盘验证）。`deep` 档（关键局面 10s 复核）已隐含在 `analyze_game.py` 的 KEY_TIME 复核段（10s MultiPV=3），照片模式独立 `deep` 档仍待跑。
8. **若日后取回真实棋谱**：直接切 game 模式复用同一引擎与数据格式，勿把照片模式的结论当成实战评判依据。
9. **连号复用**：`analyze_game.py` 已部署于 CPU1 `/root/chess/`（与 position/replay 脚本同目录），后续 game 模式直接 `scp` PGN 到 `/root/chess/work/game.pgn` + 设 env 跑即可，无需重建。

## 变更日志

### 1.2.0 (2026-09-02)

- **新增跨局连续性分析要求（game 模式必写）**：报告须含第七节「跨局连续性复盘」，对照全部往局（`~/works/记录/chess/*game/*-分析.md`）提取六维对比表（执子方与结果 / 对手开局风格 / 用户风格签名 / 反复错失的战术主题 / 胜负依赖模式 / 收官力度）。
- 连续性断言必须有往局报告证据（grep 可命中）；重复 motif 显式标注「与往局相同模式」；连续 N 局弱项须在结论给出专项训练建议。
- game 模式报告由七节扩为八节（原七节结论 → 八节）。
- 0902 实战对照实例已写入规范（0814/0828/0902 三局六维表）。

### 1.1.0 (2026-09-02)

- **`analyze_game.py` 重建并首跑通过**（0902 局，40 步全表）：逐着 before 2.0s + after 2.5s、杀棋映射 ±10000、`best(before) -> PV` 列、自动追加关键局面复核（10s MultiPV=3）与相邻一致性核对（38/40 一致，2 处噪声）。脚本部署于 CPU1 `/root/chess/analyze_game.py`，env 驱动（`PGN/SF/THREADS/HASH/BEFORE_TIME/AFTER_TIME/KEY_TIME/SWING_KEY`）。
- 新增格式要求（本局固化）：
  - 命名：game 模式对手名未知时用 `<MMDD>-otb-<局号>`（otb 取自 lichess over-the-board Site）。
  - 引擎数据文件五段制：主表 / 关键局面复核 / 相邻一致性核对 / 静态事实核查（含 C1–C7 定向搜索）/ 杀棋成因注记。
  - game 模式分析报告八节骨架（见输出格式，含跨局连续性复盘）。
  - 「对手错失的制胜」与「用户本可更快的取胜点」两节必须对列，双方失误都写全，不因胜负美化。
  - 终局判杀铁律：`attackers()` 逐格会漏判「王不能沿将线逃跑」（0902 Qd1# 的 f3 格），须以 `is_checkmate()` 终裁。
  - 评估曲线用脚本生成，杀棋值先钳制再投影，附双轴与关键点注释。
- 凭据与端点更新：rbw 无 `server/cpu1` 条目，凭据唯一源 = `~/.config/train-watch/servers.json`；2026-08-29 换代后 cpu1=11:28540 / cpu2=11:20812 / gpu=36:13024。
- 已解待验证项：`analyze_game.py`（原随 27012 容器丢失）重建完成并首跑验证；照片模式独立 `deep` 档仍待跑。

### 1.0.0 (2026-08-29)

- 初始发布。素材来源：0814 棋谱模式实战（`~/works/记录/chess/0814game/`）+ 0828/0829 照片模式实战（`~/works/记录/chess/0828game/`，四件产物 + 远端 `/root/chess/` 三个脚本）
- 新增前置铁律三条：本机禁引擎、FEN 禁反推棋谱、证据先于断言
- 新增部署经验：按 CPU 标志选 SF18 构建（`avx512_vnni → avx512icl`）、tar 解出二进制名、host key 变更即容器重建、后台 curl + `.done` 轮询
- 新增运行经验：启动前清孤儿进程、python-chess 非 daemon 线程吊进程、`setsid nohup` + scp 取回、standard 档时长预算式
- 新增防幻觉闭环：`attackers()` 攻守实测、PGN 往返校验、MultiPV 推断的定向复核、两次独立跑漂移说明
- 新增 PGN 血坑：movetext 空行静默截断（24→0/13 着）与注释/换行正确写法、照片模式 Result 自洽规则
- 新增 python-chess 1.11.2 API 踩坑六条（`timeout=` 不存在、自动管理项、`multipv=1` 返 list、`castling_xfen`、`pgn.Game` 无 `add_move`、`variation_san`）
- 待验证：`analyze_game.py` 重建、`deep` 档交叉验证
