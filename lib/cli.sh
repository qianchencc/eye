#!/bin/bash

# =================命令行逻辑 (v2.0)=================

_cmd_usage() {
    echo "$MSG_USAGE_HEADER"
    echo ""
    echo "Task Management:"
    echo "  add <name>       Create a new task"
    echo "  list             List all tasks"
    echo "  remove <id>      Delete a task"
    echo "  edit <id>        Edit task file"
    echo "  in <time> <msg>  Create a one-off temporary task"
    echo ""
    echo "Control:"
    echo "  start [id|@grp]  Start daemon or specific tasks"
    echo "  stop [id|@grp]   Stop daemon or specific tasks"
    echo "  pause [id|@grp]  Pause tasks"
    echo "  resume [id|@grp] Resume tasks"
    echo "  now [id]         Trigger task immediately"
    echo ""
    echo "Daemon:"
    echo "  daemon up/down   Manage background service"
    echo "  status           Show status overview"
    echo ""
    echo "Other:"
    echo "  sound ...        Manage sounds"
    echo "  config ...       Global configuration"
}

# --- 任务管理 ---

_cmd_add() {
    local task_id="$1"
    shift
    
    if [[ -z "$task_id" ]]; then
        # 交互模式 (简单实现)
        printf "Task ID: " >&2; read -r task_id
    fi

    [[ -z "$task_id" ]] && return 1

    # 解析参数 (简单解析)
    local interval=1200
    local duration=0
    local group="default"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interval) interval=$(_parse_duration "$2"); shift 2 ;;
            -d|--duration) duration=$(_parse_duration "$2"); shift 2 ;;
            -g|--group)    group="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # 设置默认值并保存
    NAME="$task_id"
    GROUP="$group"
    INTERVAL="$interval"
    DURATION="$duration"
    TARGET_COUNT=-1
    REMAIN_COUNT=-1
    IS_TEMP=false
    SOUND_ENABLE=true
    SOUND_START="default"
    SOUND_END="complete"
    LAST_RUN=$(date +%s)
    STATUS="running"

    if _save_task "$task_id"; then
        msg_success "$(printf "$MSG_TASK_CREATED" "$task_id")"
    fi
}

_cmd_in() {
    local time_str="$1"
    shift
    local msg="$*"
    
    if [[ -z "$time_str" ]]; then
        msg_error "Usage: eye in <time> <message>"
        return 1
    fi
    
    local interval
    interval=$(_parse_duration "$time_str") || return 1
    
    local task_id="temp_$(date +%s)_$RANDOM"
    
    # 设置临时任务属性
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
        # 立即启动后台扫描(如果守护进程未运行，此操作无影响；若运行中，它会自然扫到新文件)
    fi
}

_cmd_edit() {
    local task_id="$1"
    local task_file="$TASKS_DIR/$task_id"
    
    if [[ ! -f "$task_file" ]]; then
        msg_error "$(printf "$MSG_TASK_NOT_FOUND" "$task_id")"
        return 1
    fi
    
    local editor="${EDITOR:-nano}"
    if ! command -v "$editor" >/dev/null 2>&1; then
        editor="vi"
    fi
    
    $editor "$task_file"
    msg_success "Task updated."
}

_cmd_remove() {
    local task_id="$1"
    if [[ -f "$TASKS_DIR/$task_id" ]]; then
        rm "$TASKS_DIR/$task_id"
        msg_success "$(printf "$MSG_TASK_REMOVED" "$task_id")"
    else
        msg_error "$(printf "$MSG_TASK_NOT_FOUND" "$task_id")"
    fi
}

_cmd_list() {
    msg_info "$MSG_TASK_LIST_HEADER"
    # 表头
    printf "%s %s %s %s %s\n" "$MSG_TASK_ID" "$MSG_TASK_GROUP" "$MSG_TASK_INTERVAL" "$MSG_TASK_STATUS" "NEXT"
    echo "---------------------------------------------------------------"
    
    for task_file in "$TASKS_DIR"/*; do
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
            printf "%s %s %s %s %s\n" "$task_id" "$GROUP" "$(_format_duration $INTERVAL)" "$STATUS" "$next_run"
        fi
    done
}

# --- 控制 ---

_cmd_start() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        # 启动守护进程
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null;
        then
            msg_warn "Daemon already running."
        else
            _daemon_loop > /dev/null 2>&1 &
            disown
            msg_success "Daemon started."
        fi
        return
    fi

    # 启动特定任务或组
    _apply_to_target "$target" "STATUS" "running"
    msg_success "Started $target"
}

_cmd_stop() {
    local target="$1"
    if [[ -z "$target" ]]; then
        # 停止守护进程
        if [ -f "$PID_FILE" ]; then
            kill $(cat "$PID_FILE") 2>/dev/null
            rm "$PID_FILE"
            msg_success "Daemon stopped."
        else
            msg_info "Daemon not running."
        fi
        return
    fi

    _apply_to_target "$target" "STATUS" "stopped"
    msg_success "Stopped $target"
}

_cmd_pause() {
    local target="${1:-@default}"
    _apply_to_target "$target" "STATUS" "paused"
    msg_success "Paused $target"
}

_cmd_resume() {
    local target="${1:-@default}"
    _apply_to_target "$target" "STATUS" "running"
    msg_success "Resumed $target"
}

_cmd_now() {
    local task_id="$1"
    if [[ -z "$task_id" ]]; then
        msg_error "Usage: eye now <task_id>"
        return 1
    fi
    
    msg_info "Triggering $task_id immediately..."
    _execute_task "$task_id"
}

_apply_to_target() {
    local target="$1"
    local key="$2"
    local value="$3"

    if [[ "$target" == @* ]]; then
        # 组操作
        local group_name="${target#@}"
        for task_file in "$TASKS_DIR"/*; do
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            _load_task "$task_id"
            if [[ "$GROUP" == "$group_name" ]]; then
                declare "$key"="$value"
                _save_task "$task_id"
            fi
        done
    else
        # 单个任务
        if _load_task "$target"; then
            declare "$key"="$value"
            _save_task "$target"
        fi
    fi
}

_cmd_status() {
    local is_running=0
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null;
    then
        is_running=1
    fi

    if [ ! -t 1 ]; then
        # 机器可读
        echo "daemon=$( [[ $is_running -eq 1 ]] && echo "running" || echo "stopped" )"
        echo "task_count=$(ls "$TASKS_DIR" | wc -l)"
        return
    fi

    # TTY 模式
    if [ $is_running -eq 1 ]; then
        msg_success "● Daemon: running (PID: $(cat "$PID_FILE"))"
    else
        msg_error "● Daemon: stopped"
    fi
    
    _cmd_list
}

_cmd_config() {
    local subcmd=$1
    shift
    _load_global_config
    case "$subcmd" in
        language)
            local lang=$1
            [[ "$lang" == "zh" || "$lang" == "en" ]] && LANGUAGE="$lang"
            _save_global_config
            msg_success "Language updated to $LANGUAGE"
            ;; 
        quiet)
            GLOBAL_QUIET="$1"
            _save_global_config
            msg_success "Quiet mode: $GLOBAL_QUIET"
            ;; 
        *)
            echo "Usage: eye config <language|quiet>"
            ;; 
    esac
}

_cmd_version() {
    echo "eye version $EYE_VERSION"
}