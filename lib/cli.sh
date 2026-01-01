#!/bin/bash

# =================命令行逻辑=================

_cmd_usage() {
    echo "$MSG_USAGE_HEADER"
    echo ""
    echo "$MSG_USAGE_CORE"
    echo "$MSG_USAGE_CMD_START"
    echo "$MSG_USAGE_CMD_STOP"
    echo "$MSG_USAGE_CMD_KILL"
    echo "$MSG_USAGE_CMD_PAUSE"
    echo "$MSG_USAGE_CMD_RESUME"
    echo "$MSG_USAGE_CMD_PASS"
    echo "$MSG_USAGE_CMD_STATUS"
    echo "$MSG_USAGE_CMD_NOW"
    echo -e "$MSG_USAGE_CMD_SET"
    echo "$MSG_USAGE_CMD_LANG"
    echo "  config mode <mode> Set mode (unix|normal)"
    echo "$MSG_USAGE_CMD_AUTOSTART"
    echo ""
    echo "$MSG_USAGE_AUDIO"
    echo "$MSG_USAGE_CMD_SOUND_LIST"
    echo "$MSG_USAGE_CMD_SOUND_PLAY"
    echo "$MSG_USAGE_CMD_SOUND_SET"
    echo "$MSG_USAGE_CMD_SOUND_ADD"
    echo "$MSG_USAGE_CMD_SOUND_RM"
    echo "$MSG_USAGE_CMD_SOUND_SWITCH"
}

_cmd_start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        # Idempotency check: Exit 0 silently in Unix mode/Quiet, else warn.
        if [ "$EYE_MODE" == "unix" ] || [ -n "$QUIET_MODE" ]; then
            exit 0
        else
            msg_warn "$(printf "$MSG_START_ALREADY_RUNNING" "$(cat "$PID_FILE")")"
        fi
    else
        ( _daemon_loop ) > /dev/null 2>&1 &
        disown
        msg_success "$MSG_START_STARTED"
    fi
}

_cmd_stop() {
    if systemctl --user is-active --quiet eye.service 2>/dev/null; then
        systemctl --user stop eye.service
    fi
    
    if [ -f "$PID_FILE" ]; then
        pkill -P $(cat "$PID_FILE") >/dev/null 2>&1
        kill $(cat "$PID_FILE") >/dev/null 2>&1
        rm "$PID_FILE" 2>/dev/null
        rm "$PAUSE_FILE" 2>/dev/null
        
        # Save Stop Time
        date +%s > "$STOP_FILE"
        
        msg_success "$MSG_STOP_STOPPED"
    else
        msg_info "$MSG_STOP_STOPPED"
    fi
}

_cmd_kill() {
    _cmd_autostart "off" >/dev/null 2>&1
    systemctl --user stop eye.service 2>/dev/null
    
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null
        kill -9 "$pid" 2>/dev/null
        rm "$PID_FILE" 2>/dev/null
    fi
    
    for pid in $(pgrep -f "bin/eye"); do
        if [ "$pid" != "$$" ] && [ "$pid" != "$BASHPID" ]; then
            kill -9 "$pid" 2>/dev/null
        fi
    done
    
    rm "$PAUSE_FILE" 2>/dev/null
    rm "$EYE_LOG" 2>/dev/null
    rm "$STOP_FILE" 2>/dev/null
    rm "$PAUSE_START_FILE" 2>/dev/null
    
    msg_success "$MSG_KILL_DONE"
}

_cmd_pause() {
    duration_str=$(_read_input "$@")
    [ -z "$duration_str" ] && { msg_error "$MSG_PAUSE_SPECIFY_DURATION"; exit 1; }
    seconds=$(_parse_duration "$duration_str")
    if [ $? -eq 0 ]; then
        target_time=$(( $(date +%s) + seconds ))
        echo "$target_time" > "$PAUSE_FILE"
        date +%s > "$PAUSE_START_FILE"
        formatted_dur=$(_format_duration "$seconds")
        target_date=$(date -d "@$target_time" "+%H:%M:%S")
        msg_success "$(printf "$MSG_PAUSE_PAUSED" "$formatted_dur" "$target_date")"
    else
         msg_error "$MSG_PAUSE_ERROR_FORMAT"
    fi
}

