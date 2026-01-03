#!/bin/bash
# install.sh - Robust installation for Eye

set -e

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Installing Eye Task Manager..."

# 1. Dependency Check
echo "🔍 Checking dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq git libnotify-bin pulseaudio-utils make sound-theme-freedesktop bash-completion bsdmainutils >/dev/null
fi

# 2. Remote Installation Logic
if [ ! -f "Makefile" ]; then
    echo "📦 Remote context detected. Cloning repository..."
    TMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/qianchencc/eye.git "$TMP_DIR" >/dev/null 2>&1
    cd "$TMP_DIR"
    # Ensure we clean up the tmp dir on exit
    trap 'rm -rf "$TMP_DIR"' EXIT
fi

# 3. Run Makefile installation
if [ -f "Makefile" ]; then
    make install
else
    echo -e "${RED}❌ Error: Installation files not found.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Eye has been installed successfully!${NC}"
echo "Run 'eye help' to get started."
