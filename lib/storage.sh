#!/usr/bin/env bash
# lib/storage.sh - Persistent storage for tm-monitor using SQLite
# Enables historical data tracking and cross-session statistics

# Source dependencies
[[ -z "$(type -t debug)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
[[ -z "$(type -t format_decimal)" ]] && source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"

# Storage configuration
STORAGE_DB="${TM_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/tm-monitor}/tmmonitor.db"
STORAGE_ENABLED="${TM_STORAGE_ENABLED:-true}"
STORAGE_RETENTION_DAYS="${TM_STORAGE_RETENTION_DAYS:-30}"

# Ensure data directory exists
[[ ! -d "$(dirname "$STORAGE_DB")" ]] && mkdir -p "$(dirname "$STORAGE_DB")"

# ============================================================================
# DATABASE INITIALIZATION
# ============================================================================

# Initialize database schema
init_storage() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    # Check if sqlite3 is available
    if ! command -v sqlite3 >/dev/null 2>&1; then
        warn "SQLite not found, persistent storage disabled"
        STORAGE_ENABLED="false"
        return 1
    fi
    
    debug "Initializing storage database: $STORAGE_DB"
    
    # Create tables if they don't exist
    sqlite3 "$STORAGE_DB" <<'SQL'
-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    total_bytes INTEGER DEFAULT 0,
    total_files INTEGER DEFAULT 0,
    avg_speed_bytes INTEGER DEFAULT 0,
    peak_speed_bytes INTEGER DEFAULT 0,
    backup_type TEXT,
    destination TEXT,
    completed INTEGER DEFAULT 0
);

-- Backup samples table
CREATE TABLE IF NOT EXISTS samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    phase TEXT,
    bytes_copied INTEGER,
    total_bytes INTEGER,
    percent REAL,
    files_copied INTEGER,
    speed_bytes INTEGER,
    eta_seconds INTEGER,
    cpu_percent REAL,
    mem_mb REAL,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- Aggregated hourly statistics
CREATE TABLE IF NOT EXISTS hourly_stats (
    hour_timestamp INTEGER PRIMARY KEY,
    total_bytes INTEGER,
    avg_speed_bytes INTEGER,
    backup_count INTEGER,
    avg_cpu_percent REAL,
    avg_mem_mb REAL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_samples_session ON samples(session_id);
CREATE INDEX IF NOT EXISTS idx_samples_timestamp ON samples(timestamp);
CREATE INDEX IF NOT EXISTS idx_sessions_start ON sessions(start_time);

-- Version table for schema migrations
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER
);

-- Insert initial version if not exists
INSERT OR IGNORE INTO schema_version (version, applied_at) 
VALUES (1, strftime('%s', 'now'));
SQL
    
    # Clean up old data
    cleanup_old_data
    
    return 0
}

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

# Start a new monitoring session
start_storage_session() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    local backup_type="${1:-Incremental}"
    local destination="${2:-Unknown}"
    local timestamp=$(date +%s)
    
    # Insert new session and get ID
    local session_id
    session_id=$(sqlite3 "$STORAGE_DB" <<SQL
INSERT INTO sessions (start_time, backup_type, destination) 
VALUES ($timestamp, '$backup_type', '$destination');
SELECT last_insert_rowid();
SQL
)
    
    # Don't echo the session ID - just export it
    export STORAGE_SESSION_ID="$session_id"
    debug "Started storage session: $session_id"
    
    return 0
}

# End current session
end_storage_session() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    [[ -z "${STORAGE_SESSION_ID:-}" ]] && return 0
    
    local timestamp=$(date +%s)
    local session_id="$STORAGE_SESSION_ID"
    local completed="${1:-0}"  # Optional parameter to force completion status
    
    # Calculate session statistics
    sqlite3 "$STORAGE_DB" <<SQL
UPDATE sessions 
SET end_time = $timestamp,
    total_bytes = (SELECT COALESCE(MAX(bytes_copied), 0) FROM samples WHERE session_id = $session_id),
    total_files = (SELECT COALESCE(MAX(files_copied), 0) FROM samples WHERE session_id = $session_id),
    avg_speed_bytes = (SELECT COALESCE(AVG(speed_bytes), 0) FROM samples WHERE session_id = $session_id AND speed_bytes > 0),
    peak_speed_bytes = (SELECT COALESCE(MAX(speed_bytes), 0) FROM samples WHERE session_id = $session_id),
    completed = CASE 
        WHEN $completed = 1 THEN 1
        WHEN (SELECT phase FROM samples WHERE session_id = $session_id ORDER BY timestamp DESC LIMIT 1) = 'Finishing' 
        THEN 1 ELSE 0 END
