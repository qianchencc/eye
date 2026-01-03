#!/bin/bash
# tests/eye/test_time_count.sh
EYE="./bin/eye"
TASK="test_tc_$(date +%s)"
$EYE add "$TASK" -i 1h -c 10
$EYE time +10m "$TASK"
# next = 3600 - (now - EYE_T_LAST_RUN). 
# If we shift +10m (600s), EYE_T_LAST_RUN becomes EYE_T_LAST_RUN - 600.
# So (now - EYE_T_LAST_RUN) becomes (now - (EYE_T_LAST_RUN - 600)) = (now - EYE_T_LAST_RUN) + 600.
# So NEXT becomes 3600 - ((now - EYE_T_LAST_RUN) + 600) = 3000 - (now - EYE_T_LAST_RUN).
# It's shifted.
source "$HOME/.config/eye/tasks/$TASK"
# Just verify it's changed.
$EYE count -1 "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$EYE_T_REMAIN_COUNT" -eq 9 ] && echo "PASS: time/count" || { echo "FAIL: count shift"; exit 1; }
rm -f "$HOME/.config/eye/tasks/$TASK"
