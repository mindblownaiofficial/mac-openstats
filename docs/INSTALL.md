# Installing OpenStats

OpenStats runs on macOS 13 Ventura or later, on Apple silicon and Intel Macs.

## Option 1: Installer package (.pkg)

1. Download `OpenStats-<version>.pkg` from the
   [latest release](https://github.com/woodsjohn16/mac-openstats/releases/latest).
2. Double-click it and follow the steps. It installs `OpenStats.app` into
   `/Applications` and opens it when finished.
3. Look at the right side of your menu bar for the new CPU, memory, network, disk
   and battery items.

## Option 2: Disk image (.dmg)

1. Download `OpenStats-<version>.dmg` and open it.
2. Drag **OpenStats** onto the **Applications** shortcut in the window.
3. Open OpenStats from your Applications folder.

## "OpenStats can't be opened" / unidentified developer

OpenStats is a free community project and is not notarized with a paid Apple
Developer account, so the first launch may be blocked by Gatekeeper. Any of these
unblocks it, once:

- **Right-click** (or Control-click) `OpenStats.app` and choose **Open**, then
  confirm **Open** in the dialog.
- Or open **System Settings → Privacy & Security**, scroll down and click
  **Open Anyway** next to the OpenStats message.
- Or, in Terminal:

  ```bash
  xattr -d com.apple.quarantine /Applications/OpenStats.app
  ```

The `.pkg` installer may show a similar warning. Right-click it and choose Open.

## Launch at login

Open Settings (right-click any OpenStats menu bar item) and turn on
**Launch at login**. macOS may ask you to allow it under
System Settings → General → Login Items.

## Uninstalling

1. Quit OpenStats (right-click a menu bar item → Quit).
2. Move `/Applications/OpenStats.app` to the Trash.
3. Optionally remove its settings:

   ```bash
   defaults delete org.openstats.app
   ```

## Building from source

You need the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is
not required.

```bash
git clone https://github.com/woodsjohn16/mac-openstats.git
cd mac-openstats
./Scripts/build-app.sh      # → build/OpenStats.app
./Scripts/build-dmg.sh      # → build/OpenStats-<version>.dmg
./Scripts/build-pkg.sh      # → build/OpenStats-<version>.pkg
./Scripts/release.sh        # all of the above plus SHA256SUMS.txt
```

To sign with your own Developer ID certificates, set these before building:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export INSTALLER_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
./Scripts/release.sh
```

Then notarize with `xcrun notarytool submit build/OpenStats-<version>.dmg --wait`
(requires an Apple Developer account).
