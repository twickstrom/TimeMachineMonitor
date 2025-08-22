#!/usr/bin/env bash
# lib/process.sh - Process and signal management for tm-monitor

# Source dependencies
[[ -z "$(type -t get_version)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
[[ -z "$(type -t determine_paths)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
[[ -z "$(type -t debug)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Process tracking
HELPER_PID=""
MONITOR_PID="$$"
CLEANUP_DONE=false
ORIGINAL_STTY=""

# Initialize process management
init_process_management() {
    # Save terminal settings
    if [[ -t 0 ]]; then
        ORIGINAL_STTY="$(stty -g 2>/dev/null || true)"
        # Disable echo of control characters
        stty -echoctl 2>/dev/null || true
    fi

    # Create PID file
    mkdir -p "$TM_CACHE_DIR"
    echo "$MONITOR_PID" > "$TM_PID_FILE"

    # Set up signal handlers
    trap 'cleanup_and_exit' INT TERM QUIT EXIT
    # Remove ERR trap for now - it's causing issues
    # trap 'handle_error $? $LINENO' ERR
}

# Start Python helper process
start_helper_process() {
    local helper_script="$1"

    if [[ ! -x "$helper_script" ]]; then
        fatal "Helper script not found or not executable: $helper_script"
    fi

    # Ensure directories exist
    ensure_directories
    mkdir -p "$TM_DATA_DIR/logs"

    # Create named pipes for communication
    local pipe_in="$TM_CACHE_DIR/helper.in"
    local pipe_out="$TM_CACHE_DIR/helper.out"

    rm -f "$pipe_in" "$pipe_out"
    mkfifo "$pipe_in" "$pipe_out"

    # Start helper process
    debug "Starting helper process: $helper_script"
    "$helper_script" < "$pipe_in" > "$pipe_out" 2>"$TM_DATA_DIR/logs/helper.log" &
    HELPER_PID=$!

    # Keep pipes open
    exec 3>"$pipe_in"
    exec 4<"$pipe_out"

    # Verify it started
    sleep 0.5
    if ! kill -0 "$HELPER_PID" 2>/dev/null; then
        fatal "Failed to start helper process"
    fi

    debug "Helper process started with PID: $HELPER_PID"

    # Export pipe paths
    export HELPER_PIPE_IN="$pipe_in"
    export HELPER_PIPE_OUT="$pipe_out"
}

# Send command to helper process
send_to_helper() {
    local command="$1"

    if [[ -z "$HELPER_PID" ]] || ! kill -0 "$HELPER_PID" 2>/dev/null; then
        debug "Helper process not running (PID: $HELPER_PID)"
        return 1
    fi

    # Use file descriptor 3 which we opened earlier
    echo "$command" >&3
}

# Read response from helper process
read_from_helper() {
    local timeout="${1:-5}"

    if [[ ! -p "$HELPER_PIPE_OUT" ]]; then
        error "Helper pipe not available"
        return 1
    fi

    # Read with timeout
    local response
    if read -t "$timeout" response < "$HELPER_PIPE_OUT"; then
        echo "$response"
    else
        error "Timeout reading from helper process"
        return 1
    fi
}

# Stop helper process gracefully
stop_helper_process() {
    [[ -z "$HELPER_PID" ]] && return 0

    if kill -0 "$HELPER_PID" 2>/dev/null; then
        debug "Stopping helper process (PID: $HELPER_PID)"

        # Try graceful shutdown first
        send_to_helper "QUIT" 2>/dev/null || true

        # Give it time to exit cleanly
        local count=0
        while (( count < 10 )) && kill -0 "$HELPER_PID" 2>/dev/null; do
            sleep 0.1
            ((count++))
        done

        # Force kill if still running
        if kill -0 "$HELPER_PID" 2>/dev/null; then
            debug "Force killing helper process"
            kill -KILL "$HELPER_PID" 2>/dev/null || true
        fi
    fi

    HELPER_PID=""
}

# Error handler
handle_error() {
    local exit_code="$1"
    local line_number="$2"

    error "Error occurred (exit code: $exit_code) at line $line_number"
    debug "Stack trace: ${BASH_SOURCE[*]}"
    debug "Function stack: ${FUNCNAME[*]}"
}

# Cleanup function
cleanup_and_exit() {
    # Prevent double cleanup
    [[ "$CLEANUP_DONE" == "true" ]] && exit 0
    CLEANUP_DONE=true

    debug "Starting cleanup..."

    # Clear current line
    printf "\r\033[K"
    
    # Print bottom border if we were showing the table
    if [[ -n "${SESSION_START_TIME:-}" ]]; then
        print_footer
    fi

    # Stop helper process
    stop_helper_process

    # Remove PID file
    rm -f "$TM_PID_FILE"

    # Clean up pipes
    rm -f "$TM_CACHE_DIR"/helper.{in,out}

    # Restore terminal settings
    if [[ -n "$ORIGINAL_STTY" ]]; then
        stty "$ORIGINAL_STTY" 2>/dev/null || true
    fi

    # Show summary if enabled
    if [[ "$SHOW_SUMMARY" == "true" ]] && [[ -n "${SESSION_START_TIME:-}" ]]; then
        echo
        get_session_summary
        
        if [[ "$CSV_LOG" == "true" ]] && [[ -n "${CSV_LOG_FILE:-}" ]]; then
            info "CSV log: $CSV_LOG_FILE"
        fi
    fi

    debug "Cleanup complete"
    exit 0
}

# Check if another instance is running
check_single_instance() {
    if [[ -f "$TM_PID_FILE" ]]; then
        local old_pid
        old_pid="$(cat "$TM_PID_FILE" 2>/dev/null)"

        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            fatal "Another instance is already running (PID: $old_pid)"
        else
            # Stale PID file, remove it
            rm -f "$TM_PID_FILE"
        fi
    fi
}

# Export functions
export -f init_process_management start_helper_process send_to_helper
export -f read_from_helper stop_helper_process cleanup_and_exit
export -f check_single_instance handle_error
# Note: check_dependencies is now provided by dependencies.sh module