WHERE id = $session_id;
SQL
    
    debug "Ended storage session: $session_id (completed=$completed)"
    unset STORAGE_SESSION_ID
    
    return 0
}

# Mark session as completed
mark_session_completed() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    local session_id="${1:-$STORAGE_SESSION_ID}"
    [[ -z "$session_id" ]] && return 0
    
    sqlite3 "$STORAGE_DB" <<SQL
UPDATE sessions 
SET completed = 1
WHERE id = $session_id;
SQL
    
    debug "Marked session $session_id as completed"
    return 0
}

# ============================================================================
# DATA RECORDING
# ============================================================================

# Record a backup sample
record_sample() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    [[ -z "${STORAGE_SESSION_ID:-}" ]] && return 0
    
    local phase="$1"
    local bytes_copied="$2"
    local total_bytes="$3"
    local percent="$4"
    local files_copied="$5"
    local speed_bytes="$6"
    local eta_seconds="$7"
    local cpu_percent="${8:-0}"
    local mem_mb="${9:-0}"
    
    local timestamp=$(date +%s)
    
    sqlite3 "$STORAGE_DB" <<SQL
INSERT INTO samples (
    session_id, timestamp, phase, bytes_copied, total_bytes, 
    percent, files_copied, speed_bytes, eta_seconds, 
    cpu_percent, mem_mb
) VALUES (
    $STORAGE_SESSION_ID, $timestamp, '$phase', $bytes_copied, $total_bytes,
    $percent, $files_copied, $speed_bytes, $eta_seconds,
    $cpu_percent, $mem_mb
);
SQL
    
    return 0
}

# Record sample from current tmutil state
record_tmutil_sample() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    [[ -z "${TM_PHASE:-}" ]] && return 0
    
    # Get CPU/memory usage if available
    local cpu_pct=0 mem_mb=0
    if command -v ps >/dev/null 2>&1; then
        local tm_stats
        tm_stats=$(ps aux | grep -E "[t]m-monitor" | head -1 | awk '{print $3 " " $6/1024}')
        IFS=' ' read -r cpu_pct mem_mb <<< "$tm_stats"
    fi
    
    record_sample \
        "$TM_PHASE" \
        "${TM_BYTES:-0}" \
        "${TM_TOTAL_BYTES:-0}" \
        "${TM_PERCENT:-0}" \
        "${TM_FILES:-0}" \
        "${CURRENT_BYTES_PER_SEC:-0}" \
        "${TM_TIME_REMAINING:-0}" \
        "$cpu_pct" \
        "$mem_mb"
}

# ============================================================================
# DATA RETRIEVAL
# ============================================================================

# Get recent sessions
get_recent_sessions() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 1
    
    local limit="${1:-10}"
    
    sqlite3 -header -column "$STORAGE_DB" <<SQL
SELECT 
    id,
    datetime(start_time, 'unixepoch', 'localtime') as started,
    CASE 
        WHEN end_time IS NULL THEN 'Running'
        ELSE datetime(end_time, 'unixepoch', 'localtime')
    END as ended,
    printf('%.2f GB', total_bytes / 1000000000.0) as size,
    printf('%.2f MB/s', avg_speed_bytes / 1000000.0) as avg_speed,
    backup_type as type,
    CASE completed WHEN 1 THEN 'Yes' ELSE 'No' END as completed
FROM sessions 
ORDER BY start_time DESC 
LIMIT $limit;
SQL
}

# Get session statistics
get_session_stats() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 1
    
    local session_id="${1:-$STORAGE_SESSION_ID}"
    [[ -z "$session_id" ]] && return 1
    
    sqlite3 -header -column "$STORAGE_DB" <<SQL
SELECT 
    datetime(start_time, 'unixepoch', 'localtime') as started,
    CASE 
        WHEN end_time IS NULL THEN 'Running'
        ELSE datetime(end_time, 'unixepoch', 'localtime')
    END as ended,
    printf('%.2f GB', total_bytes / 1000000000.0) as total_size,
    total_files as files,
    printf('%.2f MB/s', avg_speed_bytes / 1000000.0) as avg_speed,
    printf('%.2f MB/s', peak_speed_bytes / 1000000.0) as peak_speed,
    backup_type,
    destination,
    CASE completed WHEN 1 THEN 'Completed' ELSE 'Incomplete' END as status
FROM sessions 
WHERE id = $session_id;
SQL
}

# Get speed history for graphing
get_speed_history() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 1
    
    local session_id="${1:-$STORAGE_SESSION_ID}"
    local limit="${2:-100}"
    
    [[ -z "$session_id" ]] && return 1
    
    sqlite3 -csv "$STORAGE_DB" <<SQL
