#!/usr/bin/env bash
# Restore world from backup
# Usage: ./restore.sh [backup-file.zip]
#        Without args, restores from save.zip

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

BACKUP_FILE="${1:-$SCRIPT_DIR/../world-backup/save.zip}"

echo "🔄 Minecraft World Restore"
echo "=========================="
echo "Source: $BACKUP_FILE"
echo ""

# Check if backup exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup not found: $BACKUP_FILE"
    echo ""
    echo "Available backups:"
    ls -la world-backup/history/ 2>/dev/null || echo "  No backups found"
    exit 1
fi

# Stop server
echo "🛑 Stopping Minecraft server..."
systemctl stop minecraft-server 2>/dev/null || echo "  Server not running"

# Backup current world first
if [ -d "/srv/minecraft/world" ]; then
    echo ""
    echo "📦 Backing up current world..."
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    cd /srv/minecraft
    zip -r "$SCRIPT_DIR/../world-backup/history/world-pre-restore-$TIMESTAMP.zip" world/ \
        -x "*.log" "world/session.lock" 2>/dev/null || true
    echo "  ✅ Pre-restore backup: world-backup/history/world-pre-restore-$TIMESTAMP.zip"
fi

# Remove old world
echo ""
echo "🗑️  Removing old world..."
rm -rf /srv/minecraft/world

# Extract new world
echo ""
echo "📦 Extracting world from backup..."
cd /srv/minecraft
unzip -o "$BACKUP_FILE" -d world 2>/dev/null || unzip -o "$BACKUP_FILE" 2>/dev/null

# Fix permissions
echo ""
echo "🔐 Setting permissions..."
chown -R minecraft:minecraft /srv/minecraft
chmod -R 755 /srv/minecraft

echo ""
echo "✅ World restored successfully!"
echo ""
echo "Quick commands:"
echo "  systemctl start minecraft-server   # Start server"
echo "  mc-logs                            # Watch logs"
