#!/bin/bash

# 定义 eye 命令的补全逻辑
_eye_completions()
{
    local cur prev words cword
    _init_completion -n : || return

    # 1. 定义基础命令
    local commands="start stop status now set sound help"
    
    # 2. 定义 sound 子命令
    local sound_commands="list play set add rm on off"

    # 3. 获取所有音效 Tags (内置 + 自定义)
    #    这里需要解析 map 文件
    local sound_tags="none default bell complete success glass alert"
    local map_file="${XDG_CONFIG_HOME:-$HOME/.config}/eye/custom_sounds.map"
    
    if [ -f "$map_file" ]; then
        # 从文件中提取 SOUND_PATH_xxx 中的 xxx
        local custom_tags=$(grep -oP '^SOUND_PATH_\K\w+' "$map_file" 2>/dev/null)
        # 如果系统没有 grep -P (Perl正则)，使用 sed:
        if [ -z "$custom_tags" ]; then
            custom_tags=$(sed -n 's/^SOUND_PATH_\([^=]*\)=.*/\1/p' "$map_file")
        fi
        sound_tags="$sound_tags $custom_tags"
    fi

    # === 逻辑判断 ===

    # 情况 A: 正在输入主命令 (eye [TAB])
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    # 情况 B: 处理二级命令
    case "${words[1]}" in
        sound)
            # 如果正在输入 eye sound [TAB] -> 显示子命令
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$sound_commands" -- "$cur") )
                return 0
            fi

            # 如果是 eye sound xxx [TAB]
            local subcmd="${words[2]}"
            case "$subcmd" in
                play|rm)
                    # eye sound play [TAG] -> 提示音效Tag
                    # eye sound rm [TAG]   -> 提示音效Tag
                    if [[ $cword -eq 3 ]]; then
                        COMPREPLY=( $(compgen -W "$sound_tags" -- "$cur") )
                    fi
                    ;;
                set)
                    # eye sound set [START_TAG] [END_TAG]
                    # 无论是第3个参数还是第4个参数，都提示音效Tag
                    if [[ $cword -ge 3 && $cword -le 4 ]]; then
                        COMPREPLY=( $(compgen -W "$sound_tags" -- "$cur") )
                    fi
                    ;;
                add)
                    # eye sound add [TAG] [PATH]
                    # 第4个参数是路径，使用默认的文件补全
                    if [[ $cword -eq 4 ]]; then
                        _filedir
                    fi
                    ;;
            esac
            ;;
        
        set)
            # eye set [GAP] [LOOK]
            # 这里是数字，暂时无法补全，可以留空或者提示默认值
            ;;
    esac
}

# 注册补全函数
complete -F _eye_completions eye
