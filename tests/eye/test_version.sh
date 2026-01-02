#!/bin/bash
# tests/eye/test_version.sh
EYE="./bin/eye"
$EYE version | grep -q "eye version" && echo "PASS: version" || { echo "FAIL: version"; exit 1; }
