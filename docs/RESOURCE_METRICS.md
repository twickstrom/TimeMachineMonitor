# Understanding Resource Metrics

## CPU%, MEM%, and RSS Explained

When monitoring tm-monitor processes, you'll see three key resource metrics:

### CPU% (CPU Percentage)
- **What it measures**: The percentage of CPU time used by the process
- **Range**: 0.00% to 100.00% (per core)
- **Note**: Can exceed 100% on multi-core systems if using multiple cores

### MEM% (Memory Percentage)
- **What it measures**: The percentage of total system memory used by the process
- **Calculation**: (Process Memory / Total System Memory) × 100
- **Why it might show 0.00%**: 
  - tm-monitor is very lightweight (typically uses < 20MB)
  - On a system with 32GB RAM, 20MB is only 0.06%
  - Values under 0.01% round down to 0.00%
- **Example**: On a 32GB system, tm-monitor using 18MB = 0.05% ≈ 0.00%

### RSS (Resident Set Size)
- **What it measures**: The actual physical memory (RAM) used by the process
- **Units**: Megabytes (MB)
- **More precise**: Shows exact memory usage in MB
- **Typical values**: 
  - tm-monitor (bash): 5-15 MB
  - tm-monitor-helper (python): 10-20 MB
  - Combined total: 15-35 MB

## Why Both MEM% and RSS?

- **MEM%** gives you context - how much of your total system resources is being used
- **RSS** gives you precision - exact memory consumption in MB

For tm-monitor, RSS is often more useful since the tool is so lightweight that MEM% will usually show 0.00% on modern systems with 16GB+ RAM.

## Example Output

```
PID        CPU%    MEM%   RSS(MB)       TIME  COMMAND
12345      0.40    0.00     12.50    0:00:15  tm-monitor
12346      0.20    0.00      8.25    0:00:10  python: tm-monitor-helper
------------------------------------------------------------------------
TOTAL      0.60%   0.00%    20.75MB
```

In this example:
- Combined CPU usage: 0.60% (very low impact)
- Combined MEM%: 0.00% (less than 0.01% of total RAM)
- Combined RSS: 20.75MB (actual memory used)

## Impact Assessment

The tool categorizes resource usage as:
- **Low**: Normal operation, minimal system impact
- **Moderate**: Noticeable but acceptable usage
- **High**: May impact system performance

Typical tm-monitor usage falls in the "Low" category for both CPU and memory.
