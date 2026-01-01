# Eye

Eye is a lightweight, Unix-style eye protection daemon for Linux. It helps you follow the 20-20-20 rule to reduce eye strain.

## Features

- **Non-intrusive**: Runs silently in the background (Unix-style).
- **Native Experience**: Native Bash auto-completion and desktop notifications.
- **Audio Schemes**: Integrated with `freedesktop-sound-theme` for high-quality alerts.
- **Configurable**: Easily set intervals, languages, and custom sound effects.

## Prerequisites

Ensure you have the following system dependencies installed:

- **notify-send**: `libnotify-bin`
- **paplay**: `pulseaudio-utils`
- **Audio Theme**: `sound-theme-freedesktop`
- **Completion**: `bash-completion`
- **Build**: `make`

On Debian/Ubuntu:
```bash
sudo apt install libnotify-bin pulseaudio-utils sound-theme-freedesktop bash-completion make
```

## Installation

### One-line Install (Recommended)

```bash
wget -qO- https://raw.githubusercontent.com/qianchencc/eye/master/install.sh | bash
```

### Manual Install

```bash
git clone https://github.com/qianchencc/eye.git
cd eye
./install.sh
```

### Post-Installation

After installation, reload your shell configuration to enable the `eye` command and auto-completion:

```bash
source ~/.bashrc  # or ~/.zshrc
```

## Usage

```bash
eye start         # Start the protection daemon
eye status        # Check current status
eye set 20m 20s   # Set work interval and break duration
eye now           # Trigger a break immediately
eye sound list    # View available sound effects
```

## Configuration

Settings are stored in `~/.config/eye/config`. You can use `eye config mode normal` to enable verbose output or `eye config mode unix` for silent operation.

---
*Keep it simple, keep it Unix.*