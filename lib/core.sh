#!/usr/bin/env bash
# lib/core.sh - Core initialization for all tm-monitor scripts
#
# This module provides centralized initialization for all tm-monitor scripts,
# eliminating duplicate bootstrapping and library sourcing code.

# Prevent multiple sourcing
[[ -n "${_CORE_SOURCED:-}" ]] && return 0
export _CORE_SOURCED=1

# Core initialization function for all tm-monitor scripts
# Usage: tm_monitor_init [script_path] [lib_selection]
# lib_selection: "minimal", "standard", "full" (default: "standard")
tm_monitor_init() {
    local script_path="${1:-${BASH_SOURCE[1]}}"
    local lib_selection="${2:-standard}"
    
    # Get the directory of the calling script
    local script_dir
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    
    # Bootstrap paths.sh first
    local paths_lib
    if [[ -d "$script_dir/../lib" ]]; then
        paths_lib="$script_dir/../lib/paths.sh"
    else
        paths_lib="${LIB_DIR:-$HOME/.local/lib/tm-monitor}/paths.sh"
    fi
    
    # Source paths.sh and initialize paths
    source "$paths_lib"
    determine_paths "$script_path"
    
    # Export commonly used paths
    export LIB_DIR="$TM_LIB_DIR"
    export HELPER_SCRIPT="$TM_HELPER_SCRIPT"
    
    # Source libraries based on selection
    case "$lib_selection" in
        minimal)
            # Minimal set for simple scripts
            source "$TM_LIB_DIR/version.sh"
            source "$TM_LIB_DIR/colors.sh"
            source "$TM_LIB_DIR/formatting.sh"
            source "$TM_LIB_DIR/logger.sh"
            ;;
            
        full)
            # Everything - for resource monitor
            _source_standard_libs
            source "$TM_LIB_DIR/system_info.sh"
            source "$TM_LIB_DIR/process_management.sh"
            source "$TM_LIB_DIR/resource_helpers.sh"
            ;;
            
        standard|*)
            # Standard set for tm-monitor
            _source_standard_libs
            ;;
    esac
    
    # Common initialization tasks
    load_config
    ensure_directories
    
    # Initialize colors based on config
    init_colors "${SHOW_COLORS:-true}"
    
    # Set common environment
    export LC_ALL=en_US.UTF-8
    
    # Return success
    return 0
}

# Internal function to source standard libraries
_source_standard_libs() {
    # Core libraries in dependency order
    source "$TM_LIB_DIR/version.sh"       # Version management
    source "$TM_LIB_DIR/colors.sh"        # Color definitions
    source "$TM_LIB_DIR/terminal.sh"      # Terminal management
    source "$TM_LIB_DIR/python_check.sh"  # Python detection
    source "$TM_LIB_DIR/dependencies.sh"  # Dependency checking
    source "$TM_LIB_DIR/constants.sh"     # Constants and defaults
    source "$TM_LIB_DIR/formatting.sh"    # Formatting functions
    source "$TM_LIB_DIR/logger.sh"        # Logging functionality
    source "$TM_LIB_DIR/config.sh"        # Configuration loading
    source "$TM_LIB_DIR/tmutil.sh"        # Time Machine utilities
    source "$TM_LIB_DIR/state.sh"         # State management
    source "$TM_LIB_DIR/process.sh"       # Process management
    source "$TM_LIB_DIR/display.sh"       # Display functions
}

# Common argument parsing for all scripts
# Usage: parse_common_args "$@"
# Sets global variables based on common arguments
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                get_version_info
                exit 0
                ;;
            -h|--help)
                # Let the calling script handle help
                return 1
                ;;
            -c|--no-colors)
                export TM_SHOW_COLORS="false"
                export SHOW_COLORS="false"
                export USE_COLORS="false"
                shift
                ;;
            -d|--debug)
                export TM_DEBUG="true"
                export DEBUG="true"
                shift
                ;;
            -i|--interval)
                if [[ $# -lt 2 ]]; then
                    error "Missing value for $1"
                    exit 1
                fi
                export TM_INTERVAL="$2"
                export INTERVAL="$2"
                shift 2
                ;;
            *)
                # Unknown argument, let calling script handle
                return 2
                ;;
        esac
    done
    return 0
}

# Setup common signal handlers
# Usage: setup_common_handlers [cleanup_function]
setup_common_handlers() {
    local cleanup_func="${1:-cleanup_and_exit}"
    
    # Set up signal handlers
    trap "$cleanup_func" INT TERM QUIT EXIT
    
    # Disable echo of control characters if terminal
    if [[ -t 0 ]]; then
        stty -echoctl 2>/dev/null || true
    fi
}

# Common cleanup function
# Can be overridden by scripts that source this
common_cleanup() {
    local exit_code="${1:-0}"
    
    # Clear current line
    printf "\r\033[K"
    
    # Stop helper process if running
    [[ -n "${HELPER_PID:-}" ]] && stop_helper_process
    
    # Remove PID file if exists
    [[ -f "${TM_PID_FILE:-}" ]] && rm -f "$TM_PID_FILE"
    
    # Clean up pipes
    [[ -d "${TM_CACHE_DIR:-}" ]] && rm -f "$TM_CACHE_DIR"/helper.{in,out} 2>/dev/null
    
    # Restore terminal settings
    [[ -n "${ORIGINAL_STTY:-}" ]] && stty "$ORIGINAL_STTY" 2>/dev/null || true
    
    exit "$exit_code"
}

# Export functions
export -f tm_monitor_init parse_common_args setup_common_handlers common_cleanup
