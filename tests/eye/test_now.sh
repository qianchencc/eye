#!/bin/bash
# tests/eye/test_now.sh
EYE="./bin/eye"
TASK="test_now_$(date +%s)"
$EYE add "$TASK" -i 1h -d 2s
start_ts=$(date +%s)
$EYE now "$TASK"
end_ts=$(date +%s)
[ $((end_ts - start_ts)) -lt 2 ] && echo "PASS: now non-blocking" || { echo "FAIL: now blocked terminal"; exit 1; }
rm -f "$HOME/.config/eye/tasks/$TASK"
