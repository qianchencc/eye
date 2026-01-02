## 1. 核心指令集 (Core Commands)

**前缀**: `eye`
**描述**: 管理任务生命周期、时间与状态。

### 1.1 任务控制 (Control)

用于改变任务的运行状态。

* **`start [target]`**
* **Usage**: `eye start`, `eye start task1`, `eye start @work`
* **描述**:
    * 无参数：启动 Daemon（如果未运行）。
    * 有参数：将目标任务状态设为 `running`，并更新 `LAST_RUN` 为当前时间。


* **`stop [target]`**
* **Usage**: `eye stop task1`, `eye stop @work`
* **描述**: 将目标任务状态设为 `stopped`。


* **`pause [target]`**
* **Usage**: `eye pause`, `eye pause @all`
* **描述**: 将任务设为 `paused` 并记录暂停时间戳。
* **参数**: `--all` (暂停所有正在运行的任务)。


* **`resume [target]`**
* **Usage**: `eye resume`, `eye resume @work`
* **描述**: 恢复运行，根据暂停时长自动补齐下次触发时间。



### 1.2 状态查询 (Status)

**别名**: `list`
**改进**: 增加了强大的排序和过滤参数。

* **`status [target] [options]`**
* **Usage**: `eye status`, `eye list`, `eye status @work --sort name -r`
* **描述**: 显示守护进程状态及任务列表。
* **参数**:
    * `--sort, -s <field>`: 排序依据。支持 `name` (名称), `created` (创建时间), `next` (下次触发时间), `group` (组名)。默认为 `next`。
    * `--reverse, -r`: 倒序排列 (Descending)。
    * `--long, -l`: 显示详细信息（包含 ID, Path 等）。
    * `--json`: 输出 JSON 格式（用于脚本集成）。


### 1.3 任务增删改 (CRUD)

**改进**: 增强了 `add` 的交互性与脚本化支持，支持一步配置所有任务属性。

* **`add <name> [options]`**
* **Usage**: `eye add water -i 1h --sound-start bell`, `eye add task1 --help`
* **描述**: 创建新任务。
* **核心参数**:
    * `--interval, -i <time>`: 间隔 (如 `20m`, `1h`)。[必填] (除非进入交互模式)。
    * `--duration, -d <time>`: 持续时间 (默认 `0`)。
    * `--group, -g <name>`: 组名 (默认 `default`)。
    * `--count, -c <int>`: 计数限制 (默认 `-1` 无限)。
    * `--temp`: 标记为临时任务 (计数归零后删除)。
* **内容参数 (新增)**:
    * `--sound-start <tag/path>`: 设置开始音效.
    * `--sound-end <tag/path>`: 设置结束音效 (仅当 `duration>0` 时有效)。
    * `--msg-start "text"`: 设置开始通知文案 (支持变量 `${DURATION}`).
    * `--msg-end "text"`: 设置结束通知文案。
* **特殊行为**:
    * `--help`: 显示该命令的详细参数说明及示例，而不进行创建操作。
    * `--edit, -e`: **[Unix特性]** 创建后立即调用 `$EDITOR` 打开文件进行微调.
    * *(无参数): 进入交互式问答向导 (Wizard Mode)。*


* **`in <time> <message>`**
* **Usage**: `eye in 30m "Take a nap"`
* **描述**: 快速创建一次性临时任务 (Shortcut for `add --temp ...`)。


* **`edit <target>`**
* **Usage**: `eye edit water`
* **描述**: 修改任务。自动调用 `$EDITOR` 编辑对应的任务文件。


* **`rm <target>`**
* **Usage**: `eye rm water`, `eye rm @temp_group`
* **描述**: 物理删除任务文件。


### 1.4 状态操纵 (Manipulation)

用于手动干预计时器和计数器。

* **`time <delta> [target]`**
* **Usage**: `eye time +10m @work`, `eye time -5m water`
* **描述**: 修改任务的 `LAST_RUN` 时间戳。
* **参数**:
    * `<delta>`: 时间增量，必须带符号 (如 `+10m`, `-1h`)。
    * `[target]`: 默认为默认任务。


