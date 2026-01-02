#!/bin/bash

# ==========================================
# Phase 1 & 2 Comprehensive Test Suite
# ==========================================

TEST_ROOT=$(mktemp -d)
TASKS_DIR="$TEST_ROOT/tasks"
STATE_DIR="$TEST_ROOT/state"
HISTORY_LOG="$STATE_DIR/history.log"
BREAK_LOCK_FILE="$TEST_ROOT/eye_focus.lock"
TEST_LOG="$TEST_ROOT/test_actions.log"

mkdir -p "$TASKS_DIR" "$STATE_DIR"

# --- Mocks ---
# Mock notify-send to log output
notify-send() {
    echo "NOTIFY: $*" >> "$TEST_LOG"
}

# Mock internal play function (since we don't have audio hardware)
_play() {
    echo "PLAY: $*" >> "$TEST_LOG"
}

# Mock format duration (usually in utils.sh, simplified here)
_format_duration() {
    echo "$1s"
}

# Mock global config loader
_load_global_config() {
    :
}

# --- Load Libraries ---
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."

# Source required libs
source "$PROJECT_ROOT/lib/constants.sh"
source "$PROJECT_ROOT/lib/i18n.sh"
source "$PROJECT_ROOT/lib/io.sh"
source "$PROJECT_ROOT/lib/daemon.sh"

# Init i18n vars
_init_messages

echo "=== Test Environment Setup at $TEST_ROOT ==="

# ==========================================
# Test Case 1: Pulse Task (Duration=0)
# ==========================================
echo ">>> Running Test Case 1: Pulse Task"
TASK_ID="pulse_test"
cat > "$TASKS_DIR/$TASK_ID" <<EOF
NAME="Pulse Task"
INTERVAL=10
DURATION=0
REMAIN_COUNT=5
TARGET_COUNT=5
STATUS="running"
SOUND_ENABLE="true"
SOUND_START="bell"
EOF

# Manually trigger execution
_execute_task "$TASK_ID"

# Verification
# 1. Check Log (Flexible grep to handle notify-send flags)
if grep -q "NOTIFY:.*Pulse Task" "$TEST_LOG" && grep -q "PLAY: bell" "$TEST_LOG"; then
    echo "  [PASS] Notification and Sound triggered."
else
    echo "  [FAIL] Missing notification or sound log."
    cat "$TEST_LOG"
    exit 1
fi

# 2. Check Data Update
_load_task "$TASK_ID"
if [ "$REMAIN_COUNT" -eq 4 ]; then
    echo "  [PASS] REMAIN_COUNT decremented to 4."
else
    echo "  [FAIL] REMAIN_COUNT is $REMAIN_COUNT (expected 4)."
    exit 1
fi

if [ "$LAST_RUN" -gt 0 ]; then
    echo "  [PASS] LAST_RUN updated."
else
    echo "  [FAIL] LAST_RUN not updated."
    exit 1
fi

# ==========================================
# Test Case 2: Periodic Task & Locking
# ==========================================
echo ">>> Running Test Case 2: Periodic Task (Locking)"
TASK_ID="periodic_test"
cat > "$TASKS_DIR/$TASK_ID" <<EOF
NAME="Periodic Task"
INTERVAL=10
DURATION=2
STATUS="running"
SOUND_ENABLE="true"
SOUND_START="start"
SOUND_END="end"
EOF

# Reset log
echo "" > "$TEST_LOG"

# Run in background to simulate daemon
_execute_task "$TASK_ID" &
BG_PID=$!

# Wait a bit for it to start and grab lock
sleep 0.5

# Check Lock
if [ -f "$BREAK_LOCK_FILE" ]; then
    LOCKED_BY=$(cat "$BREAK_LOCK_FILE")
    if [ "$LOCKED_BY" == "$TASK_ID" ]; then
        echo "  [PASS] Lock acquired by $TASK_ID."
    else
        echo "  [FAIL] Lock file content mismatch: $LOCKED_BY"
        exit 1
    fi
else
    echo "  [FAIL] Lock file not found."
    exit 1
fi

# Wait for task to finish (Duration 2s)
wait $BG_PID

# Check Lock Release
if [ ! -f "$BREAK_LOCK_FILE" ]; then
    echo "  [PASS] Lock released."
else
    echo "  [FAIL] Lock file still exists."
    exit 1
fi

# Check Logs (Start and End)
if grep -q "PLAY: start" "$TEST_LOG" && grep -q "PLAY: end" "$TEST_LOG"; then
    echo "  [PASS] Start and End sounds played."
else
    echo "  [FAIL] Missing start/end sounds."
    cat "$TEST_LOG"
    exit 1
fi

# ==========================================
# Test Case 3: Lifecycle (Temp Task Deletion)
# ==========================================
echo ">>> Running Test Case 3: Temp Task Deletion"
TASK_ID="temp_task"
cat > "$TASKS_DIR/$TASK_ID" <<EOF
NAME="Temp Task"
INTERVAL=10
DURATION=0
TARGET_COUNT=1
REMAIN_COUNT=1
IS_TEMP="true"
STATUS="running"
EOF

_execute_task "$TASK_ID"

if [ ! -f "$TASKS_DIR/$TASK_ID" ]; then
    echo "  [PASS] Temp task file deleted."
else
    echo "  [FAIL] Temp task file still exists."
    exit 1
fi

# ==========================================
# Test Case 4: Lock Contention
# ==========================================
echo ">>> Running Test Case 4: Lock Contention"
TASK_A="task_a"
TASK_B="task_b"

# Setup Task A (Long running)
cat > "$TASKS_DIR/$TASK_A" <<EOF
NAME="Task A"
INTERVAL=10
DURATION=3
STATUS="running"
EOF

# Setup Task B (Short running, tries to run during A)
cat > "$TASKS_DIR/$TASK_B" <<EOF
NAME="Task B"
INTERVAL=10
DURATION=1
STATUS="running"
EOF

# Reset Log
echo "" > "$TEST_LOG"

# Start A
_execute_task "$TASK_A" &
PID_A=$!

sleep 0.5

# Verify A has lock
if [ ! -f "$BREAK_LOCK_FILE" ]; then
    echo "  [FAIL] Task A failed to acquire lock."
    exit 1
fi

# Try to start B
echo "Attempting to start Task B (should fail to lock)..."
_execute_task "$TASK_B"

# Verify B did NOT run full cycle (check logs)
# Since B fails lock, it should NOT play sound or log "COMPLETED" (if we checked history)
# Based on current logic: "if _try_lock... else return"
# So B should just return.

# We can check that B's LAST_RUN was NOT updated? 
# Actually _execute_task loads the task. If it returns early, it doesn't save.
# So load B and check LAST_RUN is 0 (assuming default was 0 or unset)

_load_task "$TASK_B"
if [ "$LAST_RUN" == "0" ] || [ -z "$LAST_RUN" ]; then
    echo "  [PASS] Task B did not update LAST_RUN (Lock contention worked)."
else
    echo "  [FAIL] Task B updated LAST_RUN ($LAST_RUN), meaning it bypassed the lock!"
    exit 1
fi

wait $PID_A

echo "=== All Comprehensive Tests Passed ==="
rm -rf "$TEST_ROOT"
exit 0
