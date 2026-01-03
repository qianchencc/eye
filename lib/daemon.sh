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

# --- Global Cycle Lock ---
# Ensures only one task is in the "Notify/Interaction" phase at a time.
# This prevents audio overlap and user notification spam.
_acquire_global_cycle_lock() {
    local task_id="$1"
    local cycle_lock="$STATE_DIR/cycle.lock"
    
    log_lock "$task_id" "WAIT" "Waiting for cycle lock..."
    
    # Wait up to 30 seconds for the lock
    local retries=300
    while [ -f "$cycle_lock" ]; do
        # Check if lock is stale (process dead)
        local lock_pid=$(cat "$cycle_lock" 2>/dev/null)
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            log_lock "global" "CLEANUP" "Removing stale cycle lock from PID $lock_pid"
            rm -f "$cycle_lock"
            break
        fi
        
        sleep 0.1
        retries=$((retries - 1))
        if [ $retries -le 0 ]; then
            log_lock "$task_id" "TIMEOUT" "Failed to acquire cycle lock"
            return 1
        fi
    done
    
    echo "$BASHPID" > "$cycle_lock"
    log_lock "$task_id" "ACQUIRED" "Cycle lock granted"
    return 0
}

_release_global_cycle_lock() {
    local task_id="$1"
    rm -f "$STATE_DIR/cycle.lock"
    log_lock "global" "RELEASE" "Cycle lock released by $task_id"
}

_execute_task() {
    local task_id="$1"
    
    # 核心竞态防护：每任务文件锁
    if ! _try_lock "$task_id"; then return; fi
    
    # PID Registration
    local pids_dir="$STATE_DIR/pids"
    mkdir -p "$pids_dir"
    echo "$BASHPID" > "$pids_dir/$task_id"
    
    # Updated Trap: Release lock AND remove PID file
    trap "_release_lock '$task_id'; rm -f '$pids_dir/$task_id'" EXIT

    # 获取锁后重新加载
    _load_task "$task_id" || return

    # 状态检查 (Allow force run)
    if [[ "$EYE_T_STATUS" != "running" && "$EYE_FORCE_RUN" != "true" ]]; then 
        log_debug "$task_id" "Execution cancelled: Status is $EYE_T_STATUS"
        return; 
    fi
    
    # 竞态二次校验 (1秒防抖)
    local now=$(date +%s)
    if [[ "${EYE_T_LAST_TRIGGER_AT:-0}" -ne 0 && $((now - EYE_T_LAST_TRIGGER_AT)) -lt 1 ]]; then
        log_debug "$task_id" "Execution cancelled: Debounce protection"
        return
    fi

    # 计数器熔断保护
    if [[ "$EYE_T_TARGET_COUNT" -gt 0 && "$EYE_T_REMAIN_COUNT" -le 0 ]]; then
        EYE_T_STATUS="stopped"
        _save_task "$task_id"
        log_task "$task_id" "STOPPED (Count exhausted)"
        return
    fi

    log_task "$task_id" "START" "Execution begun (Duration: $EYE_T_DURATION)"

    local start_msg=$(_format_msg "${EYE_T_MSG_START:-$MSG_NOTIFY_BODY_START}")
    local end_msg=$(_format_msg "${EYE_T_MSG_END:-$MSG_NOTIFY_BODY_END}")

    # --- Interaction Phase ---
    # Attempt to acquire global cycle lock before user interaction
    if _acquire_global_cycle_lock "$task_id"; then
        # Ensure we release it even if we crash here
        trap "_release_global_cycle_lock '$task_id'; _release_lock '$task_id'; rm -f '$pids_dir/$task_id'" EXIT
        
        if [[ "$EYE_T_DURATION" -le 0 ]]; then
            _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
            [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
        else
            _notify_provider "${EYE_T_NAME:-$task_id}" "$start_msg"
            [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_START"
            
            sleep "$EYE_T_DURATION"
            
            _notify_provider "${EYE_T_NAME:-$task_id}" "$end_msg"
            [[ "$EYE_T_SOUND_ENABLE" == "true" ]] && _play_provider "$EYE_T_SOUND_END"
        fi

        # User requested delay after interaction to prevent audio overlap
        sleep 1
        _release_global_cycle_lock "$task_id"
        # Reset trap to just file lock
        trap "_release_lock '$task_id'; rm -f '$pids_dir/$task_id'" EXIT
    else
        log_error "$task_id" "Skipped interaction due to lock timeout"
    fi

    # --- State Merge & Persistence ---
    if _load_task "$task_id"; then
        EYE_T_LAST_TRIGGER_AT=$(date +%s)
        if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]]; then
            EYE_T_REMAIN_COUNT=$((EYE_T_REMAIN_COUNT - 1))
        fi
    else
        log_warn "$task_id" "Task file vanished during execution"
        return
    fi

    _save_task "$task_id"
    log_task "$task_id" "FINISHED"

    # Lifecycle check (using the refreshed data)
    if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]] && [[ "$EYE_T_REMAIN_COUNT" -le 0 ]]; then
        if [[ "$EYE_T_IS_TEMP" == "true" ]]; then
            rm -f "$TASKS_DIR/$task_id"
            log_task "$task_id" "DELETED (Temp task ended)"
        else
            EYE_T_STATUS="stopped"
            _save_task "$task_id"
            log_task "$task_id" "STOPPED (Finished)"
        fi
    fi
}
_daemon_cleanup() {
    log_system "Daemon" "Shutting down... Cleaning up child processes."
    
    # Kill all tracked background PIDs
    for pid in "${!RUNNING_PID_MAP[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_debug "Daemon" "Killing child PID $pid"
            kill "$pid" 2>/dev/null
        fi
    done
    
    rm -f "$PID_FILE"
    rm -f "$STATE_DIR/cycle.lock"
    log_system "Daemon" "Shutdown complete."
    exit 0
}

