#!/bin/bash
# tests/eye/test_group_regex.sh
EYE="./bin/eye"
TASKS_DIR="$HOME/.config/eye/tasks"

# Setup
rm -rf "$HOME/.config/eye/tasks"
mkdir -p "$HOME/.config/eye/tasks"

# Create tasks in different groups
$EYE add task_w1 -g work_personal -i 1h
$EYE add task_w2 -g work_office -i 1h
$EYE add task_h1 -g health -i 1h

# 1. Test exact match (regression)
$EYE stop @health
source "$TASKS_DIR/task_h1"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Exact group match"; exit 1; }
source "$TASKS_DIR/task_w1"
[ "$EYE_T_STATUS" == "stopped" ] || { echo "FAIL: Side effect in exact match"; exit 1; }

# 2. Test regex match (prefix)
$EYE stop "@work_.*"
source "$TASKS_DIR/task_w1"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Regex group match (task_w1)"; exit 1; }
source "$TASKS_DIR/task_w2"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Regex group match (task_w2)"; exit 1; }

# 3. Test regex match (complex)
$EYE start "@.*office"
source "$TASKS_DIR/task_w2"
[ "$EYE_T_STATUS" == "running" ] || { echo "FAIL: Complex regex match (task_w2)"; exit 1; }
source "$TASKS_DIR/task_w1"
[ "$EYE_T_STATUS" == "paused" ] || { echo "FAIL: Complex regex match side effect (task_w1)"; exit 1; }

echo "PASS: group regex support"
rm -rf "$HOME/.config/eye/tasks"