SELECT 
    timestamp - (SELECT MIN(timestamp) FROM samples WHERE session_id = $session_id) as seconds,
    speed_bytes / 1000000.0 as speed_mbps
FROM samples 
WHERE session_id = $session_id 
    AND speed_bytes > 0
ORDER BY timestamp 
LIMIT $limit;
SQL
}

# Get hourly statistics
get_hourly_stats() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 1
    
    local days="${1:-7}"
    
    sqlite3 -header -column "$STORAGE_DB" <<SQL
SELECT 
    datetime(hour_timestamp, 'unixepoch', 'localtime') as hour,
    printf('%.2f GB', total_bytes / 1000000000.0) as backed_up,
    printf('%.2f MB/s', avg_speed_bytes / 1000000.0) as avg_speed,
    backup_count as backups
FROM hourly_stats 
WHERE hour_timestamp > strftime('%s', 'now', '-$days days')
ORDER BY hour_timestamp DESC;
SQL
}

# ============================================================================
# AGGREGATION & CLEANUP
# ============================================================================

# Aggregate hourly statistics
aggregate_hourly_stats() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    local current_hour=$(date +%s)
    current_hour=$((current_hour - (current_hour % 3600)))
    
    sqlite3 "$STORAGE_DB" <<SQL
INSERT OR REPLACE INTO hourly_stats (
    hour_timestamp, total_bytes, avg_speed_bytes, backup_count, 
    avg_cpu_percent, avg_mem_mb
)
SELECT 
    $current_hour,
    COALESCE(SUM(bytes_copied), 0),
    COALESCE(AVG(speed_bytes), 0),
    COUNT(DISTINCT session_id),
    COALESCE(AVG(cpu_percent), 0),
    COALESCE(AVG(mem_mb), 0)
FROM samples
WHERE timestamp >= $current_hour 
    AND timestamp < $current_hour + 3600;
SQL
}

# Clean up old data
cleanup_old_data() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    local cutoff_time=$(date -v-${STORAGE_RETENTION_DAYS}d +%s 2>/dev/null || date -d "${STORAGE_RETENTION_DAYS} days ago" +%s)
    
    debug "Cleaning up data older than $STORAGE_RETENTION_DAYS days"
    
    sqlite3 "$STORAGE_DB" <<SQL
-- Delete old sessions and their samples (cascade)
DELETE FROM sessions WHERE start_time < $cutoff_time;

-- Delete old hourly stats
DELETE FROM hourly_stats WHERE hour_timestamp < $cutoff_time;

-- Vacuum to reclaim space
VACUUM;
SQL
}

# ============================================================================
# EXPORT DATA
# ============================================================================

# Export session to CSV
export_session_csv() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 1
    
    local session_id="${1:-$STORAGE_SESSION_ID}"
    local output_file="${2:-session_${session_id}.csv}"
    
    [[ -z "$session_id" ]] && return 1
    
    sqlite3 -header -csv "$STORAGE_DB" <<SQL > "$output_file"
SELECT 
    datetime(timestamp, 'unixepoch', 'localtime') as time,
    phase,
    bytes_copied / 1000000000.0 as gb_copied,
    total_bytes / 1000000000.0 as gb_total,
    percent,
    files_copied,
    speed_bytes / 1000000.0 as speed_mbps,
    eta_seconds,
    cpu_percent,
    mem_mb
FROM samples 
WHERE session_id = $session_id
ORDER BY timestamp;
SQL
    
    echo "Exported session $session_id to $output_file"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Get database size
get_storage_size() {
    [[ "$STORAGE_ENABLED" != "true" ]] && echo "0" && return 1
    [[ ! -f "$STORAGE_DB" ]] && echo "0" && return 1
    
    local size_bytes=$(stat -f%z "$STORAGE_DB" 2>/dev/null || stat --format=%s "$STORAGE_DB" 2>/dev/null || echo "0")
    echo "$size_bytes"
}

# Optimize database
optimize_storage() {
    [[ "$STORAGE_ENABLED" != "true" ]] && return 0
    
    debug "Optimizing storage database"
    
    sqlite3 "$STORAGE_DB" <<SQL
ANALYZE;
REINDEX;
VACUUM;
SQL
}

# Export functions
export -f init_storage start_storage_session end_storage_session mark_session_completed
export -f record_sample record_tmutil_sample
export -f get_recent_sessions get_session_stats get_speed_history get_hourly_stats
export -f aggregate_hourly_stats cleanup_old_data
export -f export_session_csv get_storage_size optimize_storage

# Export variables
export STORAGE_DB STORAGE_ENABLED STORAGE_RETENTION_DAYS STORAGE_SESSION_ID
