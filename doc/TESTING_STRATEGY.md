## 0. 通用测试原则 (General Principles)

1. **原子性验证**：每个写操作指令执行后，必须验证对应的文件（Task File 或 `eye.conf`）内容是否已正确更新。
2. **流分离验证**：
    * **Stdout**：必须仅包含机器可读的数据（如 Task ID, JSON, `key=value`）。
    * **Stderr**：交互提示、Log、Emoji 必须在此流中。开启 `eye daemon quiet on` 后，Stderr 必须为空。
3. **环境隔离测试**：
    * **Daemon 状态隔离**：必须分别在 Daemon 运行和停止两种状态下测试 CLI 命令的行为（如 `status` 的 `NEXT` 表现）。
    * **通知模拟**：在 CI/Docker 等无 UI 环境下，应验证 `notify-send` 命令的调用逻辑而非实际弹窗。
    * **变量替换验证**：验证通知内容中的 `${VAR}` 和 `{VAR}` 风格变量（如 `{DURATION}`, `{INTERVAL}`, `{NAME}`, `{REMAIN_COUNT}`）是否被正确解析为真实值。
4. **输出直观验证 (Host-like Check)**：
    * 测试程序应模拟宿主机环境中的真实交互，捕获并显示关键指令的完整输出，确保 `status` 等命令在不同状态下的展示符合预期（如显示 `(off)`）。
5. **状态一致性**：CLI 修改状态后，`status` 命令的输出必须立即反映该变化。
5. **容错性**：针对不存在的任务 ID、非法的时间格式、无权限的文件操作，必须返回非 0 退出码 (Exit Code) 并给出明确错误提示。

---

## 1. 核心指令集测试 (Core Commands)

### 1.1 任务控制 (Control)

| 测试场景 | 执行指令 | 预期行为 (Side Effects) | `status` 预期表现 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **启动特定任务** | `eye start task1` | 1. 修改 `task1` 文件：`STATUS=running`<br>2. 更新 `LAST_RUN` 为当前时间戳 | 列表行显示 `🟢 Running`<br>`Next` 开始顺延 | 验证原子写入 |
| **停止组任务** | `eye stop @work` | 遍历 ` @work` 组所有文件，修改 `STATUS=stopped` | 列表行显示 `🔴 Stopped`，<br>`Next` 显示时间不再变化 | 批量操作验证 |
| **暂停所有** | `eye pause --all` | 1. 所有运行中任务 `STATUS=paused`<br>2. 记录当前时间到 `PAUSE_TS` 字段 | 列表行显示 `⏸️ Paused`<br>显示暂停开始时间 | 全局操作验证 |
| **恢复任务** | `eye resume task1` | 1. 计算 `diff = now - PAUSE_TS`<br>2. `LAST_RUN += diff` (补时)<br>3. `STATUS=running` | 列表行恢复 `🟢 Running`<br>`Next` 时间相应顺延 | 核心：时间补偿逻辑 |

### 1.2 状态查询 (Status)

| 测试场景 | 执行指令 | Stdout 预期内容 | 格式要求 |
| --- | --- | --- | --- |
| **默认显示** | `eye status` | 包含表头 (ID, State, Next, Group) 和任务行 | 对齐的表格格式 (Table) |
| **排序验证** | `eye status -s next` | 第一行为下次运行时间最近的任务 | 验证时间戳排序逻辑 |
| **JSON 输出** | `eye status --json` | `[{"id":"task1", "status":"running"...}]` | 合法的 JSON 格式，无多余文本 |
| **管道检测** | `eye status \ cat` | `id=task1 status=running group=default...` | 自动切换为 `key=value` 格式 |

### 1.3 任务增删改 (CRUD)

| 测试场景 | 执行指令 | 预期行为 (File System) | 预期输出 (Stdout/Stderr) |
| :--- | :--- | :--- | :--- |
| **标准添加** | `eye add water -i 1h` | 创建 `tasks/water`<br>内容含 `INTERVAL=1h`, `STATUS=stopped` | Stdout: `water`<br>Stderr: `✅ Task created` |
| **临时任务** | `eye in 30m "Nap"` | 创建 `tasks/temp_<ts>`<br>含 `IS_TEMP=true`, `COUNT=1`, `INTERVAL=30m` | Stdout: `temp_<ts>`<br>Stderr: `✅ Timer set for 30m` |
| **编辑器模式** | `eye add new -e` | 1. 生成模板文件<br>2. 调用 `$EDITOR`<br>3. 仅当编辑器正常退出且文件有效时保存 | 交互式流程，无固定输出 |
| **物理删除** | `eye rm water` | `tasks/water` 文件消失 | Stderr: `🗑️ Task removed` |

