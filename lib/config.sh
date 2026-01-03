#!/bin/bash

# =================配置管理 (v2.0)=================

# 默认全局配置
DEFAULT_GLOBAL_QUIET="off"
DEFAULT_ROOT_CMD="help"
DEFAULT_LANGUAGE="en"
DEFAULT_SOUND_GLOBAL_OVERRIDE="on"
DEFAULT_TASK="eye_rest"

# 确保至少有一个默认任务 (用于新安装)
_ensure_default_task() {
    # 如果任务目录为空，创建一个默认的护眼任务
    if ! ls "$TASKS_DIR"/* >/dev/null 2>&1; then
        local now=$(date +%s)
        cat > "$TASKS_DIR/eye_rest" <<EOF
NAME="eye_rest"
GROUP="default"
INTERVAL=1200
DURATION=20
TARGET_COUNT=-1
REMAIN_COUNT=-1
IS_TEMP=false
SOUND_ENABLE=true
SOUND_START="default"
SOUND_END="complete"
MSG_START='Look away for {DURATION}!'
MSG_END="Eyes rested. Keep going!"
LAST_RUN=0
CREATED_AT=$now
LAST_TRIGGER_AT=0
STATUS="running"
EOF
    fi
}

# 加载全局配置 (eye.conf)
_load_global_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        # 生成默认全局配置
        cat > "$CONFIG_FILE" <<EOF
GLOBAL_QUIET=$DEFAULT_GLOBAL_QUIET
ROOT_CMD=$DEFAULT_ROOT_CMD
LANGUAGE=$DEFAULT_LANGUAGE
SOUND_GLOBAL_OVERRIDE=$DEFAULT_SOUND_GLOBAL_OVERRIDE
DEFAULT_TASK=$DEFAULT_TASK
EOF
    fi
    
    source "$CONFIG_FILE"
    
    # 确保变量有默认值
    GLOBAL_QUIET=${GLOBAL_QUIET:-$DEFAULT_GLOBAL_QUIET}
    ROOT_CMD=${ROOT_CMD:-$DEFAULT_ROOT_CMD}
    LANGUAGE=${LANGUAGE:-$DEFAULT_LANGUAGE}
    SOUND_GLOBAL_OVERRIDE=${SOUND_GLOBAL_OVERRIDE:-$DEFAULT_SOUND_GLOBAL_OVERRIDE}
    DEFAULT_TASK=${DEFAULT_TASK:-$DEFAULT_TASK}

    # 加载自定义音效映射
    [ -f "$CUSTOM_SOUNDS_MAP" ] && source "$CUSTOM_SOUNDS_MAP"
}

# 保存全局配置
_save_global_config() {
    cat > "$CONFIG_FILE" <<EOF
GLOBAL_QUIET=${GLOBAL_QUIET:-$DEFAULT_GLOBAL_QUIET}
ROOT_CMD=${ROOT_CMD:-$DEFAULT_ROOT_CMD}
LANGUAGE=${LANGUAGE:-$DEFAULT_LANGUAGE}
SOUND_GLOBAL_OVERRIDE=${SOUND_GLOBAL_OVERRIDE:-$DEFAULT_SOUND_GLOBAL_OVERRIDE}
DEFAULT_TASK=${DEFAULT_TASK:-$DEFAULT_TASK}
EOF
}

