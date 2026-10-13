#!/bin/bash
# One-shot release build: app bundle, disk image and installer package, with checksums.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build
./Scripts/build-app.sh
./Scripts/build-dmg.sh
./Scripts/build-pkg.sh
(cd build && shasum -a 256 OpenStats-*.dmg OpenStats-*.pkg > SHA256SUMS.txt && cat SHA256SUMS.txt)
echo "✓ Release artifacts are in ./build"
