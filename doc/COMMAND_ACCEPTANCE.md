# Eye Command Acceptance Registry

## Acceptance Principles
1.  **Strict Verification**: A command is only marked as `PASSED` after manual verification of both its state (metadata) and behavior (real-world effects like notifications and process termination).
2.  **Behavior over Flags**: Do not trust `EYE_T_STATUS` alone. Observe the logs, `NEXT` time stability, and system processes.
3.  **Regression Safety**: Once a command is `PASSED`, its logic is frozen. Any change requiring a modification to a `PASSED` command must be explicitly approved.
4.  **Edge Case focus**: Verification must include non-TTY environments (Docker/Scripts) and resource contention scenarios.
5.  **Manual Control Only**: 禁止擅自修改验收文档，修改该文档必须依赖于我的指令。
6.  **Failure Logging**: 当用户未通过验收时，收录报错信息到todo中。
7.  **Clean Fixes**: 在完成修复后删除todo，并再次等待用户验收。防止遗留的todo为后续工作带来不便。

---

## 1. Task Lifecycle & Management

### `add`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify wizard interactive mode correctly sets all `EYE_T_` variables.
- **Remarks**: Warns if daemon is down.

### `start`
- **Status**: 🟡 PENDING
- **TODO**:
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
- **Remarks**: Selective edit mode.

---

## 2. Information & Inspection

### `list` / `status`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify inspection mode (`status <id>`) returns raw data in non-TTY.
- **Remarks**: Optimized for pipe-friendliness.

---

## 3. State Manipulation

### `time`
- **Status**: 🟡 PENDING
- **TODO**:
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
- **Remarks**: Resets timer to `now` and counter to `target`.

---

## 4. Daemon & System

### `daemon`
- **Status**: 🟡 PENDING
- **TODO**:
- **Remarks**: |

### `sound`
- **Status**: 🟡 PENDING
- **TODO**:
- **Remarks**: Audio playback is now blocking.

---

### `help` / `version`
- **Status**: 🟡 PENDING
- **TODO**:
    - [ ] Verify all subcommands display correct usage.