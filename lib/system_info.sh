#!/usr/bin/env bash
# lib/system_info.sh - System information retrieval functions for tm-monitor
#
# This module provides centralized functions for retrieving system information
# such as CPU cores, memory, load averages, and other system metrics.

# Prevent multiple sourcing
[[ -n "${_SYSTEM_INFO_SOURCED:-}" ]] && return 0
export _SYSTEM_INFO_SOURCED=1

# =============================================================================
# CPU INFORMATION
# =============================================================================

# Get number of CPU cores
# Returns: Number of CPU cores (defaults to 4 if detection fails)
# WARNING: Do NOT cache this value in a monitoring loop - while CPU cores don't
#          change during execution, caching prevents proper function testing
#          and makes the code less modular. The sysctl call is very fast.
get_cpu_cores() {
    sysctl -n hw.ncpu 2>/dev/null || echo 4
}

# Get number of physical CPU cores (excluding hyperthreading)
# Returns: Number of physical cores
get_physical_cpu_cores() {
    sysctl -n hw.physicalcpu 2>/dev/null || get_cpu_cores
}

# Get number of logical CPU cores (including hyperthreading)
# Returns: Number of logical cores
get_logical_cpu_cores() {
    sysctl -n hw.logicalcpu 2>/dev/null || get_cpu_cores
}

# Get CPU brand string
# Returns: CPU model name
get_cpu_brand() {
    sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown CPU"
}

# =============================================================================
# MEMORY INFORMATION
# =============================================================================

# Get total system memory in bytes
# Returns: Total memory in bytes
# WARNING: Do NOT cache this value - memory info should always be fresh
#          for accurate monitoring. The sysctl call is fast.
get_total_memory_bytes() {
    sysctl -n hw.memsize 2>/dev/null || echo 0
}

# Get total system memory in GB
# Returns: Total memory in GB with 2 decimal places
# WARNING: Do NOT cache this value - see get_total_memory_bytes warning
get_total_memory_gb() {
    local bytes
    bytes=$(get_total_memory_bytes)
    
    if [[ "$bytes" -gt 0 ]]; then
        awk -v bytes="$bytes" 'BEGIN { printf "%.2f", bytes/1024/1024/1024 }'
    else
        echo "0.00"
    fi
}

# Get total system memory in MB
# Returns: Total memory in MB
get_total_memory_mb() {
    local bytes
    bytes=$(get_total_memory_bytes)
    
    if [[ "$bytes" -gt 0 ]]; then
        echo $((bytes / 1024 / 1024))
    else
        echo 0
    fi
}

# Get memory pressure (macOS specific)
# Returns: Memory pressure as percentage or "N/A"
get_memory_pressure() {
    # This would require parsing vm_stat output
    # For now, return N/A
    echo "N/A"
}

# =============================================================================
# LOAD AVERAGE INFORMATION
# =============================================================================

# Get load averages as three pipe-separated values
# Returns: load1|load5|load15
# WARNING: NEVER cache load averages! These values change constantly and
#          caching them defeats the purpose of real-time monitoring.
#          The uptime command is very fast.
get_load_averages() {
    local load_output
    load_output=$(uptime | awk -F'load averages?: ' '{print $2}' 2>/dev/null)
    
    if [[ -z "$load_output" ]]; then
        echo "0.00|0.00|0.00"
        return 1
    fi
    
    local load1 load5 load15
    load1=$(echo "$load_output" | awk '{print $1}' | tr -d ',')
    load5=$(echo "$load_output" | awk '{print $2}' | tr -d ',')
    load15=$(echo "$load_output" | awk '{print $3}' | tr -d ',')
    
    # Validate and format
    load1="${load1:-0.00}"
    load5="${load5:-0.00}"
    load15="${load15:-0.00}"
    
    echo "${load1}|${load5}|${load15}"
}

# Get 1-minute load average
# Returns: 1-minute load average
get_load_1min() {
    local loads
    loads=$(get_load_averages)
    echo "${loads%%|*}"
}

# Get 5-minute load average
# Returns: 5-minute load average
get_load_5min() {
    local loads
    loads=$(get_load_averages)
    loads="${loads#*|}"
    echo "${loads%%|*}"
}

# Get 15-minute load average
# Returns: 15-minute load average
get_load_15min() {
    local loads
    loads=$(get_load_averages)
    echo "${loads##*|}"
}

# =============================================================================
# SYSTEM UPTIME
# =============================================================================

# Get system uptime in seconds
# Returns: Uptime in seconds
get_uptime_seconds() {
    local boot_time current_time
    
    # Get boot time from sysctl
    boot_time=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
    
    if [[ -n "$boot_time" ]]; then
        current_time=$(date +%s)
        echo $((current_time - boot_time))
    else
        echo 0
    fi
}

