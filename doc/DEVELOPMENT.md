# Development Guide

This document provides guidelines for contributing to `eye`, an eye protection daemon designed with the Unix philosophy in mind.

## Project Structure

- **bin/eye**: The main entry point. Handles argument parsing and command dispatching.
- **lib/**: Modular logic libraries.
  - `cli.sh`: Implementation of commands. Uses `_cmd_config` for management tasks.
  - `daemon.sh`: The background loop and service integration.
  - `i18n.sh`: Localized strings for English and Chinese.
  - `constants.sh`: Paths and versioning.
- **tests/**: Automated test scripts for CI/CD and local validation.

## Command Architecture

We use a **flat-core, nested-management** model:
1.  **Top-level**: Core operational commands (`start`, `stop`, `status`, `set`, `now`).
2.  **Config**: Administrative tasks grouped under `config` (`language`, `mode`, `update`, `uninstall`).
3.  **Sound**: Audio-specific tasks under `sound`.

## Design Principles

1.  **Silence is Golden**: In `unix` mode (default), successful commands must not output anything to `stdout`.
2.  **Machine Readable**: `eye status` must output `key=value` pairs when detected not a TTY.
3.  **Idempotency**: `eye start` should exit 0 if already running. `eye sound add` should overwrite if tag exists.

## Testing

### Local Validation
You can run the comprehensive test suite directly:
```bash
./tests/comprehensive_test.sh normal
./tests/comprehensive_test.sh unix
```

### Docker Testing (Recommended)
To ensure isolation and Ubuntu compatibility:
```bash
docker build -t eye-test -f Dockerfile.test .
docker run --rm -it eye-test ./tests/comprehensive_test.sh normal
```

## Adding New Features

1.  **Messages**: Add strings to `lib/i18n.sh`.
2.  **Logic**: Implement `_cmd_yourfeature` in `lib/cli.sh`.
3.  **Dispatch**: Add entry to `case` statement in `bin/eye`.
4.  **Completion**: Update `completions/eye.bash`.

---
*Keep it simple, keep it Unix.*