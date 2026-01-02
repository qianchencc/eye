# Refactoring Plan: Eye -> General Purpose Task Manager

---
本计划旨在将 `eye` 重构为通用的、符合 Unix 哲学的桌面级周期性任务管理器。

---

## 1. 核心架构设计 (Architecture)

### 1.1 存储模型：一切皆文件

不再使用单一的 `config` 文件，而是采用 **Spool（任务池）** 模式。

* **全局配置**：`~/.config/eye/eye.conf` (存储全局开关、默认行为)。
* **任务池路径**：`~/.config/eye/tasks/`。
* **任务文件格式**：每个任务一个独立文件，文件名为 `TaskID`（如 `default`, `water`, `meditation`）。内容为纯文本 `KEY=VALUE` 结构，支持 Shell 脚本直接 source。

### 1.2 任务定义 (Schema)

所有逻辑基于以下字段的组合：

| 字段 | 类型 | 说明 | 逻辑行为 |
| --- | --- | --- | --- |
| `NAME` | String | 任务名称 | 仅用于显示 (list/status)。 |
| `GROUP` | String | 组标签 | 用于 ` @group` 批量管理。默认 `default`。 |
| `INTERVAL` | Duration | 触发间隔 | 如 `20m`, `1h`。必须 > 0。 |
| `DURATION` | Duration | 持续时间 | **核心区分点**。


`0` = **脉冲任务** (只有开始通知，不阻塞，无结束通知)。


`>0` = **周期任务** (有开始/结束通知，需获取锁，状态变为 `rest`)。 |
| `TARGET_COUNT` | Int | 目标计数 | `[新增]` `-1` = 无限循环。


`>0` = 执行 N 次后触发结束逻辑。 |
| `REMAIN_COUNT` | Int | 剩余计数 | `[新增]` 运行时递减。`<=0` 时触发销毁或停止。 |
| `IS_TEMP` | Bool | 是否临时 | `[新增]` `true` = 计数归零后**删除文件**。


`false` = 计数归零后**修改状态为 Disabled**。 |
| `SOUND_ENABLE` | Bool | 独立音效开关 | `[新增]` 默认为 `true`，可被 `eye sound off task_id` 单独关闭。 |
| `SOUND_START` | String | 开始音效 | 支持内置 Tag 或自定义路径。 |
| `SOUND_END` | String | 结束音效 | 仅当 `DURATION > 0` 时有效。 |
| `MSG_START` | String | 开始文案 | 支持变量替换 `${DURATION}`, `${REMAIN_COUNT}`。 |
| `MSG_END` | String | 结束文案 | 仅当 `DURATION > 0` 时有效。 |
| `LAST_RUN` | Timestamp | 上次运行时间 | 用于计算间隔。 |
| `STATUS` | String | 状态 | `running`, `paused`, `stopped`。 |

### 1.3 核心守护进程逻辑 (Daemon)

守护进程由“只读轮询”变为“读写执行”。

1. **加载阶段**：遍历 `tasks/` 目录，source 所有文件。读取 `eye.conf` 全局配置。
2. **检查阶段**：计算 `current_time - LAST_RUN >= INTERVAL`。
3. **触发阶段 (Trigger)**：
* **脉冲任务 (Duration=0)**：
* 直接触发 `MSG_START` 和 `SOUND_START`。
* 原子更新 `LAST_RUN` 和 `REMAIN_COUNT`。


* **周期任务 (Duration>0)**：
* **获取锁**：尝试创建文件锁 `/tmp/eye_focus.lock`。
* *成功*：触发 `MSG_START` + `SOUND_START`，进入阻塞/Sleep `DURATION`，结束后触发 `MSG_END` + `SOUND_END`，释放锁。
* *失败*：检测锁是否来自**同组任务**。若是，则推迟执行（避免打架）；若否（异组），则视策略排队或忽略。
* 原子更新 `LAST_RUN` 和 `REMAIN_COUNT`。




