#!/bin/bash

# ================= Logger System (lib/logger.sh) =================
# Provides structured, leveled logging for the Eye daemon and CLI.

# Log Levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_SYSTEM=4 # Special level for critical system events

# Current Log Level (Set to DEBUG for troubleshooting)
CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG

# Colors for log file (optional, readable with less -R)
_LOG_C_RESET='\033[0m'
_LOG_C_DEBUG='\033[34m' # Blue
_LOG_C_INFO='\033[32m'  # Green
_LOG_C_WARN='\033[33m'  # Yellow
_LOG_C_ERROR='\033[31m' # Red
_LOG_C_SYS='\033[35m'   # Magenta

_init_logger() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$HISTORY_LOG")"
    
    # Simple Rotation: If log file > 5MB, rotate
    if [ -f "$HISTORY_LOG" ]; then
        local size=$(stat -c%s "$HISTORY_LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt 5242880 ]; then
            mv "$HISTORY_LOG" "$HISTORY_LOG.old"
            _log_system "Logger" "Log rotated (size > 5MB)"
        fi
    fi
}

_log_write() {
    local level_name="$1"
    local color="$2"
    local component="$3"
    local msg="$4"
    
    # Timestamp: YYYY-MM-DD HH:MM:SS
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format: [Timestamp] [PID] [Level] [Component] Message
    # Use BASHPID to show actual subshell PID
    echo -e "${color}[$ts] [$BASHPID] [$level_name] [$component] $msg${_LOG_C_RESET}" >> "$HISTORY_LOG"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && _log_write "DEBUG" "$_LOG_C_DEBUG" "$1" "$2"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && _log_write "INFO" "$_LOG_C_INFO" "$1" "$2"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && _log_write "WARN" "$_LOG_C_WARN" "$1" "$2"
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && _log_write "ERROR" "$_LOG_C_ERROR" "$1" "$2"
}

log_system() {
    _log_write "SYSTEM" "$_LOG_C_SYS" "$1" "$2"
}

# Specialized event loggers
log_sched() {
    log_debug "SCHED" "Task $1: $2"
}

log_lock() {
    # Usage: log_lock <TaskID> <Action> <Details>
    # Action: ACQUIRE, RELEASE, WAIT, FAIL
    _log_write "LOCK" "$_LOG_C_WARN" "$1" "$2: $3"
}

log_task() {
    # Usage: log_task <TaskID> <State>
    _log_write "TASK" "$_LOG_C_INFO" "$1" "$2"
}
