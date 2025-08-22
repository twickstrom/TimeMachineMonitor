# Changelog

All notable changes to TimeMachineMonitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-01-01

### Added
- Professional installer with multiple installation modes (user/system/dev)
- Automatic Python version detection and compatibility checking
- Centralized module architecture for better maintainability
- Smoothing system for Speed, Files/s, and ETA metrics
- Weighted average algorithm for ETA calculations
- 90-second smoothing window for initial backups (auto-detected)
- Command line option `-w, --window` for custom smoothing windows
- Resource monitoring tool (`tm-monitor-resources`) for CPU/memory tracking
- Time Machine status display in resource monitor
- Session statistics tracking (duration, samples, average speed)
- CSV logging capability for data analysis
- Comprehensive documentation:
  - CONTRIBUTING.md - Contribution guidelines
  - SECURITY.md - Security policy
  - SMOOTHING.md - Smoothing algorithms documentation
  - RESOURCE_METRICS.md - CPU/Memory metrics explained
  - TMUTIL_STATUS_KEYS.md - Complete tmutil status key reference
  - ARCHITECTURE.md - System architecture overview
- Quick start script for one-command installation
- Phase change detection with buffer resets
- Percentage clamping to ensure values never exceed 100%
- Debug warnings when percentage clamping occurs
- Load average color coding and explanation
- Impact assessment for CPU and memory usage
- Helper functions library (resource_helpers.sh)
- Centralized tmutil parsing library
- Safe eval-free configuration parsing

### Changed
- Refactored to eliminate all eval usage for security
- Improved error handling throughout the codebase
- Better color management with centralized definitions
- Enhanced ETA format (now shows "> 24:00:00" instead of "> 24h")
- Optimized Python helper daemon for reduced overhead
- Updated all modules to use proper function exports
- Improved process management with proper cleanup
- Migrated to centralized path management (paths.sh)
- Refactored to use centralized version management
- Resource monitor now uses shared library functions
- Improved terminal updates without screen flashing

### Fixed
- Quote escaping issues in Python code within bash
- Bash parentheses parsing errors
- Missing function exports in library modules
- Path creation issues during first run
- Resource monitor display bug (process rows not showing)
- Memory leaks in long-running sessions
- Terminal restoration issues on interrupt
- Duplicate version definitions
- Incorrect module references (python_utils.sh -> python_check.sh)
- CONFIG_FILE reference before definition
- DRY violations in resource monitoring code
- Undefined variable references throughout codebase

### Security
- Removed all eval usage from configuration parsing
- Added input validation for all user inputs
- Implemented safe path handling throughout
- Added process isolation for helper daemon

## [0.8.0] - 2024-12-15

### Added
- Initial public release
- Real-time Time Machine backup monitoring
- Progress tracking with speed calculations
- Color-coded phase display
- Session statistics and summaries
- Basic configuration file support

## [0.1.0] - 2024-12-01

### Added
- Initial development version
- Core monitoring functionality
- Basic tmutil status parsing

---

## Roadmap

### Planned for Future Releases
- [ ] Web dashboard interface
- [ ] Historical data storage and graphing
- [ ] Email/notification alerts for backup completion
- [ ] Support for multiple backup destinations
- [ ] Integration with macOS Notification Center
- [ ] Backup health scoring system
- [ ] Predictive completion time using ML
- [ ] Export reports in multiple formats (PDF, HTML)
- [ ] Dark/light theme auto-switching
- [ ] Localization support

## Version History Note

TimeMachineMonitor follows semantic versioning:
- MAJOR version for incompatible API changes
- MINOR version for backwards-compatible functionality additions  
- PATCH version for backwards-compatible bug fixes

For upgrade instructions, see the README.md file.
