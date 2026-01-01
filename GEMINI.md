# Gemini Context: Eye Protection Tool

This document provides instructional context for the `eye` project, a lightweight, Unix-style eye protection daemon for Linux.

## Project Overview

`eye` is a CLI-based eye protection tool written in Bash. It helps users follow the 20-20-20 rule (every 20 minutes, look at something 20 feet away for 20 seconds) by providing desktop notifications and audio alerts.

### Key Technologies
- **Bash**: Core logic and CLI.
- **libnotify (notify-send)**: Desktop notifications.
- **PulseAudio (paplay)**: Audio alerts.
- **Systemd**: Optional user-level daemon management.
- **Make**: Build and installation system.

### Architecture
The project follows a modular structure where the main executable acts as a loader for libraries located in `lib/`.

- `bin/eye`: The main entry point. It sources library files and dispatches commands.
- `lib/`: Contains modular bash scripts:
    - `cli.sh`: Implementation of CLI commands (e.g., `start`, `stop`, `set`).
    - `daemon.sh`: Core background loop and systemd integration logic.
    - `config.sh`: Configuration management (loading/saving).
    - `constants.sh`: Path definitions and global constants. Follows XDG specs.
    - `i18n.sh`: Internationalization (supports English and Chinese).
    - `sound.sh`: Audio playback and sound theme management.
    - `utils.sh`: Helper functions (logging, time parsing, requirement checks).
- `assets/`: Sound assets used for notifications.
- `completions/`: Bash auto-completion scripts.

## Building and Running

### Installation
- **Standard Install**: `make install` (Installs to `~/.local/bin` and `~/.local/lib/eye`).
- **Development Setup**: `make dev` (Creates symlinks for easier development).
- **Uninstall**: `make uninstall` or `make purge` (to remove configuration and state).

### Core Commands
- `eye start`: Starts the background protection daemon.
- `eye stop`: Stops the daemon and saves the current state.
- `eye status`: Displays current status (running/paused/stopped) and configuration.
- `eye set <gap> <look>`: Sets the work interval and break duration (e.g., `eye set 20m 20s`).
- `eye autostart on|off`: Enables or disables the systemd user service for persistence.
- `eye now [--reset]`: Triggers a break immediately.
- `eye sound list`: Lists available sound effects.

## Development Conventions

### Coding Style
- **Modularity**: New features should be added to relevant files in `lib/` or a new library file.
- **Function Naming**:
    - `_cmd_<name>`: Functions implementing a CLI command.
    - `_<name>`: Internal library functions.
- **Namespacing**: While bash doesn't have namespaces, prefixing internal variables with `EYE_` or using local variables within functions is preferred.

### State and Configuration
- **XDG Compliance**:
    - Config: `~/.config/eye/config`
    - Data: `~/.local/share/eye`
    - State/PID: `~/.local/state/eye`
- **Configuration**: Always use `_load_config` before accessing configuration variables and `_save_config` after modifications.

### Internationalization (i18n)
- All user-facing strings should be defined in `lib/i18n.sh` using `MSG_*` variables for both English and Chinese.

### Testing
- Currently, there is no formal testing framework. Manual testing of CLI commands and daemon behavior is required. Propose adding unit tests for `utils.sh` (e.g., duration parsing).
