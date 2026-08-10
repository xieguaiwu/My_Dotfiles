#!/bin/bash
# Fix: VLC HEVC 10bit 播放雪花/画面错乱（文件能播放但花屏/卡顿）
# Root cause: 现代 iHD 驱动移除 Kaby Lake(Gen9.5) 的 HEVC VAAPI profile ->
#   VLC --avcodec-hw any 硬解失败静默回退软解 -> 弱 CPU 软解 1080p10 HEVC 不足
#   (实测 18fps=0.73x) -> 掉帧 + HEVC 帧线程引用错乱 -> 雪花/错乱
# Fix: 强制 legacy i965 驱动 + VLC vaapi 硬解 + 环境注入
# Run:  bash video-playback-vaapi-fix.sh          # 全流程（配置注入 + 可选重启）
#       bash video-playback-vaapi-fix.sh --check  # 仅诊断输出
# Doc:  video-playback-decode-fix.md (同目录, 症状 B 分支)
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
VLC_CFG="$CFG_DIR/vlc/vlcrc"
DESKTOP_DST="$HOME/.local/share/applications/vlc.desktop"
ENVD_DST="$HOME/.config/environment.d/50-vaapi-i965.conf"
RENDER_DEV="/dev/dri/renderD128"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

echo "==> [1/6] VAAPI 能力检查"
echo "  默认驱动 (iHD):"
if vainfo 2>/dev/null | grep -q "VAProfileHEVC"; then
  echo "    ✅ iHD 有 HEVC profile，无需 i965 干预"
else
  echo "    ⚠️  iHD 无 HEVC profile（KBL 等 Gen9 平台常见，属预期）"
fi
echo "  i965 驱动 (legacy):"
if LIBVA_DRIVER_NAME=i965 vainfo 2>/dev/null | grep -q "VAProfileHEVCMain10"; then
  echo "    ✅ i965 支持 HEVCMain10 VLD"
else
  echo "    ❌ i965 无 HEVC Main10 —— 先装 libva-intel-driver（RPM Fusion）"
  echo "       sudo dnf install -y libva-intel-driver"
  exit 1
fi

if [ "$CHECK_ONLY" = "1" ]; then
  echo ""
  echo "==> 诊断模式：以下为当前配置状态（不做修改）"
  grep -q "^avcodec-hw=vaapi" "$VLC_CFG" 2>/dev/null && echo "  vlcrc avcodec-hw=vaapi       : ✅ 已设置" || echo "  vlcrc avcodec-hw=vaapi       : ❌ 未设置"
  grep -q "LIBVA_DRIVER_NAME=i965" "$DESKTOP_DST" 2>/dev/null && echo "  vlc.desktop env 注入          : ✅ 已设置" || echo "  vlc.desktop env 注入          : ❌ 未设置"
  grep -q "LIBVA_DRIVER_NAME=i965" "$ENVD_DST" 2>/dev/null && echo "  environment.d i965           : ✅ 已设置" || echo "  environment.d i965           : ❌ 未设置"
  echo "  (配置已就绪时仅需重启 VLC；environment.d 需重新登录全会话生效)"
  exit 0
fi

echo "==> [2/6] vlcrc 启用 VAAPI 硬解"
if [ -f "$VLC_CFG" ] && grep -q "^avcodec-hw=vaapi" "$VLC_CFG"; then
  echo "    (已设置, 跳过)"
else
  [ -f "$VLC_CFG" ] && cp "$VLC_CFG" "$VLC_CFG.bak-$(date +%Y%m%d%H%M%S)"
  if grep -q "^#avcodec-hw=" "$VLC_CFG" 2>/dev/null; then
    sed -i 's/^#avcodec-hw=.*/avcodec-hw=vaapi/' "$VLC_CFG"
  else
    mkdir -p "$CFG_DIR/vlc"
    printf '\navcodec-hw=vaapi\n' >> "$VLC_CFG"
  fi
  echo "    ✅ 已设置 avcodec-hw=vaapi"
fi

echo "==> [3/6] 桌面启动器注入 LIBVA_DRIVER_NAME=i965"
if [ -f "$DESKTOP_DST" ] && grep -q "LIBVA_DRIVER_NAME=i965" "$DESKTOP_DST"; then
  echo "    (已设置, 跳过)"
