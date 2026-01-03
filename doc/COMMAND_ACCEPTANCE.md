# Eye Command Acceptance Registry

This document tracks the formal verification of each command. Once a command is marked as **PASSED**, its core logic is frozen and should not be modified without explicit justification.

| Command | Status | TODO / Pending Checks | Remarks |
| :--- | :--- | :--- | :--- |
| `add` | 🟡 PENDING | Verify wizard interactive mode | Default status is now `stopped`. Warns if daemon is down. |
| `rm` / `remove` | 🟡 PENDING | Verify multi-target removal | Alias `rm` added. Kills associated task processes. |
| `list` / `status` | 🟡 PENDING | Verify JSON output format | Fixed pipe-mode output (IDs only). |
| `start` | 🟡 PENDING | Verify behavior when task is already running | Now fails if Daemon is inactive. |
| `stop` | 🟡 PENDING | Verify timed-pause (e.g. `stop 30m`) | Kills running task process immediately. |
| `pause` | 🟡 PENDING | (Deprecated? stop is alias) | Uses `_core_task_pause`. |
| `resume` | 🟡 PENDING | Verify `--all` flag | Restores task to `running`. |
| `in` | 🟡 PENDING | Verify auto-deletion after trigger | Defaults to `stopped`. |
| `edit` | 🟡 PENDING | Verify interactive menu saving | Selective edit mode implementation. |
| `group` | 🟡 PENDING | Verify regex matching for groups | Fixed pipe-mode parameter shift. |
| `now` | 🟡 PENDING | Verify interaction when status is `stopped` | Uses `EYE_FORCE_RUN` to bypass state check. |
| `time` | 🟡 PENDING | Verify relative shifts (+/-) | |
| `count` | 🟡 PENDING | Verify infinite count protection | |
| `reset` | 🟡 PENDING | Verify `--time` and `--count` flags | |
| `daemon` | 🟡 PENDING | Verify systemd service generation | `up`/`down` manages state and cleanup. |
| `sound` | 🟡 PENDING | Verify custom sound registration | Audio playback is now blocking. |
| `help` | 🟡 PENDING | Ensure all subcommands have help | |
| `version` | 🟡 PENDING | | |

## Acceptance Protocol
1.  **Manual Test**: User performs manual verification in a live environment.
2.  **Request Acceptance**: User instructs the agent to mark command as PASSED.
3.  **Freeze**: Command logic is considered stable.
