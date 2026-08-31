#!/bin/sh
# Build the macOS app icon into the directory given as $1 (e.g. <build>/macosx).
# Prefers the Liquid Glass pipeline: compile the Icon Composer document
# (GhostshipIcon.icon) with actool into Assets.car, then extract a full
# 16-1024px .icns from the car with iconutil. Falls back to the classic
# sips iconset built from logo.png when actool is unavailable or can't
# compile the document (older Xcode).
set -e
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SRC_DIR")"
OUT="$1"
mkdir -p "$OUT"

if xcrun --find actool >/dev/null 2>&1; then
    if xcrun actool "$SRC_DIR/GhostshipIcon.icon" --compile "$OUT" \
        --app-icon GhostshipIcon \
        --output-partial-info-plist "$OUT/GhostshipIcon-partial.plist" \
        --platform macosx --target-device mac \
        --minimum-deployment-target 10.15 \
        --errors --warnings >/dev/null 2>&1 && [ -f "$OUT/Assets.car" ]; then
        iconutil -c icns "$OUT/Assets.car" GhostshipIcon -o "$OUT/Ghostship.icns"
        echo "Liquid Glass icon: Assets.car + Ghostship.icns"
        exit 0
    fi
    echo "actool could not compile GhostshipIcon.icon; falling back to sips iconset" >&2
fi

ICONSET="$OUT/ghostship.iconset"
mkdir -p "$ICONSET"
cd "$REPO_DIR"
sips -z 16 16     logo.png --out "$ICONSET/icon_16x16.png"
sips -z 32 32     logo.png --out "$ICONSET/icon_16x16@2x.png"
sips -z 32 32     logo.png --out "$ICONSET/icon_32x32.png"
sips -z 64 64     logo.png --out "$ICONSET/icon_32x32@2x.png"
sips -z 128 128   logo.png --out "$ICONSET/icon_128x128.png"
sips -z 256 256   logo.png --out "$ICONSET/icon_128x128@2x.png"
sips -z 256 256   logo.png --out "$ICONSET/icon_256x256.png"
sips -z 512 512   logo.png --out "$ICONSET/icon_256x256@2x.png"
sips -z 512 512   logo.png --out "$ICONSET/icon_512x512.png"
cp                logo.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns -o "$OUT/Ghostship.icns" "$ICONSET"
echo "sips fallback icon: Ghostship.icns"
