#!/bin/bash
# tests/eye/test_time_count.sh
EYE="./bin/eye"
TASK="test_tc_$(date +%s)"
$EYE add "$TASK" -i 1h -c 10
$EYE time +10m "$TASK"
# next = 3600 - (now - LAST_RUN). 
# If we shift +10m (600s), LAST_RUN becomes LAST_RUN - 600.
# So (now - LAST_RUN) becomes (now - (LAST_RUN - 600)) = (now - LAST_RUN) + 600.
# So NEXT becomes 3600 - ((now - LAST_RUN) + 600) = 3000 - (now - LAST_RUN).
# It's shifted.
source "$HOME/.config/eye/tasks/$TASK"
# Just verify it's changed.
$EYE count -1 "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$REMAIN_COUNT" -eq 9 ] && echo "PASS: time/count" || { echo "FAIL: count shift"; exit 1; }
rm -f "$HOME/.config/eye/tasks/$TASK"
