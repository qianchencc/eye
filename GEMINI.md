# Gemini Context: Eye Protection Tool (v2.0 Beta)

**STATUS: v2.0-beta RELEASED**

## Project Overview

`eye` has been successfully refactored into a **General Purpose Periodic Task Manager**.

### Key Achievements (v2.0)
- **Architecture**: Switched to Spool Pattern (`~/.config/eye/tasks/`).
- **Engine**: Robust daemon with multi-task support and file locking.
- **CLI**: Full CRUD support (`add`, `list`, `remove`, `edit`, `in`).
- **Control**: Group-based management (`pause @work`).
- **Migration**: Automatic v1.x -> v2.0 migration.

### Current Version: 0.2.0-beta

## Directory Structure
- `bin/eye`: Main dispatcher.
- `lib/`:
    - `cli.sh`: Command logic.
    - `daemon.sh`: Background engine.
    - `io.sh`: Atomic file operations.
    - `migrate.sh`: Migration logic.
- `tests/`:
    - `test_v2_engine.sh`: Core logic tests.
    - `test_v2_cli.sh`: CLI interaction tests.

## Recent Changes
- Fixed language switching mechanism (dynamic reload).
- Enhanced `add` command with templates.
- Added extensive help menus for subcommands.
- Updated notification format.

## Next Steps
- Gather user feedback on v2.0-beta.
- Polish documentation.
- Prepare for v1.0.0 stable release (SemVer reset or continue from 0.2?).

