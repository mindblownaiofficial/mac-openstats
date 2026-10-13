#!/bin/bash
# Packages build/OpenStats.app into a standard macOS installer:
#   build/OpenStats-<version>.pkg
# The installer places OpenStats.app in /Applications and launches it when done.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d build/OpenStats.app ] || ./Scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/OpenStats.app/Contents/Info.plist)"
IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/OpenStats.app/Contents/Info.plist)"
PKG="build/OpenStats-$VERSION.pkg"
WORK="build/pkg-work"

echo "▸ Preparing payload and scripts"
rm -rf "$WORK" "$PKG"
mkdir -p "$WORK/root/Applications" "$WORK/scripts"
cp -R build/OpenStats.app "$WORK/root/Applications/"
xattr -cr "$WORK/root"   # drop Finder/provenance attributes so no ._ files end up in the payload

# Quit a running copy before the files are replaced, and open the new one afterwards
# as the logged-in user (the installer itself runs as root).
cat > "$WORK/scripts/preinstall" <<'SH'
#!/bin/bash
pkill -x OpenStats 2>/dev/null || true
exit 0
SH
cat > "$WORK/scripts/postinstall" <<'SH'
#!/bin/bash
USER_NAME="$(stat -f %Su /dev/console)"
if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ]; then
    sudo -u "$USER_NAME" open /Applications/OpenStats.app || true
fi
exit 0
SH
chmod +x "$WORK/scripts/preinstall" "$WORK/scripts/postinstall"

echo "▸ Building component package"
pkgbuild --root "$WORK/root" \
         --identifier "$IDENTIFIER" \
         --version "$VERSION" \
         --install-location / \
         --scripts "$WORK/scripts" \
         "$WORK/OpenStats-component.pkg" >/dev/null

cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>OpenStats $VERSION</title>
    <welcome file="welcome.html"/>
    <license file="license.txt"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <allowed-os-versions><os-version min="13.0"/></allowed-os-versions>
    <choices-outline><line choice="default"><line choice="app"/></line></choices-outline>
    <choice id="default"/>
    <choice id="app" visible="false"><pkg-ref id="$IDENTIFIER"/></choice>
    <pkg-ref id="$IDENTIFIER" version="$VERSION" onConclusion="none">OpenStats-component.pkg</pkg-ref>
</installer-gui-script>
XML
mkdir -p "$WORK/resources"
cp LICENSE "$WORK/resources/license.txt"
cat > "$WORK/resources/welcome.html" <<HTML
<!DOCTYPE html><html><body style="font-family: -apple-system, sans-serif; font-size: 13px;">
<p>OpenStats is a free, open-source system monitor for your menu bar. It shows live CPU,
memory, network, disk and battery stats with graphs, one click away.</p>
<p>This installer places <b>OpenStats.app</b> in your Applications folder and opens it.
Look for the new items at the right of your menu bar. Right-click any of them for Settings.</p>
<p>Source code and updates: https://github.com/woodsjohn16/mac-openstats</p>
</body></html>
HTML

echo "▸ Building installer"
PRODUCT_SIGN=()
if [ -n "${INSTALLER_IDENTITY:-}" ]; then PRODUCT_SIGN=(--sign "$INSTALLER_IDENTITY"); fi
productbuild --distribution "$WORK/distribution.xml" \
             --resources "$WORK/resources" \
             --package-path "$WORK" \
             ${PRODUCT_SIGN[@]+"${PRODUCT_SIGN[@]}"} \
             "$PKG" >/dev/null
rm -rf "$WORK"
echo "✓ Built $PKG"