_cmd_resume() {
    if [ -f "$PAUSE_FILE" ]; then
        if [ -f "$PAUSE_START_FILE" ]; then
             start_pause=$(cat "$PAUSE_START_FILE")
             current_time=$(date +%s)
             duration=$((current_time - start_pause))
             old_last=$(cat "$EYE_LOG" 2>/dev/null || echo $current_time)
             new_last=$((old_last + duration))
             echo "$new_last" > "$EYE_LOG"
             rm "$PAUSE_START_FILE"
        fi
        rm "$PAUSE_FILE"
        msg_success "$MSG_RESUME_RESUMED"
    else
        msg_warn "$MSG_RESUME_NOT_PAUSED"
    fi
}

_cmd_pass() {
    duration_str=$(_read_input "$@")
    [ -z "$duration_str" ] && { msg_error "$MSG_PASS_ERROR"; exit 1; }
    seconds=$(_parse_duration "$duration_str")
    if [ $? -eq 0 ]; then
        if [ ! -f "$EYE_LOG" ]; then
             date +%s > "$EYE_LOG"
        fi
        
        current_last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
        new_last=$((current_last - seconds))
        echo "$new_last" > "$EYE_LOG"
        
        current_time=$(date +%s)
        diff=$((current_time - new_last))
        
        if [ $diff -ge $REST_GAP ]; then
            msg_warn "$MSG_PASS_TRIGGERED"
            if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
                kill -SIGUSR1 $(cat "$PID_FILE")
            fi
        else
            msg_success "$(printf "$MSG_PASS_SKIPPED" "$(_format_duration $seconds)")"
        fi
    else
         msg_error "$MSG_PAUSE_ERROR_FORMAT"
    fi
}

_cmd_now() {
    # Check if break is already in progress
    if [ -f "$BREAK_LOCK_FILE" ]; then
        if [ "$EYE_MODE" == "unix" ] || [ -n "$QUIET_MODE" ]; then
            exit 0
        else
            msg_warn "Break already in progress."
            exit 0
        fi
    fi

    msg_info "$MSG_NOW_TRIGGERING"
    
    is_reset="false"
    if [[ "$1" == "--reset" ]]; then
        is_reset="true"
    fi
    
    ( _eye_action "$is_reset" ) > /dev/null 2>&1 &
    disown
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        if [[ "$is_reset" == "true" ]]; then
            msg_success "$MSG_NOW_MANUAL_RESET"
        else
            msg_success "$MSG_NOW_MANUAL_TRIGGERED"
        fi
    else
        msg_info "$MSG_NOW_MANUAL_NO_RESET"
    fi
}

