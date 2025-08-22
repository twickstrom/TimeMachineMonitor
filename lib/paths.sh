#!/usr/bin/env bash
# lib/paths.sh - Centralized path management for tm-monitor

# Prevent multiple sourcing
[[ -n "${_PATHS_SOURCED:-}" ]] && return 0
export _PATHS_SOURCED=1

# Determine installation mode and set paths
determine_paths() {
    local script_path="${1:-${BASH_SOURCE[0]}}"
    local script_dir
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    
    # Check if running from source (development mode)
    if [[ -d "$script_dir/../lib" ]]; then
        # Development mode - running from source
        export TM_DEV_MODE=true
        export TM_BASE_DIR="$(cd "$script_dir/.." && pwd)"
        export TM_LIB_DIR="$TM_BASE_DIR/lib"
        export TM_BIN_DIR="$TM_BASE_DIR/bin"
        export TM_CONFIG_DIR="$TM_BASE_DIR/config"
        export TM_DATA_DIR="$TM_BASE_DIR/data"
    else
        # Installed mode
        export TM_DEV_MODE=false
        export TM_LIB_DIR="${LIB_DIR:-$HOME/.local/lib/tm-monitor}"
        export TM_BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
        export TM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tm-monitor"
        export TM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tm-monitor"
    fi
    
    # Common paths (regardless of mode)
    export TM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tm-monitor"
    export TM_LOG_DIR="$TM_DATA_DIR/logs"
    export TM_RUN_DIR="$TM_DATA_DIR/run"
    
    # File paths
    export TM_CONFIG_FILE="$TM_CONFIG_DIR/config.conf"
    export TM_PID_FILE="$TM_RUN_DIR/monitor.pid"
    export TM_HELPER_PIPE="$TM_CACHE_DIR/helper.pipe"
    
    # Helper script path
    if [[ "$TM_DEV_MODE" == "true" ]]; then
        export TM_HELPER_SCRIPT="$TM_BIN_DIR/tm-monitor-helper.py"
    else
        export TM_HELPER_SCRIPT="$TM_LIB_DIR/tm-monitor-helper.py"
    fi
}

# Create necessary directories
ensure_directories() {
    local dirs=(
        "$TM_CONFIG_DIR"
        "$TM_DATA_DIR"
        "$TM_CACHE_DIR"
        "$TM_LOG_DIR"
        "$TM_RUN_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                echo "Failed to create directory: $dir" >&2
                return 1
            }
        fi
    done
    
    return 0
}

# Get absolute path
get_absolute_path() {
    local path="$1"
    
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    else
        echo "$path"
    fi
}

# Check if running in development mode
is_dev_mode() {
    [[ "${TM_DEV_MODE:-false}" == "true" ]]
}

# Initialize paths when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    determine_paths "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
fi

# Export functions
export -f determine_paths ensure_directories get_absolute_path is_dev_mode
