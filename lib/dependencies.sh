#!/usr/bin/env bash
# lib/dependencies.sh - Centralized dependency checking for tm-monitor

# Prevent multiple sourcing
[[ -n "${_DEPENDENCIES_SOURCED:-}" ]] && return 0
export _DEPENDENCIES_SOURCED=1

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/python_check.sh"

# Initialize arrays with default values to avoid unbound variable errors
: ${REQUIRED_COMMANDS:=}
: ${OPTIONAL_COMMANDS:=}

# Required commands for tm-monitor  
REQUIRED_COMMANDS=(tmutil plutil)
OPTIONAL_COMMANDS=(bc tput stty)

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check macOS version
check_macos_version() {
    local min_version="${1:-14}"
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "This application requires macOS" >&2
        return 1
    fi
    
    # Get macOS version
    local version
    version=$(sw_vers -productVersion 2>/dev/null)
    
    if [[ -z "$version" ]]; then
        echo "Unable to determine macOS version" >&2
        return 1
    fi
    
    # Extract major version
    local major_version="${version%%.*}"
    
    if [[ "$major_version" -lt "$min_version" ]]; then
        echo "macOS $min_version or later required (found: $version)" >&2
        return 1
    fi
    
    return 0
}

# Check all dependencies
check_dependencies() {
    local verbose="${1:-false}"
    local errors=()
    local warnings=()
    local python_cmd
    
    # Check macOS version
    if ! check_macos_version 14; then
        errors+=("macOS 14 (Sonoma) or later required")
    fi
    
    # Check required commands
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command_exists "$cmd"; then
            errors+=("Required command not found: $cmd")
        elif [[ "$verbose" == "true" ]]; then
            echo "✓ Found: $cmd" >&2
        fi
    done
    
    # Check Python and export if found
    if ! python_cmd=$(find_python3); then
        errors+=("Python 3 not found (required for helper process)")
    else
        if ! check_python_version "$python_cmd" "3.8"; then
            errors+=("Python 3.8 or later required")
        else
            # Export for use by other scripts
            export TM_PYTHON_CMD="$python_cmd"
            if [[ "$verbose" == "true" ]]; then
                local py_info
                py_info=$(get_python_info "$python_cmd")
                echo "✓ Found: $py_info at $python_cmd" >&2
            fi
        fi
    fi
    
    # Check optional commands
    for cmd in "${OPTIONAL_COMMANDS[@]}"; do
        if ! command_exists "$cmd"; then
            warnings+=("Optional command not found: $cmd (some features may be limited)")
        elif [[ "$verbose" == "true" ]]; then
            echo "✓ Found: $cmd (optional)" >&2
        fi
    done
    
    # Report warnings
    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warning in "${warnings[@]:-}"; do
            echo "Warning: $warning" >&2
        done
    fi
    
    # Report errors and fail if any
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Dependency check failed:" >&2
        for error in "${errors[@]:-}"; do
            echo "  ✗ $error" >&2
        done
        return 1
    fi
    
    if [[ "$verbose" == "true" ]]; then
        echo "All dependencies satisfied" >&2
    fi
    
    return 0
}

# Get system information
get_system_info() {
    cat <<EOF
System Information:
  OS: $(uname -s) $(uname -r)
  macOS: $(sw_vers -productVersion 2>/dev/null || echo "Unknown")
  Architecture: $(uname -m)
  Python: $(get_python_info "${TM_PYTHON_CMD:-python3}")
  Bash: ${BASH_VERSION}
  Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
  Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1024/1024/1024}' || echo "Unknown")
EOF
}

# Export functions
export -f command_exists check_macos_version check_dependencies get_system_info
