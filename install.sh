#!/bin/bash
# ============================================================
#  AirPodsBar — Install Script
#  Rulează din folderul AirPodsBar/ cu: bash install.sh
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

# --- 0. Verifică că suntem în folderul corect ---
if [ ! -f "AirPodsBar/main.swift" ]; then
    echo -e "${RED}✗ Eroare: rulează scriptul DIN folderul AirPodsBar/${NC}"
    echo "  cd ~/Downloads/AirPodsBar && bash install.sh"
    exit 1
fi

# --- 1. Verifică Xcode Command Line Tools ---
echo -e "\n${YELLOW}[1/6]${NC} Verific Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}✗ Xcode Command Line Tools nu sunt instalate.${NC}"
    echo ""
    echo "  Instalează-le cu:"
    echo "  xcode-select --install"
    echo ""
    echo "  Apoi rulează din nou: bash install.sh"
    exit 1
fi
echo -e "${GREEN}✓ Xcode CLT: $(xcode-select -p)${NC}"

if ! command -v swiftc &>/dev/null; then
    echo -e "${RED}✗ swiftc nu a fost găsit. Reinstalează Xcode Command Line Tools.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ swiftc: $(swiftc --version | head -1)${NC}"

# --- 2. blueutil (opțional, nu mai e necesar) ---
echo -e "\n${YELLOW}[2/6]${NC} Verific dependențe..."
echo -e "${GREEN}✓ Connect/Disconnect folosește IOBluetooth nativ — blueutil nu e necesar.${NC}" 

# --- 3. Detectează arhitectura și compilează ---
echo -e "\n${YELLOW}[3/6]${NC} Compilez pentru arhitectura ta..."

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macos12.0"
    echo "  Arhitectură: Apple Silicon (arm64)"
else
    TARGET="x86_64-apple-macos12.0"
    echo "  Arhitectură: Intel (x86_64)"
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
        echo -e "${RED}✗ Fișier lipsă: $f${NC}"
        exit 1
    fi
done

echo "  Compilez... (poate dura 30-60 secunde)"

swiftc "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/AirPodsBar" \
    -sdk "$(xcrun --show-sdk-path)" \
    -target "$TARGET" \
    -framework SwiftUI \
    -framework AppKit \
    -framework IOBluetooth \
    -framework Combine \
    -framework UserNotifications \
    -O

echo -e "${GREEN}✓ Compilat cu succes pentru $TARGET${NC}"

# --- 4. Creează Info.plist ---
echo -e "\n${YELLOW}[4/6]${NC} Creez bundle-ul aplicației..."

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
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>AirPodsBar citește nivelul bateriei AirPods.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>AirPodsBar citește nivelul bateriei AirPods.</string>
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

# Copiază iconul în Resources
if [ -f "AirPodsBar/AppIcon.png" ]; then
    cp "AirPodsBar/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
    cp "AirPodsBar/AppIcon@2x.png" "$RESOURCES_DIR/AppIcon@2x.png" 2>/dev/null || true
    echo "  Icon copiat în bundle."
fi

# Creează .icns din PNG pentru Finder (iconița aplicației)
if command -v iconutil &>/dev/null; then
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    # Copiază toate dimensiunile disponibile
    for f in AirPodsBar/Assets.xcassets/AppIcon.appiconset/*.png; do
        cp "$f" "$ICONSET_DIR/" 2>/dev/null || true
    done
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null &&         echo "  AppIcon.icns creat." || echo "  iconutil nu a putut crea .icns (ok, PNG folosit)."
fi

echo -e "${GREEN}✓ Info.plist creat.${NC}"

# --- 5. Mută în /Applications ---
echo -e "\n${YELLOW}[5/6]${NC} Instalez în /Applications..."

DEST="/Applications/AirPodsBar.app"
if [ -d "$DEST" ]; then
    echo "  Versiune veche detectată — o șterg..."
    pkill -x AirPodsBar 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
fi

cp -R "$APP_BUNDLE" "$DEST"
echo -e "${GREEN}✓ /Applications/AirPodsBar.app${NC}"

# --- 6. Configurează startup ---
echo -e "\n${YELLOW}[6/6]${NC} Configurez pornirea automată la login..."

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS"

PLIST_DEST="$LAUNCH_AGENTS/com.vik.airpodsbar.plist"

# Scriem doar fișierul plist — launchd îl citește la login
# NU apelăm launchctl load — ar porni o a doua instanță peste cea deja pornită
cp "$(pwd)/com.vik.airpodsbar.plist" "$PLIST_DEST"

echo -e "${GREEN}✓ Startup configurat (activ de la următorul login).${NC}"

# --- Done ---
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}🎉 Instalare completă!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "  Pornesc AirPodsBar acum..."
open "$DEST"
sleep 1
echo ""
echo -e "  🎧 Iconiță a apărut în bara de meniu (sus dreapta)."
echo -e "  Apasă pe ea pentru a vedea bateria AirPods."
echo ""
echo -e "${BLUE}Comenzi utile:${NC}"
echo "  Oprește app:          pkill -x AirPodsBar"
echo "  Dezactivează startup: launchctl unload ~/Library/LaunchAgents/com.vik.airpodsbar.plist"
echo "  Dezinstalează:        rm -rf /Applications/AirPodsBar.app"
echo "  Re-instalează:        bash install.sh"
