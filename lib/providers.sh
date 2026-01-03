#!/bin/bash

# ================= 交互提供者 (lib/providers.sh) =================

# --- 通知提供者 (Notification Providers) ---

_provider_notify_desktop() {
    local title="$1" body="$2" timeout="$3"
    notify-send -t "$timeout" "$title" "$body"
}

_provider_notify_wall() {
    local title="$1" body="$2"
    echo -e "[$title]\n$body" | wall
}

_provider_notify_tmux() {
    local title="$1" body="$2"
    if [[ -n "$TMUX" ]]; then
        tmux display-message "[$title] $body"
    fi
}

_notify_provider() {
    local title="$1" body="$2" timeout="${3:-5000}"
    local backend="${NOTIFY_BACKEND:-auto}"

    case "$backend" in
        desktop) _provider_notify_desktop "$title" "$body" "$timeout" ;;
        wall)    _provider_notify_wall    "$title" "$body" ;;
        tmux)    _provider_notify_tmux    "$title" "$body" ;;
        auto|*) 
            # 智能自动探测
            if command -v notify-send >/dev/null 2>&1; then
                _provider_notify_desktop "$title" "$body" "$timeout"
            elif [[ -n "$TMUX" ]]; then
                _provider_notify_tmux    "$title" "$body"
            else
                _provider_notify_wall    "$title" "$body"
            fi
            ;;
    esac
}

# --- 音频提供者 (Sound Providers) ---

_provider_play_paplay() {
    local file="$1"
    paplay "$file" >/dev/null 2>&1
}

_provider_play_mpv() {
    local file="$1"
    mpv --no-video --really-quiet "$file" >/dev/null 2>&1
}

_provider_play_aplay() {
    local file="$1"
    aplay -q "$file" >/dev/null 2>&1
}

_play_provider() {
    local tag="$1"
    [[ "$SOUND_GLOBAL_OVERRIDE" == "off" ]] && return

    local file=$(_get_sound_path "$tag")
    [[ "$file" == "NONE" || ! -f "$file" ]] && return

    local backend="${SOUND_BACKEND:-auto}"

    case "$backend" in
        paplay) _provider_play_paplay "$file" ;;
        mpv)    _provider_play_mpv    "$file" ;;
        aplay)  _provider_play_aplay  "$file" ;;
        auto|*) 
            if command -v paplay >/dev/null 2>&1; then
                _provider_play_paplay "$file"
            elif command -v mpv >/dev/null 2>&1; then
                _provider_play_mpv    "$file"
            elif command -v aplay >/dev/null 2>&1; then
                _provider_play_aplay  "$file"
            fi
            ;;
    esac
}
