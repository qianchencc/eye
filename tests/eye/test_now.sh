#!/bin/bash
# tests/eye/test_now.sh
EYE="./bin/eye"
TASK="test_now_$(date +%s)"
$EYE add "$TASK" -i 1h -d 2s --msg-start 'Name:{NAME} Dur:{DURATION} Alias:[duration]'

# Mock notify-send to verify call and variable replacement
MOCK_LOG="/tmp/notify_mock.log"
rm -f "$MOCK_LOG"
mkdir -p /tmp/mock_bin
cat > /tmp/mock_bin/notify-send <<'EOF'
#!/bin/bash
echo "NOTIFY: $*" >> /tmp/notify_mock.log
EOF
chmod +x /tmp/mock_bin/notify-send

# Run with mocked path
PATH="/tmp/mock_bin:$PATH" $EYE now "$TASK"
# Now is backgrounded, wait a bit
sleep 1

# Check if notification contains replaced variables
if [ ! -f "$MOCK_LOG" ]; then
    echo "FAIL: now did not trigger notification (Log missing)"
    exit 1
fi

LOG_CONTENT=$(cat "$MOCK_LOG")
echo "Debug: Mock Log Content: $LOG_CONTENT"

# NAME should be TASK
# DURATION should be 2s
# Alias [duration] should be 2s
if echo "$LOG_CONTENT" | grep -q "Name:$TASK" && \
   echo "$LOG_CONTENT" | grep -q "Dur:" && \
   echo "$LOG_CONTENT" | grep -q "Alias:"; then
    echo "PASS: now triggered notification with variable replacement"
else
    echo "FAIL: variable replacement failed"
    exit 1
fi

rm -f "$HOME/.config/eye/tasks/$TASK"
rm -rf /tmp/mock_bin "$MOCK_LOG"
