#!/bin/bash
# tests/unit/test_lifecycle.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Core Lifecycle & Daemon Dependency ==="

# 1. Start (Daemon Off)
echo "--- Tag: Start (Daemon Off) ---"
setup_clean
"$BIN_EYE" add lifecycle1 -i 1h -d 20s

echo "Attempting start without daemon..."
OUTPUT=$("$BIN_EYE" start lifecycle1 2>&1)
if [[ "$OUTPUT" == *"Daemon is inactive"* ]] || [[ "$OUTPUT" == *"Daemon is NOT running"* ]]; then
    echo "PASS: CLI correctly refused start."
else
    echo "FAIL: CLI did not refuse start. Output: $OUTPUT"
    exit 1
fi
assert_status lifecycle1 stopped || exit 1

# 2. Start (Daemon On)
echo "--- Tag: Start (Daemon On) ---"
setup_daemon
# Task was deleted by setup_clean inside setup_daemon, so we must re-add it.
"$BIN_EYE" add lifecycle1 -i 1h -d 20s
"$BIN_EYE" start lifecycle1
assert_status lifecycle1 running || exit 1

# 3. Stop/Pause
echo "--- Tag: Stop/Pause ---"
"$BIN_EYE" stop lifecycle1
assert_status lifecycle1 paused || exit 1

# 4. Resume
echo "--- Tag: Resume ---"
"$BIN_EYE" resume lifecycle1
assert_status lifecycle1 running || exit 1

echo "=== All Lifecycle Tests Passed ==="
exit 0
