#!/bin/bash
# RPI3 Forensic Guard - Installer
# Compatible with Raspberry Pi 3B running Raspberry Pi OS

set -e

echo "============================================"
echo "  RPI3 Forensic Guard - Installer"
echo "============================================"

if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] Please run as root (sudo)"
    exit 1
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null &&    ! grep -q "BCM27" /proc/cpuinfo 2>/dev/null; then
    echo "[WARNING] Raspberry Pi not detected. Continuing anyway..."
fi

# Install dependencies
echo "[*] Installing dependencies..."
apt-get update
apt-get install -y python3 python3-pip blockdev lsblk

# Install udev rules
echo "[*] Installing udev rules..."
cp udev/01-forensic-readonly.rules /etc/udev/rules.d/
chmod 644 /etc/udev/rules.d/01-forensic-readonly.rules
udevadm control --reload-rules

# Install Python package
echo "[*] Installing forensic-guard..."
INSTALL_DIR="/opt/rpi3-forensic-guard"
mkdir -p "$INSTALL_DIR"
cp -r src/ "$INSTALL_DIR/"

# Create wrapper script
cat > /usr/local/bin/rpi3-guard << 'EOF'
#!/bin/bash
exec python3 /opt/rpi3-forensic-guard/src/cli.py "$@"
EOF
chmod +x /usr/local/bin/rpi3-guard

# Verify
echo ""
echo "[✓] Installation complete!"
echo ""
echo "Usage:"
echo "  sudo rpi3-guard --block /dev/sdX"
echo "  sudo rpi3-guard --hash-pre /dev/sdX --save pre.json"
echo "  sudo rpi3-guard --hash-post /path/to/image.raw --save post.json"
echo "  sudo rpi3-guard --verify pre.json post.json"
echo "  sudo rpi3-guard --full /dev/sdX /path/to/image.raw --case CASE-001"
echo ""
echo "For rclone integration:"
echo "  1. Block:  sudo rpi3-guard --block /dev/sdb"
echo "  2. Hash:   sudo rpi3-guard --hash-pre /dev/sdb --save pre.json"
echo "  3. Rclone: rclone copy /dev/sdb remote:bucket/image.raw"
echo "  4. Hash:   sudo rpi3-guard --hash-post image.raw --save post.json"
echo "  5. Verify: sudo rpi3-guard --verify pre.json post.json"
