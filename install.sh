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
    echo -e "${YELLOW}Source detected, preparing to install...${NC}"
    IS_TMP=false
fi

# 2. Dependency Check
echo -e "${YELLOW}Checking dependencies...${NC}"
MISSING_DEPS=()
command -v notify-send >/dev/null 2>&1 || MISSING_DEPS+=("libnotify-bin")
command -v paplay >/dev/null 2>&1 || MISSING_DEPS+=("pulseaudio-utils")
command -v make >/dev/null 2>&1 || MISSING_DEPS+=("make")

# Check for sound theme and bash-completion (common paths)
if [ ! -d "/usr/share/sounds/freedesktop" ]; then
    MISSING_DEPS+=("sound-theme-freedesktop")
fi
if [ ! -f "/usr/share/bash-completion/bash_completion" ] && [ ! -f "/etc/bash_completion" ]; then
    MISSING_DEPS+=("bash-completion")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "Please install them first. Example:"
    echo -e "  sudo apt install ${MISSING_DEPS[*]}"
    exit 1
fi

# 3. Installation
echo -e "${GREEN}Installing to ~/.local ...${NC}"
make install

# 4. Post-Installation Configuration
echo -e "${YELLOW}Configuring environment...${NC}"

# Check PATH
PATH_RELOAD_NEEDED=false
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
            PATH_RELOAD_NEEDED=true
        fi
    fi
fi

# 5. Cleanup
if [ "$IS_TMP" = true ]; then
    rm -rf "$INSTALL_TMP"
fi

echo -e "\n${GREEN}====================================${NC}"
echo -e "🎉  ${GREEN}Eye installed successfully!${NC}"
echo -e "👉  Run ${YELLOW}source $SHELL_RC${NC} to update your current shell."
echo -e "👉  Type ${YELLOW}eye help${NC} to get started."
echo -e "${GREEN}====================================${NC}"
