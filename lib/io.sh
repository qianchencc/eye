#!/bin/bash

# ================= 原子 IO 库 (lib/io.sh) =================

# _atomic_write <file> <content>
_atomic_write() {
    local target_file="$1"
    local content="$2"
    local target_dir=$(dirname "$target_file")
    local target_name=$(basename "$target_file")
    local tmp_file
    
    tmp_file=$(mktemp "${target_dir}/.${target_name}.XXXXXX") || return 1
    
    if echo "$content" > "$tmp_file"; then
        sync "$tmp_file" 2>/dev/null
        if mv -f "$tmp_file" "$target_file"; then
            return 0
        fi
    fi
    
    rm -f "$tmp_file"
    return 1
}

# _load_task <task_id>
_load_task() {
    local task_id="$1"
    local task_file
    
    if [[ "$task_id" == /* ]]; then
        task_file="$task_id"
    else
        task_file="$TASKS_DIR/$task_id"
    fi
    
    if [[ ! -f "$task_file" ]]; then
        return 1
    fi
    
    # 清理旧的任务变量 (EYE_T_ 命名空间)
    unset $(compgen -v EYE_T_)
    
    # 设置默认值 (命名空间化)
    EYE_T_NAME="$task_id"
    EYE_T_GROUP="default"
    EYE_T_INTERVAL=1200
    EYE_T_DURATION=0
    EYE_T_TARGET_COUNT=-1
    EYE_T_REMAIN_COUNT=-1
    EYE_T_IS_TEMP=false
    EYE_T_SOUND_ENABLE=true
    EYE_T_SOUND_START="$DEFAULT_SOUND_START"
    EYE_T_SOUND_END="$DEFAULT_SOUND_END"
    EYE_T_MSG_START=""
    EYE_T_MSG_END=""
    EYE_T_LAST_RUN=0
    EYE_T_CREATED_AT=0
    EYE_T_LAST_TRIGGER_AT=0
    EYE_T_PAUSE_TS=0
    EYE_T_RESUME_AT=0
    EYE_T_STATUS="running"
    
    # 兼容性加载：如果文件里包含不带 EYE_T_ 的变量，我们需要映射它们
    # 这里我们先 source，然后如果发现 EYE_T_ 没被设置，就用旧变量
    source "$task_file"
    
    # 映射旧变量到新变量名 (向后兼容)
    [[ -z "$EYE_T_NAME" && -n "$NAME" ]] && EYE_T_NAME="$NAME"
    [[ -z "$EYE_T_GROUP" && -n "$GROUP" ]] && EYE_T_GROUP="$GROUP"
    [[ -z "$EYE_T_INTERVAL" && -n "$INTERVAL" ]] && EYE_T_INTERVAL="$INTERVAL"
    [[ -z "$EYE_T_DURATION" && -n "$DURATION" ]] && EYE_T_DURATION="$DURATION"
    [[ -z "$EYE_T_TARGET_COUNT" && -n "$TARGET_COUNT" ]] && EYE_T_TARGET_COUNT="$TARGET_COUNT"
    [[ -z "$EYE_T_REMAIN_COUNT" && -n "$REMAIN_COUNT" ]] && EYE_T_REMAIN_COUNT="$REMAIN_COUNT"
    [[ -z "$EYE_T_IS_TEMP" && -n "$IS_TEMP" ]] && EYE_T_IS_TEMP="$IS_TEMP"
    [[ -z "$EYE_T_SOUND_ENABLE" && -n "$SOUND_ENABLE" ]] && EYE_T_SOUND_ENABLE="$SOUND_ENABLE"
    [[ -z "$EYE_T_SOUND_START" && -n "$SOUND_START" ]] && EYE_T_SOUND_START="$SOUND_START"
    [[ -z "$EYE_T_SOUND_END" && -n "$SOUND_END" ]] && EYE_T_SOUND_END="$SOUND_END"
    [[ -z "$EYE_T_MSG_START" && -n "$MSG_START" ]] && EYE_T_MSG_START="$MSG_START"
    [[ -z "$EYE_T_MSG_END" && -n "$MSG_END" ]] && EYE_T_MSG_END="$MSG_END"
    [[ -z "$EYE_T_LAST_RUN" && -n "$LAST_RUN" ]] && EYE_T_LAST_RUN="$LAST_RUN"
    [[ -z "$EYE_T_CREATED_AT" && -n "$CREATED_AT" ]] && EYE_T_CREATED_AT="$CREATED_AT"
    [[ -z "$EYE_T_LAST_TRIGGER_AT" && -n "$LAST_TRIGGER_AT" ]] && EYE_T_LAST_TRIGGER_AT="$LAST_TRIGGER_AT"
    [[ -z "$EYE_T_PAUSE_TS" && -n "$PAUSE_TS" ]] && EYE_T_PAUSE_TS="$PAUSE_TS"
    [[ -z "$EYE_T_RESUME_AT" && -n "$RESUME_AT" ]] && EYE_T_RESUME_AT="$RESUME_AT"
    [[ -z "$EYE_T_STATUS" && -n "$STATUS" ]] && EYE_T_STATUS="$STATUS"
    
    return 0
}

# _save_task <task_id>
_save_task() {
    local task_id="$1"
    local task_file="$TASKS_DIR/$task_id"
    local content
    
    content=$(cat <<EOF
EYE_T_NAME=$(printf %q "$EYE_T_NAME")
EYE_T_GROUP=$(printf %q "$EYE_T_GROUP")
EYE_T_INTERVAL=$(printf %q "$EYE_T_INTERVAL")
EYE_T_DURATION=$(printf %q "$EYE_T_DURATION")
EYE_T_TARGET_COUNT=$(printf %q "$EYE_T_TARGET_COUNT")
EYE_T_REMAIN_COUNT=$(printf %q "$EYE_T_REMAIN_COUNT")
EYE_T_IS_TEMP=$(printf %q "$EYE_T_IS_TEMP")
EYE_T_SOUND_ENABLE=$(printf %q "$EYE_T_SOUND_ENABLE")
EYE_T_SOUND_START=$(printf %q "$EYE_T_SOUND_START")
EYE_T_SOUND_END=$(printf %q "$EYE_T_SOUND_END")
EYE_T_MSG_START=$(printf %q "$EYE_T_MSG_START")
EYE_T_MSG_END=$(printf %q "$EYE_T_MSG_END")
EYE_T_LAST_RUN=$(printf %q "$EYE_T_LAST_RUN")
EYE_T_CREATED_AT=$(printf %q "$EYE_T_CREATED_AT")
EYE_T_LAST_TRIGGER_AT=$(printf %q "$EYE_T_LAST_TRIGGER_AT")
EYE_T_PAUSE_TS=$(printf %q "$EYE_T_PAUSE_TS")
EYE_T_RESUME_AT=$(printf %q "$EYE_T_RESUME_AT")
EYE_T_STATUS=$(printf %q "$EYE_T_STATUS")
EOF
)
    _atomic_write "$task_file" "$content"
}