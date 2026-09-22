#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_NAME="FloatProgress"
APP_DISPLAY_NAME="牛马"
BUILD_CONFIG="${1:-release}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_DISPLAY_NAME.app"

cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swiftpm-cache"
swift build --disable-sandbox -c "$BUILD_CONFIG" --arch arm64

BIN_DIR="$(swift build --disable-sandbox -c "$BUILD_CONFIG" --arch arm64 --show-bin-path)"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>FloatProgress</string>
    <key>CFBundleIdentifier</key><string>com.local.FloatProgress</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>牛马</string>
    <key>CFBundleDisplayName</key><string>牛马</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.0.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
