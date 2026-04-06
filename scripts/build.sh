#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="EverClip"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "⚙  Building $APP_NAME (release, arm64)…"
cd "$PROJECT_DIR"
swift build -c release --arch arm64 2>&1

echo "📦  Packaging .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Info.plist"  "$APP_BUNDLE/Contents/Info.plist"

codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "✅  $APP_BUNDLE"
echo ""
echo "To run:     open $APP_BUNDLE"
echo "To install: cp -r $APP_BUNDLE /Applications/"
