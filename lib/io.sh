#!/bin/bash

# =================原子 IO 库 (lib/io.sh)=================

# _atomic_write <file> <content>
# 使用 mktemp + fsync + mv 策略确保写入的原子性
_atomic_write() {
    local target_file="$1"
    local content="$2"
    local tmp_file
    
    tmp_file=$(mktemp "${target_file}.XXXXXX") || return 1
    
    if echo "$content" > "$tmp_file"; then
        # 尝试强制同步到磁盘
        sync "$tmp_file" 2>/dev/null
        if mv -f "$tmp_file" "$target_file"; then
            return 0
        fi
    fi
    
    rm -f "$tmp_file"
    return 1
}

# _load_task <task_id>
# 读取任务文件并解析变量。支持 TaskID 或完整路径。
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
    
    # 清理旧的任务变量 (防止污染)
    unset NAME GROUP INTERVAL DURATION TARGET_COUNT REMAIN_COUNT IS_TEMP 
    unset SOUND_ENABLE SOUND_START SOUND_END MSG_START MSG_END LAST_RUN STATUS
    
    # 设置默认值
    NAME="$task_id"
    GROUP="default"
    INTERVAL=1200
    DURATION=0
    TARGET_COUNT=-1
    REMAIN_COUNT=-1
    IS_TEMP=false
    SOUND_ENABLE=true
    SOUND_START="$DEFAULT_SOUND_START"
    SOUND_END="$DEFAULT_SOUND_END"
    MSG_START=""
    MSG_END=""
    LAST_RUN=0
    STATUS="running"
    
    # Source 任务文件 (Key=Value 结构)
    # 警告：由于使用 source，任务文件内容必须受控
    source "$task_file"
}

# _save_task <task_id>
# 将当前的内存变量保存回任务文件
_save_task() {
    local task_id="$1"
    local task_file="$TASKS_DIR/$task_id"
    local content
    
    content=$(cat <<EOF
NAME="$NAME"
GROUP="$GROUP"
INTERVAL="$INTERVAL"
DURATION="$DURATION"
TARGET_COUNT="$TARGET_COUNT"
REMAIN_COUNT="$REMAIN_COUNT"
IS_TEMP="$IS_TEMP"
SOUND_ENABLE="$SOUND_ENABLE"
SOUND_START="$SOUND_START"
SOUND_END="$SOUND_END"
MSG_START="$MSG_START"
MSG_END="$MSG_END"
LAST_RUN="$LAST_RUN"
STATUS="$STATUS"
EOF
)
    _atomic_write "$task_file" "$content"
}
