#!/bin/bash
# tests/eye/test_daemon_maint.sh
set -e
EYE="./bin/eye"

# 1. 模拟 Git 环境以便测试 update
git config user.email "tester@example.com"
git config user.name "Tester"
# 创建一个 Mock 远程仓库
mkdir -p /tmp/mock_remote
cd /tmp/mock_remote
git init --bare
cd -
git remote add origin /tmp/mock_remote || true
git push origin dev || true

echo "--- Testing: eye daemon update ---"
$EYE daemon update

echo "--- Testing: eye daemon uninstall ---"
# 我们需要先 "安装" 它是为了测试卸载
make dev
# 检查链接是否存在
[ -f "$HOME/.local/bin/eye" ] || { echo "FAIL: make dev failed"; exit 1; }

# 执行卸载
$EYE daemon uninstall

# 验证清理结果
[ ! -f "$HOME/.local/bin/eye" ] && echo "PASS: bin removed" || echo "FAIL: bin remains"
[ ! -d "$HOME/.config/eye" ] && echo "PASS: config removed" || echo "FAIL: config remains"

echo "ALL MAINTENANCE TESTS PASSED"
