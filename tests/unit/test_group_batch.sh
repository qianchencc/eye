#!/bin/bash
# tests/unit/test_group_batch.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Group & Batch Operations ==="

setup_daemon
"$BIN_EYE" add w1 -g work -i 1h
"$BIN_EYE" add w2 -g work -i 1h
"$BIN_EYE" add h1 -g health -i 1h
"$BIN_EYE" start w1
"$BIN_EYE" start w2
"$BIN_EYE" start h1

# 1. Group Stop
echo "--- Tag: Group Stop (@work) ---"
"$BIN_EYE" stop @work
assert_status w1 paused || exit 1
assert_status w2 paused || exit 1
assert_status h1 running || exit 1

# 2. Regex Group Start
echo "--- Tag: Regex Group Start (@w.*) ---"
"$BIN_EYE" start @w.*
assert_status w1 running || exit 1
assert_status w2 running || exit 1

# 3. Group Modification
echo "--- Tag: Group Modification ---"
"$BIN_EYE" group h1 work
"$BIN_EYE" stop @work
assert_status h1 paused || exit 1
assert_status w1 paused || exit 1
assert_status w2 paused || exit 1

echo "=== All Group & Batch Tests Passed ==="
exit 0
