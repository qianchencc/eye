#!/bin/bash

# Definition for eye command completion (v2.0 Refactored)

_eye_completions()
{
    local cur prev words cword
    _init_completion -n : || return

    # 1. Base Commands
    local commands="add list remove rm edit in start stop pause resume now time count reset daemon status sound help version"
    
    # 2. Subcommands
    local daemon_commands="up down enable disable default quiet root-cmd language help"
    local sound_commands="list play add rm on off help"
    
    # 3. Dynamic Resources
    local tasks_dir="${XDG_CONFIG_HOME:-$HOME/.config}/eye/tasks"
    
    _get_tasks() {
        if [ -d "$tasks_dir" ]; then
            /bin/ls "$tasks_dir" 2>/dev/null
        fi
    }
    
    _get_groups() {
        if [ -d "$tasks_dir" ]; then
            grep -h "GROUP=" "$tasks_dir"/* 2>/dev/null | cut -d'"' -f2 | sort -u | sed 's/^/@/'
        fi
    }

    # === Logic ===

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
        remove|edit|start|stop|pause|resume|now|time|count|reset)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                # Some commands take a value first (time, count), handled loosely here
                # time/count take <delta> first, then task.
                if [[ "$cmd" == "time" || "$cmd" == "count" ]]; then
                    # Could suggest typical deltas, but let's just suggest tasks for 2nd arg
                    if [[ "$prev" != "time" && "$prev" != "count" ]]; then 
                        local tasks=$(_get_tasks)
                        local groups=$(_get_groups)
                        COMPREPLY=( $(compgen -W "$tasks $groups" -- "$cur") )
                    fi
                elif [[ "$cmd" == "reset" ]]; then
                     local tasks=$(_get_tasks)
                     local groups=$(_get_groups)
                     COMPREPLY=( $(compgen -W "$tasks $groups --time --count --all" -- "$cur") )
                else
                    local tasks=$(_get_tasks)
                    local groups=$(_get_groups)
                    COMPREPLY=( $(compgen -W "$tasks $groups" -- "$cur") )
                fi
            elif [[ "$cmd" == "reset" ]]; then
                # After target, suggest flags
                COMPREPLY=( $(compgen -W "--time --count --all" -- "$cur") )
            fi
            ;;
        
        # Daemon Control
        daemon)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$daemon_commands" -- "$cur") )
            else
                local subcmd="${words[cmd_idx+1]}"
                case "$subcmd" in
                    default)
                         local tasks=$(_get_tasks)
                         COMPREPLY=( $(compgen -W "$tasks" -- "$cur") ) ;;
                    quiet)
                        COMPREPLY=( $(compgen -W "on off" -- "$cur") ) ;;
                    language)
                        COMPREPLY=( $(compgen -W "en zh" -- "$cur") ) ;;
                    root-cmd)
                        COMPREPLY=( $(compgen -W "status help" -- "$cur") ) ;;
                esac
            fi
            ;;
        
        # Sound
        sound)
            if [[ $((cword - cmd_idx)) -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$sound_commands" -- "$cur") )
            else
                local subcmd="${words[cmd_idx+1]}"
                case "$subcmd" in
                    play|rm)
                         COMPREPLY=( $(compgen -W "default bell complete success alarm camera device attention" -- "$cur") )
                         ;;
                    on|off)
                         local tasks=$(_get_tasks)
                         COMPREPLY=( $(compgen -W "$tasks" -- "$cur") )
                         ;;
                esac
            fi
            ;;
            
        # Add Command Options
        add)
             if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--interval --duration --group" -- "$cur") )
             fi
             ;;
    esac
}

complete -o nosort -F _eye_completions eye