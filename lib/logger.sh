#!/usr/bin/env bash
# lib/logger.sh - Logging functionality for tm-monitor

# Source dependencies if not already loaded
[[ -z "$(type -t get_version)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
[[ -z "$(type -t determine_paths)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
[[ -z "$(type -t init_colors)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"

# Log levels - use individual variables
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Current log level (will be set from config)
LOG_LEVEL="${LOG_LEVEL:-1}"  # Default to INFO

# Initialize logging
init_logging() {
    local debug="${1:-false}"
    local csv="${2:-false}"

    # Create log directories if needed
    mkdir -p "$TM_DATA_DIR/logs"

    # Set up log files with timestamps
    DEBUG_LOG_FILE="$TM_DATA_DIR/logs/debug-$(date +%Y%m%d_%H%M%S).log"
    CSV_LOG_FILE="$TM_DATA_DIR/logs/backup-$(date +%Y%m%d_%H%M%S).csv"

    if [[ "$debug" == "true" ]]; then
        LOG_LEVEL=$LOG_LEVEL_DEBUG
        echo "[$(date -Iseconds)] === TM-Monitor $(get_version) Debug Log ===" > "$DEBUG_LOG_FILE"
    fi

    if [[ "$csv" == "true" ]] && [[ ! -f "$CSV_LOG_FILE" ]]; then
        echo "timestamp,phase,speed_mbps,files_per_sec,percent_total,bytes_copied,total_bytes" > "$CSV_LOG_FILE"
    fi
}

# Convenience functions with color support
debug() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo "[DEBUG] $*" >&2
}

info() {
    echo "$*" >&2
}

warn() {
    if [[ "${SHOW_COLORS:-false}" == "true" ]]; then
        echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
    else
        echo "WARNING: $*" >&2
    fi
}

error() {
    if [[ "${SHOW_COLORS:-false}" == "true" ]]; then
        echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
    else
        echo "ERROR: $*" >&2
    fi
}

success() {
    if [[ "${SHOW_COLORS:-false}" == "true" ]]; then
        echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}" >&2
    else
        echo "✓ $*" >&2
    fi
}

fatal() {
    if [[ "${SHOW_COLORS:-false}" == "true" ]]; then
        echo -e "${COLOR_RED}FATAL: $*${COLOR_RESET}" >&2
    else
        echo "FATAL: $*" >&2
    fi
    exit 1
}

# CSV logging
log_csv() {
    [[ ! -w "${CSV_LOG_FILE:-}" ]] && return 0

    local timestamp="$1"
    local phase="$2"
    local speed="$3"
    local files_per_sec="$4"
    local pct_total="$5"
    local bytes="$6"
    local total="$7"

    # Extract and format numeric values with consistent precision
    speed="${speed%% *}"
    speed=$(format_decimal "$speed" 2 "0.00")
    
    files_per_sec="${files_per_sec%%/*}"
    files_per_sec=$(format_decimal "$files_per_sec" 2 "0.00")
    
    pct_total="${pct_total%%%*}"
    pct_total=$(format_decimal "$pct_total" 2 "0.00")

    echo "$timestamp,$phase,$speed,$files_per_sec,$pct_total,$bytes,$total" >> "$CSV_LOG_FILE"
}

# Export functions
export -f debug info warn error success fatal init_logging log_csv
