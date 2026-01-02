#!/bin/bash
# tests/eye/test_add.sh
EYE="./bin/eye"
TASK="test_add_$(date +%s)"
$EYE add "$TASK" -i 15m -d 30s -g work --sound-start bell --msg-start "Hello"
if [ -f "$HOME/.config/eye/tasks/$TASK" ]; then
    source "$HOME/.config/eye/tasks/$TASK"
    [ "$INTERVAL" -eq 900 ] && [ "$DURATION" -eq 30 ] && [ "$GROUP" == "work" ] && [ "$SOUND_START" == "bell" ] && [ "$MSG_START" == "Hello" ] && echo "PASS: add with flags" || { echo "FAIL: add flag verification"; exit 1; }
else
    echo "FAIL: task file not created"; exit 1
fi
rm -f "$HOME/.config/eye/tasks/$TASK"

# Test 0s duration
TASK_ZERO="test_0s_$(date +%s)"
$EYE add "$TASK_ZERO" -i 10s -d 0s
if [ -f "$HOME/.config/eye/tasks/$TASK_ZERO" ]; then
    source "$HOME/.config/eye/tasks/$TASK_ZERO"
    [ "$DURATION" -eq 0 ] && echo "PASS: add with 0s duration" || { echo "FAIL: 0s duration verification"; exit 1; }
else
    echo "FAIL: 0s task file not created"; exit 1
fi
rm -f "$HOME/.config/eye/tasks/$TASK_ZERO"