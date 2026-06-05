#!/usr/bin/env bash
# =============================================================================
# pi-agent patches — reapply after updates
# =============================================================================
# Run this script after `pi update` or `npm update` to re-apply local fixes.
#
# Patches:
#   1. Autocomplete: fix dropdown disappearing on exact match (editor.js)
#   2. Context lag:   fix status bar showing 0% for providers w/o contextWindow
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[patch]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()  { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ── Resolve target files ────────────────────────────────────────────────────

PI_TUI_DIR="${PI_TUI_DIR:-$HOME/.pi/agent/npm/node_modules/@earendil-works/pi-tui/dist/components}"
PI_CORE_DIR="${PI_CORE_DIR:-$HOME/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/dist}"

EDITOR_JS="$PI_TUI_DIR/editor.js"
SESSION_JS="$PI_CORE_DIR/core/agent-session.js"
FOOTER_JS="$PI_CORE_DIR/modes/interactive/components/footer.js"

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Sanity checks ───────────────────────────────────────────────────────────

for f in "$EDITOR_JS" "$SESSION_JS" "$FOOTER_JS"; do
    if [ ! -f "$f" ]; then
        err "Target file not found: $f"
    fi
done

# Check if already patched (idempotent guard)
if grep -q "normalizedPrefix = prefix.startsWith" "$EDITOR_JS" 2>/dev/null; then
    warn "editor.js appears already patched — skipping autocomplete patches"
    SKIP_EDITOR=1
else
    SKIP_EDITOR=0
fi

if grep -q "contextWindow <= 0.*return" "$SESSION_JS" 2>/dev/null && \
   ! grep -q "still return the token estimate" "$SESSION_JS" 2>/dev/null; then
    SKIP_SESSION=0
elif grep -q "still return the token estimate" "$SESSION_JS" 2>/dev/null; then
    warn "agent-session.js appears already patched — skipping context-lag patches"
    SKIP_SESSION=1
else
    SKIP_SESSION=0
fi

# ── Backups ─────────────────────────────────────────────────────────────────

BACKUP_DIR="$PATCH_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$EDITOR_JS" "$BACKUP_DIR/editor.js.bak"
cp "$SESSION_JS" "$BACKUP_DIR/agent-session.js.bak"
cp "$FOOTER_JS" "$BACKUP_DIR/footer.js.bak"
log "Backups saved to $BACKUP_DIR"

# =============================================================================
# Patch 1: Autocomplete fixes (editor.js)
# =============================================================================

if [ "$SKIP_EDITOR" -eq 0 ]; then
    log "Applying autocomplete patches to editor.js..."

    # 1a. Fix getBestAutocompleteMatchIndex — slash command prefix normalization
    #     Match the function signature and insert the normalizedPrefix logic
    sed -i '/getBestAutocompleteMatchIndex(items, prefix) {/{
        n
        /if (!prefix)$/{
            n
            /return -1;$/a\
        // For slash commands, strip leading "/" from prefix so it can match\
        // item values (which do not include the slash).\
        const normalizedPrefix = prefix.startsWith("/") \&\& !prefix.includes(" ")\
            ? prefix.slice(1)\
            : prefix;
        }
    }' "$EDITOR_JS"

    # 1b. Update exact-match comparison to also try normalizedPrefix
    sed -i 's/if (value === prefix) {/if (value === prefix || value === normalizedPrefix) {/' "$EDITOR_JS"

    # 1c. Update prefix-start check to also try normalizedPrefix
    sed -i 's/if (firstPrefixIndex === -1 && value.startsWith(prefix)) {/if (firstPrefixIndex === -1 \&\& (value.startsWith(prefix) || value.startsWith(normalizedPrefix))) {/' "$EDITOR_JS"

    # 1d. Fix updateAutocomplete — always use force: false for typing updates
    sed -i '/^    updateAutocomplete() {/,/^    }/{
        s/this.requestAutocomplete({ force: this.autocompleteState === "force", explicitTab: false });/this.requestAutocomplete({ force: false, explicitTab: false });/
    }' "$EDITOR_JS"

    # 1e. Add auto-accept for exact single-item matches
    #     Replace the Tab-only auto-accept block with the extended version
    AUTO_ACCEPT_OLD='if (options.force \&\& options.explicitTab \&\& suggestions.items.length === 1) {'
    AUTO_ACCEPT_NEW='const exactMatchIndex = this.getBestAutocompleteMatchIndex(suggestions.items, suggestions.prefix);\
        const isExactSingleMatch = suggestions.items.length === 1 \&\& exactMatchIndex === 0;\
        if ((options.force \&\& options.explicitTab \&\& suggestions.items.length === 1) || isExactSingleMatch) {'

    if grep -qF "options.force && options.explicitTab && suggestions.items.length === 1" "$EDITOR_JS"; then
        sed -i "s|if (options.force && options.explicitTab && suggestions.items.length === 1) {|$AUTO_ACCEPT_NEW|" "$EDITOR_JS"

        # Add the slash-command-aware cancellation after auto-accept
        CANCEL_OLD='this.cancelAutocomplete();'
        CANCEL_NEW='if (suggestions.prefix.startsWith("/") \&\& !suggestions.prefix.includes(" ")) {\
                this.autocompleteState = null;\
            } else {\
                this.cancelAutocomplete();\
            }'

        # Only replace the first occurrence after the auto-accept block
        sed -i "0,/$CANCEL_OLD/{
            /$CANCEL_OLD/{
                s|$CANCEL_OLD|$CANCEL_NEW|
                b
            }
        }" "$EDITOR_JS"
    fi

    # Verify
    if grep -q "normalizedPrefix" "$EDITOR_JS" && \
       grep -q "isExactSingleMatch" "$EDITOR_JS" && \
       grep -q "force: false, explicitTab: false" "$EDITOR_JS"; then
        log "  ✓ autocomplete patches applied successfully"
    else
        err "  ✗ autocomplete patches may have failed — check $EDITOR_JS manually"
    fi
