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
        msg_warn "$(printf "$MSG_START_ALREADY_RUNNING" "$(cat "$PID_FILE")")"
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
    duration_str="$*"
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
    duration_str="$*"
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
    is_running=0
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        is_running=1
    fi
    
    if [ $is_running -eq 1 ]; then
        _load_config
        msg_success "$(printf "$MSG_STATUS_RUNNING" "$(cat "$PID_FILE")")"
        
        if systemctl --user is-active --quiet eye.service 2>/dev/null; then
            msg_info "$MSG_STATUS_SYSTEMD_ACTIVE"
        fi
        
        if [ -f "$PAUSE_FILE" ]; then
            pause_until=$(cat "$PAUSE_FILE")
            current=$(date +%s)
            if [ "$current" -lt "$pause_until" ]; then
                remaining=$((pause_until - current))
                target_date=$(date -d "@$pause_until" "+%H:%M:%S")
                msg_warn "$(printf "$MSG_STATUS_PAUSED_REMAINING" "$(_format_duration $remaining)" "$target_date")"
                
                if [ -f "$PAUSE_START_FILE" ]; then
                    pause_start=$(cat "$PAUSE_START_FILE")
                    last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
                    diff=$((pause_start - last))
                    echo "$(printf "$MSG_STATUS_LAST_REST_FROZEN" "$(_format_duration $diff)")"
                fi
            else
                rm "$PAUSE_FILE"
            fi
        else 
            last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
            diff=$(( $(date +%s) - last ))
            gap_fmt=$(_format_duration $REST_GAP)
            look_fmt=$(_format_duration $LOOK_AWAY)
            msg_info "$(printf "$MSG_STATUS_CONFIG" "$gap_fmt" "$look_fmt")"
            msg_info "$(printf "$MSG_STATUS_LAST_REST" "$(_format_duration $diff)")"
            echo "$(printf "$MSG_STATUS_SOUND" "$SOUND_START" "$SOUND_END" "$SOUND_SWITCH")"
            echo "$(printf "$MSG_STATUS_LANG" "$LANGUAGE")"
        fi
        
    elif [ -f "$EYE_LOG" ]; then
        _load_config
        msg_info "$MSG_STATUS_STOPPED"
        
        gap_fmt=$(_format_duration $REST_GAP)
        look_fmt=$(_format_duration $LOOK_AWAY)
        msg_info "$(printf "$MSG_STATUS_CONFIG" "$gap_fmt" "$look_fmt")"
        
        if [ -f "$STOP_FILE" ]; then
            stop_time=$(cat "$STOP_FILE")
            last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
            diff=$((stop_time - last))
            echo "$(printf "$MSG_STATUS_LAST_REST_FROZEN" "$(_format_duration $diff)")"
        else
            last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
            diff=$(( $(date +%s) - last ))
            echo "$(printf "$MSG_STATUS_LAST_REST" "$(_format_duration $diff)")"
        fi
        
        echo "$(printf "$MSG_STATUS_SOUND" "$SOUND_START" "$SOUND_END" "$SOUND_SWITCH")"
        echo "$MSG_STATUS_STOPPED_HINT"
        
    else
        msg_error "$MSG_STATUS_KILLED"
        echo "$MSG_STATUS_STOPPED_HINT"
    fi
}

_cmd_set() {
    gap_input=$1
    look_input=$2
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
    lang_input=$1
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

