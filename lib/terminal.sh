#!/usr/bin/env bash
# lib/terminal.sh - Centralized terminal detection and management

# Prevent multiple sourcing
[[ -n "${_TERMINAL_SOURCED:-}" ]] && return 0
export _TERMINAL_SOURCED=1

# Terminal dimensions cache
TERMINAL_ROWS=""
TERMINAL_COLS=""
TERMINAL_CACHE_TIME=0
TERMINAL_CACHE_TTL=5  # seconds

# Get terminal dimensions (both rows and columns)
get_terminal_size() {
    local force_refresh="${1:-false}"
    local current_time=$(date +%s)
    
    # Check cache (unless force refresh)
    if [[ "$force_refresh" != "true" ]] && [[ -n "$TERMINAL_ROWS" ]] && [[ -n "$TERMINAL_COLS" ]]; then
        if (( current_time - TERMINAL_CACHE_TIME < TERMINAL_CACHE_TTL )); then
            echo "${TERMINAL_ROWS} ${TERMINAL_COLS}"
            return 0
        fi
    fi
    
    local rows=""
    local cols=""
    
    # Method 1: Try stty first (most reliable on macOS, even in alternate buffer)
    if command -v stty >/dev/null 2>&1; then
        local size
        # Use /dev/tty for more reliable detection in watch/alternate buffer mode
        if [[ -t 0 ]]; then
            size=$(stty size < /dev/tty 2>/dev/null)
        else
            size=$(stty size 2>/dev/null)
        fi
        
        if [[ -n "$size" ]]; then
            rows=$(echo "$size" | cut -d' ' -f1)
            cols=$(echo "$size" | cut -d' ' -f2)
        fi
    fi
    
    # Method 2: Try tput as fallback
    if [[ -z "$cols" ]] || [[ -z "$rows" ]]; then
        if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
            cols=$(tput cols 2>/dev/null)
            rows=$(tput lines 2>/dev/null)
        fi
    fi
    
    # Method 3: Try environment variables
    [[ -z "$cols" ]] && cols="${COLUMNS:-}"
    [[ -z "$rows" ]] && rows="${LINES:-}"
    
    # Default fallback values
    [[ -z "$cols" || "$cols" -lt 10 ]] && cols=80
    [[ -z "$rows" || "$rows" -lt 10 ]] && rows=24
    
    # Update cache
    TERMINAL_ROWS="$rows"
    TERMINAL_COLS="$cols"
    TERMINAL_CACHE_TIME="$current_time"
    
    echo "${rows} ${cols}"
    return 0
}

# Get terminal width only
get_terminal_width() {
    local size
    size=$(get_terminal_size)
    echo "${size#* }"  # Return second field (columns)
}

# Get terminal height only
get_terminal_height() {
    local size
    size=$(get_terminal_size)
    echo "${size%% *}"  # Return first field (rows)
}

# Check if terminal meets minimum size requirements
check_terminal_minimum() {
    local min_rows="${1:-24}"
    local min_cols="${2:-80}"
    local size rows cols
    
    size=$(get_terminal_size)
    rows="${size%% *}"
    cols="${size#* }"
    
    if [[ "$rows" -lt "$min_rows" ]] || [[ "$cols" -lt "$min_cols" ]]; then
        return 1  # Terminal too small
    fi
    return 0  # Terminal size OK
}

# Print terminal size warning
print_terminal_warning() {
    local min_rows="${1:-24}"
    local min_cols="${2:-80}"
    local size rows cols
    
    size=$(get_terminal_size)
    rows="${size%% *}"
    cols="${size#* }"
    
    if [[ "$rows" -lt "$min_rows" ]] || [[ "$cols" -lt "$min_cols" ]]; then
        # Use colors if available
        if [[ -n "${COLOR_BOLD_YELLOW:-}" ]]; then
            printf "\033[K${COLOR_BOLD_YELLOW}⚠ Terminal too small (${cols}x${rows})${COLOR_RESET}\n"
        else
            printf "⚠ Terminal too small (${cols}x${rows})\n"
        fi
        printf "Minimum size: ${min_cols}x${min_rows}\n"
        return 1
    fi
    return 0
}

# Terminal control sequences
# These work across different terminal emulators

# Cursor control
cursor_home() { printf "\033[H"; }
cursor_up() { printf "\033[${1:-1}A"; }
cursor_down() { printf "\033[${1:-1}B"; }
cursor_forward() { printf "\033[${1:-1}C"; }
cursor_back() { printf "\033[${1:-1}D"; }
cursor_position() { printf "\033[${1:-1};${2:-1}H"; }
cursor_save() { printf "\033[s"; }
cursor_restore() { printf "\033[u"; }
cursor_hide() { printf "\033[?25l"; }
cursor_show() { printf "\033[?25h"; }

