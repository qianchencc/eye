#!/bin/bash

# ==========================================
# Phase 3 CLI Test Suite
# ==========================================

TEST_ROOT=$(mktemp -d)
# Override constants to point to test dir
export CONFIG_DIR="$TEST_ROOT/config"
export STATE_DIR="$TEST_ROOT/state"
export TASKS_DIR="$CONFIG_DIR/tasks"
export CONFIG_FILE="$CONFIG_DIR/eye.conf"
export PID_FILE="$STATE_DIR/eye.pid"
export HISTORY_LOG="$STATE_DIR/history.log"

mkdir -p "$TASKS_DIR" "$STATE_DIR"

# Source bin/eye logic indirectly by sourcing libs
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
LIB_DIR="$PROJECT_ROOT/lib"

# Load all libs
source "$LIB_DIR/constants.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/i18n.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/io.sh"
source "$LIB_DIR/sound.sh"
source "$LIB_DIR/daemon.sh"
source "$LIB_DIR/cli.sh"

# Mock notify-send and paplay
notify-send() { :; }
paplay() { :; }
_play() { :; }

echo "=== Test Environment Setup at $TEST_ROOT ==="

# ==========================================
# Test 1: Add and List
# ==========================================
echo ">>> Test 1: Add and List"
_cmd_add "task1" -i 10m -d 20s -g work

if [ -f "$TASKS_DIR/task1" ]; then
    echo "  [PASS] task1 file created."
else
    echo "  [FAIL] task1 file missing."
    exit 1
fi

_load_task "task1"
if [[ "$INTERVAL" == "600" && "$DURATION" == "20" && "$GROUP" == "work" ]]; then
    echo "  [PASS] task1 attributes correct."
else
    echo "  [FAIL] task1 attributes wrong: I=$INTERVAL D=$DURATION G=$GROUP"
    exit 1
fi

# Capture list output
LIST_OUT=$(_cmd_list)
if [[ "$LIST_OUT" == *"task1"* && "$LIST_OUT" == *"work"* ]]; then
    echo "  [PASS] list command output correct."
else
    echo "  [FAIL] list output unexpected: $LIST_OUT"
    exit 1
fi

# ==========================================
# Test 2: Control (Pause/Resume @group)
# ==========================================
echo ">>> Test 2: Control @group"
# Add another work task
_cmd_add "task2" -g work
# Add a non-work task
_cmd_add "task3" -g personal

# Pause all work tasks
_cmd_pause "@work"

# Verify task1 (work) is paused
_load_task "task1"
if [[ "$STATUS" == "paused" ]]; then
    echo "  [PASS] task1 paused."
else
    echo "  [FAIL] task1 status: $STATUS"
    exit 1
fi

# Verify task3 (personal) is still running
_load_task "task3"
if [[ "$STATUS" == "running" ]]; then
    echo "  [PASS] task3 still running."
else
    echo "  [FAIL] task3 status: $STATUS"
    exit 1
fi

# Resume work tasks
_cmd_resume "@work"
_load_task "task1"
if [[ "$STATUS" == "running" ]]; then
    echo "  [PASS] task1 resumed."
else
    echo "  [FAIL] task1 not resumed."
    exit 1
fi

# ==========================================
# Test 3: Temporary Task (In)
# ==========================================
echo ">>> Test 3: 'In' Command"
_cmd_in "5s" "Tea is ready"

# Check if a file was created in tasks dir starting with temp_
TEMP_FILE=$(ls "$TASKS_DIR"/temp_* 2>/dev/null | head -n 1)

if [[ -n "$TEMP_FILE" ]]; then
    echo "  [PASS] Temp task created: $(basename "$TEMP_FILE")"
else
    echo "  [FAIL] No temp task file found."
    exit 1
fi

# ==========================================
# Test 4: Remove
# ==========================================
echo ">>> Test 4: Remove"
_cmd_remove "task1"

if [ ! -f "$TASKS_DIR/task1" ]; then
    echo "  [PASS] task1 removed."
else
    echo "  [FAIL] task1 still exists."
    exit 1
fi

echo "=== All CLI Tests Passed ==="
rm -rf "$TEST_ROOT"
exit 0
