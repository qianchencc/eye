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
* **状态逻辑**: **新任务默认为 `stopped` 状态**。
* **Daemon 关联**: 若 Daemon 未运行，执行此命令会弹出警告。

* **`start [target]`**
* **Usage**: `eye start task1`, `eye start @work`
* **描述**:
    * 将目标任务状态设为 `running`。
    * **强制校验**: **此命令要求 Daemon 必须处于 Active 状态**。若 Daemon 未启动，命令会报错并拒绝执行。
    * **对齐逻辑**: 启动时会自动将 `EYE_T_LAST_RUN` 对齐到当前时间。

* **`stop [target] [time]`** (别名: `pause`)
* **Usage**: `eye stop task1`, `eye stop @work 1h`
* **描述**: 暂停目标任务。
    * **立即物理停止**: 除了修改状态文件，还会立即向正在运行的任务子进程发送 `SIGTERM` 信号，确保通知/音频立即停止。
    * 无 `[time]`: 无期限暂停。
    * 有 `[time]`: 暂停指定时长（如 `30m`, `1h`）。到期后 Daemon 自动恢复。
    * **特性**: 任务进入 `paused` 状态。暂停期间 `NEXT` 触发时间保持静止。
