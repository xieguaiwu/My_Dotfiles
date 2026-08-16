---
name: pi-subagents-enametoolong-fix
version: 3.1.0
description: pi-subagents 结果索引 ENAMETOOLONG 独立修复 skill——判别路由、四层补丁 verify/apply、死索引与空目录清扫、验证闭环（聚合中文路径 session 全部修复知识）
triggers:
  - "ENAMETOOLONG"
  - "subagent 报错"
  - "subagent_wait 挂起"
  - "async 结果丢失"
  - "result-pending 报错"
  - "中文路径 session"
  - "pi-subagents 补丁重打"
inputs:
  - name: mode
    description: "verify: 只检查补丁是否在位 | apply: 检查缺失则重打（默认）"
    required: false
    default: "apply"
tools:
  - read
  - edit
  - bash
  - grep
---

# pi-subagents ENAMETOOLONG 修复（中文路径 session）

## 任务目标
一站式修复 pi-subagents 结果索引与 result-pending 的 ENAMETOOLONG（name too long）
报错：判别错误归属、核查四层补丁是否在位（缺失或升级覆盖则重打）、清扫死索引条目
与空目录、验证闭环。聚合此前散落在 System_Fix 各文档与实战记录中的全部修复知识。

## 执行流程

### 1. 判别错误类型
先确认报错是 ENAMETOOLONG 而非其他 /tmp 相关错误：

| 错误码 | 含义 | 处理 |
|--------|------|------|
| `ENOSPC` / `no space left on device` | 空间/配额不足（含换出页占配额） | 走 `enospc-tmpfs-check.md` |
| `ENAMETOOLONG` / `name too long` | 路径组件名超 255B，与空间无关 | 本 skill 继续 |
| `EACCES` / `EPERM` | 权限 | 查属主/挂载选项，非本 skill 范围 |

快速自检：`df -h /tmp` 看空间；对报错中的超长名字测字节数
`python3 -c "print(len('<超长名字>'.encode()))"`——>255B 即 ENAMETOOLONG。

### 2. 确认报错来源（旧进程 vs 当前代码）
用 grep -n 对照报错堆栈行号与当前文件：

```bash
grep -n "function existingResultFile\|function promotePendingResultFile\|function resultPayloadLocationFromIndex" \
  ~/.pi/agent/npm/node_modules/pi-subagents/src/runs/background/result-files.ts
```

- 堆栈行号与当前行号基本一致 → 当前代码仍可能抛错，进入步骤 3 核查补丁
- 堆栈行号明显小于当前行号 → 报错来自旧进程（tsx 模块缓存），查存活进程
  `ps -eo pid,lstart,cmd | grep -iE 'pi$|tsx'`；有旧进程则重启 pi，勿改代码

### 3. 核查四层补丁（mode: verify 只查缺失，apply 补缺失层）
逐层 grep 确认：

| 层 | 位置 | 判据 |
|----|------|------|
| 1 encodeSegment 截断+哈希 | result-files.ts | 存在 `MAX_SEGMENT = 180` 与 sha1 截断 |
| 2 existingResultFile 静默 | result-files.ts | catch 同时吞 ENOENT 与 ENAMETOOLONG |
| 3 遗留目录迁移 | result-files.ts / result-watcher.ts | `migrateLegacyResultSegments` 导出且 primeExistingResults 调用 |
| 4 定期自愈清扫 | result-watcher.ts | `RESULT_CLEANUP_INTERVAL_MS` + `pruneEmptyPendingDirs` |

缺失层按「附录：修复」对应代码块补回。补丁目录：
`~/.pi/agent/npm/node_modules/pi-subagents/src/runs/background/`

### 4. 清扫死索引条目与空目录
死条目判定：索引条目解析不到 result/pending payload 即死（索引只会在 payload
写成功后写入）。用模块自带函数清扫：

```bash
TSX=$HOME/.pi/agent/npm/node_modules/tsx/dist/cli.mjs
R=/tmp/pi-subagents-uid-$(id -u)/async-subagent-results
node "$TSX" -e "
import { cleanupResultIndexes, pruneEmptyPendingDirs } from '$HOME/.pi/agent/npm/node_modules/pi-subagents/src/runs/background/result-files.ts';
console.log('removed dead index entries:', cleanupResultIndexes('$R', Date.now(), 0));
pruneEmptyPendingDirs('$R');
console.log('empty pending dirs pruned');
"
```

