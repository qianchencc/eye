## 1. 核心指令集 (Core Commands)

**前缀**: `eye`
**描述**: 管理任务生命周期、时间与状态。

### 1.1 任务控制 (Control)

用于改变任务的运行状态。

* **`start [target]`**
* **Usage**: `eye start`, `eye start task1`, `eye start @work`
* **描述**:
    * 无参数：启动 Daemon（如果未运行）。
    * 有参数：将目标任务状态设为 `running`，并更新 `EYE_T_LAST_RUN` 为当前时间。
    * **提示**: `@组名` 支持正则表达式 (如 `@work_.*`)。


* **`stop [target] [time]`**
* **Usage**: `eye stop task1`, `eye stop @work 1h`
* **描述**: 暂停目标任务。
    * 无 `[time]`: 无期限暂停。
    * 有 `[time]`: 暂停指定时长（如 `30m`, `1h`）。
    * **特性**: 任务进入 `paused` 状态。暂停期间 `NEXT` 触发时间保持静止。
    * **提示**: `@组名` 支持正则表达式。


* **`resume [target]`**
* **Usage**: `eye resume`, `eye resume @work`
* **描述**: 恢复运行，根据暂停时长自动补偿 `EYE_T_LAST_RUN` 时间戳，使任务从暂停点继续。
    * **提示**: `@组名` 支持正则表达式。



### 1.2 状态查询 (Status)

**别名**: `list`
**改进**: 增加了强大的排序和过滤参数，优化了对齐逻辑与详细视图。

* **`status [target] [options]`**
* **Usage**: `eye status`, `eye list`, `eye status -l`, `eye status eye_rest`
* **描述**: 显示守护进程状态及任务列表。支持通过 `eye status help` 查看详细用法。
* **视图模式**:
    * **默认 (Compact)**: `Status  ID  Timing  Count  NEXT  Group` (完美对齐)。
    * **详细 (--long, -l)**: 带有 ASCII 边框的横向表格。
    * **单任务详情 (<task_id>)**: 纵向对齐的键值对看板，展示所有元数据及配置。
* **参数**:
    * `--long, -l`: 显示横向详细表格。
    * `--sort, -s <field>`: 排序依据: `name`, `created`, `next`, `group`。
    * `--reverse, -r`: 倒序排列。


### 1.3 任务增删改 (CRUD)

* **`add <name> [options]`**
* **Usage**: `eye add water -i 1h --sound-start bell`
* **描述**: 创建新任务。支持交互式向导或参数模式。

* **`edit <target> [options]`**
* **Usage**: `eye edit water -i 45m`
* **描述**: 修改任务配置。支持交互式编辑。

* **`in <time> <message>`**
* **Usage**: `eye in 30m "Take a nap"`
* **描述**: 快速创建一次性临时任务。

* **`rm <target>`**
* **Usage**: `eye rm water`
* **描述**: 物理删除任务文件。


* **`group <target> [new_group]`**
* **Usage**: `eye group task1 health`
* **描述**: 修改任务的分组。若 `new_group` 为空或为 `none`，则将任务归类到 `default` 组（即移除特定组属性）。
* **动态组生命周期**: 
    * **自动创建**: 当任务被分配到一个尚未存在的组名时，该组自动创建。
    * **自动销毁**: 当一个组内不再有任何任务时，该组自动销毁。
* **参数**:
    * `target`: 任务 ID (必填)。
    * `new_group`: 新的组名 (可选)。


### 1.4 状态操纵 (Manipulation)

* **`time <delta> [target]`**
* **Usage**: `eye time +10m @work`, `eye time -5m water`
* **描述**: 修改任务的 `EYE_T_LAST_RUN` 时间戳以快进或延后。


* **`count <delta> [target]`**
* **Usage**: `eye count -1 water`
* **描述**: 修改任务的 `EYE_T_REMAIN_COUNT`。


* **`reset [target] [options]`**
* **Usage**: `eye reset @work --time --count`
* **描述**: 重置任务的计时器或计数器。

---

## 2. 音频指令集 (Sound Commands)

* **`eye sound list`**: 列出所有可用音效 Tag。
* **`eye sound play <tag>`**: 试听音效。
* **`eye sound add <tag> <path>`**: 注册自定义音效。
* **`eye sound on/off [target]`**: 开启/关闭音效。

---

## 3. 守护进程与配置 (Daemon & Config)

* **`eye daemon up/down`**: 启动/停止服务。
* **`eye daemon uninstall`**: **[新]** 全量卸载。停止服务并删除所有二进制、库文件、配置文件及状态数据。
* **`eye daemon update [--apply] [--force]`**: **[新]** 检查更新。对比远程仓库 `main` 分支的版本号。使用 `--apply` 自动升级，使用 `--force` 强制覆盖更新。
* **`eye daemon quiet <on/off>`**: 静默模式。
* **`eye daemon language <zh/en>`**: 切换语言。
* **`eye daemon default <id>`**: 设置默认任务目标。

### 3.1 高级 Provider 配置 (New)

通过手动编辑 `~/.config/eye/eye.conf` 或使用 `eye daemon` 命令（如支持）配置：

* **`NOTIFY_BACKEND`**:
    * `desktop`: 桌面通知 (notify-send)。
    * `wall`: 系统广播 (wall)。
    * `tmux`: Tmux 状态栏消息。
    * `auto`: 自动探测（默认）。
* **`SOUND_BACKEND`**:
    * `paplay`: PulseAudio (默认)。
    * `mpv`: 使用 mpv 播放。
    * `aplay`: ALSA 播放。
    * `auto`: 自动探测。

---

## 4. 架构特性

* **事件驱动**: 守护进程优先使用 `inotifywait` 监听任务目录，实现配置秒级生效及零闲置 CPU 占用。
* **Provider 抽象**: 通知与音频输出已完全解耦，适配桌面、服务器、容器等多种运行环境。
* **命名空间隔离**: 所有内部变量使用 `EYE_T_` 前缀，确保 `source` 加载时的安全性。