4. **生命周期管理 `[新增]`**：
* 每次执行完，检查 `REMAIN_COUNT`。
* 若 `<= 0` 且 `TARGET_COUNT != -1`：
* `IS_TEMP=true` -> 调用 `rm` 删除任务文件。
* `IS_TEMP=false` -> 原子写入 `STATUS=stopped`。




---

## 2. 输出流设计 (Output Stream Logic) `[新增]`

不再使用 Unix/Normal 双模式配置，改为基于流（Stream）的自适应单模式。

* **原则**：
* **Stdout (标准输出)**：仅输出**数据**（下游程序需要的 ID、状态值、JSON/Key-Value）。
* **Stderr (标准错误)**：输出**交互信息**（Log、提示、Emoji、报错）。


* **自适应装饰**：
* 检测 `if [ -t 2 ]` (Stderr 是否为 TTY)：若是，输出带颜色和 Emoji 的富文本；若否，输出纯文本日志。


* **全局静默配置**：
* 通过 `eye daemon quiet on` 设置。开启后，Stderr 将被重定向至 `/dev/null`，仅保留Stdout 数据流。



---

## 3. 指令集详解 (Command Reference)

原则：**原子操作**。所有写操作必须遵循 `write to temp -> mv temp target` 流程。

### 3.1 根指令

* `eye` (不带参数)
* **行为**：读取 `eye.conf` 中的 `DEFAULT_CMD`。
* **默认**：执行 `eye help`。
* **配置**：用户可通过 `eye daemon root-cmd status` 修改为显示状态。



### 3.2 任务管理 (CRUD)

* `eye add <task_name> [options]`
* **功能**：创建新任务。
* **参数**：
* `--interval, -i`: 间隔 (必填)。
* `--duration, -d`: 持续时间 (默认 0)。
* `--group, -g`: 组名 (默认 default)。
* `--count, -c`: 次数 (默认 -1)。
* `--temp`: 标记为临时任务。
* `--sound-start/end`: 指定音效 Tag。
* `--msg-start/end`: 指定通知文案。


* **交互模式**：不带参数时，进入问答式引导。
* **输出**：Stdout 输出新 Task ID，Stderr 输出 "✅ Task created..."。


* `eye in <time> <message>` `[新增]`
* **功能**：快捷临时任务（类似 `at`）。
* **实现**：自动生成 `IS_TEMP=true`, `COUNT=1`, `INTERVAL=<time>`, `DURATION=0` 的任务文件。


* `eye edit <task_id>`
* **功能**：修改任务。
* **实现**：检测 `$EDITOR` 环境变量，自动打开对应文件供用户编辑。若无编辑器变量，回退到简单的交互式修改。


* `eye remove <task_id>`
* **功能**：物理删除任务文件。


* `eye list`
* **功能**：列出所有任务详情。
* **输出**：表格形式，包含 ID, Group, Next Run, Count 等。



### 3.3 组与控制 (Control & Grouping)

支持 `<task_id>` 或 ` @<group_name>` 选择器。

* `eye group [task_ids...] <target_group>`
* **功能**：将指定任务移动到某组。若 `target_group` 为空，清除组属性。


* `eye start [task_id | @group]`
* **功能**：
* 若指定 ID/Group：将 `STATUS` 设为 `running`，重置 `LAST_RUN` 为当前时间。
* 若不指定：启动守护进程（兼容旧版）。



* `eye stop [task_id | @group]`
* **功能**：将 `STATUS` 设为 `stopped`。


* `eye pause [task_id | @group]`
* **功能**：设置 `STATUS=paused`，记录暂停时间戳。
* **默认**：不带参数默认为 `pause @default`。
* **全局**：`pause --all`。


* `eye resume [task_id | @group]`
* **功能**：恢复运行，补齐暂停时长。


* `eye now [task_id]`
* **功能**：忽略时间检查，立即触发一次任务逻辑。
* **参数**：`--reset` (触发后重置计时器)。



### 3.4 状态与操作 (Status & Manipulation)

* `eye status`
* **功能**：显示当前守护进程状态 + 任务概览。
* **改进**：支持按组排序、按时间排序。
* **输出流逻辑**：
* `[ ! -t 1 ]` (管道模式)：输出 `status=running
task_count=3...`
* `[ -t 1 ]` (TTY模式)：输出美化的状态看板。



