---
name: piagent-cmap-fix
version: 1.0.0
description: 诊断并修复 Pi-agent 处理 PDF 时的 CMap 字体数据加载警告（Unable to load CMap data / Unknown type 1 charstring command）。根因是 unpdf ESM 版本将 CMap/标准字体路径设为 file:// URL，而 Node.js 的 fs.readFile 不识别该协议。
triggers:
  - "Pi-agent PDF报错"
  - "CMap data 加载失败"
  - "loadFont translateFont failed"
  - "Unknown type 1 charstring"
  - "Unable to load CMap"
  - "pdfjs CMap"
  - "unpdf CMap"
  - "PDF处理警告"
  - "pi agent PDF warning"
  - "fix PDF extraction pi-agent"
inputs:
  - name: mode
    description: "check-only: 只诊断不修复 | auto: 自动修复（默认）"
    required: false
    default: "auto"
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
---

# Pi-agent PDF CMap 加载修复

## 任务目标

诊断并修复 Pi-agent 在处理含 CJK 字体或复杂字体的 PDF 时出现的两条警告：

```
Warning: loadFont - translateFont failed: "UnknownErrorException: Unable to load CMap data at: file:///.../node_modules/"
Warning: Unknown type 1 charstring command of "0"
```

## 背景知识：完整调用链

Pi-agent 的 PDF 提取功能经过 4 层调用：

```
pi-web-access/pdf-extract.ts (line 47)
  → getDocumentProxy(new Uint8Array(buffer))           // unpdf

unpdf/dist/index.mjs (line 55-63, 修复前)
  → const base = import.meta.resolve("pdfjs-dist/package.json")
  → cMapUrl: new URL("./cmaps/", base).href            // 产生 file:// URL
  → standardFontDataUrl: new URL("./standard_fonts/", base).href  // 同上

pdfjs-dist/build/pdf.mjs (line 8990)
  → const url = `${baseUrl}${filename}`                // 拼接完整 URL
  → this._fetch(url, kind)                             // 调用 NodeBinaryDataFactory

pdfjs-dist/build/pdf.mjs (line 9417-9433)
  → NodeBinaryDataFactory._fetch → node_utils_fetchData(url)
  → fs.promises.readFile(url)                          // fs 不识别 file:// 协议！
```

**核心矛盾**：`new URL().href` 返回 `file:///home/.../cmaps/` 格式的 URL，但 `fs.promises.readFile()` 只接受 `/home/.../cmaps/` 格式的纯文件系统路径。Node.js 的 `fs` 模块不自动转换 `file://` 协议。

> **注意**：CJS 版本（`unpdf/dist/index.cjs`）使用 `require("path").dirname(require.resolve(...))` 直接返回纯路径，不受影响。只有 ESM 版本存在问题。Pi-agent 及其扩展以 ESM 模式运行（`"type": "module"`），所以必须走 ESM 路径。

## 受影响文件

| 文件 | 路径 | 角色 |
|------|------|------|
| unpdf ESM | `~/.pi/agent/npm/node_modules/unpdf/dist/index.mjs` | **需要修复的目标** |
| unpdf CJS | `~/.pi/agent/npm/node_modules/unpdf/dist/index.cjs` | 参考实现（已正确） |
| 补丁文件 | `~/.pi/agent/npm/patches/unpdf+1.6.2.patch` | 修复持久化 |
| pdfjs-dist | `~/.pi/agent/npm/node_modules/pdfjs-dist/build/pdf.mjs` | 下游消费者 |

## 执行流程

### Phase 1：诊断（并行采集）

所有命令可并行执行。

#### 1.1 确认 unpdf 版本和文件存在

```bash
PATCH_DIR="$HOME/.pi/agent/npm"
echo "=== unpdf 版本 ==="
node -e "console.log(require('$PATCH_DIR/node_modules/unpdf/package.json').version)" 2>/dev/null || \
  node --input-type=module -e "import pkg from '$PATCH_DIR/node_modules/unpdf/package.json' with {type:'json'}; console.log(pkg.version)" 2>/dev/null

echo "=== 关键文件 ==="
ls -la "$PATCH_DIR/node_modules/unpdf/dist/index.mjs"
ls -la "$PATCH_DIR/patches/unpdf+1.6.2.patch" 2>/dev/null || echo "(补丁文件不存在)"
```

#### 1.2 检查当前 CMap URL 是 file:// URL 还是纯路径

```bash
# 检查 ESM 版本中的 cMapUrl 赋值
grep -n "cMapUrl\|standardFontDataUrl" ~/.pi/agent/npm/node_modules/unpdf/dist/index.mjs
```

**判断标准**：
- ❌ 存在 `new URL("./cmaps/", base).href` → **有问题，需要修复**
- ✅ 存在 `basePath + "/cmaps/"` → 已修复
- ✅ 存在 `require("path").dirname(require.resolve(...))` → CJS 版本，当前不相关

#### 1.3 检查补丁是否包含 fileURLToPath 转换

```bash
grep -c "fileURLToPath" ~/.pi/agent/npm/patches/unpdf+1.6.2.patch 2>/dev/null && \
  echo "✅ 补丁已包含 fileURLToPath 转换" || \
  echo "❌ 补丁缺少 fileURLToPath 转换"
```

