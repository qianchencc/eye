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
        _save_task "$task_id"
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
    # If resuming/starting, reset LAST_RUN?
    # Spec says "start ... used for start default task".
    # Usually start implies active.
    msg_info "Task $id -> $new_status"
}

_cb_time_shift() {
    local id="$1"
    local delta_str="$2"
    # delta_str e.g. -10m, +1h, 20s
    local sign="${delta_str:0:1}"
    local val_str="$delta_str"
    
    if [[ "$sign" == "+" || "$sign" == "-" ]]; then
        val_str="${delta_str:1}"
    else
        sign="+" # Default forward? Or set? Spec says "forward... use -10m to backward"
    fi
    
    local seconds=$(_parse_duration "$val_str")
    if [ $? -ne 0 ]; then return; fi
    
    if [[ "$sign" == "-" ]]; then
        # Backward: Increase LAST_RUN (so diff becomes smaller? No.)
        # now - LAST_RUN = elapsed.
        # We want elapsed to be smaller (backward time) -> LAST_RUN bigger?
        # Wait. 
        # "Fast forward" -> elapsed bigger -> LAST_RUN smaller.
        # "Backward" -> elapsed smaller -> LAST_RUN bigger.
        
        # Spec: "Fast forward default task ... use -10m to backward"
        # So +10m means we want to trigger sooner? Or we pretend 10m passed?
        # Usually "Time +10m" means "Add 10m to elapsed time".
        # Elapsed = Now - LAST_RUN.
        # NewElapsed = Elapsed + 10m.
        # Now - NewLastRun = (Now - OldLastRun) + 10m
        # NewLastRun = OldLastRun - 10m.
        
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
    # Spec: "start, stop @<group>: used for start/stop default task or specific group"
    _apply_to_tasks "$target" _cb_set_status "running"
}

_cmd_stop() {
    local target="${1:-@$(_get_default_target)}"
    _apply_to_tasks "$target" _cb_set_status "stopped"
}

_cmd_pause() {
    local target="$1"
    local all_flag=false
    
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
        # Default task? Spec: "optional <task>"
        # If no task, try default task
        local def=$(_get_default_target)
        if [[ -f "$TASKS_DIR/$def" ]]; then
             task_id="$def"
        else
             msg_error "Usage: eye now <task_id> (No default task found)"
             return 1
        fi
    fi
    
    msg_info "Triggering $task_id immediately..."
    _execute_task "$task_id"
}

_cmd_time() {
    local delta="$1"
    local target="${2:-@$(_get_default_target)}"
    
    if [[ -z "$delta" ]]; then
        msg_error "Usage: eye time <delta> [task]"
        return 1
    fi
    
    _apply_to_tasks "$target" _cb_time_shift "$delta"
}

_cmd_count() {
    local delta="$1"
    local target="${2:-@$(_get_default_target)}"
    
    if [[ -z "$delta" ]]; then
        msg_error "Usage: eye count <delta> [task]"
        return 1
    fi
    
    _apply_to_tasks "$target" _cb_count_shift "$delta"
}

_cmd_reset() {
    local target=""
    local do_time=false
    local do_count=false
    
    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --time) do_time=true ;; 
            --count) do_count=true ;; 
            -*) msg_error "Unknown option: $1"; return 1 ;; 
            *) target="$1" ;; 
        esac
        shift
    done
    
    if [[ "$do_time" == "false" && "$do_count" == "false" ]]; then
        # If neither specified, maybe default to both? Or show help?
        # Spec says: "reset directly -> help"
        msg_error "Usage: eye reset <target> --time --count"
        return 1
    fi
    
    target="${target:-@$(_get_default_target)}"
    _apply_to_tasks "$target" _cb_reset "$do_time" "$do_count"
}

