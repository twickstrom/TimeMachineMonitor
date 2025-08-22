#!/usr/bin/env bash
# lib/python_check.sh - Python version detection and compatibility

# Find the best available Python 3 interpreter
find_python3() {
    local python_cmd=""
    
    # Try common Python 3 commands in order of preference
    # macOS 14+ should have python3 by default
    local -a candidates=("python3" "python3.12" "python3.11" "python3.10" "python3.9" "python")
    
    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            # Check if it's actually Python 3
            local version
            version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            
            if [[ -n "$version" ]]; then
                local major="${version%%.*}"
                if [[ "$major" == "3" ]]; then
                    python_cmd="$cmd"
                    break
                fi
            fi
        fi
    done
    
    if [[ -z "$python_cmd" ]]; then
        return 1
    fi
    
    echo "$python_cmd"
    return 0
}

# Check Python version meets minimum requirements
check_python_version() {
    local python_cmd="${1:-python3}"
    local min_version="${2:-3.8}"
    
    if ! command -v "$python_cmd" >/dev/null 2>&1; then
        return 1
    fi
    
    local version
    version=$("$python_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    
    if [[ -z "$version" ]]; then
        return 1
    fi
    
    # Compare versions
    local current_major="${version%%.*}"
    local current_minor="${version#*.}"
    local required_major="${min_version%%.*}"
    local required_minor="${min_version#*.}"
    
    if [[ "$current_major" -lt "$required_major" ]]; then
        return 1
    elif [[ "$current_major" -eq "$required_major" ]] && [[ "$current_minor" -lt "$required_minor" ]]; then
        return 1
    fi
    
    return 0
}

# Get Python version info (formatted string with "Python" prefix)
get_python_info() {
    local python_cmd="${1:-python3}"
    
    if ! command -v "$python_cmd" >/dev/null 2>&1; then
        echo "Not installed"
        return 1
    fi
    
    "$python_cmd" -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "Unknown version"
}

# Export functions
export -f find_python3 check_python_version get_python_info

# Export the best Python command if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Only export TM_PYTHON_CMD - it's what everything uses
    TM_PYTHON_CMD=$(find_python3)
    export TM_PYTHON_CMD
fi
