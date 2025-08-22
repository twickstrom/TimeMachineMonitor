#!/usr/bin/env bash
# lib/colors.sh - Centralized color definitions for tm-monitor

# Prevent multiple sourcing
[[ -n "${_COLORS_SOURCED:-}" ]] && return 0
export _COLORS_SOURCED=1

# Color support detection
detect_color_support() {
    # Check if output is a terminal
    if [[ ! -t 1 ]]; then
        echo "false"
        return
    fi
    
    # Check TERM variable
    case "${TERM:-}" in
        *color*|xterm*|screen*|tmux*|rxvt*) echo "true" ;;
        *) echo "false" ;;
    esac
}

# Initialize color variables based on support
init_colors() {
    local use_colors="${1:-$(detect_color_support)}"
    
    if [[ "$use_colors" == "true" ]]; then
        # ANSI Color codes - Standard Colors
        export COLOR_BLACK='\033[0;30m'
        export COLOR_RED='\033[0;31m'
        export COLOR_GREEN='\033[0;32m'
        export COLOR_YELLOW='\033[0;33m'
        export COLOR_BLUE='\033[0;34m'
        export COLOR_MAGENTA='\033[0;35m'
        export COLOR_CYAN='\033[0;36m'
        export COLOR_WHITE='\033[0;37m'
        export COLOR_RESET='\033[0m'
        
        # Bold variants
        export COLOR_BOLD_BLACK='\033[1;30m'
        export COLOR_BOLD_RED='\033[1;31m'
        export COLOR_BOLD_GREEN='\033[1;32m'
        export COLOR_BOLD_YELLOW='\033[1;33m'
        export COLOR_BOLD_BLUE='\033[1;34m'
        export COLOR_BOLD_MAGENTA='\033[1;35m'
        export COLOR_BOLD_CYAN='\033[1;36m'
        export COLOR_BOLD_WHITE='\033[1;37m'
        
        # Background colors
        export COLOR_BG_RED='\033[41m'
        export COLOR_BG_GREEN='\033[42m'
        export COLOR_BG_BLUE='\033[44m'
    else
        # No colors - Standard Colors
        export COLOR_BLACK=''
        export COLOR_RED=''
        export COLOR_GREEN=''
        export COLOR_YELLOW=''
        export COLOR_BLUE=''
        export COLOR_MAGENTA=''
        export COLOR_CYAN=''
        export COLOR_WHITE=''
        export COLOR_RESET=''
        
        # Bold variants
        export COLOR_BOLD_BLACK=''
        export COLOR_BOLD_RED=''
        export COLOR_BOLD_GREEN=''
        export COLOR_BOLD_YELLOW=''
        export COLOR_BOLD_BLUE=''
        export COLOR_BOLD_MAGENTA=''
        export COLOR_BOLD_CYAN=''
        export COLOR_BOLD_WHITE=''
        
        # Background colors
        export COLOR_BG_RED=''
        export COLOR_BG_GREEN=''
        export COLOR_BG_BLUE=''
    fi
}

# Strip color codes from text
strip_colors() {
    local text="$1"
    echo "$text" | sed 's/\x1b\[[0-9;]*m//g'
}

# Apply color to text
colorize_text() {
    local color="$1"
    local text="$2"
    local reset="${3:-true}"
    
    local color_code=""
    case "$color" in
        red) color_code="$COLOR_RED" ;;
        green) color_code="$COLOR_GREEN" ;;
        yellow) color_code="$COLOR_YELLOW" ;;
        blue) color_code="$COLOR_BLUE" ;;
        magenta) color_code="$COLOR_MAGENTA" ;;
        cyan) color_code="$COLOR_CYAN" ;;
        white) color_code="$COLOR_WHITE" ;;
        *) color_code="" ;;
    esac
    
    if [[ "$reset" == "true" ]]; then
        echo -e "${color_code}${text}${COLOR_RESET}"
    else
        echo -e "${color_code}${text}"
    fi
}

# Initialize colors on source
init_colors "${SHOW_COLORS:-true}"

# Export functions
export -f detect_color_support init_colors strip_colors colorize_text
