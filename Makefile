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

# 定义依赖包的名称 (Debian/Ubuntu)
DEPS = libnotify-bin pulseaudio-utils make sound-theme-freedesktop bash-completion

# 默认动作
all:
	@echo "Run 'make install' to install, or 'make dev' for development setup."

# 专门用来安装依赖的目标 (目前支持 apt)
install-deps:
	@echo "📦 Installing dependencies (requires sudo)..."
	@sudo apt-get update && sudo apt-get install -y $(DEPS)
	@echo "✅ Dependencies installation complete."

# 检查依赖 (仅提示)
check:
	@echo "🔍 Checking dependencies..."
	@MISSING=""; \
	command -v notify-send >/dev/null 2>&1 || MISSING="$$MISSING libnotify-bin"; \
	command -v paplay >/dev/null 2>&1 || MISSING="$$MISSING pulseaudio-utils"; \
	if [ -n "$$MISSING" ]; then \
		echo "⚠️  Missing dependencies:$$MISSING"; \
		echo "👉 Run 'make install-deps' (Debian/Ubuntu) or install them manually."; \
	else \
		echo "✅ All dependencies found."; \
	fi

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

# 全量卸载 (清理配置和状态)
purge:
	@if [ -f ./uninstall.sh ]; then \
		bash ./uninstall.sh --force; \
	else \
		rm -f $(BIN_DIR)/eye; \
		rm -rf $(LIB_DIR); \
		rm -rf $(SHARE_DIR); \
		rm -rf $(CONF_DIR); \
		rm -rf $(HOME)/.local/state/eye; \
		rm -f $(HOME)/.config/systemd/user/eye.service; \
		rm -f $(COMP_DIR)/eye; \
		echo "🧹 Purged manually (uninstall.sh missing)"; \
	fi

.PHONY: all check install dev uninstall purge
