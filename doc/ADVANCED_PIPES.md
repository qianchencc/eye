# Eye System Programming Interface & Pipeline Specification

This document provides a rigorous technical specification of the `eye` Unix interface. It defines command signatures, data schemas, and I/O contracts required for AI-driven automation.

---

## 1. Data Schema (The `EYE_T_` Metadata)

When executing `eye status <id>` in a pipeline, it outputs shell-compatible variables.

| Variable | Type | Description | Values / Format |
| :--- | :--- | :--- | :--- |
| `EYE_T_NAME` | String | Task display name | Plain string |
| `EYE_T_GROUP` | String | Task group identifier | `default` or custom string |
| `EYE_T_INTERVAL` | Integer | Trigger frequency | Seconds (e.g., 3600) |
| `EYE_T_DURATION` | Integer | Task duration | Seconds (0 = Pulse task) |
| `EYE_T_STATUS` | Enum | Current execution state | `running`, `paused`, `stopped` |
| `EYE_T_TARGET_COUNT`| Integer | Total allowed loops | -1 (Infinite) or Positive Integer |
| `EYE_T_REMAIN_COUNT`| Integer | Remaining loops | Integer |
| `EYE_T_LAST_RUN` | Timestamp | Last trigger time | Unix epoch (seconds) |
| `EYE_T_PAUSE_TS` | Timestamp | When task was paused | Unix epoch or 0 |
| `EYE_T_RESUME_AT` | Timestamp | Scheduled auto-resume | Unix epoch or 0 |

---

## 2. Command I/O Specification

### Core Input Rule
All **Sink** commands (commands that act on tasks) follow this priority:
1.  **Explicit Argument**: `eye <cmd> task1` (Acts only on `task1`).
2.  **Stdin**: If no task ID argument is provided, reads Task IDs from `stdin` (newline or space-separated).
3.  **Default**: If `stdin` is a TTY and no argument, acts on the default task (`eye_rest`).

### Command Contract Table

| Command | Role | Position Arguments | Flags (partial) | Stdout (Non-TTY) |
| :--- | :--- | :--- | :--- | :--- |
| `add` | Sink | `[ID...]` | `-i`, `-d`, `-g`, `-c` | List of created IDs |
| `remove` | Sink | `[ID...]` | None | List of removed IDs |
| `list` | Source | None | `-s`, `-r`, `-l` | List of all task IDs |
| `status` | Inspector| `[ID]` | `-l` | Raw metadata (KEY=VAL) |
| `group` | Sink | `[GRP] [ID...]` | None | List of affected IDs |
| `start` | Sink | `[ID...]` | None | List of affected IDs |
| `stop` | Sink | `[DUR] [ID...]` | `-a` | List of affected IDs |
| `resume` | Sink | `[ID...]` | `-a` | List of affected IDs |
| `now` | Sink | `[ID...]` | None | List of triggered IDs |
| `time` | Sink | `<DELTA> [ID]` | None | List of affected IDs |
| `count` | Sink | `<DELTA> [ID]` | None | List of affected IDs |
| `reset` | Sink | `[ID]` | `--time`, `--count` | List of affected IDs |

---

## 3. Advanced Pipeline Chaining & Positional Shifts

### The `group` Command Shift
In a pipeline, the `group` command interprets the **first** non-flag argument as the `NEW_GROUP_NAME`.
*   **Interactive**: `eye group task1 health`
*   **Piped**: `echo "task1" | eye group health` (Here, `health` is the group name, task ID comes from stdin).

### The `stop` Command Shift
Similar to `group`, the first argument is interpreted as `DURATION`.
*   **Piped**: `eye list | grep "work" | eye stop 30m`

---

## 4. Exit Codes (Error Handling)

Automation scripts should check `$?` for reliability.

| Code | Meaning |
| :--- | :--- |
| `0` | Success (at least one task matched and operated) |
| `1` | General error (Invalid syntax, invalid duration format) |
| `127` | Command not found |

---

## 5. Formal Logic Examples for LLM Context

### Example 1: Conditional Grouping (Filter by Metadata)
**Requirement**: Move all tasks with an interval greater than 1 hour to the "slow" group.
```bash
for id in $(eye list); do
    eval $(eye status "$id")
    if [ "$EYE_T_INTERVAL" -gt 3600 ]; then
        echo "$id"
    fi
done | eye group slow
```

### Example 2: State-Based Triggering
**Requirement**: Trigger all "health" tasks that are currently "running".
```bash
eye list | while read id; do
    eval $(eye status "$id")
    if [[ "$EYE_T_GROUP" == "health" && "$EYE_T_STATUS" == "running" ]]; then
        eye now "$id"
    fi
done
```

---

## 6. Prompt Engineering Strategy

To get the best results from an AI, include the following in your system prompt:
> "Act as a Linux systems engineer. Refer to the 'Eye Unix Specification' for I/O contracts. Write a robust bash script using pipes to [Objective]. Redirect eye's stderr to /dev/null for clean processing."
