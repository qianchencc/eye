#!/bin/bash

# ==============================================================================
# tests/debug_utils.sh
# 
# Description:
#   Helper functions for unit tests to print debug information upon failure.
# ==============================================================================

# Colors
_C_RESET='\033[0m'
_C_RED='\033[31m'
_C_GREEN='\033[32m'
_C_YELLOW='\033[33m'
_C_BOLD='\033[1m'

# Resolve paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
STATE_DIR="$HOME/.local/state/eye"
CONFIG_DIR="$HOME/.config/eye"
TOOL_DIR="$PROJECT_ROOT/tool"
BIN_EYE="$PROJECT_ROOT/bin/eye"

# Debug Dump Function
debug_dump_state() {
    echo -e "${_C_YELLOW}========= DEBUG DUMP STATE =========${_C_RESET}"
    echo -e "${_C_BOLD}1. Task Files Content ($CONFIG_DIR/tasks/):${_C_RESET}"
    if [ -d "$CONFIG_DIR/tasks" ]; then
        for f in "$CONFIG_DIR/tasks"/*; do
            [ -e "$f" ] || continue
            echo "--- $(basename "$f") ---"
            cat "$f"
        done
    else
        echo "No tasks directory found."
    fi
    
    echo -e "\n${_C_BOLD}2. PID Files ($STATE_DIR/pids/):${_C_RESET}"
    if [ -d "$STATE_DIR/pids" ]; then
        ls -l "$STATE_DIR/pids/"
    else
        echo "No pids directory found."
    fi
    
    echo -e "\n${_C_BOLD}3. Daemon Log (Last 20 lines):${_C_RESET}"
    if [ -f "$STATE_DIR/history.log" ]; then
        tail -n 20 "$STATE_DIR/history.log"
    else
        echo "No history.log found."
    fi
    echo -e "${_C_YELLOW}====================================${_C_RESET}"
}

# Assert Status Helper
assert_status() {
    local task_id="$1"
    local expected="$2"
    
    if "$TOOL_DIR/assert_var" "$task_id" STATUS "$expected" >/dev/null; then
        echo -e "${_C_GREEN}[PASS]${_C_RESET} Task '$task_id' is $expected"
        return 0
    else
        echo -e "${_C_RED}[FAIL]${_C_RESET} Task '$task_id' is NOT $expected"
        # Get actual for message
        local actual=$("$PROJECT_ROOT/bin/eye" status "$task_id" | grep "EYE_T_STATUS" | cut -d'=' -f2 | tr -d '"')
        echo "       Actual: $actual"
        debug_dump_state
        return 1
    fi
}

# Assert Generic Variable
assert_val() {
    local task_id="$1"
    local var_suffix="$2"
    local expected="$3"

    if "$TOOL_DIR/assert_var" "$task_id" "$var_suffix" "$expected" >/dev/null; then
        echo -e "${_C_GREEN}[PASS]${_C_RESET} Task '$task_id' $var_suffix == $expected"
        return 0
    else
        echo -e "${_C_RED}[FAIL]${_C_RESET} Task '$task_id' $var_suffix != $expected"
        debug_dump_state
        return 1
    fi
}

# Setup: Ensure clean state
setup_clean() {
    echo "--- Setup: Cleaning environment ---"
    "$BIN_EYE" daemon down >/dev/null 2>&1
    rm -rf "$CONFIG_DIR/tasks"
    mkdir -p "$CONFIG_DIR/tasks"
    # Ensure daemon is stopped completely
    sleep 1
}

# Setup: Clean and Start Daemon
setup_daemon() {
    setup_clean
    echo "--- Setup: Starting Daemon ---"
    "$BIN_EYE" daemon up
    # Wait for daemon to initialize
    sleep 1
    if ! pgrep -f "eye daemon" >/dev/null; then
        echo "Error: Daemon failed to start."
        exit 1
    fi
}