- 用 pi 自带的 tsx，勿用 `npx tsx`（无网络时 npx 会卡在安装提示）
- `maxAge=0` 用于一次性全清；周期清扫用 10 分钟 maxAge（grace 期内条目保留）
- 谨慎确认有效结果（resultsDir 根部 `*.json` 与其索引）不被误删——cleanup 只删
  解析不到的条目

### 5. 验证闭环
- 构造 339B 死条目 + 新条目（<10 分钟），跑清扫确认「删旧留新」✅
- 扫描函数对死条目完全静默（`missionObserverResultCandidateFiles` 等不抛错）✅
- 生产目录：有效结果文件与索引不受影响 ✅
- 重启 pi 主进程后观察无 ENAMETOOLONG 刷屏 ✅

### 6. 收尾
- 同步 `System_Fix/index.md` 目录表版本、决策树、交叉引用（须与 front matter
  version 一致）
- 写入 memory（daily log + 教训），便于下次检索

## 输出格式
修复结果报告（Markdown 文本）：

```text
判别：ENAMETOOLONG（路径 339B > 255B）
补丁状态：第 1-4 层 ✓/✓/✓/✓（缺失层已补）
清扫：移除 N 个死索引条目，M 个空目录
验证：静默测试通过 / 有效结果不受影响 / 重启后无刷屏
```

## 注意事项
- **堆栈行号是破案第一线索**：行号与当前文件不符 = 旧进程在报错（tsx 模块缓存），
  先 `ps` 查进程，勿急着改代码（第三波实战教训）
- 补丁在 `~/.pi/agent/npm` 下，`npm update` / pi-subagents 升级会覆盖，升级后
  必须按步骤 3 重打（历史教训：v0.31.0→0.31.1 曾覆盖 12 个补丁文件）
- 修复后须重启 pi 主进程生效（扩展启动时绑定；运行中进程持旧代码）
- 索引条目与 payload 可分离存在：payload 写失败 ≠ 索引不存在；死条目判定 =
  解析不到 payload 且超 grace（10 分钟）
- >255B 目录根本无法创建：旧代码写 pending 时 mkdir 即失败，payload 不可恢复；
  但输出通常经 completion-replay 通道投递，用户一般无实质损失
- 周期清扫须节流（每 10 分钟）+ 幂等 + rmdir 静默——多 pi 进程共享同一
  resultsDir 并发扫描，必须安全
- ENAMETOOLONG 不是 ENOSPC：/tmp 下 `name too long` 勿拿 enospc 流程查
  （判别见步骤 1）

## 附录：详细诊断与修复参考

### 症状
pi 启动/绑定时反复报错（两处，同根因，均非致命但中断结果索引初始化/投递）：

**① 启动期索引扫描失败**：

```
Failed to scan subagent result index in '/tmp/pi-subagents-uid-1000/async-subagent-results':
Error: ENAMETOOLONG: name too long, scandir '.../result-index/sessions/%2Fhome%2F...%E9%98%90%E8%BF%B0...jsonl'
    at listIndexFiles (result-files.ts:321)
    at primeExistingResults (result-watcher.ts:552)
```

**② 运行期结果检查刷屏**（file-coalescer 每轮重试都打印）：

```
Failed to inspect async result payload '.../result-pending/%2Fhome%2F...%E9%AB%98%E4%B8%80-...jsonl/ee925c92-....json':
Error: ENAMETOOLONG: name too long, stat '...'
    at existingResultFile (result-files.ts:175)
    at promotePendingResultFile (result-files.ts:199)
    at resultPayloadLocationFromIndex (result-files.ts:250)
```

**③ 死索引条目反复扫描刷屏（2026-08-16 第三波，堆栈指向 175 行 = 第 1 波代码）**：

```
Failed to inspect async result payload '.../result-pending/%2Fhome%2F...%E9%AB%98%E4%B8%80-%E6%95%B0%E5%AD%A6-2026AP...-2026-06-1--%2F2026-08-16T05-45-55-826Z_....jsonl/6ccc6d5c-....json':
Error: ENAMETOOLONG: name too long, stat '...'
    at existingResultFile (result-files.ts:175:15)
    at promotePendingResultFile (result-files.ts:199:8)
    at resultPayloadLocationFromIndex (result-files.ts:250:24)
    at indexedResultFile (result-files.ts:313:20)
    at resultFilesFromIndexDir (result-files.ts:341:26)
    at missionObserverResultCandidateFiles (result-files.ts:394:10)
    at Timeout.primeExistingResults (result-watcher.ts:552:26)
```

