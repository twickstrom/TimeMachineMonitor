#!/usr/bin/env bash
# QUICK_START.sh - One-command setup for tm-monitor

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BLUE}     TM-Monitor Quick Start${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

# Check if on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}✗ This application requires macOS${RESET}"
    exit 1
fi

# Check macOS version
macos_version=$(sw_vers -productVersion 2>/dev/null)
major="${macos_version%%.*}"
if [[ "$major" -lt 14 ]]; then
    echo -e "${RED}✗ macOS 14 (Sonoma) or later required (found: $macos_version)${RESET}"
    exit 1
fi
echo -e "${GREEN}✓ macOS $macos_version detected${RESET}"

# Check for Time Machine
if ! command -v tmutil >/dev/null 2>&1; then
    echo -e "${RED}✗ Time Machine (tmutil) not found${RESET}"
    exit 1
fi
echo -e "${GREEN}✓ Time Machine found${RESET}"

# Check Python
if command -v python3 >/dev/null 2>&1; then
    py_version=$(python3 --version 2>&1)
    echo -e "${GREEN}✓ $py_version found${RESET}"
else
    echo -e "${YELLOW}⚠ Python 3 not found - some features will be limited${RESET}"
fi

echo
echo -e "${BLUE}Installing tm-monitor...${RESET}"
echo

# Run installer
if ./install.sh; then
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}     Installation successful!${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    # Check if PATH needs updating
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "${YELLOW}⚠ Add this to your shell configuration:${RESET}"
        echo
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        echo "Then reload your shell or run: source ~/.bashrc (or ~/.zshrc)"
        echo
    fi
    
    echo "Quick commands:"
    echo "  ${GREEN}tm-dashboard${RESET}         # Launch split-screen dashboard (recommended)"
    echo "  tm-monitor --version     # Check version"
    echo "  tm-monitor --help        # Show help"
    echo "  tm-monitor               # Start monitoring (single window)"
    echo
    echo -e "${BLUE}To get started, run: ${GREEN}tm-dashboard${RESET}"
    echo
    echo -e "${BLUE}Enjoy monitoring your Time Machine backups!${RESET}"
else
    echo -e "${RED}✗ Installation failed${RESET}"
    echo "Please check the error messages above"
    exit 1
fi
