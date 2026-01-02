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
    _execute_task "$task_id" &
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
        msg_info "$MSG_HELP_ADD_USAGE"
        return 1
    fi
    local task_file="$TASKS_DIR/$task_id"
    if [[ -f "$task_file" ]]; then
        msg_warn "Task '$task_id' already exists."
        if ! _prompt_confirm "Overwrite?"; then return; fi
    fi
    local interval="20m" duration="20s" group="default" count="-1" is_temp="false"
    local sound_enable="true" sound_start="default" sound_end="complete" msg_start="" msg_end=""
    if [[ $# -eq 0 ]]; then
        msg_info "Creating task '$task_id'வைக்..."
        _ask_val "$MSG_WIZARD_INTERVAL" "20m" interval
        _ask_val "$MSG_WIZARD_DURATION" "20s" duration
        local dur_sec=$(_parse_duration "$duration")
        if [[ "$dur_sec" -eq 0 ]]; then
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" sound_enable
            [[ "$sound_enable" == "true" ]] && _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" sound_start
            _ask_val "$MSG_WIZARD_MSG_START" "Time is up!" msg_start
        else
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" sound_enable
            if [[ "$sound_enable" == "true" ]]; then
                _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" sound_start
                _ask_val "$(printf "$MSG_WIZARD_SOUND_END" "complete")" "complete" sound_end
            fi
            _ask_val "$MSG_WIZARD_MSG_START" "Look away for ${DURATION}!" msg_start
            _ask_val "$MSG_WIZARD_MSG_END" "Break ended." msg_end
        fi
        _ask_val "Group" "default" group
        _ask_val "$MSG_WIZARD_COUNT" "-1" count
        [[ "$count" -gt 0 ]] && _ask_bool "$MSG_WIZARD_IS_TEMP" "n" is_temp
        if ! _prompt_confirm "$MSG_WIZARD_CONFIRM"; then return; fi
    else
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) interval="$2"; shift 2 ;;
                -d|--duration) duration="$2"; shift 2 ;;
                -g|--group)    group="$2"; shift 2 ;;
                -c|--count)    count="$2"; shift 2 ;;
                --temp)        is_temp="true"; shift ;;
                --sound-start) sound_start="$2"; shift 2 ;;
                --sound-end)   sound_end="$2"; shift 2 ;;
                --msg-start)   msg_start="$2"; shift 2 ;;
                --msg-end)     msg_end="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
    fi
    NAME="$task_id"; GROUP="$group"; INTERVAL=$(_parse_duration "$interval")
    DURATION=$(_parse_duration "$duration"); TARGET_COUNT="$count"; REMAIN_COUNT="$count"
    IS_TEMP="$is_temp"; SOUND_ENABLE="$sound_enable"; SOUND_START="$sound_start"
    SOUND_END="$sound_end"; MSG_START="$msg_start"; MSG_END="$msg_end"
    LAST_RUN=$(date +%s); STATUS="running"
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
        _ask_val "$MSG_WIZARD_INTERVAL" "$interval_fmt" interval_fmt
        INTERVAL=$(_parse_duration "$interval_fmt")
        _ask_val "$MSG_WIZARD_DURATION" "$duration_fmt" duration_fmt
        DURATION=$(_parse_duration "$duration_fmt")
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
    msg_info "$MSG_TASK_LIST_HEADER"
    printf "% -15s % -10s % -10s % -10s % -10s\n" "$MSG_TASK_ID" "$MSG_TASK_GROUP" "$MSG_TASK_INTERVAL" "$MSG_TASK_STATUS" "NEXT"
    echo "---------------------------------------------------------------"
    shopt -s nullglob
    local tasks=("$TASKS_DIR"/*)
    [[ ${#tasks[@]} -eq 0 ]] && { msg_info " (No tasks found)"; return; }
    (
        for task_file in "${tasks[@]}"; do
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            if _load_task "$task_id"; then
                local next_run="-" sort_val="" current_time=$(date +%s) diff_sec=999999999
                if [[ "$STATUS" == "running" ]] && [ "$daemon_active" = true ]; then
                    diff_sec=$((INTERVAL - (current_time - LAST_RUN)))
                    [[ $diff_sec -lt 0 ]] && diff_sec=0
                    next_run=$(_format_duration $diff_sec)
                elif [[ "$STATUS" == "running" ]]; then
                    next_run="(off)"
                fi
                local mtime=$(date -r "$task_file" +%s)
                case "$sort_key" in
                    name)    sort_val="$task_id" ;;
                    group)   sort_val="$GROUP" ;;
                    next)    sort_val="$(printf "%012d" $diff_sec)" ;;
                    created) sort_val="$mtime" ;;
                esac
                printf "%s | % -15s % -10s % -10s % -10s % -10s\n" "$sort_val" "$task_id" "$GROUP" "$(_format_duration $INTERVAL)" "$STATUS" "$next_run"
            fi
        done
    ) | { if [ "$reverse" = true ]; then sort -rV; else sort -V; fi; } | cut -d'|' -f2-
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