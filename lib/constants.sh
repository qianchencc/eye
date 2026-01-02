#!/bin/bash

# =================配置与路径定义 (XDG准则)=================
export EYE_VERSION="0.2.0-beta"

# Detect Library Directory (if not already set) and Source/Install Mode
if [ -z "$LIB_DIR" ]; then
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
      DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    LIB_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
fi

# Resource Paths
if [ -d "$LIB_DIR/../assets" ]; then
    # Dev Mode: assets are in the project root
    EYE_SHARE_DIR="$(cd "$LIB_DIR/.." && pwd)"
else
    # Prod Mode: assets are in XDG_DATA_HOME/eye or standard system share
    # Default to /usr/local/share/eye or ~/.local/share/eye based on installation prefix
    # We assume if not in dev, we are in structure .../lib/eye, so .../share/eye is ../../share/eye
    # However, safest is to default to the XDG location which we will use in Makefile
    EYE_SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/eye"
fi
EYE_SOUNDS_DIR="$EYE_SHARE_DIR/assets/sounds"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eye"
TASKS_DIR="$CONFIG_DIR/tasks"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/eye"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eye"

if [ -n "$EYE_CONFIG" ]; then
    CONFIG_FILE="$EYE_CONFIG"
else
    CONFIG_FILE="$CONFIG_DIR/eye.conf"
fi

GLOBAL_CONF="$CONFIG_FILE"
HISTORY_LOG="$STATE_DIR/history.log"

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
mkdir -p "$(dirname "$CONFIG_FILE")" "$TASKS_DIR" "$DATA_DIR/sounds" "$STATE_DIR"

# 默认配置
DEFAULT_REST_GAP=1200
DEFAULT_LOOK_AWAY=20
DEFAULT_SOUND_START="default"
DEFAULT_SOUND_END="complete"
DEFAULT_SOUND_SWITCH="on"
DEFAULT_LANGUAGE="en"
DEFAULT_EYE_MODE="unix"
