# Eye

Eye is a lightweight eye protection tool for Linux that follows the XDG Base Directory Specification.

## Features

- **Non-intrusive**: Runs silently in the background.
- **Standardized**: Strictly follows XDG Base Directory Specification.
- **Native Experience**: Supports Bash auto-completion.
- **Audio Management**: Supports built-in sound schemes and custom audio files.

## Dependencies

Before installing, ensure you have the following system dependencies:

- **notify-send** (usually in `libnotify-bin` or `libnotify`)
- **paplay** (usually in `pulseaudio-utils` or `libpulse`)
- **Bash** (v4.0+)

## Installation

### For Production

```bash
# Clone the repository
git clone https://github.com/yourusername/eye.git
cd eye

# Install (checks dependencies automatically)
make install
```

### For Development

```bash
make dev
```

## Usage

```bash
eye start
eye stop
eye status
eye set 20m 20s
```
