#!/usr/bin/env bash
# install.sh - Enhanced installation script for tm-monitor

set -euo pipefail

# Script version
readonly INSTALLER_VERSION="2.0.0"

# Source colors module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/colors.sh" ]]; then
    source "$SCRIPT_DIR/lib/colors.sh"
else
    # Fallback if colors module not found
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly RESET='\033[0m'
fi

# Default installation prefix
PREFIX="${PREFIX:-$HOME/.local}"

# Installation paths
BINDIR=""
LIBDIR=""
CONFIGDIR=""
DATADIR=""
CACHEDIR=""

# Installation mode
INSTALL_MODE="user"  # user or system

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}     TM-Monitor Installation Script v${INSTALLER_VERSION}${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install tm-monitor Time Machine backup monitoring tool.

OPTIONS:
    --prefix PATH      Installation prefix (default: $HOME/.local)
    --system          Install system-wide (requires sudo)
    --dev              Development installation (symlinks)
    --uninstall       Remove tm-monitor
    --check-only      Only check dependencies, don't install
    --help            Show this help message

EXAMPLES:
    $0                           # User installation to ~/.local
    $0 --prefix /opt/tm-monitor  # Custom prefix
    $0 --system                  # System-wide installation
    $0 --dev                     # Development mode with symlinks
    $0 --uninstall               # Remove installation

EOF
    exit 0
}

error() {
    echo -e "${RED}✗ ERROR: $*${RESET}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $*${RESET}"
}

warning() {
    echo -e "${YELLOW}⚠ WARNING: $*${RESET}"
}

info() {
    echo -e "${BLUE}ℹ $*${RESET}"
}

# Check if running on macOS
check_os() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This application requires macOS"
    fi
    success "Operating system: macOS $(sw_vers -productVersion)"
}

# Check macOS version
check_macos_version() {
    local version
    version=$(sw_vers -productVersion 2>/dev/null)
    local major="${version%%.*}"
    
    if [[ "$major" -lt 14 ]]; then
        error "macOS 14 (Sonoma) or later required (found: $version)"
    fi
    success "macOS version: $version (meets requirement)"
}

# Find Python 3
find_python() {
    local python_cmd=""
    local candidates=("python3" "python3.12" "python3.11" "python3.10" "python3.9")
    
    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local version
            version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            
            if [[ -n "$version" ]]; then
                local major="${version%%.*}"
                local minor="${version#*.}"
                if [[ "$major" == "3" ]] && [[ "$minor" -ge 8 ]]; then
                    python_cmd="$cmd"
                    break
                fi
            fi
        fi
    done
    
    if [[ -z "$python_cmd" ]]; then
        error "Python 3.8 or later not found"
    fi
    
    PYTHON_CMD="$python_cmd"
    local full_version
    full_version=$("$python_cmd" --version 2>&1)
    success "Python: $full_version (using: $python_cmd)"
}

# Check all dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    check_os
    check_macos_version
    
    # Check required commands
    local -a required=(tmutil plutil)
    for cmd in "${required[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "Found: $cmd"
        else
            error "Required command not found: $cmd"
        fi
    done
    
    # Check Python
    find_python
    
    # Check optional commands
    local -a optional=(bc tput stty)
    for cmd in "${optional[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "Found: $cmd (optional)"
        else
            warning "$cmd not found (some features may be limited)"
        fi
    done
    
    echo
    success "All required dependencies satisfied"
}

# Set installation paths
set_paths() {
    if [[ "$INSTALL_MODE" == "system" ]]; then
        PREFIX="/usr/local"
        CONFIGDIR="/etc/tm-monitor"
        DATADIR="/var/lib/tm-monitor"
        CACHEDIR="/var/cache/tm-monitor"
    else
        PREFIX="${PREFIX:-$HOME/.local}"
        CONFIGDIR="${XDG_CONFIG_HOME:-$HOME/.config}/tm-monitor"
        DATADIR="${XDG_DATA_HOME:-$HOME/.local/share}/tm-monitor"
        CACHEDIR="${XDG_CACHE_HOME:-$HOME/.cache}/tm-monitor"
    fi
    
    BINDIR="$PREFIX/bin"
    LIBDIR="$PREFIX/lib/tm-monitor"
    
    info "Installation paths:"
    echo "  Prefix:    $PREFIX"
    echo "  Binaries:  $BINDIR"
    echo "  Libraries: $LIBDIR"
    echo "  Config:    $CONFIGDIR"
    echo "  Data:      $DATADIR"
    echo "  Cache:     $CACHEDIR"
    echo
}

# Create directories
create_directories() {
    info "Creating directories..."
    
    local -a dirs=(
        "$BINDIR"
        "$LIBDIR"
        "$CONFIGDIR"
        "$DATADIR/logs"
        "$DATADIR/run"
        "$CACHEDIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$INSTALL_MODE" == "system" ]]; then
                sudo mkdir -p "$dir"
            else
                mkdir -p "$dir"
            fi
            success "Created: $dir"
        else
            info "Exists: $dir"
        fi
    done
}

