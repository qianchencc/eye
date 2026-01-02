#!/bin/bash
# tests/eye/test_now.sh
EYE="./bin/eye"
TASK="test_now_$(date +%s)"
$EYE add "$TASK" -i 1h -d 2s

# Mock notify-send to verify call
MOCK_LOG="/tmp/notify_mock.log"
rm -f "$MOCK_LOG"
mkdir -p /tmp/mock_bin
cat > /tmp/mock_bin/notify-send <<EOF
#!/bin/bash
echo "NOTIFY: \$*" >> $MOCK_LOG
EOF
chmod +x /tmp/mock_bin/notify-send

# Run with mocked path
PATH="/tmp/mock_bin:$PATH" $EYE now "$TASK"
# Now is backgrounded, wait a bit
sleep 1

if grep -q "$TASK" "$MOCK_LOG"; then
    echo "PASS: now triggered notification"
else
    echo "FAIL: now did not trigger notification"
    echo "Actual Mock Log:"
    [ -f "$MOCK_LOG" ] && cat "$MOCK_LOG"
    exit 1
fi

rm -f "$HOME/.config/eye/tasks/$TASK"
rm -rf /tmp/mock_bin "$MOCK_LOG"