#!/usr/bin/env bash
# Git sync script for automatic config backup
# Usage: ./git-sync.sh
# Can be run from cron or systemd timer

set -e

cd "$(dirname "$0")/.."

LOG_FILE="/var/log/minecraft-git-sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

log "🚀 Starting Git sync..."

# Pull latest changes
log "📥 Pulling latest changes..."
git pull origin main >> "$LOG_FILE" 2>&1 || log "  No remote or no changes"

# Add and commit
log "📝 Checking for config changes..."
git add server-config/ scripts/ docs/ >> "$LOG_FILE" 2>&1

if git diff --cached --quiet; then
    log "  No changes to commit"
else
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
    log "  ✅ Changes committed"
fi

# Push
log "🚀 Pushing to remote..."
git push origin main >> "$LOG_FILE" 2>&1 || log "  ⚠️  Push failed (no remote or no network)"

log "✅ Git sync complete"
