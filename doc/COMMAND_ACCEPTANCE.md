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
    - [ ] Confirm default status is `stopped`.
    - [ ] Confirm `LAST_RUN` alignment ensures `NEXT` equals `INTERVAL` immediately after creation.
- **Remarks**: Warns if daemon is down.

### `start`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] **FAIL**: Fails to block activation when daemon is inactive? (Already implemented, needs re-verification).
    - [ ] Verify `LAST_RUN` is updated to `now` upon starting to align the timer.
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
    - [ ] **FAIL**: `NEXT` time flows for `Stopped` tasks when Daemon is inactive (stat-based ref_time issue).
    - [ ] Verify inspection mode (`status <id>`) returns raw data in non-TTY.
- **Remarks**: Optimized for pipe-friendliness.

---

## 3. State Manipulation

### `time`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] **FAIL**: `eye time +1s task` affects all tasks' `NEXT` calculation.
    - [ ] **FAIL**: Feedback message "New Next" shows incorrect/negative values.
    - [ ] **FAIL**: Confusing direction: `+1s` should decrease `NEXT` by 1 second (trigger sooner).
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
    - [ ] **FAIL**: `eye reset @group` failed to match/reset tasks in the group.
    - [ ] Verify `--time` and `--count` flags separately.
- **Remarks**: Resets timer to `now` and counter to `target`.

---

## 4. Daemon & System

### `daemon`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] **FAIL**: Infinite tasks (`count -1`) stop looping (stuck at `NEXT 0s`).
    - [ ] Verify `up`/`down` cleanup logic.
    - [ ] Verify systemd service generation.
- **Remarks**: |

### `sound`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] **FAIL**: Sound plays before Notification in queued scenarios.
    - [ ] Verify custom sound registration.
- **Remarks**: Audio playback is now blocking.

---

### `help` / `version`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify all subcommands display correct usage.