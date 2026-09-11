#!/bin/sh
# Builds the Release app (universal: arm64 + x86_64) and wraps it in a DMG under build/release/.
# Signing follows Config/Local.xcconfig (Apple Development); without it the app is ad-hoc signed.
# Developer ID + notarization (xcrun notarytool) is a follow-up once that certificate exists.
set -eu
cd "$(dirname "$0")/.."
OUT=build/release
rm -rf "$OUT"
mkdir -p "$OUT/dmg"
xcodebuild -project MiseManager.xcodeproj -scheme MiseManager -configuration Release \
  -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO -derivedDataPath "$OUT/DerivedData" build -quiet
APP="$OUT/DerivedData/Build/Products/Release/Mise Manager.app"
VERSION=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname "Mise Manager" -srcfolder "$OUT/dmg" -ov -format UDZO -quiet "$OUT/MiseManager-$VERSION.dmg"
lipo -info "$APP/Contents/MacOS/Mise Manager"
codesign -dv "$APP" 2>&1 | grep -E 'Authority|TeamIdentifier' | head -2 || true
echo "$OUT/MiseManager-$VERSION.dmg"