* `eye time <time_delta> [task_id | @group]`
* **功能**：快进/快退计时。
* **示例**：`eye time +10m @work` (让工作组的任务快进10分钟)。
* **示例**：`eye time -10m` (倒流，推迟触发)。


* `eye count <count_delta> [task_id | @group]` `[新增]`
* **功能**：修改剩余计数。
* **示例**：`eye count +1` (增加一次机会)。


* `eye reset [task_id | @group]`
* **功能**：重置计时（`LAST_RUN=now`）和计数（`REMAIN=TARGET`）。



### 3.5 音频管理 (Sound)

* `eye sound list/play/add/rm`：保持不变。
* `eye sound on/off [task_id]`
* **功能**：
* 不带参数：**全局开关** (写入 `eye.conf`)，优先级最高。
* 带参数：修改特定任务的 `SOUND_ENABLE` 字段 `[新增]`。




### 3.6 守护进程配置 (Daemon Configuration) `[修改]`

原 `config` 指令重命名为 `daemon`，专注于服务管理与全局设置。

* `eye daemon up`：启动后台服务。
* `eye daemon down`：关闭后台服务。
* `eye daemon reload`：强制重载配置。
* `eye daemon enable`：设置开机自启 (Systemd)。
* `eye daemon disable`：取消开机自启。
* `eye daemon root-cmd <help|status>` `[新增]`：
* 设置 `eye` 裸指令的行为，默认 `help`。写入 `eye.conf`。


* `eye daemon quiet <on|off>` `[新增]`：
* 设置是否将 Stderr 重定向至 `/dev/null`。满足纯静默需求。写入 `eye.conf`。



---

## 4. 技术实现细节 (Technical Specs)

### 4.1 原子写入 (Atomic Write)

为了防止并发读写导致文件损坏，必须实现 `_atomic_write` 函数：

```bash
_atomic_write() {
    local target_file=$1
    local content=$2
    local tmp_file=$(mktemp) 
    
    echo "$content" > "$tmp_file"
    # 强制同步并移动，覆盖原文件
    fsync "$tmp_file" 2>/dev/null
    mv -f "$tmp_file" "$target_file"

}

```

### 4.2 变量替换 (Variable Substitution)

在 `daemon.sh` 触发通知前，执行变量解析：

```bash
# 假设 $msg 是从配置文件读取的原始字符串 "Rest for ${DURATION}!"
formatted_msg=$(echo "$msg" | sed "s/">${DURATION}/$curr_dur/g; s/">${REMAIN_COUNT}/$curr_count/g")
notify-send "$formatted_msg"

```

### 4.3 锁机制 (Locking)

* **文件**：`/tmp/eye_focus.lock` (内容为持有锁的 `TaskID`)。
* **获取锁**：`set -C; echo "$TASK_ID" > /tmp/eye_focus.lock` (利用 `noclobber` 特性实现原子锁)。
* **策略**：
* 若当前任务是 Pulse (Duration=0)，**不检查锁**，直接运行。
* 若当前任务是 Periodic (Duration>0)，必须获取锁才能进入 `rest` 阶段。



### 4.4 历史记录 (History Log)

由于临时任务会被删除，需要保留记录。

* **文件**：`~/.local/state/eye/history.log`
* **内容**：`[TIMESTAMP] [TASK_ID] [EVENT] (Triggered/Completed/Deleted)`

---

## 5. 迁移策略 (Migration)

1. **检测**：安装脚本检测是否存在旧版 `~/.config/eye/config`。
2. **转换**：将旧版配置读取，转换为新版格式 `~/.config/eye/tasks/default`。
* `REST_GAP` -> `INTERVAL`
* `LOOK_AWAY` -> `DURATION`
* `SOUND_START` -> `SOUND_START`
* `SOUND_END` -> `SOUND_END`


3. **兼容**：首次运行时，自动生成 `eye.conf` 并应用默认值。

---
