#!/bin/bash

# =================核心功能函数=================

# 时间解析函数 (支持 1h 30m 20s 格式)
_parse_duration() {
    local input="$*"
    # 移除所有空格
    input="${input// /}"
    
    # 如果是纯数字，默认为秒
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "$input"
        return
    fi

    local total_seconds=0
    
    # 提取天 (d)
    if [[ "$input" =~ ([0-9]+)d ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 86400))
    fi
    # 提取小时 (h)
    if [[ "$input" =~ ([0-9]+)h ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 3600))
    fi
    # 提取分钟 (m)
    if [[ "$input" =~ ([0-9]+)m ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 60))
    fi
    # 提取秒 (s)
    if [[ "$input" =~ ([0-9]+)s ]]; then
        total_seconds=$((total_seconds + ${BASH_REMATCH[1]}))
    fi

    if [ "$total_seconds" -eq 0 ]; then
        # Check if localized message exists, otherwise generic
        echo "${MSG_ERROR_INVALID_TIME_FORMAT:-Error: Invalid time format}" >&2
        return 1
    fi
    
    echo "$total_seconds"
}

# 格式化秒数为易读格式
_format_duration() {
    local T=$1
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))
    
    [[ $D -gt 0 ]] && printf '%dd ' $D
    [[ $H -gt 0 ]] && printf '%dh ' $H
    [[ $M -gt 0 ]] && printf '%dm ' $M
    [[ $D -eq 0 && $H -eq 0 && $M -eq 0 ]] && printf '%ds' $S || printf '%ds' $S
}
