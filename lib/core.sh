#!/bin/bash

# ================= 核心业务逻辑 (lib/core.sh) =================

# 任务状态转换 (State Transitions)
# 这一层不处理 CLI 展示，只处理数据逻辑

_core_task_start() {
    local id="$1"
    EYE_T_STATUS="running"
    EYE_T_LAST_RUN=$(date +%s)
    EYE_T_PAUSE_TS=0
    EYE_T_RESUME_AT=0
}

_core_task_pause() {
    local id="$1"
    local duration="$2" # Optional duration string like "30m"

    if [[ "$EYE_T_STATUS" != "paused" ]]; then
        EYE_T_PAUSE_TS=$(date +%s)
    fi
    EYE_T_STATUS="paused"
    
    if [[ -n "$duration" ]]; then
        local seconds=$(_parse_duration "$duration")
        if [ $? -eq 0 ]; then
            EYE_T_RESUME_AT=$(( $(date +%s) + seconds ))
        fi
    else
        EYE_T_RESUME_AT=0
    fi
}

_core_task_resume() {
    local id="$1"
    if [[ "$EYE_T_STATUS" == "paused" ]]; then
        local now=$(date +%s)
        local diff=$((now - ${EYE_T_PAUSE_TS:-$now}))
        EYE_T_LAST_RUN=$((EYE_T_LAST_RUN + diff))
        EYE_T_PAUSE_TS=0
        EYE_T_RESUME_AT=0
    fi
    EYE_T_STATUS="running"
}

_core_task_time_shift() {
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
    if [ $? -ne 0 ]; then return 1; fi
    
    if [[ "$sign" == "-" ]]; then
        EYE_T_LAST_RUN=$((EYE_T_LAST_RUN + seconds))
    else
        EYE_T_LAST_RUN=$((EYE_T_LAST_RUN - seconds))
        # Logical Cap: If shift makes it overdue, cap LAST_RUN so NEXT is 0
        local now=$(date +%s)
        if [ $((now - EYE_T_LAST_RUN)) -gt "$EYE_T_INTERVAL" ]; then
            EYE_T_LAST_RUN=$((now - EYE_T_INTERVAL))
        fi
    fi
}

_core_task_count_shift() {
    local id="$1"
    local delta="$2"
    if [[ "$EYE_T_TARGET_COUNT" -eq -1 ]]; then
        return 1 # Error: Infinite
    fi
    EYE_T_REMAIN_COUNT=$((EYE_T_REMAIN_COUNT + delta))
}

_core_task_reset() {
    local id="$1"
    local do_time="$2"
    local do_count="$3"
    
    if [[ "$do_time" == "true" ]]; then
        EYE_T_LAST_RUN=$(date +%s)
    fi
    
    if [[ "$do_count" == "true" ]]; then
        if [[ "$EYE_T_TARGET_COUNT" -gt 0 ]]; then
            EYE_T_REMAIN_COUNT="$EYE_T_TARGET_COUNT"
        fi
    fi
}
