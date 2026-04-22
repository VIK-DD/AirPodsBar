#!/bin/bash
# ============================================================
#  AirPodsBar — Create DMG for distribution
#  Run after build: bash create_dmg.sh
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP="/Applications/AirPodsBar.app"
DMG_NAME="AirPodsBar.dmg"
VOLUME_NAME="AirPodsBar"
TMP_DIR=$(mktemp -d)

echo -e "${YELLOW}Creating DMG...${NC}"

# Check app exists
if [ ! -d "$APP" ]; then
    echo "Error: AirPodsBar.app not found in /Applications. Run install.sh first."
    exit 1
fi

# Create temp folder with app + Applications symlink
cp -R "$APP" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

rm -rf "$TMP_DIR"

echo -e "${GREEN}✓ Created: $DMG_NAME${NC}"
echo "  Upload this file to GitHub Releases."
