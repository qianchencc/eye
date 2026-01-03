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
        MSG_USAGE_CMD_START="  start [target]   启动任务 (更新 LAST_RUN 为当前时间)"
        MSG_USAGE_CMD_STOP="  stop [target]    停止/暂停任务 (不重置计时器)"
        MSG_USAGE_CMD_RESUME="  resume [target]  恢复运行 (根据暂停时长补齐时间)"
        MSG_USAGE_CMD_NOW="  now [task]       立即触发一次任务"
        MSG_USAGE_CMD_RESET="  reset [target]   重置任务 (需配合 --time/--count)"
        MSG_USAGE_CMD_TIME="  time <delta>     快进/快退计时 (如: +10m, -5s)"
        MSG_USAGE_CMD_COUNT="  count <delta>    修改计数 (如: +1, -1)"
        
        MSG_USAGE_MANAGE="任务管理:"
        MSG_USAGE_CMD_ADD="  add <name>       创建任务 (支持交互/参数)"
        MSG_USAGE_CMD_RM="  remove <id>      删除任务"
        MSG_USAGE_CMD_GROUP="  group <id> [grp] 修改任务分组"
        MSG_USAGE_CMD_EDIT="  edit <id>        修改任务"
        MSG_USAGE_CMD_LIST="  list             列出所有任务"
        MSG_USAGE_CMD_STATUS="  status           显示全状态看板 (支持排序)"
        
        MSG_USAGE_SUB="子系统:"
        MSG_USAGE_CMD_DAEMON="  daemon ...       守护进程管理 (启动/开机自启/设置)"
        MSG_USAGE_CMD_SOUND="  sound ...        音频管理"

        # Help Messages
        MSG_HELP_DAEMON_HEADER="用法: eye daemon <command>"
        MSG_HELP_DAEMON_CMDS="命令:
  up             启动守护进程
  down           停止守护进程
  uninstall      全量卸载 (不留痕迹)
  update         检查更新 (--apply 应用, --force 强制)
  enable         开启开机自启 (Systemd)
  disable        关闭开机自启
  default <task> 设置默认任务目标
  quiet <on|off> 静默模式
  language <zh|en> 语言设置
  root-cmd <cmd> 设置根指令行为
  help           显示此帮助"
        
        MSG_HELP_SOUND_HEADER="用法: eye sound <command>"
        MSG_HELP_SOUND_CMDS="命令:
  list           列出可用音效
  play <tag>     试听
  add <tag> <path> 添加自定义
  rm <tag>       删除自定义
  on [task]      全局开启 (或开启特定任务)
  off [task]     全局强制静音 (或关闭特定任务)
  help           显示此帮助"
        
        MSG_HELP_ADD_USAGE="用法: eye add <name> [options]

描述: 创建一个新的定期或脉冲任务。如果不带参数，将进入交互向导。

核心选项:
  -i, --interval <time>  触发间隔 (例如: 20m, 1h)
  -d, --duration <time>  休息时长 (例如: 20s; 0s 表示脉冲任务)
  -g, --group <name>     分组名 (默认: default)
  -c, --count <int>      循环次数 (-1 表示无限)
  --temp                 标记为临时任务 (计数结束后自动删除)

内容选项:
  --sound-start <tag>    开始时的音效标签
  --sound-end <tag>      结束时的音效标签 (仅限周期任务)
  --msg-start <text>     开始时的通知文案
  --msg-end <text>       结束时的通知文案

示例:
  eye add water -i 1h -g health
  eye add vision -i 20m -d 20s --sound-start bell
  eye add stretch --interval 30m --temp"
        
        MSG_HELP_EDIT_USAGE="用法: eye edit <id> [options]

描述: 修改现有任务的配置。如果不带参数，将进入交互式编辑。

