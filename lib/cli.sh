#!/bin/bash

# =================命令行逻辑 (v2.0 Refactored)=================

# --- 辅助函数 ---

_get_default_target() {
    echo "${DEFAULT_TASK:-default}"
}

_resolve_target() {
    local arg="$1"
    if [[ -z "$arg" || "$arg" == -* ]]; then
        echo "@$(_get_default_target)"
    elif [[ "$arg" == @* ]]; then
        echo "$arg"
    else
        echo "$arg"
    fi
}

_apply_to_tasks() {
    local target="$1" # task_id, @group, or --all
    local callback="$2" # Function name to call for each task
    shift 2
    local args=($@)

    local matched=0
    
    # Iterate all tasks
    for task_file in "$TASKS_DIR"/*;
    do
        [ -e "$task_file" ] || continue
        local task_id=$(basename "$task_file")
        
        # Filter
        if [[ "$target" == "--all" ]]; then
            : # Match all
        elif [[ "$target" == @* ]]; then
            local group_name="${target#@}"
            _load_task "$task_id"
            if [[ "$GROUP" != "$group_name" ]]; then
                continue
            fi
        else
            if [[ "$task_id" != "$target" ]]; then
                continue
            fi
        fi
        
        # Execute Callback
        matched=1
        _load_task "$task_id" # Reload to be sure
        "$callback" "$task_id" "${args[@]}"
        # Only save if the task still exists (callbacks like remove delete it)
        if [ -f "$TASKS_DIR/$task_id" ]; then
            _save_task "$task_id"
        fi
    done

    if [ $matched -eq 0 ]; then
        msg_warn "No tasks matched target: $target"
    fi
}

# --- 任务操作回调 ---

_cb_set_status() {
    local id="$1"
    local new_status="$2"
    STATUS="$new_status"
    msg_info "Task $id -> $new_status"
}

_cb_time_shift() {
    local id="$1"
    local delta_str="$2"
    local sign="${delta_str:0:1}"
    local val_str="$delta_str"
    
    if [[ "$sign" == "+" || "$sign" == "-" ]]; then
        val_str="${delta_str:1}"
    else
        sign="+"
    fi
    
    local seconds=$(_parse_duration "$val_str")
    if [ $? -ne 0 ]; then return; fi
    
    if [[ "$sign" == "-" ]]; then
        LAST_RUN=$((LAST_RUN + seconds))
    else
        LAST_RUN=$((LAST_RUN - seconds))
    fi
    msg_success "Task $id time shifted by $sign$val_str"
}

_cb_count_shift() {
    local id="$1"
    local delta="$2"
    REMAIN_COUNT=$((REMAIN_COUNT + delta))
    msg_success "Task $id count shifted by $delta (Now: $REMAIN_COUNT)"
}

_cb_reset() {
    local id="$1"
    local do_time="$2"
    local do_count="$3"
    
    if [[ "$do_time" == "true" ]]; then
        LAST_RUN=$(date +%s)
        msg_info "Task $id timer reset."
    fi
    
    if [[ "$do_count" == "true" ]]; then
        if [[ "$TARGET_COUNT" -gt 0 ]]; then
            REMAIN_COUNT="$TARGET_COUNT"
            msg_info "Task $id count reset to $TARGET_COUNT."
        else
            msg_info "Task $id has no target count."
        fi
    fi
}

# --- 核心指令 ---

_cmd_start() {
    local target="${1:-@$(_get_default_target)}"
    _apply_to_tasks "$target" _cb_set_status "running"
}

_cmd_stop() {
    local target="${1:-@$(_get_default_target)}"
    _apply_to_tasks "$target" _cb_set_status "stopped"
}

_cmd_pause() {
    local target="$1"
    if [[ "$target" == "--all" || "$target" == "-a" ]]; then
        target="--all"
    elif [[ -z "$target" ]]; then
        target="@$(_get_default_target)"
    fi
    _apply_to_tasks "$target" _cb_set_status "paused"
}

_cmd_resume() {
    local target="$1"
    if [[ "$target" == "--all" || "$target" == "-a" ]]; then
        target="--all"
    elif [[ -z "$target" ]]; then
        target="@$(_get_default_target)"
    fi
    _apply_to_tasks "$target" _cb_set_status "running"
}

_cmd_now() {
    local task_id="$1"
    if [[ -z "$task_id" ]]; then
        local def=$(_get_default_target)
        if [[ -f "$TASKS_DIR/$def" ]]; then
             task_id="$def"
        else
             msg_error "Usage: eye now <task_id> (No default task found)"
             return 1
        fi
    fi
    msg_info "Triggering $task_id immediately..."
    ( _load_task "$task_id" && _execute_task "$task_id" ) &
}

_cmd_time() {
    local delta="$1"
    local target="${2:-@$(_get_default_target)}"
    if [[ -z "$delta" || "$delta" == "--help" || "$delta" == "-h" ]]; then
        msg_info "Usage: eye time <delta> [task_id|@group|--all]"
        return 0
    fi
    _apply_to_tasks "$target" _cb_time_shift "$delta"
}

_cmd_count() {
    local delta="$1"
    local target="${2:-@$(_get_default_target)}"
    if [[ -z "$delta" || "$delta" == "--help" || "$delta" == "-h" ]]; then
        msg_info "Usage: eye count <delta> [task_id|@group|--all]"
        return 0
    fi
    _apply_to_tasks "$target" _cb_count_shift "$delta"
}

_cmd_reset() {
    local target=""
    local do_time=false
    local do_count=false
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        msg_info "Usage: eye reset [target] --time --count"
        return 0
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --time) do_time=true ;; 
            --count) do_count=true ;; 
            *) target="$1" ;; 
        esac
        shift
    done
    target="${target:-@$(_get_default_target)}"
    _apply_to_tasks "$target" _cb_reset "$do_time" "$do_count"
}

_cmd_add() {
    local task_id="$1"
    shift
    if [[ -z "$task_id" || "$task_id" == "--help" || "$task_id" == "-h" ]]; then
        msg_info "Usage: eye add <name> [options]"
        msg_data ""
        msg_data "Core Options:"
        msg_data "  -i, --interval <time>  Interval (e.g. 20m, 1h)"
        msg_data "  -d, --duration <time>  Duration (e.g. 20s, 0s for Pulse)"
        msg_data "  -g, --group <name>     Group name (default: default)"
        msg_data "  -c, --count <int>      Loop count (-1 for infinite)"
        msg_data "  --temp                 Delete task after completion"
        msg_data ""
        msg_data "Content Options:"
        msg_data "  --sound-start <tag>    Sound to play at start"
        msg_data "  --sound-end <tag>      Sound to play at end (if duration > 0)"
        msg_data "  --msg-start <text>     Notification text at start"
        msg_data "  --msg-end <text>       Notification text at end"
        msg_data ""
        msg_data "Variables for messages (styles: {VAR} or \${VAR}):"
        msg_data "  {DURATION}             Formatted duration (e.g., 20s)"
        msg_data "  {INTERVAL}             Formatted interval"
        msg_data "  {NAME}                 Task name"
        msg_data "  {REMAIN_COUNT}         Remaining loop count"
        return 0
    fi
    local task_file="$TASKS_DIR/$task_id"
    if [[ -f "$task_file" ]]; then
        msg_warn "Task '$task_id' already exists."
        if ! _prompt_confirm "Overwrite?"; then return; fi
    fi
    
    # Initialize globals for _save_task
    NAME="$task_id"
    GROUP="default"
    INTERVAL=1200
    DURATION=20
    TARGET_COUNT=-1
    REMAIN_COUNT=-1
    IS_TEMP=false
    SOUND_ENABLE=true
    SOUND_START="default"
    SOUND_END="complete"
    MSG_START=""
    MSG_END=""
    LAST_RUN=$(date +%s)
    STATUS="running"

    if [[ $# -eq 0 ]]; then
        msg_info "Creating task '$task_id'..."
        
        local tmp_val
        _ask_val "$MSG_WIZARD_INTERVAL" "20m" tmp_val
        INTERVAL=$(_parse_duration "$tmp_val") || return 1
        
        _ask_val "$MSG_WIZARD_DURATION" "20s" tmp_val
        DURATION=$(_parse_duration "$tmp_val") || return 1
        
        if [[ "$DURATION" -eq 0 ]]; then
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" SOUND_ENABLE
            if [[ "$SOUND_ENABLE" == "true" ]]; then
                 echo "Available sounds:"
                 _cmd_sound list
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" SOUND_START
            fi
            echo 'Hint: Use {REMAIN_COUNT} for remaining loops.'
            _ask_val "$MSG_WIZARD_MSG_START" "Time is up!" MSG_START
        else
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" SOUND_ENABLE
            if [[ "$SOUND_ENABLE" == "true" ]]; then
                echo "Available sounds:"
                _cmd_sound list
                _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" SOUND_START
                _ask_val "$(printf "$MSG_WIZARD_SOUND_END" "complete")" "complete" SOUND_END
            fi
            echo 'Hint: Use {DURATION} for duration, {REMAIN_COUNT} for remaining loops.'
            _ask_val "$MSG_WIZARD_MSG_START" 'Look away for {DURATION}!' MSG_START
            _ask_val "$MSG_WIZARD_MSG_END" "Break ended." MSG_END
        fi
        _ask_val "Group" "default" GROUP
        _ask_val "$MSG_WIZARD_COUNT" "-1" TARGET_COUNT
        REMAIN_COUNT="$TARGET_COUNT"
        if [[ "$TARGET_COUNT" -gt 0 ]]; then
             _ask_bool "$MSG_WIZARD_IS_TEMP" "n" IS_TEMP
        fi
        if ! _prompt_confirm "$MSG_WIZARD_CONFIRM"; then 
            msg_info "Creation cancelled."
            return
        fi
    else
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) INTERVAL=$(_parse_duration "$2"); shift 2 ;; 
                -d|--duration) DURATION=$(_parse_duration "$2"); shift 2 ;; 
                -g|--group)    GROUP="$2"; shift 2 ;; 
                -c|--count)    TARGET_COUNT="$2"; REMAIN_COUNT="$2"; shift 2 ;; 
                --temp)        IS_TEMP="true"; shift ;; 
                --sound-start) SOUND_START="$2"; shift 2 ;; 
                --sound-end)   SOUND_END="$2"; shift 2 ;; 
                --msg-start)   MSG_START="$2"; shift 2 ;; 
                --msg-end)     MSG_END="$2"; shift 2 ;; 
                *) shift ;; 
            esac
        done
    fi
    
    if _save_task "$task_id"; then msg_success "$(printf "$MSG_TASK_CREATED" "$task_id")"; fi
}

_cmd_edit() {
    local task_id="$1"
    shift
    if [[ -z "$task_id" || "$task_id" == "--help" || "$task_id" == "-h" ]]; then
        msg_info "Usage: eye edit <task_id> [options]"; return 1
    fi
    local task_file="$TASKS_DIR/$task_id"
    if [[ ! -f "$task_file" ]]; then msg_error "$(printf "$MSG_TASK_NOT_FOUND" "$task_id")"; return 1; fi
    _load_task "$task_id"
    if [[ $# -gt 0 ]]; then
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) INTERVAL=$(_parse_duration "$2"); shift 2 ;; 
                -d|--duration) DURATION=$(_parse_duration "$2"); shift 2 ;; 
                -g|--group)    GROUP="$2"; shift 2 ;; 
                -c|--count)    TARGET_COUNT="$2"; REMAIN_COUNT="$2"; shift 2 ;; 
                --temp)        IS_TEMP="true"; shift ;; 
                --no-temp)     IS_TEMP="false"; shift ;; 
                --sound-start) SOUND_START="$2"; shift 2 ;; 
                --sound-end)   SOUND_END="$2"; shift 2 ;; 
                --msg-start)   MSG_START="$2"; shift 2 ;; 
                --msg-end)     MSG_END="$2"; shift 2 ;; 
                *) shift ;; 
            esac
        done
        _save_task "$task_id"
        msg_success "Task updated."
    else
        msg_info "Editing '$task_id'வைக்..."
        local interval_fmt=$(_format_duration "$INTERVAL")
        local duration_fmt=$(_format_duration "$DURATION")
        local tmp_val
        _ask_val "$MSG_WIZARD_INTERVAL" "$interval_fmt" tmp_val
        INTERVAL=$(_parse_duration "$tmp_val")
        _ask_val "$MSG_WIZARD_DURATION" "$duration_fmt" tmp_val
        DURATION=$(_parse_duration "$tmp_val")
        _ask_val "Group" "$GROUP" GROUP
        _ask_val "$MSG_WIZARD_COUNT" "$TARGET_COUNT" TARGET_COUNT
        [[ "$TARGET_COUNT" -gt 0 ]] && REMAIN_COUNT="$TARGET_COUNT" || REMAIN_COUNT="-1"
        if _save_task "$task_id"; then msg_success "Task updated."; fi
    fi
}

_cmd_remove() {
    local target="$1"
    [[ -z "$target" ]] && { msg_error "Usage: eye remove <task_id|@group>"; return 1; }
    _apply_to_tasks "$target" _cb_remove
}

_cb_remove() {
    local id="$1"
    rm -f "$TASKS_DIR/$id"
    msg_success "Task '$id' removed."
}

_cmd_status() {
    local sort_key="next" reverse=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sort|-s) sort_key="$2"; shift 2 ;;
            --reverse|-r) reverse=true; shift ;;
            *) shift ;;
        esac
    done
    local daemon_active=false
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then daemon_active=true; fi
    if [ ! -t 1 ]; then echo "daemon_running=$daemon_active"; return; fi
    
    [ "$daemon_active" = true ] && msg_success "● Daemon: Active (PID: $(cat "$PID_FILE"))" || msg_error "● Daemon: Inactive"
    echo ""
    
    # Box drawing characters
    local TL="┌" TR="┐" BL="└" BR="┘" H="─" V="│" T="┬" B="┴" M="┼" L="├" R="┤"
    
    # Column widths: ID(20), Group(10), Interval(10), Count(10), Status(10), NEXT(10)
    # Note: total width = 20+10+10+10+10+10 + 7 separators = 77
    local sep_line=$(printf "%s%77s%s" "$L" "" "$R" | tr ' ' "$H")
    # Custom separators for the middle line
    local mid_sep="├──────────────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤"
    local top_line="┌──────────────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐"
    local bot_line="└──────────────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘"

    msg_info "$top_line"
    printf "${_C_BOLD}${V} % -20s ${V} % -10s ${V} % -10s ${V} % -10s ${V} % -10s ${V} % -10s ${V}${_C_RESET}\n" "$MSG_TASK_ID" "$MSG_TASK_GROUP" "$MSG_TASK_INTERVAL" "$MSG_TASK_COUNT" "$MSG_TASK_STATUS" "NEXT"
    msg_info "$mid_sep"

    shopt -s nullglob
    local tasks=("$TASKS_DIR"/*)
    if [[ ${#tasks[@]} -eq 0 ]]; then
        printf "${V} %-75s ${V}\n" " (No tasks found)"
        msg_info "$bot_line"
        return
    fi

    (
        for task_file in "${tasks[@]}"; do
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            if _load_task "$task_id"; then
                local next_run="-" sort_val="" current_time=$(date +%s) diff_sec=999999999
                
                # Format Status (No Emojis)
                local status_fmt="${STATUS^}" # Capitalize first letter

                if [[ "$STATUS" == "running" ]] && [ "$daemon_active" = true ]; then
                    diff_sec=$((INTERVAL - (current_time - LAST_RUN)))
                    [[ $diff_sec -lt 0 ]] && diff_sec=0
                    next_run=$(_format_duration $diff_sec)
                elif [[ "$STATUS" == "running" ]]; then
                    next_run="(off)"
                fi
                
                # Format Name
                local name_display="$task_id"
                [[ "$IS_TEMP" == "true" ]] && name_display="[T] $name_display"
                if [ ${#name_display} -gt 20 ]; then
                    name_display="${name_display:0:17}..."
                fi

                # Format Count
                local count_fmt=""
                if [ "$TARGET_COUNT" -eq -1 ]; then
                    count_fmt="∞"
                else
                    count_fmt="$REMAIN_COUNT/$TARGET_COUNT"
                fi

                local mtime=$(date -r "$task_file" +%s)
                case "$sort_key" in
                    name)    sort_val="$task_id" ;;
                    group)   sort_val="$GROUP" ;;
                    next)    sort_val="$(printf "%012d" $diff_sec)" ;;
                    created) sort_val="$mtime" ;;
                esac
                printf "%s |${V} % -20s ${V} % -10s ${V} % -10s ${V} % -10s ${V} % -10s ${V} % -10s ${V}\n" "$sort_val" "$name_display" "$GROUP" "$(_format_duration $INTERVAL)" "$count_fmt" "$status_fmt" "$next_run"
            fi
        done
    ) | { 
        if [ "$reverse" = true ]; then sort -rV; else sort -V; fi; 
    } | cut -d'|' -f2-
    
    msg_info "$bot_line"
}

_cmd_version() {
    echo "eye version $EYE_VERSION"
}

_cmd_in() {
    local time_str="$1"
    shift
    local msg="$*"
    if [[ -z "$time_str" ]]; then msg_error "Usage: eye in <time> <message>"; return 1; fi
    local interval
    interval=$(_parse_duration "$time_str") || return 1
    local task_id="temp_$(date +%s)_$RANDOM"
    NAME="Reminder"; GROUP="temp"; INTERVAL="$interval"; DURATION=0; TARGET_COUNT=1; REMAIN_COUNT=1
    IS_TEMP=true; SOUND_ENABLE=true; SOUND_START="default"; MSG_START="${msg:-Reminder}"
    LAST_RUN=$(date +%s); STATUS="running"
    if _save_task "$task_id"; then msg_success "Reminder set for $time_str: $MSG_START"; fi
}

_cmd_daemon() {
    local cmd="$1"
    shift
    _load_global_config
    case "$cmd" in
        up)
            if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null;
            then
                msg_warn "Daemon already running."
            else
                _daemon_loop > /dev/null 2>&1 &
                disown
                msg_success "Daemon started."
            fi
            ;; 
        down)
            if [ -f "$PID_FILE" ]; then
                kill $(cat "$PID_FILE") 2>/dev/null
                rm "$PID_FILE"
                msg_success "Daemon stopped."
            else
                msg_info "Daemon not running."
            fi
            ;; 
        default)
            local task="$1"
            if [[ -z "$task" ]]; then echo "Current default task: ${DEFAULT_TASK:-default}"
            else DEFAULT_TASK="$task"; _save_global_config; msg_success "Default task set to: $task"; fi
            ;; 
        enable)
            mkdir -p "$SYSTEMD_DIR"
            local bin_path=$(readlink -f "$0")
            cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Eye Protection Daemon (v2.0)
After=graphical-session.target

[Service]
ExecStart=$bin_path daemon
Restart=on-failure
Environment="PATH=$PATH"

[Install]
WantedBy=default.target
EOF
            systemctl --user daemon-reload
            systemctl --user enable eye.service
            msg_success "Autostart enabled (Systemd)."
            ;; 
        disable) systemctl --user disable eye.service; rm -f "$SERVICE_FILE"; systemctl --user daemon-reload; msg_success "Autostart disabled." ;; 
        quiet) GLOBAL_QUIET="$1"; _save_global_config; msg_success "Quiet mode: $GLOBAL_QUIET" ;; 
        root-cmd) ROOT_CMD="$1"; _save_global_config; msg_success "Root command set to: $ROOT_CMD" ;; 
        language) LANGUAGE="$1"; _save_global_config; msg_success "Language set to: $LANGUAGE" ;; 
        help|*) echo "$MSG_HELP_DAEMON_HEADER"; echo -e "$MSG_HELP_DAEMON_CMDS" ;; 
    esac
}

_cmd_usage() {
    echo "$MSG_USAGE_HEADER"
    echo ""
    echo "$MSG_USAGE_CORE"
    echo "$MSG_USAGE_CMD_START"
    echo "$MSG_USAGE_CMD_STOP"
    echo "$MSG_USAGE_CMD_PAUSE"
    echo "$MSG_USAGE_CMD_RESUME"
    echo "$MSG_USAGE_CMD_NOW"
    echo "$MSG_USAGE_CMD_RESET"
    echo "$MSG_USAGE_CMD_TIME"
    echo "$MSG_USAGE_CMD_COUNT"
    echo ""
    echo "$MSG_USAGE_MANAGE"
    echo "$MSG_USAGE_CMD_ADD"
    echo "$MSG_USAGE_CMD_RM"
    echo "$MSG_USAGE_CMD_EDIT"
    echo "$MSG_USAGE_CMD_LIST"
    echo "$MSG_USAGE_CMD_STATUS"
    echo ""
    echo "$MSG_USAGE_SUB"
    echo "$MSG_USAGE_CMD_DAEMON"
    echo "$MSG_USAGE_CMD_SOUND"
}
