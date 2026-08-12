#!/usr/bin/env bash
# =============================================================================
# pi postinstall-trigger patch — 扩展更新后自动触发 root postinstall
# =============================================================================
# 问题（2026-08-11 确认根因）：`pi update --extensions` 使用
#   npm install <specs> --prefix <root> --legacy-peer-deps
# npm 在 install 参数含包 specs 时【不会运行 root 项目的 postinstall 脚本】
# （实验验证：带参数 install 无 POSTINSTALL 输出，无参数 install 才触发）。
# 因此 ~/.pi/agent/npm/package.json 的
#   postinstall: bash ~/.pi/patches/reapply.sh && npx patch-package && bash fix-brace.sh
# 从未被自动执行——每次 pi-subagents 升级删除 temperature 支持后，
# 补丁都丢失，必须手动重打（已发生 10 次）。
#
# 修复：在 package-manager.js 的 installNpmBatch() 末尾显式追加
#   npm run postinstall --prefix <installRoot>（bun 用 --cwd）
# 幂等：postinstall 中的 reapply.sh / patch-package / fix-brace.sh 全部幂等。
# =============================================================================

set -e

PM="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/package-manager.js"

if [ ! -f "$PM" ]; then
    echo "[patch-postinstall-trigger] ⚠️  package-manager.js not found: $PM"
    exit 1
fi

python3 - << 'EOF'
import sys

path = "/home/xieguiawu/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/package-manager.js"
s = open(path).read()

MARK = "POSTINSTALL_TRIGGER_PATCHED"
if MARK in s:
    print("[patch-postinstall-trigger] ✅ already patched")
    sys.exit(0)

# ── installNpmBatch: npm install 后显式触发 root postinstall ──────────────
old = """    async installNpmBatch(specs, scope) {
        const installRoot = this.getNpmInstallRoot(scope, false);
        this.ensureNpmProject(installRoot);
        await this.runNpmCommand(this.getNpmInstallArgs(specs, installRoot));
    }"""

new = """    async installNpmBatch(specs, scope) {
        const installRoot = this.getNpmInstallRoot(scope, false);
        this.ensureNpmProject(installRoot);
        await this.runNpmCommand(this.getNpmInstallArgs(specs, installRoot));
        // POSTINSTALL_TRIGGER_PATCHED: npm skips the root project's lifecycle
        // scripts when install args include package specs, so explicitly run
        // the root postinstall (reapply.sh + patch-package + fix-brace.sh)
        // after every managed install/update.
        try {
            const pmName = this.getPackageManagerName();
            if (pmName === "bun") {
                await this.runNpmCommand(["run", "postinstall", "--cwd", installRoot]);
            } else {
                await this.runNpmCommand(["run", "postinstall", "--prefix", installRoot]);
            }
        } catch (error) {
            // A missing/failing root postinstall must not break extension installs.
        }
    }"""

if old not in s:
    print("⚠️  installNpmBatch anchor missing — version drift, manual check")
    print("   Expected snippet:")
    print(old)
    sys.exit(2)

s = s.replace(old, new, 1)
open(path, "w").write(s)
print("[patch-postinstall-trigger] ✅ patched: installNpmBatch now triggers root postinstall")
EOF