选项:
  -i, --interval <time>  修改间隔
  -d, --duration <time>  修改时长
  -g, --group <name>     修改分组
  -c, --count <int>      修改目标计数
  --sound-on/off         开启/关闭任务音效
  --sound-start <tag>    修改开始音效
  --sound-end <tag>      修改结束音效
  --msg-start <text>     修改开始文案
  --msg-end <text>       修改结束文案

示例:
  eye edit water -i 45m
  eye edit vision --sound-start alarm"

        MSG_HELP_STATUS_USAGE="用法: eye status [id] [options]

描述: 显示所有任务的当前状态或单个任务的详细信息。

选项:
  -l, --long             显示带有边框的详细横向表格
  -s, --sort <field>     排序字段: name, created, next, group (默认: next)
  -r, --reverse          倒序排列

示例:
  eye status -l
  eye status water
  eye status --sort name -r"

        MSG_HELP_STOP_USAGE="用法: eye stop [target] [time]

描述: 暂停任务的调度。与 start 不同，stop 不会重置 LAST_RUN，因此恢复后任务会继续之前的进度。

参数:
  target                 任务 ID, @组名, 或 --all (默认: @eye_rest)
  time                   可选，暂停特定时长 (例如: 30m, 1h)。到期后自动恢复。

示例:
  eye stop water         无限期暂停 water 任务
  eye stop @work 1h      将 work 组暂停 1 小时
  eye stop --all         暂停所有任务"

        MSG_HELP_GROUP_USAGE="用法: eye group <task_id> [group_name]

描述: 修改指定任务的分组属性。

参数:
  task_id                任务 ID (必填)
  group_name             新的组名 (可选)。若省略或设为 'none'/'default'，则将该任务移出当前组。

示例:
  eye group water health      将 'water' 任务移动到 'health' 组
  eye group vision none        将 'vision' 任务移出当前组"

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
        MSG_NOTIFY_BODY_START='请远眺 {DURATION}！'
        MSG_NOTIFY_TITLE_END="休息结束"
        MSG_NOTIFY_BODY_END="眼睛休息完毕，继续工作吧。"
        MSG_ERROR_INVALID_TIME_FORMAT="错误: 时间格式无效"
        MSG_ERROR_INFINITE_COUNT="错误: 任务 '%s' 是无限循环任务，无法修改计数。"
        
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
        MSG_USAGE_CMD_START="  start [target]   Start task (Update LAST_RUN to now)"
        MSG_USAGE_CMD_STOP="  stop [target]    Stop/Pause task (Keep timer state)"
        MSG_USAGE_CMD_RESUME="  resume [target]  Resume task (Compensate pause time)"
        MSG_USAGE_CMD_NOW="  now [task]       Trigger task immediately"
        MSG_USAGE_CMD_RESET="  reset [target]   Reset task metrics (needs --time/--count)"
        MSG_USAGE_CMD_TIME="  time <delta>     Shift time (e.g., +10m, -5s)"
        MSG_USAGE_CMD_COUNT="  count <delta>    Shift count (e.g., +1, -1)"
        
        MSG_USAGE_MANAGE="Task Management:"
        MSG_USAGE_CMD_ADD="  add <name>       Create task (interactive/flags)"
        MSG_USAGE_CMD_RM="  remove <id>      Delete task"
        MSG_USAGE_CMD_GROUP="  group <id> [grp] Modify task group"
        MSG_USAGE_CMD_EDIT="  edit <id>        Edit task"
        MSG_USAGE_CMD_LIST="  list             List all tasks"
        MSG_USAGE_CMD_STATUS="  status           Show status dashboard (sortable)"
        
        MSG_USAGE_SUB="Subsystems:"
        MSG_USAGE_CMD_DAEMON="  daemon ...       Daemon management (up/enable/config)"
        MSG_USAGE_CMD_SOUND="  sound ...        Audio management"

        # Help Messages
        MSG_HELP_DAEMON_HEADER="Usage: eye daemon <command>"
        MSG_HELP_DAEMON_CMDS="Commands:
  up             Start daemon
  down           Stop daemon
  uninstall      Full uninstallation (no traces)
  update         Check update (--apply to apply, --force to force)
  enable         Enable autostart (Systemd)
  disable        Disable autostart
  default <task> Set default task target
  quiet <on|off> Quiet mode
  language <zh|en> Set language
  root-cmd <cmd> Set root command action
  help           Show this help"
        
        MSG_HELP_SOUND_HEADER="Usage: eye sound <command>"
        MSG_HELP_SOUND_CMDS="Commands:
  list           List sounds
  play <tag>     Preview
  add <tag> <file> Add custom sound
  rm <tag>       Remove custom sound
  on [task]      Global ON (or enable task)
  off [task]     Global Force Mute (or disable task)
  help           Show this help"
        
        MSG_HELP_ADD_USAGE="Usage: eye add <name> [options]

