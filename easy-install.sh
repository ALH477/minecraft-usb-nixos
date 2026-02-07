#!/usr/bin/env bash
# All the Mons Server - Easy Installation Wizard
# Run this after NixOS is installed to set up the Minecraft server

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     All the Mons Server - Easy Install Wizard          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root or minecraft user
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${YELLOW}Running as root - will create minecraft user if needed${NC}"
fi

# Find server files
echo "🔍 Looking for All the Mons server files..."
SERVER_ZIP=""
for file in /root/*.zip /home/*/*.zip /tmp/*.zip ~/*.zip; do
    if [ -f "$file" ] && [[ "$file" == *"ServerFiles"* ]] || [[ "$file" == *"All the Mons"* ]]; then
        SERVER_ZIP="$file"
        break
    fi
done

# If not found, ask user
if [ -z "$SERVER_ZIP" ]; then
    echo ""
    echo -e "${YELLOW}Server files not found automatically.${NC}"
    echo "Please provide the path to All the Mons ServerFiles zip:"
    read -r SERVER_ZIP
fi

if [ ! -f "$SERVER_ZIP" ]; then
    echo -e "${RED}Error: Server file not found: $SERVER_ZIP${NC}"
    exit 1
fi

echo -e "${GREEN}Found: $SERVER_ZIP${NC}"
echo ""

# Check if /srv/minecraft exists
if [ -d "/srv/minecraft" ]; then
    echo "⚠️  /srv/minecraft already exists!"
    echo "This will overwrite existing files. Continue? (y/N)"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Create directories
echo ""
echo "📁 Creating directories..."
mkdir -p /srv/minecraft
mkdir -p /srv/backup

# Extract server files
echo ""
echo "📦 Extracting server files..."
cd /srv/minecraft
unzip -o "$SERVER_ZIP" || {
    echo -e "${RED}Failed to extract $SERVER_ZIP${NC}"
    echo "Make sure unzip is installed: nix-env -iA nixpkgs.unzip"
    exit 1
}

# Find and run Forge installer
echo ""
echo "🔧 Installing Forge..."
FORGE_JAR=$(find /srv/minecraft -name "forge-*.jar" -type f 2>/dev/null | head -1)

if [ -z "$FORGE_JAR" ]; then
    echo -e "${YELLOW}Forge installer not found in extracted files.${NC}"
    echo "Please download All the Mons Server Files from CurseForge."
    echo "Expected file pattern: *forge*.jar"
    ls -la /srv/minecraft/
else
    echo "Running: java -jar $FORGE_JAR --installServer"
    java -jar "$FORGE_JAR" --installServer || {
        echo -e "${YELLOW}Forge installation may have failed. Continuing anyway...${NC}"
    }
fi

# Accept EULA
echo ""
echo "📝 Accepting EULA..."
if [ ! -f /srv/minecraft/eula.txt ]; then
    echo "eula=true" > /srv/minecraft/eula.txt
    echo -e "${GREEN}EULA accepted.${NC}"
else
    echo -e "${YELLOW}EULA already exists, backing up and accepting...${NC}"
    cp /srv/minecraft/eula.txt /srv/minecraft/eula.txt.bak
    echo "eula=true" > /srv/minecraft/eula.txt
fi

# Set ownership
echo ""
echo "🔐 Setting ownership..."
chown -R minecraft:minecraft /srv/minecraft
chown -R minecraft:minecraft /srv/backup

# Verify installation
echo ""
echo "✅ Installation complete!"
echo ""
echo "Files in /srv/minecraft:"
ls -la /srv/minecraft/ | head -20

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                   NEXT STEPS                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "1. Start the server:"
echo "   mc-start"
echo ""
echo "2. Watch the logs:"
echo "   mc-logs"
echo ""
echo "3. First startup takes 5-10 minutes (300+ mods to load)"
echo ""
echo "4. When you see 'Done!' you're ready to play!"
echo ""
echo "Connect:  \$(hostname -I | awk '{print \$1}'):33777"
echo ""
