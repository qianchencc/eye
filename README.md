# Eye

Eye is a lightweight eye protection tool for Linux that follows the XDG Base Directory Specification.

## Features

- **Non-intrusive**: Runs silently in the background.
- **Standardized**: Strictly follows XDG Base Directory Specification.
- **Native Experience**: Supports Bash auto-completion.
- **Audio Management**: Supports built-in sound schemes and custom audio files.

## Installation

### For Development

```bash
git clone <repository_url>
cd eye
make dev
```

### For Production

```bash
make install
```

## Usage

```bash
eye start
eye stop
eye status
eye set 20m 20s
```
