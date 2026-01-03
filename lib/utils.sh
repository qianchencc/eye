#!/bin/bash

# Source Logger
if [ -f "$LIB_DIR/logger.sh" ]; then
    source "$LIB_DIR/logger.sh"
fi

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

# Helper for stderr output
_msg_stderr() {
    local color="$1"
    shift
    local msg="$*"
    
    # Check global quiet settings
    # QUIET_MODE is CLI arg (-q), GLOBAL_QUIET is from config
    if [[ -n "$QUIET_MODE" ]] || [[ "$GLOBAL_QUIET" == "on" ]]; then
        return
    fi

    _msg_direct_stderr "$color" "$msg"
}

# Output to stderr regardless of quiet mode (used for help)
_msg_direct_stderr() {
    local color="$1"
    shift
    local msg="$*"
    if [ -t 2 ]; then
        printf "${color}%s${_C_RESET}\n" "$msg" >&2
    else
        echo "$msg" >&2
    fi
}

msg_help() {
    _msg_direct_stderr "$_C_BOLD" "$*"
}

msg_error() {
    _msg_stderr "$_C_RED" "$*"
}

msg_warn() {
    _msg_stderr "$_C_YELLOW" "$*"
}

msg_info() {
    _msg_stderr "$_C_BOLD" "$*"
}

msg_success() {
    _msg_stderr "$_C_GREEN" "$*"
}

# ================= Core Functions =================

# Runtime requirement check
_check_requirements() {
    local missing=0
    
    if ! command -v notify-send >/dev/null 2>&1; then
        msg_error "❌ Error: 'notify-send' is missing (libnotify-bin)."
        msg_error "   Please install it to receive notifications."
        missing=1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        msg_warn "⚠️  Warning: 'curl' is missing."
        msg_warn "   Update and some config features may not work."
    fi
    
    if ! command -v paplay >/dev/null 2>&1; then
        msg_warn "⚠️  Warning: 'paplay' is missing (pulseaudio-utils)."
        msg_warn "   Sound features will be disabled."
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

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
        return 0
    fi

    local total_seconds=0
    local matched=0
    
    # Extract days (d)
    if [[ "$input" =~ ([0-9]+)d ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 86400))
        matched=1
    fi
    # Extract hours (h)
    if [[ "$input" =~ ([0-9]+)h ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 3600))
        matched=1
    fi
    # Extract minutes (m)
    if [[ "$input" =~ ([0-9]+)m ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 60))
        matched=1
    fi
    # Extract seconds (s)
    if [[ "$input" =~ ([0-9]+)s ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]}))
        matched=1
    fi

    if [[ $matched -eq 0 ]]; then
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
    printf '%ds' $S
}

# Prompt for confirmation [Y/n]
_prompt_confirm() {
    local msg="$1"
    local answer
    printf "${_C_YELLOW}%s [Y/n]: ${_C_RESET}" "$msg" >&2
    read -r answer
    # Default to Yes if empty
    [[ -z "$answer" ]] && return 0
    if [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        return 0
    fi
    return 1
}

# --- Interactive Input Helpers ---

_ask_val() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input
    
    if [ -n "$default" ]; then
        printf "%s [%s]: " "$prompt" "$default"
    else
        printf "%s: " "$prompt"
    fi
    
    read -r input < /dev/tty
    if [ -z "$input" ]; then
        printf -v "$var_name" "%s" "$default"
    else
        # Trim surrounding quotes
        input="${input#\"}"
        input="${input%\"}"
        input="${input#\'}"
        input="${input%\'}"
        printf -v "$var_name" "%s" "$input"
    fi
}

_ask_bool() {
    local prompt="$1"
    local default="$2" # "y" or "n"
    local var_name="$3"
    local input
    
    local yn="[y/n]"
    [[ "$default" =~ ^[Yy] ]] && yn="[Y/n]"
    [[ "$default" =~ ^[Nn] ]] && yn="[y/N]"
    
    printf "%s %s: " "$prompt" "$yn"
    read -r input < /dev/tty
    if [ -z "$input" ]; then
        input="$default"
    fi
    
    if [[ "$input" =~ ^[Yy] ]]; then
        printf -v "$var_name" "%s" "true"
    else
        printf -v "$var_name" "%s" "false"
    fi
}
