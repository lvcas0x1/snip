#!/bin/zsh
# Package build/Snip.app into build/Snip-<version>.dmg with an Applications link,
# using `diskutil image` (macOS 14 or later).
# Usage: Scripts/make-dmg.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:?usage: make-dmg.sh <version>}
app=build/Snip.app
dmg="build/Snip-$version.dmg"
[[ -d "$app" ]] || { echo "missing $app: run Scripts/build-app.sh first"; exit 1; }

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
# diskutil image replaces hdiutil, which is deprecated as of macOS 27. A folder source becomes an
# APFS volume; ULFO is a compressed read-only image.
diskutil image create from --format ULFO --volumeName "Snip" "$staging" "$dmg" >/dev/null
echo "$dmg"
