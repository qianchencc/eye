#!/bin/bash

# ================= 守护进程核心 (lib/daemon.sh) =================

# --- 核心辅助 ---

_try_lock() {
    local task_id="$1"
    local lock_file="$STATE_DIR/lock.$task_id"
    if ( set -C; echo "$BASHPID" > "$lock_file" ) 2>/dev/null; then
        return 0
    fi
    return 1
}

_release_lock() {
    local task_id="$1"
    rm -f "$STATE_DIR/lock.$task_id"
}

_format_msg() {
    local msg="$1"
    local dur_fmt=$(_format_duration "$EYE_T_DURATION")
    local int_fmt=$(_format_duration "$EYE_T_INTERVAL")
    
    # We support multiple styles: ${VAR}, {VAR}, [VAR], and lowercase versions
    local keys=("DURATION" "INTERVAL" "NAME" "REMAIN_COUNT" "REMAIN")
    local vals=("$dur_fmt" "$int_fmt" "$EYE_T_NAME" "$EYE_T_REMAIN_COUNT" "$EYE_T_REMAIN_COUNT")
    
    for i in "${!keys[@]}"; do
        local k="${keys[$i]}"
        local v="${vals[$i]}"
        
        # Use a temporary variable to avoid issues with special characters in 'v'
        # Escape backslashes and ampersands for safe use in sed or substitution if needed,
        # but bash // substitution is generally safe for the 'v' part.
        
        # Case insensitive and multiple bracket styles
        msg="${msg//\$\{$k\}/$v}"
        msg="${msg//\{$k\}/$v}"
        msg="${msg//\[$k\]/$v}"
        
        # Lowercase support
        local kl="${k,,}"
        msg="${msg//\$\{$kl\}/$v}"
        msg="${msg//\{$kl\}/$v}"
        msg="${msg//\[$kl\]/$v}"
    done
    echo "$msg"
}

