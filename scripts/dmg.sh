#!/usr/bin/env bash
# Builds a release DrIsland.app and packs it into DrIsland-<version>.dmg with an Applications shortcut.
# Without CODESIGN_IDENTITY the app is ad-hoc signed, so the first launch on another Mac needs right-click → Open.
# Distribution: CODESIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=dr-island scripts/dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh release
VERSION="$(cat VERSION 2>/dev/null || echo 0.1.0)"
DMG="DrIsland-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R DrIsland.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Dr Island" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Built $DMG"

# With a Developer ID identity and a notarytool profile the disk image is signed, notarized and stapled, so other Macs
# open it without the Gatekeeper warning. One-off setup: xcrun notarytool store-credentials "dr-island" --apple-id … --team-id …
if [ -n "${CODESIGN_IDENTITY:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "Notarized $DMG"
fi
