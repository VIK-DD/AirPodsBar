#!/bin/bash
# ============================================================
#  AirPodsBar — Install Script
#  Run from the project root:  bash install.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}🎧 AirPodsBar Installer${NC}"
echo "================================"

# --- 0. Verify we're in the right folder ---
if [ ! -f "AirPodsBar/main.swift" ]; then
    echo -e "${RED}✗ Error: run this script FROM the AirPodsBar/ project root${NC}"
    echo "  cd ~/Downloads/AirPodsBar && bash install.sh"
    exit 1
fi

# --- 1. Check Xcode Command Line Tools ---
echo -e "\n${YELLOW}[1/6]${NC} Checking Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}✗ Xcode Command Line Tools are not installed.${NC}"
    echo ""
    echo "  Install them with:"
    echo "  xcode-select --install"
    echo ""
    echo "  Then run again: bash install.sh"
    exit 1
fi
echo -e "${GREEN}✓ Xcode CLT: $(xcode-select -p)${NC}"

if ! command -v swiftc &>/dev/null; then
    echo -e "${RED}✗ swiftc not found. Reinstall Xcode Command Line Tools.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ swiftc: $(swiftc --version | head -1)${NC}"

# --- 2. Dependencies (none required since v1.0) ---
echo -e "\n${YELLOW}[2/6]${NC} Checking dependencies..."
echo -e "${GREEN}✓ Connect/Disconnect uses native IOBluetooth — no external deps needed.${NC}"

# --- 3. Detect architecture and compile ---
echo -e "\n${YELLOW}[3/6]${NC} Compiling for your architecture..."

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macos12.0"
    echo "  Architecture: Apple Silicon (arm64)"
else
    TARGET="x86_64-apple-macos12.0"
    echo "  Architecture: Intel (x86_64)"
fi

BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/AirPodsBar.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SWIFT_FILES=(
    "AirPodsBar/main.swift"
    "AirPodsBar/AppDelegate.swift"
    "AirPodsBar/BatteryMonitor.swift"
    "AirPodsBar/ContentView.swift"
)

for f in "${SWIFT_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}✗ Missing file: $f${NC}"
        exit 1
    fi
done

echo "  Compiling... (may take 30-60 seconds)"

swiftc "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/AirPodsBar" \
    -sdk "$(xcrun --show-sdk-path)" \
    -target "$TARGET" \
    -framework SwiftUI \
    -framework AppKit \
    -framework IOBluetooth \
    -framework Carbon \
    -framework Combine \
    -framework UserNotifications \
    -O

echo -e "${GREEN}✓ Built successfully for $TARGET${NC}"

# --- 4. Create Info.plist ---
echo -e "\n${YELLOW}[4/6]${NC} Creating app bundle..."

cat > "$CONTENTS/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AirPodsBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.vik.airpodsbar</string>
    <key>CFBundleName</key>
    <string>AirPodsBar</string>
    <key>CFBundleDisplayName</key>
    <string>AirPodsBar</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>AirPodsBar reads the battery level of your AirPods.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>AirPodsBar reads the battery level of your AirPods.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST_EOF

# Copy icon into Resources
if [ -f "AirPodsBar/AppIcon.png" ]; then
    cp "AirPodsBar/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
    cp "AirPodsBar/AppIcon@2x.png" "$RESOURCES_DIR/AppIcon@2x.png" 2>/dev/null || true
    echo "  Icon copied into bundle."
fi

# Build .icns from PNGs for Finder (app icon)
if command -v iconutil &>/dev/null; then
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    # Copy every available size
    for f in AirPodsBar/Assets.xcassets/AppIcon.appiconset/*.png; do
        cp "$f" "$ICONSET_DIR/" 2>/dev/null || true
    done
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null && \
        echo "  AppIcon.icns generated." || echo "  iconutil could not generate .icns (ok, PNG fallback used)."
fi

echo -e "${GREEN}✓ Info.plist created.${NC}"

# --- 5. Install into /Applications ---
echo -e "\n${YELLOW}[5/6]${NC} Installing into /Applications..."

DEST="/Applications/AirPodsBar.app"
if [ -d "$DEST" ]; then
    echo "  Old version detected — removing it..."
    pkill -x AirPodsBar 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
fi

cp -R "$APP_BUNDLE" "$DEST"
echo -e "${GREEN}✓ /Applications/AirPodsBar.app${NC}"

# --- 6. Configure launch-at-login ---
echo -e "\n${YELLOW}[6/6]${NC} Setting up launch at login..."

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS"

PLIST_DEST="$LAUNCH_AGENTS/com.vik.airpodsbar.plist"

# Just write the plist file — launchd picks it up at login.
# We do NOT call `launchctl load` here — it would start a second instance
# on top of the one we open below.
cp "$(pwd)/com.vik.airpodsbar.plist" "$PLIST_DEST"

echo -e "${GREEN}✓ Launch-at-login configured (active from next login).${NC}"

# --- Done ---
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}🎉 Install complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "  Starting AirPodsBar now..."
open "$DEST"
sleep 1
echo ""
echo -e "  🎧 Icon should appear in the menu bar (top-right)."
echo -e "  Click it to see your AirPods battery — or press ⌥⌘A from anywhere."
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Stop app:               pkill -x AirPodsBar"
echo "  Disable launch-at-login: launchctl unload ~/Library/LaunchAgents/com.vik.airpodsbar.plist"
echo "  Uninstall:              rm -rf /Applications/AirPodsBar.app"
echo "  Reinstall:              bash install.sh"
