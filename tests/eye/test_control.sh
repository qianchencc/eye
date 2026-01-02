#!/bin/bash
# tests/eye/test_control.sh
EYE="./bin/eye"
TASK="test_ctl_$(date +%s)"
$EYE add "$TASK" -i 10m
$EYE stop "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$STATUS" == "stopped" ] || { echo "FAIL: stop command"; exit 1; }
$EYE start "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$STATUS" == "running" ] || { echo "FAIL: start command"; exit 1; }
echo "PASS: control (start/stop)"
rm -f "$HOME/.config/eye/tasks/$TASK"