Description: Create a new periodic or pulse task. Enters wizard mode if no options provided.

Core Options:
  -i, --interval <time>  Trigger interval (e.g. 20m, 1h)
  -d, --duration <time>  Break duration (e.g. 20s; 0s for Pulse)
  -g, --group <name>     Group name (default: default)
  -c, --count <int>      Loop count (-1 for infinite)
  --temp                 Delete task after completion

Content Options:
  --sound-start <tag>    Sound to play at start
  --sound-end <tag>      Sound to play at end (periodic only)
  --msg-start <text>     Notification text at start
  --msg-end <text>       Notification text at end

Examples:
  eye add water -i 1h -g health
  eye add vision -i 20m -d 20s --sound-start bell
  eye add stretch --interval 30m --temp"
        
        MSG_HELP_EDIT_USAGE="Usage: eye edit <id> [options]

Description: Modify an existing task configuration. Enters interactive mode if no options provided.

Options:
  -i, --interval <time>  Modify interval
  -d, --duration <time>  Modify duration
  -g, --group <name>     Modify group
  -c, --count <int>      Modify target count
  --sound-on/off         Enable/Disable sound for this task
  --sound-start <tag>    Modify start sound
  --sound-end <tag>      Modify end sound
  --msg-start <text>     Modify start message
  --msg-end <text>       Modify end message

Examples:
  eye edit water -i 45m
  eye edit vision --sound-start alarm"

        MSG_HELP_STATUS_USAGE="Usage: eye status [id] [options]

Description: Show current status of all tasks or detailed info of a single task.

Options:
  -l, --long             Show detailed horizontal boxed table
  -s, --sort <field>     Sort by: name, created, next, group (default: next)
  -r, --reverse          Sort in descending order

Examples:
  eye status -l
  eye status water
  eye status --sort name -r"

        MSG_HELP_STOP_USAGE="Usage: eye stop [target] [time]

Description: Pause task scheduling. Unlike start, stop does not reset LAST_RUN, so the task continues its progress after resuming.

Arguments:
  target                 Task ID, @group, or --all (default: @eye_rest)
  time                   Optional, pause for a specific duration (e.g. 30m, 1h).

Examples:
  eye stop water         Pause water task indefinitely
  eye stop @work 1h      Pause work group for 1 hour
  eye stop --all         Pause all tasks"

        MSG_HELP_GROUP_USAGE="Usage: eye group <task_id> [group_name]

Description: Modify the group attribute of a specific task.

Arguments:
  task_id                Task ID (Required)
  group_name             New group name (Optional). If omitted or set to 'none'/'default', the task is moved out of its current group.

Examples:
  eye group water health      Move 'water' task to 'health' group
  eye group vision none        Remove 'vision' task from its current group"

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
        MSG_NOTIFY_BODY_START='Look away for {DURATION}!'
        MSG_NOTIFY_TITLE_END="Break Ended"
        MSG_NOTIFY_BODY_END="Eyes rested. Keep going!"
        MSG_ERROR_INVALID_TIME_FORMAT="Error: Invalid time format"
        MSG_ERROR_INFINITE_COUNT="Error: Task '%s' is an infinite loop task, cannot modify count."
        
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
