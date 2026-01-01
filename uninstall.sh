#!/bin/bash

# Eye - One-line Uninstaller
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}>>> Eye Protection Tool Uninstaller${NC}"

# 1. Stop the daemon if it's running
if command -v eye >/dev/null 2>&1; then
    echo -e "${YELLOW}Stopping eye daemon...${NC}"
    eye stop >/dev/null 2>&1 || true
fi

# 2. Run make purge
if [ -f "Makefile" ]; then
    echo -e "${YELLOW}Running make purge...${NC}"
    make purge
else
    echo -e "${RED}Error: Makefile not found. Cannot perform full uninstall.${NC}"
    exit 1
fi

# 3. Clean up PATH in shell RC files
echo -e "${YELLOW}Cleaning up environment...${NC}"
LOCAL_BIN="$HOME/.local/bin"
FILES_TO_CLEAN=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")

for RC_FILE in "${FILES_TO_CLEAN[@]}"; do
    if [ -f "$RC_FILE" ]; then
        if grep -q "# Eye Path" "$RC_FILE"; then
            # Remove the comment and the export line
            sed -i '/# Eye Path/d' "$RC_FILE"
            # Use | as delimiter to avoid issues with / in paths
            sed -i "s|export PATH=\"\$PATH:$LOCAL_BIN\"||g" "$RC_FILE"
            # Remove resulting empty lines
            sed -i '/^$/d' "$RC_FILE"
            echo -e "${GREEN}Removed Eye Path from $RC_FILE${NC}"
        fi
    fi
done

echo -e "\n${GREEN}====================================${NC}"
echo -e "🗑️  ${GREEN}Eye has been fully uninstalled.${NC}"
echo -e "🧹  ${GREEN}Configuration and state files removed.${NC}"
echo -e "${GREEN}====================================${NC}"