* **`count <delta> [target]`**
* **Usage**: `eye count -1 water`
* **描述**: 修改任务的 `REMAIN_COUNT`。
* **逻辑**:
    * 若任务是无限循环 (`TARGET_COUNT = -1`)，此命令仅返回警告但不生效。
    * 若修改导致 `REMAIN_COUNT <= 0`，自动触发任务结束逻辑 (Stop or Delete)。


* **`reset [target] [options]`**
* **Usage**: `eye reset @work --timer`
* **描述**: 重置任务状态。直接运行 `reset` 会显示帮助。
* **参数**:
    * `--timer, -t`: 重置计时器 (`LAST_RUN = now`)。
    * `--counter, -c`: 重置计数器 (`REMAIN = TARGET`)。
    * `--all，-a`: 重置计时器和计数器。


### 1.5 组管理 (Group)

* **`group <target> <new_group>`**
* **Usage**: `eye group task1 @office`
* **描述**: 将任务移动到新组。若 `<new_group>` 为 `none` 或 `default`，则移出当前组。


### 1.6 其他

* **`help`**: 显示帮助。
* **`version`**: 显示版本。

---

## 2. 音频指令集 (Sound Commands)

**前缀**: `eye sound`
**描述**: 管理音效资源及播放策略。

* **`list`**: 列出所有可用音效 Tag 及路径。
* **`play <tag>`**: 试听音效。
* **`add <tag> <path>`**: 注册自定义音效。
* **`rm <tag>`**: 移除自定义音效。
* **`on [target]`**
* **Usage**: `eye sound on`, `eye sound on water`
* **描述**:
    * 无参数：**全局解除静音**。恢复对各个任务音频配置的尊重。
    * 有参数：开启指定任务/组的 `SOUND_ENABLE` 开关。


* **`off [target]`**
* **Usage**: `eye sound off`, `eye sound off @meeting`
* **描述**:
    * 无参数：**全局静音 (Master Mute)**。覆盖所有任务设置，强制静音。
    * 有参数：关闭指定任务/组的 `SOUND_ENABLE` 开关。



---

## 3. 守护进程与配置 (Daemon & Config)

**前缀**: `eye daemon`
**描述**: 管理后台服务、持久化及全局偏好。所有 set 类命令都会写入 `eye.conf`。

### 3.1 服务管理

* **`up`**: 启动守护进程。**注意**：安装后默认不启动，用户必须手动执行 `eye daemon up` 才能开启任务调度。
* **`down`**: 停止守护进程。
* **`reload`**: 强制重载所有配置文件。
* **`enable`**: 注册并开启开机自启 (Systemd)。
* **`disable`**: 取消开机自启。

### 3.2 全局偏好设置 (Preferences)

* **`quiet <on|off>`**
* **描述**: 开启后，将 Standard Error (Stderr) 重定向至 `/dev/null`。
* **作用**: 实现绝对的静默运行（适合 Crontab 或极简主义者）。


* **`root-cmd <help|status>`**
* **描述**: 设置当用户仅输入 `eye` 时的默认行为。


* **`default <task_id>`**
* **描述**: 设置默认操作的任务 ID (用于 `pause` 等不带参数时的行为)。


* **`language <zh|en>`**
* **描述**: 设置 CLI 交互语言。



---

## 设计补充说明

1. **参数位置的灵活性**：
在实现参数解析（`getopts` 或手动解析）时，建议支持参数位置的灵活性。
例如 `eye status @work --sort name` 和 `eye status --sort name @work` 应当等效。
2. **默认行为的智能回退**：
对于 `stop`, `pause`, `resume` 等命令，如果用户未指定 `target`：
    1. 检查 `eye.conf` 中的 `DEFAULT_TASK`。
    2. 如果未设置，则默认操作名为 `default` 的组或任务。
    3. 如果都不存在，报错并提示用户指定。


3. **排序实现提示**：
在 Bash 中实现 `status` 的排序，可以将所有任务数据读入数组，格式化为 `timestamp|name|group|...` 的行，然后通过 `sort` 命令管道处理：
```bash
# 伪代码示例：按时间倒序
... | sort -t'|' -k1 -rn
```

此外，除了根指令，所有二级指令都要有自己的完整help.
