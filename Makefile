# 定义安装路径
PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
CONF_DIR = $(HOME)/.config/eye
COMP_DIR = $(CONF_DIR)

# 默认动作
all:
	@echo "请运行 'make install' 进行安装，或 'make dev' 进行开发链接"

# 【生产环境安装】：直接复制文件 (稳定，互不影响)
install:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(CONF_DIR)
	@cp bin/eye $(BIN_DIR)/eye
	@chmod +x $(BIN_DIR)/eye
	@cp completions/eye.bash $(COMP_DIR)/completion.bash
	@echo "✅ 安装完成！"

# 【开发环境安装】：创建软链接 (修改源码立即生效)
dev:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(CONF_DIR)
	@ln -sf $(PWD)/bin/eye $(BIN_DIR)/eye
	@ln -sf $(PWD)/completions/eye.bash $(COMP_DIR)/completion.bash
	@chmod +x bin/eye
	@echo "🔗 开发链接已建立！你现在可以直接修改源码。"

# 卸载
uninstall:
	@rm -f $(BIN_DIR)/eye
	@echo "🗑️ 已卸载"

.PHONY: all install dev uninstall
