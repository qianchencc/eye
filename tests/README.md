# Eye Test Suite Documentation

This directory contains the comprehensive test suite for `eye`. The tests are designed to be run inside a Docker container to ensure a clean, reproducible environment.

## 1. Test Structure

*   `test_full_suite.sh`: The master wrapper script. It runs all tests in `tests/eye/*.sh` sequentially, handles timeouts, and reports a summary.
*   `tests/eye/*.sh`: Individual test scripts focusing on specific commands or features.
    *   `test_add.sh`: Task creation.
    *   `test_remove.sh`: Task deletion and **process cleanup verification**.
    *   `test_status.sh`: Status reporting (Pipe-friendly vs Inspection).
    *   `test_group_cmd.sh`: Group management and **pipe mode logic**.
    *   `test_daemon_*.sh`: Daemon lifecycle (up, down, uninstall, maintenance).
    *   ...and others.

## 2. Running Tests

### 2.1 Pre-requisites
Ensure you have the Docker environment set up (see `../doc/DOCKER_TESTING.md`).

### 2.2 Execution
Run the full suite inside the container:

```bash
docker-compose up -d
docker exec eye_eye-dev_1 bash -c "make install && bash tests/test_full_suite.sh"
```

### 2.3 Individual Tests
You can run a specific test script for debugging:

```bash
docker exec eye_eye-dev_1 bash tests/eye/test_group_cmd.sh
```

## 3. Test Standards

*   **Idempotency**: Tests should clean up after themselves (remove tasks, reset daemon).
*   **Timeout**: All tests are wrapped with `timeout 20s` in `test_full_suite.sh` to prevent hanging processes.
*   **Non-TTY Compatibility**: Tests explicitly verify behavior in non-TTY environments (simulating cron/scripts).
*   **Assertions**: Tests use strict exit codes (`exit 1` on failure) and verify output using `grep` or variable comparison.

## 4. Troubleshooting

If a test fails:
1.  Check the specific error output.
2.  Inspect `~/.local/state/eye/history.log` inside the container for daemon logs.
3.  Verify if `column` or other utilities behave differently in your environment (known issue: `column` crashes in some non-TTY docker shells).
