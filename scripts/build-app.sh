#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_NAME="FloatProgress"
APP_DISPLAY_NAME="牛马"
BUILD_CONFIG="${1:-release}"
APP_VERSION="${APP_VERSION:-2.1.0}"
APP_BUILD="${APP_BUILD:-3}"
BUNDLE_ID="${BUNDLE_ID:-com.local.FloatProgress}"
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_DISPLAY_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_DISPLAY_NAME-macOS-Universal.zip"

cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swiftpm-cache"
swift build --disable-sandbox -c "$BUILD_CONFIG" --arch arm64
swift build --disable-sandbox -c "$BUILD_CONFIG" --arch x86_64

ARM_BIN_DIR="$(swift build --disable-sandbox -c "$BUILD_CONFIG" --arch arm64 --show-bin-path)"
INTEL_BIN_DIR="$(swift build --disable-sandbox -c "$BUILD_CONFIG" --arch x86_64 --show-bin-path)"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create \
    "$ARM_BIN_DIR/$APP_NAME" \
    "$INTEL_BIN_DIR/$APP_NAME" \
    -output "$APP_DIR/Contents/MacOS/$APP_NAME"

# Release 产物无需携带本地符号；不会改变运行逻辑或增加运行内存。
if [[ "$BUILD_CONFIG" == "release" ]]; then
    strip -x "$APP_DIR/Contents/MacOS/$APP_NAME"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>FloatProgress</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>牛马</string>
    <key>CFBundleDisplayName</key><string>牛马</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
    <key>CFBundleVersion</key><string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_DIR"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        echo "NOTARY_PROFILE 需要同时提供 CODESIGN_IDENTITY（Developer ID Application）。" >&2
        exit 2
    fi
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
fi

echo "$APP_DIR"
echo "$ZIP_PATH"
