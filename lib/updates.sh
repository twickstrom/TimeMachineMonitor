#!/usr/bin/env bash
# lib/updates.sh - Auto-update management for tm-monitor

# Prevent multiple sourcing
[[ -n "${_UPDATES_SOURCED:-}" ]] && return 0
export _UPDATES_SOURCED=1

# Source dependencies
[[ -z "$(type -t determine_paths)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
[[ -z "$(type -t debug)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t get_version)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
[[ -z "${COLOR_GREEN:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Update check configuration defaults
readonly DEFAULT_UPDATE_CHECK_ENABLED="true"
readonly DEFAULT_UPDATE_CHECK_INTERVAL="86400"  # Daily
readonly DEFAULT_UPDATE_CHECK_CHANNEL="stable"
readonly DEFAULT_UPDATE_NOTIFICATION_STYLE="banner"
readonly DEFAULT_UPDATE_AUTO_INSTALL="false"
readonly DEFAULT_GITHUB_REPO="twickstrom/TimeMachineMonitor"

# Update check state files
readonly UPDATE_CHECK_PID_FILE="$TM_DATA_DIR/update-check.pid"
readonly UPDATE_LAST_CHECK_FILE="$TM_DATA_DIR/last-update-check"
readonly UPDATE_AVAILABLE_FILE="$TM_DATA_DIR/update-available"
readonly UPDATE_SNOOZED_FILE="$TM_DATA_DIR/update-snoozed-until"
readonly FIRST_RUN_FILE="$TM_DATA_DIR/first-run-complete"

# Called automatically from tm_monitor_init() in lib/core.sh
auto_check_updates() {
    # Check if updates are disabled
    if [[ "${UPDATE_CHECK_ENABLED:-$DEFAULT_UPDATE_CHECK_ENABLED}" == "false" ]]; then
        debug "Update checks disabled"
        return 0
    fi
    
    # Check if we're in a CI/automated environment
    if [[ -n "${CI:-}" ]] || [[ ! -t 1 ]]; then
        debug "Skipping update check in CI/automated environment"
        return 0
    fi
    
    # Check if snoozed
    if is_update_snoozed; then
        debug "Update checks snoozed"
        return 0
    fi
    
    # Check throttling - only check once per configured interval
    local check_interval="${UPDATE_CHECK_INTERVAL:-$DEFAULT_UPDATE_CHECK_INTERVAL}"
    
    if [[ -f "$UPDATE_LAST_CHECK_FILE" ]]; then
        local last_check=$(cat "$UPDATE_LAST_CHECK_FILE" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local elapsed=$((now - last_check))
        
        if [[ $elapsed -lt $check_interval ]]; then
            debug "Update check throttled (last check: ${elapsed}s ago, interval: ${check_interval}s)"
            return 0
        fi
    fi
    
    # Perform check in background to not block startup
    debug "Starting background update check"
    (
        check_github_release_async
    ) &
    
    # Store PID for cleanup if needed
    local check_pid=$!
    echo "$check_pid" > "$UPDATE_CHECK_PID_FILE"
    
    # Don't wait for it to complete
    return 0
}

# Background update check
check_github_release_async() {
    local repo="${GITHUB_REPO:-$DEFAULT_GITHUB_REPO}"
    local current_version="$(get_version)"
    
    debug "Checking for updates from GitHub repo: $repo"
    
    # Query GitHub API
    local api_response
    api_response=$(curl -s --connect-timeout 2 --max-time 5 \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null)
    
    if [[ -z "$api_response" ]] || [[ "$api_response" == *"Not Found"* ]]; then
        debug "Update check failed: Unable to reach GitHub API"
        handle_update_check_failure "Network or API error"
        return 1
    fi
    
    # Parse version from tag_name
    local latest_version
    latest_version=$(echo "$api_response" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/' | head -1)
    
    if [[ -z "$latest_version" ]]; then
        debug "Update check failed: Unable to parse version from API response"
        return 1
    fi
    
    # Update last check timestamp
    mkdir -p "$(dirname "$UPDATE_LAST_CHECK_FILE")"
    date +%s > "$UPDATE_LAST_CHECK_FILE"
    
    debug "Current version: $current_version, Latest version: $latest_version"
    
    # Compare versions (version_compare returns 0 if v1 >= v2)
    if [[ "$latest_version" != "$current_version" ]]; then
        if ! version_compare "$current_version" "$latest_version"; then
            # New version available
            debug "New version available: $latest_version"
            store_update_notification "$latest_version" "$api_response"
        else
            debug "Current version is newer than latest release"
        fi
    else
        debug "Already on latest version"
        # Remove any existing update notification
        rm -f "$UPDATE_AVAILABLE_FILE"
    fi
}

# Store update notification for later display
store_update_notification() {
    local version="$1"
    local api_response="$2"
    
    # Extract release notes (first 500 chars)
    local release_notes
    release_notes=$(echo "$api_response" | grep '"body"' | sed -E 's/.*"body"[[:space:]]*:[[:space:]]*"([^"]*).*/\1/' | head -c 500)
    
    # Extract download URL
    local download_url
    download_url=$(echo "$api_response" | grep '"html_url"' | head -1 | sed -E 's/.*"html_url"[[:space:]]*:[[:space:]]*"([^"]+).*/\1/')
    
    # Store notification details
    cat > "$UPDATE_AVAILABLE_FILE" << EOF
version=$version
timestamp=$(date +%s)
url=$download_url
notes=$release_notes
EOF
    
    debug "Update notification stored for version $version"
}

# Show update notification to user (called after startup)
show_update_notification() {
    # Don't show if disabled
    if [[ "${UPDATE_CHECK_ENABLED:-$DEFAULT_UPDATE_CHECK_ENABLED}" == "false" ]]; then
        return 0
    fi
    
    # Check if notification exists
    if [[ ! -f "$UPDATE_AVAILABLE_FILE" ]]; then
        return 0
    fi
    
    # Check if snoozed
    if is_update_snoozed; then
        return 0
    fi
    
    # Read notification details
    local latest_version=$(grep "^version=" "$UPDATE_AVAILABLE_FILE" 2>/dev/null | cut -d= -f2)
    
    if [[ -z "$latest_version" ]]; then
        return 0
    fi
    
    local current_version=$(get_version)
    
    # Check notification style preference
    local style="${UPDATE_NOTIFICATION_STYLE:-$DEFAULT_UPDATE_NOTIFICATION_STYLE}"
    
    case "$style" in
        banner)
            show_update_banner "$latest_version"
            ;;
        inline)
            show_update_inline "$latest_version"
            ;;
        silent)
            # Don't show, but log it
            debug "Update available: $latest_version (silent mode)"
            ;;
    esac
}

# Show update banner notification
show_update_banner() {
    local version="$1"
    local current_version=$(get_version)
    
    # Only show after main display is stable (2 second delay)
    (
        sleep 2
        
        # Save cursor position
        tput sc 2>/dev/null || true
        
        # Move to top of screen
        tput cup 0 0 2>/dev/null || true
        
        echo "${COLOR_BOLD}${COLOR_GREEN}╭─────────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET} 🎉 ${COLOR_BOLD}Update Available: v${version}${COLOR_RESET}                                    ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}    Current version: v${current_version}                                        ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}                                                                     ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET} Run: ${COLOR_CYAN}tm-monitor --update${COLOR_RESET}          to install                       ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET} Run: ${COLOR_CYAN}tm-monitor --update-snooze${COLOR_RESET}   to snooze for 7 days            ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET} Run: ${COLOR_CYAN}tm-monitor --update-disable${COLOR_RESET}  to disable update checks         ${COLOR_BOLD}${COLOR_GREEN}│${COLOR_RESET}"
        echo "${COLOR_BOLD}${COLOR_GREEN}╰─────────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
        
        # Restore cursor
        tput rc 2>/dev/null || true
        
        # Auto-dismiss after 5 seconds
        sleep 5
        
        # Clear the banner area
        tput cup 0 0 2>/dev/null || true
        for i in {1..8}; do
            echo "                                                                         "
        done
        tput rc 2>/dev/null || true
    ) &
}

# Show inline update notification
show_update_inline() {
    local version="$1"
    local current_version=$(get_version)
    
    echo ""
    echo "${COLOR_YELLOW}📦 Update available: v${version} (current: v${current_version})${COLOR_RESET}"
    echo "   Run '${COLOR_CYAN}tm-monitor --update${COLOR_RESET}' to install"
    echo ""
}

# Check if updates are snoozed
is_update_snoozed() {
    if [[ ! -f "$UPDATE_SNOOZED_FILE" ]]; then
        return 1
    fi
    
    local until=$(cat "$UPDATE_SNOOZED_FILE" 2>/dev/null || echo 0)
    local now=$(date +%s)
    
    if [[ $now -lt $until ]]; then
        return 0
    else
        # Snooze expired, remove file
        rm -f "$UPDATE_SNOOZED_FILE"
        return 1
    fi
}

# Handle update check failure with exponential backoff
handle_update_check_failure() {
    local reason="$1"
    
    # Silently fail - don't annoy user
    debug "Update check failed: $reason"
    
    # Don't implement exponential backoff for now - keep it simple
    return 0
}

# Force update check (bypasses throttling)
force_update_check() {
    printf "Checking for updates...\n"
    
    # Remove last check file to bypass throttling
    rm -f "$UPDATE_LAST_CHECK_FILE"
    
    # Run check synchronously
    check_github_release_async
    
    # Check if update is available
    if [[ -f "$UPDATE_AVAILABLE_FILE" ]]; then
        local version=$(grep "^version=" "$UPDATE_AVAILABLE_FILE" | cut -d= -f2)
        local current=$(get_version)
        printf "\n"
        printf "${COLOR_GREEN}✓${COLOR_RESET} Update available: v${version} (current: v${current})\n"
        printf "\n"
        printf "Run '${COLOR_CYAN}tm-monitor --update${COLOR_RESET}' to install\n"
    else
        printf "${COLOR_GREEN}✓${COLOR_RESET} You're on the latest version (v$(get_version))\n"
    fi
}

# Install available update interactively
install_update_interactive() {
    # Check if update is available
    if [[ ! -f "$UPDATE_AVAILABLE_FILE" ]]; then
        echo "No update available. Checking for updates..."
        force_update_check
        
        if [[ ! -f "$UPDATE_AVAILABLE_FILE" ]]; then
            echo "You're already on the latest version (v$(get_version))"
            return 0
        fi
    fi
    
    # Read update details
    local version=$(grep "^version=" "$UPDATE_AVAILABLE_FILE" | cut -d= -f2)
    local url=$(grep "^url=" "$UPDATE_AVAILABLE_FILE" | cut -d= -f2-)
    local current=$(get_version)
    
    echo "╭─────────────────────────────────────────────────────────────────────╮"
    echo "│                         Update Available                           │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│ Current version: v${current}"
    echo "│ New version:     v${version}"
    echo "│"
    echo "│ This will download and install the latest version of tm-monitor."
    echo "│ Your configuration and data will be preserved."
    echo "╰─────────────────────────────────────────────────────────────────────╯"
    echo ""
    read -p "Install update now? (y/N): " -r response
    
    if [[ ! "$response" =~ ^[Yy] ]]; then
        echo "Update cancelled"
        return 0
    fi
    
    echo ""
    echo "Downloading tm-monitor v${version}..."
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Download the release
    local download_url="https://github.com/${GITHUB_REPO:-$DEFAULT_GITHUB_REPO}/archive/refs/tags/v${version}.tar.gz"
    
    if ! curl -L -o "$temp_dir/tm-monitor-${version}.tar.gz" "$download_url" 2>/dev/null; then
        echo "${COLOR_RED}✗${COLOR_RESET} Failed to download update"
        return 1
    fi
    
    echo "Extracting update..."
    
    # Extract the archive
    if ! tar -xzf "$temp_dir/tm-monitor-${version}.tar.gz" -C "$temp_dir"; then
        echo "${COLOR_RED}✗${COLOR_RESET} Failed to extract update"
        return 1
    fi
    
    # Find the extracted directory
    local extract_dir=$(find "$temp_dir" -type d -name "TimeMachineMonitor-*" -o -name "tm-monitor-*" | head -1)
    
    if [[ ! -d "$extract_dir" ]]; then
        echo "${COLOR_RED}✗${COLOR_RESET} Failed to find extracted files"
        return 1
    fi
    
    echo "Installing update..."
    
    # Run the installer
    if [[ -f "$extract_dir/install.sh" ]]; then
        if bash "$extract_dir/install.sh" --update; then
            echo ""
            echo "${COLOR_GREEN}✓${COLOR_RESET} Successfully updated to v${version}"
            
            # Remove update notification
            rm -f "$UPDATE_AVAILABLE_FILE"
            
            echo ""
            echo "Please restart tm-monitor to use the new version."
            return 0
        else
            echo "${COLOR_RED}✗${COLOR_RESET} Installation failed"
            return 1
        fi
    else
        echo "${COLOR_RED}✗${COLOR_RESET} Installer not found in update package"
        return 1
    fi
}

# Disable update checks
disable_update_checks() {
    printf "Disabling automatic update checks...\n"
    
    # Update config
    update_config "UPDATE_CHECK_ENABLED" "false"
    
    # Remove any pending notifications
    rm -f "$UPDATE_AVAILABLE_FILE"
    rm -f "$UPDATE_CHECK_PID_FILE"
    
    printf "${COLOR_GREEN}✓${COLOR_RESET} Update checks disabled\n"
    printf "\n"
    printf "You can re-enable them with: ${COLOR_CYAN}tm-monitor --update-enable${COLOR_RESET}\n"
    printf "Or manually check with: ${COLOR_CYAN}tm-monitor --update-check${COLOR_RESET}\n"
}

# Enable update checks
enable_update_checks() {
    printf "Enabling automatic update checks...\n"
    
    # Update config
    update_config "UPDATE_CHECK_ENABLED" "true"
    
    printf "${COLOR_GREEN}✓${COLOR_RESET} Update checks enabled\n"
    printf "\n"
    printf "Checking for updates now...\n"
    force_update_check
}

# Snooze updates for X days
snooze_updates() {
    local days="${1:-7}"
    
    # Validate input
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ $days -lt 1 ]] || [[ $days -gt 365 ]]; then
        printf "Invalid number of days. Please specify 1-365.\n"
        return 1
    fi
    
    local until_timestamp
    
    # Calculate future timestamp (portable for macOS)
    if date -v +1d >/dev/null 2>&1; then
        # BSD date (macOS)
        until_timestamp=$(date -v +"${days}d" +%s)
    else
        # GNU date (Linux)
        until_timestamp=$(date -d "+${days} days" +%s)
    fi
    
    printf "Snoozing update notifications for $days days...\n"
    
    # Store snooze timestamp
    mkdir -p "$(dirname "$UPDATE_SNOOZED_FILE")"
    echo "$until_timestamp" > "$UPDATE_SNOOZED_FILE"
    
    # Format the date for display
    local until_date
    if date -r 1 >/dev/null 2>&1; then
        # BSD date
        until_date=$(date -r "$until_timestamp" "+%Y-%m-%d %H:%M")
    else
        # GNU date
        until_date=$(date -d "@$until_timestamp" "+%Y-%m-%d %H:%M")
    fi
    
    printf "${COLOR_GREEN}✓${COLOR_RESET} Updates snoozed until $until_date\n"
    printf "\n"
    printf "You'll see update notifications again after this date\n"
    printf "Or check manually with: ${COLOR_CYAN}tm-monitor --update-check${COLOR_RESET}\n"
}

# Set update check frequency
set_update_frequency() {
    local frequency="$1"
    local seconds
    
    case "$frequency" in
        hourly)
            seconds=3600
            ;;
        daily)
            seconds=86400
            ;;
        weekly)
            seconds=604800
            ;;
        monthly)
            seconds=2592000
            ;;
        never)
            disable_update_checks
            return
            ;;
        *)
            printf "Invalid frequency. Options: hourly, daily, weekly, monthly, never\n"
            return 1
            ;;
    esac
    
    update_config "UPDATE_CHECK_INTERVAL" "$seconds"
    printf "${COLOR_GREEN}✓${COLOR_RESET} Update check frequency set to: $frequency\n"
}

