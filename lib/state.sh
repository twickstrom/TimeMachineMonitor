#!/usr/bin/env bash
# lib/state.sh - State management for tm-monitor

# Source dependencies
[[ -z "${TM_MONITOR_VERSION:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
[[ -z "$(type -t log_message)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"

# Session state variables
SESSION_START_TIME=""
SESSION_LAST_UPDATE=""
SESSION_TOTAL_BYTES=0
SESSION_TOTAL_FILES=0
SESSION_SAMPLE_COUNT=0
SESSION_FAILURE_COUNT=0

# Previous iteration state
PREV_TIMESTAMP=""
PREV_BYTES=0
PREV_FILES=0
PREV_SPEED="-"
PREV_ETA="-"
PREV_PHASE=""

# Current iteration state
CURRENT_TIMESTAMP=""
CURRENT_PHASE=""
CURRENT_BYTES=0
CURRENT_FILES=0
CURRENT_TOTAL_BYTES=0
CURRENT_PERCENT=0
CURRENT_SPEED="-"
CURRENT_FILES_PER_SEC="-"
CURRENT_BYTES_PER_SEC=0
CURRENT_BATCH_TOTAL=0
CURRENT_COPIED_BATCH="-"
CURRENT_PCT_BATCH="-"
CURRENT_COPIED_TOTAL="-"
CURRENT_PCT_TOTAL="-"
CURRENT_ETA="-"

# Initialize SPEED_SAMPLES to avoid unbound variable
: ${SPEED_SAMPLES:=}

# Speed samples for averaging
SPEED_SAMPLES=()
MAX_SPEED_SAMPLES=30

# Initialize session state
init_session() {
    SESSION_START_TIME="$(date +%s)"
    SESSION_LAST_UPDATE="$(date +%s)"
}

# Update state from tmutil data
update_state() {
    local json_data="$1"

    # Store previous state
    PREV_TIMESTAMP="$CURRENT_TIMESTAMP"
    PREV_BYTES="$CURRENT_BYTES"
    PREV_FILES="$CURRENT_FILES"
    PREV_SPEED="$CURRENT_SPEED"
    PREV_ETA="$CURRENT_ETA"
    PREV_PHASE="$CURRENT_PHASE"

    # Parse new data via helper or inline
    if [[ -n "$HELPER_PID" ]]; then
        if ! _update_via_helper "$json_data"; then
            _update_inline "$json_data"
        fi
    else
        _update_inline "$json_data"
    fi

    # Update session statistics
    SESSION_LAST_UPDATE="$(date +%s)"
    ((SESSION_SAMPLE_COUNT++))

    # Track speed samples
    if [[ "$CURRENT_BYTES_PER_SEC" -gt 0 ]]; then
        SPEED_SAMPLES+=("$CURRENT_BYTES_PER_SEC")
        # Keep only recent samples
        if (( "${#SPEED_SAMPLES[@]}" > "$MAX_SPEED_SAMPLES" )); then
            SPEED_SAMPLES=("${SPEED_SAMPLES[@]:1}")
        fi
    fi
}

# Update state via helper process
_update_via_helper() {
    local json_data="$1"

    # Send JSON to helper
    if ! send_to_helper "$json_data"; then
        return 1
    fi

    # Read parsed response
    local response
    if ! response="$(read_from_helper 2)"; then
        ((SESSION_FAILURE_COUNT++))
        return 1
    fi

    # Parse response into state
    _parse_helper_response "$response"
}

# Parse helper response
_parse_helper_response() {
    local response="$1"
    local -a fields

    # Split response on delimiter
    IFS='|' read -ra fields <<< "$response"

    # Map to state variables
    CURRENT_TIMESTAMP="${fields[0]:-}"
    CURRENT_PHASE="${fields[1]:-}"
    CURRENT_BYTES="${fields[2]:-0}"
    CURRENT_FILES="${fields[3]:-0}"
    CURRENT_TOTAL_BYTES="${fields[4]:-0}"
    CURRENT_PERCENT="${fields[5]:-0}"
    CURRENT_SPEED="${fields[6]:--}"
    CURRENT_FILES_PER_SEC="${fields[7]:--}"
    CURRENT_BYTES_PER_SEC="${fields[8]:-0}"
    CURRENT_COPIED_BATCH="${fields[9]:--}"
    CURRENT_PCT_BATCH="${fields[10]:--}"
    CURRENT_COPIED_TOTAL="${fields[11]:--}"
    CURRENT_PCT_TOTAL="${fields[12]:--}"
    CURRENT_ETA="${fields[13]:--}"
}

# Calculate average speed
get_average_speed() {
    local total=0
    local count="${#SPEED_SAMPLES[@]}"
    local speed

    [[ "$count" -eq 0 ]] && echo "0" && return 0

    if [[ ${#SPEED_SAMPLES[@]} -gt 0 ]]; then
        for speed in "${SPEED_SAMPLES[@]}"; do
            ((total += speed))
        done
    fi

    echo "$((total / count))"
    return 0
}

# Get session duration
get_session_duration() {
    local now
    local start="$SESSION_START_TIME"
    
    now="$(date +%s)"
    [[ -z "$start" ]] && echo "0" && return 0
    echo "$((now - start))"
    return 0
}

# Check if backup is running
is_backup_running() {
    [[ "$CURRENT_PHASE" != "BackupNotRunning" ]] && \
    [[ "$CURRENT_PHASE" != "Idle" ]] && \
    [[ -n "$CURRENT_PHASE" ]]
}

# Cache speed/ETA for display continuity
cache_dynamic_values() {
    # Cache speed if valid
    if [[ "$CURRENT_SPEED" != "-" ]]; then
        PREV_SPEED="$CURRENT_SPEED"
    elif [[ "$PREV_SPEED" != "-" ]]; then
        # Use cached value
        CURRENT_SPEED="$PREV_SPEED"
    fi

    # Cache ETA if valid
    if [[ "$CURRENT_ETA" != "-" ]]; then
        PREV_ETA="$CURRENT_ETA"
    elif [[ "$PREV_ETA" != "-" ]]; then
        # Use cached value
        CURRENT_ETA="$PREV_ETA"
    fi
}

# Get session summary
get_session_summary() {
    local duration
    duration="$(get_session_duration)"

    local avg_speed
    avg_speed="$(get_average_speed)"

    # Use centralized formatting for speed
    local avg_speed_mb
    avg_speed_mb="$(format_speed_mbps "$avg_speed")"

    cat <<SUMMARY
Session Summary:
  Duration: $(format_duration "$duration")
  Samples: $SESSION_SAMPLE_COUNT
  Average Speed: ${avg_speed_mb}
  Speed Samples: ${#SPEED_SAMPLES[@]}
  Failures: $SESSION_FAILURE_COUNT

SUMMARY
}

# Inline update (fallback when helper not available)
_update_inline() {
    local json_data="$1"
    
    # Parse JSON using Python inline
    local parsed
    parsed=$(echo "$json_data" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    progress = data.get("Progress", {})
    
    # Output pipe-delimited values
    import time
    values = [
        str(int(time.time())),  # timestamp
        data.get("BackupPhase", "Unknown"),  # phase
        str(progress.get("bytes", 0)),  # bytes
        str(progress.get("files", 0)),  # files
        str(progress.get("totalBytes", 0)),  # total bytes
        str(progress.get("Percent", 0)),  # percent
        "-",  # speed
        "-",  # files per sec
        "0",  # bytes per sec
        "-",  # copied batch
        "-",  # pct batch
        "-",  # copied total
        "-",  # pct total
        "-"   # eta
    ]
    
    # Calculate batch and total if we have data
    if float(progress.get("Percent", 0)) > 0 and progress.get("bytes", 0) > 0:
        percent = float(progress.get("Percent", 0))
        bytes_val = int(progress.get("bytes", 0))
        total = int(progress.get("totalBytes", 0))
        
        batch_total = bytes_val / percent
        gb_copied = bytes_val / (1000**3)
        gb_batch = batch_total / (1000**3)
        gb_total = total / (1000**3)
        
        values[9] = f"{gb_copied:.2f} GB / {gb_batch:.2f} GB"  # copied batch
        values[10] = f"{(percent * 100):.2f}%"  # pct batch
        
        copied_total_bytes = (total - batch_total) + bytes_val
        gb_copied_total = copied_total_bytes / (1000**3)
        values[11] = f"{gb_copied_total:.2f} GB / {gb_total:.2f} GB"  # copied total
        values[12] = f"{(copied_total_bytes / total * 100):.2f}%"  # pct total
    
    print("|".join(values))
except Exception as e:
    print(f"0|Error|0|0|0|0|-|-|0|-|-|-|-|-", file=sys.stderr)
    sys.exit(1)
' 2>/dev/null)
    
    if [[ -n "$parsed" ]]; then
        _parse_helper_response "$parsed"
    else
        debug "Failed to parse JSON inline"
        return 1
    fi
}

# Export functions
export -f init_session update_state get_average_speed get_session_duration
export -f is_backup_running cache_dynamic_values get_session_summary
