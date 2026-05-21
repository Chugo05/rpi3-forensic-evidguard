#!/usr/bin/env python3
"""
RPI3 Forensic EvidGuard
=======================
Write Blocker + Hash Checker for Raspberry Pi 3 Model B
Designed to complement rclone (or any other imaging tool)

Usage:
    sudo python3 -m src.cli --block /dev/sdb
    sudo python3 -m src.cli --hash-pre /dev/sdb --save pre.json
    sudo python3 -m src.cli --hash-post /mnt/evidencia/imagen.raw --save post.json
    sudo python3 -m src.cli --verify pre.json post.json
    sudo python3 -m src.cli --full /dev/sdb /mnt/evidencia/imagen.raw --case CASE-001
"""
import argparse
import sys
import os
import json

from .blocker import WriteBlocker
from .hasher import HashChecker
from .logger import ForensicLogger

def main():
    parser = argparse.ArgumentParser(
        description="RPI3 Forensic EvidGuard - Write Blocker + Hash Checker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Integration with rclone:
  1. Block device:   sudo rpi3-evidguard --block /dev/sdb
  2. Hash source:    sudo rpi3-evidguard --hash-pre /dev/sdb --save pre.json
  3. Run rclone:     rclone copy /dev/sdb remote:bucket/imagen.raw
  4. Hash image:     sudo rpi3-evidguard --hash-post /path/to/imagen.raw --save post.json
  5. Verify:         sudo rpi3-evidguard --verify pre.json post.json

Or do it all at once:
  sudo rpi3-evidguard --full /dev/sdb /mnt/evidencia/imagen.raw --case CASE-001
        """
    )

    parser.add_argument("--block", metavar="DEV", help="Enable write blocking on device")
    parser.add_argument("--unblock", metavar="DEV", help="Disable write blocking (CAUTION)")
    parser.add_argument("--status", metavar="DEV", help="Check write blocking status")

    parser.add_argument("--hash-pre", metavar="DEV", help="Calculate hash of source device")
    parser.add_argument("--hash-post", metavar="FILE", help="Calculate hash of image/file")
    parser.add_argument("--algorithm", "-a", default="sha256", 
                       choices=["md5","sha1","sha256","sha512","blake2b"],
                       help="Hash algorithm (default: sha256)")
    parser.add_argument("--save", metavar="FILE", help="Save hash result to JSON file")

    parser.add_argument("--verify", nargs=2, metavar=("PRE","POST"),
                       help="Verify integrity: pre-hash.json post-hash.json")

    parser.add_argument("--full", nargs=2, metavar=("DEV","IMAGE"),
                       help="Full workflow: block + hash-pre + hash-post + verify")
    parser.add_argument("--case", default="UNNAMED", help="Case ID for logging")
    parser.add_argument("--log", default="forensic-evidguard.log", help="Log file path")

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    logger = ForensicLogger(args.log)

    # === BLOCK ===
    if args.block:
        print(f"[*] Enabling write block on {args.block}...")
        logger.header(args.case)
        blocker = WriteBlocker(args.block)
        results = blocker.enable()
        all_ok = True
        for target, ok, msg in results:
            status = "[OK]" if ok else "[ERROR]"
            print(f"  {status} {target}: {msg}")
            logger.log("BLOCK", f"{target}: {msg}", {"success": ok})
            if not ok:
                all_ok = False
        if not all_ok:
            print("[!] Some devices could not be blocked. Abort.")
            sys.exit(1)
        status = blocker.status()
        print("\n[STATUS]")
        for dev, st in status.items():
            print(f"  {dev}: {st}")
        logger.log("BLOCK_STATUS", "Write blocking confirmed", status)
        print("\n[✓] Device is now write-protected. Safe to run rclone.")
        return

    # === UNBLOCK ===
    if args.unblock:
        print(f"[!] WARNING: Disabling write protection on {args.unblock}")
        confirm = input("Type YES to confirm: ")
        if confirm != "YES":
            print("Cancelled.")
            return
        blocker = WriteBlocker(args.unblock)
        results = blocker.disable()
        for target, ok, msg in results:
            status = "[OK]" if ok else "[ERROR]"
            print(f"  {status} {target}: {msg}")
        return

    # === STATUS ===
    if args.status:
        blocker = WriteBlocker(args.status)
        status = blocker.status()
        print(f"Status for {args.status}:")
        for dev, st in status.items():
            print(f"  {dev}: {st}")
        return

    # === HASH PRE ===
    if args.hash_pre:
        print(f"[*] Calculating {args.algorithm} hash of {args.hash_pre}...")
        logger.header(args.case)
        hasher = HashChecker(args.algorithm)
        result = hasher.hash_path(args.hash_pre)
        print(f"\n[RESULT]")
        print(f"  Algorithm: {result['algorithm']}")
        print(f"  Hash:      {result['hash']}")
        print(f"  Bytes:     {result['bytes']}")
        print(f"  Source:    {result['path']}")
        logger.log("HASH_PRE", f"Source hash calculated", result)
        if args.save:
            with open(args.save, "w") as f:
                json.dump(result, f, indent=2)
            print(f"\n[✓] Saved to {args.save}")
        return

    # === HASH POST ===
    if args.hash_post:
        if not os.path.exists(args.hash_post):
            print(f"[ERROR] File not found: {args.hash_post}")
            sys.exit(1)
        print(f"[*] Calculating {args.algorithm} hash of {args.hash_post}...")
        hasher = HashChecker(args.algorithm)
        result = hasher.hash_path(args.hash_post)
        print(f"\n[RESULT]")
        print(f"  Algorithm: {result['algorithm']}")
        print(f"  Hash:      {result['hash']}")
        print(f"  Bytes:     {result['bytes']}")
        print(f"  File:      {result['path']}")
        logger.log("HASH_POST", f"Image hash calculated", result)
        if args.save:
            with open(args.save, "w") as f:
                json.dump(result, f, indent=2)
            print(f"\n[✓] Saved to {args.save}")
        return

    # === VERIFY ===
    if args.verify:
        pre_file, post_file = args.verify
        with open(pre_file) as f:
            pre = json.load(f)
        with open(post_file) as f:
            post = json.load(f)
        print(f"[*] Verifying integrity...")
        print(f"  Pre:  {pre['hash']} ({pre['algorithm']})")
        print(f"  Post: {post['hash']} ({post['algorithm']})")
        if pre["algorithm"] != post["algorithm"]:
            print(f"[!] WARNING: Different algorithms used!")
        checker = HashChecker(pre["algorithm"])
        match = checker.verify(pre, post)
        if match:
            print(f"\n[✓] INTEGRITY VERIFIED - Hashes match perfectly")
            logger.log("VERIFY", "Integrity confirmed", {"match": True})
        else:
            print(f"\n[✗] INTEGRITY FAILURE - Hashes DO NOT match")
            logger.log("VERIFY", "Integrity failure", {"match": False})
            sys.exit(2)
        return

    # === FULL ===
    if args.full:
        device, image_path = args.full
        print(f"[*] FORENSIC EVIDGUARD FULL WORKFLOW")
        print(f"    Case: {args.case}")
        print(f"    Source: {device}")
        print(f"    Image:  {image_path}")
        print(f"    Hash:   {args.hash}")
        print()
        logger.header(args.case)

        # 1. Block
        print("[1/4] Enabling write block...")
        blocker = WriteBlocker(device)
        for target, ok, msg in blocker.enable():
            if not ok:
                print(f"[ERROR] {target}: {msg}")
                sys.exit(1)
        print("[✓] Blocked\n")
        logger.log("BLOCK", "Write blocking enabled")

        # 2. Hash source
        print(f"[2/4] Hashing source ({args.hash})...")
        hasher = HashChecker(args.hash)
        pre = hasher.hash_path(device)
        print(f"[✓] {pre['hash']}\n")
        logger.log("HASH_PRE", "Done", pre)

        # 3. Wait for rclone / inform user
        print("[3/4] READY FOR RCLONE")
        print(f"""
    The source device is blocked and hashed.
    Now run your rclone command, for example:

    rclone copy {device} remote:bucket/evidence/{args.case}.raw

    Or if rclone expects a file:

    sudo dd if={device} of=/tmp/{args.case}.raw bs=4M status=progress
    rclone copy /tmp/{args.case}.raw remote:bucket/

    Once the image is created, re-run this tool with --hash-post
    or press Enter to hash the image now (if already present).
        """)
        if not os.path.exists(image_path):
            input("Press Enter when the image is ready...")
        if not os.path.exists(image_path):
            print(f"[ERROR] Image not found: {image_path}")
            sys.exit(1)

        # 4. Hash image and verify
        print(f"[4/4] Hashing image and verifying...")
        post = hasher.hash_path(image_path)
        print(f"  Source: {pre['hash']}")
        print(f"  Image:  {post['hash']}")
        if hasher.verify(pre, post):
            print(f"\n[✓✓✓] FORENSIC INTEGRITY CONFIRMED")
            logger.log("VERIFY", "PASS", {"match": True})
        else:
            print(f"\n[✗✗✗] FORENSIC INTEGRITY FAILURE")
            logger.log("VERIFY", "FAIL", {"match": False})
            sys.exit(2)

        logger.footer()
        print(f"\nLog saved: {args.log}")
        return

if __name__ == "__main__":
    main()