# Show current update settings
show_update_settings() {
    printf "╭─────────────────────────────────────────────────────────────────────╮\n"
    printf "│                      Update Settings                               │\n"
    printf "├─────────────────────────────────────────────────────────────────────┤\n"
    
    local enabled="${UPDATE_CHECK_ENABLED:-$DEFAULT_UPDATE_CHECK_ENABLED}"
    local interval="${UPDATE_CHECK_INTERVAL:-$DEFAULT_UPDATE_CHECK_INTERVAL}"
    local style="${UPDATE_NOTIFICATION_STYLE:-$DEFAULT_UPDATE_NOTIFICATION_STYLE}"
    local auto="${UPDATE_AUTO_INSTALL:-$DEFAULT_UPDATE_AUTO_INSTALL}"
    local repo="${GITHUB_REPO:-$DEFAULT_GITHUB_REPO}"
    
    # Convert interval to human-readable
    local frequency="custom"
    case "$interval" in
        3600) frequency="hourly" ;;
        86400) frequency="daily" ;;
        604800) frequency="weekly" ;;
        2592000) frequency="monthly" ;;
    esac
    
    printf "│ %-30s %36s │\n" "Update checks:" "$([ "$enabled" == "true" ] && printf "${COLOR_GREEN}Enabled${COLOR_RESET}" || printf "${COLOR_RED}Disabled${COLOR_RESET}")"
    printf "│ %-30s %36s │\n" "Check frequency:" "$frequency"
    printf "│ %-30s %36s │\n" "Notification style:" "$style"
    printf "│ %-30s %36s │\n" "Auto-install:" "$([ "$auto" == "true" ] && echo "Yes" || echo "No")"
    printf "│ %-30s %36s │\n" "GitHub repository:" "$repo"
    
    # Check if snoozed
    if is_update_snoozed; then
        local until=$(cat "$UPDATE_SNOOZED_FILE")
        local until_date
        if date -r 1 >/dev/null 2>&1; then
            until_date=$(date -r "$until" "+%Y-%m-%d %H:%M")
        else
            until_date=$(date -d "@$until" "+%Y-%m-%d %H:%M")
        fi
        printf "│ %-30s %36s │\n" "Snoozed until:" "$until_date"
    fi
    
    # Check last update check
    if [[ -f "$UPDATE_LAST_CHECK_FILE" ]]; then
        local last_check=$(cat "$UPDATE_LAST_CHECK_FILE")
        local last_date
        if date -r 1 >/dev/null 2>&1; then
            last_date=$(date -r "$last_check" "+%Y-%m-%d %H:%M")
        else
            last_date=$(date -d "@$last_check" "+%Y-%m-%d %H:%M")
        fi
        printf "│ %-30s %36s │\n" "Last check:" "$last_date"
    fi
    
    # Check if update available
    if [[ -f "$UPDATE_AVAILABLE_FILE" ]]; then
        local version=$(grep "^version=" "$UPDATE_AVAILABLE_FILE" | cut -d= -f2)
        printf "│ %-30s %36s │\n" "Update available:" "${COLOR_GREEN}v${version}${COLOR_RESET}"
    fi
    
    printf "╰─────────────────────────────────────────────────────────────────────╯\n"
}

