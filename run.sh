#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO/.build/debug"
APP="$REPO/MacClip.app"
BINARY="$BUILD_DIR/MacClip"
MACOS_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"

# Build
echo "--> Building..."
cd "$REPO"
swift build 2>&1

# Assemble .app bundle
echo "--> Assembling app bundle..."
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/MacClip"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacClip</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipboardmanager.app</string>
    <key>CFBundleName</key>
    <string>MacClip</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MacClip needs Accessibility access to paste selected entries automatically.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacClip uses System Events to paste when Accessibility is unavailable.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Sign with the persistent self-signed cert so TCC (Accessibility/Automation)
# recognises the app by a stable identity across rebuilds.
echo "--> Signing..."
CERT="ClipboardManager Dev"
if ! security find-certificate -c "$CERT" ~/Library/Keychains/login.keychain-db &>/dev/null; then
    echo "  No persistent cert found, falling back to ad-hoc (run setup_cert.sh once to fix TCC persistence)"
    CERT="-"
fi
codesign --sign "$CERT" --force \
  --entitlements "$REPO/MacClip/MacClip.entitlements" \
  "$APP"

echo "--> Launching..."
open "$APP"

echo ""
echo "MacClip is running in the menu bar."
echo "Press Cmd+Ctrl+V from any app to open the clipboard history popup."
