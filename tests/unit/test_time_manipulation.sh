#!/bin/bash
# tests/unit/test_time_manipulation.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Time Manipulation ==="

setup_daemon
"$BIN_EYE" add time_test -i 60m
"$BIN_EYE" start time_test

# Helper to get numeric NEXT value (seconds)
get_next_sec() {
    local str=$("$TOOL_DIR/get_next" "$1" | tail -n 1 | awk -F"│" '{print $2}' | xargs)
    # _parse_duration is internal to eye, let's use eye's utils by sourcing
    # But wait, we can just approximate from the string "50m" or "3600s"
    # Let's just rely on string output or parsing.
    # The output of tool/get_next is formatted (e.g. "59m 59s").
    # It's easier to check roughly or assume parsing logic.
    # Let's trust tool/get_next output format is consistent.
    echo "$str"
}

# 1. Time Shift Forward (+10m) -> NEXT should reduce
echo "--- Tag: Time Shift Forward (+10m) ---"
"$BIN_EYE" time +10m time_test
NEXT_STR=$(get_next_sec time_test)
echo "Next after +10m: $NEXT_STR"
# Expect ~50m.
if [[ "$NEXT_STR" == *"50m"* ]] || [[ "$NEXT_STR" == *"49m"* ]]; then
    echo "PASS: Time shifted correctly."
else
    echo "FAIL: Expected ~50m, got $NEXT_STR"
    debug_dump_state
    exit 1
fi

# 2. Time Shift Backward (-20m) -> NEXT should increase
echo "--- Tag: Time Shift Backward (-20m) ---"
"$BIN_EYE" time -20m time_test
NEXT_STR=$(get_next_sec time_test)
echo "Next after -20m: $NEXT_STR"
# Previous was ~50m. -(-20m) = +20m to NEXT?
# Wait.
# `time +` means "Add to LAST_RUN"? No, CLI logic:
# `eye time +10m`: _core_task_time_shift calls with +10m.
# core.sh: EYE_T_LAST_RUN = LAST_RUN - delta.
# So if I say "time +10m", I am saying "10m passed". So LAST_RUN becomes older (smaller timestamp).
# So NEXT (Interval - (Now - LastRun)) becomes smaller. Correct.
# `eye time -20m`: LAST_RUN = LAST_RUN - (-20m) = LAST_RUN + 20m.
# So LAST_RUN becomes newer (closer to now).
# So NEXT becomes larger.
# Current state: ~50m.
# Action: -20m.
# New NEXT: ~50m + 20m = ~70m = 1h 10m.
if [[ "$NEXT_STR" == *"1h 10m"* ]] || [[ "$NEXT_STR" == *"1h 9m"* ]]; then
    echo "PASS: Time shifted backward correctly."
else
    echo "FAIL: Expected ~1h 10m, got $NEXT_STR"
    debug_dump_state
    exit 1
fi

# 3. Time Overflow
echo "--- Tag: Time Overflow (+2h) ---"
"$BIN_EYE" time +2h time_test
NEXT_STR=$(get_next_sec time_test)
echo "Next after +2h: $NEXT_STR"
# Should be 0s
if [[ "$NEXT_STR" == "0s" ]]; then
    echo "PASS: Overflow clamped to 0s."
else
    echo "FAIL: Expected 0s, got $NEXT_STR"
    debug_dump_state
    exit 1
fi

echo "=== All Time Manipulation Tests Passed ==="
exit 0
