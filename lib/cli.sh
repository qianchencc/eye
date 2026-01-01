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
    echo "$MSG_USAGE_CMD_CONFIG"
    echo "$MSG_USAGE_CMD_CONFIG_LANG"
    echo "$MSG_USAGE_CMD_CONFIG_MODE"
    echo "$MSG_USAGE_CMD_CONFIG_AUTO"
    echo "$MSG_USAGE_CMD_CONFIG_UPDATE"
    echo "$MSG_USAGE_CMD_CONFIG_UN"
    echo "  version            Show version information"
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
    local long_mode=0
    for arg in "$@"; do
        if [[ "$arg" == "-l" ]] || [[ "$arg" == "--long" ]]; then
            long_mode=1
        fi
    done

    local is_running=0
    local pid=""
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
        
        local paused="false"
        if [ -f "$PAUSE_FILE" ]; then
            paused="true"
            echo "pause_until=$(cat "$PAUSE_FILE")"
        fi
        echo "paused=$paused"
        
        local last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
        local diff=$(( $(date +%s) - last ))
        echo "last_rest_ago=$diff"
        return
    fi

    # 2. Human Readable Mode (TTY)
    local last=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
    local current_ts=$(date +%s)
    local raw_diff=$((current_ts - last))
    
    # Calculate effective diff
    local effective_diff=$raw_diff
    
    # Handle Pause Info
    local pause_info=""
    local paused="false"
    if [ -f "$PAUSE_FILE" ]; then
        local pause_until=$(cat "$PAUSE_FILE")
        if [ "$current_ts" -lt "$pause_until" ]; then
            paused="true"
            if [ -f "$PAUSE_START_FILE" ]; then
                local pause_start=$(cat "$PAUSE_START_FILE")
                local current_pause_duration=$((current_ts - pause_start))
                effective_diff=$((raw_diff - current_pause_duration))
            fi
            
            local p_diff=$((pause_until - current_ts))
            pause_info=$(_format_duration $p_diff)
        else
            rm "$PAUSE_FILE"
        fi
    fi
    
    # Handle Stop Adjustment
    if [ $is_running -eq 0 ] && [ -f "$STOP_FILE" ]; then
        local stop_time=$(cat "$STOP_FILE")
        local stop_duration=$((current_ts - stop_time))
        effective_diff=$((raw_diff - stop_duration))
    fi
    
    if [ $effective_diff -lt 0 ]; then effective_diff=0; fi
    local rest_fmt=$(_format_duration $effective_diff)
    
    local gap_fmt=$(_format_duration $REST_GAP)
    local look_fmt=$(_format_duration $LOOK_AWAY)

    if [ "$EYE_MODE" == "unix" ]; then
        # Unix Mode: Single line, no decoration
        local status_label="$MSG_LBL_RUNNING"
        [ $is_running -eq 0 ] && status_label="$MSG_LBL_STOPPED"
        [ "$paused" == "true" ] && status_label="$MSG_LBL_PAUSED"
        
        printf "%s: %s ago [%s / %s]" "$status_label" "$rest_fmt" "$gap_fmt" "$look_fmt"
        if [ $long_mode -eq 1 ]; then
            printf " (PID: %s, Lang: %s, Sound: %s)" "${pid:-N/A}" "$LANGUAGE" "$SOUND_SWITCH"
        fi
        echo ""
    else
        # Normal Mode: Visual layering with bold titles and colors
        if [ $is_running -eq 1 ]; then
            if [ "$paused" == "true" ]; then
                 printf "${_C_BOLD}● %s:${_C_RESET} ${_C_YELLOW}%s${_C_RESET} (Remaining: %s)\n" "$MSG_LBL_STATUS" "$MSG_LBL_PAUSED" "$pause_info"
            else
                 printf "${_C_BOLD}● %s:${_C_RESET} ${_C_GREEN}%s${_C_RESET} (PID: %s)\n" "$MSG_LBL_STATUS" "$MSG_LBL_RUNNING" "$pid"
            fi
        else
            printf "${_C_BOLD}● %s:${_C_RESET} ${_C_RED}%s${_C_RESET}\n" "$MSG_LBL_STATUS" "$MSG_LBL_STOPPED"
        fi
        
        printf "${_C_BOLD}● %s:${_C_RESET} %s ago\n" "$MSG_LBL_LAST_REST" "$rest_fmt"
        printf "${_C_BOLD}● %s:${_C_RESET}      %s %s / %s %s\n" "$MSG_LBL_PLAN" "$gap_fmt" "$MSG_LBL_WORK" "$look_fmt" "$MSG_LBL_REST"
        
        if [ $long_mode -eq 1 ]; then
            echo "--------------------------------"
            printf "${_C_BOLD}Language:${_C_RESET}   %s\n" "$LANGUAGE"
            printf "${_C_BOLD}Sound:${_C_RESET}      %s (Start: %s, End: %s)\n" "$SOUND_SWITCH" "$SOUND_START" "$SOUND_END"
            if systemctl --user is-active --quiet eye.service 2>/dev/null; then
                printf "${_C_BOLD}Systemd:${_C_RESET}    Active\n"
            fi
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

