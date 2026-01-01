# 定义安装路径
PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
LIB_DIR = $(PREFIX)/lib/eye
SHARE_DIR = $(PREFIX)/share/eye
CONF_DIR = $(HOME)/.config/eye
# Bash completion usually goes to XDG_DATA_HOME/bash-completion/completions or /etc/bash_completion.d
# But for user-local install, let's stick to what we had or improve it.
# The original Makefile put it in CONF_DIR? That's weird.
# Standard user path: ~/.local/share/bash-completion/completions
# We'll use a variable for it.
COMP_DIR = $(HOME)/.local/share/bash-completion/completions

# 默认动作
all:
	@echo "Run 'make install' to install, or 'make dev' for development setup."

# 检查依赖
check:
	@echo "Checking dependencies..."
	@if ! command -v notify-send >/dev/null 2>&1; then echo "❌ Missing: notify-send (libnotify)"; exit 1; fi
	@if ! command -v paplay >/dev/null 2>&1; then echo "❌ Missing: paplay (pulseaudio-utils)"; exit 1; fi
	@echo "✅ Dependencies satisfied."

# 【生产环境安装】
install: check
	@echo "Installing to $(PREFIX)..."
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(LIB_DIR)
	@mkdir -p $(SHARE_DIR)
	@mkdir -p $(CONF_DIR)
	@mkdir -p $(COMP_DIR)
	
	@cp bin/eye $(BIN_DIR)/eye
	@chmod +x $(BIN_DIR)/eye
	@cp lib/*.sh $(LIB_DIR)/
	# Copy assets if they exist (ignore error if assets dir is empty/missing, though we expect it)
	@if [ -d assets ]; then cp -r assets/* $(SHARE_DIR)/ 2>/dev/null || true; fi
	
	@cp completions/eye.bash $(COMP_DIR)/eye
	@echo "✅ Installation complete!"
	@echo "   Run 'eye help' to get started."

# 【开发环境安装】
dev:
	@echo "Setting up development environment..."
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(CONF_DIR)
	@mkdir -p $(COMP_DIR)
	
	@ln -sf $(PWD)/bin/eye $(BIN_DIR)/eye
	@ln -sf $(PWD)/completions/eye.bash $(COMP_DIR)/eye
	@chmod +x bin/eye
	@echo "🔗 Development links created!"

# 卸载
uninstall:
	@rm -f $(BIN_DIR)/eye
	@rm -rf $(LIB_DIR)
	@rm -rf $(SHARE_DIR)
	@rm -f $(COMP_DIR)/eye
	@echo "🗑️ Uninstalled"

.PHONY: all check install dev uninstall
