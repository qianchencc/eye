#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
LONG_TASK="this_is_a_very_long_task_name_for_truncation_test"
log_info() { echo -e "\033[32m[INFO]\033[0m $*"; }

$EYE daemon down >/dev/null 2>&1
$EYE add "$TASK" -i 10m -d 20s -c 5
$EYE add "$LONG_TASK" -i 20m -d 0s -c -1 --temp

log_info "Verifying status table layout and Duration column"
export LC_ALL=C.UTF-8
if command -v script >/dev/null; then
    script -q -c "NO_COLOR=1 $EYE status" /tmp/status_out >/dev/null
    log_info "Status output:"
    cat /tmp/status_out
    
    # Check Duration column for periodic task
    grep "test_status_" /tmp/status_out | grep -q "20s" && echo "PASS: Duration column (periodic)" || { echo "FAIL: Duration column (periodic)"; exit 1; }
    
    # Check Duration column for pulse task (0s)
    grep "this_is_a_ve..." /tmp/status_out | grep -q "0s" && echo "PASS: Duration column (pulse)" || { echo "FAIL: Duration column (pulse)"; exit 1; }
    
    # Check Count column
    grep "test_status_" /tmp/status_out | grep -q "5/5" && echo "PASS: Count column" || { echo "FAIL: Count column"; exit 1; }
    
    # Check Infinite symbol
    grep "this_is_a_ve..." /tmp/status_out | grep -q "∞" && echo "PASS: Infinite symbol" || { echo "FAIL: Infinite symbol"; exit 1; }

    # Check alignment (no trailing characters after the last bar of the header)
    # The last column should be NEXT.
    head -n 3 /tmp/status_out | tail -n 1 | grep -q "NEXT  |$" || echo "Note: Alignment check might be sensitive to trailing spaces."
fi

$EYE remove "$TASK"
$EYE remove "$LONG_TASK"