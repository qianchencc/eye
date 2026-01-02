#!/bin/bash
# tests/eye/test_reset.sh
EYE="./bin/eye"
TASK="test_reset_$(date +%s)"
$EYE add "$TASK" -i 1h -c 10
# Manipulate
$EYE time +30m "$TASK"
$EYE count -5 "$TASK"
# Reset
$EYE reset "$TASK" --time --count
source "$HOME/.config/eye/tasks/$TASK"
# After reset, LAST_RUN should be close to now
now=$(date +%s)
[ $((now - LAST_RUN)) -lt 5 ] && [ "$REMAIN_COUNT" -eq 10 ] && echo "PASS: reset" || { echo "FAIL: reset"; exit 1; }
rm -f "$HOME/.config/eye/tasks/$TASK"
