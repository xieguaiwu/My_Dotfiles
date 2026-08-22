#!/usr/bin/env bash
# =============================================================================
# pi-agent patches — reapply after npm updates
# =============================================================================
# This script is called by pi-agent's postinstall hook and can also be
# run manually after any npm update (pi update, npm install, etc).
#
# Patches managed here:
#   1. Temperature chain — PI_SUBAGENT_TEMPERATURE → provider API
#   2. Update timeouts — git fetch/clone + npm install network timeouts
#      (pi update --extensions hanging for 28m+ when proxy stalls)
#   3. pi-memory deep --no-rerank — reranker crashes on this machine (Vulkan/CPU)
# =============================================================================

set -e

PATCHES_DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

echo "[patch] Checking pi-agent patches..."

# ─── Temperature chain ─────────────────────────────────────────────
if [ -x "$PATCHES_DIR/temperature/reapply.sh" ]; then
    echo ""
    if "$PATCHES_DIR/temperature/reapply.sh" --apply; then
        echo "[patch] Temperature chain OK"
    else
        echo "[patch] Temperature chain needs attention (see above)"
        FAIL=1
    fi
fi

# ─── Update timeouts ────────────────────────────────────────────────────
if [ -x "$PATCHES_DIR/update-timeout/reapply.sh" ]; then
    echo ""
    if "$PATCHES_DIR/update-timeout/reapply.sh"; then
        echo "[patch] Update timeouts OK"
    else
        echo "[patch] Update timeouts need attention (see above)"
        FAIL=1
    fi
fi

# ─── pi-memory deep --no-rerank ──────────────────────────────────────
if [ -x "$PATCHES_DIR/pi-memory-deep-norerank/reapply.sh" ]; then
    echo ""
    if "$PATCHES_DIR/pi-memory-deep-norerank/reapply.sh"; then
        echo "[patch] pi-memory deep --no-rerank OK"
    else
        echo "[patch] pi-memory deep --no-rerank need attention (see above)"
        FAIL=1
    fi
fi

# ─── postinstall trigger ─────────────────────────────────────────────
# npm skips root lifecycle scripts when install args include specs, so
# installNpmBatch() must explicitly run the root postinstall after every
# managed install/update, otherwise reapply.sh never runs automatically.
if [ -x "$PATCHES_DIR/postinstall-trigger/reapply.sh" ]; then
    echo ""
    if "$PATCHES_DIR/postinstall-trigger/reapply.sh"; then
        echo "[patch] postinstall trigger OK"
    else
        echo "[patch] postinstall trigger needs attention (see above)"
        FAIL=1
    fi
fi

# ─── (future patches) ──────────────────────────────────────────────

if [ $FAIL -eq 0 ]; then
    echo "[patch] All patches applied"
else
    echo "[patch] Some patches could not be applied — review output above"
fi
