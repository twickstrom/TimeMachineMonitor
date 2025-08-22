#!/usr/bin/env bash
# lib/version.sh - Version management for tm-monitor

# Prevent multiple sourcing
[[ -n "${_VERSION_SOURCED:-}" ]] && return 0
export _VERSION_SOURCED=1

# Version information
readonly TM_MONITOR_VERSION="0.9.1"
readonly TM_MONITOR_BUILD_DATE="2025-01-01"
readonly TM_MONITOR_MIN_MACOS="14"
readonly TM_MONITOR_MIN_PYTHON="3.8"

# Get version string
get_version() {
    echo "${TM_MONITOR_VERSION}"
}

# Get full version info
get_version_info() {
    cat <<EOF
tm-monitor version ${TM_MONITOR_VERSION}
Build date: ${TM_MONITOR_BUILD_DATE}
Minimum macOS: ${TM_MONITOR_MIN_MACOS}
Minimum Python: ${TM_MONITOR_MIN_PYTHON}
EOF
}

# Compare versions (returns 0 if v1 >= v2)
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # Split versions into components
    local -a v1_parts=(${v1//./ })
    local -a v2_parts=(${v2//./ })
    
    # Pad arrays to same length
    local max_parts=$((${#v1_parts[@]} > ${#v2_parts[@]} ? ${#v1_parts[@]} : ${#v2_parts[@]}))
    
    for ((i=0; i<max_parts; i++)); do
        local p1="${v1_parts[i]:-0}"
        local p2="${v2_parts[i]:-0}"
        
        if [[ "$p1" -gt "$p2" ]]; then
            return 0
        elif [[ "$p1" -lt "$p2" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Check for updates (placeholder for future implementation)
check_for_updates() {
    local current="${TM_MONITOR_VERSION}"
    local check_url="${1:-https://api.github.com/repos/yourusername/tm-monitor/releases/latest}"
    
    # This is a placeholder - would need actual implementation
    echo "Update checking not yet implemented"
    return 1
}

# Get changelog for version
get_changelog() {
    local version="${1:-$TM_MONITOR_VERSION}"
    local changelog_file="${TM_BASE_DIR:-$(dirname "${BASH_SOURCE[0]}")/..}/CHANGELOG.md"
    
    if [[ -f "$changelog_file" ]]; then
        # Extract section for specific version
        awk "/^## \\[$version\\]/,/^## \\[/" "$changelog_file" | head -n -1
    else
        echo "Changelog not found"
    fi
}

# Export functions
export -f get_version get_version_info version_compare check_for_updates get_changelog