# Update configuration value
update_config() {
    local key="$1"
    local value="$2"
    local config_file="$TM_CONFIG_FILE"
    
    # Ensure config directory exists
    mkdir -p "$(dirname "$config_file")"
    
    # Create config file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        # Copy from example if available
        local example_file
        if [[ -f "$TM_CONFIG_DIR/config.conf.example" ]]; then
            example_file="$TM_CONFIG_DIR/config.conf.example"
        elif [[ -f "$TM_BASE_DIR/config/config.conf.example" ]]; then
            example_file="$TM_BASE_DIR/config/config.conf.example"
        fi
        
        if [[ -n "$example_file" ]]; then
            cp "$example_file" "$config_file"
        else
            touch "$config_file"
        fi
    fi
    
    # Check if key exists in config
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        # Update existing value
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS sed
            sed -i '' "s/^${key}=.*/${key}=${value}/" "$config_file"
        else
            # GNU sed
            sed -i "s/^${key}=.*/${key}=${value}/" "$config_file"
        fi
    else
        # Add new key
        echo "" >> "$config_file"
        echo "# Auto-update settings" >> "$config_file"
        echo "${key}=${value}" >> "$config_file"
    fi
    
    debug "Updated config: ${key}=${value}"
}

# First-run setup for update preferences
first_run_update_setup() {
    # Check if first run is already complete
    if [[ -f "$FIRST_RUN_FILE" ]]; then
        return 0
    fi
    
    # Don't show in CI or non-interactive environments
    if [[ -n "${CI:-}" ]] || [[ ! -t 1 ]]; then
        touch "$FIRST_RUN_FILE"
        return 0
    fi
    
    # Don't show if explicitly disabled via environment
    if [[ "${TM_SKIP_FIRST_RUN:-}" == "true" ]]; then
        touch "$FIRST_RUN_FILE"
        return 0
    fi
    
    clear
    
    # Use printf for proper formatting (73 chars wide total)
    printf "╭─────────────────────────────────────────────────────────────────────╮\n"
    printf "│                    TM-Monitor Update Settings                      │\n"
    printf "├─────────────────────────────────────────────────────────────────────┤\n"
    printf "│ TM-Monitor can automatically check for updates to ensure you       │\n"
    printf "│ have the latest features and bug fixes.                            │\n"
    printf "│                                                                     │\n"
    printf "│ • Checks happen in the background (no delays)                      │\n"
    printf "│ • You control when/if to install updates                           │\n"
    printf "│ • No data is collected except version check                        │\n"
    printf "│ • You can disable this anytime                                     │\n"
    printf "╰─────────────────────────────────────────────────────────────────────╯\n"
    printf "\n"
    printf "Enable automatic update checks? (Y/n): "
    
    read -r response
    
    if [[ "$response" =~ ^[Nn] ]]; then
        update_config "UPDATE_CHECK_ENABLED" "false"
        printf "\n"
        printf "${COLOR_GREEN}✓${COLOR_RESET} Update checks disabled.\n"
        printf "\n"
        printf "You can enable later with: ${COLOR_CYAN}tm-monitor --update-enable${COLOR_RESET}\n"
    else
        update_config "UPDATE_CHECK_ENABLED" "true"
        printf "\n"
        printf "${COLOR_GREEN}✓${COLOR_RESET} Update checks enabled (daily)\n"
        printf "\n"
        printf "Customize with:\n"
        printf "  ${COLOR_CYAN}tm-monitor --update-settings${COLOR_RESET}    View settings\n"
        printf "  ${COLOR_CYAN}tm-monitor --update-frequency${COLOR_RESET}   Change frequency\n"
        printf "  ${COLOR_CYAN}tm-monitor --update-disable${COLOR_RESET}     Turn off\n"
    fi
    
    printf "\n"
    printf "Press any key to continue..."
    read -n 1 -s
    
    # Mark first run as complete
    mkdir -p "$(dirname "$FIRST_RUN_FILE")"
    touch "$FIRST_RUN_FILE"
    
    clear
}

# Export functions
export -f auto_check_updates check_github_release_async store_update_notification
export -f show_update_notification show_update_banner show_update_inline
export -f is_update_snoozed handle_update_check_failure force_update_check
export -f install_update_interactive disable_update_checks enable_update_checks
export -f snooze_updates set_update_frequency show_update_settings
export -f update_config first_run_update_setup
