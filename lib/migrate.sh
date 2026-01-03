#!/bin/bash

# ================= 迁移逻辑 (v1.x -> v2.0) =================

_migrate_v1_to_v2() {
    local old_config="$CONFIG_DIR/config"
    local new_task_file="$TASKS_DIR/eye_rest"
    
    # 前置检查：
    # 1. 旧配置必须存在
    # 2. 新的任务目录中如果没有 eye_rest (避免覆盖)
    if [[ ! -f "$old_config" ]]; then
        return 0
    fi
    
    if [[ -f "$new_task_file" ]]; then
        # 如果已经存在 eye_rest，说明可能已经迁移过或者已经有默认任务
        return 0
    fi

    msg_info "🚀 Detected v1.x configuration. Migrating to v2.0..."

    # 读取旧配置 (在一个子 Shell 中读取，以免污染当前环境)
    (
        source "$old_config"
        
        # 转换变量
        NAME="eye_rest"
        GROUP="default"
        INTERVAL="${REST_GAP:-1200}"
        DURATION="${LOOK_AWAY:-20}"
        TARGET_COUNT=-1
        REMAIN_COUNT=-1
        IS_TEMP=false
        
        # 音效开关处理
        SOUND_ENABLE="true"
        if [[ "$SOUND_SWITCH" == "off" ]]; then
            SOUND_ENABLE="false"
        fi
        
        SOUND_START="${SOUND_START:-default}"
        SOUND_END="${SOUND_END:-complete}"
        
        local now=$(date +%s)
        LAST_RUN=0
        CREATED_AT=$now
        LAST_TRIGGER_AT=0
        STATUS="running"
        
        # 写入新任务文件
        cat > "$new_task_file" <<EOF
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
MSG_START='Look away for {DURATION}!'
MSG_END="Eyes rested. Keep going!"
LAST_RUN="$LAST_RUN"
CREATED_AT="$CREATED_AT"
LAST_TRIGGER_AT="$LAST_TRIGGER_AT"
STATUS="$STATUS"
EOF
    )

    if [ $? -eq 0 ]; then
        msg_success "✅ Migration successful: 'eye_rest' task created."
        mv "$old_config" "$old_config.bak"
        msg_info "ℹ️  Old config backed up to config.bak"
    else
        msg_error "❌ Migration failed."
    fi
}