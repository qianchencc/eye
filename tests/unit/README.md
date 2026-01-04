# Eye Unit Tests

This directory contains focused unit tests for verifying specific components and logic of the `eye` system.

## Test Standards

1.  **Isolation**: Each test script must start by cleaning the environment (stopping daemon, clearing tasks).
2.  **Helpers**: Use `source ../debug_utils.sh` to access assertion and debug functions.
3.  **Assertions**:
    *   Use `assert_status <task_id> <expected_status>` for status checks.
    *   Use `assert_val <task_id> <VAR_SUFFIX> <expected_value>` for other variable checks.
4.  **Failure**: Tests should exit with code 1 on failure and print debug information (handled by helpers).

## Running Tests

You can run individual tests directly:
```bash
./tests/unit/test_lifecycle.sh
```

Or run the full suite (if available in parent directory).

## Test Files

*   `test_lifecycle.sh`: Core task state transitions (start/stop/resume).
*   `test_daemon_states.sh`: Verifies CLI behavior when Daemon is ON vs OFF.
*   `test_time_manipulation.sh`: Verifies `time` command impact on NEXT calculation.
*   `test_counter_temp.sh`: Verifies `count` limits and temporary task deletion.
*   `test_group_batch.sh`: Verifies group operations and regex targeting.
*   `test_now_trigger.sh`: Verifies `now` command behavior.
*   `test_complex_scenarios.sh`: Simulates complex user workflows.
