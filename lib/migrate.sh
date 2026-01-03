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
        EYE_T_NAME="eye_rest"
        EYE_T_GROUP="default"
        EYE_T_INTERVAL="${REST_GAP:-1200}"
        EYE_T_DURATION="${LOOK_AWAY:-20}"
        EYE_T_TARGET_COUNT=-1
        EYE_T_REMAIN_COUNT=-1
        EYE_T_IS_TEMP=false
        
        # 音效开关处理
        EYE_T_SOUND_ENABLE="true"
        if [[ "$SOUND_SWITCH" == "off" ]]; then
            EYE_T_SOUND_ENABLE="false"
        fi
        
        EYE_T_SOUND_START="${SOUND_START:-default}"
        EYE_T_SOUND_END="${SOUND_END:-complete}"
        
        local now=$(date +%s)
        EYE_T_LAST_RUN=$now
        EYE_T_CREATED_AT=$now
        EYE_T_LAST_TRIGGER_AT=0
        EYE_T_STATUS="running"
        
        # 写入新任务文件
        cat > "$new_task_file" <<EOF
EYE_T_NAME="$EYE_T_NAME"
EYE_T_GROUP="$EYE_T_GROUP"
EYE_T_INTERVAL="$EYE_T_INTERVAL"
EYE_T_DURATION="$EYE_T_DURATION"
EYE_T_TARGET_COUNT="$EYE_T_TARGET_COUNT"
EYE_T_REMAIN_COUNT="$EYE_T_REMAIN_COUNT"
EYE_T_IS_TEMP="$EYE_T_IS_TEMP"
EYE_T_SOUND_ENABLE="$EYE_T_SOUND_ENABLE"
EYE_T_SOUND_START="$EYE_T_SOUND_START"
EYE_T_SOUND_END="$EYE_T_SOUND_END"
EYE_T_MSG_START='Look away for {DURATION}!'
EYE_T_MSG_END="Eyes rested. Keep going!"
EYE_T_LAST_RUN="$EYE_T_LAST_RUN"
EYE_T_CREATED_AT="$EYE_T_CREATED_AT"
EYE_T_LAST_TRIGGER_AT="$EYE_T_LAST_TRIGGER_AT"
EYE_T_STATUS="$EYE_T_STATUS"
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