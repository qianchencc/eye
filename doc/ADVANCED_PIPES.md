# 管道与高级自动化指南 (Advanced Automation with Pipes)

`eye` (v2.0) 深度集成了 Unix 管道哲学。所有的核心指令（add, start, stop, remove, group, now 等）都原生支持从标准输入 (stdin) 读取目标 ID。

这使得 `eye` 可以作为更复杂自动化脚本中的一个强力环节。

---

## 1. 批量任务操作 (Mass Operations)

### 批量创建任务
你可以通过 `seq` 或其他命令生成 ID 并批量创建相同配置的任务：
```bash
# 一次性创建 5 个任务，每小时触发一次
seq 1 5 | xargs -I{} echo "work_{}" | eye add -i 1h -g work
```

### 批量删除任务
配合 `eye list` (非 TTY 模式下输出纯 ID)，可以快速清理特定任务：
```bash
# 删除所有包含 "temp_" 的任务
eye list | grep "temp_" | eye remove
```

---

## 2. 动态过滤与控制 (Filtered Control)

你可以结合 `grep` 或 `awk` 对当前任务进行复杂的逻辑过滤，然后立即执行控制命令。

### 停止特定组的任务
虽然 `eye stop @group` 已内置，但管道模式支持更复杂的正则：
```bash
# 停止所有组名包含 "office" 或 "biz" 的任务
eye list | grep -E "office|biz" | eye stop
```

### 立即触发所有已暂停的任务
```bash
# 找出所有状态为 Paused 的任务并立即执行一次
eye status | grep "Paused" | awk '{print $2}' | eye now
```

---

## 3. 批量属性修改 (Bulk Modification)

### 快速重新分组
```bash
# 将所有以 "proj_" 开头的任务移动到 "archive" 组
eye list | grep "^proj_" | eye group archive
```

### 重置所有健康类任务的计数器
```bash
# 找出 health 组的所有任务并重置它们的计数
eye list | grep "health" | eye reset --count
```

---

## 4. 机器可读性 (Machine-Friendly Output)

当 `eye` 指令在管道中使用时，它的输出会自动发生变化：

*   **`eye list` / `eye status`**: 
    *   在终端运行：显示漂亮的表格。
    *   在管道运行：仅输出任务 ID 列表（每行一个）。
*   **`eye status <id>`**:
    *   在终端运行：显示带边框的详情看板。
    *   在管道运行：输出纯净的 `EYE_T_KEY=VALUE` 环境变量格式，方便 `source` 或 `grep`。

---

## 5. 示例：定时任务清理脚本
你可以编写简单的 Cron 任务来自动化管理 `eye`：
```bash
#!/bin/bash
# 每天凌晨清理所有已过期的临时任务
eye list | grep "^temp_" | eye remove
```

通过拥抱管道，`eye` 不再仅仅是一个简单的护眼工具，而是一个可以无限扩展的任务调度引擎。
