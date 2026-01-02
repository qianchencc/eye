#!/bin/bash

# ================= 迁移逻辑 (v1.x -> v2.0) =================

_migrate_v1_to_v2() {
    local old_config="$CONFIG_DIR/config"
    local new_task_file="$TASKS_DIR/default"
    
    # 前置检查：
    # 1. 旧配置必须存在
    # 2. 新的任务目录必须为空 (避免覆盖用户已有的 v2 配置)
    if [[ ! -f "$old_config" ]]; then
        return 0
    fi
    
    if ls "$TASKS_DIR"/* >/dev/null 2>&1; then
        # v2 已经在使用中，不自动迁移
        return 0
    fi

    msg_info "🚀 Detected v1.x configuration. Migrating to v2.0..."

    # 读取旧配置 (在一个子 Shell 中读取，以免污染当前环境)
    (
        source "$old_config"
        
        # 转换变量
        NAME="default"
        GROUP="default"
        INTERVAL="${REST_GAP:-1200}"
        DURATION="${LOOK_AWAY:-20}"
        TARGET_COUNT=-1
        REMAIN_COUNT=-1
        IS_TEMP=false
        
        # 音效开关处理
        # v1 SOUND_SWITCH=off 对应 v2 的任务级 SOUND_ENABLE=false 
        # (虽然 v2 也有全局开关，但为了保险，先设在任务上)
        SOUND_ENABLE="true"
        if [[ "$SOUND_SWITCH" == "off" ]]; then
            SOUND_ENABLE="false"
        fi
        
        SOUND_START="${SOUND_START:-default}"
        SOUND_END="${SOUND_END:-complete}"
        
        LAST_RUN=$(date +%s)
        STATUS="running"
        
        # 写入新任务文件
        # 这里不能用 _save_task，因为它依赖当前环境的变量
        # 我们手动写入
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
LAST_RUN="$LAST_RUN"
STATUS="$STATUS"
EOF
    )

    if [ $? -eq 0 ]; then
        msg_success "✅ Migration successful: 'default' task created."
        mv "$old_config" "$old_config.bak"
        msg_info "ℹ️  Old config backed up to config.bak"
    else
        msg_error "❌ Migration failed."
    fi
}
