#!/bin/bash
# tests/eye/test_group_cmd.sh
EYE="./bin/eye"
TASKS_DIR="$HOME/.config/eye/tasks"

# Setup
rm -rf "$HOME/.config/eye/tasks"
mkdir -p "$HOME/.config/eye/tasks"

# Create a task
$EYE add test_task -g old_group -i 1h

# 1. Test moving to a new group
$EYE group test_task new_group
source "$TASKS_DIR/test_task"
[ "$EYE_T_GROUP" == "new_group" ] || { echo "FAIL: Moving to new group"; exit 1; }

# 2. Test removing group (setting to none)
$EYE group test_task none
source "$TASKS_DIR/test_task"
[ "$EYE_T_GROUP" == "default" ] || { echo "FAIL: Setting group to none"; exit 1; }

# 3. Test removing group (setting to default)
$EYE group test_task office
$EYE group test_task default
source "$TASKS_DIR/test_task"
[ "$EYE_T_GROUP" == "default" ] || { echo "FAIL: Setting group to default"; exit 1; }

# 4. Test removing group (omitting argument)
$EYE group test_task health
$EYE group test_task
source "$TASKS_DIR/test_task"
[ "$EYE_T_GROUP" == "default" ] || { echo "FAIL: Omitting group argument"; exit 1; }

# 5. Test Dynamic Lifecycle (Auto-destruction)
$EYE add lifecycle_task -g temp_group -i 1h
# Verify file level metadata
source "$TASKS_DIR/lifecycle_task"
[ "$EYE_T_GROUP" == "temp_group" ] || { echo "FAIL: Group metadata assignment"; exit 1; }

# After moving out, the group should be default
$EYE group lifecycle_task none
source "$TASKS_DIR/lifecycle_task"
[ "$EYE_T_GROUP" == "default" ] || { echo "FAIL: Group auto-destruction check"; exit 1; }
echo "PASS: dynamic lifecycle"

# 6. Test help output
$EYE group help 2>&1 | grep -qE "Usage:|用法:" || { echo "FAIL: Group help output"; exit 1; }

# 6. Test missing task_id
$EYE group 2>&1 | grep -qE "Usage:|用法:" || { echo "FAIL: Group missing task_id output"; exit 1; }

echo "PASS: group command"
rm -rf "$HOME/.config/eye/tasks"
