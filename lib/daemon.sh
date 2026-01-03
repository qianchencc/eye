#!/bin/bash

# =================守护进程核心 (v2.0)=================

# 锁管理
_try_lock() {
    local task_id="$1"
    # 使用 noclobber 原子创建锁文件
    if ( set -C; echo "$task_id" > "$BREAK_LOCK_FILE" ) 2>/dev/null; then
        return 0
    fi
    return 1
}

_release_lock() {
    rm -f "$BREAK_LOCK_FILE"
}

# 变量替换
_format_msg() {
    local msg="$1"
    local dur_fmt=$(_format_duration "$DURATION")
    local int_fmt=$(_format_duration "$INTERVAL")
    
    # We support multiple styles: ${VAR}, {VAR}, [VAR]
    local keys=("DURATION" "INTERVAL" "NAME" "REMAIN_COUNT")
    local vals=("$dur_fmt" "$int_fmt" "$NAME" "$REMAIN_COUNT")
    
    for i in "${!keys[@]}"; do
        local k="${keys[$i]}"
        local v="${vals[$i]}"
        
        msg="${msg//\$\{$k\}/$v}"
        msg="${msg//\{$k\}/$v}"
        
        # Lowercase fallback for brackets/braces
        local kl="${k,,}"
        msg="${msg//\{$kl\}/$v}"
        msg="${msg//\[$kl\]/$v}"
    done
    
    echo "$msg"
}

# 执行单个任务
_execute_task() {
    local task_id="$1"
    
    # 重新加载任务数据确保最新 (主要是 LAST_RUN 和 STATUS)
    _load_task "$task_id"
    
    # 状态检查
    if [[ "$STATUS" != "running" ]]; then
        return
    fi

    # 逻辑调整：先扣减计数，使通知中的 {REMAIN_COUNT} 准确
    if [[ "$TARGET_COUNT" -gt 0 ]]; then
        REMAIN_COUNT=$((REMAIN_COUNT - 1))
    fi

    # 变量准备
    local start_msg=$(_format_msg "${MSG_START:-$MSG_NOTIFY_BODY_START}")
    local end_msg=$(_format_msg "${MSG_END:-$MSG_NOTIFY_BODY_END}")

    if [[ "$DURATION" -le 0 ]]; then
        # --- 脉冲任务 (Duration=0) ---
        notify-send -t 5000 "${NAME:-$task_id}" "$start_msg"
        if [[ "$SOUND_ENABLE" == "true" ]]; then
            _play "$SOUND_START"
        fi
        
        # 更新状态
        LAST_RUN=$(date +%s)
        LAST_TRIGGER_AT=$LAST_RUN
        _save_task "$task_id"
        _log_history "$task_id" "TRIGGERED"
    else
        # --- 周期任务 (Duration>0) ---
        if _try_lock "$task_id"; then
            notify-send -t 5000 "${NAME:-$task_id}" "$start_msg"
            if [[ "$SOUND_ENABLE" == "true" ]]; then
                _play "$SOUND_START"
            fi
            
            # 阻塞执行
            sleep "$DURATION"
            
            notify-send -t 5000 "${NAME:-$task_id}" "$end_msg"
            if [[ "$SOUND_ENABLE" == "true" ]]; then
                _play "$SOUND_END"
            fi
            
            _release_lock
            
            # 更新状态
            LAST_RUN=$(date +%s)
            LAST_TRIGGER_AT=$LAST_RUN
            _save_task "$task_id"
            _log_history "$task_id" "COMPLETED"
        else
            # 抢锁失败：还原计数以便下次尝试
            [[ "$TARGET_COUNT" -gt 0 ]] && REMAIN_COUNT=$((REMAIN_COUNT + 1))
            return
        fi
    fi

    # 生命周期检查
    if [[ "$TARGET_COUNT" -gt 0 ]] && [[ "$REMAIN_COUNT" -le 0 ]]; then
        if [[ "$IS_TEMP" == "true" ]]; then
            rm -f "$TASKS_DIR/$task_id"
            _log_history "$task_id" "DELETED (Count reached)"
            # If default task is deleted, maybe warn? But standard behavior is just delete.
        else
            STATUS="stopped"
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

# 守护进程主循环
_daemon_loop() {
    echo $BASHPID > "$PID_FILE"
    rm -f "$STOP_FILE"
    
    msg_info "Daemon started. PID: $BASHPID"

    # 初始化逻辑：对齐所有任务的计时器，防止由于长期停机导致的“通知风暴”
    local now=$(date +%s)
    for task_file in "$TASKS_DIR"/*; do
        [ -e "$task_file" ] || continue
        task_id=$(basename "$task_file")
        if _load_task "$task_id" && [[ "$STATUS" == "running" ]]; then
            if [ "$LAST_RUN" -eq 0 ]; then
                # 从未运行过的任务，从现在开始计时
                LAST_RUN=$now
                _save_task "$task_id"
            elif [ $((now - LAST_RUN)) -ge "$INTERVAL" ]; then
                # 已过期的任务，对齐到上一个理论触发点 (now - elapsed % interval)
                LAST_RUN=$(( now - ((now - LAST_RUN) % INTERVAL) ))
                _save_task "$task_id"
            fi
        fi
    done

    while true; do
        # 动态重载配置 (语言、静默模式等)
        _load_global_config
        _init_messages

        # 扫描任务
        for task_file in "$TASKS_DIR"/*; do
            [ -e "$task_file" ] || continue
            task_id=$(basename "$task_file")
            
            # 加载任务并检查触发
            if _load_task "$task_id"; then
                if [[ "$STATUS" == "running" ]]; then
                    current_time=$(date +%s)
                    if [ $((current_time - LAST_RUN)) -ge "$INTERVAL" ]; then
                        # 触发执行 (后台运行以防阻塞其他任务检查)
                        # 注意：周期任务内部会有 sleep，所以必须后台执行
                        _execute_task "$task_id" &
                    fi
                fi
            fi
        done
        
        # 频率控制
        sleep 5
    done
}