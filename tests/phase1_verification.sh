#!/bin/bash

# Setup environment
TEST_DIR=$(mktemp -d)
TASKS_DIR="$TEST_DIR/tasks"
mkdir -p "$TASKS_DIR"

# Mock constants/variables expected by io.sh
DEFAULT_SOUND_START="bell"
DEFAULT_SOUND_END="gong"

# Source the library
# We need to find where we are
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
source "$PROJECT_ROOT/lib/io.sh"

echo "=== Test 1: Load Task with Defaults ==="
# Create a partial task file
echo 'NAME="partial_task"' > "$TASKS_DIR/test_task"

# Load it
_load_task "test_task"

# Check defaults
FAILED=0
if [ "$GROUP" != "default" ]; then echo "FAIL: GROUP default not set"; FAILED=1; fi
if [ "$INTERVAL" != "1200" ]; then echo "FAIL: INTERVAL default not set"; FAILED=1; fi
if [ "$SOUND_START" != "bell" ]; then echo "FAIL: SOUND_START default not set"; FAILED=1; fi

if [ $FAILED -eq 0 ]; then
    echo "PASS: Defaults loaded correctly."
else
    echo "FAIL: Defaults loading failed."
    exit 1
fi

echo "=== Test 2: Atomic Write Concurrency ==="
TARGET_FILE="$TEST_DIR/atomic_target"
COUNT=100

# Function to write concurrently
write_worker() {
    local i=$1
    _atomic_write "$TARGET_FILE" "WRITE_CONTENT_$i"
}

# Launch workers
for i in $(seq 1 $COUNT); do
    write_worker $i &
done

# Wait for all
wait

# Check result
if [ ! -f "$TARGET_FILE" ]; then
    echo "FAIL: Target file missing."
    exit 1
fi

CONTENT=$(cat "$TARGET_FILE")
if [[ "$CONTENT" =~ ^WRITE_CONTENT_[0-9]+$ ]]; then
    echo "PASS: File content is valid: $CONTENT"
else
    echo "FAIL: File content corrupted or invalid: '$CONTENT'"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"
echo "All Phase 1 tests passed."
exit 0