_cmd_config() {
    local subcmd=$1
    shift
    case "$subcmd" in
        mode)
            local mode=$(_read_input "$@")
            if [[ "$mode" == "unix" || "$mode" == "normal" ]]; then
                EYE_MODE="$mode"
                _save_config
                msg_success "Mode updated to: $mode"
            else
                msg_error "Usage: eye config mode <unix|normal>"
                exit 1
            fi
            ;;
        language)
            local lang_input=$(_read_input "$@")
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
            ;;
        autostart)
            _cmd_autostart "$@"
            ;;
        uninstall)
            _cmd_uninstall
            ;;
        update)
            _cmd_update "$@"
            ;;
        *)
            msg_error "Usage: eye config <mode|language|autostart|update|uninstall>"
            exit 1
            ;;
    esac
}

_cmd_update() {
    local apply_update=0
    for arg in "$@"; do
        if [[ "$arg" == "--apply" ]]; then
            apply_update=1
        fi
    done

    msg_info "$MSG_UPDATE_CHECKING"

    local current_version="$EYE_VERSION"
    local remote_version=""
    local update_mode=""

    if [ -d "$LIB_DIR/../.git" ]; then
        update_mode="git"
        git -C "$LIB_DIR/.." fetch origin --quiet 2>/dev/null
        remote_version=$(git -C "$LIB_DIR/.." rev-parse --short origin/master 2>/dev/null || \
                         git -C "$LIB_DIR/.." rev-parse --short origin/main 2>/dev/null)
        current_version=$(git -C "$LIB_DIR/.." rev-parse --short HEAD 2>/dev/null)
    else
        update_mode="url"
        remote_version=$(curl -s https://raw.githubusercontent.com/qianchencc/eye/master/lib/constants.sh | grep "export EYE_VERSION=" | cut -d'"' -f2)
        if [ -z "$remote_version" ]; then
            remote_version=$(curl -s https://raw.githubusercontent.com/qianchencc/eye/main/lib/constants.sh | grep "export EYE_VERSION=" | cut -d'"' -f2)
        fi
    fi

    if [[ -z "$remote_version" ]]; then
        msg_error "Failed to check for updates."
        return 1
    fi

    if [[ "$current_version" == "$remote_version" ]]; then
        msg_success "$(printf "$MSG_UPDATE_ALREADY_NEWEST" "$current_version")"
        return 0
    fi

    msg_warn "$(printf "$MSG_UPDATE_NEW_VERSION" "$remote_version" "$current_version")"

    if [ $apply_update -eq 0 ]; then
        if [ -t 1 ]; then
             _prompt_confirm "$MSG_UPDATE_APPLY_PROMPT" || return 0
             apply_update=1
        else
             return 0
        fi
    fi

    if [ $apply_update -eq 1 ]; then
        msg_info "$MSG_UPDATE_UPDATING"
        local success=0
        if [ "$update_mode" == "git" ]; then
            echo ">>> Executing: git pull" >&2
            git -C "$LIB_DIR/.." pull && success=1
        else
            echo ">>> Executing: curl | bash" >&2
            (curl -sSL https://raw.githubusercontent.com/qianchencc/eye/master/install.sh | bash || \
             curl -sSL https://raw.githubusercontent.com/qianchencc/eye/main/install.sh | bash) && success=1
        fi
        
        if [ $success -eq 1 ]; then
            msg_success "$MSG_UPDATE_DONE"
        else
            msg_error "$MSG_UPDATE_FAILED"
            return 1
        fi
    fi
}

_cmd_version() {
    echo "eye version $EYE_VERSION"
}

_cmd_uninstall() {
    _prompt_confirm "$MSG_UNINSTALL_CONFIRM" || exit 0

    msg_info "$MSG_UNINSTALL_STARTING"

    # 1. Stop and disable autostart
    _cmd_autostart off >/dev/null 2>&1 || true
    _cmd_stop >/dev/null 2>&1 || true

    # 2. Identify Paths
    local bin_path=$(command -v eye)
    [[ -z "$bin_path" ]] && bin_path=$(readlink -f "$0")
    local comp_file="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/eye"

    # 3. Clean environment (PATH cleanup in shell RCs)
    local FILES_TO_CLEAN=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    for RC_FILE in "${FILES_TO_CLEAN[@]}"; do
        if [ -f "$RC_FILE" ] && grep -q "# Eye Path" "$RC_FILE"; then
            sed -i '/# Eye Path/d' "$RC_FILE"
            sed -i "s|export PATH=\"\$PATH:$HOME/.local/bin\"||g" "$RC_FILE"
            sed -i '${/^$/d;}' "$RC_FILE"
        fi
    done

    # 4. Final Deletion of all traces
    
    # Remove binary
    [ -f "$bin_path" ] && rm -f "$bin_path"
    
    # Remove Libs (if in standard location)
    [[ "$LIB_DIR" == *"$HOME/.local/lib/eye"* ]] && rm -rf "$LIB_DIR"
    
    # Remove Data, Config and State
    [ -d "$DATA_DIR" ] && rm -rf "$DATA_DIR"
    [ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR"
    [ -d "$STATE_DIR" ] && rm -rf "$STATE_DIR"
    
    # Remove Completion
    [ -f "$comp_file" ] && rm -f "$comp_file"

    echo "$MSG_UNINSTALL_DONE"
}

