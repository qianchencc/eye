#!/bin/bash
# tests/unit/test_now_trigger.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Now Trigger ==="

setup_daemon
"$BIN_EYE" add now_test -i 1h -d 0

# 1. Trigger Stopped
echo "--- Tag: Trigger Stopped ---"
"$BIN_EYE" now now_test
# Status should REMAIN stopped
assert_status now_test stopped || exit 1
# Verification of notification is hard without mock, but checking status stability is key.

# 2. Trigger Running (Reset Timer)
echo "--- Tag: Trigger Running ---"
"$BIN_EYE" start now_test
sleep 2
# Manually shift time to make it look like 30m passed
"$BIN_EYE" time +30m now_test
# Check NEXT is ~30m
NEXT_BEFORE=$("$TOOL_DIR/get_next" now_test | tail -n 1 | awk -F"│" '{print $2}' | xargs)
echo "Next before now: $NEXT_BEFORE"

# Trigger now
"$BIN_EYE" now now_test
sleep 2 # Wait for execution to finish and LAST_RUN to update

# NEXT should be reset to ~1h (59m or 1h)
NEXT_AFTER=$("$TOOL_DIR/get_next" now_test | tail -n 1 | awk -F"│" '{print $2}' | xargs)
echo "Next after now: $NEXT_AFTER"

if [[ "$NEXT_AFTER" == *"59m"* ]] || [[ "$NEXT_AFTER" == *"1h"* ]]; then
    echo "PASS: Timer reset after 'now' trigger."
else
    echo "FAIL: Timer did not reset. Got $NEXT_AFTER"
    debug_dump_state
    exit 1
fi

echo "=== All Now Trigger Tests Passed ==="
exit 0
