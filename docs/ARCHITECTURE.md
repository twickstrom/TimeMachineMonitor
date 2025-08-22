# Architecture Documentation

## System Architecture

TM-Monitor uses a hybrid bash/Python architecture optimized for different monitoring scenarios.

## Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         tm-monitor                           │
│  (Main monitoring script - orchestrates everything)          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ├──► tmutil status (System command)
              │
              ├──► tm-monitor-helper.py (Python daemon)
              │    └─► Stateful calculations
              │        - Speed smoothing (30-sec window)
              │        - Batch stabilization
              │        - Complex ETA calculations
              │
              └──► Library Modules (Bash)
                   ├─► tmutil.sh    - Centralized parsing
                   ├─► state.sh     - State management
                   ├─► display.sh   - UI rendering
                   ├─► logger.sh    - Logging
                   ├─► config.sh    - Configuration
                   └─► process.sh   - Process management
```

## Design Decisions

### Why Hybrid Bash/Python?

1. **Bash for orchestration**: Native macOS support, lightweight, good for system calls
2. **Python for calculations**: Better math capabilities, easier data structure handling
3. **Separation of concerns**: Each language used for its strengths

### Why Three Parsing Implementations?

We intentionally have three different tmutil parsing approaches:

1. **Python Helper Daemon** (`tm-monitor-helper.py`)
   - **Purpose**: Continuous monitoring with complex calculations
   - **Features**: Stateful, speed smoothing, batch stabilization
   - **Use case**: Main tm-monitor display

2. **Centralized Library** (`lib/tmutil.sh`)
   - **Purpose**: Simple, stateless parsing for utilities
   - **Features**: Comprehensive field extraction, no state needed
   - **Use case**: Resource monitor, quick status checks

3. **Inline Fallback** (`state.sh::_update_inline`)
   - **Purpose**: Emergency fallback when helper fails
   - **Features**: Minimal parsing, basic functionality
   - **Use case**: Graceful degradation

This is NOT duplication - it's appropriate specialization for different needs.

### Security Considerations

- **No eval usage**: All variable assignments use safe methods
- **Input validation**: JSON parsing with error handling
- **Process isolation**: Helper runs as separate process with limited communication

## Data Flow

### Main Monitor Flow

1. `tm-monitor` calls `tmutil status`
2. Converts to JSON using `plutil`
3. Sends JSON to Python helper via named pipe
4. Helper returns pipe-delimited results
5. State management stores values
6. Display renders the UI

### Resource Monitor Flow

1. `tm-monitor-resources` uses `lib/tmutil.sh`
2. Parses tmutil status directly
3. Displays process and TM status
4. No persistent state needed

## Key Design Patterns

### 1. Daemon Pattern (Python Helper)
- Long-running process
- Maintains state between calls
- Communicates via named pipes
- Graceful shutdown handling

### 2. Library Pattern (Bash Modules)
- Sourced libraries for code reuse
- Exported functions and variables
- Dependency management via source checks

### 3. Cache Pattern (tmutil.sh)
- 1-second TTL for tmutil calls
- Reduces system load
- Shared cache across functions

### 4. Fallback Pattern
- Primary: Python helper
- Secondary: Inline Python
- Ensures continuity of service

## Performance Optimizations

1. **Python Daemon**: Avoids Python startup overhead
2. **Speed Buffering**: 30-second window for smoothing
3. **Caching**: tmutil results cached for 1 second
4. **Batch Stabilization**: Prevents number jumping
5. **Selective Rendering**: Only update changed values

## File Responsibilities

### Core Scripts
- `tm-monitor`: Main orchestrator, UI loop
- `tm-monitor-resources`: System resource monitoring
- `tm-monitor-helper.py`: Complex calculations daemon

### Libraries
- `constants.sh`: Configuration constants, colors, symbols
- `tmutil.sh`: Centralized tmutil parsing (NEW)
- `state.sh`: Session and state management
- `display.sh`: Terminal UI rendering
- `logger.sh`: Logging and debug output
- `config.sh`: Configuration file handling
- `process.sh`: Process and signal management

## Error Handling Strategy

1. **Graceful Degradation**: Helper failure → inline fallback
2. **User Feedback**: Clear error messages
3. **Logging**: Debug mode for troubleshooting
4. **Recovery**: Automatic retry with exponential backoff

## Future Extensibility

The architecture supports:
- Additional monitoring metrics
- Plugin system for custom analyzers
- Web UI via data export
- Historical data analysis
- Multiple backup destination support

## Testing Approach

- **Unit Tests**: Individual function testing
- **Integration Tests**: Component interaction
- **System Tests**: Full workflow validation
- **Debug Mode**: Built-in diagnostic output

## Compatibility

- macOS 14.0+ (Sonoma and later)
- Bash 3.2+ (macOS default)
- Python 3.x (macOS default)
- No external dependencies required
