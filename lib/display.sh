#!/usr/bin/env bash
# lib/display.sh - Display and UI functions for tm-monitor

# Source dependencies
[[ -z "$TM_MONITOR_VERSION" ]] && source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
[[ -z "$(type -t log_message)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t get_tm_metadata)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/tmutil.sh"
[[ -z "$(type -t CURRENT_STATE)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
[[ -z "$(type -t get_terminal_width)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/terminal.sh"

# Display state
TABLE_WIDTH=0
TERMINAL_WIDTH=80
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

    for definition in "${TABLE_COLUMNS[@]}"; do
        IFS=':' read -r header width align <<< "$definition"
        COLUMN_HEADERS+=("$header")
        COLUMN_WIDTHS+=("$width")
        COLUMN_ALIGNS+=("$align")
    done
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
}

# Generate border line
_generate_border() {
    local type="$1"  # top, middle, or bottom
    local result=""
    local i width total_width

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
    local i width align

    for i in "${!COLUMN_WIDTHS[@]}"; do
        width="${COLUMN_WIDTHS[$i]}"
        align="${COLUMN_ALIGNS[$i]}"

        if [[ "$align" == "left" ]]; then
            fmt+="$BOX_VERTICAL %-${width}s "
        else
            fmt+="$BOX_VERTICAL %${width}s "
        fi
    done
    fmt+="$BOX_VERTICAL\n"

    echo "$fmt"
}

# Pad colored text to proper width accounting for ANSI escape sequences
pad_colored_text() {
local text="$1"
local width="$2"
local align="${3:-left}"

# Count visible characters (excluding ANSI escape sequences)
local visible_text
visible_text=$(printf "%b" "$text" | sed 's/\x1b\[[0-9;]*m//g')
local visible_length=${#visible_text}

local padding=$((width - visible_length))
[[ $padding -lt 0 ]] && padding=0

if [[ "$align" == "right" ]]; then
printf "%*s%b" "$padding" "" "$text"
else
    printf "%b%*s" "$text" "$padding" ""
fi
}

# Print table header
print_header() {
    printf "%s\n" "$TOP_BORDER"
    printf "$ROW_FORMAT" "${COLUMN_HEADERS[@]}"
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
                BackupNotRunning|Idle) echo -e "${COLOR_CYAN}${value}${COLOR_RESET}" ;;
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
        BackupNotRunning|Idle) echo -n "$STATUS_IDLE " ;;
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
    local phase_width=$((${COLUMN_WIDTHS[1]} - 1))
    local padded_phase="$(pad_colored_text "$colored_phase" "$phase_width" "left")"
    printf "%s" "$padded_phase"
    
    # Rest of the columns
    # Speed column needs padding for colored text
    local speed_width="${COLUMN_WIDTHS[2]}"
    local padded_speed="$(pad_colored_text "$colored_speed" "$speed_width" "right")"
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
    local phase_width=$((${COLUMN_WIDTHS[1]} - 1))
    local padded_phase="$(pad_colored_text "$colored_phase" "$phase_width" "left")"
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

# Clear current line
clear_line() {
    printf "\r\033[K"
}

# Move cursor up N lines
cursor_up() {
    local lines="${1:-1}"
    printf "\033[${lines}A"
}

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

# Export functions
export -f init_display print_header print_footer
export -f print_data_row print_idle_row colorize get_status_indicator
export -f print_backup_metadata pad_colored_text
