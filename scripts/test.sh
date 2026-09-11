#!/bin/sh
# Runs MiseCore package tests, then the app test bundle.
set -eu
cd "$(dirname "$0")/.."
swift test --package-path Packages/MiseCore
xcodebuild test -project MiseManager.xcodeproj -scheme MiseManager -destination 'platform=macOS,arch=arm64' -quiet
