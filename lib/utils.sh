#!/bin/bash

# ================= Logging & Formatting =================

# Colors
if [ -t 1 ]; then
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

msg_error() {
    printf "${_C_RED}%s${_C_RESET}\n" "$*" >&2
}

msg_warn() {
    printf "${_C_YELLOW}%s${_C_RESET}\n" "$*" >&2
}

msg_info() {
    printf "${_C_BOLD}%s${_C_RESET}\n" "$*"
}

msg_success() {
    printf "${_C_GREEN}%s${_C_RESET}\n" "$*"
}

# ================= Core Functions =================

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
