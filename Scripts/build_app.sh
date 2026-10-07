#!/bin/bash
# Builds LifeNotch into a normal double-clickable app: build/LifeNotch.app
#
# Needs: a Mac with Xcode (or the free "Command Line Tools") installed.
# What it does, in plain words:
#   1. swift build   -> compiles the Swift code
#   2. makes a folder called LifeNotch.app (an app is really just a folder)
#   3. copies the program + Info.plist into it
#   4. gives it a local "ad-hoc" signature so macOS will run it
# It only ever creates/replaces build/LifeNotch.app inside this project folder.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/LifeNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/LifeNotch" "$APP/Contents/MacOS/LifeNotch"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo ""
echo "Built: $APP"
echo "Open it with:  open $APP"
echo "(First launch: if macOS complains, right-click the app > Open.)"
