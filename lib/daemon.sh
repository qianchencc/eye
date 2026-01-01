#!/bin/bash

# =================后台进程逻辑=================

_eye_action() {
    local reset_timer=${1:-true}
    _load_config
    _init_messages
    
    local look_fmt=$(_format_duration ${LOOK_AWAY})
    local body_start=$(printf "$MSG_NOTIFY_BODY_START" "$look_fmt")
    
    notify-send -i appointment-soon -t 5000 "$MSG_NOTIFY_TITLE_START" "$body_start"
    _play "$SOUND_START"
    
    sleep "$LOOK_AWAY"
    
    notify-send -i emblem-success -t 3000 "$MSG_NOTIFY_TITLE_END" "$MSG_NOTIFY_BODY_END"
    _play "$SOUND_END"
    
    if [ "$reset_timer" == "true" ]; then
        date +%s > "$EYE_LOG"
    fi
}

# 守护进程主循环
IS_ACTING=0
_check_trigger() {
    # 如果正在执行动作，则忽略
    [ "$IS_ACTING" -eq 1 ] && return
    
    _load_config
    # _init_messages # Loop already calls it? Maybe better here too
    
    local current_time=$(date +%s)
    
    # Pause check
    if [ -f "$PAUSE_FILE" ]; then
        pause_until=$(cat "$PAUSE_FILE")
        if [ "$current_time" -lt "$pause_until" ]; then
             return
        else
             rm "$PAUSE_FILE" 
             # Resume logic: add paused duration
             if [ -f "$PAUSE_START_FILE" ]; then
                 start_pause=$(cat "$PAUSE_START_FILE")
                 duration=$((current_time - start_pause))
                 old_last=$(cat "$EYE_LOG" 2>/dev/null || echo $current_time)
                 new_last=$((old_last + duration))
                 echo "$new_last" > "$EYE_LOG"
                 rm "$PAUSE_START_FILE"
             fi
        fi
    fi

    local last_time=$(cat "$EYE_LOG" 2>/dev/null || date +%s)
    if [ $((current_time - last_time)) -ge $REST_GAP ]; then
         IS_ACTING=1
         _eye_action true # Run in foreground of this function/subshell
         IS_ACTING=0
    fi
}

_daemon_loop() {
    echo $BASHPID > "$PID_FILE"
    
    # Handle Stop Resume
    if [ -f "$STOP_FILE" ]; then
        stop_time=$(cat "$STOP_FILE")
        current_time=$(date +%s)
        stopped_duration=$((current_time - stop_time))
        old_last=$(cat "$EYE_LOG" 2>/dev/null || echo $current_time)
        new_last=$((old_last + stopped_duration))
        echo "$new_last" > "$EYE_LOG"
        rm "$STOP_FILE"
    fi
    
    if [ ! -f "$EYE_LOG" ]; then
        date +%s > "$EYE_LOG"
    fi
    
    # 注册信号处理
    trap '_check_trigger' SIGUSR1
    
    while true; do
        _check_trigger
        
        # 使用 sleep & wait 实现可中断的 sleep
        sleep 5 &
        wait $!
    done
}

_cmd_autostart() {
    local action=$1
    if [[ "$action" == "on" ]]; then
        mkdir -p "$SYSTEMD_DIR"
        
        # 2. 获取 eye 可执行文件的绝对路径
        # 由于我们重构了，这里 eye 指向的是 loader。
        # 在 systemd 中，我们需要调用 bin/eye
        # 我们假设用户已经安装到了 ~/.local/bin/eye
        local install_path="${HOME}/.local/bin/eye"
        
        if [ ! -x "$install_path" ]; then
             # 如果标准路径不存在，尝试使用当前解析的路径
             install_path=$(readlink -f "$0")
        fi

        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Eye Protection Tool
After=graphical-session.target

[Service]
Type=simple
ExecStart=$install_path daemon
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
        
        systemctl --user daemon-reload
        systemctl --user enable eye.service >/dev/null 2>&1
        systemctl --user start eye.service >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            msg_success "$MSG_AUTOSTART_ON"
        else
            msg_error "$MSG_AUTOSTART_ERROR"
        fi
        
    elif [[ "$action" == "off" ]]; then
        systemctl --user stop eye.service >/dev/null 2>&1
        systemctl --user disable eye.service >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
        systemctl --user daemon-reload
        msg_success "$MSG_AUTOSTART_OFF"
    else
        echo "Usage: eye autostart [on|off]"
    fi
}
