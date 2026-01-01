# Development Guide

This document provides guidelines for contributing to `eye`, an eye protection daemon designed with the Unix philosophy in mind.

## Project Structure

- **bin/eye**: The main executable entry point. Handles argument parsing, global flags (`-q`), and signal trapping.
- **lib/**: Core logic libraries.
  - `cli.sh`: Implementation of CLI commands (`start`, `stop`, `status`, etc.).
  - `daemon.sh`: The background process logic and signal handling.
  - `config.sh`: Configuration loading and saving (`~/.config/eye/config`).
  - `constants.sh`: File paths and global constants.
  - `i18n.sh`: Internationalization (English/Chinese) and message strings.
  - `sound.sh`: Audio management logic (`paplay`).
  - `utils.sh`: Utility functions (logging, time parsing, valid input reading).
- **doc/**: Documentation.

## Design Principles (Unix Philosophy)

1.  **Silence is Golden**: Successful commands should output nothing by default (Unix Mode). Use `msg_success` wrapper which respects `QUIET_MODE` and `EYE_MODE`.
2.  **Stdout vs Stderr**:
    - Data goes to `stdout`.
    - Errors, warnings, and decorative headers go to `stderr`.
3.  **Machine Readable**:
    - `eye status` automatically detects if it is being piped (`! -t 1`) and switches to `key=value` format.
    - In TTY, it shows human-readable formats.
4.  **Exit Codes**:
    - Success: `0`
    - Error: `1` (or other non-zero)
5.  **Idempotency**:
    - `eye start` should not fail if already running (silent exit in Unix mode).
    - `eye sound add` should not fail if the tag exists with the same path.

## Environment Variables

- `NO_COLOR=1`: Disable ANSI color codes.
- `EYE_CONFIG=/path/to/config`: Override configuration file.
- `QUIET_MODE=1`: Force silence (set via `-q` flag).

## Testing

### Manual Testing
Use `bin/eye` directly from the source during development.

```bash
# Start daemon
bin/eye start

# Check status (Human)
bin/eye status

# Check status (Machine)
bin/eye status | grep "status="

# Test Silence
bin/eye set 20m 20s -q
```

### Debugging
- Use `msg_info` for debug logs (visible in TTY).
- Check `~/.local/state/eye/` for PID and logs.

## Internationalization

Add new strings to `lib/i18n.sh`.
- Use `LANG_MODE` variable to check language.
- Define keys like `MSG_MY_FEATURE_SUCCESS`.

## Adding Commands

1.  Define the function `_cmd_myfeature` in `lib/cli.sh`.
2.  Add it to the `case` statement in `bin/eye`.
3.  Update `_cmd_usage` in `lib/cli.sh`.

---
*Keep it simple, keep it Unix.*