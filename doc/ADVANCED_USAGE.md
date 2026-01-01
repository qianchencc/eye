# Advanced Usage & Unix Integration

`eye` has been designed with the Unix philosophy in mind: *"Write programs that do one thing and do it well. Write programs to work together."*

This guide demonstrates how to leverage pipes (`|`), redirects (`>`), and scripting to integrate `eye` into your daily workflow.

## 1. Unix Mode & Silence

By default, `eye` runs in **Unix Mode**. This means:
- **Silence is Golden**: Successful commands produce no output to `stdout`.
- **Errors to Stderr**: Only errors and warnings are printed to `stderr`.
- **Machine-Readable**: Commands like `status` output clean `key=value` pairs when piped.

You can toggle modes via:
```bash
eye config mode normal  # Verbose, human-friendly output
eye config mode unix    # Silent, script-friendly (Default)
```

Or force silence temporarily with `-q`:
```bash
eye set 20m 20s -q
```

## 2. Controlling `eye` via Pipes

You can pipe arguments into `eye` commands. This is useful for scripts, dmenu/rofi integrations, or batch processing.

### Pause/Resume
```bash
# Pause for 1 hour without typing arguments manually
echo "1h" | eye pause

# Resume (Input is ignored but pipe triggers command)
echo "" | eye resume
```

### Configuration
```bash
# Set work interval to 45m and look-away to 15s
echo "45m 15s" | eye set

# Switch language dynamically
echo "zh" | eye language
```

### Sound Management
```bash
# Preview a sound by piping the tag
echo "bell" | eye sound play

# Bulk add sounds (using xargs or loops)
ls ~/Music/Alerts/*.oga | while read path; do
    filename=$(basename "$path" .oga)
    echo "$filename $path" | eye sound add
done
```

## 3. Status Monitoring & Integration

When `eye status` output is piped, it automatically switches to a machine-readable format (`key=value`). This is perfect for building status bar modules (Polybar, Waybar, i3blocks, etc.).

**Example Output (Piped):**
```ini
status=running
pid=12345
gap_seconds=1200
look_seconds=20
language=en
sound_switch=on
paused=false
last_rest_ago=300
```

### Example: Simple Status Checker
```bash
#!/bin/bash
# check_eye.sh

STATUS=$(eye status | grep "status=" | cut -d= -f2)

if [ "$STATUS" == "running" ]; then
    echo "🟢 Eye: On"
elif [ "$STATUS" == "paused" ]; then
    echo "⏸️ Eye: Paused"
else
    echo "🔴 Eye: Off"
fi
```

### Example: Polybar Module
```ini
[module/eye]
type = custom/script
exec = ~/.config/polybar/scripts/eye_status.sh
interval = 5
click-left = eye now
click-right = eye pause 30m
```

With `eye_status.sh`:
```bash
#!/bin/bash
eval $(eye status) # Imports output as shell variables

if [ "$status" == "running" ]; then
    if [ "$paused" == "true" ]; then
        echo "⏸️ Until $(date -d "@$pause_until" +%H:%M)"
    else
        # Calculate time until next break
        next_break=$(( gap_seconds - last_rest_ago ))
        if [ $next_break -lt 0 ]; then next_break=0; fi
        echo "👀 Next: $((next_break / 60))m"
    fi
else
    echo "zzz"
fi
```

## 4. Environment Variables

`eye` respects standard Unix environment variables to behave predictably in different environments.

### `NO_COLOR`
Set `NO_COLOR=1` to disable ANSI color codes in output (e.g., for logging to text files).
```bash
NO_COLOR=1 eye status
```

### `EYE_CONFIG`
Override the default configuration file location. Useful for testing or having multiple profiles (e.g., "Work" vs "Gaming" profiles).

```bash
# Start with a gaming profile (long intervals)
EYE_CONFIG=~/.config/eye/gaming.conf eye start

# Check status of specific profile
EYE_CONFIG=~/.config/eye/gaming.conf eye status
```

## 5. Idempotency & Startup Scripts

You can safely add `eye` to your `.bashrc` or startup scripts (e.g., `~/.xinitrc`, sway config) without worrying about errors if it's already running.

```bash
# In your startup script:
# If already running, this exits silently with code 0.
eye start -q
```

## 6. Advanced Workflow Examples

### "Focus Mode" Script
Create a script that pauses eye protection while you are in a Zoom meeting or playing a game.

```bash
#!/bin/bash
# toggle_focus.sh

# Check if we are paused
is_paused=$(eye status | grep "paused=true")

if [ -n "$is_paused" ]; then
    eye resume
    notify-send "Focus Mode Ends" "Eye protection resumed."
else
    # Pause for 2 hours
    echo "2h" | eye pause
    notify-send "Focus Mode" "Eye protection paused for 2 hours."
fi
```

### Log Analysis
Since `eye` writes logs and status, you can track your habits.
```bash
# Check how many times you triggered a manual break today?
# (Assuming you log output or grep logs)
```

---
*Happy Hacking!*
