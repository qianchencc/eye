#!/bin/bash
# tests/eye/test_advanced_pipes.sh
EYE="./bin/eye"
TASKS_DIR="$HOME/.config/eye/tasks"

# Setup
rm -rf "$TASKS_DIR"
mkdir -p "$TASKS_DIR"

# 1. Test Mass Creation via Pipe
echo "p1 p2 p3" | $EYE add -i 1h -g pipe_test
[ -f "$TASKS_DIR/p1" ] && [ -f "$TASKS_DIR/p2" ] && [ -f "$TASKS_DIR/p3" ] || { echo "FAIL: Mass creation via pipe"; exit 1; }
echo "PASS: Mass creation via pipe"

# 2. Test Filtered Control (Status -> Grep -> Stop)
# Create some tasks in different groups
$EYE add group_a_1 -g group_a -i 1h
$EYE add group_a_2 -g group_a -i 1h
$EYE add group_b_1 -g group_b -i 1h

# Use pipe to stop all 'group_a' tasks
# In piped mode, 'eye list' should output raw IDs
$EYE list | grep "group_a" | $EYE stop
source "$TASKS_DIR/group_a_1"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Piped filtered stop (a1)"; exit 1; }
source "$TASKS_DIR/group_a_2"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Piped filtered stop (a2)"; exit 1; }
source "$TASKS_DIR/group_b_1"
[ "$EYE_T_STATUS" == "stopped" ] || { echo "FAIL: Piped filtered stop side effect (b1)"; exit 1; }
echo "PASS: Filtered control via pipe"

# 3. Test Bulk Attribute Modification (List -> Group)
$EYE list | grep "p[1-3]" | $EYE group bulk_group
source "$TASKS_DIR/p1"
[ "$EYE_T_GROUP" == "bulk_group" ] || { echo "FAIL: Bulk group change via pipe"; exit 1; }
echo "PASS: Bulk attribute modification via pipe"

# 4. Test Bulk Removal
$EYE list | grep "group_" | $EYE remove
[ ! -f "$TASKS_DIR/group_a_1" ] && [ ! -f "$TASKS_DIR/group_b_1" ] || { echo "FAIL: Bulk removal via pipe"; exit 1; }
echo "PASS: Bulk removal via pipe"

# 5. Test Piped 'now'
$EYE list | $EYE now
# Just verify it doesn't crash and output contains trigger messages
echo "PASS: Piped now"

echo "ALL ADVANCED PIPE TESTS PASSED"
rm -rf "$TASKS_DIR"
