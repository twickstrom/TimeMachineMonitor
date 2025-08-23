#!/usr/bin/env bash
# lib/process_management.sh - Process finding and management functions for tm-monitor
#
# This module provides centralized functions for finding and managing processes,
# particularly tm-monitor and Time Machine related processes.

# Prevent multiple sourcing
[[ -n "${_PROCESS_MANAGEMENT_SOURCED:-}" ]] && return 0
export _PROCESS_MANAGEMENT_SOURCED=1

# Source dependencies
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"
[[ -z "$(type -t get_cpu_color)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/resource_helpers.sh"
[[ -z "$(type -t clear_line)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/terminal.sh"
[[ -z "$(type -t init_colors)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# =============================================================================
# PROCESS FINDING FUNCTIONS
# =============================================================================

# Generic process finder
# Usage: find_processes <pattern>
# Returns: Matching processes from ps aux
find_processes() {
    local pattern="$1"
    ps aux | grep -E "$pattern" 2>/dev/null
}

# Find tm-monitor main processes
# Returns: tm-monitor processes (excluding tm-monitor-resources)
find_tm_monitor_processes() {
    find_processes "[b]ash.*tm-monitor|tm-monitor$" | grep -v "tm-monitor-resources"
}

# Find tm-monitor python helper processes
# Returns: Python helper processes
find_tm_monitor_helper_processes() {
    find_processes "[p]ython.*tm-monitor-helper"
}

# Find Time Machine backupd processes
# Returns: backupd processes (excluding backupd-helper)
find_backupd_processes() {
    find_processes "[b]ackupd$" | grep -v "backupd-helper"
}

# Find Time Machine backupd-helper processes
# Returns: backupd-helper processes
find_backupd_helper_processes() {
    find_processes "[b]ackupd-helper"
}

# Find all tm-monitor related processes
# Returns: All tm-monitor and helper processes
find_all_tm_monitor_processes() {
    {
        find_tm_monitor_processes
        find_tm_monitor_helper_processes
    } 2>/dev/null
}

# Find all Time Machine related processes
# Returns: All backupd and backupd-helper processes
find_all_time_machine_processes() {
    {
        find_backupd_processes
        find_backupd_helper_processes
    } 2>/dev/null
}

# =============================================================================
# PROCESS CHECKING FUNCTIONS
# =============================================================================

# Check if tm-monitor is running
# Returns: 0 if running, 1 if not
is_tm_monitor_running() {
    local procs
    procs=$(find_tm_monitor_processes)
    [[ -n "$procs" ]]
}

# Check if tm-monitor helper is running
# Returns: 0 if running, 1 if not
is_tm_monitor_helper_running() {
    local procs
    procs=$(find_tm_monitor_helper_processes)
    [[ -n "$procs" ]]
}

# Check if Time Machine backup daemon is running
# Returns: 0 if running, 1 if not
is_backupd_running() {
    local procs
    procs=$(find_backupd_processes)
    [[ -n "$procs" ]]
}

# Check if any tm-monitor component is running
# Returns: 0 if any component running, 1 if not
is_any_tm_monitor_running() {
    is_tm_monitor_running || is_tm_monitor_helper_running
}

# Check if any Time Machine component is running
# Returns: 0 if any component running, 1 if not
is_any_time_machine_running() {
    local procs
    procs=$(find_all_time_machine_processes)
    [[ -n "$procs" ]]
}

# =============================================================================
# PROCESS COUNTING FUNCTIONS
# =============================================================================

# Count tm-monitor processes
# Returns: Number of tm-monitor processes
count_tm_monitor_processes() {
    find_tm_monitor_processes | wc -l | awk '{print $1}'
}

# Count all tm-monitor related processes
# Returns: Total count of tm-monitor and helper processes
count_all_tm_monitor_processes() {
    find_all_tm_monitor_processes | wc -l | awk '{print $1}'
}

# Count all Time Machine processes
# Returns: Total count of backupd processes
count_all_time_machine_processes() {
    find_all_time_machine_processes | wc -l | awk '{print $1}'
}

# =============================================================================
# PROCESS PARSING FUNCTIONS
# =============================================================================

# Parse process info from ps output line
# Usage: parse_process_line <ps_line> [is_helper]
# Returns: pid|cpu|mem|rss|time|cmd (pipe-separated)
parse_process_line() {
    local line="$1"
    local is_helper="${2:-false}"
    
    local pid cpu mem rss time cmd
    pid=$(echo "$line" | awk '{print $2}')
    
    # Use centralized formatting for numeric values
    cpu=$(format_decimal "$(echo "$line" | awk '{print $3}')" 2 "0.00")
    mem=$(format_decimal "$(echo "$line" | awk '{print $4}')" 2 "0.00")
    rss=$(format_decimal "$(echo "$line" | awk '{print $6/1024}')" 2 "0.00")
    
    # Get raw time and format it consistently
    time=$(echo "$line" | awk '{print $10}')
    # Format TIME to ensure consistent width: HH:MM.SS or MM:SS.SS
    if [[ "$time" =~ ^[0-9]:.*$ ]]; then
        # Single digit hour/minute, add leading zero
        time="0${time}"
    fi
    
    if [[ "$is_helper" == "true" ]]; then
        cmd="tm-monitor-helper"
    else
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/.*\///' | cut -c1-29)
    fi
    
    echo "$pid|$cpu|$mem|$rss|$time|$cmd"
}

# =============================================================================
# PROCESS DISPLAY FUNCTIONS
# =============================================================================

# Format a process row for display
# Usage: format_process_row <pid> <cpu> <mem> <rss> <time> <cmd> [use_colors]
# Outputs: Formatted process row
format_process_row() {
    local pid="$1"
    local cpu="$2"
    local mem="$3"
    local rss="$4"
    local time="$5"
    local cmd="$6"
    local use_colors="${7:-true}"
    
    local color
    color=$(get_cpu_color "$cpu" "$use_colors")
    
    # Handle special case for placeholder rows (when process not running)
    if [[ "$pid" == "-" ]]; then
        # Show dashes for inactive processes (dimmed if colors enabled)
        if [[ "$use_colors" == "true" ]]; then
            clear_line
            printf "${COLOR_DIM}%-6s%8s %8s %8s    %-10s %-29.29s${COLOR_RESET}\n" \
                   "-" "-" "-" "-" "-" "${cmd:0:29}"
        else
            clear_line
            printf "%-6s%8s %8s %8s    %-10s %-29.29s\n" \
                   "-" "-" "-" "-" "-" "${cmd:0:29}"
        fi
    else
        # Use centralized formatting for numeric values
        local formatted_cpu formatted_mem formatted_rss
        formatted_cpu=$(format_decimal "$cpu" 2 "0.00")
        formatted_mem=$(format_decimal "$mem" 2 "0.00")
        formatted_rss=$(format_decimal "$rss" 2 "0.00")
        
        # Normal process row with values
        clear_line
        printf "${color}%-6s%8s %8s %8s    %-10s %-29.29s${COLOR_RESET}\n" \
               "${pid:0:6}" "$formatted_cpu" "$formatted_mem" "$formatted_rss" "${time:0:10}" "${cmd:0:29}"
    fi
}

# Display a placeholder row for a process that's not running
# Usage: display_placeholder_row <process_name> [use_colors]
display_placeholder_row() {
    local process_name="$1"
    local use_colors="${2:-true}"
    
    format_process_row "-" "0.00" "0.00" "0.00" "-" "$process_name" "$use_colors"
}

# =============================================================================
# PROCESS STATISTICS FUNCTIONS
# =============================================================================

# Get total resource usage for a list of processes
# Usage: get_process_totals <process_lines>
# Returns: total_cpu|total_mem|total_rss|count (pipe-separated)
get_process_totals() {
    local process_lines="$1"
    local total_cpu=0
    local total_mem=0
    local total_rss=0
    local count=0
    
    if [[ -n "$process_lines" ]]; then
        while IFS= read -r line; do
            local parsed_info
            parsed_info=$(parse_process_line "$line" "false")
            
            local pid cpu mem rss time cmd
            IFS='|' read -r pid cpu mem rss time cmd <<< "$parsed_info"
            
            # Accumulate totals
            if command -v bc >/dev/null 2>&1; then
                total_cpu=$(echo "$total_cpu + $cpu" | bc -l 2>/dev/null || echo "$total_cpu")
                total_mem=$(echo "$total_mem + $mem" | bc -l 2>/dev/null || echo "$total_mem")
                total_rss=$(echo "$total_rss + $rss" | bc -l 2>/dev/null || echo "$total_rss")
            else
                # Fallback to integer math
                local cpu_int="${cpu%%.*}"
                local mem_int="${mem%%.*}"
                local rss_int="${rss%%.*}"
                total_cpu=$((total_cpu + cpu_int))
                total_mem=$((total_mem + mem_int))
                total_rss=$((total_rss + rss_int))
            fi
            ((count++))
        done <<< "$process_lines"
    fi
    
    echo "$total_cpu|$total_mem|$total_rss|$count"
}

# Get PID of main tm-monitor process
# Returns: PID or empty if not running
get_tm_monitor_pid() {
    find_tm_monitor_processes | head -1 | awk '{print $2}'
}

# Get PID of tm-monitor helper process
# Returns: PID or empty if not running
get_tm_monitor_helper_pid() {
    find_tm_monitor_helper_processes | head -1 | awk '{print $2}'
}

# =============================================================================
# PROCESS CONTROL FUNCTIONS
# =============================================================================

# Kill tm-monitor and all related processes
# Returns: 0 on success, 1 on failure
kill_tm_monitor() {
    local main_pid helper_pid
    
    main_pid=$(get_tm_monitor_pid)
    helper_pid=$(get_tm_monitor_helper_pid)
    
    local killed=0
    
    if [[ -n "$main_pid" ]]; then
        kill "$main_pid" 2>/dev/null && ((killed++))
    fi
    
    if [[ -n "$helper_pid" ]]; then
        kill "$helper_pid" 2>/dev/null && ((killed++))
    fi
    
    [[ "$killed" -gt 0 ]]
}

# Check if a specific PID is running
# Usage: is_pid_running <pid>
# Returns: 0 if running, 1 if not
is_pid_running() {
    local pid="$1"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Wait for a process to exit
# Usage: wait_for_process_exit <pid> [timeout]
# Returns: 0 if process exited, 1 if timeout
wait_for_process_exit() {
    local pid="$1"
    local timeout="${2:-10}"
    local count=0
    
    while is_pid_running "$pid" && [[ "$count" -lt "$timeout" ]]; do
        sleep 1
        ((count++))
    done
    
    ! is_pid_running "$pid"
}

# Display processes or placeholder row
# Usage: display_processes_or_placeholder <process_list> <process_name> <is_fixed_name> <use_colors>
# This function handles the common pattern of showing processes if they exist or a placeholder if not
display_processes_or_placeholder() {
    local process_list="$1"
    local process_name="$2"
    local is_fixed_name="${3:-false}"
    local use_colors="${4:-true}"
    
    if [[ -n "$process_list" ]]; then
        # Process each line if processes found
        while IFS= read -r line; do
            local parsed_info
            parsed_info=$(parse_process_line "$line" "false")
            
            local pid cpu mem rss time cmd
            IFS='|' read -r pid cpu mem rss time cmd <<< "$parsed_info"
            
            # Override command name if fixed
            if [[ "$is_fixed_name" == "true" ]]; then
                cmd="$process_name"
            fi
            
            # Format and print the row
            format_process_row "$pid" "$cpu" "$mem" "$rss" "$time" "$cmd" "$use_colors"
        done <<< "$process_list"
    else
        # Show placeholder row if no processes found
        display_placeholder_row "$process_name" "$use_colors"
    fi
}

# Export all functions
export -f find_processes find_tm_monitor_processes find_tm_monitor_helper_processes
export -f find_backupd_processes find_backupd_helper_processes
export -f find_all_tm_monitor_processes find_all_time_machine_processes
export -f is_tm_monitor_running is_tm_monitor_helper_running is_backupd_running
export -f is_any_tm_monitor_running is_any_time_machine_running
export -f count_tm_monitor_processes count_all_tm_monitor_processes count_all_time_machine_processes
export -f parse_process_line format_process_row display_placeholder_row
export -f get_process_totals get_tm_monitor_pid get_tm_monitor_helper_pid
export -f kill_tm_monitor is_pid_running wait_for_process_exit
export -f display_processes_or_placeholder
