#!/bin/bash
# tests/eye/test_daemon_uninstall.sh
set -e
EYE_BIN="./bin/eye"

echo "--- Preparing for Uninstallation Test ---"
# 1. Install using make dev
make dev

# 2. Verify installation
[ -f "$HOME/.local/bin/eye" ] || { echo "FAIL: Installation check"; exit 1; }
mkdir -p "$HOME/.config/eye/tasks"
touch "$HOME/.config/eye/eye.conf"

# 3. Trigger uninstall
echo "--- Running: eye daemon uninstall ---"
# We need to use the installed binary to test the real-world scenario
"$HOME/.local/bin/eye" daemon uninstall

# 4. Verify cleanup
echo "--- Verifying cleanup ---"
ERROR=0
[ -f "$HOME/.local/bin/eye" ] && { echo "FAIL: Binary still exists"; ERROR=1; }
[ -d "$HOME/.config/eye" ] && { echo "FAIL: Config dir still exists"; ERROR=1; }
[ -d "$HOME/.local/lib/eye" ] && { echo "FAIL: Lib dir still exists"; ERROR=1; }
[ -d "$HOME/.local/state/eye" ] && { echo "FAIL: State dir still exists"; ERROR=1; }

if [ $ERROR -eq 0 ]; then
    echo "PASS: Full uninstallation successful"
else
    echo "FAIL: Full uninstallation leaked files"
    exit 1
fi
