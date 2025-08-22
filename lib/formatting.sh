#!/usr/bin/env bash
# lib/formatting.sh - Centralized formatting functions for tm-monitor
# 
# This module provides consistent formatting for all output in tm-monitor.
# All numeric values use 2 decimal places, null values display as "-"

# =============================================================================
# NUMBER FORMATTING
# =============================================================================

# Format decimal number with specified precision (default 2)
# Usage: format_decimal <value> [precision] [default]
# Example: format_decimal "3.14159" 2 "-"  # Returns: "3.14"
format_decimal() {
    local value="${1:-}"
    local precision="${2:-2}"
    local default="${3:--}"
    
    # Check if value is numeric
    if [[ -z "$value" ]] || [[ "$value" == "-" ]] || ! [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        echo "$default"
        return
    fi
    
    printf "%.${precision}f" "$value" 2>/dev/null || echo "$default"
}

# Format percentage with clamping to 0-100 range
# Usage: format_percentage <value> [show_symbol] [default]
# Example: format_percentage "45.678" true "-"  # Returns: "45.68%"
format_percentage() {
    local value="${1:-}"
    local show_symbol="${2:-true}"
    local default="${3:--}"
    
    # Check if value is numeric
    if [[ -z "$value" ]] || [[ "$value" == "-" ]] || ! [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        echo "$default"
        return
    fi
    
    # Clamp to 0-100 range
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$value > 100" | bc -l 2>/dev/null || echo 0) )); then
            value="100"
        elif (( $(echo "$value < 0" | bc -l 2>/dev/null || echo 0) )); then
            value="0"
        fi
    else
        # Fallback to integer comparison
        local int_value="${value%%.*}"
        if [[ "$int_value" -gt 100 ]]; then
            value="100"
        elif [[ "$int_value" -lt 0 ]]; then
            value="0"
        fi
    fi
    
    local formatted
    formatted=$(printf "%.2f" "$value" 2>/dev/null || echo "$default")
    
    if [[ "$show_symbol" == "true" ]] && [[ "$formatted" != "$default" ]]; then
        echo "${formatted}%"
    else
        echo "$formatted"
    fi
}

# Format integer with optional thousand separators
# Usage: format_integer <value> [use_separators] [default]
format_integer() {
    local value="${1:-}"
    local use_separators="${2:-false}"
    local default="${3:--}"
    
    if [[ -z "$value" ]] || [[ "$value" == "-" ]] || ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "$default"
        return
    fi
    
    if [[ "$use_separators" == "true" ]]; then
        # Add thousand separators (requires GNU printf)
        printf "%'d" "$value" 2>/dev/null || printf "%d" "$value" 2>/dev/null || echo "$default"
    else
        printf "%d" "$value" 2>/dev/null || echo "$default"
    fi
}

# =============================================================================
# SIZE FORMATTING
# =============================================================================

# Helper function for format_bytes
format_size_with_unit() {
    local bytes="$1"
    local divisor="$2"
    local unit="$3"
    local precision="${4:-2}"
    
    if command -v bc >/dev/null 2>&1; then
        local value
        value=$(echo "scale=$precision; $bytes / $divisor" | bc 2>/dev/null || echo "0")
        printf "%.${precision}f %s" "$value" "$unit"
    else
        # Fallback to integer math
        local value=$((bytes / divisor))
        echo "$value $unit"
    fi
}

# Format bytes to human-readable size
# Usage: format_bytes <bytes> <unit> [precision] [use_binary]
# Units: AUTO, KB, MB, GB, TB
# Example: format_bytes "1073741824" "GB" 2 false  # Returns: "1.07 GB"
# Example: format_bytes "1073741824" "GB" 2 true   # Returns: "1.00 GiB"
format_bytes() {
    local bytes="${1:-0}"
    local unit="${2:-AUTO}"
    local precision="${3:-2}"
    local use_binary="${4:-}"  # empty = use UNITS config
    
    # Check if bytes is numeric
    if [[ -z "$bytes" ]] || [[ "$bytes" == "-" ]] || ! [[ "$bytes" =~ ^-?[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    # Use global UNITS if set and use_binary not explicitly provided
    if [[ -z "$use_binary" ]] && [[ -n "${UNITS:-}" ]]; then
        if [[ "$UNITS" == "1024" ]]; then
            use_binary="true"
        else
            use_binary="false"
        fi
    elif [[ -z "$use_binary" ]]; then
        use_binary="false"  # Default to decimal (1000)
    fi
    
    local divisor suffix
    if [[ "$use_binary" == "true" ]]; then
        divisor=1024
        suffix="iB"
    else
        divisor=1000
        suffix="B"
    fi
    
    case "$unit" in
        AUTO)
            # Auto-scale to appropriate unit
            if (( bytes < divisor )); then
                echo "${bytes} B"
            elif (( bytes < divisor ** 2 )); then
                format_size_with_unit "$bytes" "$divisor" "K${suffix}" "$precision"
            elif (( bytes < divisor ** 3 )); then
                format_size_with_unit "$bytes" "$((divisor ** 2))" "M${suffix}" "$precision"
            elif (( bytes < divisor ** 4 )); then
                format_size_with_unit "$bytes" "$((divisor ** 3))" "G${suffix}" "$precision"
            else
                format_size_with_unit "$bytes" "$((divisor ** 4))" "T${suffix}" "$precision"
            fi
            ;;
        KB)
            format_size_with_unit "$bytes" "$divisor" "K${suffix}" "$precision"
            ;;
        MB)
            format_size_with_unit "$bytes" "$((divisor ** 2))" "M${suffix}" "$precision"
            ;;
        GB)
            format_size_with_unit "$bytes" "$((divisor ** 3))" "G${suffix}" "$precision"
            ;;
        TB)
            format_size_with_unit "$bytes" "$((divisor ** 4))" "T${suffix}" "$precision"
            ;;
        *)
            echo "$bytes B"
            ;;
    esac
}

