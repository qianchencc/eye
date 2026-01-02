#!/bin/bash
# tests/eye/test_remove.sh
EYE="./bin/eye"
TASK="test_rm_$(date +%s)"
$EYE add "$TASK" -i 10m
$EYE remove "$TASK"
[ ! -f "$HOME/.config/eye/tasks/$TASK" ] && echo "PASS: remove" || { echo "FAIL: task file still exists"; exit 1; }
