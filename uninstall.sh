#!/usr/bin/env bash
# uninstall.sh - Uninstallation script for tm-monitor

set -euo pipefail

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

# Functions
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

# Detect installation
detect_installation() {
    local found=false
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}     TM-Monitor Uninstaller${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    
    info "Detecting tm-monitor installation..."
    echo
    
    # Check common locations
    local -a bin_locations=(
        "$HOME/.local/bin/tm-monitor"
        "/usr/local/bin/tm-monitor"
        "/opt/tm-monitor/bin/tm-monitor"
    )
    
    for location in "${bin_locations[@]}"; do
        if [[ -f "$location" ]]; then
            success "Found: $location"
            found=true
        fi
    done
    
    # Check library locations
    local -a lib_locations=(
        "$HOME/.local/lib/tm-monitor"
        "/usr/local/lib/tm-monitor"
        "/opt/tm-monitor/lib"
    )
    
    for location in "${lib_locations[@]}"; do
        if [[ -d "$location" ]]; then
            success "Found: $location"
            found=true
        fi
    done
    
    # Check config/data locations
    if [[ -d "$HOME/.config/tm-monitor" ]]; then
        success "Found config: $HOME/.config/tm-monitor"
        found=true
    fi
    
    if [[ -d "/etc/tm-monitor" ]]; then
        success "Found config: /etc/tm-monitor"
        found=true
    fi
    
    if [[ -d "$HOME/.local/share/tm-monitor" ]]; then
        success "Found data: $HOME/.local/share/tm-monitor"
        found=true
    fi
    
    if [[ -d "$HOME/.cache/tm-monitor" ]]; then
        success "Found cache: $HOME/.cache/tm-monitor"
        found=true
    fi
    
    if [[ "$found" == false ]]; then
        warning "No tm-monitor installation found"
        exit 0
    fi
    
    echo
}

# Remove files
remove_files() {
    info "The following will be removed:"
    echo
    
    # List files to remove
    local -a to_remove=()
    
    # Binaries
    for bin in tm-monitor tm-monitor-resources tm-monitor-stats tm-dashboard; do
        for prefix in "$HOME/.local" "/usr/local" "/opt/tm-monitor"; do
            local file="$prefix/bin/$bin"
            [[ -f "$file" ]] && to_remove+=("$file")
        done
    done
    
    # Libraries
    for prefix in "$HOME/.local" "/usr/local" "/opt/tm-monitor"; do
        local dir="$prefix/lib/tm-monitor"
        [[ -d "$dir" ]] && to_remove+=("$dir")
    done
    
    # Show what will be removed
    for item in "${to_remove[@]}"; do
        echo "  - $item"
    done
    
    echo
    read -p "Remove these files? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled"
        exit 0
    fi
    
    # Remove files
    for item in "${to_remove[@]}"; do
        if [[ -w "$item" ]] || [[ -w "$(dirname "$item")" ]]; then
            rm -rf "$item"
            success "Removed: $item"
        else
            if sudo rm -rf "$item" 2>/dev/null; then
                success "Removed (sudo): $item"
            else
                warning "Could not remove: $item"
            fi
        fi
    done
}

# Remove config and data
remove_config_data() {
    echo
    info "Configuration and data files:"
    echo
    
    local -a config_data=()
    
    # Config directories
    [[ -d "$HOME/.config/tm-monitor" ]] && config_data+=("$HOME/.config/tm-monitor")
    [[ -d "/etc/tm-monitor" ]] && config_data+=("/etc/tm-monitor")
    
    # Data directories
    [[ -d "$HOME/.local/share/tm-monitor" ]] && config_data+=("$HOME/.local/share/tm-monitor")
    [[ -d "/var/lib/tm-monitor" ]] && config_data+=("/var/lib/tm-monitor")
    
    # Cache directories
    [[ -d "$HOME/.cache/tm-monitor" ]] && config_data+=("$HOME/.cache/tm-monitor")
    [[ -d "/var/cache/tm-monitor" ]] && config_data+=("/var/cache/tm-monitor")
    
    if [[ ${#config_data[@]} -eq 0 ]]; then
        info "No configuration or data files found"
        return
    fi
    
    for item in "${config_data[@]}"; do
        echo "  - $item"
    done
    
    echo
    warning "This includes logs, configuration, and cached data"
    read -p "Remove configuration and data files? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Configuration and data preserved"
        return
    fi
    
    # Remove config/data
    for item in "${config_data[@]}"; do
        if [[ -w "$item" ]] || [[ -w "$(dirname "$item")" ]]; then
            rm -rf "$item"
            success "Removed: $item"
        else
            if sudo rm -rf "$item" 2>/dev/null; then
                success "Removed (sudo): $item"
            else
                warning "Could not remove: $item"
            fi
        fi
    done
}

# Kill running processes
kill_processes() {
    info "Checking for running tm-monitor processes..."
    
    # Use ps and grep instead of pgrep for better compatibility
    local procs
    procs=$(ps aux | grep -E "[t]m-monitor|tm-monitor-helper" | grep -v "uninstall.sh" || true)
    
    if [[ -n "$procs" ]]; then
        warning "Found running processes:"
        echo "$procs"
        echo
        read -p "Terminate these processes? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Extract PIDs and kill
            local pids
            pids=$(echo "$procs" | awk '{print $2}')
            for pid in $pids; do
                if kill "$pid" 2>/dev/null; then
                    success "Terminated process $pid"
                fi
            done
            
            sleep 1
            
            # Force kill if still running
            procs=$(ps aux | grep -E "[t]m-monitor|tm-monitor-helper" | grep -v "uninstall.sh" || true)
            if [[ -n "$procs" ]]; then
                pids=$(echo "$procs" | awk '{print $2}')
                for pid in $pids; do
                    if kill -9 "$pid" 2>/dev/null; then
                        success "Force killed process $pid"
                    fi
                done
            fi
        fi
    else
        success "No running processes found"
    fi
}

# Main
main() {
    detect_installation
    kill_processes
    echo
    remove_files
    remove_config_data
    
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}     Uninstall complete${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    info "tm-monitor has been removed from your system"
    info "To reinstall, run: ./install.sh"
}

# Run main
main "$@"
