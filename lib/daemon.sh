#!/bin/bash

# ================= 守护进程核心 (lib/daemon.sh) =================

# --- Provider 抽象层 ---

_notify_provider() {
    local title="$1"
    local body="$2"
    local timeout="${3:-5000}"
    
    # 以后可以根据配置切换到 termux-notification 或 kdialog 等
    notify-send -t "$timeout" "$title" "$body"
}

_play_provider() {
    local tag="$1"
    _play "$tag"
}

# --- 核心辅助 ---

_try_lock() {
    local task_id="$1"
    if ( set -C; echo "$task_id" > "$BREAK_LOCK_FILE" ) 2>/dev/null; then
        return 0
    fi
    return 1
}

_release_lock() {
    rm -f "$BREAK_LOCK_FILE"
}

_format_msg() {
    local msg="$1"
    local dur_fmt=$(_format_duration "$EYE_T_DURATION")
    local int_fmt=$(_format_duration "$EYE_T_INTERVAL")
    
    local keys=("DURATION" "INTERVAL" "NAME" "REMAIN_COUNT")
    local vals=("$dur_fmt" "$int_fmt" "$EYE_T_NAME" "$EYE_T_REMAIN_COUNT")
    
    for i in "${!keys[@]}"; do
        local k="${keys[$i]}"
        local v="${vals[$i]}"
        msg="${msg//\$\{$k\}/$v}"
        msg="${msg//\{$k\}/$v}"
        local kl="${k,,}"
        msg="${msg//\{$kl\}/$v}"
        msg="${msg//\[$kl\]/$v}"
    done
    echo "$msg"
}

_execute_task() {
    local task_id="$1"
    _load_task "$task_id"
    
    if [[ "$EYE_T_STATUS" != "running" ]]; then return; fi

    if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]]; then
        EYE_T_REMAIN_COUNT=$((EYE_T_REMAIN_COUNT - 1))
    fi

    local start_msg=$(_format_msg "${EYE_T_MSG_START:-$MSG_NOTIFY_BODY_START}")
    local end_msg=$(_format_msg "${EYE_T_MSG_END:-$MSG_NOTIFY_BODY_END}")

    if [[ "$EYE_T_DURATION" -le 0 ]]; then
        _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
        [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
        
        EYE_T_LAST_RUN=$(date +%s)
        EYE_T_LAST_TRIGGER_AT=$EYE_T_LAST_RUN
        _save_task "$task_id"
        _log_history "$task_id" "TRIGGERED"
    else
        if _try_lock "$task_id"; then
            _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
            [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
            
            sleep "$EYE_T_DURATION"
            
            _notify_provider "${EYE_T_NAME:-$task_id}" "$end_msg"
            [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_END"
            
            _release_lock
            EYE_T_LAST_RUN=$(date +%s)
            EYE_T_LAST_TRIGGER_AT=$EYE_T_LAST_RUN
            _save_task "$task_id"
            _log_history "$task_id" "COMPLETED"
        else
            [[ "$EYE_T_TARGET_COUNT" -gt 0 ]] && EYE_T_REMAIN_COUNT=$((EYE_T_REMAIN_COUNT + 1))
            return
        fi
    fi

    # Lifecycle check
    if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]] && [[ "$EYE_T_REMAIN_COUNT" -le 0 ]]; then
        if [[ "$EYE_T_IS_TEMP" == "true" ]]; then
            rm -f "$TASKS_DIR/$task_id"
            _log_history "$task_id" "DELETED (Count reached)"
        else
            EYE_T_STATUS="stopped"
            _save_task "$task_id"
            _log_history "$task_id" "FINISHED (Count reached)"
        fi
    fi
}

_log_history() {
    local task_id="$1"
    local event="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$task_id] $event" >> "$HISTORY_LOG"
}

_daemon_loop() {
    echo $BASHPID > "$PID_FILE"
    local now=$(date +%s)
    local downtime_offset=0
    if [ -f "$STOP_FILE" ]; then
        local stop_time=$(cat "$STOP_FILE")
        downtime_offset=$((now - stop_time))
        rm -f "$STOP_FILE"
    fi

    msg_info "Daemon started. PID: $BASHPID"

    shopt -s nullglob
    for task_file in "$TASKS_DIR"/*; do
        [[ $(basename "$task_file") == .* ]] && continue
        [ -e "$task_file" ] || continue
        task_id=$(basename "$task_file")
        if _load_task "$task_id" && [[ "$EYE_T_STATUS" == "running" ]]; then
            if [ "$downtime_offset" -gt 0 ]; then
                EYE_T_LAST_RUN=$((EYE_T_LAST_RUN + downtime_offset))
            fi
            if [ "$EYE_T_LAST_RUN" -eq 0 ]; then
                EYE_T_LAST_RUN=$now
            elif [ $((now - EYE_T_LAST_RUN)) -ge "$EYE_T_INTERVAL" ]; then
                EYE_T_LAST_RUN=$(( now - ((now - EYE_T_LAST_RUN) % EYE_T_INTERVAL) ))
            fi
            _save_task "$task_id"
        fi
    done

    while true; do
        _load_global_config
        _init_messages

        for task_file in "$TASKS_DIR"/*; do
            [[ $(basename "$task_file") == .* ]] && continue
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            
            if _load_task "$task_id"; then
                local now=$(date +%s)
                if [[ "$EYE_T_STATUS" == "paused" && "$EYE_T_RESUME_AT" -gt 0 && "$now" -ge "$EYE_T_RESUME_AT" ]]; then
                    _core_task_resume "$task_id"
                    _save_task "$task_id"
                    _log_history "$task_id" "AUTO-RESUMED"
                fi

                if [[ "$EYE_T_STATUS" == "running" ]]; then
                    if [ $((now - EYE_T_LAST_RUN)) -ge "$EYE_T_INTERVAL" ]; then
                        _execute_task "$task_id" &
                    fi
                fi
            fi
        done
        sleep 5
    done
}