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
            --kill-all)
                kill_all_tm_monitor
                exit 0
                ;;
            --no-auto-start)
                export TM_NO_AUTO_START="true"
                shift
                ;;
            --update)
                # Load update module if not already loaded
                [[ -z "$(type -t install_update_interactive)" ]] && source "$TM_LIB_DIR/updates.sh"
                install_update_interactive
                exit $?
                ;;
            --update-check)
                # Load update module if not already loaded
                [[ -z "$(type -t force_update_check)" ]] && source "$TM_LIB_DIR/updates.sh"
                force_update_check
                exit 0
                ;;
            --update-disable)
                # Load update module if not already loaded
                [[ -z "$(type -t disable_update_checks)" ]] && source "$TM_LIB_DIR/updates.sh"
                disable_update_checks
                exit 0
                ;;
            --update-enable)
                # Load update module if not already loaded
                [[ -z "$(type -t enable_update_checks)" ]] && source "$TM_LIB_DIR/updates.sh"
                enable_update_checks
                exit 0
                ;;
            --update-snooze)
                # Load update module if not already loaded
                [[ -z "$(type -t snooze_updates)" ]] && source "$TM_LIB_DIR/updates.sh"
                # Get the number of days (optional, default 7)
                local days="7"
                if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    days="$2"
                    shift
                fi
                snooze_updates "$days"
                exit 0
                ;;
            --update-settings)
                # Load update module if not already loaded
                [[ -z "$(type -t show_update_settings)" ]] && source "$TM_LIB_DIR/updates.sh"
                show_update_settings
                exit 0
                ;;
            --update-frequency)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --update-frequency requires a value (hourly/daily/weekly/monthly/never)"
                    exit 1
                fi
                # Load update module if not already loaded
                [[ -z "$(type -t set_update_frequency)" ]] && source "$TM_LIB_DIR/updates.sh"
                set_update_frequency "$2"
                shift
                exit 0
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
