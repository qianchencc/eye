#!/bin/bash
# tests/unit/test_daemon_states.sh

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../debug_utils.sh"

echo "=== Test: Daemon State Double Testing ==="

# --- 1. Daemon OFF Tests ---
echo ">>> Phase 1: Daemon OFF <<<"
setup_clean

# 1.1 Add
echo "Tag: Add (Daemon OFF)"
"$BIN_EYE" add off_test -i 1h
assert_status off_test stopped || exit 1

# 1.2 Start (Expect Fail)
echo "Tag: Start (Daemon OFF)"
if "$BIN_EYE" start off_test 2>/dev/null; then
    echo "FAIL: Start should fail when daemon is off"
    exit 1
else
    echo "PASS: Start failed as expected"
fi
assert_status off_test stopped || exit 1

# 1.3 Resume (Daemon OFF) -> Should allow state change logic but warn?
# Spec says: "EYE_T_LAST_RUN calculation change... should succeed"
# Current implementation might require daemon check for resume too?
# Let's check cli.sh: _cb_cli_resume calls _core_task_resume.
# It doesn't seem to have explicit check for daemon like _cb_cli_start.
echo "Tag: Resume (Daemon OFF)"
# Manually set to paused to test resume
"$BIN_EYE" stop off_test >/dev/null 2>&1 # This sets it to paused
assert_status off_test paused || exit 1

"$BIN_EYE" resume off_test
assert_status off_test running || exit 1
# Note: It runs "logically" (state=running), but won't trigger without daemon.

# --- 2. Daemon ON Tests ---
echo ">>> Phase 2: Daemon ON <<<"
setup_daemon

# 2.1 Add
echo "Tag: Add (Daemon ON)"
"$BIN_EYE" add on_test -i 1h
assert_status on_test stopped || exit 1

# 2.2 Start
echo "Tag: Start (Daemon ON)"
"$BIN_EYE" start on_test
assert_status on_test running || exit 1

# 2.3 Stop
echo "Tag: Stop (Daemon ON)"
"$BIN_EYE" stop on_test
assert_status on_test paused || exit 1

echo "=== All Daemon State Tests Passed ==="
exit 0
