# Eye

Eye 是一款轻量级、遵循 Unix 哲学的 Linux 护眼守护进程。它旨在通过非侵入的方式提醒您遵循 **20-20-20 原则**（每隔 20 分钟，抬头眺望 20 英尺远的地方，持续 20 秒）来缓解眼部疲劳。

## 功能特性

* **非侵入式**：在后台静默运行。
* **原生体验**：提供原生的 Bash 自动补全功能和桌面通知。
* **音频方案**：集成 `freedesktop-sound-theme`，提供高质量的提示音。
* **高度可配置**：可轻松设置提醒间隔、语言及自定义音效。

## 安装指南

### 一键安装（推荐）

```bash
wget -qO- https://raw.githubusercontent.com/qianchencc/eye/master/install.sh | bash

```

### 手动安装以及开发

```bash
git clone https://github.com/qianchencc/eye.git
cd eye
./install.sh

```

### 安装后设置

安装完成后，请重新加载 shell 配置以启用 `eye` 命令及自动补全：

```bash
source ~/.bashrc  # 或 ~/.zshrc

```

## 使用方法

```bash
eye start         # 启动护眼守护进程
# 初次安装后需要手动执行eye start后才会启动。

eye status        # 查看当前运行状态

eye set 20m 20s   # 设置工作时长和休息时长

eye now           # 立即触发一次休息
# 即使在eye未运行时也可以使用now触发休息。当使用eye now -r时会重置上次休息时间。

eye sound list    # 查看可用的提示音效

eye kill # 用于处理可能存在的bug情况，将eye清理至刚完成安装的状态。
```

## 配置说明

配置文件存储在 `~/.config/eye/config`。

* `eye config mode normal` 开启详细输出模式，对普通用户更友好。
* `eye config mode unix` 默认模式，支持管道，输出更简洁。可以通过doc/ADVANCED_USAGE.md查看一些高级用法。
* `eye language <zh/en>` 配置输出语言。不影响管道操作。

---