### 根因
`pi-subagents/src/runs/background/result-files.ts` 的 `encodeSegment()` 用
`encodeURIComponent(sessionId)` 直接做结果索引目录名。`sessionId` 是完整
session 路径（含 cwd）。当 cwd 含非 ASCII 字符（中文等），每个字符 URL 编码后
膨胀为 9 字节（UTF-8 3 字节 × %XX），完整编码名可达 335+ 字节，超过 ext4 等
文件系统单文件名 255 字节上限 → 内核拒绝解析 → ENAMETOOLONG。

`listIndexFiles()` 只吞 ENOENT/ENOTDIR，ENAMETOOLONG 向上抛 → 结果 watcher
初始化失败，async 结果索引写入/读取均可能中断（subagent_wait 有挂起风险）。
旧版未截断的 181-255B 目录名（能创建但超长）若不做迁移，修复后的
decode→re-encode 会得到不同路径 → pending 结果漏找（subagent_wait 静默挂起）。

### 第三波根因（2026-08-16）：
- **sessionId 是完整 session 文件路径**（含嵌套目录 + `.jsonl` 后缀），编码后
  可达 339B（实测 高一-数学-2026AP…-2026-06-1--/2026-08-16T05-45-55-…jsonl）。
  >255B 的目录名**根本无法创建**：旧代码写入 pending 时 mkdir 即失败，payload
  丢失，但结果索引条目（observers/sessions/tool-calls）仍可能残留。
- 死条目带 339B sessionId，旧代码每次 `primeExistingResults` 定时扫描都 stat
  该不可能路径 → ENAMETOOLONG 刷屏（每次约 10+ 条，直到进程重启）。
- 本次报错进程是**第 1 波补丁后、第 2 波补丁前**启动的旧进程（堆栈行号 175 =
  existingResultFile 尚无 try/catch 的版本）；当前代码对同类条目完全静默。
- 实际影响：run 6ccc6d5c 的 payload 丢失（不可恢复），但其输出经
  completion-replay 通道正常投递，用户已收到监测报告，无实质损失。

### 修复（2026-08-15/16，四层补丁）
文件：`~/.pi/agent/npm/node_modules/pi-subagents/src/runs/background/result-files.ts`
+ `result-watcher.ts`

#### 第 1 层：encodeSegment 长度有界 + 稳定哈希
`encodeSegment` 改为长度有界 + 稳定哈希（读写同函数，一致）：

```ts
import { createHash } from "node:crypto";
...
function encodeSegment(value: string): string {
	const encoded = encodeURIComponent(value);
	// 单文件名上限 255 字节（ext4 等）。URL 编码后的完整 session 路径在 cwd
	// 含非 ASCII 字符（如中文）时每字符展开为 9 字节，可超限导致 ENAMETOOLONG，
	// 使结果索引写入/扫描整体失败。超长时截断并附加稳定哈希（读写同函数，一致）。
	const MAX_SEGMENT = 180;
	if (encoded.length <= MAX_SEGMENT) return encoded;
	const digest = createHash("sha1").update(value).digest("hex").slice(0, 16);
	return `${encoded.slice(0, MAX_SEGMENT - 17)}-${digest}`;
}
```

真实出错 sessionId：335B → 180B（含 `.json` 后缀 185B < 255B）✅

#### 第 2 层：existingResultFile 对 ENAMETOOLONG 静默
旧数据/旧进程升级后的残留超长路径，视为不存在即可，不再每次重试刷屏：

```ts
function existingResultFile(resultPath: string): boolean {
	try {
		return fs.statSync(resultPath).isFile();
	} catch (error) {
		const code = (error as NodeJS.ErrnoException).code;
		if (code !== "ENOENT" && code !== "ENAMETOOLONG") console.error(`Failed to inspect async result payload '${resultPath}':`, error);
		return false;
	}
}
```

#### 第 3 层：遗留目录启动期迁移 + 扫描兼容
- 新增导出 `migrateLegacyResultSegments(resultsDir)`：把 `result-pending/`、
  `result-index/sessions/` 下旧版未截断的 181-255B 目录重命名为规范
  截断+哈希名（幂等；无法解码/重命名冲突的原样保留）。
- 在 `result-watcher.ts` 的 `primeExistingResults()` 开头调用（每次 pi
  启动自愈）。
- `pendingResultLocationForIndexedRun()` 改为按磁盘目录名直接扫描目录内
  payload（匹配 runId），不再 decode→re-encode → 新旧两种命名都能找到。

