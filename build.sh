#!/bin/sh
# Builds Pomodoro.app. LSUIElement keeps it out of the Dock.
set -e
cd "$(dirname "$0")"
swift build -c release
APP=Pomodoro.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pomodoro "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pomodoro</string>
  <key>CFBundleIdentifier</key><string>se.emil.pomodoro</string>
  <key>CFBundleExecutable</key><string>Pomodoro</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
</dict></plist>
EOF
codesign --force -s - "$APP"
echo "Built $APP — run: open $APP"

# ./build.sh dmg  → also packs Pomodoro.dmg with an Applications shortcut inside
if [ "$1" = dmg ]; then
  STAGE=$(mktemp -d)
  cp -R "$APP" "$STAGE"
  ln -s /Applications "$STAGE/Applications"
  rm -f Pomodoro.dmg
  hdiutil create -quiet -volname Pomodoro -srcfolder "$STAGE" -format UDZO Pomodoro.dmg
  rm -rf "$STAGE"
  echo "Built Pomodoro.dmg"
fi
