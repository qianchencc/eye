#!/bin/bash
set -e
EYE_BIN="./bin/eye"
# 清理环境
rm -rf "$HOME/.config/eye" "$HOME/.local/share/eye" "$HOME/.local/state/eye"
mkdir -p "$HOME/.config/eye/tasks"

echo "--- Running Full Suite ---"
bash tests/test_full_suite.sh

echo "--- Running Individual Tests ---"
for t in tests/eye/test_*.sh; do
    echo "Running $t..."
    bash "$t"
done

echo "--- VERIFICATION PASSED ---"