_cmd_status() {
    # Parse arguments for status command
    long_mode=0
    for arg in "$@"; do
        if [[ "$arg" == "-l" ]] || [[ "$arg" == "--long" ]]; then
            long_mode=1
        fi
    done
    
    # DEBUG
    # echo "DEBUG: long_mode=$long_mode args=$@"

    is_running=0
    pid=""
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        is_running=1
        pid=$(cat "$PID_FILE")
    fi
    
    _load_config
    
    # 1. Machine Readable Mode (Pipe)
    if [ ! -t 1 ]; then
        if [ $is_running -eq 1 ]; then
            echo "status=running"
            echo "pid=$pid"
        elif [ -f "$EYE_LOG" ]; then
             echo "status=stopped"
        else
             echo "status=dead"
        fi
        
        echo "gap_seconds=$REST_GAP"
        echo "look_seconds=$LOOK_AWAY"
        echo "language=$LANGUAGE"
        echo "sound_switch=$SOUND_SWITCH"
        
        paused="false"
        if [ -f "$PAUSE_FILE" ]; then
            paused="true"
            echo "pause_until=$(cat "$PAUSE_FILE")"
        fi
        echo "paused=$paused"
        
        last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
        diff=$(( $(date +%s) - last ))
        echo "last_rest_ago=$diff"
        return
    fi

    # 2. Human Readable Mode (TTY)
    last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
    current_ts=$(date +%s)
    raw_diff=$((current_ts - last))
    
    # Calculate effective diff (subtract stagnation time)
    effective_diff=$raw_diff
    
    # Handle Pause Info & Adjustment
    pause_info=""
    paused="false"
    if [ -f "$PAUSE_FILE" ]; then
        pause_until=$(cat "$PAUSE_FILE")
        if [ "$current_ts" -lt "$pause_until" ]; then
            paused="true"
            # Calculate pause duration so far
            if [ -f "$PAUSE_START_FILE" ]; then
                pause_start=$(cat "$PAUSE_START_FILE")
                current_pause_duration=$((current_ts - pause_start))
                effective_diff=$((raw_diff - current_pause_duration))
            fi
            
            # Remaining time
            p_diff=$((pause_until - current_ts))
            p_fmt=$(_format_duration $p_diff)
            pause_info=$(printf "$MSG_STATUS_PAUSED_REMAINING_HUMAN" "$p_fmt")
        else
            pause_info="$MSG_STATUS_PAUSED_EXPIRED_HUMAN"
            rm "$PAUSE_FILE"
        fi
    fi
    
    # Handle Stop Adjustment
    if [ $is_running -eq 0 ] && [ -f "$STOP_FILE" ]; then
        stop_time=$(cat "$STOP_FILE")
        stop_duration=$((current_ts - stop_time))
        effective_diff=$((raw_diff - stop_duration))
    fi
    
    # Format effective diff
    if [ $effective_diff -lt 0 ]; then effective_diff=0; fi
    rest_fmt=$(_format_duration $effective_diff)
    
    # Config format
    gap_fmt=$(_format_duration $REST_GAP)
    look_fmt=$(_format_duration $LOOK_AWAY)

    # Output Logic
    
    # Status indicators for Last Rest line
    status_suffix=""
    if [ "$paused" == "true" ]; then
        status_suffix=" (Paused)"
    elif [ $is_running -eq 0 ] && [ -f "$EYE_LOG" ]; then
        status_suffix=" (Stopped)"
    elif [ $is_running -eq 0 ]; then
        status_suffix=" (Not Running)"
    fi

    # Concise Output (Default)
    # Format: Last Rest: <time> ago<status> [<gap> / <look>]
    last_rest_str=$(printf "$MSG_STATUS_LAST_REST_HUMAN" "$rest_fmt")
    echo "${last_rest_str}${status_suffix} [${gap_fmt} / ${look_fmt}]"
    
    # Long Output (-l/--long)
    if [ $long_mode -eq 1 ]; then
        if [ $is_running -eq 1 ]; then
            if [ "$paused" == "true" ]; then
                 echo "$(printf "$MSG_STATUS_PAUSED_HUMAN" "$pause_info")"
            else
                 echo "$(printf "$MSG_STATUS_RUNNING_HUMAN" "$pid")"
            fi
        elif [ -f "$EYE_LOG" ]; then
            echo "$MSG_STATUS_STOPPED_HUMAN"
        else
            echo "$MSG_STATUS_NOT_RUNNING_HUMAN"
        fi
        
        echo "$(printf "$MSG_STATUS_CONFIG_HUMAN" "$gap_fmt" "$look_fmt")"
        echo "$(printf "$MSG_STATUS_SOUND_HUMAN" "$SOUND_SWITCH")"
        
        if systemctl --user is-active --quiet eye.service 2>/dev/null; then
            echo "$MSG_STATUS_SYSTEMD_HUMAN"
        fi
    fi
}

_cmd_set() {
    input_str=$(_read_input "$@")
    # Split input into array
    read -r -a args <<< "$input_str"
    gap_input=${args[0]}
    look_input=${args[1]}
    
    if [ -z "$gap_input" ]; then
        msg_error "$(echo -e "$MSG_SET_USAGE_HINT")"
        exit 1
    fi
    
    _load_config
    
    new_gap=$(_parse_duration "$gap_input")
    [ $? -ne 0 ] && exit 1
    
    if [ -n "$look_input" ]; then
        new_look=$(_parse_duration "$look_input")
        [ $? -ne 0 ] && exit 1
    else
        new_look=$LOOK_AWAY
    fi
    
    REST_GAP=$new_gap
    LOOK_AWAY=$new_look
    _save_config
    
    msg_success "$(printf "$MSG_SET_UPDATED" "$(_format_duration $REST_GAP)" "$(_format_duration $LOOK_AWAY)")"
}

_cmd_language() {
    lang_input=$(_read_input "$@")
    if [[ "$lang_input" == "en" ]] || [[ "$lang_input" == "English" ]]; then
        LANGUAGE="en"
    elif [[ "$lang_input" == "zh" ]] || [[ "$lang_input" == "Chinese" ]]; then
        LANGUAGE="zh"
    else
        msg_error "$MSG_LANG_INVALID"
        exit 1
    fi
    _save_config
    _init_messages
    msg_success "$(printf "$MSG_LANG_UPDATED" "$LANGUAGE")"
}

_cmd_config() {
    local subcmd=$1
    shift
    if [ "$subcmd" == "mode" ]; then
        local mode=$1
        if [[ "$mode" == "unix" || "$mode" == "normal" ]]; then
            EYE_MODE="$mode"
            _save_config
            msg_success "Mode updated to: $mode"
        else
            msg_error "Usage: eye config mode <unix|normal>"
            exit 1
        fi
    else
         msg_error "Usage: eye config mode <unix|normal>"
         exit 1
    fi
}

