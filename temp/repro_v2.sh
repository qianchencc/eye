#!/bin/bash
# temp/repro_v2.sh
export PATH=$HOME/.local/bin:$PATH

echo "=== Setup ==="
eye daemon down >/dev/null 2>&1
rm -rf ~/.config/eye/tasks/*
mkdir -p ~/.config/eye/tasks

echo "=== Problem 1 & 2: New Task Behavior ==="
# Should default to stopped. NEXT should be interval.
eye add test1 -i 10s -d 2s
echo "Status of test1 (should be stopped):"
eye status test1 | grep "EYE_T_STATUS"
echo "NEXT of test1 (should be 10s):"
eye status test1 | grep "NEXT" || eye status -l | grep "test1"

echo "=== Problem 1: Start without Daemon ==="
eye start test1

echo "=== Problem 3: Conflict Tasks Looping ==="
eye daemon up
sleep 1
# Create 3 conflict tasks
eye add temp1 -i 10s -d 3s
eye add temp2 -i 10s -d 4s
eye add temp3 -i 10s -d 2s

# Start them (Daemon is up now)
eye start temp1
eye start temp2
eye start temp3

echo "=== Watching Logs for 60s ==="
# We expect to see multiple TRIGGERED/COMPLETED events for each task
timeout 60s tail -f ~/.local/state/eye/history.log &
LOG_PID=$!

sleep 60
kill $LOG_PID

echo "=== Final Task States ==="
for f in ~/.config/eye/tasks/temp*; do
    echo "--- $f ---"
    cat "$f"
done

echo "=== Final Status ==="
eye status -l

echo "=== Cleanup ==="
eye daemon down
