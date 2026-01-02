#!/bin/bash

# Definition for eye command completion (v2.0)

_eye_completions()
{
    local cur prev words cword
    _init_completion -n : || return

    # 1. Base Commands
    local commands="add list remove edit in start stop pause resume now daemon status sound config help version"
    
    # 2. Subcommands
    local daemon_commands="up down reload enable disable root-cmd quiet"
    local config_commands="language quiet"
    local sound_commands="list play add rm on off"
    
    # 3. Dynamic Resources
    local tasks_dir="${XDG_CONFIG_HOME:-$HOME/.config}/eye/tasks"
    
    _get_tasks() {
        if [ -d "$tasks_dir" ]; then
            /bin/ls "$tasks_dir" 2>/dev/null
        fi
    }
    
    _get_groups() {
        if [ -d "$tasks_dir" ]; then
            # Extract content between quotes in GROUP="value"
            grep -h "GROUP=" "$tasks_dir"/* 2>/dev/null | cut -d'"' -f2 | sort -u | sed 's/^/@/'
        fi
    }

    # === Logic ===

    # Find the main command (skip flags)
    local cmd=""
    local cmd_idx=0
    for ((i=1; i<cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            cmd="${words[i]}"
            cmd_idx=$i
            break
        fi
    done

    # Case A: Completing main command
    if [[ -z "$cmd" || $cword -eq $cmd_idx ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "-q --quiet -v --version -h --help" -- "$cur") )
        else
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        fi
        return 0
    fi

    # Case B: Completing arguments for commands
    case "$cmd" in
        # Task ID or Group Arguments
        remove|edit|start|stop|pause|resume|now)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                local tasks=$(_get_tasks)
                local groups=$(_get_groups)
                COMPREPLY=( $(compgen -W "$tasks $groups" -- "$cur") )
            fi
            ;;
        
        # Daemon Control
        daemon)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$daemon_commands" -- "$cur") )
            fi
            ;;

        # Config
        config)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$config_commands" -- "$cur") )
            else
                local subcmd="${words[cmd_idx+1]}"
                case "$subcmd" in
                    language)
                        COMPREPLY=( $(compgen -W "en zh" -- "$cur") ) ;;
                    quiet)
                        COMPREPLY=( $(compgen -W "on off" -- "$cur") ) ;;
                esac
            fi
            ;;
        
        # Sound
        sound)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$sound_commands" -- "$cur") )
            else
                # ... (Simplified sound completion logic)
                local subcmd="${words[cmd_idx+1]}"
                case "$subcmd" in
                    play|rm)
                         # Simple hardcoded common tags + logic to scan map if needed
                         COMPREPLY=( $(compgen -W "default bell complete" -- "$cur") )
                         ;;
                    on|off)
                         # Support toggling specific tasks
                         local tasks=$(_get_tasks)
                         COMPREPLY=( $(compgen -W "$tasks" -- "$cur") )
                         ;;
                esac
            fi
            ;;
            
        # Add Command Options
        add)
             if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--interval --duration --group --count --temp" -- "$cur") )
             fi
             ;;
    esac
}

complete -o nosort -F _eye_completions eye
