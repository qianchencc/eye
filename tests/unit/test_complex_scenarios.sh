#!/bin/bash
# tests/unit/test_complex_scenarios.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Complex Scenarios (Procrastination Workflow) ==="

setup_daemon
"$BIN_EYE" add work -i 60m
# 1. Start
"$BIN_EYE" start work
assert_status work running || exit 1

# 2. Delay (User cheats: says -20m passed, so logic: LAST_RUN becomes newer, NEXT increases)
# Wait, "run 50 mins then cheat to say only 30 passed".
# Real time passed: 0 (simulation).
# I want to simulate: "I want to delay the next trigger by 20 mins".
# `eye time -20m` -> LAST_RUN += 20m. NEXT += 20m.
"$BIN_EYE" time -20m work
NEXT=$("$TOOL_DIR/get_next" work | tail -n 1 | awk -F"│" '{print $2}' | xargs)
echo "Next after delay: $NEXT"
# Should be ~ 1h 20m
if [[ "$NEXT" != *"1h 20m"* ]] && [[ "$NEXT" != *"1h 19m"* ]]; then
    echo "FAIL: Delay logic incorrect. Got $NEXT"
    debug_dump_state
    exit 1
fi

# 3. Pause
"$BIN_EYE" stop work
assert_status work paused || exit 1

# 4. Wait (Simulated by sleeping 2s)
sleep 2

# 5. Resume
"$BIN_EYE" resume work
assert_status work running || exit 1
# NEXT should be same as before pause (approx), NOT reduced by sleep time.
# The `eye` logic handles pause compensation.
NEXT_RESUME=$("$TOOL_DIR/get_next" work | tail -n 1 | awk -F"│" '{print $2}' | xargs)
echo "Next after resume: $NEXT_RESUME"
if [[ "$NEXT_RESUME" != *"1h 20m"* ]] && [[ "$NEXT_RESUME" != *"1h 19m"* ]]; then
     echo "FAIL: Resume compensation incorrect. Got $NEXT_RESUME"
     debug_dump_state
     exit 1
fi

# 6. Skip (Force finish)
"$BIN_EYE" now work
sleep 2
# Should be back to 1h
NEXT_SKIP=$("$TOOL_DIR/get_next" work | tail -n 1 | awk -F"│" '{print $2}' | xargs)
echo "Next after skip: $NEXT_SKIP"
if [[ "$NEXT_SKIP" == *"59m"* ]] || [[ "$NEXT_SKIP" == *"1h"* ]]; then
    echo "PASS: Cycle reset correctly."
else
    echo "FAIL: Cycle not reset. Got $NEXT_SKIP"
    exit 1
fi

echo "=== All Complex Scenarios Passed ==="
exit 0
