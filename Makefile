# Makefile for tm-monitor

.PHONY: all install uninstall dev clean test help check

# Default target
all: help

# Help target
help:
	@echo "TM-Monitor Makefile Targets:"
	@echo "  make install    - Install tm-monitor to ~/.local"
	@echo "  make uninstall  - Remove tm-monitor installation"
	@echo "  make dev        - Install with symlinks for development"
	@echo "  make clean      - Remove logs and temporary files"
	@echo "  make test       - Run installation tests"
	@echo "  make check      - Check dependencies only"
	@echo ""
	@echo "Installation options:"
	@echo "  make install PREFIX=/opt/tm-monitor  - Custom prefix"
	@echo "  sudo make install-system             - System-wide install"

# Install to user directory
install:
	@./install.sh $(if $(PREFIX),--prefix $(PREFIX))

# System-wide installation
install-system:
	@./install.sh --system

# Development installation
dev:
	@./install.sh --dev

# Uninstall
uninstall:
	@./uninstall.sh

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -f data/logs/*.log data/logs/*.csv
	@rm -f data/run/*.pid
	@rm -f tests/*.out tests/*.err tests/*.log
	@find . -name "*.bak" -delete
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete"

# Run tests
test:
	@echo "Running tests..."
	@cd tests && ./test_installation.sh

# Check dependencies
check:
	@./install.sh --check-only

# Show version
version:
	@./bin/tm-monitor --version
