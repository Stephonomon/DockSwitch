#!/usr/bin/env bash
set -euo pipefail

# Builds a distributable DockSwitch.app and zip in dist/.
# Usage: ./scripts/package-release.sh [version]   (default: 1.0.0)

VERSION="${1:-1.0.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building DockSwitch $VERSION (release)..."

# Prefer a universal binary so both Apple Silicon and Intel Macs are covered;
# fall back to a native-only build if the toolchain can't do both slices.
if xcrun swift build -c release --disable-sandbox --arch arm64 --arch x86_64 >/dev/null 2>&1; then
  BIN_PATH="$ROOT_DIR/.build/apple/Products/Release/DockSwitch"
  echo "Built universal binary (arm64 + x86_64)."
else
  echo "Universal build unavailable; building for this Mac's architecture only."
  xcrun swift build -c release --disable-sandbox
  BIN_PATH="$ROOT_DIR/.build/release/DockSwitch"
fi

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected executable not found at: $BIN_PATH" >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/DockSwitch.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$DIST_DIR/DockSwitch.iconset"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/DockSwitch"
chmod +x "$MACOS_DIR/DockSwitch"

build_icns_from_png() {
  local src_png="$1"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16     "$src_png" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
  sips -z 32 32     "$src_png" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
  sips -z 32 32     "$src_png" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
  sips -z 64 64     "$src_png" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
  sips -z 128 128   "$src_png" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
  sips -z 256 256   "$src_png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$src_png" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
  sips -z 512 512   "$src_png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$src_png" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
  sips -z 1024 1024 "$src_png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/DockSwitch.icns"
  rm -rf "$ICONSET_DIR"
}

if [[ -f "$ROOT_DIR/Design/DockSwitch.icns" ]]; then
  cp "$ROOT_DIR/Design/DockSwitch.icns" "$RESOURCES_DIR/DockSwitch.icns"
elif [[ -f "$ROOT_DIR/Design/DockSwitch-icon-concept.icon/Assets/dock_demo.png" ]]; then
  build_icns_from_png "$ROOT_DIR/Design/DockSwitch-icon-concept.icon/Assets/dock_demo.png"
else
  echo "Warning: no app icon source found in Design/. Shipping without an icon." >&2
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
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
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
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

# Ad-hoc signature: required for the binary to run at all on Apple Silicon.
# (This is not notarization; see the README for the first-launch steps.)
codesign --force --sign - "$APP_DIR"

ZIP_PATH="$DIST_DIR/DockSwitch-$VERSION.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo ""
echo "Done:"
echo "  App: $APP_DIR"
echo "  Zip: $ZIP_PATH"
echo ""
echo "Upload the zip to a GitHub release, or push a v$VERSION tag to let CI do it."