### 1.4 状态操纵 (Manipulation)

| 测试场景 | 执行指令 | 预期逻辑验证 | `status` 预期表现 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **时间快进** | `eye time +10m task1` | `LAST_RUN` 减去 600秒 (让下次触发提前) | `Next` 字段减少 10分钟 | 模拟时间流逝 |
| **时间倒流** | `eye time -1h task1` | `LAST_RUN` 加上 3600秒 | `Next` 字段增加 1小时 | 延迟任务执行 |
| **减少计数** | `eye count -1 task1` | `REMAIN_COUNT` 减 1 | `Count` 列显示 `x/y` 更新 | 验证计数扣减逻辑 |
| **触发结束** | `eye count -99 task1` | 当 `REMAIN` 归零：<br>1. 若 `IS_TEMP=true`，文件被删除<br>2. 若 `IS_TEMP=false`，`STATUS=stopped` | 任务从列表消失 或 状态变为 `🔴 Stopped` | 验证生命周期终点 |
| **重置全部** | `eye reset task1 -a` | `LAST_RUN=now`, `REMAIN=TARGET` | 计时器和计数器均恢复初始值 | 验证状态重置 |
---

## 2. 音频指令测试 (Sound)

*重点验证层级覆盖逻辑：全局设置 > 任务设置。*

| 测试场景 | 执行指令 | 配置变化 | 播放行为预期 (Mock Play) |
| --- | --- | --- | --- |
| **任务静音** | `eye sound off task1` | `task1` 文件：`SOUND_ENABLE=false` | 任务触发时，**不调用**播放器 |
| **全局静音** | `eye sound off` | `eye.conf`: `GLOBAL_MUTE=true` | 即使任务 `SOUND_ENABLE=true`，也**不播放** |
| **全局恢复** | `eye sound on` | `eye.conf`: `GLOBAL_MUTE=false` | 恢复尊重任务自身的设置 |
| **自定义音效** | `eye sound add my_sound /path/a.wav` | `custom_sounds.map` 增加记录 | `eye sound play my_sound` 应调用播放器 |

---

## 3. 守护进程与配置测试 (Daemon & Config)

### 3.1 偏好设置 (Preferences)

| 测试场景 | 执行指令 | 配置文件 (`eye.conf`) | 行为验证 |
| --- | --- | --- | --- |
| **静默模式** | `eye daemon quiet on` | `QUIET_MODE=on` | 执行 `eye add ...` 时，**Stderr 无任何输出** |
| **默认命令** | `eye daemon root-cmd status` | `ROOT_CMD=status` | 仅输入 `eye` 回车，应显示状态列表 |
| **默认 ID** | `eye daemon default water` | `DEFAULT_TASK=water` | 执行 `eye pause` (无参) 应暂停 `water` 任务 |

### 3.2 守护进程行为 (Daemon Process)

*此部分需模拟 Daemon 运行环境进行集成测试。*

1. **并发锁测试**：
    * **预设**：任务 A (Interval 1m, Duration 10s) 和 任务 B (同上)，同属 Group G。
    * **触发**：手动修改 A 的 `LAST_RUN` 使其触发。
    * **操作**：在 A 进入 `rest` (Duration) 期间，手动修改 B 的 `LAST_RUN` 使其也应该触发。
    * **预期**：Daemon 检测到锁，**B 不应立即触发**（不弹窗、不播放），而是推迟到锁释放后。


2. **生命周期测试**：
    * **预设**：临时任务 T (`IS_TEMP=true`, `COUNT=1`)。
    * **触发**：修改时间使其触发。
    * **预期**：触发完成后，Daemon 再次扫描时，`tasks/T` 文件应当**不存在**。


3. **热加载测试**：
    * **操作**：Daemon 运行时，外部执行 `eye add ...` 新增文件。
    * **预期**：Daemon 下一次轮询（如 5s 后）应当能自动识别并处理新任务，无需重启。



---

## 4. 边界条件与异常测试 (Edge Cases)

| 场景 | 输入 | 预期结果 |
| --- | --- | --- |
| **非法时间格式** | `eye add t1 -i 20x` | Exit 1, Stderr 提示格式错误 (如 "Invalid duration format") |
| **操作不存在的任务** | `eye stop ghost_task` | Exit 1, Stderr 提示 "Task not found" |
| **重复添加** | `eye add t1 ...` (t1 已存在) | 询问覆盖 (交互模式) 或 报错 (脚本模式)，不应默默破坏原文件 |
| **空组操作** | `eye start @empty_group` | Stderr 提示 "No tasks found in group"，Exit 0 或 1 视策略定 |
| **权限不足** | `chmod 000 tasks/t1; eye rm t1` | Exit 1, 提示权限错误 |