完整代码（result-files.ts，`cleanupResultIndexes` 之前）：

```ts
export function migrateLegacyResultSegments(resultsDir: string): void {
	const roots = [
		path.join(resultsDir, RESULT_PENDING_DIR),
		path.join(resultsDir, RESULT_INDEX_DIR, SESSION_INDEX_DIR),
	];
	for (const root of roots) {
		let entries: fs.Dirent[];
		try {
			entries = fs.readdirSync(root, { withFileTypes: true });
		} catch (error) {
			if ((error as NodeJS.ErrnoException).code === "ENOENT") continue;
			throw error;
		}
		for (const entry of entries) {
			if (!entry.isDirectory()) continue;
			let decoded: string;
			try {
				decoded = decodeURIComponent(entry.name);
			} catch {
				continue;
			}
			const canonical = encodeSegment(decoded);
			if (canonical === entry.name) continue;
			try {
				fs.renameSync(path.join(root, entry.name), path.join(root, canonical));
				console.error(`Migrated legacy async result segment '${entry.name}' -> '${canonical}'`);
			} catch (error) {
				if ((error as NodeJS.ErrnoException).code !== "ENOENT") console.error(`Failed to migrate legacy async result segment '${entry.name}':`, error);
			}
		}
	}
}
```

`pendingResultLocationForIndexedRun()` 直接扫描版（替换原 decode→re-encode 实现）：

```ts
function pendingResultLocationForIndexedRun(resultsDir: string, runId: string): ResultPayloadLocation | undefined {
	const root = path.join(resultsDir, RESULT_PENDING_DIR);
	let sessions: fs.Dirent[];
	try {
		sessions = fs.readdirSync(root, { withFileTypes: true });
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "ENOENT") console.error(`Failed to inspect pending async result root '${root}':`, error);
		return undefined;
	}
	for (const session of sessions) {
		if (!session.isDirectory()) continue;
		const location = pendingResultLocationInDir(path.join(root, session.name), runId);
		if (location) return location;
	}
	return undefined;
}
```

#### 第 4 层：定期自愈清扫（2026-08-16，v2.1.0）
在 `primeExistingResults()` 中 migrate 之后加入节流清扫（每进程每 10 分钟一次）：

```ts
if (Date.now() - lastResultCleanupAt >= RESULT_CLEANUP_INTERVAL_MS) {
	lastResultCleanupAt = Date.now();
	try {
		cleanupResultIndexes(resultsDir, Date.now(), RESULT_CLEANUP_MAX_AGE_MS);
		pruneEmptyPendingDirs(resultsDir);
	} catch (error) {
		console.error("Failed to prune stale async result indexes:", error);
	}
}
```

- `cleanupResultIndexes(resultsDir, now, 10min)`：移除无 result/pending payload
  且 >10 分钟的索引条目（索引只会在 payload 写成功后写入，解析不到 = 死条目；
  <10 分钟的在途条目受 grace 保护）。
- 新增导出 `pruneEmptyPendingDirs(resultsDir)`：删 `result-pending/` 空目录
  （payload 消费后的空壳），只删空目录，幂等安全。
- 多进程并发执行安全：幂等 + force:true + rmdir 失败静默。

配套代码（缺一则 apply 编译失败，逐项补）：

result-watcher.ts 常量（`SLOW_RESULT_SCAN_MS` 之后）：

```ts
const RESULT_CLEANUP_INTERVAL_MS = 10 * 60 * 1000;
const RESULT_CLEANUP_MAX_AGE_MS = 10 * 60 * 1000;
```

result-watcher.ts 闭包变量（`resultScanTimer` 之后）：

```ts
	let lastResultCleanupAt = 0;
```

result-watcher.ts import（"./result-files.ts" 行首加入两个新导出）：

```ts
import { cleanupResultIndexes, pruneEmptyPendingDirs, ... } from "./result-files.ts";
```

result-files.ts 新增导出（`cleanupResultIndexes` 之后）：

```ts
export function pruneEmptyPendingDirs(resultsDir: string): void {
	const root = path.join(resultsDir, RESULT_PENDING_DIR);
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(root, { withFileTypes: true });
	} catch {
		return;
	}
	for (const entry of entries) {
		if (!entry.isDirectory()) continue;
		try {
			fs.rmdirSync(path.join(root, entry.name));
		} catch {
			// 非空或并发写入：保留，下次再试
		}
	}
}
```