# Line control
clear_line() { printf "\033[K"; }
clear_line_from_cursor() { printf "\033[0K"; }
clear_line_to_cursor() { printf "\033[1K"; }
clear_entire_line() { printf "\033[2K"; }

# Screen control
clear_screen() { printf "\033[2J"; }
clear_from_cursor() { printf "\033[J"; }
clear_to_cursor() { printf "\033[1J"; }

# Alternate screen buffer (for full-screen apps)
enter_alternate_buffer() {
    printf "\033[?1049h"  # Save screen and switch to alternate buffer
    clear_screen
    cursor_home
}

exit_alternate_buffer() {
    printf "\033[?1049l"  # Restore original screen
}

# Terminal setup for monitoring applications
setup_terminal_monitoring() {
    enter_alternate_buffer
    cursor_hide
    clear_screen
    cursor_home
}

# Terminal cleanup for monitoring applications
cleanup_terminal_monitoring() {
    cursor_show
    exit_alternate_buffer
    printf "\033[0m"  # Reset all attributes
}

# Check if output is to a terminal
is_terminal() {
    [[ -t 1 ]]
}

# Check if input is from a terminal
is_interactive() {
    [[ -t 0 ]]
}

# Get terminal type
get_terminal_type() {
    echo "${TERM:-dumb}"
}

# Check if terminal supports colors
supports_colors() {
    local term="${TERM:-}"
    
    # Check if output is to a terminal
    if ! is_terminal; then
        return 1
    fi
    
    # Check TERM variable for color support
    case "$term" in
        *color*|xterm*|screen*|tmux*|rxvt*|linux|cygwin)
            return 0
            ;;
        *)
            # Check if tput reports color capability
            if command -v tput >/dev/null 2>&1; then
                local colors
                colors=$(tput colors 2>/dev/null)
                [[ -n "$colors" && "$colors" -ge 8 ]] && return 0
            fi
            return 1
            ;;
    esac
}

# Format text to fit terminal width with optional padding
fit_to_width() {
    local text="$1"
    local max_width="${2:-$(get_terminal_width)}"
    local pad_char="${3:- }"
    
    # Remove ANSI escape sequences for length calculation
    local clean_text
    clean_text=$(echo "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    
    if [[ $text_len -gt $max_width ]]; then
        # Truncate if too long
        echo "${text:0:$((max_width-3))}..."
    elif [[ $text_len -lt $max_width ]]; then
        # Pad if too short
        local padding=$((max_width - text_len))
        printf "%s%*s" "$text" "$padding" "" | sed "s/ /$pad_char/g"
    else
        echo "$text"
    fi
}

# Create a horizontal line across terminal width
draw_horizontal_line() {
    local char="${1:--}"
    local width="${2:-$(get_terminal_width)}"
    printf '%*s' "$width" '' | tr ' ' "$char"
}

# Center text in terminal
center_text() {
    local text="$1"
    local width="${2:-$(get_terminal_width)}"
    
    # Remove ANSI escape sequences for length calculation
    local clean_text
    clean_text=$(echo "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    
    if [[ $text_len -ge $width ]]; then
        echo "$text"
    else
        local padding=$(( (width - text_len) / 2 ))
        printf "%*s%s\n" "$padding" "" "$text"
    fi
}

# Set scroll region to exclude footer (last N lines)
set_scroll_region() {
    local footer_lines="${1:-1}"
    local total_lines
    total_lines=$(tput lines 2>/dev/null || echo 24)
    local scroll_end=$((total_lines - footer_lines))
    
    # Set scrolling region from line 1 to scroll_end
    printf "\033[1;${scroll_end}r"
}

# Reset scroll region to full screen
reset_scroll_region() {
    printf "\033[r"
}

# Position cursor at specific line from bottom
position_at_bottom_line() {
    local lines_from_bottom="${1:-0}"
    local total_lines
    total_lines=$(tput lines 2>/dev/null || echo 24)
    local target_line=$((total_lines - lines_from_bottom))
    
    tput cup "$target_line" 0
}

# Legacy compatibility - map old function names to new ones
detect_terminal_width() { get_terminal_width; }
check_terminal_size() { check_terminal_minimum "$@"; }

# Export functions
export -f get_terminal_size get_terminal_width get_terminal_height
export -f check_terminal_minimum print_terminal_warning
export -f cursor_home cursor_up cursor_down cursor_forward cursor_back
export -f cursor_position cursor_save cursor_restore cursor_hide cursor_show
export -f clear_line clear_line_from_cursor clear_line_to_cursor clear_entire_line
export -f clear_screen clear_from_cursor clear_to_cursor
export -f enter_alternate_buffer exit_alternate_buffer
export -f setup_terminal_monitoring cleanup_terminal_monitoring
export -f is_terminal is_interactive get_terminal_type supports_colors
export -f fit_to_width draw_horizontal_line center_text
export -f set_scroll_region reset_scroll_region position_at_bottom_line
export -f detect_terminal_width check_terminal_size  # Legacy compatibility