_execute_task() {
    local task_id="$1"
    
    # 核心竞态防护：无论 duration 多少，执行期间必须持有锁
    if ! _try_lock "$task_id"; then return; fi
    trap "_release_lock '$task_id'" EXIT

    # 关键：获取锁后立即重新加载最新数据，防止读取到过时的 LAST_RUN 或 LAST_TRIGGER_AT
    _load_task "$task_id" || return

    # 状态与计数器熔断保护
    if [[ "$EYE_T_STATUS" != "running" ]]; then return; fi
    
    # 竞态二次校验：如果距离上次触发不到 1 秒，说明是误触发，直接退出
    local now=$(date +%s)
    if [[ "${EYE_T_LAST_TRIGGER_AT:-0}" -ne 0 && $((now - EYE_T_LAST_TRIGGER_AT)) -lt 1 ]]; then
        return
    fi

    if [[ "$EYE_T_TARGET_COUNT" -gt 0 && "$EYE_T_REMAIN_COUNT" -le 0 ]]; then
        EYE_T_STATUS="stopped"
        _save_task "$task_id"
        return
    fi

    if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]]; then
        EYE_T_REMAIN_COUNT=$((EYE_T_REMAIN_COUNT - 1))
    fi

    local start_msg=$(_format_msg "${EYE_T_MSG_START:-$MSG_NOTIFY_BODY_START}")
    local end_msg=$(_format_msg "${EYE_T_MSG_END:-$MSG_NOTIFY_BODY_END}")

    if [[ "$EYE_T_DURATION" -le 0 ]]; then
        _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
        [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
        
        EYE_T_LAST_TRIGGER_AT=$(date +%s)
        _save_task "$task_id"
        _log_history "$task_id" "TRIGGERED"
    else
        _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
        [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
        
        sleep "$EYE_T_DURATION"
        
        _notify_provider "${EYE_T_NAME:-$task_id}" "$end_msg"
        [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_END"
        
        EYE_T_LAST_TRIGGER_AT=$(date +%s)
        _save_task "$task_id"
        _log_history "$task_id" "COMPLETED"
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

    msg_info "Daemon started (PID: $BASHPID, Mode: $(command -v inotifywait >/dev/null && echo "Event-Driven" || echo "Polling"))"

    # 初始化补偿逻辑
    shopt -s nullglob
    for task_file in "$TASKS_DIR"/*; do
        [[ $(basename "$task_file") == .* ]] && continue
        [ -e "$task_file" ] || continue
        task_id=$(basename "$task_file")
        if _load_task "$task_id" && [[ "$EYE_T_STATUS" == "running" ]]; then
            # Only compensate if task existed before daemon stopped
            if [ "$downtime_offset" -gt 0 ] && [ "$EYE_T_LAST_RUN" -gt 0 ] && [ "$EYE_T_LAST_RUN" -le "$stop_time" ]; then
                EYE_T_LAST_RUN=$((EYE_T_LAST_RUN + downtime_offset))
            fi
            
            if [ "${EYE_T_LAST_RUN:-0}" -eq 0 ]; then
                # New task or broken state: align to now to start first interval from now
                EYE_T_LAST_RUN=$now
            elif [ $((now - EYE_T_LAST_RUN)) -ge "$EYE_T_INTERVAL" ]; then
                # Align to theoretical last trigger point in the past
                EYE_T_LAST_RUN=$(( now - ((now - EYE_T_LAST_RUN) % EYE_T_INTERVAL) ))
            fi
            _save_task "$task_id"
        fi
    done

    # 检查 inotifywait 是否可用
    local has_inotify=false
    command -v inotifywait >/dev/null 2>&1 && has_inotify=true

    # 初始化运行中清单
    local -A RUNNING_PID_MAP=()

    while true; do
        _load_global_config
        _init_messages

        # 扫描任务并触发
        for task_file in "$TASKS_DIR"/*; do
            [[ $(basename "$task_file") == .* ]] && continue
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            
            # 清理已经结束的后台进程
            for pid in "${!RUNNING_PID_MAP[@]}"; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    unset RUNNING_PID_MAP["$pid"]
                fi
            done

            if _load_task "$task_id"; then
                # 检查此任务是否已经在运行列表中（通过 PID 映射或物理锁文件检测）
                local is_running=false
                local lock_file="$STATE_DIR/lock.$task_id"
                
                # 检查内存中的 PID 映射
                for pid in "${!RUNNING_PID_MAP[@]}"; do
                    if [[ "${RUNNING_PID_MAP[$pid]}" == "$task_id" ]]; then
                        is_running=true; break
                    fi
                done
                
                # 物理锁文件校验（Double Check）
                if [[ "$is_running" == "false" && -f "$lock_file" ]]; then
                    # 检查锁文件对应的进程是否真的还在
                    local lock_pid=$(cat "$lock_file" 2>/dev/null)
                    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
                        is_running=true
                    else
                        # 锁文件残留，清理掉
                        rm -f "$lock_file"
                    fi
                fi

                [[ "$is_running" == "true" ]] && continue

                local now=$(date +%s)
                # 自动恢复
                if [[ "$EYE_T_STATUS" == "paused" && "$EYE_T_RESUME_AT" -gt 0 && "$now" -ge "$EYE_T_RESUME_AT" ]]; then
                    _core_task_resume "$task_id"
                    _save_task "$task_id"
                    _log_history "$task_id" "AUTO-RESUMED"
                fi

                # 检查执行
                if [[ "$EYE_T_STATUS" == "running" ]]; then
                    current_time=$(date +%s)
                    # 终极对齐保护：如果 LAST_RUN 为 0，说明是异常状态，立即对齐到当前时间以启动计时
                    if [[ "${EYE_T_LAST_RUN:-0}" -eq 0 ]]; then
                        EYE_T_LAST_RUN=$current_time
                        _save_task "$task_id"
                        continue
                    fi

                    if [ $((current_time - EYE_T_LAST_RUN)) -ge "$EYE_T_INTERVAL" ]; then
                        # Update timestamp BEFORE backgrounding to prevent re-triggering
                        local intervals_passed=$(( (current_time - EYE_T_LAST_RUN) / EYE_T_INTERVAL ))
                        EYE_T_LAST_RUN=$(( EYE_T_LAST_RUN + (intervals_passed * EYE_T_INTERVAL) ))
                        _save_task "$task_id"
                        
                        # 触发执行并记录 PID
                        _execute_task "$task_id" &
                        RUNNING_PID_MAP[$!]="$task_id"
                    fi
                fi
            fi
        done
        
        # 混合等待机制：
        # 如果有 inotify，等待文件变动 OR 5秒超时
        # 如果没有 inotify，直接 sleep 5秒
        if [ "$has_inotify" = true ]; then
            # -t 5 表示 5 秒超时，如果没有事件发生也返回
            inotifywait -t 5 -q -e close_write,create,delete "$TASKS_DIR" >/dev/null 2>&1 || true
        else
            sleep 5
        fi
    done
}
