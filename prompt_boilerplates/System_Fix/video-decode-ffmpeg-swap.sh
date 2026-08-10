#!/bin/bash
# Fix: Fedora VLC/播放器 cannot decode HEVC (H.265) / H.264
# Root cause: ffmpeg-free (Fedora official build) disables h264/hevc/vc1/vvc decoders
# Fix: enable RPM Fusion, swap ffmpeg-free -> full ffmpeg, refresh vlc
# Run with: sudo bash video-decode-ffmpeg-swap.sh
# Doc: video-playback-decode-fix.md (同目录)
set -euo pipefail

RELEASE="$(rpm -E %fedora 2>/dev/null || echo 42)"

echo "==> [1/3] Enabling RPM Fusion repos (free + nonfree)..."
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm"
else
  echo "    (already enabled, skipping)"
fi

echo "==> [2/3] Swapping ffmpeg-free -> full ffmpeg (enables HEVC/H.264 decode)..."
if rpm -q ffmpeg-free >/dev/null 2>&1; then
  dnf swap ffmpeg-free ffmpeg --allowerasing -y
else
  echo "    (ffmpeg-free not installed; ensuring full ffmpeg present)"
  dnf install -y ffmpeg
fi

echo "==> [3/3] Refreshing vlc + plugins to match..."
dnf install vlc --refresh -y

echo ""
echo "==> Verify:"
echo "    rpm -qa | grep -iE '^ffmpeg|libavcodec'          # expect NO -free suffix"
echo "    ffmpeg -version | grep -o 'disable-decoder[^ ]*' # expect empty/not containing h264,hevc"
echo "    ffmpeg -v error -i <FILE> -f null - -t 60 && echo DECODE_OK"
echo "    vlc <FILE>"
