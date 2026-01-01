#!/bin/bash

# =================配置与路径定义 (XDG准则)=================
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eye"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/eye"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eye"

if [ -n "$EYE_CONFIG" ]; then
    CONFIG_FILE="$EYE_CONFIG"
else
    CONFIG_FILE="$CONFIG_DIR/config"
fi

CUSTOM_SOUNDS_MAP="$CONFIG_DIR/custom_sounds.map"
EYE_LOG="$STATE_DIR/last_notified"
PID_FILE="$STATE_DIR/daemon.pid"
PAUSE_FILE="$STATE_DIR/pause_until"
PAUSE_START_FILE="$STATE_DIR/pause_start"
STOP_FILE="$STATE_DIR/stop_time"
BREAK_LOCK_FILE="$STATE_DIR/break.lock"

# Systemd user service path
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_FILE="$SYSTEMD_DIR/eye.service"

# 确保目录存在
mkdir -p "$(dirname "$CONFIG_FILE")" "$DATA_DIR/sounds" "$STATE_DIR"

# 默认配置
DEFAULT_REST_GAP=1200
DEFAULT_LOOK_AWAY=20
DEFAULT_SOUND_START="default"
DEFAULT_SOUND_END="complete"
DEFAULT_SOUND_SWITCH="on"
DEFAULT_LANGUAGE="en"
DEFAULT_EYE_MODE="unix"
