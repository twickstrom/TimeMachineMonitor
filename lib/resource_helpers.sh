#!/usr/bin/env bash
# lib/resource_helpers.sh - Helper functions for resource monitoring

# Source dependencies
[[ -z "$(type -t init_colors)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

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

# Parse and display process information
parse_process_info() {
    local process_line="$1"
    local process_type="$2"  # "monitor" or "helper"
    local use_colors="${3:-true}"
    
    # Declare local variables
    local pid cpu mem rss time cmd color
    
    pid=$(echo "$process_line" | awk '{print $2}')
    cpu=$(echo "$process_line" | awk '{print $3}')
    mem=$(echo "$process_line" | awk '{print $4}')
    rss=$(echo "$process_line" | awk '{printf "%.1f", $6/1024}')
    time=$(echo "$process_line" | awk '{print $10}')
    
    if [[ "$process_type" == "helper" ]]; then
        cmd="python: tm-monitor-helper"
    else
        cmd=$(echo "$process_line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/.*\///' | cut -c1-30)
    fi
    
    # Get color based on CPU usage
    color=$(get_cpu_color "$cpu" "$use_colors")
    
    # Print formatted line
    printf "\033[K${color}%-8s %6s %6s %8s %10s  %-30s${COLOR_RESET}\n" \
           "$pid" "$cpu" "$mem" "$rss" "$time" "$cmd"
    
    # Return values for accumulation (using echo with pipe separator)
    echo "${cpu}|${mem}|${rss}"
}

# Export functions
export -f get_cpu_color get_impact_level parse_process_info