### 验证
- 模拟测试（/tmp/test-enametoolong-fix.ts，tsx 运行，全部通过）：
  ① 未迁移的遗留 195B 目录可被直接扫描找到 ✅
  ② 迁移后重命名为规范名（≤197B），查找/解析一致 ✅
  ③ 新写入落在规范目录，不产生第二目录 ✅
  ④ >255B 组件 stat 不抛异常（第 2 层容错）✅
- 生产结果目录实测迁移：唯一 195B 遗留目录（高一-英语-SAT-0813hw）已重命名 ✅
- `result-watcher.ts` 模块加载正常 ✅
- 同包其他 `encodeURIComponent` 用法排查：`nested-events.ts`（rootRunId/
  capabilityToken）、`active-run-index.ts`（toolCallId）、`completion-replay.ts`
  （runId）均为 UUID/短 token，无同类风险 ✅
- 第三波实测（2026-08-16）：
  ① 构造 339B sessionId 死 observer 条目（10 分钟前）+ 新条目（<10 分钟）→
     清扫删旧留新（grace 生效）✅
  ② 8 个遗留空 pending 目录全部清除 ✅
  ③ 清扫后扫描函数对死条目完全静默、有效结果（97a87830）不受影响 ✅
  ④ 生产目录清扫：18 个死索引条目移除，仅保留可解析条目 ✅
- 已确认无旧版进程存活（ps 仅剩当日启动的 pi 进程 + intercom broker），
  当前代码对 339B 条目零报错；用户看到的刷屏来自 13:45-14:12 间的旧进程，
  随进程重启消失。

### 生效方式
重启 pi 主进程（tsx 模块缓存，扩展在启动时绑定；已运行的旧进程仍持旧代码）。
补丁在 `~/.pi/agent/npm` 下，`npm update` / pi 包重装会覆盖（历史教训：
v0.31.0→0.31.1 曾覆盖 12 个补丁文件），升级后需重新应用本补丁。

### 遗留影响
- 补丁前未能写入的 pending 结果（如 ee925c92-…/0f77ed1e-…，其 pending 目录
  名超 255B 根本无法创建）不可恢复；对应 subagent_wait 挂起/超时属历史损失。
- 已成功投递的结果不受影响；本次迁移仅重命名空目录/残留目录，无数据移动。

### 上游跟进
可向 github.com/nicobailon/pi-subagents 提 issue：session 路径 URL 编码做
目录名无长度上限，建议改用截断+哈希（本补丁方案）或 sha1 短哈希。

## 变更日志

### 3.1.0 (2026-08-16)
- 修复：第 3/4 层补丁代码不完整——apply 模式无法重打（第 3 层缺 migrate 函数与直扫循环完整代码，第 4 层缺常量/闭包变量/import/pruneEmptyPendingDirs 函数体），现已补全
- 精进：执行流程步骤 4 清扫命令改用 pi 自带 tsx 与 `$(id -u)`（去 npx 网络依赖与硬编码 uid）
- 精进：附录修复第 1-4 层标题降为四级（修复章节为三级，层级不再扁平）

### 3.0.0 (2026-08-16)
- 重构：按 skill_creator.md 升级为独立可执行 skill（任务目标/执行流程 6 步/输出格式/注意事项）
- 聚合：enospc 判别路由、旧进程行号判定法、死条目判定与清扫命令、补丁重打流程、周期清扫纪律——此前散落在 enospc-tmpfs-check.md、index.md、memory 的内容

### 2.1.0 (2026-08-16)
- 修复：第三波 ENAMETOOLONG 刷屏（死索引条目反复扫描）——确认当前代码已静默，
  新增定期自愈清扫（cleanupResultIndexes 10min maxAge + pruneEmptyPendingDirs），
  死条目/空目录 10 分钟内自动清理，无需手工介入
- 新增：症状③（死 observer 条目刷屏，堆栈指向 175 行旧代码）+ 第三波根因分析
- 修复：run 6ccc6d5c payload 丢失不可恢复（旧进程 339B 路径写失败），输出经
  completion-replay 通道投递成功

### 2.0.0 (2026-08-15)
- 修复：existingResultFile 对 ENAMETOOLONG 静默（不再每轮重试刷屏）
- 修复：遗留 181-255B 目录 decode→re-encode 路径不一致导致 pending 漏找
- 新增：migrateLegacyResultSegments 启动期自愈迁移 + 直接目录扫描兜底
- 新增：YAML front matter（可被 pi-agent 触发加载）

### 1.0.0 (2026-08-15)
- 初始发布：encodeSegment 截断 + 稳定哈希（v0.50.0）
