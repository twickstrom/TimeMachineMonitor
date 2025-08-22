#!/usr/bin/env bash
# lib/tmutil.sh - Centralized tmutil status parsing for tm-monitor
# Refactored to avoid eval and use only macOS 14.x+ built-in tools

# Source dependencies
[[ -z "${DEFAULT_INTERVAL:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
[[ -z "$(type -t debug)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"

# Cache for last tmutil status to avoid repeated calls
TMUTIL_CACHE_TIME=0
TMUTIL_CACHE_DATA=""
TMUTIL_CACHE_TTL=1  # seconds

# Global variables to store parsed tmutil data (safer than eval)
TM_RUNNING=0
TM_PHASE=""
TM_BYTES=0
TM_TOTAL_BYTES=0
TM_PERCENT=0
TM_FILES=0
TM_TOTAL_FILES=0
TM_DATE_CHANGE=""
TM_DESTINATION=""
TM_DESTINATION_ID=""
TM_FIRST_BACKUP=0
TM_TIME_REMAINING=0
TM_STOPPING=0
TM_NUMBER_OF_CHANGED_ITEMS=0
TM_FRACTION_OF_PROGRESS_BAR=0
TM_ATTEMPT_OPTIONS=0
TM_RAW_PERCENT=0
TM_RAW_TOTAL_BYTES=0

# Get raw tmutil status output
get_tmutil_raw() {
    local output
    output="$(tmutil status 2>/dev/null || echo "")"
    
    [[ -z "$output" ]] && return 1
    
    # Check if it says "Not running" as a single line
    if [[ "$output" == "Not running" ]]; then
        return 1
    fi
    
    echo "$output"
    return 0
}

# Get tmutil status as JSON (with caching)
get_tmutil_json() {
    local current_time=$(date +%s)
    
    # Check cache
    if [[ -n "$TMUTIL_CACHE_DATA" ]] && (( current_time - TMUTIL_CACHE_TIME < TMUTIL_CACHE_TTL )); then
        echo "$TMUTIL_CACHE_DATA"
        return 0
    fi
    
    # Get fresh data
    local raw_output
    raw_output=$(get_tmutil_raw) || return 1
    
    # Convert to JSON using plutil
    local json_output
    json_output=$(echo "$raw_output" | sed -n '/^{/,/^}$/p' | plutil -convert json -o - - 2>/dev/null)
    
    if [[ -z "$json_output" ]]; then
        debug "Failed to convert tmutil output to JSON"
        return 1
    fi
    
    # Update cache
    TMUTIL_CACHE_TIME="$current_time"
    TMUTIL_CACHE_DATA="$json_output"
    
    echo "$json_output"
    return 0
}

# Parse tmutil status into global variables (no eval needed)
parse_tmutil_status() {
    local json_data="${1:-}"
    local python_cmd="${TM_PYTHON_CMD:-python3}"
    
    # If no JSON provided, get it
    if [[ -z "$json_data" ]]; then
        json_data="$(get_tmutil_json)" || return 1
    fi
    
    # Parse with Python using a temp file to avoid quote issues
    local temp_script="/tmp/tmutil_parse_$$.py"
    cat > "$temp_script" << 'PYTHON_EOF'
import json, sys

try:
    data = json.load(sys.stdin)
    
    # Extract all relevant fields (handle string conversions from plutil)
    running = int(data.get("Running", "0"))
    phase = data.get("BackupPhase", "Unknown")
    progress = data.get("Progress", {})
    
    # Progress dictionary fields (convert strings to numbers)
    bytes_val = int(float(progress.get("bytes", "0")))
    total_bytes = int(float(progress.get("totalBytes", "0")))
    percent = float(progress.get("Percent", "0.0"))
    files = int(float(progress.get("files", "0")))
    total_files = int(float(progress.get("totalFiles", "0")))
    time_remaining = int(float(progress.get("TimeRemaining", "0")))
    raw_percent = float(progress.get("_raw_Percent", str(percent)))
    raw_total_bytes = int(float(progress.get("_raw_totalBytes", str(total_bytes))))
    
    # Top-level metadata
    date_change = data.get("DateOfStateChange", "")
    destination = data.get("DestinationMountPoint", "")
    destination_id = data.get("DestinationID", "")
    first_backup = int(data.get("FirstBackup", "0"))
    stopping = int(data.get("Stopping", "0"))
    number_of_changed = int(float(data.get("NumberOfChangedItems", "0")))
    fraction_progress = float(data.get("FractionOfProgressBar", "0.0"))
    attempt_opts = int(data.get("attemptOptions", "0"))
    
    # Output tab-separated values for easy parsing
    output = "\t".join(str(x) for x in [
        running, phase, bytes_val, total_bytes, percent, files, total_files, 
        time_remaining, date_change, destination, destination_id, first_backup, 
        stopping, number_of_changed, fraction_progress, attempt_opts, 
        raw_percent, raw_total_bytes
    ])
    print(output)
    
except Exception as e:
    print("0\tError\t0\t0\t0\t0\t0\t0\t\t\t\t0\t0\t0\t0\t0\t0\t0", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
    
    local parsed_output
    parsed_output=$(echo "$json_data" | "$python_cmd" "$temp_script" 2>/dev/null)
    rm -f "$temp_script"
    
    if [[ -z "$parsed_output" ]]; then
        debug "Failed to parse tmutil JSON"
        return 1
    fi
    
    # Parse tab-separated values into global variables
    IFS=$'\t' read -r TM_RUNNING TM_PHASE TM_BYTES TM_TOTAL_BYTES TM_PERCENT TM_FILES TM_TOTAL_FILES TM_TIME_REMAINING TM_DATE_CHANGE TM_DESTINATION TM_DESTINATION_ID TM_FIRST_BACKUP TM_STOPPING TM_NUMBER_OF_CHANGED_ITEMS TM_FRACTION_OF_PROGRESS_BAR TM_ATTEMPT_OPTIONS TM_RAW_PERCENT TM_RAW_TOTAL_BYTES <<< "$parsed_output"
    
    # Ensure numeric values are actually numeric
    TM_RUNNING="${TM_RUNNING:-0}"
    TM_BYTES="${TM_BYTES:-0}"
    TM_TOTAL_BYTES="${TM_TOTAL_BYTES:-0}"
    TM_PERCENT="${TM_PERCENT:-0}"
    TM_FILES="${TM_FILES:-0}"
    TM_TOTAL_FILES="${TM_TOTAL_FILES:-0}"
    TM_TIME_REMAINING="${TM_TIME_REMAINING:-0}"
    TM_FIRST_BACKUP="${TM_FIRST_BACKUP:-0}"
    TM_STOPPING="${TM_STOPPING:-0}"
    TM_NUMBER_OF_CHANGED_ITEMS="${TM_NUMBER_OF_CHANGED_ITEMS:-0}"
    TM_FRACTION_OF_PROGRESS_BAR="${TM_FRACTION_OF_PROGRESS_BAR:-0}"
    TM_ATTEMPT_OPTIONS="${TM_ATTEMPT_OPTIONS:-0}"
    TM_RAW_PERCENT="${TM_RAW_PERCENT:-0}"
    TM_RAW_TOTAL_BYTES="${TM_RAW_TOTAL_BYTES:-0}"
    
    return 0
}

# Get simplified status for display (returns formatted string, no eval needed)
get_tmutil_simple_status() {
    # Parse the status into global variables
    if ! parse_tmutil_status; then
        # Return not running status when parse fails
        echo "Not Running|Not Running|0|0|0"
        return 1
    fi
    
    # Format phase for display
    local display_phase="${TM_PHASE:-Unknown}"
    case "${TM_PHASE:-}" in
        Copying) 
            display_phase="Copying Files" 
            ;;
        ThinningPreBackup) 
            display_phase="Thinning Pre" 
            ;;
        ThinningPostBackup) 
            display_phase="Thinning Post" 
            ;;
        DeletingOldBackups) 
            display_phase="Deleting Old" 
            ;;
        Starting) 
            display_phase="Starting" 
            ;;
        Finishing) 
            display_phase="Finishing" 
            ;;
        BackupNotRunning) 
            display_phase="Not Running" 
            ;;
        MountingDiskImage) 
            display_phase="Mounting" 
            ;;
        "") 
            display_phase="Unknown" 
            ;;
    esac
    
    # Add preparation info if in Starting phase
    if [[ "$TM_PHASE" == "Starting" ]] && [[ "$TM_NUMBER_OF_CHANGED_ITEMS" -gt 0 ]]; then
        display_phase="Preparing - ${TM_NUMBER_OF_CHANGED_ITEMS} items"
    fi
    
    # Calculate sizes in GB using centralized formatting
    local size_gb="0.00"
    local total_gb="0.00"
    if [[ "${TM_BYTES:-0}" -gt 0 ]]; then
        # Extract just the number from format_bytes output (e.g., "1.23 GB" -> "1.23")
        local formatted_size
        formatted_size=$(format_bytes "${TM_BYTES}" "GB" 2)
        size_gb="${formatted_size%% *}"
    fi
    if [[ "${TM_TOTAL_BYTES:-0}" -gt 0 ]]; then
        local formatted_total
        formatted_total=$(format_bytes "${TM_TOTAL_BYTES}" "GB" 2)
        total_gb="${formatted_total%% *}"
    fi
    
    # Calculate percentage with standardized formatting
    local percent_display="0.00"
    if [[ -n "${TM_PERCENT:-}" ]]; then
        local percent_value
        if command -v bc >/dev/null 2>&1; then
            percent_value=$(echo "${TM_PERCENT} * 100" | bc 2>/dev/null || echo "0")
        else
            percent_value="0"
        fi
        percent_display=$(format_decimal "$percent_value" 2 "0.00")
    fi
    
    # Determine status - check for stopping
    local status="Not Running"
    if [[ "${TM_STOPPING:-0}" == "1" ]]; then
        status="Stopping"
    elif [[ "${TM_RUNNING:-0}" == "1" ]]; then
        status="Running"
    elif [[ "${TM_PHASE:-}" != "BackupNotRunning" ]] && [[ -n "${TM_PHASE:-}" ]] && [[ "${TM_PHASE:-}" != "Unknown" ]]; then
        status="Idle"
    fi
    
    # Return pipe-separated values for easy parsing
    echo "${status}|${display_phase}|${percent_display}|${size_gb}|${total_gb}"
    return 0
}

