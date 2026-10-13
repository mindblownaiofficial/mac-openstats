#!/bin/bash
# Packages build/OpenStats.app into a drag-to-Applications disk image:
#   build/OpenStats-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d build/OpenStats.app ] || ./Scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/OpenStats.app/Contents/Info.plist)"
DMG="build/OpenStats-$VERSION.dmg"
STAGING="build/dmg-staging"

echo "▸ Staging disk image contents"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/OpenStats.app "$STAGING/"
xattr -cr "$STAGING"
ln -s /Applications "$STAGING/Applications"
cp docs/INSTALL.md "$STAGING/Read Me First.md"

echo "▸ Creating $DMG"
hdiutil create -volname "OpenStats $VERSION" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGING"
echo "✓ Built $DMG"
