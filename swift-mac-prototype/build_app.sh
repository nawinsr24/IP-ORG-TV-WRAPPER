#!/bin/bash
# Builds TamilTV.app next to this script.
set -e
cd "$(dirname "$0")"
swift build -c release
APP=TamilTV.app
rm -rf $APP; mkdir -p $APP/Contents/MacOS
cp .build/release/TamilTV $APP/Contents/MacOS/
mkdir -p $APP/Contents/Resources; cp AppIcon.icns $APP/Contents/Resources/
cat > $APP/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Tamil TV</string>
<key>CFBundleDisplayName</key><string>Tamil TV</string>
<key>CFBundleIdentifier</key><string>com.local.tamiltv</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>TamilTV</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
P
codesign --force --sign - $APP
echo "Built $APP"
