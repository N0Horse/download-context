#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP_DIR="$DIST/Ctx.app"
CACHE_DIR="$DIST/.swift-cache"

mkdir -p "$DIST" "$CACHE_DIR/module-cache"

"$ROOT/scripts/build_core.sh"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is not installed. Install Xcode (or Command Line Tools) and retry." >&2
  exit 1
fi

set +e
CLANG_MODULE_CACHE_PATH="$CACHE_DIR/module-cache" swift build --configuration release --package-path "$ROOT/app-swift"
SWIFT_STATUS=$?
set -e
if [[ $SWIFT_STATUS -ne 0 ]]; then
  cat <<'MSG' >&2
Swift build failed.
Common fixes:
1) Install full Xcode and select it:
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
2) Ensure Xcode and Command Line Tools versions match.
3) Re-run: ./scripts/build_app.sh
MSG
  exit $SWIFT_STATUS
fi

BIN="$ROOT/app-swift/.build/release/Ctx"
if [[ ! -x "$BIN" ]]; then
  echo "Swift executable not found: $BIN" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/Ctx"
cp "$DIST/ctx-core" "$APP_DIR/Contents/MacOS/ctx-core"
chmod +x "$APP_DIR/Contents/MacOS/Ctx" "$APP_DIR/Contents/MacOS/ctx-core"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Ctx</string>
  <key>CFBundleDisplayName</key>
  <string>Ctx</string>
  <key>CFBundleIdentifier</key>
  <string>local.ctx.app</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Ctx</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built app bundle at $APP_DIR"
