#!/bin/bash

# ================= Logging & Formatting =================

# Colors
if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
    _C_RESET='\033[0m'
    _C_RED='\033[31m'
    _C_GREEN='\033[32m'
    _C_YELLOW='\033[33m'
    _C_BOLD='\033[1m'
else
    _C_RESET=''
    _C_RED=''
    _C_GREEN=''
    _C_YELLOW=''
    _C_BOLD=''
fi

# Print raw data to stdout (Always print, no silence)
msg_data() {
    echo "$*"
}

msg_error() {
    printf "${_C_RED}%s${_C_RESET}\n" "$*" >&2
}

msg_warn() {
    printf "${_C_YELLOW}%s${_C_RESET}\n" "$*" >&2
}

msg_info() {
    # Silent if QUIET_MODE is set or EYE_MODE is unix or not TTY
    if [ -z "$QUIET_MODE" ] && [ "$EYE_MODE" != "unix" ] && [ -t 1 ]; then
        printf "${_C_BOLD}%s${_C_RESET}\n" "$*"
    fi
}

msg_success() {
    # Silent if QUIET_MODE is set or EYE_MODE is unix or not TTY
    if [ -z "$QUIET_MODE" ] && [ "$EYE_MODE" != "unix" ] && [ -t 1 ]; then
        printf "${_C_GREEN}%s${_C_RESET}\n" "$*"
    fi
}

# ================= Core Functions =================

# Read input from arguments or stdin
_read_input() {
    if [ $# -gt 0 ]; then
        echo "$*"
    elif [ ! -t 0 ]; then
        # Read from stdin
        local input
        input=$(cat)
        # Trim leading and trailing whitespace
        input="${input#"${input%%[![:space:]]*}"}"
        input="${input%"${input##*[![:space:]]}"}"
        echo "$input"
    fi
}

# Time parser (supports 1h 30m 20s)
_parse_duration() {
    local input="$*"
    # Remove all spaces
    input="${input// /}"
    
    # If pure number, default to seconds
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "$input"
        return
    fi

    local total_seconds=0
    
    # Extract days (d)
    if [[ "$input" =~ ([0-9]+)d ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 86400))
    fi
    # Extract hours (h)
    if [[ "$input" =~ ([0-9]+)h ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 3600))
    fi
    # Extract minutes (m)
    if [[ "$input" =~ ([0-9]+)m ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 60))
    fi
    # Extract seconds (s)
    if [[ "$input" =~ ([0-9]+)s ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]}))
    fi

    if [ "$total_seconds" -eq 0 ]; then
        # Check if localized message exists, otherwise generic
        msg_error "${MSG_ERROR_INVALID_TIME_FORMAT:-Error: Invalid time format}"
        return 1
    fi
    
    echo "$total_seconds"
}

# Format seconds to readable string
_format_duration() {
    local T=$1
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))
    
    [[ $D -gt 0 ]] && printf '%dd ' $D
    [[ $H -gt 0 ]] && printf '%dh ' $H
    [[ $M -gt 0 ]] && printf '%dm ' $M
    [[ $D -eq 0 && $H -eq 0 && $M -eq 0 ]] && printf '%ds' $S || printf '%ds' $S
}
