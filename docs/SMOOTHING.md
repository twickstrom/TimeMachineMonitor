# TM-Monitor Smoothing System

## Overview
The tm-monitor uses sophisticated smoothing algorithms to provide stable, accurate readings during Time Machine backups.

## Smoothing Components

### 1. Speed (MB/s)
- **Buffer**: Ring buffer storing (timestamp, bytes) tuples
- **Window**: 30 seconds default, 90 seconds for initial backups
- **Algorithm**: Delta calculation over entire buffer window
- **Formula**: `(newest_bytes - oldest_bytes) / (newest_time - oldest_time)`

### 2. Files/s
- **Buffer**: Ring buffer storing (timestamp, files) tuples  
- **Window**: Same as speed window
- **Algorithm**: Delta calculation over entire buffer window
- **Formula**: `(newest_files - oldest_files) / (newest_time - oldest_time)`

### 3. ETA (Estimated Time)
- **Buffer**: Ring buffer storing (timestamp, eta_seconds) tuples
- **Window**: Same as speed window
- **Algorithm**: Weighted average giving more weight to recent samples
- **Formula**: `sum(eta[i] * (i+1)) / sum(i+1 for all i)`
- **Special**: Buffer cleared on phase changes for accurate recalculation

## Configuration

### Command Line
```bash
# Set custom smoothing window
tm-monitor -w 60  # 60-second window

# Debug mode shows window being used
tm-monitor -d
```

### Config File
```bash
# ~/.config/tm-monitor/config.conf
SPEED_WINDOW=45              # Regular backup window
INITIAL_BACKUP_WINDOW=120    # Initial backup window
```

### Environment Variables
```bash
export TM_SPEED_WINDOW=60
export TM_INITIAL_BACKUP_WINDOW=90
```

## Initial Backup Detection
- Automatically detects `FirstBackup = 1` from tmutil status
- Switches to 90-second window for more stability
- Can be overridden with explicit settings

## Benefits
1. **Stable Readings** - No more jumpy values
2. **Accurate Averages** - True average over time window
3. **Responsive** - Weighted averaging for ETA
4. **Phase-Aware** - Resets on phase transitions
5. **Configurable** - Adjust for your needs

## Technical Details

### Ring Buffer Implementation
- Fixed-size window in seconds
- Old entries automatically pruned
- Memory efficient (only stores needed samples)

### Weighted Average (ETA only)
- Linear weighting: weight = index + 1
- Recent samples have more influence
- Balances stability with responsiveness

### Phase Change Handling
- ETA buffer cleared on phase change
- Prevents mixing different calculation contexts
- Examples: Copying → Thinning, Starting → Copying
