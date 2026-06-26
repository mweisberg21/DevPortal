#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DevPortal"
BUNDLE_ID="com.mswdigital.DevPortal"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${DEVPORTAL_VERSION:-0.1.0}"
SPARKLE_FEED_URL="${DEVPORTAL_SPARKLE_FEED_URL:-https://github.com/mweisberg21/DevPortal/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_KEY="LFQgb2IVf7iqRg10DAk4t3AltuvU5hTazf1RtLufcwA="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
ICON_SCRIPT="$ROOT_DIR/script/make_app_icon.swift"
ZIP_FILE="$DIST_DIR/$APP_NAME.app.zip"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    ;;
esac

cd "$ROOT_DIR"
if [[ ! -f "$ICON_FILE" || "$ICON_SCRIPT" -nt "$ICON_FILE" ]]; then
  swift script/make_app_icon.swift
fi

swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
SPARKLE_FRAMEWORK="$BUILD_DIR/Sparkle.framework"

if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found in $BUILD_DIR" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
/usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign - "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
/usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --package|package)
    echo "Packaged $APP_BUNDLE"
    ;;
  --zip|zip)
    rm -f "$ZIP_FILE"
    (cd "$DIST_DIR" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_FILE")
    echo "Packaged $ZIP_FILE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--package|--zip|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
