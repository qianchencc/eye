#!/bin/bash
# uninstall.sh - Comprehensive cleanup for Eye

set -e

# --- Colors ---
RED='\033[0;31m'
NC='\033[0m'

# Allow --force flag to skip confirmation
FORCE=false
[[ "$1" == "--force" ]] && FORCE=true

if [ "$FORCE" = false ]; then
    read -p "⚠️  Are you sure you want to completely uninstall Eye and remove ALL tasks/config? [y/N] " choice
    [[ "$choice" != "y" && "$choice" != "Y" ]] && { echo "Aborted."; exit 0; }
fi

echo "🗑️  Starting full cleanup..."

# 1. Stop Daemon if running
EYE_PID_FILE="$HOME/.local/state/eye/daemon.pid"
if [ -f "$EYE_PID_FILE" ]; then
    PID=$(cat "$EYE_PID_FILE")
    kill "$PID" 2>/dev/null || true
    echo "Stopping daemon (PID $PID)..."
fi

# 2. Disable Systemd Service
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable eye.service >/dev/null 2>&1 || true
fi

# 3. Remove Files (Mirroring Makefile purge)
echo "Removing binaries and libraries..."
rm -f "$HOME/.local/bin/eye"
rm -rf "$HOME/.local/lib/eye"
rm -rf "$HOME/.local/share/eye"
rm -f "$HOME/.local/share/bash-completion/completions/eye"

echo "Cleaning configuration and state..."
rm -rf "$HOME/.config/eye"
rm -rf "$HOME/.local/state/eye"
rm -f "$HOME/.config/systemd/user/eye.service"

echo -e "${RED}✅ Eye has been completely removed from your system.${NC}"