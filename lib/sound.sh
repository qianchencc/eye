#!/bin/bash

# =================音频管理=================

# 获取音效路径
_get_sound_path() {
    local tag=$1
    local filename=""
    
    # 1. Handle Custom Tags
    if [[ ! " none default bell complete success alarm camera device attention " =~ " $tag " ]]; then
        local custom_var="SOUND_PATH_${tag}"
        local custom_path="${!custom_var}"
        if [ -n "$custom_path" ] && [ -f "$custom_path" ]; then
            echo "$custom_path"
            return
        fi
        # If custom tag not found or file missing, fallback to default sound
        tag="default"
    fi

    # 2. Resolve Filename for Built-in Tags
    case "$tag" in
        "none")      echo "NONE"; return ;; 
        "default")   filename="message.oga" ;; 
        "bell")      filename="bell.oga" ;; 
        "complete")  filename="complete.oga" ;; 
        "success")   filename="service-login.oga" ;; 
        "alarm")     filename="alarm-clock-elapsed.oga" ;; 
        "camera")    filename="camera-shutter.oga" ;; 
        "device")    filename="device-added.oga" ;; 
        "attention") filename="window-attention.oga" ;; 
    esac

    # 3. Check App Bundled Sounds
    if [ -n "$EYE_SOUNDS_DIR" ] && [ -f "$EYE_SOUNDS_DIR/$filename" ]; then
        echo "$EYE_SOUNDS_DIR/$filename"
        return
    fi

    # 4. Check System Sounds
    echo "/usr/share/sounds/freedesktop/stereo/$filename"
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
    _load_global_config

    case "$subcmd" in
        list)
            # Headers to stderr
            echo "$MSG_SOUND_LIST_HEADER" >&2
            echo "$MSG_SOUND_LIST_BUILTIN" >&2
            
            # Data to stdout
            msg_data "$MSG_SOUND_LIST_ITEM_NONE"
            msg_data "$MSG_SOUND_LIST_ITEM_DEFAULT"
            msg_data "$MSG_SOUND_LIST_ITEM_BELL"
            msg_data "$MSG_SOUND_LIST_ITEM_COMPLETE"
            msg_data "$MSG_SOUND_LIST_ITEM_SUCCESS"
            msg_data "$MSG_SOUND_LIST_ITEM_ALARM"
            msg_data "$MSG_SOUND_LIST_ITEM_CAMERA"
            msg_data "$MSG_SOUND_LIST_ITEM_DEVICE"
            msg_data "$MSG_SOUND_LIST_ITEM_ATTENTION"
            
            echo "" >&2
            echo "$MSG_SOUND_LIST_CUSTOM" >&2
            local has_custom=0
            if [ -f "$CUSTOM_SOUNDS_MAP" ]; then
                while IFS='=' read -r key value; do
                    if [[ $key == SOUND_PATH_* ]]; then
                        tag=${key#SOUND_PATH_}
                        # Value contains quotes, remove them
                        clean_val="${value%\"}"
                        clean_val="${clean_val#\"}"
                        msg_data "  - $tag : $clean_val"
                        has_custom=1
                    fi
                done < "$CUSTOM_SOUNDS_MAP"
            fi
            [ $has_custom -eq 0 ] && echo "$MSG_SOUND_LIST_NONE" >&2
            ;; 
        play)
            local tag=$1
            [ -z "$tag" ] && tag=$(_read_input)
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
            local input_str=$(_read_input "$@")
            read -r s1 s2 <<< "$input_str"
            s1=${s1:-$SOUND_START}
            s2=${s2:-$SOUND_END}
            SOUND_START=$s1
            SOUND_END=$s2
            _save_global_config
            msg_success "$(printf "$MSG_SOUND_SET_UPDATED" "$s1" "$s2")"
            ;; 
        add)
            local tag=$1
            local path=$2
            if [ -z "$tag" ]; then
                read -r tag path <<< "$(_read_input)"
            fi
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
            
            local abs_path=$(readlink -f "$path")
            
            # Idempotency check
            if grep -q "SOUND_PATH_${tag}=" "$CUSTOM_SOUNDS_MAP" 2>/dev/null; then
                # Extract existing path
                existing_line=$(grep "SOUND_PATH_${tag}=" "$CUSTOM_SOUNDS_MAP")
                existing_path="${existing_line#*=}"
                existing_path="${existing_path%\"}"
                existing_path="${existing_path#\"}"
                
                if [ "$existing_path" == "$abs_path" ]; then
                    # Same path, silent success
                    if [ "$EYE_MODE" == "unix" ] || [ -n "$QUIET_MODE" ]; then
                        return 0
                    else
                        msg_warn "Sound tag '$tag' already points to '$abs_path'."
                        return 0
                    fi
                fi
                
                # Different path, ask/overwrite
                if [ -t 0 ]; then
                    printf "$MSG_SOUND_ADD_CONFIRM_REPLACE" "$tag"
                    read choice
                    [[ "$choice" != "y" && "$choice" != "Y" ]] && return
                else
                    true # Overwrite if piped
                fi
            fi
            
            [ -f "$CUSTOM_SOUNDS_MAP" ] && sed -i "/SOUND_PATH_${tag}=/d" "$CUSTOM_SOUNDS_MAP"
            echo "SOUND_PATH_${tag}=\"${abs_path}\"" >> "$CUSTOM_SOUNDS_MAP"
            msg_success "$(printf "$MSG_SOUND_ADD_ADDED" "$tag")"
            ;; 
        rm)
            local tag=$1
            [ -z "$tag" ] && tag=$(_read_input)
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
            SOUND_SWITCH="on"; _save_global_config; msg_success "$MSG_SOUND_ON" ;; 
        off)
            SOUND_SWITCH="off"; _save_global_config; msg_success "$MSG_SOUND_OFF" ;; 
        *)
            echo "$MSG_SOUND_USAGE" ;; 
    esac
}
