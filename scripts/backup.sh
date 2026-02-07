#!/usr/bin/env bash
# Hybrid backup script - Git for configs + Zip for world
# Usage: ./backup.sh [--push]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🔧 Minecraft Hybrid Backup"
echo "=========================="

# 1. Git commit config changes
echo ""
echo "📝 Committing config changes..."
git add server-config/ scripts/ docs/ 2>/dev/null || true
if git diff --cached --quiet; then
    echo "  No config changes to commit"
else
    git commit -m "Config update: $(date '+%Y-%m-%d %H:%M')"
    echo "  ✅ Config changes committed"
fi

# 2. Create timestamped world backup
echo ""
echo "💾 Creating world snapshot..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p world-backup/history

# Check if world exists
if [ ! -d "/srv/minecraft/world" ]; then
    echo "  ⚠️  No world found at /srv/minecraft/world"
    echo "  Creating empty marker..."
    echo "No world - server not started yet" > world-backup/history/world-$TIMESTAMP.txt
else
    cd /srv/minecraft
    zip -r "$SCRIPT_DIR/../world-backup/history/world-$TIMESTAMP.zip" world/ \
        -x "*.log" "world/session.lock" "world/playerdata/*.dat" 2>/dev/null || true
    echo "  ✅ World snapshot: world-backup/history/world-$TIMESTAMP.zip"
fi

# 3. Update save.zip (latest snapshot for NixOS rebuilds)
echo ""
echo "📦 Updating save.zip for NixOS rebuilds..."
if [ -f "world-backup/history/world-$TIMESTAMP.zip" ]; then
    cp "world-backup/history/world-$TIMESTAMP.zip" world-backup/save.zip
    echo "  ✅ save.zip updated"
elif [ -f "world-backup/save.zip" ]; then
    echo "  ℹ️  Using existing save.zip (no world yet)"
else
    echo "  ⚠️  No world to backup"
fi

# 4. Optional push
if [ "$1" = "--push" ]; then
    echo ""
    echo "🚀 Pushing to remote..."
    git push origin main 2>/dev/null || echo "  ⚠️  No remote configured"
fi

echo ""
echo "✅ Backup complete!"
echo ""
echo "Quick commands:"
echo "  git status          # See what's changed"
echo "  git log             # View config history"
echo "  ls world-backup/    # See world snapshots"