else
  mkdir -p "$HOME/.local/share/applications"
  if [ ! -f "$DESKTOP_DST" ]; then
    cp /usr/share/applications/vlc.desktop "$DESKTOP_DST"
  fi
  sed -i 's|^Exec=/usr/bin/vlc |Exec=env LIBVA_DRIVER_NAME=i965 /usr/bin/vlc |' "$DESKTOP_DST"
  echo "    ✅ 已注入 env LIBVA_DRIVER_NAME=i965"
fi

echo "==> [4/6] 全会话环境注入（下次登录生效）"
if [ -f "$ENVD_DST" ] && grep -q "LIBVA_DRIVER_NAME=i965" "$ENVD_DST"; then
  echo "    (已设置, 跳过)"
else
  mkdir -p "$HOME/.config/environment.d"
  cat > "$ENVD_DST" <<'EOF'
# Kaby Lake (HD 620): iHD driver lacks HEVC decode (removed for Gen9).
# Legacy i965 driver provides HEVC Main8/Main10 VLD. Force for all VAAPI apps.
LIBVA_DRIVER_NAME=i965
EOF
  echo "    ✅ 已写入 $ENVD_DST"
fi

echo "==> [5/6] ffmpeg VAAPI 硬解实测（30 秒基准）"
if [ -c "$RENDER_DEV" ]; then
  SPEED=$(LIBVA_DRIVER_NAME=i965 ffmpeg -hwaccel vaapi -hwaccel_device "$RENDER_DEV" \
    -v error -i "${2:-}" -t 30 -f null -benchmark - 2>&1 | grep -oE "speed=[0-9.]+x" | tail -1)
  [ -n "$SPEED" ] && echo "    ✅ 硬解基准: $SPEED (软解通常 <1x, 硬解 >3x)" || echo "    ⚠️ 基准无输出（未提供文件参数则忽略）"
fi

echo "==> [6/6] VLC 重启（MPRIS 保存位置）"
VLC_PID=$(pgrep -f "vlc --started-from-file" | head -1 || true)
if [ -z "$VLC_PID" ]; then
  echo "    无运行中 VLC，跳过（配置已就绪，下次启动即硬解）"
else
  if command -v dbus-send >/dev/null && [ -S /run/user/$(id -u)/bus ]; then
    POS=$(dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc \
      /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
      string:org.mpris.MediaPlayer2.Player string:Position 2>/dev/null | grep -oE "int64 [0-9]+" | awk '{print $2}')
    STATUS=$(dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc \
      /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
      string:org.mpris.MediaPlayer2.Player string:PlaybackStatus 2>/dev/null | grep -oE '"[A-Za-z]+"' | tr -d '"')
    dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.vlc \
      /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Quit >/dev/null 2>&1 || true
    sleep 2
    kill -9 "$VLC_PID" 2>/dev/null || true
  else
    POS=""; STATUS=""
    kill -9 "$VLC_PID" 2>/dev/null || true
  fi
  FILE=$(readlink -f /proc/$VLC_PID/fd/* 2>/dev/null | grep -E "\.(mkv|mp4|avi|ts|m2ts)$" | head -1 || true)
  [ -n "$FILE" ] || FILE="${2:-}"
  if [ -n "$FILE" ] && [ -f "$FILE" ]; then
    START_ARGS=""
    if [ -n "$POS" ] && [ "$POS" -gt 0 ] 2>/dev/null; then
      START_ARGS="--start-time=$((POS/1000000))"
      echo "    恢复位置: $((POS/1000000))s (状态: ${STATUS:-unknown})"
    fi
    systemd-run --user --unit=vlc-restart-$(date +%s%N) \
      --setenv=HOME=$HOME --setenv=PATH=/usr/bin:/bin \
      --setenv=DISPLAY=:0 --setenv=WAYLAND_DISPLAY=wayland-1 \
      --setenv=XDG_RUNTIME_DIR=/run/user/$(id -u) \
      --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
      --setenv=LIBVA_DRIVER_NAME=i965 \
      /usr/bin/vlc --started-from-file $START_ARGS "$FILE"
    echo "    ✅ VLC 已重启（硬解模式）"
  else
    echo "    ⚠️ 未能定位播放文件，请手动启动 VLC"
  fi
fi

echo ""
echo "==> 验证:"
echo "    ps -C vlc -o pid,%cpu --no-headers          # 硬解 <20%, 软解 150%+"
echo "    journalctl --user -u vlc-restart-* --no-pager | grep 'hardware decoding'"
echo "    LIBVA_DRIVER_NAME=i965 vainfo | grep HEVCMain10"
