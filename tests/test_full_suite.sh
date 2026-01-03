#!/bin/bash
# tests/test_full_suite.sh (Updated wrapper with timeout)

echo "=== Running Full Test Suite ==="

# Ensure clean state
./bin/eye daemon down >/dev/null 2>&1
sleep 1
./bin/eye daemon up >/dev/null 2>&1
sleep 1

FAILED=0

# Run all tests in tests/eye/
for test_script in tests/eye/*.sh; do
    echo "Running $(basename "$test_script")..."
    
    # Ensure daemon is running before each test
    PID_FILE="$HOME/.local/state/eye/daemon.pid"
    if [[ ! -f "$PID_FILE" ]] || ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
         ./bin/eye daemon up >/dev/null 2>&1
         sleep 1
    fi
    
    # Use timeout 20s to prevent hanging
    if timeout 20s bash "$test_script"; then
        echo "✅ PASS: $(basename "$test_script")"
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "❌ FAIL: $(basename "$test_script") (TIMEOUT)"
        else
            echo "❌ FAIL: $(basename "$test_script") (Exit Code: $EXIT_CODE)"
        fi
        FAILED=1
    fi
    echo "-----------------------------------"
done

# Cleanup
./bin/eye daemon down >/dev/null 2>&1
rm -f ~/.local/state/eye/history.log
rm -rf ~/.local/state/eye/pids

if [ $FAILED -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "🔥 Some tests failed."
    exit 1
fi
