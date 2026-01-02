# Eye v2.0 重构路线图 (Implementation Roadmap)

---

### 第一阶段：基础设施与数据层 (Infrastructure & Data Layer)

**目标**：建立可靠的文件读写机制，确保“原子操作”和“任务模型”的正确性。此阶段不涉及守护进程逻辑。

1. **目录结构初始化**
* [ ] 修改 `lib/constants.sh`：
* 定义 `TASKS_DIR="$CONFIG_DIR/tasks"`。
* 定义 `GLOBAL_CONF="$CONFIG_DIR/eye.conf"`。
* 定义 `HISTORY_LOG="$STATE_DIR/history.log"`。


* [ ] 编写初始化脚本：确保上述目录在运行时存在。


2. **原子 IO 库 (`lib/io.sh` - 新增)**
* [ ] 实现 `_atomic_write <file> <content>`：使用 `mktemp` + `fsync` + `mv` 策略。
* [ ] 实现 `_load_task <task_id>`：读取文件并 export 变量（做简单的字段校验，缺失字段赋予默认值）。
* [ ] 实现 `_save_task <task_id> <key=value...>`：将内存变量组装并写入文件。


3. **输出流控制库 (`lib/utils.sh` - 重构)**
* [ ] 移除所有关于 `EYE_MODE` (Unix/Normal) 的判断逻辑。
* [ ] 重写 `msg_info` / `msg_warn` / `msg_error`：
* 增加检查 `GLOBAL_QUIET` 开关。
* 增加检查 `if [ -t 2 ]`，决定是否输出颜色/Emoji 到 Stderr。


* [ ] 重写 `msg_data`：无条件输出到 Stdout。



**✅ 阶段验收标准**：
编写一个测试脚本，能够并发调用 `_atomic_write` 100次而不损坏文件；能够正确读取一个包含缺省字段的任务文件。

---

### 第二阶段：守护进程核心 (The Engine)

**目标**：重写 `daemon.sh`，使其成为一个支持多任务、锁机制和生命周期管理的调度器。

4. **全局配置加载**
* [ ] 在 `lib/config.sh` 中实现 `_load_global_config`，仅读取 `eye.conf`。


5. **核心循环重构 (`lib/daemon.sh`)**
* [ ] **任务扫描**：在 `while true` 循环中，使用 `for file in "$TASKS_DIR"/*` 遍历。
* [ ] **触发逻辑**：
* 实现 `_check_trigger <task_id>` 函数。
* 计算 `now - LAST_RUN >= INTERVAL`。


* [ ] **锁机制 (`_try_lock`)**：
* 针对 `DURATION > 0` 的任务，实现基于 `/tmp/eye_focus.lock` 的抢占逻辑。
* 实现同组推迟策略（Same Group Delay）。


* [ ] **执行逻辑 (`_execute_task`)**：
* 变量替换：解析 `${DURATION}`, `${REMAIN_COUNT}`。
* 脉冲任务：Notify -> Update Data。
* 周期任务：Notify -> Sleep (Duration) -> Notify End -> Update Data。


* [ ] **生命周期钩子**：
* 实现计数器递减。
* 实现 `REMAIN_COUNT <= 0` 时的分支逻辑（删除文件 或 修改状态）。




6. **历史记录**
* [ ] 实现 `_log_history <task_id> <event>`，追加写入 `history.log`。



**✅ 阶段验收标准**：
手动创建两个任务文件（一个脉冲，一个周期），启动 `bin/eye daemon`（前台运行），观察是否按预期触发，且无文件冲突。

---

### 第三阶段：CLI 交互层 (Interface & CLI)

**目标**：重构 `bin/eye` 和 `lib/cli.sh`，提供符合新设计的人机交互。

7. **入口分发 (`bin/eye`)**
* [ ] 读取 `eye.conf` 获取 `DEFAULT_CMD` (默认 `help`)。
* [ ] 根指令不带参数时，分发到默认指令。
* [ ] 增加 `daemon` 二级指令的 case 分发。


8. **CRUD 指令集 (`lib/cli.sh`)**
* [ ] **Add**: 实现 `_cmd_add`。
* 参数解析（getopts 或手动解析）。
* 交互式向导（若无参数）。
* 调用 `_atomic_write` 生成文件。


* [ ] **In**: 实现 `_cmd_in`。
* 快速生成临时任务的逻辑封装。


* [ ] **Edit**: 实现 `_cmd_edit`。
* 优先调用 `$EDITOR`，降级处理为交互式修改。


* [ ] **Remove**: 实现 `_cmd_remove` (`rm` 操作)。
* [ ] **List**: 实现 `_cmd_list`。
* 读取所有任务，格式化为表格输出到 Stdout。




9. **控制指令集**
* [ ] **Group/Start/Stop/Pause/Resume**：
* 支持 `@group` 解析器：`grep -l "GROUP=xxx" tasks/*`。
* 批量修改文件状态字段。


* [ ] **Time/Count/Reset**：
* 实现对 `LAST_RUN` 和 `REMAIN_COUNT` 的数学运算修改。




10. **状态看板 (`status`)**
* [ ] 重写 `_cmd_status`。
* [ ] 检测 TTY：
* Non-TTY: 输出 key=value (包含所有任务状态)。
* TTY: 渲染包含守护进程状态和任务列表的富文本视图。




11. **音频与设置**
* [ ] 更新 `lib/sound.sh`：支持 `eye sound on/off <task_id>`。
* [ ] 实现 `eye daemon <up|down|reload|quiet|root-cmd>`。



**✅ 阶段验收标准**：
所有 CLI 指令可用。可以通过命令行完整管理任务生命周期（增删改查、暂停恢复）。

---

### 第四阶段：迁移与发布 (Migration & Release)

**目标**：确保旧用户平滑过渡，完善周边生态。

12. **迁移脚本 (`lib/migrate.sh`)**
* [ ] 编写逻辑：检查 `~/.config/eye/config` 是否存在且为旧版格式。
* [ ] 转换逻辑：解析旧变量，生成 `tasks/default` 文件。
* [ ] 归档旧配置（避免重复迁移）。
* [ ] 在 `bin/eye` 启动最开始调用此脚本。


13. **安装与自动补全**
* [ ] 更新 `Makefile` 和 `install.sh` 以适配新目录结构。
* [ ] 重写 `completions/eye.bash`：
* 支持动态获取 Task ID 补全。
* 支持 `@group` 补全。
* 支持新指令 (`daemon`, `in` 等) 补全。




14. **文档更新**
* [ ] 更新 `README.md`：展示新的任务模型和核心用法。
* [ ] 更新 `doc/ADVANCED.md`：解释文件结构和自定义脚本集成方法。



**✅ 阶段验收标准**：
在一个安装了 v0.1.1 的环境上执行更新，原有配置未丢失且自动转化为默认任务；新功能正常工作；卸载无残留。
