# Eye (v2.0)

**Eye** has evolved from a simple eye protection tool into a **General Purpose Periodic Task Manager** for Linux, built with the Unix philosophy in mind.

It manages recurring tasks (like the 20-20-20 rule, hydration reminders, or medication schedules) via a robust file-based spool system and a lightweight background daemon.

## ✨ Features (v2.0)

- **Everything is a File**: Tasks are simple text files in `~/.config/eye/tasks/`.
- **Spool Architecture**: Add, remove, or edit tasks atomically without stopping the daemon.
- **Dynamic Groups**: Groups are automatically created when referenced and destroyed when empty.
- **Flexible Scheduling**: Support for **Pulse** (instant notification) and **Periodic** (duration-based with locking) tasks.
- **Group Control**: Manage tasks in batches using `@group` selectors (e.g., `eye pause @work`). Supports **Regular Expressions** for flexible matching (e.g., `eye stop "@work_.*"`).
- **Resource Efficient**: Pure Bash, event-driven, minimal footprint.

## 🚀 Installation

```bash
git clone https://github.com/qianchencc/eye.git
cd eye
make install
```
*Note: Ensure `~/.local/bin` is in your `$PATH`.*

## 📖 Quick Start

### 1. Start the Daemon
```bash
eye daemon up
```

### 2. Create Tasks
```bash
# Classic 20-20-20 rule (Interval: 20m, Duration: 20s)
eye add vision -i 20m -d 20s -g health

# Hydration reminder (Every 1 hour, instant notification)
eye add water -i 1h

# Temporary reminder (One-off)
eye in 45m "Pizza is ready!"
```

### Manage Tasks
```bash
eye list               # View all tasks
eye stop @health       # Pause all health-related tasks
eye now water          # Trigger hydration reminder immediately
eye edit vision        # Edit the task file in $EDITOR or interactively
```

## 🛠️ Command Reference

### Task Management
| Command | Description |
| :--- | :--- |
| `eye add <name>` | Create a new task (interactive wizard or flags). |
| `eye list` | Show status of all tasks (alias for `status`). |
| `eye remove <id>` | Delete a task. |
| `eye edit <id>` | Modify task configuration. |
| `eye in <time> <msg>` | Create a temporary one-off task. |

### Control
| Command | Description |
| :--- | :--- |
| `eye start [id\|@grp]` | Start/Resume tasks. |
| `eye stop [id\|@grp] [t]` | Pause tasks (preserves state, optional duration). |
| `eye resume [id\|@grp]` | Resume paused tasks. |
| `eye now [id]` | Trigger a task immediately. |

### Daemon & Config
| Command | Description |
| :--- | :--- |
| `eye daemon up/down` | Start/Stop the background service. |
| `eye daemon status` | Show detailed service status. |
| `eye config quiet on` | Enable silent mode (no stderr output). |
| `eye sound on/off` | Global sound switch. |

## 📂 Configuration

- **Global Config**: `~/.config/eye/eye.conf`
- **Task Files**: `~/.config/eye/tasks/`
- **Logs**: `~/.local/state/eye/history.log`

Tasks are simple Shell-sourced files. You can edit them manually:
```bash
NAME="Deep Work"
INTERVAL=3000  # Seconds
DURATION=0
GROUP="work"
SOUND_START="bell"
```

## 🔄 Migration from v1.x

Eye v2.0 automatically detects your old configuration and migrates it to a default task (`tasks/default`) upon first run. Your old `config` file is backed up as `config.bak`.

## 📄 License

MIT License