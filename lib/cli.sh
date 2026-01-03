#!/bin/bash

# ================= 命令行界面逻辑 (lib/cli.sh) =================

# --- 内部辅助 ---

_get_default_target() {
    echo "${DEFAULT_TASK:-eye_rest}"
}

_apply_to_tasks() {
    local target_arg="$1" 
    local callback="$2"
    shift 2
    local args=($@)
    local matched=0
    local targets=()

    # Determine targets: from argument or stdin
    if [[ -n "$target_arg" ]]; then
        targets+=("$target_arg")
    elif [[ ! -t 0 ]]; then
        # Read from stdin (one target per line or space-separated)
        while read -r line; do
            for word in $line; do
                targets+=("$word")
            done
        done
    else
        # Fallback to default
        targets+=("@$(_get_default_target)")
    fi
    
    shopt -s nullglob
    for task_file in "$TASKS_DIR"/*; do
        [[ $(basename "$task_file") == .* ]] && continue
        [ -e "$task_file" ] || continue
        local task_id=$(basename "$task_file")
        
        local task_matches=0
        for t in "${targets[@]}"; do
            if [[ "$t" == "--all" ]]; then
                task_matches=1; break
            elif [[ "$t" == @* ]]; then
                local group_pattern="${t#@}"
                _load_task "$task_id"
                if [[ "$EYE_T_GROUP" =~ ^${group_pattern}$ ]]; then
                    task_matches=1; break
                fi
            else
                if [[ "$task_id" == "$t" ]]; then
                    task_matches=1; break
                fi
            fi
        done

        [[ $task_matches -eq 0 ]] && continue
        
        matched=1
        _load_task "$task_id"
        "$callback" "$task_id" "${args[@]}"
        [ -f "$TASKS_DIR/$task_id" ] && _save_task "$task_id"
    done

    [ $matched -eq 0 ] && msg_warn "No tasks matched targets: ${targets[*]}"
}

# --- CLI 回调 (调用 core.sh 逻辑并负责 UI 反馈) ---

_cb_cli_start() {
    local id="$1"
    _core_task_start "$id"
    msg_info "Task $id -> running"
}

_cb_cli_stop() {
    local id="$1"
    local duration="$2"
    _core_task_pause "$id" "$duration"
    if [[ -n "$duration" ]]; then
        msg_info "Task $id paused for $duration (Until $(date -d "@$EYE_T_RESUME_AT" "+%H:%M:%S"))."
    else
        msg_info "Task $id paused indefinitely."
    fi
}

_cb_cli_resume() {
    local id="$1"
    _core_task_resume "$id"
    msg_info "Task $id -> running"
}

_cb_cli_time_shift() {
    local id="$1"
    local delta="$2"
    if _core_task_time_shift "$id" "$delta"; then
        msg_success "Task $id time shifted (New Next: $(_format_duration $((EYE_T_INTERVAL - ($(date +%s) - EYE_T_LAST_RUN)))) )"
    fi
}

_cb_cli_count_shift() {
    local id="$1"
    local delta="$2"
    if _core_task_count_shift "$id" "$delta"; then
        msg_success "Task $id count shifted by $delta (Now: $EYE_T_REMAIN_COUNT)"
    else
        msg_error "$(printf "$MSG_ERROR_INFINITE_COUNT" "$id")"
    fi
}

_cb_cli_reset() {
    local id="$1"
    _core_task_reset "$id" "$2" "$3"
    [[ "$2" == "true" ]] && msg_info "Task $id timer reset."
    [[ "$3" == "true" && "$EYE_T_TARGET_COUNT" -gt 0 ]] && msg_info "Task $id count reset."
}

_cb_cli_remove() {
    local id="$1"
    rm -f "$TASKS_DIR/$id"
    msg_success "Task '$id' removed."
}

# --- 指令入口 ---

_cmd_start() {
    local target="$1"
    if [[ "$target" == "help" || "$target" == "-h" ]]; then
        msg_info "$MSG_USAGE_CMD_START"
        return
    fi
    if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    
    _apply_to_tasks "$target" _cb_cli_start
    _apply_to_tasks "$target" _cb_cli_reset "true" "false"
}

_cmd_stop() {
    local arg1="$1" arg2="$2"
    local target="" duration=""
    
    if [[ "$arg1" == "help" || "$arg1" == "-h" ]]; then
        msg_info "$MSG_HELP_STOP_USAGE"
        return
    fi

    if [[ -z "$arg1" ]]; then
        if [[ -t 0 ]]; then
            target="@$(_get_default_target)"
        else
            target="" 
        fi
    elif [[ "$arg1" == "--all" || "$arg1" == "-a" ]]; then
        target="--all"; duration="$arg2"
    elif [[ "$arg1" =~ ^[0-9]+[smhd]$ || "$arg1" =~ ^[0-9]+$ ]]; then
        duration="$arg1"; target="${arg2:-}"
        if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    else
        target="$arg1"; duration="$arg2"
    fi
    _apply_to_tasks "$target" _cb_cli_stop "$duration"
}

_cmd_resume() {
    local target="$1"
    if [[ "$target" == "help" || "$target" == "-h" ]]; then
        msg_info "$MSG_USAGE_CMD_RESUME"
        return
    fi
    if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    [[ "$target" == "--all" || "$target" == "-a" ]] && target="--all"
    _apply_to_tasks "$target" _cb_cli_resume
}

_cmd_now() {
    local task_id="$1"
    if [[ "$task_id" == "help" || "$task_id" == "-h" ]]; then
        msg_info "$MSG_USAGE_CMD_NOW"
        return
    fi
    
    if [[ -z "$task_id" ]]; then
        if [[ -t 0 ]]; then
            task_id=$(_get_default_target)
        else
            task_id=$(_read_input)
        fi
    fi
    
    for tid in $task_id; do
        if [[ -f "$TASKS_DIR/$tid" ]]; then
            msg_info "Triggering $tid immediately..."
            ( _load_task "$tid" && _execute_task "$tid" ) &
        else
            msg_error "Task not found: $tid"
        fi
    done
}

_cmd_time() {
    local delta="$1" target="$2"
    if [[ -z "$delta" || "$delta" == "help" || "$delta" == "-h" ]]; then
        msg_info "Usage: eye time <delta> [target]"
        return
    fi
    if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    _apply_to_tasks "$target" _cb_cli_time_shift "$delta"
}

_cmd_count() {
    local delta="$1" target="$2"
    if [[ -z "$delta" || "$delta" == "help" || "$delta" == "-h" ]]; then
        msg_info "Usage: eye count <delta> [target]"
        return
    fi
    if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    _apply_to_tasks "$target" _cb_cli_count_shift "$delta"
}

_cmd_reset() {
    local target="" do_time=false do_count=false
    if [[ "$1" == "help" || "$1" == "-h" ]]; then
        msg_info "Usage: eye reset [target] --time --count"
        return
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --time|-t) do_time=true ;; 
            --count|-c) do_count=true ;; 
            *) target="$1" ;; 
        esac
        shift
    done
    if [[ -z "$target" && -t 0 ]]; then target="@$(_get_default_target)"; fi
    _apply_to_tasks "$target" _cb_cli_reset "$do_time" "$do_count"
}

_cmd_add() {
    local task_ids=()
    local options=()
    
    # Parse IDs first (before flags)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*) break ;;
            *) task_ids+=("$1"); shift ;;
        esac
    done

    # If no IDs in args, check stdin
    if [[ ${#task_ids[@]} -eq 0 && ! -t 0 ]]; then
        while read -r line; do
            for word in $line; do task_ids+=("$word"); done
        done
    fi

    if [[ ${#task_ids[@]} -eq 0 ]]; then
        msg_info "$MSG_HELP_ADD_USAGE"
        return
    fi
    
    # The rest are options
    options=("$@")

    for tid in "${task_ids[@]}"; do
        _execute_add_single "$tid" "${options[@]}"
    done
}

_execute_add_single() {
    local task_id="$1"
    shift
    local task_file="$TASKS_DIR/$task_id"
    if [[ -f "$task_file" ]]; then
        msg_warn "Task '$task_id' already exists. Skipping."
        return
    fi
    
    EYE_T_NAME="$task_id"; EYE_T_GROUP="default"; EYE_T_INTERVAL=1200; EYE_T_DURATION=20
    EYE_T_TARGET_COUNT=-1; EYE_T_REMAIN_COUNT=-1; EYE_T_IS_TEMP=false; EYE_T_SOUND_ENABLE=true
    EYE_T_SOUND_START="default"; EYE_T_SOUND_END="complete"; EYE_T_MSG_START=""; EYE_T_MSG_END=""
    EYE_T_LAST_RUN=0; EYE_T_CREATED_AT=$(date +%s); EYE_T_LAST_TRIGGER_AT=0; EYE_T_STATUS="running"

    if [[ $# -eq 0 && -t 0 ]]; then
        local tmp_val
        _ask_val "$MSG_WIZARD_INTERVAL" "20m" tmp_val
        EYE_T_INTERVAL=$(_parse_duration "$tmp_val") || return 1
        _ask_val "$MSG_WIZARD_DURATION" "20s" tmp_val
        EYE_T_DURATION=$(_parse_duration "$tmp_val") || return 1
        _ask_bool "$MSG_WIZARD_SOUND_ENABLE" "y" EYE_T_SOUND_ENABLE
        if [[ "$EYE_T_SOUND_ENABLE" == "true" ]]; then
            _ask_val "$(printf "$MSG_WIZARD_SOUND_START" "default")" "default" EYE_T_SOUND_START
            [[ "$EYE_T_DURATION" -gt 0 ]] && _ask_val "$(printf "$MSG_WIZARD_SOUND_END" "complete")" "complete" EYE_T_SOUND_END
        fi
        _ask_val "$MSG_WIZARD_MSG_START" "Start message" EYE_T_MSG_START
        [[ "$EYE_T_DURATION" -gt 0 ]] && _ask_val "$MSG_WIZARD_MSG_END" "End message" EYE_T_MSG_END
        _ask_val "Group" "default" EYE_T_GROUP
        _ask_val "$MSG_WIZARD_COUNT" "-1" EYE_T_TARGET_COUNT
        EYE_T_REMAIN_COUNT="$EYE_T_TARGET_COUNT"
        [[ "$EYE_T_TARGET_COUNT" -gt 0 ]] && _ask_bool "$MSG_WIZARD_IS_TEMP" "n" EYE_T_IS_TEMP
        _prompt_confirm "$MSG_WIZARD_CONFIRM" || { msg_info "Cancelled."; return; }
    else
        # Flag mode
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) EYE_T_INTERVAL=$(_parse_duration "$2"); shift 2 ;; 
                -d|--duration) EYE_T_DURATION=$(_parse_duration "$2"); shift 2 ;; 
                -g|--group)    EYE_T_GROUP="$2"; shift 2 ;; 
                -c|--count)    EYE_T_TARGET_COUNT="$2"; EYE_T_REMAIN_COUNT="$2"; shift 2 ;; 
                --temp)        EYE_T_IS_TEMP="true"; shift ;; 
                --sound-start) EYE_T_SOUND_START="$2"; shift 2 ;; 
                --sound-end)   EYE_T_SOUND_END="$2"; shift 2 ;; 
                --msg-start)   EYE_T_MSG_START="$2"; shift 2 ;; 
                --msg-end)     EYE_T_MSG_END="$2"; shift 2 ;; 
                *) shift ;; 
            esac
        done
    fi
    _save_task "$task_id" && msg_success "$(printf "$MSG_TASK_CREATED" "$task_id")"
}

_cmd_edit() {
    local task_id="$1"; shift
    [[ -z "$task_id" || "$task_id" == "help" || "$task_id" == "-h" ]] && { msg_info "$MSG_HELP_EDIT_USAGE"; return; }
    [[ ! -f "$TASKS_DIR/$task_id" ]] && { msg_error "$(printf "$MSG_TASK_NOT_FOUND" "$task_id")"; return 1; }
    _load_task "$task_id"
    if [[ $# -gt 0 ]]; then
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--interval) EYE_T_INTERVAL=$(_parse_duration "$2"); shift 2 ;; 
                -d|--duration) EYE_T_DURATION=$(_parse_duration "$2"); shift 2 ;; 
                -g|--group)    EYE_T_GROUP="$2"; shift 2 ;; 
                -c|--count)    EYE_T_TARGET_COUNT="$2"; EYE_T_REMAIN_COUNT="$2"; shift 2 ;; 
                --temp)        EYE_T_IS_TEMP="true"; shift ;; 
                --no-temp)     EYE_T_IS_TEMP="false"; shift ;; 
                --sound-on)    EYE_T_SOUND_ENABLE="true"; shift ;;
                --sound-off)   EYE_T_SOUND_ENABLE="false"; shift ;;
                --sound-start) EYE_T_SOUND_START="$2"; shift 2 ;; 
                --sound-end)   EYE_T_SOUND_END="$2"; shift 2 ;; 
                --msg-start)   EYE_T_MSG_START="$2"; shift 2 ;; 
                --msg-end)     EYE_T_MSG_END="$2"; shift 2 ;; 
                *) shift ;; 
            esac
        done
        _save_task "$task_id" && msg_success "Task updated."
    else
        local tmp_val
        _ask_val "$MSG_WIZARD_INTERVAL" "$(_format_duration "$EYE_T_INTERVAL")" tmp_val
        EYE_T_INTERVAL=$(_parse_duration "$tmp_val")
        _ask_val "$MSG_WIZARD_DURATION" "$(_format_duration "$EYE_T_DURATION")" tmp_val
        EYE_T_DURATION=$(_parse_duration "$tmp_val")
        _ask_val "Group" "$EYE_T_GROUP" EYE_T_GROUP
        _ask_val "$MSG_WIZARD_COUNT" "$EYE_T_TARGET_COUNT" EYE_T_TARGET_COUNT
        [[ "$EYE_T_TARGET_COUNT" -gt 0 ]] && EYE_T_REMAIN_COUNT="$EYE_T_TARGET_COUNT" || EYE_T_REMAIN_COUNT="-1"
        _ask_bool "Enable Sound" "$( [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && echo "y" || echo "n" )" EYE_T_SOUND_ENABLE
        _ask_val "Sound Start" "$EYE_T_SOUND_START" EYE_T_SOUND_START
        _ask_val "Sound End" "$EYE_T_SOUND_END" EYE_T_SOUND_END
        _ask_val "Message Start" "$EYE_T_MSG_START" EYE_T_MSG_START
        _ask_val "Message End" "$EYE_T_MSG_END" EYE_T_MSG_END
        _save_task "$task_id" && msg_success "Task updated."
    fi
}

_cmd_remove() {
    local target="$1"
    if [[ -z "$target" && -t 0 ]]; then
        msg_error "Usage: eye remove <target>"
        return 1
    fi
    _apply_to_tasks "$target" _cb_cli_remove
}

_cmd_group() {
    local task_id="$1"
    local new_group="$2"
    
    if [[ "$task_id" == "help" || "$task_id" == "-h" ]]; then
        msg_info "$MSG_HELP_GROUP_USAGE"
        return
    fi

    if [[ ! -t 0 ]]; then
        # Piped mode: $1 is the new group, IDs come from stdin
        new_group="$1"
        task_id="" # _apply_to_tasks will read from stdin
    fi

    if [[ -z "$task_id" && -t 0 ]]; then
        msg_error "Usage: eye group <task_id> [group_name]"
        return 1
    fi
    
    if [[ -z "$new_group" || "$new_group" == "none" ]]; then new_group="default"; fi
    _apply_to_tasks "$task_id" _cb_group_logic "$new_group"
}

_cb_group_logic() {
    local id="$1"; local new_group="$2"; local old_group="$EYE_T_GROUP"
    EYE_T_GROUP="$new_group"
    if [[ "$new_group" == "default" ]]; then msg_success "Task '$id' moved to default group (unassigned)."
    else msg_success "Task '$id' moved from '$old_group' to '$new_group'."; fi
}

_cmd_status() {
    local sort_key="next" reverse=false long_format=false target_task=""
    if [[ -n "$1" && "$1" != -* && "$1" != "help" ]]; then
        [[ -f "$TASKS_DIR/$1" ]] && { target_task="$1"; shift; }
    fi
    [[ "$1" == "help" || "$1" == "-h" ]] && { msg_info "$MSG_HELP_STATUS_USAGE"; return; }
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sort|-s) sort_key="$2"; shift 2 ;; 
            --reverse|-r) reverse=true; shift ;; 
            --long|-l) long_format=true; shift ;; 
            *) shift ;; 
        esac
    done
    local daemon_active=false ref_time=$(date +%s)
    [[ -f "$PID_FILE" ]] && kill -0 $(cat "$PID_FILE") 2>/dev/null && daemon_active=true
    if [[ "$daemon_active" != "true" ]]; then
        [[ -f "$STOP_FILE" ]] && ref_time=$(cat "$STOP_FILE") || ref_time=$(stat -c %Y "$TASKS_DIR" 2>/dev/null || date +%s)
    fi
    if [[ -n "$target_task" ]]; then
        [[ ! -t 1 ]] && { source "$TASKS_DIR/$target_task" && env | grep "^EYE_T_"; return; }
        _load_task "$target_task"
        local created_fmt="Never" trigger_fmt="Never"
        [[ "${EYE_T_CREATED_AT:-0}" -gt 0 ]] && created_fmt=$(date -d "@$EYE_T_CREATED_AT" "+%Y-%m-%d %H:%M:%S")
        [[ "${EYE_T_LAST_TRIGGER_AT:-0}" -gt 0 ]] && trigger_fmt=$(date -d "@$EYE_T_LAST_TRIGGER_AT" "+%Y-%m-%d %H:%M:%S")
        local effective_ref=$ref_time
        [[ "$EYE_T_STATUS" == "paused" ]] && effective_ref=${EYE_T_PAUSE_TS:-$ref_time}
        local next_val=$((EYE_T_INTERVAL - (effective_ref - EYE_T_LAST_RUN)))
        [[ $next_val -lt 0 ]] && next_val=0
        local labels=("ID" "GROUP" "INTERVAL" "DURATION" "COUNT" "TEMP" "SOUND" "S-START" "S-END" "STATUS" "NEXT" "CREATED" "L-TRIGGER")
        local values=("$target_task" "$EYE_T_GROUP" "$(_format_duration $EYE_T_INTERVAL)" "$(_format_duration $EYE_T_DURATION)" "$EYE_T_REMAIN_COUNT/$EYE_T_TARGET_COUNT" "$EYE_T_IS_TEMP" "$EYE_T_SOUND_ENABLE" "$EYE_T_SOUND_START" "$EYE_T_SOUND_END" "${EYE_T_STATUS^}" "$(_format_duration $next_val)" "$created_fmt" "$trigger_fmt")
        echo "┌$(printf '─%.0s' {1..40})┐"
        for i in "${!labels[@]}"; do printf "│ %-10s : %-25s │\n" "${labels[$i]}" "${values[$i]}"; done
        echo "└$(printf '─%.0s' {1..40})┘"
        return
    fi
    local rows=()
    shopt -s nullglob
    local tasks=("$TASKS_DIR"/*)
    if [[ ! -t 1 ]] && [[ -z "$target_task" ]]; then
        for task_file in "${tasks[@]}"; do [[ $(basename "$task_file") == .* ]] && continue; basename "$task_file"; done
        return
    fi
    [ "$daemon_active" = "true" ] && msg_success "● Daemon: Active (PID: $(cat "$PID_FILE"))" || msg_error "● Daemon: Inactive"
    if [ ! -t 1 ] && [ -z "$target_task" ]; then echo "$MSG_TASK_LIST_HEADER"; fi
    echo ""
    [[ ${#tasks[@]} -eq 0 ]] && { echo " (No tasks found)"; return; }
    for task_file in "${tasks[@]}"; do
        [[ $(basename "$task_file") == .* ]] && continue
        local tid=$(basename "$task_file")
        if _load_task "$tid"; then
            local effective_ref=$ref_time
            [[ "$EYE_T_STATUS" == "paused" ]] && effective_ref=${EYE_T_PAUSE_TS:-$ref_time}
            local diff_sec=$((EYE_T_INTERVAL - (effective_ref - EYE_T_LAST_RUN)))
            [[ $diff_sec -lt 0 ]] && diff_sec=0
            local name_display="$tid"
            [[ "$EYE_T_IS_TEMP" == "true" ]] && name_display="[T]$tid"
            local sort_val=""
            case "$sort_key" in
                name)    sort_val="$tid" ;; 
                group)   sort_val="$EYE_T_GROUP" ;; 
                next)    sort_val="$(printf "%012d" $diff_sec)" ;; 
                created) sort_val=$(date -r "$task_file" +%s) ;; 
            esac
            if [[ "$long_format" == "true" ]]; then
                rows+=("$sort_val@$name_display@$EYE_T_GROUP@$(_format_duration $EYE_T_INTERVAL)@$(_format_duration $EYE_T_DURATION)@($EYE_T_REMAIN_COUNT/$EYE_T_TARGET_COUNT)@${EYE_T_STATUS^}@$(_format_duration $diff_sec)")
            else
                rows+=("$sort_val@${EYE_T_STATUS^}@$name_display@$(_format_duration $EYE_T_INTERVAL)/$(_format_duration $EYE_T_DURATION)@($EYE_T_REMAIN_COUNT/$EYE_T_TARGET_COUNT)@$(_format_duration $diff_sec)@$EYE_T_GROUP")
            fi
        fi
    done
    local sorted_data
    [[ "$reverse" == "true" ]] && sorted_data=$(printf "%s\n" "${rows[@]}" | sort -rV | cut -d'@' -f2-) || sorted_data=$(printf "%s\n" "${rows[@]}" | sort -V | cut -d'@' -f2-)
    if [[ "$long_format" == "true" ]]; then printf "%s\n" "$sorted_data" | column -t -s '@' -o ' │ '
    else printf "%s\n" "$sorted_data" | column -t -s '@' -o '  '; fi
}

_cmd_in() {
    local time_str="$1"; shift; local msg="$*"
    [[ -z "$time_str" ]] && { msg_error "Usage: eye in <time> <message>"; return 1; }
    local interval=$(_parse_duration "$time_str") || return 1
    local task_id="temp_$(date +%s)_$RANDOM"
    EYE_T_NAME="Reminder"; EYE_T_GROUP="temp"; EYE_T_INTERVAL="$interval"; EYE_T_DURATION=0
    EYE_T_TARGET_COUNT=1; EYE_T_REMAIN_COUNT=1; EYE_T_IS_TEMP=true; EYE_T_SOUND_ENABLE=true
    EYE_T_SOUND_START="default"; EYE_T_MSG_START="${msg:-Reminder}"; EYE_T_LAST_RUN=0; EYE_T_CREATED_AT=$(date +%s); EYE_T_STATUS="running"
    _save_task "$task_id" && msg_success "Reminder set for $time_str: $EYE_T_MSG_START"
}

_cmd_daemon() {
    local cmd="$1"; shift
    _load_global_config
    case "$cmd" in
        up)
            if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then msg_warn "Daemon already running."
            else _daemon_loop > /dev/null 2>&1 & disown; msg_success "Daemon started."; fi ;; 
        down)
            if [ -f "$PID_FILE" ]; then date +%s > "$STOP_FILE"; kill $(cat "$PID_FILE") 2>/dev/null; rm "$PID_FILE"; msg_success "Daemon stopped."
            else msg_info "Daemon not running."; fi ;; 
        uninstall)
            msg_info "🚀 Starting full uninstallation..."
            _cmd_daemon down >/dev/null 2>&1
            _cmd_daemon disable >/dev/null 2>&1
            local bin_path=$(readlink -f "$0")
            local project_root=$(dirname "$(dirname "$bin_path")")
            if [[ -f "$project_root/uninstall.sh" ]]; then
                msg_info "Running uninstall script..."
                bash "$project_root/uninstall.sh" --force
            elif [[ -f "$project_root/Makefile" ]]; then
                msg_info "Using Makefile to purge..."
                (cd "$project_root" && make purge)
            else
                msg_info "Performing manual purge..."
                rm -f "$bin_path"
                rm -rf "$LIB_DIR"
                rm -rf "$EYE_SHARE_DIR"
                rm -rf "$CONFIG_DIR"
                rm -rf "$STATE_DIR"
                msg_success "Eye purged manually."
            fi
            msg_success "Eye has been completely uninstalled."
            exit 0 ;;
        update)
            local apply=false force=false
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --apply) apply=true ;;
                    --force) force=true ;;
                esac
                shift
            done

            if [[ "$force" == "true" ]]; then
                msg_info "🚀 Force updating to the latest version..."
                # Only use git when user explicitly asks for a force update
                git pull origin master && make install
                msg_success "Eye force-updated."
                return 0
            fi

            msg_info "🔍 Checking for updates..."
            # Directly use the raw URL for version check to avoid git remote auth
            local raw_url="https://raw.githubusercontent.com/qianchencc/eye/master/lib/constants.sh"
            local remote_version=$(curl -s --connect-timeout 5 "$raw_url" | grep "EYE_VERSION=" | cut -d'"' -f2)
            
            if [[ -z "$remote_version" ]]; then
                # Fallback to main
                raw_url="https://raw.githubusercontent.com/qianchencc/eye/main/lib/constants.sh"
                remote_version=$(curl -s --connect-timeout 5 "$raw_url" | grep "EYE_VERSION=" | cut -d'"' -f2)
            fi

            if [[ -z "$remote_version" ]]; then
                msg_error "Error: Could not retrieve remote version. (Is network available?)"
                return 1
            fi

            if [[ "$EYE_VERSION" == "$remote_version" ]]; then
                msg_success "Eye is up to date ($EYE_VERSION)."
            else
                msg_warn "Update available: $remote_version"
                if [[ "$apply" == "true" ]]; then
                    git pull origin master && make install
                else
                    msg_info "Run 'eye daemon update --apply' to upgrade."
                fi
            fi ;;
        default)
            local task="$1"
            if [[ -z "$task" ]]; then echo "Current default task: ${DEFAULT_TASK:-eye_rest}"
            else DEFAULT_TASK="$task"; _save_global_config; msg_success "Default task set to: $task"; fi ;; 
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
            systemctl --user daemon-reload && systemctl --user enable eye.service && msg_success "Autostart enabled (Systemd)." ;; 
        disable) systemctl --user disable eye.service; rm -f "$SERVICE_FILE"; systemctl --user daemon-reload; msg_success "Autostart disabled." ;; 
        quiet) GLOBAL_QUIET="$1"; _save_global_config; msg_success "Quiet mode: $GLOBAL_QUIET" ;; 
        root-cmd) ROOT_CMD="$1"; _save_global_config; msg_success "Root command set to: $ROOT_CMD" ;; 
        language) LANGUAGE="$1"; _save_global_config; msg_success "Language set to: $LANGUAGE" ;; 
        help|*) echo "$MSG_HELP_DAEMON_HEADER"; echo -e "$MSG_HELP_DAEMON_CMDS" ;; 
    esac
}
_cmd_version() { echo "eye version $EYE_VERSION"; }

_cmd_usage() {
    echo "$MSG_USAGE_HEADER"
    echo ""
    echo "$MSG_USAGE_CORE"
    echo "$MSG_USAGE_CMD_START"
    echo "$MSG_USAGE_CMD_STOP"
    echo "$MSG_USAGE_CMD_RESUME"
    echo "$MSG_USAGE_CMD_NOW"
    echo "$MSG_USAGE_CMD_RESET"
    echo "$MSG_USAGE_CMD_TIME"
    echo "$MSG_USAGE_CMD_COUNT"
    echo ""
    echo "$MSG_USAGE_MANAGE"
    echo "$MSG_USAGE_CMD_ADD"
    echo "$MSG_USAGE_CMD_RM"
    echo "$MSG_USAGE_CMD_GROUP"
    echo "$MSG_USAGE_CMD_EDIT"
    echo "$MSG_USAGE_CMD_LIST"
    echo "$MSG_USAGE_CMD_STATUS"
    echo ""
    echo "$MSG_USAGE_SUB"
    echo "$MSG_USAGE_CMD_DAEMON"
    echo "$MSG_USAGE_CMD_SOUND"
}
