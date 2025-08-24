#!/usr/bin/env bash
# lib/display.sh - Display and UI functions for tm-monitor

# Source dependencies
[[ -z "$TM_MONITOR_VERSION" ]] && source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
[[ -z "$(type -t log_message)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"
[[ -z "$(type -t get_tm_metadata)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/tmutil.sh"
[[ -z "$(type -t CURRENT_STATE)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
[[ -z "$(type -t get_terminal_width)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/terminal.sh"

# Display state
TABLE_WIDTH=0
TERMINAL_WIDTH=80
# Initialize arrays to avoid unbound variable errors
: ${COLUMN_HEADERS:=}
: ${COLUMN_WIDTHS:=}
: ${COLUMN_ALIGNS:=}
COLUMN_HEADERS=()
COLUMN_WIDTHS=()
COLUMN_ALIGNS=()

# Cached display elements
TOP_BORDER=""
MIDDLE_BORDER=""
BOTTOM_BORDER=""
ROW_FORMAT=""

# Initialize display system
init_display() {
    # Parse table definition
    _parse_table_definition

    # Calculate table width
    TABLE_WIDTH=$(calculate_minimum_width)

    # Check terminal width (using centralized function)
    TERMINAL_WIDTH=$(get_terminal_width)
    _check_terminal_fit

    # Generate borders and format strings
    _generate_display_cache

    debug "Display initialized: terminal=$TERMINAL_WIDTH, table=$TABLE_WIDTH"
}

# Parse table column definitions
_parse_table_definition() {
    local header width align

    if [[ ${#TABLE_COLUMNS[@]} -gt 0 ]]; then
        for definition in "${TABLE_COLUMNS[@]}"; do
            IFS=':' read -r header width align <<< "$definition"
            COLUMN_HEADERS+=("$header")
            COLUMN_WIDTHS+=("$width")
            COLUMN_ALIGNS+=("$align")
        done
    fi
}

# Check if table fits in terminal
_check_terminal_fit() {
    if (( TERMINAL_WIDTH < TABLE_WIDTH )); then
        warn "Terminal width ($TERMINAL_WIDTH) may be too narrow (need $TABLE_WIDTH)"
    fi
}

# Generate cached display elements
_generate_display_cache() {
    TOP_BORDER=$(_generate_border "top")
    MIDDLE_BORDER=$(_generate_border "middle")
    BOTTOM_BORDER=$(_generate_border "bottom")
    ROW_FORMAT=$(_generate_row_format)
    # Make sure nothing is output here
    : # No-op command
}

# Generate border line
_generate_border() {
    local type="$1"  # top, middle, or bottom
    local result=""
    local i
    local width
    local total_width

    if [[ ${#COLUMN_WIDTHS[@]} -gt 0 ]]; then
        for i in "${!COLUMN_WIDTHS[@]}"; do
            width="${COLUMN_WIDTHS[$i]}"
            total_width=$((width + 2))  # Add padding

            if [[ $i -eq 0 ]]; then
                # First column
                case "$type" in
                    top)    result+="$BOX_TOP_LEFT" ;;
                    middle) result+="$BOX_MIDDLE_LEFT" ;;
                    bottom) result+="$BOX_BOTTOM_LEFT" ;;
                esac
            else
                # Middle columns
                case "$type" in
                    top)    result+="$BOX_TOP_MIDDLE" ;;
                    middle) result+="$BOX_MIDDLE" ;;
                    bottom) result+="$BOX_BOTTOM_MIDDLE" ;;
                esac
            fi

            # Add horizontal lines
            for ((j=0; j<total_width; j++)); do
                result+="$BOX_HORIZONTAL"
            done
        done
    fi

    # End piece
    case "$type" in
        top)    result+="$BOX_TOP_RIGHT" ;;
        middle) result+="$BOX_MIDDLE_RIGHT" ;;
        bottom) result+="$BOX_BOTTOM_RIGHT" ;;
    esac

    echo "$result"
}

# Generate row format string
_generate_row_format() {
    local fmt=""
    local i
    local width
    local align

    if [[ ${#COLUMN_WIDTHS[@]} -gt 0 ]]; then
        for i in "${!COLUMN_WIDTHS[@]}"; do
            width="${COLUMN_WIDTHS[$i]}"
            align="${COLUMN_ALIGNS[$i]}"

            if [[ "$align" == "left" ]]; then
                fmt+="$BOX_VERTICAL %-${width}s "
            else
                fmt+="$BOX_VERTICAL %${width}s "
            fi
        done
    fi
    fmt+="$BOX_VERTICAL\n"

    echo "$fmt"
}

# Print table header
print_header() {
    printf "%s\n" "$TOP_BORDER"
    if [[ ${#COLUMN_HEADERS[@]} -gt 0 ]]; then
        printf "$ROW_FORMAT" "${COLUMN_HEADERS[@]}"
    fi
    printf "%s\n" "$MIDDLE_BORDER"
}

# Print table footer
print_footer() {
    printf "%s\n" "$BOTTOM_BORDER"
}

# Colorize text based on type and value
colorize() {
    local type="$1"
    local value="$2"

    [[ "$SHOW_COLORS" != "true" ]] && echo "$value" && return

    case "$type" in
        speed)
            local speed_num="${value%% *}"
            speed_num="${speed_num//[^0-9.]/}"
            if [[ -n "$speed_num" ]] && [[ "$speed_num" != "." ]]; then
                if (( $(echo "$speed_num >= $SPEED_THRESHOLD_HIGH" | bc -l) )); then
                    echo -e "${COLOR_GREEN}${value}${COLOR_RESET}"
                elif (( $(echo "$speed_num >= $SPEED_THRESHOLD_LOW" | bc -l) )); then
                    echo -e "${COLOR_YELLOW}${value}${COLOR_RESET}"
                else
                    echo -e "${COLOR_RED}${value}${COLOR_RESET}"
                fi
            else
                echo "$value"
            fi
            ;;
        phase)
            case "$value" in
                Copying) echo -e "${COLOR_BLUE}${value}${COLOR_RESET}" ;;
                Thinning*|DeletingOldBackups) echo -e "${COLOR_YELLOW}${value}${COLOR_RESET}" ;;
                Starting|Finishing) echo -e "${COLOR_GREEN}${value}${COLOR_RESET}" ;;
                BackupNotRunning|Idle|"Not Running") echo -e "${COLOR_CYAN}${value}${COLOR_RESET}" ;;
                *) echo -e "${COLOR_CYAN}${value}${COLOR_RESET}" ;;
            esac
            ;;
        *)
            echo "$value"
            ;;
    esac
}

# Get status indicator for phase
get_status_indicator() {
    local phase="$1"

    [[ "$SHOW_COLORS" != "true" ]] && return

    case "$phase" in
        Copying|Starting) echo -n "$STATUS_ACTIVE " ;;
        DeletingOldBackups|Thinning*) echo -n "$STATUS_MAINTENANCE " ;;
        Mounting*|HealthCheck*) echo -n "$STATUS_SYSTEM " ;;
        BackupNotRunning|Idle|"Not Running") echo -n "$STATUS_IDLE " ;;
        *) echo -n "$STATUS_SYSTEM " ;;
    esac
}

