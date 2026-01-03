#!/bin/bash
# install.sh - One-click installation for Eye

set -e

# --- Colors ---
GREEN='\033[0;32m'
NC='\033[0m'

echo "🚀 Installing Eye Task Manager..."

# 1. Dependency Check
echo "🔍 Checking dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq libnotify-bin pulseaudio-utils make sound-theme-freedesktop bash-completion bsdmainutils >/dev/null
fi

# 2. Run Makefile installation
if [ -f "Makefile" ]; then
    make install
else
    echo "❌ Error: Makefile not found. Please run this script from the project root."
    exit 1
fi

echo -e "${GREEN}✅ Eye has been installed successfully!${NC}"
echo "Run 'eye help' to get started."