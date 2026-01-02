# Gemini Context: Eye Protection Tool (v2.0 Refactoring)

This document provides instructional context for the `eye` project, a lightweight, Unix-style periodic task manager and eye protection daemon for Linux.

**STATUS: v2.0 REFACTORING IN PROGRESS (Branch: `dev`)**

## Project Overview

`eye` is being refactored from a simple eye protection tool into a **General Purpose Periodic Task Manager**. It helps users manage recurring tasks (like the 20-20-20 rule, hydration reminders, medication, etc.) via a robust CLI and background daemon.

### Key Technologies
- **Bash**: Core logic and CLI.
- **Spool Pattern**: File-based task management (`~/.config/eye/tasks/`).
- **Systemd**: User-level daemon management.
- **libnotify & PulseAudio**: Notification and sound alert systems.

### Architecture (Target v2.0)

The project is moving towards an "Everything is a File" architecture.

- **Storage Model**:
    - **Tasks**: stored as individual files in `~/.config/eye/tasks/`. Each file represents a task (key-value pairs + sourced script).
    - **Global Config**: `~/.config/eye/eye.conf` (global switches, default behaviors).
    - **State**: `~/.local/state/eye/` (PID files, history logs).
- **Daemon Logic**:
    - A read-write execution loop that scans the task spool.
    - Handles "Pulse" tasks (instant notification) and "Periodic" tasks (duration-based with file locking).
    - Manages task lifecycle (execution counts, temporary tasks).

### Directory Structure (v2.0 Target)
- `bin/eye`: Main entry point (dispatcher).
- `lib/`:
    - `io.sh`: Atomic file I/O operations.
    - `daemon.sh`: Core scheduler engine.
    - `cli.sh`: Command implementations (CRUD).
    - `utils.sh`: Output stream management (Stdout vs Stderr/TTY).
    - `migrate.sh`: Migration logic from v1.x.

## Development & Refactoring Roadmap

The project is currently in the **Refactoring Phase** (see `roadmap.md` for details).

1.  **Infrastructure & Data Layer**: Establish atomic I/O, `tasks/` directory structure, and stream-based output logging.
2.  **The Engine**: Rewrite `daemon.sh` to support multi-task scheduling, file locking, and lifecycle hooks.
3.  **CLI Interface**: Implement `add`, `remove`, `list`, `in` (temp task), and group control commands (`start @work`).
4.  **Migration & Release**: Create scripts to migrate v1.0 `config` to v2.0 task files; update documentation and completions.

## Core Commands (Target)

- **Task Management**:
    - `eye add <name>`: Create a new task (interactive or flagged).
    - `eye list`: Show all tasks in a table.
    - `eye in <time> <msg>`: Create a one-off temporary task.
    - `eye edit <id>`: Edit a task file.
    - `eye remove <id>`: Delete a task.
- **Control**:
    - `eye start/stop/pause/resume [id | @group]`: Control specific tasks or groups.
    - `eye now [id]`: Trigger a task immediately.
- **Daemon**:
    - `eye daemon up/down`: Manage the background service.
    - `eye status`: Show daemon status and active tasks.

## Building and Running

- **Install**: `make install`
- **Dev Setup**: `make dev` (Symlinks for local development).
- **Tests**: Use `tests/comprehensive_test.sh` (needs updating for v2.0).

## Coding Conventions

- **Atomic Writes**: Always use `_atomic_write` for file modifications to prevent corruption.
- **Output Streams**:
    - **Stdout**: Data only (parsable).
    - **Stderr**: Human interaction, logs, emojis. Check `[ -t 2 ]` for color.
- **Locking**: Use `set -C` (noclobber) on lockfiles for critical sections.