# TM-Monitor

A powerful, real-time Apple Time Machine backup monitor for macOS Sonoma+ with advanced analytics and resource tracking.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-purple)
![Platform](https://img.shields.io/badge/platform-Apple%20Silicon%20%7C%20Intel-lightgrey)
![Size](https://img.shields.io/github/repo-size/twickstrom/TimeMachineMonitor)
![macOS](https://img.shields.io/badge/macOS-15.0%2B-green)
![Python](https://img.shields.io/badge/python-3.8%2B-blue)
![Bash](https://img.shields.io/badge/bash-3.2%2B-green)

## 🤔 Why TM-Monitor?

Apple's Time Machine is great, but it lacks visibility. **You're left wondering:**
- 🐌 Why is my backup taking so long?
- 📊 How fast is data actually transferring?
- 🔮 When will the backup finish?
- 💾 How much data is left to copy?
- 🔥 Is Time Machine using too much CPU?

**TM-Monitor answers all these questions in real-time**, giving you the insights Apple didn't build into macOS.

## 🚀 Quick Start

### Recommended: Dashboard View

**The easiest way to use TM-Monitor is with the dashboard launcher:**

```bash
# Launch split-screen dashboard with both monitors
tm-dashboard
```

This automatically:
- ✅ Opens two perfectly sized terminal windows
- ✅ Positions them side-by-side for optimal viewing
- ✅ Starts both the backup monitor and resource monitor
- ✅ Handles Retina displays correctly
- ✅ Works with Terminal.app and iTerm2

<img src="docs/images/tm-side-by-side.png" width="100%" alt="TM-Monitor Dashboard View">

### Alternative: Individual Monitors

You can also run the monitors separately:

```bash
# Run the main backup monitor
tm-monitor

# In another terminal, run the resource monitor
tm-monitor-resources --watch
```

## 📸 Screenshots

<img src="docs/images/tm-side-by-side.png" width="100%" alt="TM-Monitor Dashboard View">

<img src="docs/images/tm-monitor.png" width="100%" alt="TM-Monitor Main Display">

<img src="docs/images/tm-monitor-resource-usage.png" width="100%" alt="TM-Monitor Resource Usage">

## 🎯 What Makes TM-Monitor Special?

- **Native Apple Integration** - Uses Apple's own `tmutil` for accurate data
- **📈 Advanced Analytics** - 30-second smoothed averages, not jumpy instant values
- **🔋 Low Overhead** - Efficient Python daemon, minimal CPU usage (<1%)
- **🎨 Beautiful TUI** - Color-coded phases, progress bars, emoji indicators
- **📊 Data Export** - CSV logging for historical analysis
- **🔒 Security First** - No eval, no sudo required, safe parsing
- **🚀 Zero Dependencies** - Everything needed is already in macOS

## ✨ Features

### 🆕 Automatic Updates (v1.0.0+)
- 🔄 **Smart Update Checking** - Automatic background checks for new versions
- 📦 **One-Command Updates** - Install updates with `tm-monitor --update`
- 🔔 **Non-Intrusive Notifications** - Beautiful banners that don't block your work
- ⚙️ **Full User Control** - Enable, disable, or snooze update checks anytime
- 🔒 **Privacy-Focused** - No telemetry, only version checks to GitHub
- 🎯 **Configurable Frequency** - Check hourly, daily, weekly, or monthly
- 🚫 **Works Offline** - Gracefully handles network failures
- 📝 **First-Run Setup** - Choose your update preferences on first launch

### Real-Time Monitoring
- 📊 Live backup progress with percentage complete
- ⚡ Current transfer speed in MB/s or MiB/s
- 📁 Files per second transfer rate
- ⏱️ Accurate ETA with smart calculations
- 🔄 Automatic refresh every 2 seconds

### Advanced Analytics  
- 📈 30-second rolling average for smooth readings
- 🎯 Batch vs. total progress tracking
- 📝 CSV export for historical analysis
- 🔢 Precise 2-decimal formatting throughout
- 💾 **NEW: SQLite storage for historical data tracking**
- 📊 **NEW: Terminal-based speed graphs**

### Resource Management
- 💻 CPU usage monitoring for all TM processes
- 🧠 Memory (RAM) tracking with RSS metrics
- ⚖️ System load impact assessment
- 🚦 Color-coded performance indicators
- 🔄 **NEW: Shared cache between monitoring processes**

### Professional Tools
- ⚙️ Configuration file support
- 🎨 Customizable display options
- 🐛 Debug logging for troubleshooting
- 📦 Multiple installation modes
- 📈 **NEW: Historical statistics viewer (`tm-monitor-stats`)**
- 🗄️ **NEW: Session-based data persistence**
- 🚀 **NEW: Automatic Time Machine startup**
- 🔍 **NEW: Intelligent backup completion detection**

## 📊 TM-Monitor vs. Vanilla Time Machine

| Feature | Time Machine | TM-Monitor |
|---------|---------------|------------|
| Progress Bar | ✅ Basic | ✅ Detailed with % |
| Speed Display | ❌ | ✅ MB/s with smoothing |
| ETA | ❌ | ✅ Smart calculations |
| Files/sec | ❌ | ✅ Real-time |
| CPU Usage | ❌ | ✅ All TM processes |
| Memory Usage | ❌ | ✅ RSS tracking |
| Phase Details | ✅ Limited | ✅ Full phase info |
| CSV Export | ❌ | ✅ For analysis |
| Batch Progress | ❌ | ✅ Current vs Total |
| Historical Data | ❌ | ✅ SQLite storage |
| Speed Graphs | ❌ | ✅ Terminal graphs |
| Session Stats | ❌ | ✅ Complete tracking |
| Auto-Start | ❌ | ✅ Smart startup |
| Completion Detection | ❌ | ✅ Clean exit |

## 🖥️ System Requirements

### Supported Systems
- **macOS**: 14.0 Sonoma or later (for latest Time Machine features)
- **Hardware**: Apple Silicon (M1/M2/M3) or Intel Macs
- **Time Machine**: Must be configured and enabled

### Built with macOS Native Tools
No additional downloads needed! TM-Monitor uses only what Apple provides:
- `tmutil` - Apple's Time Machine utility
- `plutil` - Apple's property list utility  
- Python 3 - Included with macOS
- Bash - macOS default shell

## 📦 Installation

### One-Command Quick Start

```bash
# Clone, install, and launch dashboard in one command
git clone https://github.com/twickstrom/TimeMachineMonitor.git && \
cd TimeMachineMonitor && \
chmod +x QUICK_START.sh && \
./QUICK_START.sh && \
tm-dashboard
```

### Standard Install

```bash
# Clone the repository
git clone https://github.com/twickstrom/TimeMachineMonitor.git
cd TimeMachineMonitor

# Run the installer
./install.sh

# Launch the dashboard!
tm-dashboard
```

The installer will:
- ✅ Check all dependencies
- ✅ Detect the best Python 3 version
- ✅ Create necessary directories
- ✅ Install to `~/.local` by default
- ✅ Check if PATH is configured correctly

### Installation Options

```bash
# Standard user installation (default)
./install.sh

# Install to custom location
./install.sh --prefix /opt/tm-monitor

# System-wide installation (requires sudo)
sudo ./install.sh --system

# Development mode (uses symlinks)
./install.sh --dev

# Check dependencies only
./install.sh --check-only
```

### Manual Installation

If you prefer to run directly without installing:

```bash
# Make scripts executable
chmod +x bin/tm-monitor bin/tm-monitor-resources bin/tm-monitor-helper.py

# Run directly from the source directory
./bin/tm-monitor
```

### Uninstallation

```bash
# Run the uninstaller
./uninstall.sh
```

## 📖 Usage

### 🎯 Dashboard View (Recommended)

**The best way to use TM-Monitor is with the dashboard launcher:**

```bash
# Launch split-screen dashboard
tm-dashboard
```

This creates a professional monitoring setup:
- **Left window**: Main backup monitor (144 columns wide)
- **Right window**: Resource usage monitor (65 columns wide)
- **Auto-positioned**: Windows are perfectly aligned
- **Retina-aware**: Works correctly on all displays

#### Dashboard Options

```bash
# Use specific terminal app
tm-dashboard --terminal iTerm2     # Force iTerm2
tm-dashboard --terminal Terminal   # Force Terminal.app

# Monitor only (no resource window)
tm-dashboard --no-resources

# Adjust for different font sizes
tm-dashboard --char-width 7   # Smaller fonts
tm-dashboard --char-width 10  # Larger fonts

# Show help
tm-dashboard --help
```

#### Dashboard Features
- 🖥️ **Auto-detects** Terminal.app or iTerm2
- 📐 **Smart positioning** - Resource window aligned to right edge
- 🔝 **Brings to front** - Windows open on top of stack
- 🧹 **Clean startup** - Kills existing instances first
- 🎨 **Font-aware** - Adjustable character width for different fonts

### Basic Monitoring

```bash
# Start monitoring with defaults (auto-starts Time Machine if not running)
tm-monitor

# Monitor without auto-starting Time Machine
tm-monitor --no-auto-start

# Monitor with 1-second updates
tm-monitor -i 1

# Use GiB instead of GB
tm-monitor --units 1024

# Enable debug logging
tm-monitor -d

# Log to CSV for analysis
tm-monitor -l

# Disable colors
tm-monitor -c

# Show help
tm-monitor --help

# Kill all running tm-monitor instances (useful for cleanup)
tm-monitor --kill-all
```

### Resource Monitoring

Monitor CPU and memory usage of tm-monitor processes:

```bash
# Check resource usage once
tm-monitor-resources

# Continuous monitoring (updates every 2 seconds)
tm-monitor-resources --watch

# Custom update interval
tm-monitor-resources -w -i 5

# Without colors
tm-monitor-resources -c
```

### Historical Statistics (NEW - WIP)

View and analyze historical backup data:

```bash
# Show overall summary
tm-monitor-stats summary

# View recent backup sessions
tm-monitor-stats sessions

# Show last 20 sessions
tm-monitor-stats sessions 20

# Display speed graph for current session
tm-monitor-stats graph

# Display speed graph for specific session
tm-monitor-stats graph 42

# Show hourly statistics
tm-monitor-stats hourly

# Show hourly stats for last 30 days
tm-monitor-stats hourly 30

# Export session data to CSV
tm-monitor-stats export 42

# Clean up old data
tm-monitor-stats cleanup
```

### Update Management

TM-Monitor includes a sophisticated auto-update system:

```bash
# Check for updates manually
tm-monitor --update-check

# Install available update
tm-monitor --update

# Configure update settings
tm-monitor --update-settings      # Show current settings
tm-monitor --update-frequency daily  # Set check frequency
tm-monitor --update-disable       # Disable auto-checks
tm-monitor --update-enable        # Re-enable auto-checks
tm-monitor --update-snooze 7      # Snooze for 7 days
```

### Configuration

Create a configuration file to set defaults:

```bash
# Create sample config
tm-monitor --create-config

# Edit the config file
nano ~/.config/tm-monitor/config.conf
```

Configuration options:

**Basic Settings:**
- `INTERVAL` - Update interval in seconds (1-300)
- `UNITS` - Size units: 1000 (GB) or 1024 (GiB)
- `SHOW_COLORS` - Enable/disable colored output
- `SHOW_SUMMARY` - Show summary on exit
- `DEBUG` - Enable debug logging
- `CSV_LOG` - Enable CSV logging
- `MAX_FAILURES` - Max tmutil failures before giving up

**Storage Settings:**
- `TM_STORAGE_ENABLED` - Enable SQLite storage (default: true)
- `TM_STORAGE_RETENTION_DAYS` - Days to keep historical data (default: 30)
- `TMUTIL_CACHE_TTL` - Cache TTL in seconds (default: 2)

**Update Settings:**
- `UPDATE_CHECK_ENABLED` - Enable automatic update checks (default: true)
- `UPDATE_CHECK_INTERVAL` - Seconds between checks (86400 = daily)
- `UPDATE_CHECK_CHANNEL` - Update channel: stable/beta/edge
- `UPDATE_NOTIFICATION_STYLE` - Notification style: banner/inline/silent
- `UPDATE_AUTO_INSTALL` - Auto-install updates (default: false)
- `GITHUB_REPO` - GitHub repository for updates

## 📊 Command Line Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-i` | `--interval SECONDS` | Update interval | 2 |
| `-u` | `--units 1000\|1024` | Size units (GB vs GiB) | 1000 |
| `-c` | `--no-colors` | Disable colored output | false |
| `-s` | `--no-summary` | Don't show summary on exit | false |
| `-d` | `--debug` | Enable debug logging | false |
| `-l` | `--csv-log` | Enable CSV logging | false |
| | `--no-auto-start` | Disable automatic Time Machine startup | false |
| | `--kill-all` | Kill all running tm-monitor instances | - |
| `-C` | `--create-config` | Create sample config file | - |
| | **Update Options** | | |
| | `--update` | Install available update | - |
| | `--update-check` | Check for updates now | - |
| | `--update-enable` | Enable automatic update checks | - |
| | `--update-disable` | Disable automatic update checks | - |
| | `--update-snooze [DAYS]` | Snooze update notifications | 7 |
| | `--update-frequency` | Set check frequency (hourly/daily/weekly/monthly) | - |
| | `--update-settings` | Show current update settings | - |
| `-v` | `--version` | Show version information | - |
| `-h` | `--help` | Show help message | - |

## 🏗️ Architecture

TM-Monitor uses a sophisticated hybrid architecture:

### Core Components

- **Main Monitor** (`tm-monitor`) - Real-time backup tracking
  - Python helper daemon for stateful calculations
  - Speed smoothing over 30-second windows
  - Complex ETA and progress calculations
  - Batch vs total progress tracking
  - SQLite storage integration for historical data
  - Automatic Time Machine startup when not running
  - Intelligent backup completion detection

- **Resource Monitor** (`tm-monitor-resources`) - System resource tracking
  - Standalone bash implementation
  - CPU/memory usage monitoring
  - Time Machine status display
  - Session statistics
  - Shared cache with main monitor
  - Fixed footer positioning with scroll regions

- **Statistics Viewer** (`tm-monitor-stats`) - Historical data analysis
  - Terminal-based speed graphs
  - Session history browsing
  - Hourly statistics aggregation
  - Data export to CSV
  - Database management

- **Python Helper** (`tm-monitor-helper.py`) - Calculation daemon
  - Persistent process to avoid startup overhead
  - Stateful speed calculations
  - Ring buffer for speed smoothing
  - Type-hinted for reliability

### Library Modules

- **Core Modules**
  - `version.sh` - Version management
  - `paths.sh` - Centralized path management
  - `colors.sh` - Color definitions and detection
  - `python_check.sh` - Python version detection
  - `dependencies.sh` - Dependency checking
  - `core.sh` - Centralized initialization
  - `arguments.sh` - Argument parsing

- **Functional Modules**
  - `tmutil.sh` - Time Machine status parsing with shared caching
  - `state.sh` - Session state management
  - `display.sh` - Terminal UI rendering
  - `logger.sh` - Logging functionality
  - `config.sh` - Configuration handling
  - `process.sh` - Process management
  - `constants.sh` - Application constants
  - `resource_helpers.sh` - Resource monitoring helpers
  - `storage.sh` - SQLite persistent storage
  - `formatting.sh` - Unified formatting functions
  - `terminal.sh` - Terminal management
  - `system_info.sh` - System information retrieval
  - `process_management.sh` - Process finding and parsing

## 📁 Project Structure

```
tm-monitor/
├── bin/
│   ├── tm-monitor              # Main monitor script
│   ├── tm-monitor-resources    # Resource monitor
│   ├── tm-monitor-stats        # Historical statistics viewer (with watch mode)
│   ├── tm-dashboard            # Split-screen dashboard launcher
│   └── tm-monitor-helper.py    # Python calculation daemon
├── lib/
│   ├── colors.sh               # Color definitions
│   ├── config.sh               # Configuration handling
│   ├── constants.sh            # Application constants
│   ├── dependencies.sh         # Dependency checking
│   ├── display.sh              # UI rendering
│   ├── logger.sh               # Logging functions
│   ├── paths.sh                # Path management
│   ├── process.sh              # Process management
│   ├── python_check.sh         # Python detection
│   ├── resource_helpers.sh     # Resource monitoring helpers
│   ├── state.sh                # State management
│   ├── tmutil.sh               # Time Machine status parsing
│   └── version.sh              # Version management
├── config/
│   └── tm-monitor.conf.example # Sample configuration
├── docs/                       # Documentation
│   ├── SMOOTHING.md            # Smoothing algorithms
│   ├── RESOURCE_METRICS.md     # CPU/Memory metrics
│   └── TMUTIL_STATUS_KEYS.md   # tmutil status reference
├── tests/                      # Test scripts
├── install.sh                  # Professional installer
├── uninstall.sh                # Clean uninstaller
├── LICENSE                     # MIT License
├── CHANGELOG.md                # Version history
├── README.md                   # This file
└── Makefile                    # Make targets
```

## 🔧 Troubleshooting

### Common Issues

**"Time Machine not found" error**
- Ensure Time Machine is configured in System Settings → General → Time Machine

**Numbers showing as "-"**
- This is normal when Time Machine is idle or between backup phases

**Python not found**
- Run `./install.sh --check-only` to diagnose
- The installer will find the best Python version automatically

**Permission denied**
- Make sure scripts are executable: `chmod +x bin/*`

## 🔒 Security

- **No eval usage** - Safe configuration parsing
- **Input validation** - All user input is validated
- **Safe path handling** - Proper quoting and escaping
- **Process isolation** - Helper runs as separate process

## 🚀 Performance

- **Efficient daemon** - Python helper avoids repeated startup
- **Speed smoothing** - 30-second rolling average
- **Minimal subprocess calls** - Caching where appropriate
- **Optimized parsing** - Fast JSON processing

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the need for better Time Machine visibility
- Built for the macOS community
- Thanks to all contributors

## 📞 Support

- 🐛 [Report bugs](https://github.com/twickstrom/TimeMachineMonitor/issues)
- 💡 [Request features](https://github.com/twickstrom/TimeMachineMonitor/issues)
- 📖 [Read the docs](https://github.com/twickstrom/TimeMachineMonitor/wiki)
- ⭐ Star this project if you find it useful!

## 🔄 Changelog

For a detailed list of changes and version history, see [CHANGELOG.md](CHANGELOG.md).

---

## ⭐ Star History

If you find TM-Monitor useful, please star ⭐ this repository!

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

---

<div align="center">
Made with ❤️ for the Apple macOS community by Tim Wickstrom

**[Report Bug](https://github.com/twickstrom/TimeMachineMonitor/issues) · [Request Feature](https://github.com/twickstrom/TimeMachineMonitor/issues) · [Contribute](CONTRIBUTING.md)**
</div>
