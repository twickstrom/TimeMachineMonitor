# Makefile for tm-monitor
# A professional Time Machine backup monitoring tool for macOS

# Version
VERSION := $(shell grep "TM_MONITOR_VERSION=" lib/version.sh | cut -d'"' -f2)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RESET := \033[0m

# Default installation prefix
PREFIX ?= $(HOME)/.local

# Directories
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/tm-monitor
CONFIGDIR := $(HOME)/.config/tm-monitor
DATADIR := $(HOME)/.local/share/tm-monitor
CACHEDIR := $(HOME)/.cache/tm-monitor

# Default target
.PHONY: all
all: help

# Help target with better formatting
.PHONY: help
help:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "$(BLUE)     TM-Monitor $(VERSION) - Makefile Targets$(RESET)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo ""
	@echo "$(GREEN)Installation:$(RESET)"
	@echo "  make install          Install to ~/.local (user)"
	@echo "  make install-system   Install system-wide (requires sudo)"
	@echo "  make dev              Development install (symlinks)"
	@echo "  make uninstall        Remove tm-monitor"
	@echo ""
	@echo "$(GREEN)Quick Start:$(RESET)"
	@echo "  make dashboard        Launch tm-dashboard after install check"
	@echo "  make run              Run tm-monitor directly"
	@echo ""
	@echo "$(GREEN)Development:$(RESET)"
	@echo "  make test             Run test suite"
	@echo "  make check            Check dependencies"
	@echo "  make lint             Run shellcheck on scripts"
	@echo "  make format           Format Python code"
	@echo "  make clean            Remove temporary files"
	@echo ""
	@echo "$(GREEN)Information:$(RESET)"
	@echo "  make version          Show version"
	@echo "  make stats            Show code statistics"
	@echo ""
	@echo "$(YELLOW)Options:$(RESET)"
	@echo "  PREFIX=/opt/tm-monitor   Custom installation prefix"
	@echo ""
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make install PREFIX=/opt/tm-monitor"
	@echo "  sudo make install-system"
	@echo "  make dev && make dashboard"

# Install to user directory
.PHONY: install
install:
	@echo "$(BLUE)Installing tm-monitor to $(PREFIX)...$(RESET)"
	@./install.sh $(if $(filter-out $(HOME)/.local,$(PREFIX)),--prefix $(PREFIX))
	@echo "$(GREEN)✓ Installation complete!$(RESET)"
	@echo "$(YELLOW)Run 'make dashboard' to launch the dashboard$(RESET)"

# System-wide installation
.PHONY: install-system
install-system:
	@echo "$(BLUE)Installing tm-monitor system-wide...$(RESET)"
	@sudo ./install.sh --system
	@echo "$(GREEN)✓ System installation complete!$(RESET)"

# Development installation
.PHONY: dev
dev:
	@echo "$(BLUE)Creating development installation...$(RESET)"
	@./install.sh --dev
	@echo "$(GREEN)✓ Development setup complete!$(RESET)"

# Uninstall
.PHONY: uninstall
uninstall:
	@echo "$(BLUE)Uninstalling tm-monitor...$(RESET)"
	@./uninstall.sh

# Quick start - launch dashboard
.PHONY: dashboard
dashboard:
	@if [ ! -f "$(BINDIR)/tm-dashboard" ]; then \
		echo "$(YELLOW)tm-dashboard not found, installing first...$(RESET)"; \
		$(MAKE) install; \
	fi
	@echo "$(BLUE)Launching tm-dashboard...$(RESET)"
	@$(BINDIR)/tm-dashboard

# Run tm-monitor directly
.PHONY: run
run:
	@if [ ! -x "bin/tm-monitor" ]; then \
		echo "$(RED)Error: bin/tm-monitor not found or not executable$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running tm-monitor...$(RESET)"
	@./bin/tm-monitor

# Clean temporary files
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning temporary files...$(RESET)"
	@rm -f data/logs/*.log data/logs/*.csv 2>/dev/null || true
	@rm -f data/run/*.pid 2>/dev/null || true
	@rm -f data/*.db-wal data/*.db-shm 2>/dev/null || true
	@rm -f tests/*.out tests/*.err tests/*.log 2>/dev/null || true
	@find . -name "*.bak" -delete 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete$(RESET)"

# Run tests
.PHONY: test
test:
	@echo "$(BLUE)Running test suite...$(RESET)"
	@if [ -d "tests" ] && [ -f "tests/test_installation.sh" ]; then \
		cd tests && ./test_installation.sh; \
	else \
		echo "$(YELLOW)No tests found$(RESET)"; \
	fi

# Check dependencies
.PHONY: check
check:
	@echo "$(BLUE)Checking dependencies...$(RESET)"
	@./install.sh --check-only

# Lint shell scripts with shellcheck
.PHONY: lint
lint:
	@echo "$(BLUE)Running shellcheck...$(RESET)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck bin/tm-monitor bin/tm-monitor-resources bin/tm-monitor-stats bin/tm-dashboard || true; \
		shellcheck lib/*.sh || true; \
		echo "$(GREEN)✓ Lint complete$(RESET)"; \
	else \
		echo "$(YELLOW)shellcheck not installed - install with: brew install shellcheck$(RESET)"; \
	fi

# Format Python code
.PHONY: format
format:
	@echo "$(BLUE)Formatting Python code...$(RESET)"
	@if command -v black >/dev/null 2>&1; then \
		black bin/tm-monitor-helper.py; \
		echo "$(GREEN)✓ Format complete$(RESET)"; \
	elif command -v autopep8 >/dev/null 2>&1; then \
		autopep8 --in-place --aggressive bin/tm-monitor-helper.py; \
		echo "$(GREEN)✓ Format complete$(RESET)"; \
	else \
		echo "$(YELLOW)No Python formatter found$(RESET)"; \
		echo "Install with: pip3 install black"; \
	fi

# Show version
.PHONY: version
version:
	@echo "$(BLUE)TM-Monitor Version:$(RESET) $(VERSION)"
	@echo "$(BLUE)Build Date:$(RESET) $(shell grep "TM_MONITOR_BUILD_DATE=" lib/version.sh | cut -d'"' -f2)"

# Show code statistics
.PHONY: stats
stats:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "$(BLUE)     TM-Monitor Code Statistics$(RESET)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo ""
	@echo "$(GREEN)Shell Scripts:$(RESET)"
	@wc -l bin/tm-monitor bin/tm-monitor-resources bin/tm-monitor-stats bin/tm-dashboard 2>/dev/null | tail -1 | awk '{printf "  Binaries:     %5d lines\n", $$1}'
	@wc -l lib/*.sh 2>/dev/null | tail -1 | awk '{printf "  Libraries:    %5d lines\n", $$1}'
	@echo ""
	@echo "$(GREEN)Python:$(RESET)"
	@wc -l bin/tm-monitor-helper.py 2>/dev/null | awk '{printf "  Helper:       %5d lines\n", $$1}'
	@echo ""
	@echo "$(GREEN)Files:$(RESET)"
	@echo "  Shell files:    $$(find . -name "*.sh" -o -name "tm-monitor*" | grep -v ".git" | wc -l | tr -d ' ')"
	@echo "  Library modules: $$(ls -1 lib/*.sh 2>/dev/null | wc -l | tr -d ' ')"
	@echo "  Total size:      $$(du -sh . 2>/dev/null | cut -f1)"

# Create distribution tarball
.PHONY: dist
dist: clean
	@echo "$(BLUE)Creating distribution tarball...$(RESET)"
	@mkdir -p dist
	@tar -czf dist/tm-monitor-$(VERSION).tar.gz \
		--exclude='.git' \
		--exclude='dist' \
		--exclude='.internal' \
		--exclude='data/logs/*' \
		--exclude='data/run/*' \
		--exclude='data/*.db*' \
		--exclude='*.bak' \
		--exclude='.DS_Store' \
		.
	@echo "$(GREEN)✓ Created dist/tm-monitor-$(VERSION).tar.gz$(RESET)"

# Quick install and run
.PHONY: quick
quick: install dashboard

# Reinstall (uninstall then install)
.PHONY: reinstall
reinstall: uninstall install
	@echo "$(GREEN)✓ Reinstall complete$(RESET)"

# Check for updates (placeholder for future implementation)
.PHONY: update
update:
	@echo "$(YELLOW)Update checking not yet implemented$(RESET)"
	@echo "Visit: https://github.com/twickstrom/TimeMachineMonitor/releases"

# Development watch mode (if entr is installed)
.PHONY: watch
watch:
	@if command -v entr >/dev/null 2>&1; then \
		echo "$(BLUE)Watching for changes...$(RESET)"; \
		find . -name "*.sh" -o -name "*.py" | entr -c make test; \
	else \
		echo "$(YELLOW)entr not installed - install with: brew install entr$(RESET)"; \
	fi

.PHONY: validate
validate: check lint test
	@echo "$(GREEN)✓ All validations passed$(RESET)"