_cmd_add() {
    local task_id="$1"
    shift
    
    if [[ -z "$task_id" ]]; then
        msg_error "$MSG_HELP_ADD_USAGE"
        return 1
    fi

    local task_file="$TASKS_DIR/$task_id"
    if [[ -f "$task_file" ]]; then
        msg_warn "Task '$task_id' already exists."
        if ! _prompt_confirm "Overwrite?"; then
            return
        fi
    fi

    # Defaults
    local interval="20m"
    local duration="20s"
    local group="default"
    local count="-1"
    local is_temp="false"
    local sound_enable="true"
    local sound_start="default"
    local sound_end="complete"
    local msg_start=""
    local msg_end=""

    if [[ $# -eq 0 ]]; then
        # === Interactive Wizard ===
        msg_info "Creating task '$task_id'..."

        # 1. Timing
        _ask_val "$MSG_WIZARD_INTERVAL" "20m" interval
        _ask_val "$MSG_WIZARD_DURATION" "20s" duration
        
        local dur_sec=$(_parse_duration "$duration")
        
        # 2. Sound & Messages
        if [[ "$dur_sec" -eq 0 ]]; then
            # Pulse Task
            echo ">> Pulse Task (No duration)"
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" sound_enable
            if [[ "$sound_enable" == "true" ]]; then
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" sound_start
            fi
            _ask_val "$MSG_WIZARD_MSG_START" "Time is up!" msg_start
        else
            # Periodic Task
            echo ">> Periodic Task"
            _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" sound_enable
             if [[ "$sound_enable" == "true" ]]; then
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" sound_start
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_END" "complete")" "complete" sound_end
            fi
            _ask_val "$MSG_WIZARD_MSG_START" "Look away for \${DURATION}!" msg_start
            _ask_val "$MSG_WIZARD_MSG_END" "Break ended." msg_end
        fi
        
        # 3. Group
        _ask_val "Group" "default" group

        # 4. Count & Lifecycle
        _ask_val "$MSG_WIZARD_COUNT" "-1" count
        if [[ "$count" -gt 0 ]]; then
             _ask_bool "$MSG_WIZARD_IS_TEMP" "n" is_temp
        fi

        if ! _prompt_confirm "$MSG_WIZARD_CONFIRM"; then
            return
        fi
    else
        # === Flag Parsing ===
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) interval="$2"; shift 2 ;;
                -d|--duration) duration="$2"; shift 2 ;;
                -g|--group)    group="$2"; shift 2 ;;
                -c|--count)    count="$2"; shift 2 ;;
                --temp)        is_temp="true"; shift ;;
                --sound-on)    sound_enable="true"; shift ;;
                --sound-off)   sound_enable="false"; shift ;;
                --sound-start) sound_start="$2"; shift 2 ;;
                --sound-end)   sound_end="$2"; shift 2 ;;
                --msg-start)   msg_start="$2"; shift 2 ;;
                --msg-end)     msg_end="$2"; shift 2 ;;
                *) msg_warn "Unknown option: $1"; shift ;;
            esac
        done
    fi

    # Save
    NAME="$task_id"
    GROUP="$group"
    INTERVAL=$(_parse_duration "$interval")
    DURATION=$(_parse_duration "$duration")
    TARGET_COUNT="$count"
    REMAIN_COUNT="$count"
    IS_TEMP="$is_temp"
    SOUND_ENABLE="$sound_enable"
    SOUND_START="$sound_start"
    SOUND_END="$sound_end"
    MSG_START="$msg_start"
    MSG_END="$msg_end"
    LAST_RUN=$(date +%s)
    STATUS="running"

    if _save_task "$task_id"; then
        msg_success "$(printf "$MSG_TASK_CREATED" "$task_id")"
    fi
}

_cmd_edit() {
    local task_id="$1"
    shift
    local task_file="$TASKS_DIR/$task_id"
    
    if [[ ! -f "$task_file" ]]; then
        msg_error "$(printf "$MSG_TASK_NOT_FOUND" "$task_id")"
        return 1
    fi
    
    _load_task "$task_id"
    
    if [[ $# -gt 0 ]]; then
        # Flags Edit
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) INTERVAL=$(_parse_duration "$2"); shift 2 ;;
                -d|--duration) DURATION=$(_parse_duration "$2"); shift 2 ;;
                -g|--group)    GROUP="$2"; shift 2 ;;
                -c|--count)    TARGET_COUNT="$2"; REMAIN_COUNT="$2"; shift 2 ;;
                --temp)        IS_TEMP="true"; shift ;;
                --no-temp)     IS_TEMP="false"; shift ;;
                --sound-on)    SOUND_ENABLE="true"; shift ;;
                --sound-off)   SOUND_ENABLE="false"; shift ;;
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
        # Interactive Edit (Wizard-like, pre-filled)
        msg_info "Editing '$task_id' (Enter to keep current value)..."
        
        local interval_fmt=$(_format_duration "$INTERVAL")
        local duration_fmt=$(_format_duration "$DURATION")
        
        _ask_val "$MSG_WIZARD_INTERVAL" "$interval_fmt" interval_fmt
        INTERVAL=$(_parse_duration "$interval_fmt")
        
        _ask_val "$MSG_WIZARD_DURATION" "$duration_fmt" duration_fmt
        DURATION=$(_parse_duration "$duration_fmt")
        
        # Check Pulse/Periodic again
        if [[ "$DURATION" -eq 0 ]]; then
             echo ">> Pulse Task Mode"
             _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "$SOUND_ENABLE" SOUND_ENABLE
             if [[ "$SOUND_ENABLE" == "true" ]]; then
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "$SOUND_START")" "$SOUND_START" SOUND_START
             fi
             _ask_val "$MSG_WIZARD_MSG_START" "${MSG_START:-Time is up!}" MSG_START
        else
             echo ">> Periodic Task Mode"
             _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "$SOUND_ENABLE" SOUND_ENABLE
             if [[ "$SOUND_ENABLE" == "true" ]]; then
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "$SOUND_START")" "$SOUND_START" SOUND_START
                 _ask_val "$(printf "$MSG_WIZARD_SOUND_END" "$SOUND_END")" "$SOUND_END" SOUND_END
             fi
             _ask_val "$MSG_WIZARD_MSG_START" "${MSG_START:-Look away!}" MSG_START
             _ask_val "$MSG_WIZARD_MSG_END" "${MSG_END:-Break ended.}" MSG_END
        fi
        
        _ask_val "Group" "$GROUP" GROUP
        _ask_val "$MSG_WIZARD_COUNT" "$TARGET_COUNT" TARGET_COUNT
        # Update REMAIN_COUNT only if TARGET changed? Or reset it? 
        # Usually edit resets count if user explicitly changes it, but here we just set what user wants.
        # Let's ask if they want to reset remaining count? 
        # For simplicity, if they change target count, we probably should reset remaining count, 
        # but difficult to detect change easily in bash without old var.
        # Let's just update REMAIN_COUNT to TARGET_COUNT if TARGET_COUNT > 0
        if [[ "$TARGET_COUNT" -gt 0 ]]; then
             REMAIN_COUNT="$TARGET_COUNT"
             _ask_bool "$MSG_WIZARD_IS_TEMP" "$IS_TEMP" IS_TEMP
        else
             REMAIN_COUNT="-1"
        fi
        
        if _save_task "$task_id"; then
             msg_success "Task updated."
        fi
    fi
}

