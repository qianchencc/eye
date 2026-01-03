#!/bin/bash
# tests/eye/test_daemon_up.sh
EYE="./bin/eye"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

# 1. Ensure daemon is off initially
$EYE daemon down >/dev/null 2>&1
log_info "Initial check: Daemon should be inactive"
script -q -c "NO_COLOR=1 $EYE status" /tmp/init_stat >/dev/null
grep -q "Daemon: Inactive" /tmp/init_stat && echo "PASS: Initial inactive" || { echo "FAIL: Daemon started unexpectedly"; cat /tmp/init_stat; exit 1; }

# 2. Start daemon manually
log_info "Starting daemon manually: eye daemon up"
$EYE daemon up
sleep 1

# 3. Verify daemon is active
log_info "Verifying daemon status"
RETRIES=5
SUCCESS=0
while [ $RETRIES -gt 0 ]; do
    script -q -c "NO_COLOR=1 $EYE status" /tmp/active_stat >/dev/null
    if grep -q "Daemon: Active" /tmp/active_stat; then
        echo "PASS: Daemon started manually"
        SUCCESS=1
        break
    fi
    sleep 1
    RETRIES=$((RETRIES - 1))
done

if [ $SUCCESS -eq 0 ]; then
    echo "FAIL: Daemon failed to start"
    cat /tmp/active_stat
    exit 1
fi

# 4. Stop daemon
log_info "Stopping daemon"
$EYE daemon down
sleep 2
script -q -c "NO_COLOR=1 $EYE status" /tmp/stop_stat >/dev/null
grep -q "Daemon: Inactive" /tmp/stop_stat && echo "PASS: Daemon stopped" || { echo "FAIL: Daemon failed to stop"; cat /tmp/stop_stat; exit 1; }