else
    log "  (skipped — already patched)"
fi

# =============================================================================
# Patch 2: Context lag (agent-session.js + footer.js)
# =============================================================================

if [ "$SKIP_SESSION" -eq 0 ]; then
    log "Applying context-lag patch to agent-session.js..."

    # 2a. Remove the early return when contextWindow <= 0, and add it after
    #     the estimate calculation instead.
    #
    #     Original pattern:
    #       if (contextWindow <= 0)
    #           return undefined;
    #
    #     Replace with: (remove early return, move check after estimation)

    # Step 1: Remove the early return lines
    sed -i '/if (contextWindow <= 0)$/{
        N
        s/if (contextWindow <= 0)\n            return undefined;//
    }' "$SESSION_JS"

    # Step 2: After the estimate line, insert the fallback return
    ESTIMATE_LINE='const estimate = estimateContextTokens(this.messages);'
    FALLBACK_BLOCK='        // When contextWindow is unknown (0), still return the token estimate\
        // so the footer can show token count even without a percentage.\
        // This prevents the bar from showing 0% when the provider does not\
        // expose the context window size.\
        if (contextWindow <= 0) {\
            return {\
                tokens: estimate.tokens,\
                contextWindow: 0,\
                percent: null,\
            };\
        }'

    if grep -q "$ESTIMATE_LINE" "$SESSION_JS"; then
        sed -i "/$ESTIMATE_LINE/a\\
$FALLBACK_BLOCK" "$SESSION_JS"
    fi

    if grep -q "still return the token estimate" "$SESSION_JS"; then
        log "  ✓ agent-session.js patched successfully"
    else
        err "  ✗ agent-session.js patch may have failed"
    fi
fi

# 2b. Fix footer.js to handle contextWindow === 0 gracefully
log "Applying context-lag patch to footer.js..."

FOOTER_OLD='? `?\/\${formatTokens(contextWindow)}\${autoIndicator}`'
FOOTER_NEW='? contextWindow > 0\
                ? `?\/\${formatTokens(contextWindow)}\${autoIndicator}`\
                : `~\${formatTokens(contextUsage?.tokens ?? 0)} tokens\${autoIndicator}`'

if grep -q "contextWindow > 0" "$FOOTER_JS"; then
    log "  (footer.js already patched)"
else
    sed -i "s|? \`?/\${formatTokens(contextWindow)}\${autoIndicator}\`|$FOOTER_NEW|" "$FOOTER_JS"
    if grep -q "contextWindow > 0" "$FOOTER_JS"; then
        log "  ✓ footer.js patched successfully"
    else
        warn "  ⚠ footer.js patch may have failed — attempting alternate pattern..."
        # Alternate: use a simpler sed
        sed -i 's|? `?/${formatTokens(contextWindow)}${autoIndicator}`|? contextWindow > 0 ? `?/${formatTokens(contextWindow)}${autoIndicator}` : `~${formatTokens(contextUsage?.tokens ?? 0)} tokens${autoIndicator}`|' "$FOOTER_JS"
    fi
fi

# ── Final verification ──────────────────────────────────────────────────────

echo ""
log "All patches applied. Running syntax checks..."

node --check "$EDITOR_JS" 2>&1 && echo "  ✓ editor.js syntax OK" || err "editor.js has syntax errors!"
node --check "$SESSION_JS" 2>&1 && echo "  ✓ agent-session.js syntax OK" || err "agent-session.js has syntax errors!"
node --check "$FOOTER_JS" 2>&1 && echo "  ✓ footer.js syntax OK" || err "footer.js has syntax errors!"

echo ""
log "Done. Backups at: $BACKUP_DIR"
log "To revert: cp $BACKUP_DIR/*.bak back to their original locations"
