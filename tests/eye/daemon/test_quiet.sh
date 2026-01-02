#!/bin/bash
# tests/eye/daemon/test_quiet.sh
EYE="./bin/eye"
$EYE daemon quiet on
grep -q "GLOBAL_QUIET=on" "$HOME/.config/eye/eye.conf" && echo "PASS: daemon quiet on" || { echo "FAIL: quiet config save"; exit 1; }
# Test stderr silence
err_out=$($EYE add quiet_test -i 10m 2>&1 >/dev/null)
[ -z "$err_out" ] && echo "PASS: stderr silenced" || { echo "FAIL: stderr not empty in quiet mode"; exit 1; }
$EYE daemon quiet off
rm -f "$HOME/.config/eye/tasks/quiet_test"
