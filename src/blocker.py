#!/usr/bin/env python3
"""
Write Blocker module for Raspberry Pi 3B
Uses Linux kernel read-only flags + msuhanov patch compatibility
"""
import subprocess
import sys

class WriteBlocker:
    def __init__(self, device):
        self.device = device
        # Detect parent block device (e.g. /dev/sdb1 -> /dev/sdb)
        self.parent = self._detect_parent(device)

    def _detect_parent(self, dev):
        """Find parent block device for partitions"""
        try:
            result = subprocess.run(
                ["lsblk", "-no", "PKNAME", dev],
                capture_output=True, text=True, check=True
            )
            parent = result.stdout.strip()
            if parent:
                return f"/dev/{parent}"
        except Exception:
            pass
        return dev

    def enable(self):
        """Enable write blocking on device and parent"""
        targets = [self.parent]
        if self.device != self.parent:
            targets.append(self.device)

        results = []
        for target in targets:
            try:
                subprocess.run(
                    ["blockdev", "--setro", target],
                    check=True, capture_output=True
                )
                ro = subprocess.run(
                    ["blockdev", "--getro", target],
                    capture_output=True, text=True, check=True
                )
                if ro.stdout.strip() == "1":
                    results.append((target, True, "Read-only enabled"))
                else:
                    results.append((target, False, "Still read-write"))
            except subprocess.CalledProcessError as e:
                results.append((target, False, f"Error: {e.stderr.decode().strip()}"))

        return results

    def disable(self):
        """Disable write blocking (use with caution)"""
        targets = [self.parent]
        if self.device != self.parent:
            targets.append(self.device)

        results = []
        for target in targets:
            try:
                subprocess.run(
                    ["blockdev", "--setrw", target],
                    check=True, capture_output=True
                )
                results.append((target, True, "Read-write restored"))
            except subprocess.CalledProcessError as e:
                results.append((target, False, f"Error: {e.stderr.decode().strip()}"))
        return results

    def status(self):
        """Check current blocking status"""
        targets = [self.parent]
        if self.device != self.parent:
            targets.append(self.device)

        status = {}
        for target in targets:
            try:
                ro = subprocess.run(
                    ["blockdev", "--getro", target],
                    capture_output=True, text=True, check=True
                )
                status[target] = "READ-ONLY" if ro.stdout.strip() == "1" else "READ-WRITE"
            except Exception as e:
                status[target] = f"ERROR: {e}"
        return status
