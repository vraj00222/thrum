#!/usr/bin/env bash
# Packages dist/Thrum.app into a distributable disk image.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP="dist/Thrum.app"
DMG="dist/Thrum-$VERSION.dmg"
STAGE="dist/dmg-stage"
VOLUME="Thrum $VERSION"

[ -d "$APP" ] || { echo "No $APP — run scripts/build-app.sh first"; exit 1; }

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/Thrum.app"
ln -s /Applications "$STAGE/Applications"
[ -f dist/dmg-background.png ] && cp dist/dmg-background.png "$STAGE/.background/background.png"

hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDRW -quiet "dist/rw.dmg"

# Lay the window out. Finder scripting is flaky on headless machines and under
# some permission setups, so a failure here costs the background image and
# nothing else — the symlink is what actually matters.
if MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen "dist/rw.dmg" 2>/dev/null | grep -o '/Volumes/.*'); then
  osascript <<APPLESCRIPT 2>/dev/null || echo "  (window layout skipped)"
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 160, 800, 560}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    try
      set background picture of theViewOptions to file ".background:background.png"
    end try
    set position of item "Thrum.app" of container window to {150, 190}
    set position of item "Applications" of container window to {450, 190}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
  sync
  hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force -quiet
fi

hdiutil convert "dist/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
rm -f "dist/rw.dmg"
rm -rf "$STAGE"

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
