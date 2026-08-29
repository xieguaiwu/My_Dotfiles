#!/usr/bin/env bash
# =============================================================================
# pi update-timeout patch — git fetch/clone + npm install 网络超时
# =============================================================================
# 问题（2026-08-10 实测 28m38s）：`pi update --extensions` 中
#   - ensureGitRef() 的 `git fetch` 无 timeoutMs（runCommand 不设超时）
#   - installGit() 的 `git clone` 无 timeoutMs
#   - runNpmCommand()（npm install）无 timeoutMs
# 代理节点抽风时连接停滞即无限挂起。全局 git http.lowSpeedLimit 兜不住
# （libcurl 停滞时不总是触发 low-speed abort）。
#
# 修复：给三类网络操作加超时
#   - git fetch      60s   (GIT_NETWORK_TIMEOUT_MS)
#   - git clone      120s  (GIT_CLONE_TIMEOUT_MS)
#   - npm install    300s  (NPM_INSTALL_TIMEOUT_MS, runNpmCommand 默认)
#
# 幂等：已有标记常量则跳过。postinstall 自动重打（~/.pi/patches/reapply.sh）。
# =============================================================================

set -e

PM="$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/package-manager.js"

if [ ! -f "$PM" ]; then
    echo "[patch-update-timeout] ⚠️  package-manager.js not found: $PM"
    exit 1
fi

python3 - << 'EOF'
import sys

path = "/home/xieguiawu/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/package-manager.js"
s = open(path).read()
changed = []

# ── 1) 常量 ──────────────────────────────────────────────────────────────
if "GIT_NETWORK_TIMEOUT_MS" not in s:
    old = "const NETWORK_TIMEOUT_MS = 10000;"
    if old not in s:
        print("⚠️  anchor 'const NETWORK_TIMEOUT_MS' missing — version drift, manual check")
        sys.exit(2)
    s = s.replace(old, old + "\nconst GIT_NETWORK_TIMEOUT_MS = 60000;\nconst GIT_CLONE_TIMEOUT_MS = 120000;\nconst NPM_INSTALL_TIMEOUT_MS = 300000;", 1)
    changed.append("constants")

# ── 2) git clone 超时 ────────────────────────────────────────────────────
old = 'await this.runCommand("git", ["clone", source.repo, targetDir]);'
if old in s:
    s = s.replace(old, 'await this.runCommand("git", ["clone", source.repo, targetDir], { timeoutMs: GIT_CLONE_TIMEOUT_MS });', 1)
    changed.append("git clone timeout")
elif '["clone", source.repo, targetDir], { timeoutMs' not in s:
    print("⚠️  git clone anchor missing — version drift, manual check")
    sys.exit(2)

# ── 3) git fetch 超时（ensureGitRef）──────────────────────────────────────
old = 'await this.runCommand("git", fetchArgs, { cwd: targetDir });'
if old in s:
    s = s.replace(old, 'await this.runCommand("git", fetchArgs, { cwd: targetDir, timeoutMs: GIT_NETWORK_TIMEOUT_MS });', 1)
    changed.append("git fetch timeout")
elif "fetchArgs, { cwd: targetDir, timeoutMs: GIT_NETWORK_TIMEOUT_MS }" not in s:
    print("⚠️  git fetch anchor missing — version drift, manual check")
    sys.exit(2)

# ── 4) runNpmCommand 默认超时 ─────────────────────────────────────────────
old = """    async runNpmCommand(args, options) {
        const npmCommand = this.getNpmCommand();
        await this.runCommand(npmCommand.command, [...npmCommand.args, ...args], options);
    }"""
if old in s:
    new = """    async runNpmCommand(args, options) {
        const npmCommand = this.getNpmCommand();
        await this.runCommand(npmCommand.command, [...npmCommand.args, ...args], {
            timeoutMs: NPM_INSTALL_TIMEOUT_MS,
            ...options,
        });
    }"""
    s = s.replace(old, new, 1)
    changed.append("npm install timeout")
elif "timeoutMs: NPM_INSTALL_TIMEOUT_MS," not in s:
    print("⚠️  runNpmCommand anchor missing — version drift, manual check")
    sys.exit(2)

open(path, "w").write(s)
if changed:
    print(f"[patch-update-timeout] ✅ applied: {', '.join(changed)}")
else:
    print("[patch-update-timeout] ✅ already patched")
EOF
