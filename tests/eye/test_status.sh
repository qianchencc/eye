#!/bin/bash
# tests/eye/test_status.sh
EYE="./bin/eye"
TASK="test_status_$(date +%s)"
$EYE add "$TASK" -i 10m

# Create a temp file to capture output while preserving -t behavior if possible, 
# or just force it to think it's a TTY if we can, but simpler to just 
# check for the machine-readable output if grep fails.
# Actually, the logic in lib/cli.sh is: if [ ! -t 1 ]; then echo daemon_running=...; return; fi

# Let's test the machine readable output too.
NO_COLOR=1 $EYE status | grep -q "daemon_running=false" && echo "PASS: machine status" || { echo "FAIL: machine status"; exit 1; }

# To test the table, we need to bypass the [ ! -t 1 ] check.
# We can't easily do that without modifying the code, 
# UNLESS we use 'script' or similar to fake a TTY.
if command -v script >/dev/null; then
    script -q -c "NO_COLOR=1 $EYE status" /tmp/eye_status_out >/dev/null
    grep -q "$TASK" /tmp/eye_status_out && echo "PASS: status table" || { echo "FAIL: status table"; cat /tmp/eye_status_out; exit 1; }
else
    # Fallback: if we can't fake TTY, we skip table check but it's not ideal.
    echo "SKIP: status table (script command not found)"
fi

rm -f "$HOME/.config/eye/tasks/$TASK"
