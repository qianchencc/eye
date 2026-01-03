# Docker Testing Strategy & Standards

This document outlines the standardized approach for developing and testing `eye` using Docker containers. We strictly use `docker-compose` to ensure a persistent, reproducible, and clean testing environment.

## 1. Core Principles

1.  **Persistence**: We use a persistent container (`eye-dev`) via `docker-compose` to avoid repetitive dependency installation and enable stateful debugging.
2.  **Isolation**: All tests must run inside the container. Do not pollute the host system.
3.  **Cleanliness**:
    *   Test scripts must be placed in `tests/` or a dedicated `temp/` directory.
    *   **NEVER** place temporary shell scripts in the project root.
    *   Clean up temporary files and task configurations after execution.
4.  **Verification Rigor**:
    *   **Do not rely solely on Status Flags** (e.g., `EYE_T_STATUS=paused`).
    *   **Verify Behavior**: Check logs for absence of triggers.
    *   **Verify State**: Ensure `NEXT` execution time is stable (not changing) for paused tasks.
    *   **Verify Side Effects**: Ensure no orphaned processes (sleep/notify-send) remain running.

## 2. Environment Setup

### 2.1 Starting the Environment
The environment is defined in `docker-compose.yml` and `Dockerfile.dev`.

```bash
# Start the persistent container in background
docker-compose up -d

# Check if it's running
docker-compose ps
```

### 2.2 Entering the Environment
Access the container's shell to run commands manually:

```bash
docker-compose exec eye-dev bash
```

Inside the container, the project root is mounted at `/home/tester/eye`.

## 3. Running Tests

### 3.1 Standard Test Suite
Run the established test suite located in `tests/`:

```bash
# Inside container
make test
# OR
./tests/test_full_suite.sh
```

### 3.2 Ad-hoc / Reproduction Scripts
When investigating bugs or verifying fixes:
1.  Create a script in `temp/` (e.g., `temp/repro_lock.sh`).
2.  Script should:
    *   Reset daemon state (`eye daemon down && eye daemon up`).
    *   Create specific scenarios.
    *   Assert results.
    *   **Clean up** tasks and stop daemon upon completion.
3.  Run it: `bash temp/repro_lock.sh`
4.  Delete it after verification.

## 4. Debugging & Logs

The new logging system writes to `~/.local/state/eye/history.log`.

- **Tail logs**: `tail -f ~/.local/state/eye/history.log`
- **Log Levels**:
    - `SYSTEM`: Daemon lifecycle events.
    - `LOCK`: Lock acquisition/release (Critical for concurrency).
    - `TASK`: Execution flow.
    - `SCHED`: Timer scheduling.

## 5. Concurrency & Locking Tests
When testing resource contention:
- **Do not** use identical tasks. Vary `interval` and `duration` slightly to create realistic overlaps.
- Observe the `[LOCK]` entries in the log to confirm `WAIT` and `ACQUIRED` sequences.