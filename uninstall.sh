#!/bin/bash
# uninstall.sh - Standalone comprehensive cleanup for Eye

set -e

# --- Colors ---
RED='\033[0;31m'
NC='\033[0m'

# Allow --force flag to skip confirmation
FORCE=false
[[ "$1" == "--force" ]] && FORCE=true

if [ "$FORCE" = false ]; then
    printf "${RED}⚠️  Are you sure you want to completely uninstall Eye and remove ALL tasks/config? [y/N] ${NC}"
    read -r choice
    [[ "$choice" != "y" && "$choice" != "Y" ]] && { echo "Aborted."; exit 0; }
fi

echo "🗑️  Starting full cleanup..."

# 1. Stop Daemon if running
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eye"
EYE_PID_FILE="$STATE_DIR/daemon.pid"
if [ -f "$EYE_PID_FILE" ]; then
    PID=$(cat "$EYE_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping daemon (PID $PID)..."
        kill "$PID" 2>/dev/null || true
    fi
fi

# 2. Disable Systemd Service
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-enabled eye.service >/dev/null 2>&1; then
        echo "Disabling systemd service..."
        systemctl --user disable eye.service >/dev/null 2>&1 || true
    fi
fi

# 3. Remove Files
echo "Removing binaries and libraries..."
rm -f "$HOME/.local/bin/eye"
rm -rf "$HOME/.local/lib/eye"
rm -rf "$HOME/.local/share/eye"
rm -f "$HOME/.local/share/bash-completion/completions/eye"

echo "Cleaning configuration and state..."
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/eye"
rm -rf "$STATE_DIR"
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/eye.service"

echo -e "${RED}✅ Eye has been completely removed from your system.${NC}"
