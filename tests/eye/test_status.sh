#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

$EYE daemon down >/dev/null 2>&1
$EYE add "$TASK" -i 10m -d 5s -c 3 -g test_group

log_info "Testing Default Compact Status"
script -q -c "NO_COLOR=1 $EYE status" /tmp/compact_stat >/dev/null
grep "$TASK" /tmp/compact_stat | grep -q "Running" && echo "PASS: Compact status" || { echo "FAIL: Compact status"; cat /tmp/compact_stat; exit 1; }

log_info "Testing Long Status (-l)"
script -q -c "NO_COLOR=1 $EYE status -l" /tmp/long_stat >/dev/null
grep -q "test_group" /tmp/long_stat && echo "PASS: Long status" || { echo "FAIL: Long status"; cat /tmp/long_stat; exit 1; }

log_info "Testing static NEXT time after daemon down"
$EYE daemon down >/dev/null 2>&1
script -q -c "NO_COLOR=1 $EYE status" /tmp/stat1 >/dev/null
stat1=$(grep "$TASK" /tmp/stat1)
sleep 2
script -q -c "NO_COLOR=1 $EYE status" /tmp/stat2 >/dev/null
stat2=$(grep "$TASK" /tmp/stat2)
if [ "$stat1" == "$stat2" ]; then
    echo "PASS: Static NEXT time"
else
    echo "FAIL: NEXT time is flowing while daemon is off"
    echo "1: $stat1"
    echo "2: $stat2"
    exit 1
fi

$EYE remove "$TASK"
