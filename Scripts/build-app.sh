#!/bin/zsh
# Builds Snip with SwiftPM and assembles build/Snip.app (signed with a stable identity when available).
# Optional environment: APP_VERSION (CFBundleShortVersionString), BUILD_NUMBER (CFBundleVersion), SIGN_IDENTITY.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

CONFIG="${1:-release}"
swift build -c "$CONFIG" --product Snip
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Snip"

APP="build/Snip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Snip"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
[[ -n "${APP_VERSION:-}" ]] && plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP/Contents/Info.plist"
[[ -n "${BUILD_NUMBER:-}" ]] && plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
# A stable identity keeps the Screen Recording permission across rebuilds; ad-hoc signing changes it every build.
IDENTITY="${SIGN_IDENTITY:-Screenshot Dev}"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" --identifier dev.lvcas0x1.snip "$APP"
else
    echo "warning: identity '$IDENTITY' not found; using ad-hoc signing (permission resets on every build)"
    codesign --force --sign - --identifier dev.lvcas0x1.snip "$APP"
fi
echo "Built $APP"
