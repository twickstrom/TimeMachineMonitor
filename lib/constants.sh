#!/usr/bin/env bash
# lib/constants.sh - Constants and default values for tm-monitor

# Prevent multiple sourcing
[[ -n "${_CONSTANTS_SOURCED:-}" ]] && return 0
export _CONSTANTS_SOURCED=1

# Source required modules first (if not already loaded)
[[ -z "$(type -t get_version)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
[[ -z "$(type -t determine_paths)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
[[ -z "$(type -t init_colors)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Application identification
readonly TM_MONITOR_NAME="tm-monitor"

# Default configuration values
readonly DEFAULT_INTERVAL=2
readonly DEFAULT_UNITS=1000
readonly DEFAULT_SHOW_COLORS=true
readonly DEFAULT_SHOW_SUMMARY=true
readonly DEFAULT_DEBUG=false
readonly DEFAULT_CSV_LOG=false
readonly DEFAULT_MAX_FAILURES=3
readonly DEFAULT_SPEED_WINDOW=30  # seconds for speed smoothing
readonly DEFAULT_INITIAL_BACKUP_WINDOW=90  # seconds for initial backup smoothing

# Box drawing characters (UTF-8)
readonly BOX_TOP_LEFT="┌"
readonly BOX_TOP_RIGHT="┐"
readonly BOX_TOP_MIDDLE="┬"
readonly BOX_MIDDLE_LEFT="├"
readonly BOX_MIDDLE_RIGHT="┤"
readonly BOX_MIDDLE="┼"
readonly BOX_BOTTOM_LEFT="└"
readonly BOX_BOTTOM_RIGHT="┘"
readonly BOX_BOTTOM_MIDDLE="┴"
readonly BOX_HORIZONTAL="─"
readonly BOX_VERTICAL="│"

# Status indicators (emoji)
readonly STATUS_ACTIVE="🟢"
readonly STATUS_MAINTENANCE="🟡"
readonly STATUS_SYSTEM="🔵"
readonly STATUS_IDLE="⚪"

# Initialize TABLE_COLUMNS to avoid unbound variable
: ${TABLE_COLUMNS:=}

# Table column definitions
# Format: "header:width:alignment"
TABLE_COLUMNS=(
    "Time:8:left"
    "Phase:32:left"
    "Speed:12:right"
    "Files/s:9:right"
    "Copied/Batch:24:right"
    "% Batch:10:right"
    "Copied/Total:24:right"
    "% Complete:10:right"
    "ETA:10:right"
)

# Speed thresholds (MB/s)
readonly SPEED_THRESHOLD_HIGH=10
readonly SPEED_THRESHOLD_LOW=1

# Function to calculate minimum terminal width from table definition
calculate_minimum_width() {
    local total_width=0
    local width

    if [[ ${#TABLE_COLUMNS[@]} -gt 0 ]]; then
        for column in "${TABLE_COLUMNS[@]}"; do
            # Extract width from format "header:width:alignment"
            width="${column#*:}"        # Remove header
            width="${width%%:*}"         # Remove alignment
            total_width=$((total_width + width + 2))  # +2 for padding
        done
    fi

    # Add border characters (number of columns + 1 for vertical separators)
    if [[ ${#TABLE_COLUMNS[@]} -gt 0 ]]; then
        total_width=$((total_width + ${#TABLE_COLUMNS[@]} + 1))
    else
        total_width=$((total_width + 1))
    fi

    echo "$total_width"
}

# Export function for use in other modules
export -f calculate_minimum_width
