#!/bin/bash

# =================音频管理=================

# 获取音效路径
_get_sound_path() {
    local tag=$1
    local path=""    
    case "$tag" in
        "none")      echo "NONE"; return ;; 
        "default")   path="/usr/share/sounds/freedesktop/stereo/message.oga" ;; 
        "bell")      path="/usr/share/sounds/freedesktop/stereo/bell.oga" ;; 
        "complete")  path="/usr/share/sounds/freedesktop/stereo/complete.oga" ;; 
        "success")   path="/usr/share/sounds/freedesktop/stereo/service-login.oga" ;; 
        "alarm")     path="/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" ;; 
        "camera")    path="/usr/share/sounds/freedesktop/stereo/camera-shutter.oga" ;; 
        "device")    path="/usr/share/sounds/freedesktop/stereo/device-added.oga" ;; 
        "attention") path="/usr/share/sounds/freedesktop/stereo/window-attention.oga" ;; 
        *)            local custom_var="SOUND_PATH_${tag}"
            path="${!custom_var}" 
            ;; 
    esac

    if [ ! -f "$path" ]; then
         path="/usr/share/sounds/freedesktop/stereo/message.oga"
    fi
    echo "$path"
}

_play() {
    [ "$SOUND_SWITCH" != "on" ] && return
    local tag=$1
    local file=$(_get_sound_path "$tag")
    
    if [ "$file" == "NONE" ]; then
        return
    elif [ -f "$file" ] && command -v paplay > /dev/null; then
        paplay "$file" > /dev/null 2>&1 &
    fi
}

_cmd_sound() {
    local subcmd=$1
    shift
    _load_config

    case "$subcmd" in
        list)
            echo "$MSG_SOUND_LIST_HEADER"
            echo "$MSG_SOUND_LIST_BUILTIN"
            echo "$MSG_SOUND_LIST_ITEM_NONE"
            echo "$MSG_SOUND_LIST_ITEM_DEFAULT"
            echo "$MSG_SOUND_LIST_ITEM_BELL"
            echo "$MSG_SOUND_LIST_ITEM_COMPLETE"
            echo "$MSG_SOUND_LIST_ITEM_SUCCESS"
            echo "$MSG_SOUND_LIST_ITEM_ALARM"
            echo "$MSG_SOUND_LIST_ITEM_CAMERA"
            echo "$MSG_SOUND_LIST_ITEM_DEVICE"
            echo "$MSG_SOUND_LIST_ITEM_ATTENTION"
            
            echo ""
            echo "$MSG_SOUND_LIST_CUSTOM"
            local has_custom=0
            if [ -f "$CUSTOM_SOUNDS_MAP" ]; then
                while IFS='=' read -r key value; do
                    if [[ $key == SOUND_PATH_* ]]; then
                        tag=${key#SOUND_PATH_}
                        echo "  - $tag : $value"
                        has_custom=1
                    fi
                done < "$CUSTOM_SOUNDS_MAP"
            fi
            [ $has_custom -eq 0 ] && echo "$MSG_SOUND_LIST_NONE"
            ;; 
        play)
            local tag=$1
            [ -z "$tag" ] && { msg_error "$MSG_SOUND_PLAY_TAG_REQUIRED"; return 1; }
            local path=$(_get_sound_path "$tag")
            msg_info "$(printf "$MSG_SOUND_PLAY_PLAYING" "$tag" "$path")"
            if [ -f "$path" ]; then
                command -v paplay >/dev/null && paplay "$path"
            elif [ "$tag" == "none" ]; then
                msg_info "$MSG_SOUND_PLAY_MUTE"
            else
                msg_error "$MSG_SOUND_PLAY_ERROR"
            fi
            ;; 
        set)
            local s1=${1:-$SOUND_START}
            local s2=${2:-$SOUND_END}
            SOUND_START=$s1
            SOUND_END=$s2
            _save_config
            msg_success "$(printf "$MSG_SOUND_SET_UPDATED" "$s1" "$s2")"
            ;; 
        add)
            local tag=$1
            local path=$2
            if [ -z "$tag" ] || [ -z "$path" ]; then
                msg_error "$MSG_SOUND_ADD_USAGE"
                return 1
            fi
            if [[ " none default bell complete success alarm camera device attention " =~ " $tag " ]]; then
                 msg_error "$(printf "$MSG_SOUND_ADD_ERROR_BUILTIN" "$tag")"
                 return 1
            fi
            if [ ! -f "$path" ]; then
                msg_error "$(printf "$MSG_SOUND_ADD_ERROR_FILE" "$path")"
                return 1
            fi
            if grep -q "SOUND_PATH_${tag}=" "$CUSTOM_SOUNDS_MAP" 2>/dev/null; then
                printf "$MSG_SOUND_ADD_CONFIRM_REPLACE" "$tag"
                read choice
                [[ "$choice" != "y" && "$choice" != "Y" ]] && return
            fi
            local abs_path=$(readlink -f "$path")
            [ -f "$CUSTOM_SOUNDS_MAP" ] && sed -i "/SOUND_PATH_${tag}=/d" "$CUSTOM_SOUNDS_MAP"
            echo "SOUND_PATH_${tag}=\"${abs_path}\"" >> "$CUSTOM_SOUNDS_MAP"
            msg_success "$(printf "$MSG_SOUND_ADD_ADDED" "$tag")"
            ;; 
        rm)
            local tag=$1
            if [ -z "$tag" ]; then
                msg_error "$MSG_SOUND_RM_USAGE"
                return 1
            fi
            if [[ " none default bell complete success alarm camera device attention " =~ " $tag " ]]; then
                 msg_error "$(printf "$MSG_SOUND_RM_ERROR_BUILTIN" "$tag")"
                 return 1
            fi
            if [ -f "$CUSTOM_SOUNDS_MAP" ]; then
                if grep -q "SOUND_PATH_${tag}=" "$CUSTOM_SOUNDS_MAP"; then
                    sed -i "/SOUND_PATH_${tag}=/d" "$CUSTOM_SOUNDS_MAP"
                    msg_success "$(printf "$MSG_SOUND_RM_DELETED" "$tag")"
                else
                    msg_error "$(printf "$MSG_SOUND_RM_NOT_FOUND" "$tag")"
                fi
            else
                msg_warn "$MSG_SOUND_RM_NO_CUSTOM"
            fi
            ;; 
        on)
            SOUND_SWITCH="on"; _save_config; msg_success "$MSG_SOUND_ON" ;; 
        off)
            SOUND_SWITCH="off"; _save_config; msg_success "$MSG_SOUND_OFF" ;; 
        *)
            echo "$MSG_SOUND_USAGE" ;; 
    esac
}