# Get detailed tmutil info as structured text
get_tmutil_detailed() {
    # Parse the status
    if ! parse_tmutil_status; then
        return 1
    fi
    
    # Format output
    cat <<EOF
Running: ${TM_RUNNING}
Phase: ${TM_PHASE}
Bytes: ${TM_BYTES}
TotalBytes: ${TM_TOTAL_BYTES}
Percent: ${TM_PERCENT}
Files: ${TM_FILES}
TotalFiles: ${TM_TOTAL_FILES}
TimeRemaining: ${TM_TIME_REMAINING}
DateChange: ${TM_DATE_CHANGE}
Destination: ${TM_DESTINATION}
DestinationID: ${TM_DESTINATION_ID}
FirstBackup: ${TM_FIRST_BACKUP}
Stopping: ${TM_STOPPING}
NumberOfChangedItems: ${TM_NUMBER_OF_CHANGED_ITEMS}
FractionOfProgressBar: ${TM_FRACTION_OF_PROGRESS_BAR}
AttemptOptions: ${TM_ATTEMPT_OPTIONS}
EOF
}

# Check if Time Machine is running
is_tm_running() {
    local json_data
    json_data=$(get_tmutil_json 2>/dev/null) || return 1
    
    # Quick check for Running flag (handle both "1" and 1)
    echo "$json_data" | grep -qE '"Running"\s*:\s*"?1"?'
}

