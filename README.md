# Eye 👁️

[![Version](https://img.shields.io/badge/version-0.1.1-blue.svg)](https://github.com/qianchencc/eye)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

**Eye** 是一款轻量级、遵循 Unix 哲学的 Linux 护眼守护进程。它旨在通过非侵入的方式提醒您遵循 **20-20-20 原则**，缓解眼部疲劳。

---

## ✨ 功能特性

*   **极简主义**：纯 Bash 编写，无重型依赖。
*   **类Unix风格**：原生支持管道操作，提供机器可读的 `key=value` 输出。
*   **非侵入式通知**：桌面通知与音频提示。
*   **高度可配置**：支持多语言切换、自定义音效及运行模式。
*   **零残留**：内置自更新与自卸载功能。

## 🚀 快速开始

### 安装 (Recommended)
```bash
wget -qO- https://raw.githubusercontent.com/qianchencc/eye/master/install.sh | bash
```

### 开发与源码安装
```bash
git clone https://github.com/qianchencc/eye.git
cd eye
make install  # 生产环境安装
# 或者使用 make dev 建立开发软链接
```

> **注意**：安装后请运行 `source ~/.bashrc` (或对应的 shell 配置) 以启用补全。

## 🛠️ 使用指南

### 核心控制
| 命令 | 说明 |
| :--- | :--- |
| `eye start` | 启动后台守护进程 |
| `eye stop` | 停止服务并保存当前状态 |
| `eye status [-l]` | 查看状态。`-l` 展开详细配置与 PID |
| `eye now [--reset]` | 立即休息。`--reset` 重置当前计时周期.即使eye未运行也可以使用该命令 |
| `eye set <gap> <look>` | 设置周期。例如 `eye set 20m 20s` |
| `eye kill`| 用于处理可能存在的卡死情况，释放所有进程，并将eye恢复到刚安装时的状态 |

### 高级管理 (`eye config`)
*   `eye config language <en|zh>`：切换中英文。
*   `eye config mode <unix|normal>`：切换输出风格（默认为Unix 模式）。
*   `eye config update [--apply,--force]`：直接使用update为检查更新.--apply,--force用于应用在线更新。
*   `eye config uninstall`：一键清理所有痕迹并卸载。

### 音频管理 (`eye sound`)
*   `eye sound list`：列出所有音效。
*   `eye sound on|off`：全局开关提示音。
*   `eye sound add <tag> <path>`：注册音效。

---

## 🔗 高级集成

`eye` 设计之初就考虑了自动化。您可以轻松将其集成到 **Polybar**, **Waybar** 或 **i3blocks** 中。

详见：[高级用法与集成手册](./doc/ADVANCED.md)