# Get formatted uptime string
# Returns: Human-readable uptime (e.g., "5 days, 3:45")
get_uptime_string() {
    uptime | sed -E 's/.*up ([^,]+).*/\1/'
}

# =============================================================================
# DISK INFORMATION
# =============================================================================

# Get disk usage for a path
# Usage: get_disk_usage [path]
# Returns: used|available|capacity|mount
get_disk_usage() {
    local path="${1:-/}"
    
    df -H "$path" 2>/dev/null | awk 'NR==2 {
        gsub(/%/, "", $5)
        print $3 "|" $4 "|" $5 "|" $9
    }'
}

# Get Time Machine volume disk usage
# Returns: used|available|capacity|mount or empty if not mounted
get_tm_disk_usage() {
    local tm_dest
    tm_dest=$(tmutil destinationinfo 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}')
    
    if [[ -n "$tm_dest" ]]; then
        get_disk_usage "$tm_dest"
    fi
}

# =============================================================================
# NETWORK INFORMATION
# =============================================================================

# Get primary network interface
# Returns: Interface name (e.g., en0)
get_primary_interface() {
    route get default 2>/dev/null | awk '/interface:/ {print $2}'
}

# Get IP address for an interface
# Usage: get_interface_ip [interface]
# Returns: IP address or empty
get_interface_ip() {
    local interface="${1:-$(get_primary_interface)}"
    
    ifconfig "$interface" 2>/dev/null | awk '/inet / {print $2}'
}

# =============================================================================
# PROCESS INFORMATION
# =============================================================================

# Count total number of processes
# Returns: Total process count
get_process_count() {
    ps aux | wc -l | awk '{print $1-1}'  # Subtract header line
}

# Count processes by user
# Usage: get_user_process_count [username]
# Returns: Process count for user
get_user_process_count() {
    local user="${1:-$USER}"
    ps aux | grep "^$user" | wc -l | awk '{print $1}'
}

# =============================================================================
# THERMAL INFORMATION
# =============================================================================

# Get CPU temperature (requires sudo on some systems)
# Returns: Temperature in Celsius or "N/A"
get_cpu_temperature() {
    # This is system-specific and may require additional tools
    # For now, return N/A
    echo "N/A"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if system is under load
# Usage: is_system_loaded [threshold_multiplier]
# Returns: 0 if loaded, 1 if not
is_system_loaded() {
    local multiplier="${1:-1.0}"
    local cores load1
    
    cores=$(get_cpu_cores)
    load1=$(get_load_1min)
    
    if command -v bc >/dev/null 2>&1; then
        local threshold
        threshold=$(echo "$cores * $multiplier" | bc)
        (( $(echo "$load1 > $threshold" | bc -l) ))
    else
        # Fallback to integer comparison
        local load_int="${load1%%.*}"
        [[ "$load_int" -gt "$cores" ]]
    fi
}

# Get system load status
# Returns: "Normal", "Elevated", or "High"
# WARNING: Do NOT cache - this function calls get_load_1min which
#          must return real-time data for accurate monitoring
get_load_status() {
    local cores load1
    
    cores=$(get_cpu_cores)
    load1=$(get_load_1min)
    
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$load1 < $cores" | bc -l 2>/dev/null || echo 1) )); then
            echo "Normal"
        elif (( $(echo "$load1 < $((cores * 2))" | bc -l 2>/dev/null || echo 0) )); then
            echo "Elevated"
        else
            echo "High"
        fi
    else
        # Fallback to integer comparison
        local load_int="${load1%%.*}"
        if [[ "$load_int" -lt "$cores" ]]; then
            echo "Normal"
        elif [[ "$load_int" -lt "$((cores * 2))" ]]; then
            echo "Elevated"
        else
            echo "High"
        fi
    fi
}

# Get memory usage percentage (rough estimate)
# Returns: Percentage of memory used
get_memory_usage_percent() {
    # This would require parsing vm_stat for accurate results
    # For now, return a placeholder
    echo "0"
}

# Export all functions
export -f get_cpu_cores get_physical_cpu_cores get_logical_cpu_cores get_cpu_brand
export -f get_total_memory_bytes get_total_memory_gb get_total_memory_mb get_memory_pressure
export -f get_load_averages get_load_1min get_load_5min get_load_15min
export -f get_uptime_seconds get_uptime_string
export -f get_disk_usage get_tm_disk_usage
export -f get_primary_interface get_interface_ip
export -f get_process_count get_user_process_count
export -f get_cpu_temperature
export -f is_system_loaded get_load_status get_memory_usage_percent
