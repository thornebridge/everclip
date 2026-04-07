#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="EverClip"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
VERSION=$(grep -A1 CFBundleShortVersionString "$PROJECT_DIR/Info.plist" | tail -1 | sed 's/[^0-9.]//g')

echo "⚙  Building $APP_NAME v$VERSION (release, arm64)…"
cd "$PROJECT_DIR"
swift build -c release --arch arm64 2>&1

# ─── Generate app icon ───────────────────
echo "🎨  Generating app icon…"
swift "$SCRIPT_DIR/generate-icon.swift"
iconutil -c icns AppIcon.iconset -o AppIcon.icns 2>/dev/null
rm -rf AppIcon.iconset

# ─── Package .app bundle ─────────────────
echo "📦  Packaging .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Info.plist"  "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -f AppIcon.icns

codesign --force --sign - "$APP_BUNDLE"

echo "✅  $APP_BUNDLE"

# ─── Create DMG installer ────────────────
echo "📀  Creating DMG installer…"
DMG_NAME="EverClip-v${VERSION}-arm64"
DMG_STAGING="$PROJECT_DIR/.dmg-staging"
rm -rf "$DMG_STAGING" "$PROJECT_DIR/$DMG_NAME.dmg"
mkdir -p "$DMG_STAGING"
cp -r "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "EverClip" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  -imagekey zlib-level=9 \
  "$PROJECT_DIR/$DMG_NAME.dmg" 2>/dev/null

rm -rf "$DMG_STAGING"

echo ""
echo "✅  $APP_BUNDLE"
echo "✅  $PROJECT_DIR/$DMG_NAME.dmg"
echo ""
echo "To run:     open $APP_BUNDLE"
echo "To install: open $PROJECT_DIR/$DMG_NAME.dmg"