# Install files
install_files() {
    info "Installing files..."
    
    # Install binaries
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo cp bin/tm-monitor "$BINDIR/"
        sudo cp bin/tm-monitor-resources "$BINDIR/"
        sudo chmod +x "$BINDIR/tm-monitor" "$BINDIR/tm-monitor-resources"
    else
        cp bin/tm-monitor "$BINDIR/"
        cp bin/tm-monitor-resources "$BINDIR/"
        chmod +x "$BINDIR/tm-monitor" "$BINDIR/tm-monitor-resources"
    fi
    success "Installed: tm-monitor, tm-monitor-resources"
    
    # Install helper and libraries
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo cp bin/tm-monitor-helper.py "$LIBDIR/"
        sudo cp -r lib/* "$LIBDIR/"
        sudo chmod +x "$LIBDIR/tm-monitor-helper.py"
    else
        cp bin/tm-monitor-helper.py "$LIBDIR/"
        cp -r lib/* "$LIBDIR/"
        chmod +x "$LIBDIR/tm-monitor-helper.py"
    fi
    success "Installed: helper script and libraries"
    
    # Install config example
    if [[ ! -f "$CONFIGDIR/config.conf" ]]; then
        if [[ "$INSTALL_MODE" == "system" ]]; then
            sudo cp config/tm-monitor.conf.example "$CONFIGDIR/config.conf.example"
        else
            cp config/tm-monitor.conf.example "$CONFIGDIR/config.conf.example"
        fi
        success "Installed: config example"
    fi
    
    # Update Python shebang to use detected Python
    if [[ -n "${PYTHON_CMD:-}" ]] && [[ "$PYTHON_CMD" != "python3" ]]; then
        info "Updating Python interpreter to: $PYTHON_CMD"
        if [[ "$INSTALL_MODE" == "system" ]]; then
            sudo sed -i.bak "1s|.*|#!/usr/bin/env $PYTHON_CMD|" "$LIBDIR/tm-monitor-helper.py"
        else
            sed -i.bak "1s|.*|#!/usr/bin/env $PYTHON_CMD|" "$LIBDIR/tm-monitor-helper.py"
        fi
        rm -f "$LIBDIR/tm-monitor-helper.py.bak"
    fi
}

# Development installation with symlinks
install_dev() {
    info "Creating development symlinks..."
    
    create_directories
    
    # Create symlinks
    ln -sf "$(pwd)/bin/tm-monitor" "$BINDIR/tm-monitor"
    ln -sf "$(pwd)/bin/tm-monitor-resources" "$BINDIR/tm-monitor-resources"
    ln -sf "$(pwd)/bin/tm-monitor-helper.py" "$LIBDIR/tm-monitor-helper.py"
    
    for file in lib/*.sh; do
        ln -sf "$(pwd)/$file" "$LIBDIR/$(basename "$file")"
    done
    
    success "Development installation complete"
}

# Uninstall
uninstall() {
    info "Uninstalling tm-monitor..."
    
    set_paths
    
    # Confirm
    read -p "Remove all tm-monitor files? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled"
        exit 0
    fi
    
    # Remove files
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo rm -f "$BINDIR/tm-monitor" "$BINDIR/tm-monitor-resources"
        sudo rm -rf "$LIBDIR"
    else
        rm -f "$BINDIR/tm-monitor" "$BINDIR/tm-monitor-resources"
        rm -rf "$LIBDIR"
    fi
    
    # Ask about config/data
    read -p "Remove configuration and data files? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$INSTALL_MODE" == "system" ]]; then
            sudo rm -rf "$CONFIGDIR" "$DATADIR" "$CACHEDIR"
        else
            rm -rf "$CONFIGDIR" "$DATADIR" "$CACHEDIR"
        fi
        success "All files removed"
    else
        info "Configuration and data preserved"
    fi
    
    success "Uninstall complete"
}

# Check PATH
check_path() {
    if [[ ":$PATH:" != *":$BINDIR:"* ]]; then
        warning "$BINDIR is not in your PATH"
        echo
        echo "Add this line to your shell configuration file:"
        echo "  export PATH=\"$BINDIR:\$PATH\""
        echo
        echo "For bash: ~/.bash_profile or ~/.bashrc"
        echo "For zsh:  ~/.zshrc"
    else
        success "$BINDIR is in PATH"
    fi
}

# Main installation
main() {
    local check_only=false
    local dev_mode=false
    local do_uninstall=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                PREFIX="$2"
                shift 2
                ;;
            --system)
                INSTALL_MODE="system"
                shift
                ;;
            --dev)
                dev_mode=true
                shift
                ;;
            --uninstall)
                do_uninstall=true
                shift
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                error "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done
    
    print_header
    
    # Handle uninstall
    if [[ "$do_uninstall" == true ]]; then
        uninstall
        exit 0
    fi
    
    # Check dependencies
    check_dependencies
    
    if [[ "$check_only" == true ]]; then
        success "Dependency check complete"
        exit 0
    fi
    
    # Set paths and install
    set_paths
    
    if [[ "$dev_mode" == true ]]; then
        install_dev
    else
        create_directories
        install_files
    fi
    
    check_path
    
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}     Installation complete!${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo "Run 'tm-monitor --help' to get started"
    echo "Run 'tm-monitor --create-config' to create a configuration file"
    echo
    
    # Show quick test
    info "Quick test:"
    echo "  tm-monitor --version"
    echo "  tm-monitor --check-only"
}

# Run main
main "$@"
