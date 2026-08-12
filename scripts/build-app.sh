#!/usr/bin/env bash
# Assembles Thrum.app from the SPM executable.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP="dist/Thrum.app"
CONFIG="${CONFIG:-release}"
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

# Universal by default so the download works on Intel too. UNIVERSAL=0 for a fast
# local build.
if [ "${UNIVERSAL:-1}" = "1" ]; then
  ARCHS="--arch arm64 --arch x86_64"
else
  ARCHS=""
fi

echo "Building Thrum $VERSION ($CONFIG${ARCHS:+, universal})"
cd mac
# shellcheck disable=SC2086
swift build -c "$CONFIG" $ARCHS --product Thrum
BIN=$(swift build -c "$CONFIG" $ARCHS --product Thrum --show-bin-path)
cd ..

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Thrum" "$APP/Contents/MacOS/Thrum"

# SPM emits resources as a .bundle next to the binary. Bundle.module finds it in
# Contents/Resources, which is where the fonts have to live.
for bundle in "$BIN"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

# The icon has to sit loose in Resources; Finder won't look inside the SPM bundle.
cp mac/Sources/ThrumApp/Resources/Thrum.icns "$APP/Contents/Resources/Thrum.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Thrum</string>
  <key>CFBundleDisplayName</key><string>Thrum</string>
  <key>CFBundleExecutable</key><string>Thrum</string>
  <key>CFBundleIconFile</key><string>Thrum</string>
  <key>CFBundleIdentifier</key><string>app.thrum.Thrum</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Thrum reads the text you select so it can tap it out in Morse.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature. Without it the private MultitouchSupport lookup and the global
# hotkey both work, but macOS nags harder on first launch.
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (ad-hoc signing skipped)"

echo "Built $APP"
