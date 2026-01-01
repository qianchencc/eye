#!/bin/bash

# 定义 eye 命令的补全逻辑
_eye_completions()
{
    local cur prev words cword
    _init_completion -n : || return

    # 1. 定义基础命令
    local commands="start stop kill status now pass set sound pause resume config help version"
    
    # 2. 定义 sound 子命令
    local sound_commands="list play set add rm on off"

    # 3. 定义 config 子命令
    local config_commands="mode language autostart update uninstall"

    # 3. 获取所有音效 Tags (内置 + 自定义)
    local sound_tags="none default bell complete success alarm camera device attention"
    local map_file="${XDG_CONFIG_HOME:-$HOME/.config}/eye/custom_sounds.map"
    
    if [ -f "$map_file" ]; then
        local custom_tags=$(sed -n 's/^SOUND_PATH_\([^=]*\)=.*/\1/p' "$map_file")
        sound_tags="$sound_tags $custom_tags"
    fi

    # === 逻辑判断 ===

    # 情况 A: 正在输入主命令 (eye [TAB])
    if [[ $cword -eq 1 ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "-q --quiet -v --version -h --help" -- "$cur") )
        else
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        fi
        return 0
    fi

    # 情况 B: 处理二级命令
    case "${words[1]}" in
        sound)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$sound_commands" -- "$cur") )
                return 0
            fi

            local subcmd="${words[2]}"
            case "$subcmd" in
                play|rm)
                    if [[ $cword -eq 3 ]]; then
                        COMPREPLY=( $(compgen -W "$sound_tags" -- "$cur") )
                    fi
                    ;;
                set)
                    if [[ $cword -ge 3 && $cword -le 4 ]]; then
                        COMPREPLY=( $(compgen -W "$sound_tags" -- "$cur") )
                    fi
                    ;;
                add)
                    if [[ $cword -eq 4 ]]; then
                        _filedir
                    fi
                    ;;
            esac
            ;;
        config)
             if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$config_commands" -- "$cur") )
            else
                local subcmd="${words[2]}"
                case "$subcmd" in
                    mode)
                        if [[ $cword -eq 3 ]]; then
                            COMPREPLY=( $(compgen -W "unix normal" -- "$cur") )
                        fi
                        ;;
                    language)
                        if [[ $cword -eq 3 ]]; then
                            COMPREPLY=( $(compgen -W "en zh English Chinese" -- "$cur") )
                        fi
                        ;;
                    autostart)
                        if [[ $cword -eq 3 ]]; then
                            COMPREPLY=( $(compgen -W "on off" -- "$cur") )
                        fi
                        ;;
                    update)
                        if [[ $cword -eq 3 ]]; then
                            COMPREPLY=( $(compgen -W "--apply --force" -- "$cur") )
                        fi
                        ;;
                    uninstall)
                        ;;
                esac
            fi
            ;;
        pause)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "30m 1h 2h 10m" -- "$cur") )
            fi
            ;;
        pass)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "10m 30m 1h" -- "$cur") )
            fi
            ;;
        now)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "--reset" -- "$cur") )
            fi
            ;;
    esac
}

# 注册补全函数
complete -o nosort -F _eye_completions eye