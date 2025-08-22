#!/usr/bin/env bash
# lib/config.sh - Configuration management for tm-monitor

# Source dependencies
[[ -z "$(type -t determine_paths)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
[[ -z "${DEFAULT_INTERVAL:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
[[ -z "$(type -t debug)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Configuration variables (global without -g flag for bash 3.2 compatibility)
INTERVAL=""
UNITS=""
SHOW_COLORS=""
SHOW_SUMMARY=""
DEBUG=""
CSV_LOG=""
MAX_FAILURES=""

# Load configuration from file and command line
load_config() {
    # Set defaults first
    INTERVAL="${DEFAULT_INTERVAL}"
    UNITS="${DEFAULT_UNITS}"
    SHOW_COLORS="${DEFAULT_SHOW_COLORS}"
    SHOW_SUMMARY="${DEFAULT_SHOW_SUMMARY}"
    DEBUG="${DEFAULT_DEBUG}"
    CSV_LOG="${DEFAULT_CSV_LOG}"
    MAX_FAILURES="${DEFAULT_MAX_FAILURES}"
    
    # Load from config file if exists
    if [[ -f "$TM_CONFIG_FILE" ]]; then
        debug "Loading config from $TM_CONFIG_FILE"
        _parse_config_file "$TM_CONFIG_FILE"
    fi
    
    # Override with environment variables if set
    [[ -n "${TM_INTERVAL:-}" ]] && INTERVAL="$TM_INTERVAL"
    [[ -n "${TM_UNITS:-}" ]] && UNITS="$TM_UNITS"
    [[ -n "${TM_DEBUG:-}" ]] && DEBUG="$TM_DEBUG"
    [[ -n "${TM_CSV_LOG:-}" ]] && CSV_LOG="$TM_CSV_LOG"
    [[ -n "${TM_SHOW_COLORS:-}" ]] && SHOW_COLORS="$TM_SHOW_COLORS"
    [[ -n "${TM_SHOW_SUMMARY:-}" ]] && SHOW_SUMMARY="$TM_SHOW_SUMMARY"
    
    # Validate configuration
    _validate_config
}

# Parse configuration file safely
_parse_config_file() {
    local file="$1"
    local line key value
    
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${key// }" ]] && continue
        
        # Trim whitespace
        key="${key// /}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        
        # Validate key names (security)
        case "$key" in
            INTERVAL|UNITS|SHOW_COLORS|SHOW_SUMMARY|DEBUG|CSV_LOG|MAX_FAILURES)
                # Validate value format
                if [[ ! "$value" =~ ^[a-zA-Z0-9_./\-]+$ ]]; then
                    warn "Invalid characters in config value for $key: $value"
                    continue
                fi
                
                # Assign validated value WITHOUT eval (safer)
                case "$key" in
                    INTERVAL) INTERVAL="$value" ;;
                    UNITS) UNITS="$value" ;;
                    SHOW_COLORS) SHOW_COLORS="$value" ;;
                    SHOW_SUMMARY) SHOW_SUMMARY="$value" ;;
                    DEBUG) DEBUG="$value" ;;
                    CSV_LOG) CSV_LOG="$value" ;;
                    MAX_FAILURES) MAX_FAILURES="$value" ;;
                esac
                debug "Config: $key = $value"
                ;;
            *)
                debug "Ignoring unknown config key: $key"
                ;;
        esac
    done < "$file"
}

# Validate configuration values
_validate_config() {
    local errors=()
    
    # Validate interval
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || (( INTERVAL < 1 || INTERVAL > 300 )); then
        errors+=("INTERVAL must be 1-300 seconds (got: $INTERVAL)")
    fi
    
    # Validate units
    if [[ "$UNITS" != "1000" && "$UNITS" != "1024" ]]; then
        errors+=("UNITS must be 1000 or 1024 (got: $UNITS)")
    fi
    
    # Validate booleans
    for var in SHOW_COLORS SHOW_SUMMARY DEBUG CSV_LOG; do
        local value="${!var}"
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            errors+=("$var must be true or false (got: $value)")
        fi
    done
    
    # Validate max failures
    if ! [[ "$MAX_FAILURES" =~ ^[0-9]+$ ]] || (( MAX_FAILURES < 1 || MAX_FAILURES > 10 )); then
        errors+=("MAX_FAILURES must be 1-10 (got: $MAX_FAILURES)")
    fi
    
    # Report errors
    if (( ${#errors[@]} > 0 )); then
        error "Configuration validation failed:"
        for err in "${errors[@]}"; do
            error "  - $err"
        done
        return 1
    fi
    
    return 0
}

# Create sample configuration file
create_sample_config() {
    mkdir -p "$TM_CONFIG_DIR"
    
    cat > "$TM_CONFIG_FILE.example" << EOF
# TM-Monitor Configuration
# Copy to $TM_CONFIG_FILE to use

# Update interval in seconds (1-300)
INTERVAL=$DEFAULT_INTERVAL

# Size units: 1000 (SI/GB) or 1024 (IEC/GiB)
UNITS=$DEFAULT_UNITS

# Show colored output (true/false)
SHOW_COLORS=$DEFAULT_SHOW_COLORS

# Show session summary on exit (true/false)
SHOW_SUMMARY=$DEFAULT_SHOW_SUMMARY

# Enable debug logging (true/false)
DEBUG=$DEFAULT_DEBUG

# Enable CSV logging (true/false)
CSV_LOG=$DEFAULT_CSV_LOG

# Maximum tmutil failures before giving up (1-10)
MAX_FAILURES=$DEFAULT_MAX_FAILURES

# Smoothing window in seconds (default: 30, or 90 for initial backups)
# SPEED_WINDOW=30
# INITIAL_BACKUP_WINDOW=90
EOF
    
    info "Sample configuration created at: $TM_CONFIG_FILE.example"
    info "Copy to $TM_CONFIG_FILE to use"
}

# Export functions
export -f load_config create_sample_config
