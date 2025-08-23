#!/usr/bin/env bash
# lib/arguments.sh - Centralized argument parsing for tm-monitor scripts
#
# This module provides consistent argument parsing across all tm-monitor scripts,
# eliminating duplicate parsing code.

# Prevent multiple sourcing
[[ -n "${_ARGUMENTS_SOURCED:-}" ]] && return 0
export _ARGUMENTS_SOURCED=1

# Parse tm-monitor specific arguments
# Usage: parse_tm_monitor_args "$@"
# Returns: 0 on success, 1 if help requested, 2 if unknown argument
parse_tm_monitor_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interval)
                if [[ $# -lt 2 ]]; then
                    error "Missing value for $1"
                    return 2
                fi
                export TM_INTERVAL="$2"
                shift 2
                ;;
            -u|--units)
                if [[ $# -lt 2 ]]; then
                    error "Missing value for $1"
                    return 2
                fi
                export TM_UNITS="$2"
                shift 2
                ;;
            -w|--window)
                if [[ $# -lt 2 ]]; then
                    error "Missing value for $1"
                    return 2
                fi
                export TM_SPEED_WINDOW="$2"
                export TM_INITIAL_BACKUP_WINDOW="$2"
                shift 2
                ;;
            -c|--no-colors)
                export TM_SHOW_COLORS="false"
                shift
                ;;
            -s|--no-summary)
                export TM_SHOW_SUMMARY="false"
                shift
                ;;
            -d|--debug)
                export TM_DEBUG="true"
                shift
                ;;
            -l|--csv-log)
                export TM_CSV_LOG="true"
                shift
                ;;
            -C|--create-config)
                create_sample_config
                exit 0
                ;;
            -v|--version)
                get_version_info
                exit 0
                ;;
            -h|--help)
                return 1  # Signal that help was requested
                ;;
            *)
                error "Unknown option: $1 (use --help for usage)"
                return 2
                ;;
        esac
    done
    return 0
}

# Parse tm-monitor-resources specific arguments
# Usage: parse_resources_args "$@"
# Returns: 0 on success, 1 if help requested, 2 if unknown argument
parse_resources_args() {
    # Initialize resource-specific defaults
    export WATCH_MODE=false
    export INTERVAL=2
    export USE_COLORS=true
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--watch)
                export WATCH_MODE=true
                shift
                ;;
            -i|--interval)
                if [[ $# -lt 2 ]]; then
                    error "Missing value for $1"
                    return 2
                fi
                export INTERVAL="$2"
                shift 2
                ;;
            -c|--no-colors)
                export USE_COLORS=false
                export SHOW_COLORS=false  # For compatibility
                shift
                ;;
            -v|--version)
                echo "tm-monitor-resources version $(get_version)"
                exit 0
                ;;
            -h|--help)
                return 1  # Signal that help was requested
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information" >&2
                return 2
                ;;
        esac
    done
    
    # Validate interval
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || (( INTERVAL < 1 || INTERVAL > 60 )); then
        error "Interval must be 1-60 seconds (got: $INTERVAL)"
        return 2
    fi
    
    return 0
}

# Export functions
export -f parse_tm_monitor_args parse_resources_args
