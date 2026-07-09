#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SWIFT_BUILD_FLAGS=(--disable-sandbox)

echo "Building DockSwitch..."
xcrun swift build "${SWIFT_BUILD_FLAGS[@]}"

BIN_PATH="$ROOT_DIR/.build/arm64-apple-macosx/debug/DockSwitch"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected executable not found at: $BIN_PATH" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/.build/DockSwitch.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/DockSwitch.iconset"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/DockSwitch"
chmod +x "$MACOS_DIR/DockSwitch"

build_icns_from_png() {
  local src_png="$1"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16 "$src_png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$src_png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$src_png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$src_png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$src_png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$src_png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$src_png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$src_png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$src_png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$src_png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/DockSwitch.icns"
}

ICON_SET=false
if [[ -f "$ROOT_DIR/Design/DockSwitch.icns" ]]; then
  cp "$ROOT_DIR/Design/DockSwitch.icns" "$RESOURCES_DIR/DockSwitch.icns"
  ICON_SET=true
elif [[ -f "$ROOT_DIR/Design/DockSwitch-icon-concept.icns" ]]; then
  cp "$ROOT_DIR/Design/DockSwitch-icon-concept.icns" "$RESOURCES_DIR/DockSwitch.icns"
  ICON_SET=true
elif [[ -f "$ROOT_DIR/Design/DockSwitch-icon-concept.icon/Assets/dock_demo.png" ]]; then
  build_icns_from_png "$ROOT_DIR/Design/DockSwitch-icon-concept.icon/Assets/dock_demo.png"
  ICON_SET=true
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>DockSwitch</string>
  <key>CFBundleIconFile</key>
  <string>DockSwitch</string>
  <key>CFBundleIdentifier</key>
  <string>com.dockswitch.menuapp</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>DockSwitch</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1.0.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSLocationUsageDescription</key>
  <string>DockSwitch uses your location to auto-select your home/work device profile.</string>
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>DockSwitch uses your location to auto-select your home/work device profile.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>DockSwitch uses your location to auto-select your home/work device profile.</string>
</dict>
</plist>
PLIST

if [[ "$ICON_SET" != true ]]; then
  echo "Warning: no app icon source found in Design/. Using default app icon."
fi

echo "Launching DockSwitch.app from $APP_DIR"
open "$APP_DIR"
