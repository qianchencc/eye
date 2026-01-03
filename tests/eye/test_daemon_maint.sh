#!/bin/bash
# tests/eye/test_daemon_maint.sh
# 彻底隔离环境，禁止任何真实 Git 操作
set -e
EYE="./bin/eye"

# 创建 Mock Git 目录
MOCK_BIN="/tmp/eye_mock_bin"
mkdir -p "$MOCK_BIN"

# Mock git: 无论调用什么都返回成功，防止触发网络
cat > "$MOCK_BIN/git" <<'EOF'
#!/bin/bash
echo "MOCK GIT: $*"
exit 0
EOF
chmod +x "$MOCK_BIN/git"

# Mock curl: 模拟版本号返回
cat > "$MOCK_BIN/curl" <<'EOF'
#!/bin/bash
echo 'EYE_VERSION="0.9.9"'
EOF
chmod +x "$MOCK_BIN/curl"

echo "--- Testing: eye daemon update (Isolated) ---"
# 通过修改 PATH 强制使用 Mock 工具
PATH="$MOCK_BIN:$PATH" $EYE daemon update

echo "--- Testing: eye daemon uninstall (Isolated) ---"
# 仅验证卸载逻辑流程
make dev >/dev/null 2>&1
PATH="$MOCK_BIN:$PATH" $EYE daemon uninstall

# 清理 Mock
rm -rf "$MOCK_BIN"
echo "PASS: Maintenance commands (Isolated)"