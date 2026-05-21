#!/bin/bash
# RPI3 Forensic EvidGuard - Installer
# For Raspberry Pi 3B and x86_64 VMs

set -e

echo "============================================"
echo "  RPI3 Forensic EvidGuard - Installer"
echo "============================================"

if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] Run as root: sudo ./install.sh"
    exit 1
fi

# Detect real user (not root) who invoked sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="/home/$SUDO_USER"
else
    REAL_USER="$(whoami)"
    REAL_HOME="$HOME"
fi

# Dependencies
echo "[*] Checking dependencies..."
apt-get update || true
apt-get install -y python3 util-linux || true

# udev rules
echo "[*] Installing udev rules..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/udev/01-forensic-readonly.rules" ]; then
    cp "$SCRIPT_DIR/udev/01-forensic-readonly.rules" /etc/udev/rules.d/
    chmod 644 /etc/udev/rules.d/01-forensic-readonly.rules
    udevadm control --reload-rules
    echo "  [OK] udev rules installed"
else
    echo "  [WARN] udev rules not found in $SCRIPT_DIR/udev/"
fi

# Install Python package
echo "[*] Installing EvidGuard..."
INSTALL_DIR="/opt/rpi3-forensic-evidguard"
mkdir -p "$INSTALL_DIR"

if [ -d "$SCRIPT_DIR/src" ]; then
    cp -r "$SCRIPT_DIR/src" "$INSTALL_DIR/"
    echo "  [OK] Code copied from $SCRIPT_DIR/src"
else
    echo "  [ERROR] Source not found at $SCRIPT_DIR/src"
    exit 1
fi

# Create global command: rpi3-evidguard
cat > /usr/local/bin/rpi3-evidguard << 'EOF'
#!/bin/bash
cd /opt/rpi3-forensic-evidguard
exec python3 -m src.cli "$@"
EOF
chmod +x /usr/local/bin/rpi3-evidguard

# Create alias: rpi3-evidguard-mod (backup wrapper)
cat > /usr/local/bin/rpi3-evidguard-mod << 'EOF'
#!/bin/bash
cd /opt/rpi3-forensic-evidguard
exec sudo python3 -m src.cli "$@"
EOF
chmod +x /usr/local/bin/rpi3-evidguard-mod

echo ""
echo "[✓] Installation complete!"
echo ""
echo "Commands:"
echo "  rpi3-evidguard --help          (standard)"
echo "  rpi3-evidguard-mod --help      (backup if standard fails)"
echo ""
echo "Examples:"
echo "  sudo rpi3-evidguard --block /dev/sdX"
echo "  sudo rpi3-evidguard --hash-pre /dev/sdX --save pre.json"
echo "  sudo rpi3-evidguard --hash-post /mnt/imagen.raw --save post.json"
echo "  sudo rpi3-evidguard --verify pre.json post.json"
echo "  sudo rpi3-evidguard --full /dev/sdX /mnt/imagen.raw --case CASE-001"
echo ""
echo "Note: If 'rpi3-evidguard' fails with import errors, use 'rpi3-evidguard-mod'."