# Get backup phase
get_tm_phase() {
    parse_tmutil_status >/dev/null 2>&1 || echo "Unknown"
    echo "${TM_PHASE:-Unknown}"
}

# Calculate speed from byte deltas
calculate_tm_speed() {
    local prev_bytes="${1:-0}"
    local curr_bytes="${2:-0}"
    local prev_time="${3:-0}"
    local curr_time="${4:-0}"
    local units="${5:-1000}"  # Not used anymore, kept for compatibility
    
    local delta_bytes=$((curr_bytes - prev_bytes))
    local delta_time=$((curr_time - prev_time))
    
    if [[ $delta_time -gt 0 ]] && [[ $delta_bytes -ge 0 ]]; then
        local bytes_per_sec=$((delta_bytes / delta_time))
        # Use centralized formatting which respects UNITS config
        format_speed_mbps "$bytes_per_sec"
    else
        echo "0.00 MB/s"
    fi
}

# Format time remaining is now provided by formatting.sh
# Keep this for backward compatibility only
# The formatting.sh version (format_eta) is already aliased as format_time_remaining

# Get enhanced status with all available info
get_tmutil_enhanced_status() {
    # Parse the status
    if ! parse_tmutil_status; then
        return 1
    fi
    
    # Build enhanced status output
    cat <<EOF
Status: $([ "$TM_RUNNING" == "1" ] && echo "Running" || echo "Not Running")
Phase: ${TM_PHASE}
Stopping: $([ "$TM_STOPPING" == "1" ] && echo "Yes" || echo "No")

Progress:
  Bytes: ${TM_BYTES} / ${TM_TOTAL_BYTES}
  Files: ${TM_FILES} / ${TM_TOTAL_FILES}
  Percent: $(format_percentage "$(echo "${TM_PERCENT} * 100" | bc 2>/dev/null || echo "0")" true "0.00")
  ETA: $(format_time_remaining "$TM_TIME_REMAINING")
  
Preparation:
  Changed Items: ${TM_NUMBER_OF_CHANGED_ITEMS}
  
Backup Details:
  First Backup: $([ "$TM_FIRST_BACKUP" == "1" ] && echo "Yes" || echo "No")
  Destination: ${TM_DESTINATION}
  Destination ID: ${TM_DESTINATION_ID}
  Started: ${TM_DATE_CHANGE}
  
Internal:
  Attempt Options: ${TM_ATTEMPT_OPTIONS} (0x$(printf "%x" "$TM_ATTEMPT_OPTIONS" 2>/dev/null || echo "0"))
  Progress Bar Fraction: ${TM_FRACTION_OF_PROGRESS_BAR}
  Raw Percent: ${TM_RAW_PERCENT}
  Raw Total Bytes: ${TM_RAW_TOTAL_BYTES}
EOF
}

