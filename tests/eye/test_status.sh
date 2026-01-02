#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
LONG_TASK="this_is_a_very_long_task_name_for_truncation_test"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

$EYE daemon down >/dev/null 2>&1
$EYE add "$TASK" -i 10m -c 5
$EYE add "$LONG_TASK" -i 20m -c -1 --temp

log_info "Verifying NEXT is (off) when daemon is inactive"
if command -v script >/dev/null; then
    script -q -c "NO_COLOR=1 $EYE status" /tmp/status_off >/dev/null
    log_info "Status output:"
    cat /tmp/status_off
    
    # Check Count column for finite task (use partial name due to truncation)
    grep "test_status_" /tmp/status_off | grep -q "5/5" && echo "PASS: Count column (finite)" || { echo "FAIL: Count column (finite)"; exit 1; }
    
    # Check Infinite symbol
    grep "this_is_a_ve..." /tmp/status_off | grep -q "∞" && echo "PASS: Count column (infinite)" || { echo "FAIL: Count column (infinite)"; exit 1; }
    
    # Check Truncation
    grep -q "this_is_a_ve..." /tmp/status_off && echo "PASS: Name truncation" || { echo "FAIL: Name truncation"; exit 1; }
    
    # Check Temp indicator [T]
    grep "this_is_a_ve..." /tmp/status_off | grep -q "\[T\]" && echo "PASS: Temp task indicator" || { echo "FAIL: Temp task indicator"; exit 1; }

    # Check NEXT (off)
    grep "test_status_" /tmp/status_off | grep -q "(off)" && echo "PASS: NEXT is (off)" || { echo "FAIL: NEXT is NOT (off)"; exit 1; }
fi

$EYE remove "$TASK"
$EYE remove "$LONG_TASK"
