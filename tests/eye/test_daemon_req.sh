#!/bin/bash
# tests/eye/test_daemon_req.sh
EYE="./bin/eye"
TASKS_DIR="$HOME/.config/eye/tasks"

# Ensure daemon is DOWN
$EYE daemon down >/dev/null 2>&1
sleep 1

# 1. Test Add Default Status
TASK="req_test_add"
$EYE rm "$TASK" >/dev/null 2>&1
$EYE add "$TASK" -i 1h >/dev/null 2>&1
source "$TASKS_DIR/$TASK"
if [ "$EYE_T_STATUS" == "stopped" ]; then
    echo "PASS: New task defaults to stopped"
else
    echo "FAIL: New task status is $EYE_T_STATUS (expected stopped)"
    exit 1
fi

# 2. Test Start fails without Daemon
OUTPUT=$($EYE start "$TASK" 2>&1)
if echo "$OUTPUT" | grep -q "Daemon is inactive"; then
    echo "PASS: Start rejected without daemon"
else
    echo "FAIL: Start allowed or wrong error"
    echo "Output: $OUTPUT"
    exit 1
fi

# 3. Test Start works WITH Daemon
$EYE daemon up >/dev/null 2>&1
sleep 1
$EYE start "$TASK" >/dev/null 2>&1
source "$TASKS_DIR/$TASK"
if [ "$EYE_T_STATUS" == "running" ]; then
    echo "PASS: Start works with daemon"
else
    echo "FAIL: Start failed with daemon"
    exit 1
fi

$EYE rm "$TASK" >/dev/null 2>&1
$EYE daemon down >/dev/null 2>&1
exit 0
