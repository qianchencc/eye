#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

$EYE daemon down >/dev/null 2>&1
$EYE add "$TASK" -i 10m

log_info "Verifying NEXT is (off) when daemon is inactive"
# Use script to capture TTY output
if command -v script >/dev/null; then
    script -q -c "NO_COLOR=1 $EYE status" /tmp/status_off >/dev/null
    log_info "Status output with daemon inactive:"
    cat /tmp/status_off
    grep "$TASK" /tmp/status_off | grep -q "(off)" && echo "PASS: NEXT is (off)" || { echo "FAIL: NEXT is NOT (off)"; exit 1; }
else
    # Fallback for machine readable
    NO_COLOR=1 $EYE status | grep -q "daemon_running=false" && echo "PASS: machine status" || { echo "FAIL: machine status"; exit 1; }
fi

# Now start daemon and check NEXT
log_info "Starting daemon and checking NEXT"
$EYE daemon up >/dev/null 2>&1
sleep 2
script -q -c "NO_COLOR=1 $EYE status" /tmp/status_on >/dev/null
log_info "Status output with daemon active:"
cat /tmp/status_on
grep "$TASK" /tmp/status_on | grep -qv "(off)" && echo "PASS: NEXT is dynamic" || { echo "FAIL: NEXT is still (off)"; exit 1; }

$EYE daemon down >/dev/null 2>&1
rm -f "$HOME/.config/eye/tasks/$TASK"