#### 1.4 验证 fs 不识别 file:// URL（快速确认根因）

```bash
node -e "const fs = require('fs'); try { fs.readFileSync('file:///etc/hostname'); console.log('UNEXPECTED: OK'); } catch(e) { console.log('EXPECTED FAIL:', e.code); }"
```

预期输出：`EXPECTED FAIL: ENOENT`

#### 1.5 验证 Pi-agent 使用 ESM 模式

```bash
grep '"type"' ~/.pi/agent/npm/node_modules/pi-web-access/package.json | head -1
```

预期输出：`"type": "module"`

### Phase 2：修复

如果 Phase 1 中 `index.mjs` 仍使用 `new URL().href` 模式，执行以下修复。

#### 2.1 直接修改 unpdf ESM 源文件

将 `getDocumentProxy` 函数中的 `cMapUrl` 和 `standardFontDataUrl` 从 `file://` URL 改为纯文件系统路径。

**搜索目标**：

```js
    try {
      const base = import.meta.resolve("pdfjs-dist/package.json");
      nodeDefaults = {
        disableFontFace: true,
        standardFontDataUrl: new URL("./standard_fonts/", base).href,
        cMapUrl: new URL("./cmaps/", base).href,
        cMapPacked: true
      };
    } catch {
    }
```

**替换为**：

```js
    try {
      const { fileURLToPath } = await import("node:url");
      const { dirname } = await import("node:path");
      const base = import.meta.resolve("pdfjs-dist/package.json");
      const basePath = dirname(fileURLToPath(base));
      nodeDefaults = {
        disableFontFace: true,
        standardFontDataUrl: basePath + "/standard_fonts/",
        cMapUrl: basePath + "/cmaps/",
        cMapPacked: true
      };
    } catch {
    }
```

使用 `edit_file` 工具精确替换。

#### 2.2 重新生成补丁文件

```bash
cd ~/.pi/agent/npm && npx patch-package unpdf --patch-dir patches
```

这会将修改持久化为 `patches/unpdf+1.6.2.patch`，供后续 `npm install` 自动重打。

#### 2.3 验证修复

```bash
# 确认修改已生效
grep -n "basePath\|fileURLToPath" ~/.pi/agent/npm/node_modules/unpdf/dist/index.mjs

# 用真实 PDF 快速验证（使用任意已存在的 PDF）
PDF=$(find ~/Downloads -name "*.pdf" -type f 2>/dev/null | head -1)
if [ -n "$PDF" ]; then
  cd ~/.pi/agent/npm && node --input-type=module -e "
    import {readFile} from 'node:fs/promises';
    import {getDocumentProxy} from 'unpdf';
    const buf = await readFile('$PDF');
    const pdf = await getDocumentProxy(new Uint8Array(buf));
    const page = await pdf.getPage(1);
    const text = await page.getTextContent();
    console.log('✅ pages:', pdf.numPages, '| text items:', text.items.length);
    console.log('   first 80 chars:', text.items.map(i=>i.str||'').join(' ').substring(0,80));
  " 2>&1
fi
```

**成功标准**：无 CMap/loadFont 警告，正确输出页数和文本内容。

## 补丁自动重打机制

Pi-agent 扩展的 `package.json` 包含 postinstall 脚本：

```json
"scripts": {
  "postinstall": "bash \"$HOME/.pi/patches/reapply.sh\" && npx patch-package"
}
```

`npx patch-package` 会自动查找 `./patches/` 目录下的所有 `.patch` 文件并应用。因此只要补丁文件存在，`npm install` 或 `pi update` 后修改会自动恢复。

> `~/.pi/patches/reapply.sh` 当前是 no-op（旧的 pi 包已内置补丁），不影响本修复。

## 注意事项

1. **CJS 版本不受影响**：`unpdf/dist/index.cjs` 使用 `require("path").dirname(require.resolve(...))` 直接返回纯路径，仅 ESM 版本需要修复。

2. **"Unknown type 1 charstring command" 警告**：此警告来自 PDF.js 的 Type 1 字体解析器，与 CMap 加载无关。CMap 加载失败可能导致字体回退到 Type 1 解析路径，间接触发此警告。修复 CMap 后此警告通常会减少，但若 PDF 本身包含非标准 Type 1 指令，仍可能出现残留警告——这是正常的，不影响文本提取。

3. **版本兼容性**：本修复适用于 `unpdf@1.6.2` + `pdfjs-dist@5.6.205` 组合。如果 Pi-agent 升级了这些依赖，补丁可能需要调整 line offset。此时应检查新版本的 `getDocumentProxy` 函数是否已内置此修复，若未内置则重新生成补丁。

4. **替代修复方案**：也可以修改 `pdfjs-dist` 的 `node_utils_fetchData` 函数，在 `fs.readFile` 前添加 `fileURLToPath` 转换。但修改 unpdf 更简单、更局部化，且不会影响其他 pdfjs-dist 消费者。

5. **修复后需重启 Pi-agent**：已运行的 Pi-agent 进程不会自动加载修改后的模块，需要重启 TUI。
