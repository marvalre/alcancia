#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Alcancía"
BIN_NAME="Alcancia"
BUILD_CONFIG="release"

echo "Compilando en modo $BUILD_CONFIG..."
swift build -c "$BUILD_CONFIG"

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --show-bin-path)
APP_BUNDLE="./${APP_NAME}.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.mvisuals.alcancia</string>
    <key>CFBundleExecutable</key>
    <string>${BIN_NAME}</string>
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
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Firmando ad-hoc para que Gatekeeper lo deje correr localmente..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Listo: $APP_BUNDLE"
echo "Abrilo con: open \"$APP_BUNDLE\""
echo "O movelo a /Applications para tenerlo siempre disponible."