# Print data row
print_data_row() {
    local timestamp="${CURRENT_TIMESTAMP:-$(date +%s)}"
    local phase="${CURRENT_PHASE:-}"
    local speed="${CURRENT_SPEED:-}"
    local files_per_sec="${CURRENT_FILES_PER_SEC:-}"
    local copied_batch="${CURRENT_COPIED_BATCH:-}"
    local pct_batch="${CURRENT_PCT_BATCH:-}"
    local copied_total="${CURRENT_COPIED_TOTAL:-}"
    local pct_total="${CURRENT_PCT_TOTAL:-}"
    local eta="${CURRENT_ETA:-}"

    # Format timestamp for display
    timestamp="$(date -r "$timestamp" '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S')"

    # Apply colors and indicators
    local colored_phase="$(get_status_indicator "$phase")$(colorize phase "$phase")"
    local colored_speed="$(colorize speed "$speed")"

    # Handle the phase column specially with padding
    printf "$BOX_VERTICAL "
    printf "%-8s" "$timestamp"
    printf " $BOX_VERTICAL "
    
    # Phase column needs special handling for colored text and emoji
    # Reduce width by 1 to account for emoji taking 2 display columns
    local phase_width=31  # Default if not set
    if [[ ${#COLUMN_WIDTHS[@]} -gt 1 ]]; then
        phase_width=$((${COLUMN_WIDTHS[1]} - 1))
    fi
    local padded_phase="$(format_colored_column "$colored_phase" "$phase_width" "left")"
    printf "%s" "$padded_phase"
    
    # Rest of the columns
    # Speed column needs padding for colored text
    local speed_width=12  # Default if not set
    if [[ ${#COLUMN_WIDTHS[@]} -gt 2 ]]; then
        speed_width="${COLUMN_WIDTHS[2]}"
    fi
    local padded_speed="$(format_colored_column "$colored_speed" "$speed_width" "right")"
    printf " $BOX_VERTICAL %s " "$padded_speed"
    
    printf "$BOX_VERTICAL %9s " "$files_per_sec"
    printf "$BOX_VERTICAL %24s " "$copied_batch"
    printf "$BOX_VERTICAL %10s " "$pct_batch"
    printf "$BOX_VERTICAL %24s " "$copied_total"
    printf "$BOX_VERTICAL %10s " "$pct_total"
    printf "$BOX_VERTICAL %10s $BOX_VERTICAL\n" "$eta"

    # Log to CSV if enabled
    [[ "$CSV_LOG" == "true" ]] && log_csv "$timestamp" "$phase" "$speed" \
        "$files_per_sec" "$pct_total" "${CURRENT_BYTES}" "${CURRENT_TOTAL_BYTES}"
}

# Print idle row
print_idle_row() {
    local timestamp="$(date '+%H:%M:%S')"
    local phase="Idle"
    local colored_phase="$(get_status_indicator "$phase")$(colorize phase "$phase")"

    # Handle the phase column specially with padding
    printf "$BOX_VERTICAL "
    printf "%-8s" "$timestamp"
    printf " $BOX_VERTICAL "
    
    # Phase column needs special handling for colored text and emoji
    # Reduce width by 1 to account for emoji taking 2 display columns
    local phase_width=31  # Default if not set
    if [[ ${#COLUMN_WIDTHS[@]} -gt 1 ]]; then
        phase_width=$((${COLUMN_WIDTHS[1]} - 1))
    fi
    local padded_phase="$(format_colored_column "$colored_phase" "$phase_width" "left")"
    printf "%s" "$padded_phase"
    
    # Rest of the columns with dashes
    printf " $BOX_VERTICAL %12s " "-"
    printf "$BOX_VERTICAL %9s " "-"
    printf "$BOX_VERTICAL %24s " "-"
    printf "$BOX_VERTICAL %10s " "-"
    printf "$BOX_VERTICAL %24s " "-"
    printf "$BOX_VERTICAL %10s " "-"
    printf "$BOX_VERTICAL %10s $BOX_VERTICAL\n" "-"
}

# Print "Not Running" row with message
print_not_running_row() {
    local timestamp="$(date '+%H:%M:%S')"
    local phase="${TM_PHASE:-Not Running}"
    # If phase is "Unknown", replace with "Not Running"
    [[ "$phase" == "Unknown" ]] && phase="Not Running"
    local colored_phase="$(get_status_indicator "$phase")$(colorize phase "$phase")"

    # Handle the phase column specially with padding
    printf "$BOX_VERTICAL "
    printf "%-8s" "$timestamp"
    printf " $BOX_VERTICAL "
    
    # Phase column needs special handling for colored text and emoji
    # Reduce width by 1 to account for emoji taking 2 display columns
    local phase_width=31  # Default if not set
    if [[ ${#COLUMN_WIDTHS[@]} -gt 1 ]]; then
        phase_width=$((${COLUMN_WIDTHS[1]} - 1))
    fi
    local padded_phase="$(format_colored_column "$colored_phase" "$phase_width" "left")"
    printf "%s" "$padded_phase"
    
    # Rest of the columns with dashes
    printf " $BOX_VERTICAL %12s " "-"
    printf "$BOX_VERTICAL %9s " "-"
    printf "$BOX_VERTICAL %24s " "-"
    printf "$BOX_VERTICAL %10s " "-"
    printf "$BOX_VERTICAL %24s " "-"
    printf "$BOX_VERTICAL %10s " "-"
    printf "$BOX_VERTICAL %10s $BOX_VERTICAL\n" "-"
}

# Print waiting message below table
print_waiting_message() {
    local seconds="${1:-2}"
    clear_line
    printf "\n"
    clear_line
    printf "${COLOR_CYAN}⏳ Checking Time Machine status again in ${seconds}s...${COLOR_RESET}\n"
}

# Print backup complete message
print_backup_complete() {
    printf "\n${COLOR_BOLD_GREEN}✅ Time Machine backup completed successfully${COLOR_RESET}\n"
}

# Print error and prepare for exit
print_error_and_exit() {
    local error_msg="$1"
    
    # Clear current line and print error
    clear_line
    printf "\n"
    clear_line
    printf "${COLOR_BOLD_RED}❌ Error: ${error_msg}${COLOR_RESET}\n"
    clear_line
    printf "\n"
    
    # Print suggestions based on error type
    if echo "$error_msg" | grep -q "destination"; then
        printf "${COLOR_YELLOW}💡 Tip: Check that your backup disk is connected and mounted${COLOR_RESET}\n"
    elif echo "$error_msg" | grep -q "disabled"; then
        printf "${COLOR_YELLOW}💡 Tip: Enable Time Machine in System Preferences > Time Machine${COLOR_RESET}\n"
    fi
    
    return 1
}

# NOTE: Using terminal.sh functions for all cursor/clear operations
# This maintains DRY principle - no duplicate implementations

# Print backup metadata block
print_backup_metadata() {
    local json_data="$1"
    
    # Use centralized metadata parsing (returns formatted text)
    local metadata
    metadata=$(get_tm_metadata "$json_data")
    
    if [[ -n "$metadata" ]]; then
        # Print formatted output
        echo
        echo "Time Machine Backup Status:"
        # Add indentation to each line
        echo "$metadata" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
}

# NOTE: The 76-width specific functions (print_section_header, print_divider_76, print_line_76)
# were removed as they're no longer used. tm-monitor-resources now uses inline printf
# statements for better control over line-by-line updates without flickering.
# If you need these functions, use this pattern directly:
#   printf "\r%-76.76s\033[K\n" "$content"  # For content lines
#   printf "\r%-.76s\033[K\n" "${DIVIDER}"   # For divider lines

# Export functions
export -f init_display print_header print_footer
export -f print_data_row print_idle_row colorize get_status_indicator
export -f print_backup_metadata
export -f print_not_running_row print_waiting_message print_backup_complete
export -f print_error_and_exit
