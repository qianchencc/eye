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
