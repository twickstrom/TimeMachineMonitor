#!/usr/bin/env python3
"""
tm-monitor-helper.py - Python helper daemon for tm-monitor
Handles JSON parsing and calculations to avoid spawning Python repeatedly
"""

import sys
import json
import signal
import time
import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional, Any

class TMMonitorHelper:
    """Helper daemon for Time Machine monitoring calculations."""
    
    def __init__(self, units: int = 1000) -> None:
        """Initialize the helper with specified units (1000 or 1024)."""
        self.units: int = units
        self.prev_bytes: int = 0
        self.prev_files: int = 0
        self.prev_timestamp: int = 0
        self.running: bool = True
        
        # Ring buffer for speed smoothing (store tuples of timestamp, bytes)
        self.speed_buffer: List[Tuple[int, int]] = []
        # Ring buffer for files/s smoothing (store tuples of timestamp, files)
        self.files_buffer: List[Tuple[int, int]] = []
        # Ring buffer for ETA smoothing (store tuples of timestamp, eta_seconds)
        self.eta_buffer: List[Tuple[int, int]] = []
        self.buffer_window: int = 30  # default seconds to keep in buffer
        self.is_initial_backup: bool = False  # Will be set from tmutil data
        self.prev_phase: str = ""  # Track phase changes
        
        # Stable batch total for consistency
        self.stable_batch_total: float = 0.0
        
        # Set up signal handlers
        signal.signal(signal.SIGTERM, self.handle_signal)
        signal.signal(signal.SIGINT, self.handle_signal)
    
    def handle_signal(self, signum: int, frame: Any) -> None:
        """Handle shutdown signals gracefully."""
        self.running = False
        sys.exit(0)
    
    def calculate_speed(self, delta_bytes: int, delta_time: int) -> str:
        """Calculate speed in MB/s from byte and time deltas."""
        if delta_time > 0 and delta_bytes >= 0:
            bytes_per_sec: float = delta_bytes / delta_time
            mbps: float = bytes_per_sec / (self.units ** 2)
            return f'{mbps:.2f} MB/s'
        return '-'
    
    def calculate_eta(self, bytes_per_sec: int, total_bytes: int, 
                     copied_total_bytes: int) -> str:
        """Calculate estimated time remaining."""
        if bytes_per_sec > 0 and total_bytes > 0:
            try:
                remain: int = max(0, total_bytes - copied_total_bytes)
                eta_seconds: int = remain // bytes_per_sec
                
                # Show actual time if under 24 hours, otherwise show > 24h
                if eta_seconds < 86400:
                    hours: int = eta_seconds // 3600
                    minutes: int = (eta_seconds % 3600) // 60
                    seconds: int = eta_seconds % 60
                    return f'{hours}:{minutes:02d}:{seconds:02d}'
                else:
                    return '> 24:00:00'
            except (ZeroDivisionError, ValueError, OverflowError):
                pass
        return '-'
    
    def calculate_smoothed_eta(self, current_time: int, bytes_per_sec: int, 
                               total_bytes: int, copied_total_bytes: int) -> Tuple[str, int]:
        """Calculate and smooth ETA values."""
        eta_str: str = '-'
        eta_seconds: int = 0
        
        if bytes_per_sec > 0 and total_bytes > 0:
            try:
                remain: int = max(0, total_bytes - copied_total_bytes)
                eta_seconds = remain // bytes_per_sec
                
                # Add to ETA buffer
                self.eta_buffer.append((current_time, eta_seconds))
                
                # Clean old entries from buffer
                cutoff_time: int = current_time - self.buffer_window
                self.eta_buffer = [(t, e) for t, e in self.eta_buffer if t >= cutoff_time]
                
                # Calculate weighted average ETA from buffer
                # Give more weight to recent samples
                if len(self.eta_buffer) > 0:
                    total_weight: float = 0
                    weighted_sum: float = 0
                    
                    for i, (t, e) in enumerate(self.eta_buffer):
                        # Weight increases linearly from 1 to len(buffer)
                        weight: float = i + 1
                        weighted_sum += e * weight
                        total_weight += weight
                    
                    avg_eta: int = int(weighted_sum / total_weight) if total_weight > 0 else eta_seconds
                    
                    # Format the smoothed ETA
                    if avg_eta < 86400:
                        hours: int = avg_eta // 3600
                        minutes: int = (avg_eta % 3600) // 60
                        seconds: int = avg_eta % 60
                        eta_str = f'{hours}:{minutes:02d}:{seconds:02d}'
                    else:
                        eta_str = '> 24:00:00'
                        
            except (ZeroDivisionError, ValueError, OverflowError):
                pass
                
        return eta_str, eta_seconds
    
    def process_tmutil_json(self, json_str: str) -> str:
        """Process tmutil status JSON and return formatted data."""
        try:
            if not json_str or json_str == "QUIT":
                return "QUIT"
            
            data: Dict[str, Any] = json.loads(json_str)
            
            # Extract values with safe defaults
            running: int = int(data.get('Running', 0))
            phase: str = str(data.get('BackupPhase', 'Unknown'))
            progress: Dict[str, Any] = data.get('Progress', {})
            
            # Clear ETA buffer if phase changed (different calculation needed)
            if phase != self.prev_phase:
                self.eta_buffer = []
                self.prev_phase = phase
            
            bytes_val: int = int(progress.get('bytes', 0))
            total_bytes: int = int(progress.get('totalBytes', 0))
            percent: float = float(progress.get('Percent', 0))
            files: int = int(progress.get('files', 0))
            
            # Check if this is an initial backup and adjust window accordingly
            first_backup: int = int(data.get('FirstBackup', 0))
            if first_backup == 1:
                self.is_initial_backup = True
                # Use 90 second window for initial backups unless overridden
                if os.environ.get('TM_INITIAL_BACKUP_WINDOW'):
                    self.buffer_window = int(os.environ.get('TM_INITIAL_BACKUP_WINDOW', '90'))
                else:
                    self.buffer_window = 90
            
            current_time: int = int(time.time())
            
            # Update buffers with current samples
            self.speed_buffer.append((current_time, bytes_val))
            self.files_buffer.append((current_time, files))
            
            # Clean old entries from buffers (keep only recent window)
            cutoff_time: int = current_time - self.buffer_window
            self.speed_buffer = [(t, b) for t, b in self.speed_buffer if t >= cutoff_time]
            self.files_buffer = [(t, f) for t, f in self.files_buffer if t >= cutoff_time]
            # Note: eta_buffer is cleaned in calculate_smoothed_eta
            
            # Initialize return values
            speed: str = '-'
            files_per_sec: str = '-'
            bytes_per_sec: int = 0
            
            # Calculate smoothed speed using buffer window
            if len(self.speed_buffer) >= 2:
                # Get oldest and newest samples in buffer
                oldest_time, oldest_bytes = self.speed_buffer[0]
                newest_time, newest_bytes = self.speed_buffer[-1]
                
                delta_time: int = newest_time - oldest_time
                delta_bytes: int = newest_bytes - oldest_bytes
                
                if delta_time > 0 and delta_bytes >= 0:
                    bytes_per_sec = delta_bytes // delta_time
                    speed = self.calculate_speed(delta_bytes, delta_time)
            
            # Calculate smoothed files/s using buffer window
            if len(self.files_buffer) >= 2:
                # Get oldest and newest samples in files buffer
                oldest_time_f, oldest_files = self.files_buffer[0]
                newest_time_f, newest_files = self.files_buffer[-1]
                
                delta_time_f: int = newest_time_f - oldest_time_f
                delta_files: int = newest_files - oldest_files
                
                if delta_time_f > 0 and delta_files >= 0:
                    files_rate: float = delta_files / delta_time_f
                    files_per_sec = f'{files_rate:.2f}/s'
            
            # Initialize batch and total metrics
            copied_batch: str = '-'
            pct_batch: str = '-'
            copied_total: str = '-'
            pct_total: str = '-'
            eta: str = '-'
            
            # Handle different phases
            if 'Thinning' in phase or 'Deleting' in phase:
                # During thinning, show different metrics
                if bytes_val > 0 and total_bytes > 0:
                    gb_copied: float = bytes_val / (self.units ** 3)
                    gb_total: float = total_bytes / (self.units ** 3)
                    copied_total = f'{gb_copied:.2f} GB / {gb_total:.2f} GB'
                    # Clamp percentage to valid range [0, 100]
                    thinning_pct: float = (bytes_val / total_bytes) * 100 if total_bytes > 0 else 0
                    thinning_pct = max(0.0, min(100.0, thinning_pct))
                    pct_total = f'{thinning_pct:6.2f}%'
                    copied_batch = 'Thinning'
                    pct_batch = '-'
            elif 0 < percent <= 1 and bytes_val > 0 and total_bytes > 0:
                # Normal copying phase calculations
                try:
                    batch_total: float = bytes_val / percent
                    
                    # Stabilize batch total to prevent jumping
                    if (not self.stable_batch_total or 
                        abs(batch_total - self.stable_batch_total) > (1 * self.units ** 3)):
                        self.stable_batch_total = batch_total
                    else:
                        batch_total = self.stable_batch_total
                    
                    gb_copied: float = bytes_val / (self.units ** 3)
                    gb_batch: float = batch_total / (self.units ** 3)
                    copied_batch = f'{gb_copied:.2f} GB / {gb_batch:.2f} GB'
                    
                    # Calculate batch percentage and clamp to valid range [0, 100]
                    batch_pct: float = (bytes_val / batch_total) * 100 if batch_total > 0 else 0
                    if batch_pct > 100.0:
                        sys.stderr.write(f"Warning: Batch % was {batch_pct:.2f}%, clamping to 100%\n")
                        sys.stderr.flush()
                    batch_pct = max(0.0, min(100.0, batch_pct))
                    pct_batch = f'{batch_pct:6.2f}%'
                    
                    copied_total_bytes: float = max(0, (total_bytes - batch_total) + bytes_val)
                    # Ensure copied total never exceeds total bytes
                    copied_total_bytes = min(copied_total_bytes, total_bytes)
                    
                    gb_copied_total: float = copied_total_bytes / (self.units ** 3)
                    gb_total: float = total_bytes / (self.units ** 3)
                    copied_total = f'{gb_copied_total:.2f} GB / {gb_total:.2f} GB'
                    
                    if total_bytes > 0:
                        # Calculate total percentage and clamp to valid range [0, 100]
                        total_pct: float = (copied_total_bytes / total_bytes) * 100
                        if total_pct > 100.0:
                            sys.stderr.write(f"Warning: Total % was {total_pct:.2f}%, clamping to 100%\n")
                            sys.stderr.flush()
                        total_pct = max(0.0, min(100.0, total_pct))
                        pct_total = f'{total_pct:6.2f}%'
                    
                    # Calculate smoothed ETA
                    eta, _ = self.calculate_smoothed_eta(current_time, bytes_per_sec, 
                                                         total_bytes, int(copied_total_bytes))
                    
                except (ZeroDivisionError, ValueError, OverflowError) as e:
                    sys.stderr.write(f"Calculation error: {e}\n")
                    sys.stderr.flush()
            
            # Update state for next iteration
            self.prev_bytes = bytes_val
            self.prev_files = files
            self.prev_timestamp = current_time
            
            # Return pipe-delimited result
            return '|'.join(str(x) for x in [
                current_time, phase, bytes_val, files, total_bytes, percent,
                speed, files_per_sec, bytes_per_sec, copied_batch, pct_batch,
                copied_total, pct_total, eta
            ])
            
        except json.JSONDecodeError as e:
            sys.stderr.write(f"JSON parsing error: {e}\n")
            sys.stderr.flush()
            return f"0|JSONError|0|0|0|0|-|-|0|-|-|-|-|-"
        except (KeyError, ValueError, TypeError) as e:
            sys.stderr.write(f"Data extraction error: {e}\n")
            sys.stderr.flush()
            return f"0|DataError|0|0|0|0|-|-|0|-|-|-|-|-"
        except Exception as e:
            sys.stderr.write(f"Unexpected error: {e}\n")
            sys.stderr.flush()
            return f"0|Error|0|0|0|0|-|-|0|-|-|-|-|-"
    
    def run(self) -> None:
        """Main loop - read JSON from stdin, write results to stdout."""
        sys.stderr.write(f"Helper started with PID {os.getpid()}\n")
        sys.stderr.flush()
        
        while self.running:
            try:
                line: str = sys.stdin.readline()
                if not line:
                    break
                
                line = line.strip()
                if line == "QUIT":
                    break
                
                result: str = self.process_tmutil_json(line)
                if result == "QUIT":
                    break
                
                print(result, flush=True)
                
            except KeyboardInterrupt:
                break
            except IOError as e:
                sys.stderr.write(f"IO error: {e}\n")
                sys.stderr.flush()
                break
            except Exception as e:
                sys.stderr.write(f"Helper error: {e}\n")
                sys.stderr.flush()
        
        sys.stderr.write("Helper shutting down\n")
        sys.stderr.flush()

def main() -> None:
    """Main entry point."""
    # Get configuration from environment
    units: int = int(os.environ.get('TM_UNITS', '1000'))
    buffer_window: int = int(os.environ.get('TM_SPEED_WINDOW', '30'))
    initial_window: int = int(os.environ.get('TM_INITIAL_BACKUP_WINDOW', '90'))
    
    # Validate units
    if units not in (1000, 1024):
        sys.stderr.write(f"Invalid units: {units}, using 1000\n")
        sys.stderr.flush()
        units = 1000
    
    sys.stderr.write(f"Helper config: units={units}, window={buffer_window}s, initial_window={initial_window}s\n")
    sys.stderr.flush()
    
    # Create and run helper
    helper = TMMonitorHelper(units=units)
    helper.buffer_window = buffer_window
    helper.run()

if __name__ == "__main__":
    main()