# Get backup metadata for display (returns formatted text)
get_tm_metadata() {
    local json_data="${1:-}"
    
    # If no JSON provided, get it
    if [[ -z "$json_data" ]]; then
        json_data=$(get_tmutil_json) || return 1
    fi
    
    # Parse the status first
    parse_tmutil_status "$json_data" || return 1
    
    # Format output using bash instead of Python
    local backup_type="Incremental Backup"
    [[ "$TM_FIRST_BACKUP" == "1" ]] && backup_type="Initial Backup"
    
    echo "Type: $backup_type"
    echo "Started: ${TM_DATE_CHANGE:-Unknown}"
    
    # Clean up destination path
    local clean_dest="${TM_DESTINATION#/Volumes/}"
    echo "Destination: ${clean_dest:-Unknown}"
    
    if [[ -n "$TM_DESTINATION_ID" ]]; then
        echo "Destination ID: ${TM_DESTINATION_ID:0:8}..."
    fi
    
    if [[ "$TM_ATTEMPT_OPTIONS" -gt 0 ]]; then
        printf "Attempt Options: %d [0x%x]\n" "$TM_ATTEMPT_OPTIONS" "$TM_ATTEMPT_OPTIONS"
    fi
}

# Export functions
export -f get_tmutil_raw get_tmutil_json parse_tmutil_status
export -f get_tmutil_simple_status is_tm_running get_tm_phase
export -f calculate_tm_speed get_tm_metadata get_tmutil_detailed
export -f get_tmutil_enhanced_status

# Export global variables for use in other scripts
export TM_RUNNING TM_PHASE TM_BYTES TM_TOTAL_BYTES TM_PERCENT
export TM_FILES TM_TOTAL_FILES TM_TIME_REMAINING
export TM_DATE_CHANGE TM_DESTINATION TM_DESTINATION_ID TM_FIRST_BACKUP
export TM_STOPPING TM_NUMBER_OF_CHANGED_ITEMS TM_FRACTION_OF_PROGRESS_BAR
export TM_ATTEMPT_OPTIONS TM_RAW_PERCENT TM_RAW_TOTAL_BYTES
