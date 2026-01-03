# eye

eye 是一个遵循 Unix 哲学的通用周期性任务管理器。它采用轻量级守护进程（Daemon）与文件池（Spool）架构，旨在为 Linux 环境提供非侵入式的、轻量且高度可编程的任务调度功能。
起初我仅将其开发为一个贯彻20-20-20用眼原则的提醒组件.因此在将其开发为周期任务管理器后,我仍然保留了eye_rest作为默认任务。

## 项目概述

- **核心优势：Unix 生态集成**是 eye 最强大的功能。采用 **Spool 架构**，所有任务均为独立的纯文本文件。你可以直接利用 `grep`, `sed`, `awk` 以及 **Unix 管道** 对任务池进行复杂的逻辑过滤与批量操作，无需编写复杂的插件。
- **内核驱动**：基于 `inotify` 事件驱动，配置变更毫秒级响应，无闲置 CPU 占用。
- **解耦输出**：支持 Provider 模式，原生适配桌面通知、终端广播（Wall）及 Tmux 状态栏。
- **环境隔离**：所有任务变量严格隔离在 `EYE_T_` 命名空间，确保系统环境纯净。
- **自动补全**: 所有的指令包括名称均支持自动补全。
- **多语言支持**: 可以通过`eye daemon language zh`设置语言为中文，将应用于终端打印以及交互式命令。

## 快速使用

### 1. 一键安装
```bash
curl -sSL https://raw.githubusercontent.com/qianchencc/eye/master/install.sh | bash
```

### 2. 基础操作

安装后，需要手动开启eye服务进程.
- **启动服务**：`eye daemon up`

你可以通过eye add <task_name>来通过交互式脚本创建任务。也可以通过eye add help查看如何通过命令行快速创建任务。
下面是一个快速创建一个每小时提醒饮水的样例，并将该任务添加到组health中。
- **创建任务**：`eye add water -i 1h -g health`

eye 提供了 **`eye in <time> <msg>`** 语法糖，用于快速创建一次性临时提醒（触发后自动销毁）。
- **临时提醒**：`eye in 30m "Go for a walk"`

默认情况下eye指令被配置为eye help。也可以使用eye daemon root-cmd status将eye配置为eye status以快速查看状态。
- **查看状态**：`eye list` # list是status的别名。

eye中使用`@`对组进行操作，并且支持正则表达式。使用eye help，查看详细用法。下面是一个简单的样例：
- **任务控制**：`eye stop @health` (暂停健康组) 或 `eye start water`

### 3. 卸载清理
若需彻底移除 eye 及其所有配置，请执行：
```bash
eye daemon uninstall
```

如果因为特殊原因导致安装失败，你也可以下载代码中的uninstall.sh来协助完成全量卸载。

## 如何查看帮助

eye 拥有完善的自文档系统：
- **全局帮助**：`eye help`
- **二级指令帮助**：`eye <command> help`
  - 示例：`eye add help`, `eye status help`, `eye group help`

也可以在doc/目录下查看所有指令的设计文档。

## 从源代码安装

```bash
git clone https://github.com/qianchencc/eye.git
cd eye
make install
```

## 高级使用文档

- [核心指令手册](./doc/COMMANDS.md)：详细的参数说明与状态机逻辑。
- [管道与自动化指南](./doc/ADVANCED_PIPES.md)：**[AI 友好]** 详细定义了 eye 的 Unix 输出规范。我们鼓励用户将此文档提供给 AI 工具（如 ChatGPT/Claude），以快速生成满足个人需求的复杂高级管道指令。
- [测试与维护](./doc/TESTING_STRATEGY.md)：了解项目的原子性原则与测试策略。

## 参与贡献与反馈

我们非常欢迎用户提出宝贵的意见或建议，以帮助我们不断改进这个工具。如果您发现它在日常生活中帮上了忙，我们将深感荣幸。

您可以随时通过 GitHub 提交 Issue 或 Pull Request 来参与项目。

---
LICENSE: MIT
