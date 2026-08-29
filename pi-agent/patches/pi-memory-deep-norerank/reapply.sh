#!/usr/bin/env bash
# =============================================================================
# pi-memory deep-search patch — degrade deep mode to hybrid RRF (--no-rerank)
# =============================================================================
# 问题（2026-08-10）：qmd deep 搜索（qmd query）的 rerank 阶段在本机必崩：
#   - 默认 Vulkan 后端：vk::Queue::submit: ErrorDeviceLost（Intel HD 620 / Mesa ANV）
#   - QMD_FORCE_CPU=1 后：Bun 1.3.14 segfault（llama.cpp CPU 后端绑定崩溃）
# qmd 只内置 Qwen3-Reranker-0.6B 一个 reranker，无配置可禁（仅 env QMD_RERANK_MODEL）。
# 修复：pi-memory 扩展 deep 模式调用加 --no-rerank（hybrid RRF，BM25+向量混合，
# 实测 4s 稳定返回）。keyword/semantic 不受影响（search/vsearch 不触发 reranker）。
#
# 配套：QMD_FORCE_CPU=1 全局设置（~/.config/environment.d/50-qmd.conf + fish conf.d），
# embedding 走 CPU 稳定模式，避免 Vulkan 崩溃风险。
#
# 幂等：已有标记注释则跳过。postinstall 自动重打（~/.pi/patches/reapply.sh）。
# 生效：需重启 pi 主进程（扩展模块缓存）。
# =============================================================================

set -e

PIM="$HOME/.pi/agent/npm/node_modules/pi-memory/index.ts"

if [ ! -f "$PIM" ]; then
    echo "[patch-pi-memory-deep] ⚠️  pi-memory/index.ts not found: $PIM"
    exit 1
fi

python3 - << 'EOF'
import sys

path = "/home/xieguiawu/.pi/agent/npm/node_modules/pi-memory/index.ts"
s = open(path).read()

MARK = "[patch:deep-norerank]"
if MARK in s:
    print("[patch-pi-memory-deep] ✅ already patched")
    sys.exit(0)

old = '\tconst subcommand = mode === "keyword" ? "search" : mode === "semantic" ? "vsearch" : "query";\n\tconst args = [subcommand, "--json", "-c", "pi-memory", "-n", String(limit), query];'
new = '\tconst subcommand = mode === "keyword" ? "search" : mode === "semantic" ? "vsearch" : "query";\n\t// [patch:deep-norerank] reranker (Qwen3-Reranker-0.6B) crashes on this machine\n\t// (Vulkan ErrorDeviceLost / CPU Bun segfault) — degrade deep to hybrid RRF.\n\tconst args = [subcommand, "--json", "-c", "pi-memory", "-n", String(limit), ...(mode === "deep" ? ["--no-rerank"] : []), query];'

if old not in s:
    print("⚠️  pi-memory args anchor missing — version drift, manual check")
    sys.exit(2)

s = s.replace(old, new, 1)
open(path, "w").write(s)
print("[patch-pi-memory-deep] ✅ applied: deep mode now uses --no-rerank")
EOF
