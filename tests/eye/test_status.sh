#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

# Cleanup first
$EYE rm "$TASK" >/dev/null 2>&1

$EYE daemon down >/dev/null 2>&1
$EYE add "$TASK" -i 10m -d 5s -c 3 -g test_group >/dev/null 2>&1

log_info "Testing Pipe-friendly Status (No TTY)"
# Should output just the task ID
OUTPUT=$($EYE status)
if echo "$OUTPUT" | grep -q "$TASK"; then
    echo "PASS: Pipe status contains ID"
else
    echo "FAIL: Pipe status missing ID"
    echo "Output: $OUTPUT"
    exit 1
fi

log_info "Testing Single Task Inspection"
# Should output metadata KEY=VALUE
OUTPUT=$($EYE status "$TASK")
if echo "$OUTPUT" | grep -q "EYE_T_GROUP=test_group"; then
    echo "PASS: Single task inspection"
else
    echo "FAIL: Single task inspection missing metadata"
    echo "Output: $OUTPUT"
    exit 1
fi

log_info "Testing static NEXT time after daemon down"
$EYE daemon down >/dev/null 2>&1
# Using inspection to get raw values for robust comparison
VAL1=$($EYE status "$TASK" | grep "EYE_T_LAST_RUN")
sleep 2
VAL2=$($EYE status "$TASK" | grep "EYE_T_LAST_RUN")
if [ "$VAL1" == "$VAL2" ]; then
    echo "PASS: Static state (LAST_RUN unchanged)"
else
    echo "FAIL: State changed while daemon is off"
    echo "1: $VAL1"
    echo "2: $VAL2"
    exit 1
fi

$EYE remove "$TASK" >/dev/null 2>&1
exit 0