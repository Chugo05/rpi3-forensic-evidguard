#!/bin/bash
# ============================================================
# RPI3 Forensic EvidGuard - Automated Test Suite
# Auto-detects installation path
# ============================================================

set -e

DISCO="/dev/sdb"
IMAGEN="/tmp/imagen-prueba.raw"
PRE_HASH="/tmp/pre-hash.json"
POST_HASH="/tmp/post-hash.json"
POST_ATAQUE="/tmp/post-ataque.json"
REPORTE="/tmp/forensic-test-report.txt"

# ============================================================
# DETECT EVIDGUARD COMMAND
# ============================================================

if command -v rpi3-evidguard &> /dev/null; then
    GUARD_CMD="rpi3-evidguard"
    echo "[*] Using global command: rpi3-evidguard"
elif command -v rpi3-evidguard-mod &> /dev/null; then
    GUARD_CMD="rpi3-evidguard-mod"
    echo "[*] Using backup command: rpi3-evidguard-mod"
else
    echo "[*] Searching project in common directories..."
    FOUND=""
    for DIR in "$HOME/rpi3-forensic-evidguard"                "/home/$(logname 2>/dev/null || echo "$USER")/rpi3-forensic-evidguard"                "/opt/rpi3-forensic-evidguard"; do
        if [ -f "$DIR/src/cli.py" ]; then
            FOUND="$DIR"
            break
        fi
    done

    if [ -z "$FOUND" ]; then
        echo "[ERROR] Project rpi3-forensic-evidguard not found."
        echo "  Searched:"
        echo "    - ~/rpi3-forensic-evidguard/src/cli.py"
        echo "    - /opt/rpi3-forensic-evidguard/src/cli.py"
        echo ""
        echo "Fix: Run first: sudo ./install.sh"
        exit 1
    fi

    GUARD_CMD="cd $FOUND && sudo python3 -m src.cli"
    echo "[*] Using project at: $FOUND"
fi

GUARD() {
    $GUARD_CMD "$@"
}

# ============================================================
# START
# ============================================================

echo "=============================================="
echo "  RPI3 FORENSIC EVIDGUARD - TEST SUITE"
echo "  Test disk: $DISCO"
echo "  Date: $(date)"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Run as root: sudo bash test-forensic.sh"
    exit 1
fi

if [ ! -e "$DISCO" ]; then
    echo "[ERROR] Disk $DISCO not found. Check with: lsblk"
    echo "  Add a second virtual disk in VirtualBox:"
    echo "    Settings > Storage > Add Hard Disk > 1GB"
    exit 1
fi

rm -f "$IMAGEN" "$PRE_HASH" "$POST_HASH" "$POST_ATAQUE" "$REPORTE"

# ============================================================
# TEST 1: WRITE BLOCKING
# ============================================================
echo "[TEST 1/7] Enabling write block on $DISCO..."
GUARD --block "$DISCO" > /tmp/test1.log 2>&1
if [ "$(blockdev --getro "$DISCO")" == "1" ]; then
    echo "  [✓ PASS] Write block active"
    echo "TEST 1: PASS - Block active" >> "$REPORTE"
else
    echo "  [✗ FAIL] Disk still read-write"
    echo "TEST 1: FAIL - Block not active" >> "$REPORTE"
    cat /tmp/test1.log
    exit 1
fi

# ============================================================
# TEST 2: PRE-ACQUISITION HASH
# ============================================================
echo ""
echo "[TEST 2/7] Calculating SHA256 hash of source..."
GUARD --hash-pre "$DISCO" --save "$PRE_HASH" > /tmp/test2.log 2>&1
echo "  [✓ PASS] Hash calculated"
echo "  Hash: $(python3 -c "import json; print(json.load(open('$PRE_HASH'))['hash'])")"
echo "TEST 2: PASS - Pre-hash calculated" >> "$REPORTE"

# ============================================================
# TEST 3: WRITE ATTEMPT (must fail)
# ============================================================
echo ""
echo "[TEST 3/7] Attempting to write to blocked disk..."
if sudo dd if=/dev/zero of="$DISCO" bs=512 count=1 2>/dev/null; then
    echo "  [✗ FAIL] Write succeeded! Block is not working."
    echo "TEST 3: FAIL - Write not blocked" >> "$REPORTE"
    exit 1
else
    echo "  [✓ PASS] Write blocked (Operation not permitted)"
    echo "TEST 3: PASS - Write blocked" >> "$REPORTE"
fi

# ============================================================
# TEST 4: POST-ATTACK INTEGRITY
# ============================================================
echo ""
echo "[TEST 4/7] Verifying disk was not altered after write attempt..."
GUARD --hash-pre "$DISCO" --save "$POST_ATAQUE" > /tmp/test4.log 2>&1
if GUARD --verify "$PRE_HASH" "$POST_ATAQUE" > /tmp/test4-verify.log 2>&1; then
    echo "  [✓ PASS] Integrity maintained - hashes match"
    echo "TEST 4: PASS - Post-attack integrity confirmed" >> "$REPORTE"
else
    echo "  [✗ FAIL] Disk was altered! Hashes do not match."
    echo "TEST 4: FAIL - Integrity compromised" >> "$REPORTE"
    exit 1
fi

# ============================================================
# TEST 5: SIMULATED ACQUISITION (dd)
# ============================================================
echo ""
echo "[TEST 5/7] Simulating acquisition with dd (as rclone would)..."
sudo dd if="$DISCO" of="$IMAGEN" bs=4M status=progress
if [ -f "$IMAGEN" ]; then
    SIZE=$(du -h "$IMAGEN" | cut -f1)
    echo "  [✓ PASS] Image created: $IMAGEN ($SIZE)"
    echo "TEST 5: PASS - Image acquired ($SIZE)" >> "$REPORTE"
else
    echo "  [✗ FAIL] Image not created"
    echo "TEST 5: FAIL - Acquisition failed" >> "$REPORTE"
    exit 1
fi

# ============================================================
# TEST 6: POST-ACQUISITION HASH
# ============================================================
echo ""
echo "[TEST 6/7] Calculating hash of acquired image..."
GUARD --hash-post "$IMAGEN" --save "$POST_HASH" > /tmp/test6.log 2>&1
echo "  [✓ PASS] Hash calculated"
echo "  Hash: $(python3 -c "import json; print(json.load(open('$POST_HASH'))['hash'])")"
echo "TEST 6: PASS - Post-hash calculated" >> "$REPORTE"

# ============================================================
# TEST 7: SOURCE vs IMAGE VERIFICATION
# ============================================================
echo ""
echo "[TEST 7/7] Verifying integrity between source and image..."
if GUARD --verify "$PRE_HASH" "$POST_HASH" > /tmp/test7.log 2>&1; then
    echo "  [✓ PASS] INTEGRITY VERIFIED - Source and image are identical"
    echo "TEST 7: PASS - Source/image integrity confirmed" >> "$REPORTE"
else
    echo "  [✗ FAIL] Hashes DO NOT match"
    echo "TEST 7: FAIL - Corruption detected" >> "$REPORTE"
    exit 1
fi

# ============================================================
# FINAL REPORT
# ============================================================
echo ""
echo "=============================================="
echo "  FINAL RESULTS"
echo "=============================================="
cat "$REPORTE"
echo ""
echo "Generated files:"
echo "  Pre-hash:   $PRE_HASH"
echo "  Post-hash:  $POST_HASH"
echo "  Image:      $IMAGEN"
echo "  Report:     $REPORTE"
echo ""
echo "[✓✓✓] ALL TESTS PASSED"
echo "EvidGuard is working correctly."
