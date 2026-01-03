# Task Lifecycle & Process Management Specification

## 1. Overview
This document defines how `eye` manages the lifecycle of periodic tasks, specifically focusing on process creation, tracking, and termination. The goal is to ensure that "Stopped" means **Stopped**, and that tasks cannot run effectively without the Daemon.

## 2. Process Model

### 2.1 Dependency on Daemon
- **Rule**: Users CAN create task configurations (files) at any time.
- **Rule**: However, a task **MUST NOT** execute or trigger if the Daemon is not running.
- **Implementation**: `eye add` and `eye in` must warn the user if the Daemon is inactive.

### 2.2 The PID Registry (`$STATE_DIR/pids/`)
To effectively manage background processes (which `bash` cannot easily track once disowned/backgrounded from a function), we utilize a file-based PID Registry.

- **Registry Path**: `~/.local/state/eye/pids/`
- **Registration**: When `_execute_task` starts, it MUST write its own `$BASHPID` to `$STATE_DIR/pids/<task_id>`.
- **Deregistration**: When `_execute_task` exits (naturally or signal), it MUST remove this file via `trap`.

## 3. Signal Handling & Termination

### 3.1 Stopping a Task (`eye stop`)
When a user stops a task:
1.  **Update State**: `EYE_T_STATUS` is set to `paused` in the task file (Persistence).
2.  **Kill Process**: CLI checks `$STATE_DIR/pids/<task_id>`.
    *   If found: Sends `SIGTERM` to the PID.
    *   The Process receives `SIGTERM`, triggers cleanup trap, and exits immediately.
    *   This ensures the `sleep` is interrupted and the "End Sound" does not play.

### 3.2 Removing a Task (`eye remove`/`rm`)
1.  **Kill Process**: Same logic as `eye stop` (Force Kill).
2.  **Delete File**: Remove the definition from `tasks/`.

### 3.3 Daemon Shutdown (`eye daemon down`)
1.  **Kill Daemon**: Sends signal to Daemon PID.
2.  **Kill Children**: Daemon (or CLI as fallback) iterates through ALL files in `$STATE_DIR/pids/` and kills the corresponding processes.
3.  **Cleanup**: Removes the `pids/` directory.

## 4. Crash Recovery
- **Stale PIDs**: On `eye daemon up`, the Daemon MUST clean up any leftover files in `pids/`, as no tasks should be running from a previous session.
