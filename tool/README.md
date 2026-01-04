# Eye Auxiliary Tools (`tool/`)

This directory contains utility scripts designed for advanced users and developers to integrate `eye` with other systems (like Tmux, Polybar, custom dashboards) or to perform automated inspections.

## 1. Usage Guide

All tools are executable scripts. They expect `eye` to be installed or available in the project structure.

### `get_status`
Displays a comprehensive status row for specific task(s).
```bash
./tool/get_status <task_id> [task_id...]
```
**Output Format:**
```
ID       │ GROUP   │ INTERVAL │ DUR │ COUNT   │ STATUS  │ NEXT
work     │ default │ 45m 0s   │ 0s  │ (-1/-1) │ Running │ 12m 30s
break    │ health  │ 10m 0s   │ 5m  │ (2/5)   │ Stopped │ 10m 0s
```

### `get_next`
Displays a minimal status row, focusing on the countdown.
```bash
./tool/get_next <task_id> [task_id...]
```
**Output Format:**
```
ID       │NEXT     │ STATUS
work     │12m 30s  │ Running
break    │10m 0s   │ Stopped
```

---

## 2. Development Guidelines

When creating new tools for this directory, please adhere to the following standards:

### 2.1 Batch Processing (Multi-Arg Support)
*   Tools **MUST** support multiple arguments to process tasks in batch.
*   **Pattern**: Iterate over `$@` to handle each argument as a separate target.
    ```bash
    for target in "$@"; do
        process_target "$target"
    done
    ```

### 2.2 Environment & Dependencies
*   **Language**: Bash is preferred for consistency with the core project.
*   **Shebang**: Use `#!/bin/bash`.
*   **Library Loading**:
    Scripts should automatically resolve the `lib/` directory relative to themselves. Use this standard boilerplate:
    ```bash
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
    EYE_BIN="$(cd "$SCRIPT_DIR/../bin" && pwd)/eye"
    
    if [ ! -d "$LIB_DIR" ]; then
        echo "Error: Library not found." >&2; exit 1
    fi
    source "$LIB_DIR/utils.sh" # Load necessary modules
    ```

### 2.2 Output Format
*   **Pipe-Friendly**: If the tool is intended for data processing, avoid ASCII borders.
*   **Human-Friendly**: If intended for display (like `get_status`), use aligned columns (`printf`) and standard separators (e.g., `│`).
*   **No ANSI Colors (Optional)**: By default, tools should output plain text unless a `--color` flag is supported, to ensure compatibility with bars/logs.

### 2.3 Logic Reuse
*   **Do not duplicate logic**. Call `eye status <id>` to get raw data (`EYE_T_*` variables) and `eval` it.
    ```bash
    TASK_DATA=$("$EYE_BIN" status "$TASK_ID" 2>/dev/null)
    [ -z "$TASK_DATA" ] && exit 1
    eval "$TASK_DATA"
    ```
*   Use `lib/utils.sh` for formatting helpers like `_format_duration`.

### 2.4 naming convention
*   Use `snake_case` for file names (e.g., `check_health`, `export_csv`).
*   Make the name descriptive of the action or output.

---

## 3. Contribution
To add a new tool:
1.  Create the script in `tool/`.
2.  Make it executable: `chmod +x tool/your_script`.
3.  Add documentation to this README and `GEMINI.md`.
