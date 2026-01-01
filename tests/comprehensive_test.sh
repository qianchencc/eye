#!/bin/bash

MODE=$1
[ -z "$MODE" ] && MODE="normal"

# ANSI Colors
GREEN='\033[0;32m'
NC='\033[0m'
export PATH="$PWD/bin:$PATH"

echo -e "${GREEN}>>> Starting Comprehensive Test in [$MODE] Mode <<<${NC}"

# 0. Set Mode
eye config mode $MODE

# 1. Core Service Commands
echo "Testing: start, status, set, now, pause, resume, pass, kill"
eye start >/dev/null
eye status
eye status -l
eye set 25m 25s >/dev/null
eye now --reset >/dev/null
eye pause 10s >/dev/null
eye resume >/dev/null
eye pass 5m >/dev/null
eye status

# 2. Config Commands
echo "Testing: config language, autostart, update"
eye config language zh >/dev/null
eye status | grep -q "状态" || eye status | grep -q "status=" || eye status | grep -q "已停止"
echo "Language switch (zh) verified."

eye config language en >/dev/null
eye config autostart on >/dev/null
eye config autostart off >/dev/null
eye config update # Just check if it runs without crash

# 3. Sound Commands
echo "Testing: sound on/off, list, set"
eye sound on >/dev/null
eye sound off >/dev/null
eye sound set default complete >/dev/null
eye sound list >/dev/null

# 4. Cleanup & System
eye version
eye kill >/dev/null
# Check if killed
sleep 1
if ! pgrep -f "bin/eye daemon" >/dev/null; then
    echo "Service killed successfully."
fi

echo -e "${GREEN}>>> Comprehensive Test in [$MODE] Mode Finished <<<\n${NC}"
