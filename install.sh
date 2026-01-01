#!/bin/bash

# Eye - Intelligent One-line Installer
set -e

REPO_URL="https://github.com/qianchencc/eye.git"
INSTALL_TMP="/tmp/eye_install_$(date +%s)"
LOCAL_BIN="$HOME/.local/bin"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}>>> Eye Protection Tool Installer${NC}"

# 1. Environment Check
if [ ! -f "Makefile" ] || [ ! -d "bin" ]; then
    echo -e "${YELLOW}Non-source environment detected, cloning from GitHub...${NC}"
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}Error: git is not installed.${NC}"
        exit 1
    fi
    git clone "$REPO_URL" "$INSTALL_TMP"
    cd "$INSTALL_TMP"
    IS_TMP=true
else
    IS_TMP=false
fi

# 2. Pre-requisite Check (make)
if ! command -v make >/dev/null 2>&1; then
    echo -e "${RED}Error: 'make' is required for installation.${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        echo -e "👉 Please run: ${YELLOW}sudo apt-get update && sudo apt-get install -y make${NC}"
    else
        echo -e "👉 Please install 'make' using your package manager."
    fi
    exit 1
fi

# 3. Dependency Check
echo -e "${YELLOW}Checking dependencies...${NC}"
make check

# 4. Installation
echo -e "${GREEN}Installing to ~/.local ...${NC}"
make install

# 5. Post-Installation Configuration
echo -e "${YELLOW}Configuring environment...${NC}"
if [[ ":$PATH:" != ":$LOCAL_BIN:"* ]]; then
    SHELL_RC=""
    case "$SHELL" in
        */bash) SHELL_RC="$HOME/.bashrc" ;; 
        */zsh)  SHELL_RC="$HOME/.zshrc" ;; 
        *)      SHELL_RC="$HOME/.profile" ;; 
    esac
    
    if [ -f "$SHELL_RC" ]; then
        if ! grep -q "$LOCAL_BIN" "$SHELL_RC"; then
            echo -e "\n# Eye Path\nexport PATH=\"\$PATH:$LOCAL_BIN\"" >> "$SHELL_RC"
            echo -e "${GREEN}Added $LOCAL_BIN to $SHELL_RC${NC}"
        fi
    fi
fi

# 6. Cleanup
if [ "$IS_TMP" = true ]; then
    rm -rf "$INSTALL_TMP"
fi

echo -e "\n${GREEN}====================================${NC}"
echo -e "🎉  ${GREEN}Eye installed successfully!${NC}"
echo -e "👉  If you missed dependencies, run 'make install-deps'."
echo -e "👉  Type ${YELLOW}eye help${NC} to get started."
echo -e "${GREEN}====================================${NC}"
