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
make install
```

### 安装后设置

安装完成后，请重新加载 shell 配置以启用 `eye` 命令及自动补全：

```bash
source ~/.bashrc  # 或 ~/.zshrc
```

## 使用方法

### 核心命令
- `eye start`: 启动后台保护程序。
- `eye stop`: 停止程序并保存当前状态。
- `eye status [-l]`: 显示当前状态。使用 `-l` 查看详细信息（PID、音效等）。
- `eye set <gap> <look>`: 设置工作/休息时长 (例如: `20m 20s`)。
- `eye now [--reset]`: 立即触发休息 (`--reset` 将重置计时器)。
- `eye pause <time>`: 暂停服务 (例如: `1h`, `30m`)。
- `eye resume`: 恢复服务。
- `eye kill`: 强制清理所有进程并重置状态。

### 配置与管理 (`eye config ...`)
- `eye config language <en|zh>`: 设置显示语言。
- `eye config mode <unix|normal>`: 切换输出模式 (Unix 简洁模式或 Normal 友好模式)。
- `eye config autostart <on|off>`: 管理开机自启动。
- `eye config update [--apply|--force]`: 检查并应用更新。
- `eye config uninstall`: 从系统中彻底卸载 `eye`。

### 音频管理 (`eye sound ...`)
- `eye sound list`: 列出所有可用的音效。
- `eye sound on|off`: 开启/关闭提示音。
- `eye sound set <start> <end>`: 设置开始和结束时的提示音。
- `eye sound add <tag> <path>`: 添加自定义音效文件。

更多集成示例（Polybar、脚本集成），请参阅 [高级用法指南](./doc/ADVANCED.md)。

## 配置说明

配置文件存储在 `~/.config/eye/config`。

---
*保持简单，保持 Unix。*