_cmd_list() {
    msg_info "$MSG_TASK_LIST_HEADER"
    printf "% -15s % -10s % -10s % -10s % -10s\n" "$MSG_TASK_ID" "$MSG_TASK_GROUP" "$MSG_TASK_INTERVAL" "$MSG_TASK_STATUS" "NEXT"
    echo "---------------------------------------------------------------"
    
    for task_file in "$TASKS_DIR"/*;
    do
        [ -e "$task_file" ] || continue
        task_id=$(basename "$task_file")
        if _load_task "$task_id"; then
            local next_run="-"
            if [[ "$STATUS" == "running" ]]; then
                local current_time=$(date +%s)
                local diff=$((INTERVAL - (current_time - LAST_RUN)))
                [[ $diff -lt 0 ]] && diff=0
                next_run=$(_format_duration $diff)
            fi
            printf "% -15s % -10s % -10s % -10s % -10s\n" "$task_id" "$GROUP" "$(_format_duration $INTERVAL)" "$STATUS" "$next_run"
        fi
    done
}

_cmd_status() {
    # Sort by group, name, creation time (we use mtime as creation/mod time proxy)
    # This requires collecting data first.
    
    if [ ! -t 1 ]; then
        # Machine readable (simple)
        echo "daemon_running=$( [ -f "$PID_FILE" ] && echo true || echo false )"
        return
    fi
    
    # Daemon Status
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null;
    then
        msg_success "● Daemon: Active (PID: $(cat "$PID_FILE"))"
    else
        msg_error "● Daemon: Inactive"
    fi
    
    echo ""
    _cmd_list | sort -k2,2 -k1,1  # Simple sort by Group then ID
}

_cmd_in() {
    local time_str="$1"
    shift
    local msg="$*"
    # ... reused existing logic ...
    if [[ -z "$time_str" ]]; then
        msg_error "Usage: eye in <time> <message>"
        return 1
    fi
    local interval
    interval=$(_parse_duration "$time_str") || return 1
    local task_id="temp_$(date +%s)_$RANDOM"
    NAME="Reminder"
    GROUP="temp"
    INTERVAL="$interval"
    DURATION=0
    TARGET_COUNT=1
    REMAIN_COUNT=1
    IS_TEMP=true
    SOUND_ENABLE=true
    SOUND_START="default"
    MSG_START="${msg:-Reminder}"
    LAST_RUN=$(date +%s)
    STATUS="running"
    if _save_task "$task_id"; then
        msg_success "Reminder set for $time_str: $MSG_START"
    fi
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
            if [[ -z "$task" ]]; then
                echo "Current default task: ${DEFAULT_TASK:-default}"
            else
                DEFAULT_TASK="$task"
                _save_global_config
                msg_success "Default task set to: $task"
            fi
            ;; 
        enable)
            # Create systemd service
            mkdir -p "$SYSTEMD_DIR"
            # Resolve absolute path to bin/eye (or where it is installed)
            local bin_path=$(readlink -f "$0") # $0 is usually the script
            # Note: In dev mode via symlink, this works. In prod, it works.
            
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
        disable)
            systemctl --user disable eye.service
            rm -f "$SERVICE_FILE"
            systemctl --user daemon-reload
            msg_success "Autostart disabled."
            ;; 
        quiet)
            GLOBAL_QUIET="$1"
            _save_global_config
            msg_success "Quiet mode: $GLOBAL_QUIET"
            ;; 
        root-cmd)
            ROOT_CMD="$1"
            _save_global_config
            msg_success "Root command set to: $ROOT_CMD"
            ;; 
        language)
             LANGUAGE="$1"
             _save_global_config
             msg_success "Language set to: $LANGUAGE"
             ;; 
        help|*)
            echo "$MSG_HELP_DAEMON_HEADER"
            echo -e "$MSG_HELP_DAEMON_CMDS"
            ;; 
    esac
}

_cmd_usage() {
    # Main Help
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