# Format size ratio (e.g., "1.23 GB / 4.56 GB")
# Usage: format_size_ratio <current_bytes> <total_bytes> <unit> [use_binary]
format_size_ratio() {
    local current_bytes="${1:-0}"
    local total_bytes="${2:-0}"
    local unit="${3:-GB}"
    local use_binary="${4:-}"
    
    # Check for invalid inputs
    if [[ "$current_bytes" == "-" ]] || [[ "$total_bytes" == "-" ]]; then
        echo "-"
        return
    fi
    
    local current total
    current=$(format_bytes "$current_bytes" "$unit" 2 "$use_binary")
    total=$(format_bytes "$total_bytes" "$unit" 2 "$use_binary")
    
    if [[ "$current" == "-" ]] || [[ "$total" == "-" ]]; then
        echo "-"
    else
        echo "$current / $total"
    fi
}

# =============================================================================
# TIME FORMATTING
# =============================================================================

# Format duration from seconds to human-readable
# Usage: format_duration <seconds> [format]
# Formats: "HMS" (H:MM:SS), "DHMS" (Xd Yh Zm), "AUTO"
format_duration() {
    local seconds="${1:-0}"
    local format="${2:-HMS}"
    
    # Check if seconds is numeric
    if [[ -z "$seconds" ]] || [[ "$seconds" == "-" ]] || ! [[ "$seconds" =~ ^-?[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    if [[ "$seconds" -le 0 ]]; then
        echo "-"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    case "$format" in
        HMS)
            printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
            ;;
        DHMS)
            if [[ $hours -ge 24 ]]; then
                local days=$((hours / 24))
                local remaining_hours=$((hours % 24))
                echo "${days}d ${remaining_hours}h ${minutes}m"
            else
                echo "${hours}h ${minutes}m ${secs}s"
            fi
            ;;
        AUTO)
            if [[ $hours -ge 24 ]]; then
                local days=$((hours / 24))
                local remaining_hours=$((hours % 24))
                echo "${days}d ${remaining_hours}h"
            elif [[ $hours -gt 0 ]]; then
                printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
            else
                printf "%d:%02d" "$minutes" "$secs"
            fi
            ;;
        *)
            printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
            ;;
    esac
}

