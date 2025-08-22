# tmutil status Key Reference

## Overview

This document provides a comprehensive reference for all keys returned by the `tmutil status` command in macOS 14+ (Sonoma) and macOS 15+ (Sequoia). Since `tmutil status` is an undocumented command, this information has been compiled from observed outputs and real-world usage.

## Key Reference Table

### Top-Level Keys

| Key | Type | Definition | Example Values | Appears In |
|-----|------|------------|----------------|------------|
| **BackupPhase** | String | Current stage of the Time Machine backup | "Copying", "Starting", "ThinningPreBackup", "MountingDiskImage", "Finishing" | All phases when backup is active |
| **ClientID** | String | Identifier of the backup daemon client (always Time Machine's bundle ID) | "com.apple.backupd" | All phases |
| **DateOfStateChange** | String (ISO date) | Timestamp when backup entered current state/phase | "2024-09-16 21:03:33 +0000" | All active phases |
| **DestinationID** | String (UUID) | Unique identifier of the backup destination | "B3D2100F-5891-4961-94E6-BDD11341CD2F" | All phases when destination is set |
| **DestinationMountPoint** | String (path) | Filesystem path where backup volume is mounted | "/Volumes/Time Machine Backups" | All phases after destination mounted |
| **Running** | Number (0 or 1) | Whether Time Machine backup is currently running | 1 = running, 0 = not running | Always present |
| **Stopping** | Number (0 or 1) | Whether stop/cancellation has been requested | 1 = stopping, 0 = normal | Only during cancellation |
| **FirstBackup** | Number (0 or 1) | Whether this is the first backup to this destination | 1 = initial full backup | Starting/Copying of first backup only |
| **NumberOfChangedItems** | Number | Count of items identified as changed | 2020012 (increments during scan) | Preparation phases |
| **FractionOfProgressBar** | String (float 0-1) | Fraction of progress bar allocated to current phase | "0.9" (90% for copy phase) | Copying phase |
| **attemptOptions** | Number (bitmask) | Flags for how backup was initiated | 1, 1042 (varies by scenario) | All active backup phases |
| **Progress** | Dictionary | Detailed progress metrics for current phase | See nested keys below | Data transfer phases |

### Progress Dictionary Keys (Nested)

| Key | Type | Definition | Example Values | Appears In |
|-----|------|------------|----------------|------------|
| **Percent** | String/Number (float) | Percentage of current phase completed (0.0-1.0) | "0.4725556582622986" (47.3%) | Copying, Thinning phases |
| **TimeRemaining** | Number (seconds) | Estimated seconds to complete current phase | 15549.20435386221 | Primarily Copying phase |
| **bytes** | Number | Bytes processed so far in this phase | 121972273152 | Copying, Thinning phases |
| **totalBytes** | Number | Total bytes to process in this phase | 886845165568 | Copying, Thinning phases |
| **files** | Number | Files/items processed so far | 2593015 | Copying phase |
| **totalFiles** | Number | Total files/items to process | 29771424 | Copying phase |
| **_raw_Percent** | String/Number (float) | Raw percentage (often matches Percent) | "0.4725556582622986" | When Percent is present |
| **_raw_totalBytes** | Number | Raw total bytes (often matches totalBytes) | 886845165568 | When byte counts tracked |

## Common BackupPhase Values

### Known BackupPhase Values in Time Machine (macOS 14+ Sonoma/Sequoia)

| Phase | Definition/Meaning | When/Why It Occurs | Sources |
|-------|-------------------|---------------------|----------|
| **Starting** | The backup has just started – Time Machine's backup engine is initializing the session. Initial checks or setup before any file copying begins. | Occurs right after a backup is initiated. During this phase, no data is yet copied (Percent may be -1), and the macOS UI typically shows "Preparing backup…". Appears as the first phase if no immediate pre-backup thinning is needed. | Apple SE user output showing BackupPhase = Starting with 0% progress |
| **PreparingSourceVolumes** | Time Machine is preparing the source volume(s) for backup, for example by creating snapshots of those volumes to capture their state. In APFS-based backups, this represents making the source disk(s) ready for a consistent backup. | Occurs early in the backup (after "Starting"). Especially on APFS systems, Time Machine will create a local APFS snapshot of each source volume during this phase, ensuring the backup captures a static view of the data. | Apple Unified Log (Big Sur) showing Time Machine creating local snapshots |
| **MountingBackupVol** | Time Machine is mounting the backup volume (destination). The backup drive/partition is being accessed and attached to the system so the backup can proceed. | Occurs if the backup destination isn't already mounted. For example, when an external disk is plugged in or a network share is contacted at backup start. Typically seen at the beginning of a backup session before scanning or copying. | tmutil status showing BackupPhase = MountingBackupVol while Time Machine volume was being mounted |
| **MountingDiskImage** | For network or disk image-based backups, Time Machine is mounting the sparsebundle disk image that contains the backup. This phase indicates the backup disk image file is being opened/attached. | Occurs when backing up to a network Time Machine destination (e.g., NAS or Time Capsule) or an encrypted backup that uses a disk image. Corresponds to the "Preparing to back up… mounting" step for network backups. | TrueNAS forum: BackupPhase = MountingDiskImage when mounting sparsebundle for network backup |
| **FindingChanges** | Time Machine is determining which files and folders have changed since the last backup. It scans the source (using FSEvents or snapshot differences) to compile the list of items to back up. | Occurs after the backup destination is ready. Part of "Preparing backup…" in the UI. Time Machine computes the delta of changes. In older macOS versions this was referred to as "CalculatingChanges". Ends once all changes to copy are identified. | Third-party tools confirm FindingChanges as the phase where Time Machine is "finding changes" to back up |
| **Copying** | The main backup phase in which changed files are being copied to the backup destination. Time Machine is actively transferring data (files and bytes) to the backup. | Occurs after the list of changes is prepared. This phase corresponds to the visible progress of backup (e.g., "X GB of Y GB copied"). Shows increasing Percent and counters for files/bytes during copying. Typically the longest phase. | Example output: BackupPhase = Copying with detailed Progress dictionary (files, bytes, totalBytes, etc.) |
| **ThinningPreBackup** | Time Machine is deleting old backups before the current backup runs, to free up space. The backup daemon purges expired or least-recent backups as needed to fulfill space requirements. | Occurs before copying when the destination is low on space. The system reports "Preparing backup…" while it removes old snapshots/backup instances to make room. Ends once sufficient space is cleared (or skipped if no thinning needed). | Apple SE: tmutil status showed BackupPhase = ThinningPreBackup during "Preparing backup," indicating removal of old backups due to space constraints |
| **ThinningPostBackup** | Time Machine is deleting older backups after a successful backup, as part of routine thinning (e.g., removing outdated hourly/daily snapshots per retention policy or additional space cleanup). | Occurs after the copying phase and after finalizing the new backup. The macOS GUI shows "Cleaning up…" during this phase. Time Machine culls old backups according to its schedule (e.g., hourly backups older than 24 hours). | Apple Community: User observed "Cleaning up…" with BackupPhase = ThinningPostBackup, meaning deletion of now-unneeded older backups |
| **Finishing** | The backup is in its final completion stage. Time Machine is finishing up the backup session – recording metadata, updating indexes, and performing any final tasks to finalize the backup. | Occurs right after all data is copied (and after any post-backup thinning). Time Machine writes the "complete" status for the backup (updating the backup catalog, indexing Spotlight). The UI may show "Finishing backup…". | Server Fault Q&A: "Finishing backup…" involves Time Machine recording changes and wrapping up the backup |
| **Stopping** | The backup is being stopped/cancelled. Time Machine has received a stop request and is aborting the current backup safely – it closes out the in-progress backup and cleans up any partial data. | Occurs when a backup is manually canceled or interrupted. Indicates that backupd is terminating the session. You may see this if you click "Cancel" (UI might briefly say "Stopping…"). | tmutil-status utility includes Stopping phase state; appears after issuing tmutil stopbackup |

### Additional Phase Notes

- **BackupNotRunning**: Older macOS term for when no backup is active (modern systems use Running=0)
- **CalculatingChanges**: Older name for FindingChanges phase (pre-macOS 13)
- Phase transitions are recorded in `DateOfStateChange` field
- Each phase has distinct UI representations in System Settings/Time Machine
- Network backups have additional phases (MountingDiskImage) not seen in local backups
- The `NumberOfChangedItems` field increments during FindingChanges/PreparingSourceVolumes phases

Each of the above values has been observed in Time Machine's tmutil status output on macOS 14+ and are supported by multiple sources (Apple documentation is sparse, so developer logs, Apple Community posts, and credible third-party resources were used to verify each phase). All phases represent distinct steps of a Time Machine backup session, and monitoring BackupPhase helps automation scripts understand what Time Machine is doing at any given time.

## Understanding the Data

### Running States
- `Running = 1`: Backup is actively running
- `Running = 0`: No backup running (most fields will be absent)

### Progress Calculation
- **Phase Progress**: `Progress.Percent` shows completion of current phase (0.0 to 1.0)
- **Overall Progress**: Multiply `Progress.Percent` by `FractionOfProgressBar` for overall backup progress
- **Bytes Progress**: `Progress.bytes / Progress.totalBytes` gives byte-based completion
- **Files Progress**: `Progress.files / Progress.totalFiles` gives file-based completion

### Time Estimates
- `TimeRemaining` is in seconds
- Only available during `Copying` phase
- May fluctuate significantly early in backup

### Special Cases

#### First Backup
- `FirstBackup = 1` indicates initial full backup
- All files will be copied (no incremental)
- Will take significantly longer than incremental backups

#### Network Backups
- Include `MountingDiskImage` phase
- `DestinationMountPoint` points to mounted sparsebundle
- May have different `attemptOptions` values

#### Thinning Phases
- `ThinningPreBackup`: Occurs before copying to make space
- `ThinningPostBackup`: Occurs after copying to maintain retention
- Progress tracks bytes/files deleted rather than copied

## Version Compatibility

| macOS Version | tmutil status Support | Notes |
|---------------|----------------------|-------|
| 14.x (Sonoma) | Full | All keys documented here |
| 15.x (Sequoia) | Full | Same as Sonoma |
| 13.x (Ventura) | Partial | Some keys may differ |
| < 13.x | Limited | Different key structure |

## Example Output Parsing

### Active Backup (Copying Phase)
```json
{
    "BackupPhase": "Copying",
    "ClientID": "com.apple.backupd",
    "DateOfStateChange": "2025-08-21 06:10:22 +0000",
    "DestinationID": "A32438EA-87FC-4028-A559-9673AE09C188",
    "DestinationMountPoint": "/Volumes/Backups of Tim's MacBook Pro M2 Max",
    "FirstBackup": "1",
    "FractionOfProgressBar": "0.9",
    "Progress": {
        "Percent": "0.2890040192592089",
        "TimeRemaining": "119633.8977499993",
        "_raw_Percent": "0.2890040192592089",
        "_raw_totalBytes": "828480970752",
        "bytes": "39612698624",
        "files": "71643",
        "totalBytes": "828480970752",
        "totalFiles": "9348288"
    },
    "Running": "1",
    "attemptOptions": "1"
}
```

### No Active Backup
```
Not running
```
Or in JSON format:
```json
{
    "Running": "0"
}
```

## Using in tm-monitor

The tm-monitor application parses these keys to provide:
- **Real-time progress**: Using `Progress.Percent` and `FractionOfProgressBar`
- **Speed calculations**: Tracking changes in `Progress.bytes` over time
- **ETA calculations**: Using `Progress.TimeRemaining` or calculating from speed
- **Phase detection**: Mapping `BackupPhase` to user-friendly descriptions
- **Batch vs Total**: Calculating incremental batch size from `Progress` data

## Notes and Caveats

1. **Undocumented Command**: `tmutil status` is not officially documented by Apple and may change
2. **String vs Number Types**: plutil conversion often converts numbers to strings
3. **Missing Keys**: Many keys only appear during specific phases
4. **Version Differences**: Older macOS versions may have different key structures
5. **Network vs Local**: Network backups may have additional phases and different timing

## Sources

This documentation is compiled from:
- Observed outputs from macOS 14.x (Sonoma) and 15.x (Sequoia)
- Real-world Time Machine backup sessions
- Community observations and forum discussions
- Direct testing on production systems

**Note**: Since `tmutil status` is undocumented, this information is based on observation and reverse engineering. Apple may change the format or behavior in future macOS updates without notice.

## Related Documentation

- [SMOOTHING.md](SMOOTHING.md) - How tm-monitor smooths the raw data
- [RESOURCE_METRICS.md](RESOURCE_METRICS.md) - Understanding CPU/Memory metrics
- [README.md](../README.md) - Main documentation

---

*Last Updated: 2025-01-01*  
*Applies to: macOS 14+ (Sonoma and later)*