_daemon_loop() {
    # Initialize Logger
    _init_logger
    
    echo $BASHPID > "$PID_FILE"
    
    # Cleanup stale PIDs from previous runs
    rm -rf "$STATE_DIR/pids"
    mkdir -p "$STATE_DIR/pids"
    
    # Trap signals for cleanup
    trap '_daemon_cleanup' EXIT SIGINT SIGTERM

    local now=$(date +%s)
    local downtime_offset=0
    if [ -f "$STOP_FILE" ]; then
        local stop_time=$(cat "$STOP_FILE")
        downtime_offset=$((now - stop_time))
        rm -f "$STOP_FILE"
    fi

    log_system "Daemon" "Started (PID: $BASHPID, Mode: $(command -v inotifywait >/dev/null && echo "Event-Driven" || echo "Polling"))"

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
                log_sched "$task_id" "Compensated downtime: +${downtime_offset}s"
            fi
            
            if [ "${EYE_T_LAST_RUN:-0}" -eq 0 ]; then
                # New task or broken state: align to now to start first interval from now
                EYE_T_LAST_RUN=$now
                log_sched "$task_id" "Initialized LAST_RUN to NOW"
            elif [ $((now - EYE_T_LAST_RUN)) -ge "$EYE_T_INTERVAL" ]; then
                # Align to theoretical last trigger point in the past
                EYE_T_LAST_RUN=$(( now - ((now - EYE_T_LAST_RUN) % EYE_T_INTERVAL) ))
                log_sched "$task_id" "Re-aligned LAST_RUN"
            fi
            _save_task "$task_id"
        fi
    done

    # 检查 inotifywait 是否可用
    local has_inotify=false
    command -v inotifywait >/dev/null 2>&1 && has_inotify=true

    # 初始化运行中清单 (Declared global so trap can see it? No, needs to be accessible. 
    # Bash variables are global by default unless 'local' is used. 
    # However, _daemon_loop is called as a function. 
    # Let's declare it at file scope or ensure trap can access it. 
    # Since trap executes in the same context, it should be fine if declared here but NOT local if we want to be safe, 
    # but local works in bash 4+ for traps set inside function. 
    # Let's make it explicitly associative.)
    declare -A RUNNING_PID_MAP

    while true; do
        _load_global_config
        _init_messages

        # Reap background processes and update PID map
        jobs > /dev/null 
        for pid in "${!RUNNING_PID_MAP[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                log_debug "Daemon" "Reaped task process $pid"
                unset RUNNING_PID_MAP["$pid"]
            fi
        done

        # 扫描任务并触发
        for task_file in "$TASKS_DIR"/*; do
            [[ $(basename "$task_file") == .* ]] && continue
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            
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
                        log_warn "$task_id" "Removed stale lock file"
                    fi
                fi

                if [[ "$is_running" == "true" ]]; then
                    log_debug "$task_id" "Skip: Task is still running (Lock/PID check)"
                    continue
                fi

                local now=$(date +%s)
                # 自动恢复
                if [[ "$EYE_T_STATUS" == "paused" && "$EYE_T_RESUME_AT" -gt 0 && "$now" -ge "$EYE_T_RESUME_AT" ]]; then
                    _core_task_resume "$task_id"
                    _save_task "$task_id"
                    log_sched "$task_id" "Auto-resumed"
                fi

                # 检查执行
                if [[ "$EYE_T_STATUS" == "running" ]]; then
                    current_time=$(date +%s)
                    local diff=$((current_time - EYE_T_LAST_RUN))
                    log_debug "$task_id" "Check: diff=$diff, interval=$EYE_T_INTERVAL"
                    
                    # 终极对齐保护：如果 LAST_RUN 为 0，说明是异常状态，立即对齐到当前时间以启动计时
                    if [[ "${EYE_T_LAST_RUN:-0}" -eq 0 ]]; then
                        EYE_T_LAST_RUN=$current_time
                        _save_task "$task_id"
                        log_sched "$task_id" "LAST_RUN was 0, reset to NOW"
                        continue
                    fi

                    if [ $diff -ge "$EYE_T_INTERVAL" ]; then
                        # Update timestamp BEFORE backgrounding to prevent re-triggering
                        local intervals_passed=$(( diff / EYE_T_INTERVAL ))
                        EYE_T_LAST_RUN=$(( EYE_T_LAST_RUN + (intervals_passed * EYE_T_INTERVAL) ))
                        _save_task "$task_id"
                        
                        log_sched "$task_id" "Triggering (Passed: $intervals_passed intervals)"
                        # 触发执行并记录 PID
                        _execute_task "$task_id" &
                        RUNNING_PID_MAP[$!]="$task_id"
                    fi
                else
                    log_debug "$task_id" "Skip: Status is $EYE_T_STATUS"
                fi
            fi
        done
        
        # 混合等待机制：
        if [ "$has_inotify" = true ]; then
            # Add moved_to because _save_task uses 'mv'
            inotifywait -t 5 -q -e close_write,create,delete,moved_to "$TASKS_DIR" >/dev/null 2>&1 || true
        else
            sleep 5
        fi
    done
}