# Format ETA with special handling for long durations
# Replaces format_time_remaining from tmutil.sh
# Usage: format_eta <seconds>
format_eta() {
    local seconds="${1:-0}"
    
    if [[ -z "$seconds" ]] || [[ "$seconds" == "-" ]] || ! [[ "$seconds" =~ ^-?[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    if [[ "$seconds" -le 0 ]]; then
        echo "-"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    # Match tmutil.sh format_time_remaining behavior
    if [[ $hours -gt 24 ]]; then
        local days=$((hours / 24))
        local remaining_hours=$((hours % 24))
        echo "${days}d ${remaining_hours}h"
    elif [[ $hours -gt 0 ]]; then
        printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
    else
        printf "%d:%02d" "$minutes" "$secs"
    fi
}

# Alias for backward compatibility
format_time_remaining() {
    format_eta "$@"
}

# Format Unix timestamp to readable format
# Usage: format_timestamp <unix_timestamp> [format]
format_timestamp() {
    local timestamp="${1:-}"
    local format="${2:-%H:%M:%S}"
    
    if [[ -z "$timestamp" ]] || [[ "$timestamp" == "-" ]]; then
        date "+$format"
    else
        date -r "$timestamp" "+$format" 2>/dev/null || date "+$format"
    fi
}

# =============================================================================
# SPEED FORMATTING
# =============================================================================

# Format transfer speed in MB/s
# Usage: format_speed_mbps <bytes_per_sec> [use_binary]
format_speed_mbps() {
    local bytes_per_sec="${1:-0}"
    local use_binary="${2:-}"
    
    if [[ -z "$bytes_per_sec" ]] || [[ "$bytes_per_sec" == "-" ]] || ! [[ "$bytes_per_sec" =~ ^-?[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    if [[ "$bytes_per_sec" -eq 0 ]]; then
        echo "0.00 MB/s"
        return
    fi
    
    # Use global UNITS if set and use_binary not explicitly provided
    if [[ -z "$use_binary" ]] && [[ -n "${UNITS:-}" ]]; then
        if [[ "$UNITS" == "1024" ]]; then
            use_binary="true"
        else
            use_binary="false"
        fi
    elif [[ -z "$use_binary" ]]; then
        use_binary="false"  # Default to decimal
    fi
    
    local divisor unit
    if [[ "$use_binary" == "true" ]]; then
        divisor=$((1024 * 1024))
        unit="MiB/s"
    else
        divisor=$((1000 * 1000))
        unit="MB/s"
    fi
    
    if command -v bc >/dev/null 2>&1; then
        local speed
        speed=$(echo "scale=2; $bytes_per_sec / $divisor" | bc 2>/dev/null || echo "0")
        printf "%.2f %s" "$speed" "$unit"
    else
        local speed=$((bytes_per_sec / divisor))
        echo "$speed $unit"
    fi
}

# Format transfer rate (files/sec, items/sec)
# Usage: format_transfer_rate <count> <seconds> [unit]
format_transfer_rate() {
    local count="${1:-0}"
    local seconds="${2:-1}"
    local unit="${3:-/s}"
    
    if [[ -z "$count" ]] || [[ "$count" == "-" ]] || ! [[ "$count" =~ ^-?[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    if [[ "$seconds" -le 0 ]]; then
        echo "-"
        return
    fi
    
    if command -v bc >/dev/null 2>&1; then
        local rate
        rate=$(echo "scale=2; $count / $seconds" | bc 2>/dev/null || echo "0")
        printf "%.2f%s" "$rate" "$unit"
    else
        local rate=$((count / seconds))
        echo "${rate}${unit}"
    fi
}

# =============================================================================
# TABLE/COLUMN FORMATTING
# =============================================================================

# Format value for fixed-width column
# Usage: format_column <value> <width> [alignment] [truncate]
# Alignment: "left", "right", "center"
format_column() {
    local value="${1:-}"
    local width="${2:-10}"
    local alignment="${3:-left}"
    local truncate="${4:-true}"
    
    # Handle empty/null values
    if [[ -z "$value" ]]; then
        value="-"
    fi
    
    # Truncate if needed
    if [[ "$truncate" == "true" ]] && [[ ${#value} -gt $width ]]; then
        value="${value:0:$((width - 3))}..."
    fi
    
    case "$alignment" in
        left)
            printf "%-${width}s" "$value"
            ;;
        right)
            printf "%${width}s" "$value"
            ;;
        center)
            local padding=$(( (width - ${#value}) / 2 ))
            local remainder=$(( (width - ${#value}) % 2 ))
            printf "%*s%s%*s" "$padding" "" "$value" "$((padding + remainder))" ""
            ;;
        *)
            printf "%-${width}s" "$value"
            ;;
    esac
}

# Format colored text for fixed-width column (handles ANSI codes)
# Usage: format_colored_column <colored_text> <width> [alignment]
format_colored_column() {
    local text="$1"
    local width="$2"
    local alignment="${3:-left}"
    
    # Count visible characters (excluding ANSI escape sequences)
    local visible_text
    visible_text=$(printf "%b" "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local visible_length=${#visible_text}
    
    local padding=$((width - visible_length))
    [[ $padding -lt 0 ]] && padding=0
    
    if [[ "$alignment" == "right" ]]; then
        printf "%*s%b" "$padding" "" "$text"
    else
        printf "%b%*s" "$text" "$padding" ""
    fi
}

# Backward compatibility alias for pad_colored_text
pad_colored_text() {
    format_colored_column "$@"
}

# Pad string to specified width
# Usage: pad_string <string> <width> [pad_char] [alignment]
pad_string() {
    local string="${1:-}"
    local width="${2:-10}"
    local pad_char="${3:- }"
    local alignment="${4:-left}"
    
    local length=${#string}
    if [[ $length -ge $width ]]; then
        echo "$string"
        return
    fi
    
    local padding=$((width - length))
    local pad_string=""
    for ((i=0; i<padding; i++)); do
        pad_string+="$pad_char"
    done
    
    if [[ "$alignment" == "right" ]]; then
        echo "${pad_string}${string}"
    elif [[ "$alignment" == "center" ]]; then
        local left_pad=$((padding / 2))
        local right_pad=$((padding - left_pad))
        local left_string=""
        local right_string=""
        for ((i=0; i<left_pad; i++)); do
            left_string+="$pad_char"
        done
        for ((i=0; i<right_pad; i++)); do
            right_string+="$pad_char"
        done
        echo "${left_string}${string}${right_string}"
    else
        echo "${string}${pad_string}"
    fi
}

# Truncate string with ellipsis
# Usage: truncate_string <string> <max_length> [ellipsis]
truncate_string() {
    local string="${1:-}"
    local max_length="${2:-20}"
    local ellipsis="${3:-...}"
    
    if [[ ${#string} -le $max_length ]]; then
        echo "$string"
    else
        local truncated_length=$((max_length - ${#ellipsis}))
        echo "${string:0:$truncated_length}${ellipsis}"
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Validate if value is numeric
# Usage: is_numeric <value>
is_numeric() {
    local value="${1:-}"
    [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]
}

# Clamp value between min and max
# Usage: clamp_value <value> <min> <max>
clamp_value() {
    local value="${1:-0}"
    local min="${2:-0}"
    local max="${3:-100}"
    
    if ! is_numeric "$value"; then
        echo "$min"
        return
    fi
    
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$value < $min" | bc -l) )); then
            echo "$min"
        elif (( $(echo "$value > $max" | bc -l) )); then
            echo "$max"
        else
            echo "$value"
        fi
    else
        local int_value="${value%%.*}"
        if [[ $int_value -lt $min ]]; then
            echo "$min"
        elif [[ $int_value -gt $max ]]; then
            echo "$max"
        else
            echo "$value"
        fi
    fi
}

# Handle null/empty values consistently
# Usage: handle_null <value> [default]
handle_null() {
    local value="${1:-}"
    local default="${2:--}"
    
    if [[ -z "$value" ]] || [[ "$value" == "null" ]] || [[ "$value" == "NULL" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Export all functions
export -f format_decimal format_percentage format_integer
export -f format_bytes format_size_with_unit format_size_ratio
export -f format_duration format_eta format_timestamp format_time_remaining
export -f format_speed_mbps format_transfer_rate
export -f format_column format_colored_column pad_colored_text pad_string truncate_string
export -f is_numeric clamp_value handle_null
