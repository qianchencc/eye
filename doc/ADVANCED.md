# eye 高级集成与管道操作指南

`eye` 遵循 Unix 哲学：“编写程序，使其只做一件事并做好。编写程序，使其能够协同工作。”

本手册详细介绍了如何利用 Linux 管道（Pipes）、重定向（Redirects）和脚本集成，将 `eye` 深度融入您的自动化工作流或状态栏展示。

## 1. 机器可读的状态监控

当 `eye status` 的输出被重定向或通过管道传递时，它会自动从人类友好模式切换为 **机器可读模式**（`key=value` 格式）。这消除了复杂的正则解析，方便脚本直接处理。

### 1.1 自动变量导入 (eval 技巧)
在 Shell 脚本中，您可以使用 `eval` 直接将状态导入为局部变量：

```bash
#!/bin/bash
# 自动导入所有状态变量
eval $(eye status)

# 现在可以直接访问变量：
echo "当前状态: $status"        # running, stopped, dead
echo "休息间隔: $gap_seconds"   # 整数（秒）
echo "是否暂停: $paused"        # true, false
```

### 1.2 状态栏集成示例 (Polybar/Waybar)
通过解析 `key=value` 快速判断状态并更换图标：

```bash
#!/bin/bash
STATUS=$(eye status | grep "status=" | cut -d= -f2)

case "$STATUS" in
    "running") echo "🟢 在线" ;;
    "paused")  echo "⏸️ 暂停" ;;
    *)         echo "🔴 离线" ;;
esac
```

---

## 2. 管道式配置与控制

`eye` 的交互式命令支持从标准输入（stdin）读取参数，这使得批量配置和远程控制变得非常简单。

### 2.1 动态切换语言与模式
不需要手动输入二级参数，直接通过管道传递：

```bash
# 脚本化设置语言为中文
echo "zh" | eye config language

# 脚本化切换输出模式为 unix (静默)
echo "unix" | eye config mode
```

### 2.2 批量音效管理
利用循环配合管道，可以快速导入大量自定义音效：

```bash
# 假设您有一组音效文件，快速批量注册标签
ls ~/Music/Alerts/*.oga | while read path; do
    tag=$(basename "$path" .oga)
    echo "$tag $path" | eye sound add
done
```

---

## 3. 高级脚本工作流

### 3.1 专注模式 (Focus Mode)
您可以编写一个“专注模式”脚本。当运行此脚本时，如果 `eye` 正在运行，则暂停保护（例如在视频会议或演示时），再次运行则恢复。

```bash
#!/bin/bash
# toggle_focus.sh
eval $(eye status)

if [ "$paused" == "true" ]; then
    eye resume
    notify-send "专注模式结束" "护眼提醒已恢复。"
else
    # 自动暂停 2 小时
    echo "2h" | eye pause
    notify-send "专注模式开启" "护眼提醒将暂停 2 小时。"
fi
```

### 3.2 任务切换自动暂停
利用操作系统的窗口管理器钩子（如 i3/sway 的 IPC），您可以在进入特定全屏应用时自动执行：
`echo "30m" | eye pause`

---

## 4. 环境隔离与调试

### 4.1 使用 EYE_CONFIG 切换环境
您可以通过 `EYE_CONFIG` 环境变量指定不同的配置文件，实现多场景切换：

```bash
# 办公模式：默认 20 分钟提醒一次
eye start

# 游戏模式：长间隔模式 (需要提前创建好配置文件)
EYE_CONFIG=~/.config/eye/gaming.conf eye start
```

### 4.2 无色输出 (NO_COLOR)
在将输出重定向到日志文件或 CI 环境时，可以使用 `NO_COLOR` 禁用 ANSI 颜色代码：

```bash
NO_COLOR=1 eye status > eye_report.log
```

---

## 5. 启动幂等性 (Idempotency)

在您的 `~/.bashrc` 或 X11 启动脚本（如 `.xinitrc`）中，可以放心添加以下命令：

```bash
# -q 参数确保如果服务已在运行，则静默退出 0，不会产生干扰信息
eye start -q
```

---
*保持简单，保持 Unix。*
