# Eye 开发文档 (Development Guide)

本文档旨在为 `eye` 项目的贡献者提供架构概览、开发流程和最佳实践指南。

## 1. 项目架构 (Architecture)

`eye` 采用模块化的 Bash 脚本架构。

### 1.1 目录结构

```text
eye/
├── bin/
│   └── eye              # 主程序入口 (Entry Point) & 库加载器
├── lib/                 # 核心逻辑库 (Modules)
│   ├── cli.sh           # 命令行接口实现 (Command Handlers)
│   ├── config.sh        # 配置加载与持久化
│   ├── constants.sh     # 全局常量与路径定义
│   ├── daemon.sh        # 守护进程循环、信号处理、核心动作
│   ├── i18n.sh          # 多语言消息定义 (en/zh)
│   ├── sound.sh         # 音频播放与管理
│   └── utils.sh         # 通用工具函数 (时间解析等)
├── completions/
│   └── eye.bash         # Bash 自动补全脚本
├── config/
│   └── default.conf     # 默认配置文件模板
├── doc/                 # 文档
├── Makefile             # 安装与构建脚本
└── README.md            # 用户指南
```

### 1.2 核心流程

1.  **启动流程**: 用户执行 `eye [command]` -> `bin/eye` 启动 -> 自动定位并 source `lib/*.sh` -> 解析参数 -> 调用 `lib/cli.sh` 中对应的 `_cmd_xxx` 函数。
2.  **守护进程**: `eye start` 启动后台子 Shell (`_daemon_loop` in `lib/daemon.sh`)。该循环每 5 秒检查一次时间差。
3.  **进程间通信 (IPC)**:
    -   **状态共享**: 通过文件系统 (`~/.local/state/eye/`) 共享状态。
        -   `daemon.pid`: 守护进程 PID。
        -   `last_notified`: 上次休息的时间戳。
        -   `pause_until`: 暂停结束时间戳。
        -   `stop_time`: 手动停止时的时间戳（用于计算冻结时间）。
    -   **信号控制**:
        -   `SIGUSR1`: 触发立即检查（用于 `eye pass` 立即生效）。
        -   `SIGTERM`: 优雅退出。
        -   `SIGKILL`: 强制结束 (`eye kill`)。

## 2. 开发环境搭建 (Setup)

本项目不需要编译，但为了方便调试，建议使用软链接模式。

### 2.1 初始化

```bash
# 1. 克隆仓库
git clone <repo_url> eye
cd eye

# 2. 建立开发链接 (Dev Mode)
# 这会将 ~/.local/bin/eye 链接到当前项目的 bin/eye
# 修改代码后立即生效，无需重新安装
make dev
```

### 2.2 验证

```bash
eye status
# 应该显示当前开发环境的状态
```

## 3. 模块功能说明

### 3.1 库文件职责

*   **`bin/eye`**: 
    *   **职责**: 环境探测（判断是开发环境还是生产环境），加载 `lib/`，分发 `$1` 到对应函数。
    *   **注意**: 尽量不要在此文件中编写业务逻辑。

*   **`lib/constants.sh`**:
    *   **职责**: 定义 `CONFIG_DIR`, `PID_FILE` 等常量。遵循 XDG Base Directory 规范。

*   **`lib/i18n.sh`**:
    *   **职责**: 定义 `_init_messages` 函数。根据 `LANGUAGE` 变量设置 `MSG_xxx` 变量。
    *   **扩展**: 添加新语言时，在此处增加 `elif` 分支。

*   **`lib/daemon.sh`**:
    *   **核心**: `_daemon_loop` 是后台驻留的主循环。
    *   **逻辑**: 处理 `trap` 信号，计算时间差，调用 `_eye_action`。
    *   **状态**: 处理暂停、停止后的时间补偿逻辑。

*   **`lib/cli.sh`**:
    *   **职责**: 包含所有 `_cmd_xxx` 函数（如 `_cmd_start`, `_cmd_pass`）。
    *   **逻辑**: 处理参数检查，调用其他库函数，打印用户友好的输出。

### 3.2 增加新命令 (How-to)

假设要增加一个命令 `eye report`：

1.  **实现逻辑**: 在 `lib/cli.sh` 中添加 `_cmd_report` 函数。
2.  **注册命令**: 在 `bin/eye` 的 `case "$CMD"` 中添加 `report) _cmd_report "$@" ;;`。
3.  **添加帮助**: 在 `lib/i18n.sh` 中定义 `MSG_USAGE_CMD_REPORT` 并添加到 `_usage` 函数中。
4.  **自动补全**: 在 `completions/eye.bash` 的 `commands` 列表中添加 `report`。

## 4. 状态机与时间逻辑 (State & Time)

### 4.1 计时器逻辑

*   **正常运行**: `elapsed = current_time - last_notified`.
*   **暂停 (`pause`)**: 创建 `pause_until` (结束时间) 和 `pause_start` (开始时间)。`status` 显示时计算 `pause_start - last_notified` 作为冻结的“上次休息时间”。
*   **停止 (`stop`)**: 创建 `stop_time`。`status` 显示时计算 `stop_time - last_notified`。
*   **恢复 (`start` / `resume`)**: 读取 `stop_time` 或 `pause_start`，计算停滞的时长 `duration`，将 `last_notified` 向后推移 (`new_last = old_last + duration`)，从而实现“冻结”效果（即停滞期间不计入工作时间）。

### 4.2 强制重置 (`kill`)

`eye kill` 执行彻底清理：
1.  禁用 Systemd 服务。
2.  `kill -9` 所有相关进程。
3.  删除所有状态文件 (`daemon.pid`, `last_notified`, `pause_*`, `stop_time`)。
4.  下次启动时，视为全新安装启动。

## 5. 测试 (Testing)

目前采用手动测试。每次提交前请验证：

1.  **生命周期**: `start` -> `status` -> `stop` -> `status` -> `start`。
2.  **暂停恢复**: `pause 10s` -> `status` (frozen) -> wait -> auto resume? / manual `resume`.
3.  **时间跳跃**: `pass 1h` -> 确认立即触发提醒。
4.  **强制终止**: `kill` -> 确认进程消失且 Systemd 关闭。
5.  **语言切换**: `language zh` / `en`。

## 6. 发布与安装

生产环境安装使用 `Makefile`：

```bash
make install
# 安装路径:
# bin -> ~/.local/bin/eye
# lib -> ~/.local/lib/eye/*.sh
# conf -> ~/.config/eye/
```
