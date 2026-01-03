## 0. 通用测试原则 (General Principles)

1. **原子性验证**：每个写操作指令执行后，必须验证对应的文件内容（带 `EYE_T_` 前缀的变量）是否已正确更新。
2. **流分离验证**：
    * **Stdout**：包含机器可读数据或表格。
    * **Stderr**：包含交互提示、Emoji 及 Log。
3. **环境隔离测试**：
    * **Daemon 状态隔离**：验证 Daemon 运行（事件触发）和停止状态下的 CLI 行为。
    * **Provider Mock**：通过 Mock `notify-send` 或设置 `NOTIFY_BACKEND="wall"` 验证通知逻辑。
    * **变量替换验证**：验证通知内容中的 `{DURATION}`, `{INTERVAL}`, `{NAME}`, `{REMAIN_COUNT}` 是否被正确解析。
4. **命名空间一致性**：验证 `lib/io.sh` 加载的任务变量均带有 `EYE_T_` 前缀。

---

## 1. 核心指令集测试 (Core Commands)

### 1.1 任务控制 (Control)

| 测试场景 | 执行指令 | 预期行为 (Side Effects) | `status` 预期表现 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **启动特定任务** | `eye start task1` | 1. 修改文件：`EYE_T_STATUS=running`<br>2. 更新 `EYE_T_LAST_RUN` | 列表行显示 `🟢 Running` | 验证命名空间写入 |
| **停止组任务** | `eye stop @work` | 组内任务修改为 `EYE_T_STATUS=paused` | 列表行显示 `⏸️ Paused` | 状态机流转验证 |
| **恢复任务** | `eye resume task1` | 1. 计算时间补偿<br>2. `EYE_T_STATUS=running` | 列表行恢复 `🟢 Running` | 核心：时间补偿逻辑 |

### 1.2 状态查询 (Status)

* **管道检测**: `eye status | cat` 应输出简单的文本列表。
* **排序验证**: `eye status -s next` 应正确按时间戳排序。

### 1.3 任务增删改 (CRUD)

* **标准添加**: `eye add water -i 1h` -> 检查文件包含 `EYE_T_INTERVAL=3600`。
* **临时任务**: `eye in 30m "Nap"` -> 检查 `EYE_T_IS_TEMP=true`。

### 1.4 状态操纵 (Manipulation)

* **时间偏移**: `eye time +10m task1` -> `EYE_T_LAST_RUN` 相应减小。
* **重置全部**: `eye reset task1 --time --count` -> 验证计时器和计数器均恢复初始值。

---

## 2. Provider 与后端测试 (Providers)

*重点验证后端切换与降级逻辑。*

| 测试场景 | 配置 | 预期行为 |
| --- | --- | --- |
| **桌面通知** | `NOTIFY_BACKEND=desktop` | 调用 `notify-send` |
| **系统广播** | `NOTIFY_BACKEND=wall` | 调用 `wall` 指令 |
| **自动探测** | `NOTIFY_BACKEND=auto` | 根据环境自动选择最佳后端 |

---

## 3. 守护进程行为测试 (Daemon)

1. **inotify 响应测试**：
    * **操作**：Daemon 运行中，手动 `echo "EYE_T_INTERVAL=5" >> tasks/task1`。
    * **预期**：Daemon 应立即检测到文件变动并重新加载任务，无需等待轮询周期。
2. **停机补偿测试**：
    * **操作**：停止 Daemon 10分钟后重启。
    * **预期**：`EYE_T_LAST_RUN` 应自动增加 600秒，防止通知堆积。