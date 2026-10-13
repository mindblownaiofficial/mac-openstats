#!/bin/bash
# Builds OpenStats.app into ./build. Requires only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
echo "▸ Building OpenStats $VERSION (release)"
swift build -c release 2>&1 | tail -1
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/OpenStats.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OpenStats" "$APP/Contents/MacOS/OpenStats"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f Resources/AppIcon.icns ]; then
    echo "▸ Rendering app icon"
    ICONSET="build/AppIcon.iconset"
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        swift Scripts/make-icon.swift "$ICONSET/icon_${size}x${size}.png" "$size"
        swift Scripts/make-icon.swift "$ICONSET/icon_${size}x${size}@2x.png" "$((size * 2))"
    done
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
    rm -rf "$ICONSET"
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a Developer ID when CODESIGN_IDENTITY is set, otherwise ad hoc so it runs locally.
IDENTITY="${CODESIGN_IDENTITY:--}"
echo "▸ Signing with identity: $IDENTITY"
codesign --force --options runtime --sign "$IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true

echo "✓ Built $APP"
