#!/usr/bin/env python3
"""
Forensic audit logger
"""
import json
from datetime import datetime

class ForensicLogger:
    def __init__(self, log_path="forensic-guard.log"):
        self.log_path = log_path
        self.entries = []

    def log(self, stage, message, data=None):
        entry = {
            "timestamp": datetime.now().isoformat(),
            "stage": stage,
            "message": message,
            "data": data or {}
        }
        self.entries.append(entry)

        # Write immediately for persistence
        with open(self.log_path, "a") as f:
            f.write(json.dumps(entry) + "\n")

        return entry

    def header(self, case_id=""):
        self.log("START", f"Forensic Guard initiated", {"case": case_id})

    def footer(self):
        self.log("END", "Forensic Guard completed")

    def export_json(self, path):
        with open(path, "w") as f:
            json.dump(self.entries, f, indent=2)
