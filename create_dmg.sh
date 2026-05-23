#!/bin/bash
# ============================================================
#  AirPodsBar — DMG Installer Builder
#  Creates a native-feeling macOS installer DMG.
#
#  Usage:
#    bash create_dmg.sh            # builds app then creates DMG
#    bash create_dmg.sh --no-build # skips build (uses build/AirPodsBar.app)
# ============================================================

set -e

# -------- colors --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------- config --------
APP_NAME="AirPodsBar"
VERSION="2.0"
DMG_NAME="${APP_NAME}-${VERSION}"
VOLUME_NAME="${APP_NAME} ${VERSION}"

BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_TMP="$BUILD_DIR/${DMG_NAME}-tmp.dmg"
DMG_FINAL="$BUILD_DIR/${DMG_NAME}.dmg"

echo ""
echo -e "${BLUE}📦 AirPodsBar DMG Builder${NC}"
echo "================================"

# -------- 0. check sanity --------
if [ ! -f "AirPodsBar/main.swift" ]; then
    echo -e "${RED}✗ Run this script from the project root (where AirPodsBar/ lives).${NC}"
    exit 1
fi

# -------- 1. build the app (unless --no-build) --------
if [ "$1" != "--no-build" ]; then
    echo -e "\n${YELLOW}[1/5]${NC} Building app..."
    if [ ! -f "install.sh" ]; then
        echo -e "${RED}✗ install.sh not found — cannot build.${NC}"
        exit 1
    fi
    # Run install.sh up to the bundle creation, but don't install to /Applications.
    # We re-implement a minimal build here to keep this script standalone-friendly.

    CONTENTS="$APP_BUNDLE/Contents"
    MACOS_DIR="$CONTENTS/MacOS"
    RESOURCES_DIR="$CONTENTS/Resources"

    rm -rf "$BUILD_DIR"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    SWIFT_SRCS=(
        "AirPodsBar/main.swift"
        "AirPodsBar/AppDelegate.swift"
        "AirPodsBar/BatteryMonitor.swift"
        "AirPodsBar/ContentView.swift"
    )
    SWIFTC_FRAMEWORKS=(
        -framework SwiftUI -framework AppKit -framework IOBluetooth
        -framework Carbon -framework Combine -framework UserNotifications
    )
    SDK_PATH="$(xcrun --show-sdk-path)"

    # Build universal binary — both arm64 (Apple Silicon) and x86_64 (Intel)
    echo "  Building arm64 slice..."
    swiftc "${SWIFT_SRCS[@]}" \
        -o "$BUILD_DIR/${APP_NAME}-arm64" \
        -sdk "$SDK_PATH" -target arm64-apple-macos12.0 \
        "${SWIFTC_FRAMEWORKS[@]}" -O

    echo "  Building x86_64 slice..."
    swiftc "${SWIFT_SRCS[@]}" \
        -o "$BUILD_DIR/${APP_NAME}-x86_64" \
        -sdk "$SDK_PATH" -target x86_64-apple-macos12.0 \
        "${SWIFTC_FRAMEWORKS[@]}" -O

    echo "  Merging slices with lipo..."
    lipo -create -output "$MACOS_DIR/${APP_NAME}" \
        "$BUILD_DIR/${APP_NAME}-arm64" \
        "$BUILD_DIR/${APP_NAME}-x86_64"
    rm "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x86_64"

    # Info.plist
    cat > "$CONTENTS/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.vik.airpodsbar</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>AirPodsBar reads your AirPods battery levels.</string>
    <key>NSBluetoothPeripheralUsageDescription</key><string>AirPodsBar reads your AirPods battery levels.</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST_EOF

    # Icon
    if command -v iconutil &>/dev/null; then
        ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
        mkdir -p "$ICONSET_DIR"
        for f in AirPodsBar/Assets.xcassets/AppIcon.appiconset/*.png; do
            cp "$f" "$ICONSET_DIR/" 2>/dev/null || true
        done
        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ App built at $APP_BUNDLE${NC}"
else
    echo -e "\n${YELLOW}[1/5]${NC} Skipping build (--no-build)."
    if [ ! -d "$APP_BUNDLE" ]; then
        echo -e "${RED}✗ $APP_BUNDLE not found. Run without --no-build first.${NC}"
        exit 1
    fi
fi

# -------- 2. ad-hoc sign the app so Gatekeeper doesn't quarantine on copy --------
echo -e "\n${YELLOW}[2/5]${NC} Ad-hoc signing the app..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && \
    echo -e "${GREEN}✓ Signed (ad-hoc).${NC}" || \
    echo -e "${YELLOW}⚠ Could not ad-hoc sign (continuing anyway).${NC}"

# -------- 3. stage DMG contents --------
echo -e "\n${YELLOW}[3/5]${NC} Staging DMG contents..."

rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Symlink to /Applications (so user can drag-and-drop)
ln -s /Applications "$DMG_DIR/Applications"

# Background folder (hidden)
mkdir -p "$DMG_DIR/.background"
if [ -f "Assets/dmg-background.png" ]; then
    cp "Assets/dmg-background.png" "$DMG_DIR/.background/background.png"
    HAS_BG=1
else
    HAS_BG=0
fi

echo -e "${GREEN}✓ Staged at $DMG_DIR${NC}"

# -------- 4. create temp DMG, mount, configure layout --------
echo -e "\n${YELLOW}[4/5]${NC} Creating DMG..."

# Compute size with some padding
SIZE_KB=$(du -sk "$DMG_DIR" | awk '{print $1}')
SIZE_MB=$(( (SIZE_KB / 1024) + 50 ))

rm -f "$DMG_TMP" "$DMG_FINAL"

hdiutil create \
    -srcfolder "$DMG_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${SIZE_MB}m" \
    "$DMG_TMP" >/dev/null

# Mount
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$DMG_TMP" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null

# AppleScript to set Finder window layout
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 1000, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        if $HAS_BG = 1 then
            try
                set background picture of viewOptions to file ".background:background.png"
            end try
        end if
        set position of item "${APP_NAME}.app" of container window to {160, 200}
        set position of item "Applications" of container window to {440, 200}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

# Ensure all writes are flushed
sync

# Unmount
hdiutil detach "$MOUNT_DIR" >/dev/null

echo -e "${GREEN}✓ Layout configured.${NC}"

# -------- 5. convert to compressed read-only DMG --------
echo -e "\n${YELLOW}[5/5]${NC} Finalizing DMG..."
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null
rm -f "$DMG_TMP"

FINAL_SIZE=$(du -h "$DMG_FINAL" | awk '{print $1}')

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}🎉 DMG ready!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "  📦 ${BLUE}${DMG_FINAL}${NC}"
echo -e "     Size: ${FINAL_SIZE}"
echo ""
echo "  Upload this file to your GitHub release."
echo ""
