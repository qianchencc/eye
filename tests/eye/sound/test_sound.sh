#!/bin/bash
# tests/eye/sound/test_sound.sh
EYE="./bin/eye"
# Global off
$EYE sound off
grep -q "SOUND_GLOBAL_OVERRIDE=off" "$HOME/.config/eye/eye.conf" && echo "PASS: sound global off" || { echo "FAIL: sound global off"; exit 1; }
# Global on
$EYE sound on
grep -q "SOUND_GLOBAL_OVERRIDE=on" "$HOME/.config/eye/eye.conf" && echo "PASS: sound global on" || { echo "FAIL: sound global on"; exit 1; }

# Task sound toggle
TASK="test_sound_$(date +%s)"
$EYE add "$TASK" -i 10m
$EYE sound off "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$SOUND_ENABLE" == "false" ] || { echo "FAIL: task sound off"; exit 1; }

$EYE sound on "$TASK"
source "$HOME/.config/eye/tasks/$TASK"
[ "$SOUND_ENABLE" == "true" ] || { echo "FAIL: task sound on"; exit 1; }
echo "PASS: task sound toggle"

# Custom sound
DUMMY_SOUND="/tmp/dummy.oga"
touch "$DUMMY_SOUND"
$EYE sound add mytag "$DUMMY_SOUND"
grep -q "mytag" "$HOME/.config/eye/custom_sounds.map" && echo "PASS: sound add" || { echo "FAIL: sound add"; exit 1; }
$EYE sound rm mytag
grep -q "mytag" "$HOME/.config/eye/custom_sounds.map" && { echo "FAIL: sound rm"; exit 1; } || echo "PASS: sound rm"

rm -f "$HOME/.config/eye/tasks/$TASK"
rm -f "$DUMMY_SOUND"