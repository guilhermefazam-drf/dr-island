#!/usr/bin/env bash
# Builds DrIsland.app (ad-hoc signed, menu-bar only). Usage: scripts/bundle.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
# The macOS 27 SDK shipped with the Command Line Tools lacks the SwiftUI macro plugin, so pin SDK 26.
SDK="${SDKROOT_OVERRIDE:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
[ -d "$SDK" ] || SDK="$(xcrun --show-sdk-path)"

swift build -c "$CONFIG" --sdk "$SDK" 2>&1 | grep -v "ld: warning" || true
BIN="$(swift build -c "$CONFIG" --sdk "$SDK" --show-bin-path 2>/dev/null)/DrIsland"
[ -x "$BIN" ] || { echo "build failed: $BIN not found" >&2; exit 1; }

APP="DrIsland.app"
VERSION="$(cat VERSION 2>/dev/null || echo 0.1.0)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# System-wide Now Playing helper (loaded by /usr/bin/perl, see helper/nowplaying.c); the player works without it, minus browsers.
clang -dynamiclib -framework CoreFoundation -o "$APP/Contents/Resources/libnowplaying.dylib" helper/nowplaying.c 2>/dev/null \
  && cp helper/nowplaying.pl "$APP/Contents/Resources/nowplaying.pl" || echo "warning: Now Playing helper not built" >&2
cp "$BIN" "$APP/Contents/MacOS/DrIsland"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>pt.doutorfinancas.dr-island</string>
  <key>CFBundleName</key><string>Dr Island</string>
  <key>CFBundleDisplayName</key><string>Dr Island</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key><string>Doutor Finanças</string>
  <key>CFBundleExecutable</key><string>DrIsland</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>O Dr Island lê e controla o que estás a ouvir no Spotify ou na Música.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
# CODESIGN_IDENTITY="Developer ID Application: Nome (TEAMID)" signs for distribution (hardened runtime, with the
# entitlements); without it the app is ad-hoc signed, which is enough to run it on the Mac that built it.
IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed" >&2
else
  for lib in "$APP"/Contents/Resources/*.dylib; do
    [ -e "$lib" ] && codesign --force --timestamp --sign "$IDENTITY" "$lib"
  done
  codesign --force --options runtime --timestamp --entitlements scripts/DrIsland.entitlements --sign "$IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP" && echo "Signed with: $IDENTITY"
fi
echo "Built $APP"
