#!/bin/bash

# ================= Internationalization =================
_init_messages() {
    # Detect language
    if [[ "$LANGUAGE" == "zh" ]] || [[ "$LANGUAGE" == "Chinese" ]]; then
        LANG_MODE="zh"
    elif [[ "$LANGUAGE" == "en" ]] || [[ "$LANGUAGE" == "English" ]]; then
        LANG_MODE="en"
    elif [[ -z "$LANGUAGE" ]]; then
        if [[ "$LANG" == zh* ]]; then
            LANG_MODE="zh"
        else
            LANG_MODE="en"
        fi
    else
        LANG_MODE="en"
    fi

    if [ "$LANG_MODE" == "zh" ]; then
        # --- Chinese (Simplified) ---
        MSG_USAGE_HEADER="用法: eye <command> [args]"
        MSG_USAGE_CORE="任务控制 (支持 @group, --all):"
        MSG_USAGE_CMD_START="  start [target]   启动/恢复任务 (默认: @default)"
        MSG_USAGE_CMD_STOP="  stop [target]    停止任务"
        MSG_USAGE_CMD_PAUSE="  pause [target]   暂停任务"
        MSG_USAGE_CMD_RESUME="  resume [target]  恢复任务"
        MSG_USAGE_CMD_NOW="  now [task]       立即触发一次任务"
        MSG_USAGE_CMD_RESET="  reset [target]   重置任务 (需配合 --time/--count)"
        MSG_USAGE_CMD_TIME="  time <delta>     快进/快退计时 (如: +10m, -5s)"
        MSG_USAGE_CMD_COUNT="  count <delta>    修改计数 (如: +1, -1)"
        
        MSG_USAGE_MANAGE="任务管理:"
        MSG_USAGE_CMD_ADD="  add <name>       创建任务 (支持交互/参数)"
        MSG_USAGE_CMD_RM="  remove <id>      删除任务"
        MSG_USAGE_CMD_EDIT="  edit <id>        修改任务"
        MSG_USAGE_CMD_LIST="  list             列出所有任务"
        MSG_USAGE_CMD_STATUS="  status           显示全状态看板 (支持排序)"
        
        MSG_USAGE_SUB="子系统:"
        MSG_USAGE_CMD_DAEMON="  daemon ...       守护进程管理 (启动/开机自启/设置)"
        MSG_USAGE_CMD_SOUND="  sound ...        音频管理"

        # Help Messages
        MSG_HELP_DAEMON_HEADER="用法: eye daemon <command>"
        MSG_HELP_DAEMON_CMDS="命令:\n  up             启动守护进程\n  down           停止守护进程\n  enable         开启开机自启 (Systemd)\n  disable        关闭开机自启\n  default <task> 设置默认任务目标\n  quiet <on|off> 静默模式\n  language <zh|en> 语言设置\n  root-cmd <cmd> 设置根指令行为\n  help           显示此帮助"
        
        MSG_HELP_SOUND_HEADER="用法: eye sound <command>"
        MSG_HELP_SOUND_CMDS="命令:\n  list           列出可用音效\n  play <tag>     试听\n  add <tag> <path> 添加自定义\n  rm <tag>       删除自定义\n  on [task]      全局开启 (或开启特定任务)\n  off [task]     全局强制静音 (或关闭特定任务)\n  help           显示此帮助"
        
        MSG_HELP_ADD_USAGE="用法: eye add <name> [options]\n选项:\n  -i, --interval <time>  间隔\n  -d, --duration <time>  时长\n  -g, --group <name>     分组"
        
        # General Messages
        MSG_TASK_CREATED="✅ 任务已创建: %s"
        MSG_TASK_REMOVED="🗑️  任务已删除: %s"
        MSG_TASK_NOT_FOUND="❌ 未找到任务: %s"
        MSG_TASK_LIST_HEADER="任务列表:"
        MSG_TASK_ID="ID"
        MSG_TASK_NAME="名称"
        MSG_TASK_GROUP="组"
        MSG_TASK_INTERVAL="间隔"
        MSG_TASK_DURATION="持续"
        MSG_TASK_COUNT="计数"
        MSG_TASK_STATUS="状态"
        
        MSG_NOTIFY_TITLE_START="护眼提醒"
        MSG_NOTIFY_BODY_START="请远眺 ${DURATION}！"
        MSG_NOTIFY_TITLE_END="休息结束"
        MSG_NOTIFY_BODY_END="眼睛休息完毕，继续工作吧。"
        MSG_ERROR_INVALID_TIME_FORMAT="错误: 时间格式无效"
        
        MSG_SOUND_ON="全局音效: 开启 (尊重任务配置)"
        MSG_SOUND_OFF="全局音效: 关闭 (强制静音)"

        MSG_SOUND_LIST_HEADER="可用音效:"
        MSG_SOUND_LIST_BUILTIN="  [内置]"
        MSG_SOUND_LIST_CUSTOM="  [自定义]"
        MSG_SOUND_LIST_NONE="  (无)"
        MSG_SOUND_LIST_ITEM_NONE="  - none      : 静音"
        MSG_SOUND_LIST_ITEM_DEFAULT="  - default   : 标准"
        MSG_SOUND_LIST_ITEM_BELL="  - bell      : 铃声"
        MSG_SOUND_LIST_ITEM_COMPLETE="  - complete  : 完成"
        MSG_SOUND_LIST_ITEM_SUCCESS="  - success   : 成功"
        MSG_SOUND_LIST_ITEM_ALARM="  - alarm     : 闹钟"
        MSG_SOUND_LIST_ITEM_CAMERA="  - camera    : 快门"
        MSG_SOUND_LIST_ITEM_DEVICE="  - device    : 设备"
        MSG_SOUND_LIST_ITEM_ATTENTION="  - attention : 注意"

        MSG_SOUND_PLAY_TAG_REQUIRED="错误: 请指定标签。"
        MSG_SOUND_PLAY_PLAYING="正在播放 [%s] : %s"
        MSG_SOUND_PLAY_MUTE="(静音)"
        MSG_SOUND_PLAY_ERROR="错误: 无法播放文件。"
        MSG_SOUND_ADD_USAGE="用法: eye sound add <tag> <path>"
        MSG_SOUND_ADD_ERROR_BUILTIN="错误: '%s' 是内置音效，无法覆盖。"
        MSG_SOUND_ADD_ERROR_FILE="错误: 文件不存在: %s"
        MSG_SOUND_ADD_CONFIRM_REPLACE="标签 '%s' 已存在，覆盖? [y/N] "
        MSG_SOUND_ADD_ADDED="已添加: %s"
        MSG_SOUND_RM_USAGE="用法: eye sound rm <tag>"
        MSG_SOUND_RM_ERROR_BUILTIN="错误: '%s' 是内置音效，无法删除。"
        MSG_SOUND_RM_DELETED="已删除: %s"
        MSG_SOUND_RM_NOT_FOUND="错误: 未找到标签: %s"
        MSG_SOUND_RM_NO_CUSTOM="无自定义配置。"

        # Wizard Prompts
        MSG_WIZARD_INTERVAL="间隔 (如: 20m, 1h)"
        MSG_WIZARD_DURATION="持续时间 (如: 20s; 设为 0s 即为脉冲任务)"
        MSG_WIZARD_SOUND_ENABLE="启用音效?"
        MSG_WIZARD_SOUND_START="  开始音效标签 (留空默认: %s)"
        MSG_WIZARD_SOUND_END="  结束音效标签 (留空默认: %s)"
        MSG_WIZARD_MSG_START="  开始提醒文案"
        MSG_WIZARD_MSG_END="  结束提醒文案"
        MSG_WIZARD_COUNT="循环次数 (-1 为无限)"
        MSG_WIZARD_IS_TEMP="是否为临时任务? (计数结束即删除任务)"
        MSG_WIZARD_CONFIRM="确认创建?"
    else

        # --- English ---
        MSG_USAGE_HEADER="Usage: eye <command> [args]"
        MSG_USAGE_CORE="Task Control (supports @group, --all):"
        MSG_USAGE_CMD_START="  start [target]   Start/Resume tasks (default: @default)"
        MSG_USAGE_CMD_STOP="  stop [target]    Stop tasks"
        MSG_USAGE_CMD_PAUSE="  pause [target]   Pause tasks"
        MSG_USAGE_CMD_RESUME="  resume [target]  Resume tasks"
        MSG_USAGE_CMD_NOW="  now [task]       Trigger task immediately"
        MSG_USAGE_CMD_RESET="  reset [target]   Reset task metrics (needs --time/--count)"
        MSG_USAGE_CMD_TIME="  time <delta>     Shift time (e.g., +10m, -5s)"
        MSG_USAGE_CMD_COUNT="  count <delta>    Shift count (e.g., +1, -1)"
        
        MSG_USAGE_MANAGE="Task Management:"
        MSG_USAGE_CMD_ADD="  add <name>       Create task (interactive/flags)"
        MSG_USAGE_CMD_RM="  remove <id>      Delete task"
        MSG_USAGE_CMD_EDIT="  edit <id>        Edit task"
        MSG_USAGE_CMD_LIST="  list             List all tasks"
        MSG_USAGE_CMD_STATUS="  status           Show status dashboard (sortable)"
        
        MSG_USAGE_SUB="Subsystems:"
        MSG_USAGE_CMD_DAEMON="  daemon ...       Daemon management (up/enable/config)"
        MSG_USAGE_CMD_SOUND="  sound ...        Audio management"

        # Help Messages
        MSG_HELP_DAEMON_HEADER="Usage: eye daemon <command>"
        MSG_HELP_DAEMON_CMDS="Commands:\n  up             Start daemon\n  down           Stop daemon\n  enable         Enable autostart (Systemd)\n  disable        Disable autostart\n  default <task> Set default task target\n  quiet <on|off> Quiet mode\n  language <zh|en> Set language\n  root-cmd <cmd> Set root command action\n  help           Show this help"
        
        MSG_HELP_SOUND_HEADER="Usage: eye sound <command>"
        MSG_HELP_SOUND_CMDS="Commands:\n  list           List sounds\n  play <tag>     Preview\n  add <tag> <file> Add custom sound\n  rm <tag>       Remove custom sound\n  on [task]      Global ON (or enable task)\n  off [task]     Global Force Mute (or disable task)\n  help           Show this help"
        
        MSG_HELP_ADD_USAGE="Usage: eye add <name> [options]\nOptions:\n  -i, --interval <time>\n  -d, --duration <time>\n  -g, --group <name>"
        
        # General Messages
        MSG_TASK_CREATED="✅ Task created: %s"
        MSG_TASK_REMOVED="🗑️  Task removed: %s"
        MSG_TASK_NOT_FOUND="❌ Task not found: %s"
        MSG_TASK_LIST_HEADER="Task List:"
        MSG_TASK_ID="ID"
        MSG_TASK_NAME="Name"
        MSG_TASK_GROUP="Group"
        MSG_TASK_INTERVAL="Interval"
        MSG_TASK_DURATION="Duration"
        MSG_TASK_COUNT="Count"
        MSG_TASK_STATUS="Status"
        
        MSG_NOTIFY_TITLE_START="Eye Protection"
        MSG_NOTIFY_BODY_START="Look away for ${DURATION}!"
        MSG_NOTIFY_TITLE_END="Break Ended"
        MSG_NOTIFY_BODY_END="Eyes rested. Keep going!"
        MSG_ERROR_INVALID_TIME_FORMAT="Error: Invalid time format"
        
        MSG_SOUND_ON="Global Sound: ON (Respecting tasks)"
        MSG_SOUND_OFF="Global Sound: OFF (Forced Mute)"

        MSG_SOUND_LIST_HEADER="Available Sounds:"
        MSG_SOUND_LIST_BUILTIN="  [Built-in]"
        MSG_SOUND_LIST_CUSTOM="  [Custom]"
        MSG_SOUND_LIST_NONE="  (None)"
        MSG_SOUND_LIST_ITEM_NONE="  - none      : Mute"
        MSG_SOUND_LIST_ITEM_DEFAULT="  - default   : Standard"
        MSG_SOUND_LIST_ITEM_BELL="  - bell      : Bell"
        MSG_SOUND_LIST_ITEM_COMPLETE="  - complete  : Task complete"
        MSG_SOUND_LIST_ITEM_SUCCESS="  - success   : Success"
        MSG_SOUND_LIST_ITEM_ALARM="  - alarm     : Alarm clock"
        MSG_SOUND_LIST_ITEM_CAMERA="  - camera    : Shutter"
        MSG_SOUND_LIST_ITEM_DEVICE="  - device    : Device"
        MSG_SOUND_LIST_ITEM_ATTENTION="  - attention : Attention"
        
        MSG_SOUND_PLAY_TAG_REQUIRED="Error: Please specify a tag."
        MSG_SOUND_PLAY_PLAYING="Playing [%s] : %s"
        MSG_SOUND_PLAY_MUTE="(Muted)"
        MSG_SOUND_PLAY_ERROR="Error: Cannot play file."
        MSG_SOUND_ADD_USAGE="Usage: eye sound add <tag> <path>"
        MSG_SOUND_ADD_ERROR_BUILTIN="Error: '%s' is built-in."
        MSG_SOUND_ADD_ERROR_FILE="Error: File not found: %s"
        MSG_SOUND_ADD_CONFIRM_REPLACE="Tag '%s' exists, replace? [y/N] "
        MSG_SOUND_ADD_ADDED="Added: %s"
        MSG_SOUND_RM_USAGE="Usage: eye sound rm <tag>"
        MSG_SOUND_RM_ERROR_BUILTIN="Error: Cannot remove built-in sound."
        MSG_SOUND_RM_DELETED="Deleted: %s"
        MSG_SOUND_RM_NOT_FOUND="Error: Tag not found: %s"
        MSG_SOUND_RM_NO_CUSTOM="No custom configuration."

        # Wizard Prompts
        MSG_WIZARD_INTERVAL="Interval (e.g. 20m, 1h)"
        MSG_WIZARD_DURATION="Duration (e.g. 20s; 0s for Pulse)"
        MSG_WIZARD_SOUND_ENABLE="Enable Sound?"
        MSG_WIZARD_SOUND_START="  Start Sound Tag (Enter for default: %s)"
        MSG_WIZARD_SOUND_END="  End Sound Tag (Enter for default: %s)"
        MSG_WIZARD_MSG_START="  Start Message"
        MSG_WIZARD_MSG_END="  End Message"
        MSG_WIZARD_COUNT="Loop Count (-1 for Infinite)"
        MSG_WIZARD_IS_TEMP="Is this a temporary task? (Delete after finish)"
        MSG_WIZARD_CONFIRM="Confirm creation?"
    fi
}