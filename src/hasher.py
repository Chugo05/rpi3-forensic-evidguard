#!/usr/bin/env python3
"""
Hash Checker module
Supports streaming hash calculation with progress for large devices/files
"""
import hashlib
import os
import sys

class HashChecker:
    ALGORITHMS = {
        "md5": hashlib.md5,
        "sha1": hashlib.sha1,
        "sha256": hashlib.sha256,
        "sha512": hashlib.sha512,
        "blake2b": hashlib.blake2b,
    }

    def __init__(self, algorithm="sha256", chunk_size=4*1024*1024):
        if algorithm not in self.ALGORITHMS:
            raise ValueError(f"Unsupported algorithm: {algorithm}. Use: {list(self.ALGORITHMS.keys())}")
        self.algorithm = algorithm
        self.chunk_size = chunk_size

    def hash_path(self, path, progress=True):
        """
        Calculate hash of a device or file.
        For block devices, size is unknown so progress shows bytes read.
        """
        hasher = self.ALGORITHMS[self.algorithm]()
        bytes_read = 0

        # Check if it's a block device to get size if possible
        total_size = None
        if os.path.exists(path):
            try:
                total_size = os.path.getsize(path)
            except OSError:
                pass

        with open(path, "rb") as f:
            while True:
                chunk = f.read(self.chunk_size)
                if not chunk:
                    break
                hasher.update(chunk)
                bytes_read += len(chunk)

                if progress:
                    if total_size and total_size > 0:
                        pct = (bytes_read / total_size) * 100
                        sys.stderr.write(f"\r[{self.algorithm.upper()}] {bytes_read}/{total_size} bytes ({pct:.1f}%)")
                    else:
                        sys.stderr.write(f"\r[{self.algorithm.upper()}] {bytes_read} bytes read...")
                    sys.stderr.flush()

        if progress:
            sys.stderr.write("\n")

        return {
            "algorithm": self.algorithm,
            "hash": hasher.hexdigest(),
            "bytes": bytes_read,
            "path": path
        }

    def verify(self, hash1, hash2):
        """Compare two hash dicts or hex strings"""
        h1 = hash1["hash"] if isinstance(hash1, dict) else hash1
        h2 = hash2["hash"] if isinstance(hash2, dict) else hash2
        return h1.lower() == h2.lower()
