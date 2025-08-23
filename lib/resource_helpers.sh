#!/usr/bin/env bash
# lib/resource_helpers.sh - Helper functions for resource monitoring

# Source dependencies
[[ -z "$(type -t init_colors)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"

# Get color based on CPU usage
get_cpu_color() {
    local cpu="$1"
    local use_colors="${2:-true}"
    
    [[ "$use_colors" != "true" ]] && return
    
    if (( $(echo "$cpu > 10" | bc -l 2>/dev/null || echo 0) )); then
        echo "${COLOR_RED}"
    elif (( $(echo "$cpu > 5" | bc -l 2>/dev/null || echo 0) )); then
        echo "${COLOR_BOLD_YELLOW}"
    else
        echo "${COLOR_GREEN}"
    fi
}

# Get impact level and color
get_impact_level() {
    local value="$1"
    local low_threshold="$2"
    local high_threshold="$3"
    
    if (( $(echo "$value < $low_threshold" | bc -l 2>/dev/null || echo 1) )); then
        echo "Low|${COLOR_GREEN}"
    elif (( $(echo "$value < $high_threshold" | bc -l 2>/dev/null || echo 0) )); then
        echo "Moderate|${COLOR_BOLD_YELLOW}"
    else
        echo "High|${COLOR_RED}"
    fi
}

# Get load average color based on core count
# This calculates appropriate thresholds based on number of CPU cores:
# - Green: load < cores (system is underutilized)
# - Yellow: cores <= load < cores*2 (system is busy but not overloaded)
# - Red: load >= cores*2 (system is overloaded)
get_load_color() {
    local load="$1"
    local num_cores="$2"
    
    # Use centralized impact level function with core-based thresholds
    local impact_result
    impact_result=$(get_impact_level "$load" "$num_cores" "$((num_cores * 2))")
    
    # Extract just the color from the result (part after the pipe)
    echo "${impact_result#*|}"
}

# Export functions
export -f get_cpu_color get_impact_level get_load_color
