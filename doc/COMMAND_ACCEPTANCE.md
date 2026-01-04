# Eye Command Acceptance Registry

## Acceptance Principles
1.  **Strict Verification**: A command is only marked as `PASSED` after manual verification of both its state (metadata) and behavior (real-world effects like notifications and process termination).
2.  **Behavior over Flags**: Do not trust `EYE_T_STATUS` alone. Observe the logs, `NEXT` time stability, and system processes.
3.  **Regression Safety**: Once a command is `PASSED`, its logic is frozen. Any change requiring a modification to a `PASSED` command must be explicitly approved.
4.  **Edge Case focus**: Verification must include non-TTY environments (Docker/Scripts) and resource contention scenarios.
5.  **Manual Control Only**: 禁止擅自修改验收文档，修改该文档必须依赖于我的指令。

---

## 1. Task Lifecycle & Management

### `add`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify wizard interactive mode correctly sets all `EYE_T_` variables.
    - [x] **FIXED**: Default status is now `stopped`.
    - [x] **FIXED**: `LAST_RUN` alignment ensures `NEXT` equals `INTERVAL` immediately after creation.
- **Remarks**: Warns if daemon is down.

### `start`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: Fails to block activation when daemon is inactive.
    - [x] **FIXED**: `LAST_RUN` is updated to `now` upon starting to align the timer (effectively skipping past overdue cycles).
- **Remarks**: Now strictly requires an active Daemon.

### `stop` (alias: `pause`)
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify physical process termination (SIGTERM) works for various providers.
    - [ ] Verify timed-pause (e.g., `stop 30m`) resume logic in Daemon.
- **Remarks**: Kills running instances immediately.

### `rm` / `remove`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify both alias `rm` and `remove` work identically.
    - [ ] Confirm physical process cleanup.
- **Remarks**: Permanent deletion.

### `edit`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify interactive menu correctly saves specific fields without corrupting others.
    - [ ] Verify flag-based editing (e.g., `edit -i 1h`).
- **Remarks**: Selective edit mode.

---

## 2. Information & Inspection

### `list` / `status`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: `NEXT` time is now stable for `Stopped` tasks (shows full INTERVAL).
    - [x] **FIXED**: `NEXT` calculation no longer shifts for all tasks when a file is saved (removed directory stat dependency).
    - [ ] Verify inspection mode (`status <id>`) returns raw data in non-TTY.
- **Remarks**: Optimized for pipe-friendliness.

---

## 3. State Manipulation

### `time`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: Feedback message "New Next" shows correct/capped values.
    - [x] **FIXED**: Confusing direction: `+1s` correctly decreases `NEXT` by 1 second.
    - [x] **FIXED**: Capping: `NEXT` is capped at `0s` for positive shifts, never negative.
- **Remarks**: Direct timestamp manipulation.

### `count`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify decrement/increment.
    - [ ] Confirm infinite count (`-1`) protection.
- **Remarks**: |

### `reset`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: `@group*` glob-style matching implemented.
    - [x] **FIXED**: Enforced flags: `reset` without flags now shows help and errors out.
    - [x] **FIXED**: Finished tasks (count=0) reject `reset --time` with a warning.
- **Remarks**: Resets timer to `now` and counter to `target`.

---

## 4. Daemon & System

### `daemon`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: Gap-based Timing: The next interval starts *after* the task finishes (Duration + Sounds + 1s Buffer), ensuring a full period of "work" time.
    - [x] **FIXED**: Scheduling Robustness: Removed memory PID map in favor of 100% physical state registry.
    - [ ] Verify `up`/`down` cleanup logic.
- **Remarks**: |

### `sound`
- **Status**: 🟡 PENDING
- **TODO**:
    - [x] **FIXED**: Notification-Sound synchronization: Added 0.1s delay to ensure notification appears before blocking audio starts.
- **Remarks**: Audio playback is now blocking and synchronized.

---

### `help` / `version`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify all subcommands display correct usage.