#!/bin/bash
# fix-ghostwriter-math.sh — idempotent self-healing for ghostwriter math rendering
#
# Ghostwriter 26.04 (flatpak) live-preview math depends on THREE fragile pieces:
#   1. ~/.local/bin/pandoc wrapper  (merges "+smart" into "-f markdown+smart"
#      because pandoc 3.x rejects a standalone "+smart" as a format extension)
#   2. flatpak overrides             (--filesystem=~/.local/bin + PATH prefix)
#   3. config lastUsedExporter=Pandoc (only cmark-gfm/Pandoc support math;
#      cmark-gfm has supportsMath()=false, so no MathJax is triggered)
# Any Flatpak update, config rewrite, or fresh install can silently break one
# of them. This script detects and repairs all three. Safe to run any time:
# the config is only touched while ghostwriter is NOT running (the app
# overwrites the file on exit, which would clobber our fix).
#
# Install: copy to ~/.local/bin/ and enable the systemd timer:
#   systemctl --user enable --now ghostwriter-math-fix.timer
# Remove (revert to default behavior):
#   systemctl --user disable --now ghostwriter-math-fix.timer
#   rm ~/.local/bin/fix-ghostwriter-math.sh
#   rm ~/.local/bin/pandoc && flatpak override --user --reset org.kde.ghostwriter
#   # then set lastUsedExporter=cmark-gfm in ghostwriter.conf if desired

set -u

APP="org.kde.ghostwriter"
WRAPPER_SRC="$HOME/My_Dotfiles/ghostwriter/bin/pandoc"
WRAPPER_DST="$HOME/.local/bin/pandoc"
CONF="$HOME/.var/app/org.kde.ghostwriter/config/kde.org/ghostwriter.conf"
LOG="$HOME/.cache/ghostwriter-math-fix.log"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

changed=0

# --- 1. pandoc wrapper -----------------------------------------------------
if [ -f "$WRAPPER_SRC" ]; then
    if [ ! -f "$WRAPPER_DST" ] || ! cmp -s "$WRAPPER_SRC" "$WRAPPER_DST"; then
        if cp "$WRAPPER_SRC" "$WRAPPER_DST" && chmod +x "$WRAPPER_DST"; then
            log "restored pandoc wrapper -> $WRAPPER_DST"
            changed=1
        else
            log "ERROR: could not restore pandoc wrapper"
        fi
    fi
else
    log "WARN: wrapper source missing at $WRAPPER_SRC (dotfiles not present)"
fi

# --- 2. flatpak overrides ---------------------------------------------------
if command -v flatpak >/dev/null 2>&1; then
    current="$(flatpak override --user --show "$APP" 2>/dev/null || true)"
    if ! printf '%s' "$current" | grep -q "~/.local/bin"; then
        if flatpak override --user --filesystem=~/.local/bin "$APP" 2>/dev/null; then
            log "restored flatpak --filesystem=~/.local/bin"
            changed=1
        fi
    fi
    if ! printf '%s' "$current" | grep -q "PATH=/home/xieguiawu/.local/bin"; then
        if flatpak override --user --env=PATH=/home/xieguiawu/.local/bin:/app/bin:/usr/bin:/bin "$APP" 2>/dev/null; then
            log "restored flatpak PATH override"
            changed=1
        fi
    fi
else
    log "WARN: flatpak not found"
fi

# --- 3. config lastUsedExporter (only while app is NOT running) -------------
ghostwriter_running() {
    pgrep -x ghostwriter >/dev/null 2>&1 && return 0
    pgrep -f "bwrap.*${APP}" >/dev/null 2>&1 && return 0
    return 1
}

if [ -f "$CONF" ] && grep -q '^lastUsedExporter=' "$CONF"; then
    if ghostwriter_running; then
        log "skip config fix: ghostwriter is running"
    elif ! grep -q '^lastUsedExporter=Pandoc$' "$CONF"; then
        if sed -i 's/^lastUsedExporter=.*/lastUsedExporter=Pandoc/' "$CONF"; then
            log "fixed lastUsedExporter -> Pandoc"
            changed=1
        fi
    fi
fi

[ "$changed" -eq 1 ] && log "heal applied (changed=1)" || log "all healthy (no change)"
exit 0
