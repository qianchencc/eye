#!/bin/bash
# tests/unit/test_counter_temp.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Counter & Temporary Logic ==="

setup_daemon
"$BIN_EYE" add count_task -i 10s -c 5
"$BIN_EYE" add temp_task -i 10s -c 2 --temp
"$BIN_EYE" start count_task
"$BIN_EYE" start temp_task

# 1. Count Decrement
echo "--- Tag: Count Decrement ---"
"$BIN_EYE" count -2 count_task
# Expect 3/5
assert_val count_task REMAIN_COUNT 3 || exit 1

# 2. Count Exhaustion (Standard)
echo "--- Tag: Count Exhaustion (Standard) ---"
"$BIN_EYE" count -3 count_task
assert_val count_task REMAIN_COUNT 0 || exit 1
# Trigger to activate completion logic
"$BIN_EYE" now count_task
sleep 3 # Wait for daemon/process to finish
assert_status count_task stopped || exit 1
# File should still exist
if [ -f "$CONFIG_DIR/tasks/count_task" ]; then
    echo "PASS: count_task file persists."
else
    echo "FAIL: count_task file was deleted."
    exit 1
fi

# 3. Count Exhaustion (Temp)
echo "--- Tag: Count Exhaustion (Temp) ---"
"$BIN_EYE" count -2 temp_task
assert_val temp_task REMAIN_COUNT 0 || exit 1
# Trigger
"$BIN_EYE" now temp_task
sleep 3 # Wait for cleanup
# File should be gone
if [ ! -f "$CONFIG_DIR/tasks/temp_task" ]; then
    echo "PASS: temp_task file deleted."
else
    echo "FAIL: temp_task file still exists."
    debug_dump_state
    exit 1
fi

echo "=== All Counter & Temp Tests Passed ==="
exit 0
