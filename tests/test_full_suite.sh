#!/bin/bash

# ==========================================
# Eye CLI Full Suite Test
# ==========================================
# Covers:
# 1. Task Creation (Periodic vs Pulse, Loop vs Infinite, Temp vs Persistent)
# 2. Task Editing
# 3. Quiet Mode (CLI output suppression)
# 4. Language Switching (Output verification)
# ==========================================

EYE_BIN="./bin/eye"
TASKS_DIR="$HOME/.config/eye/tasks"
CONFIG_FILE="$HOME/.config/eye/eye.conf"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Utils ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fail() { log_error "$1"; exit 1; }

setup() {
    rm -rf "$HOME/.config/eye" "$HOME/.local/share/eye"
    mkdir -p "$TASKS_DIR"
    # Ensure daemon is stopped
    $EYE_BIN daemon down >/dev/null 2>&1
}

assert_task_field() {
    local id="$1"
    local field="$2"
    local expected="$3"
    local file="$TASKS_DIR/$id"
    
    if [ ! -f "$file" ]; then fail "Task $id not found"; fi
    
    local val=$(grep "^$field=" "$file" | cut -d'=' -f2 | tr -d '"')
    if [[ "$val" != "$expected" ]]; then
        fail "Task $id: $field expected '$expected', got '$val'"
    fi
}

assert_output_contains() {
    local output="$1"
    local substring="$2"
    if [[ "$output" != *"$substring"* ]]; then
        fail "Output does not contain '$substring'. Got:\n$output"
    fi
}

# ==========================================
# Test Case 1: Periodic Task Creation
# ==========================================
test_periodic_creation() {
    log_info "Testing Periodic Task Creation..."
    
    # Infinite Loop
    $EYE_BIN add periodic_infinite \
        --interval 20m --duration 20s \
        --group work --count -1 \
        --sound-on --sound-start bell --sound-end complete \
        --msg-start "Start Msg" --msg-end "End Msg" || fail "Failed to create periodic_infinite"
        
    assert_task_field periodic_infinite INTERVAL 1200
    assert_task_field periodic_infinite DURATION 20
    assert_task_field periodic_infinite TARGET_COUNT -1
    assert_task_field periodic_infinite SOUND_ENABLE true
    assert_task_field periodic_infinite SOUND_START bell
    assert_task_field periodic_infinite SOUND_END complete
    assert_task_field periodic_infinite MSG_START "Start Msg"
    
    # Finite Loop (Stop)
    $EYE_BIN add periodic_stop \
        --interval 10s --duration 5s \
        --count 3 || fail "Failed to create periodic_stop"
        
    assert_task_field periodic_stop TARGET_COUNT 3
    assert_task_field periodic_stop IS_TEMP false
    
    # Finite Loop (Temp)
    $EYE_BIN add periodic_temp \
        --interval 5s --duration 2s \
        --count 1 --temp || fail "Failed to create periodic_temp"
        
    assert_task_field periodic_temp IS_TEMP true
}

# ==========================================
# Test Case 2: Pulse Task Creation
# ==========================================
test_pulse_creation() {
    log_info "Testing Pulse Task Creation..."
    
    # Pulse (Duration=0)
    $EYE_BIN add pulse_task \
        --interval 30m --duration 0 \
        --sound-on --sound-start alarm \
        --msg-start "Pulse!" || fail "Failed to create pulse_task"
        
    assert_task_field pulse_task DURATION 0
    assert_task_field pulse_task SOUND_START alarm
    # Ensure MSG_END is ignored/empty for pulse? Or just doesn't matter.
}

# ==========================================
# Test Case 3: Editing
# ==========================================
test_editing() {
    log_info "Testing Task Editing..."
    
    $EYE_BIN edit periodic_infinite \
        --interval 1h --duration 1m \
        --sound-off || fail "Failed to edit periodic_infinite"
        
    assert_task_field periodic_infinite INTERVAL 3600
    assert_task_field periodic_infinite DURATION 60
    assert_task_field periodic_infinite SOUND_ENABLE false
}

# ==========================================
# Test Case 4: Quiet Mode
# ==========================================
test_quiet_mode() {
    log_info "Testing Quiet Mode..."
    
    $EYE_BIN daemon quiet on
    local out=$($EYE_BIN list 2>&1)
    # With quiet mode on globally, commands might still output to stdout if they are info?
    # Spec says: "开启后sterr不输出到终端" (After enabling, stderr is not output to terminal).
    # Wait, usually quiet mode suppresses info logs too.
    # Let's check how the implementation handles `msg_info` vs `msg_error`.
    # Current implementation check `QUIET_MODE` arg or `GLOBAL_QUIET` config.
    
    # We expect verify minimal output or no "INFO" logs.
    
    # Let's try a command that usually outputs success message
    $EYE_BIN add quiet_task --interval 10s --duration 1s > /tmp/out.log 2>&1
    if grep -q "✅" /tmp/out.log; then
        fail "Quiet mode failed: Success message printed."
    fi
    
    # Turn off
    $EYE_BIN daemon quiet off
}

# ==========================================
# Test Case 5: Language Switching
# ==========================================
test_language() {
    log_info "Testing Language Switching..."
    
    # Switch to English
    $EYE_BIN daemon language en
    local out_en=$($EYE_BIN list 2>&1)
    assert_output_contains "$out_en" "Task List"
    
    # Switch to Chinese
    $EYE_BIN daemon language zh
    local out_zh=$($EYE_BIN list 2>&1)
    assert_output_contains "$out_zh" "任务列表"
}

# ==========================================
# Main
# ==========================================
setup
test_periodic_creation
test_pulse_creation
test_editing
test_quiet_mode
test_language

echo -e "${GREEN}All Tests Passed!${NC}"
