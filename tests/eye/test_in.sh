#!/bin/bash
# tests/eye/test_in.sh
EYE="./bin/eye"
NO_COLOR=1 $EYE in 30m "Nap time" 2>&1 | grep -q "Reminder set for 30m" && echo "PASS: in" || { echo "FAIL: in"; exit 1; }
# Cleanup temp tasks
rm -f "$HOME/.config/eye/tasks/temp_"*
