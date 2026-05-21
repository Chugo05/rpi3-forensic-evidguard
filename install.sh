#!/bin/bash
# RPI3 Forensic EvidGuard - Instalador
# Para Raspberry Pi 3B y maquinas virtuales x86_64

set -e

echo "============================================"
echo "  RPI3 Forensic EvidGuard - Instalador"
echo "============================================"

if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] Ejecutar como root: sudo ./install.sh"
    exit 1
fi

# Detectar usuario real (no root) que invoco sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="/home/$SUDO_USER"
else
    REAL_USER="$(whoami)"
    REAL_HOME="$HOME"
fi

# Dependencias
echo "[*] Verificando dependencias..."
apt-get update || true
apt-get install -y python3 util-linux || true

# Reglas udev
echo "[*] Instalando reglas udev..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/udev/01-forensic-readonly.rules" ]; then
    cp "$SCRIPT_DIR/udev/01-forensic-readonly.rules" /etc/udev/rules.d/
    chmod 644 /etc/udev/rules.d/01-forensic-readonly.rules
    udevadm control --reload-rules
    echo "  [OK] Reglas udev instaladas"
else
    echo "  [AVISO] Reglas udev no encontradas en $SCRIPT_DIR/udev/"
fi

# Instalar paquete Python
echo "[*] Instalando EvidGuard..."
INSTALL_DIR="/opt/rpi3-forensic-evidguard"
mkdir -p "$INSTALL_DIR"

if [ -d "$SCRIPT_DIR/src" ]; then
    cp -r "$SCRIPT_DIR/src" "$INSTALL_DIR/"
    echo "  [OK] Codigo copiado desde $SCRIPT_DIR/src"
else
    echo "  [ERROR] Codigo fuente no encontrado en $SCRIPT_DIR/src"
    exit 1
fi

# Crear comando global: rpi3-evidguard
cat > /usr/local/bin/rpi3-evidguard << 'EOF'
#!/bin/bash
cd /opt/rpi3-forensic-evidguard
exec python3 -m src.cli "$@"
EOF
chmod +x /usr/local/bin/rpi3-evidguard

# Crear respaldo: rpi3-evidguard-mod
cat > /usr/local/bin/rpi3-evidguard-mod << 'EOF'
#!/bin/bash
cd /opt/rpi3-forensic-evidguard
exec sudo python3 -m src.cli "$@"
EOF
chmod +x /usr/local/bin/rpi3-evidguard-mod

echo ""
echo "[✓] Instalacion completada!"
echo ""
echo "Comandos disponibles:"
echo "  rpi3-evidguard --help          (estandar)"
echo "  rpi3-evidguard-mod --help      (respaldo si el estandar falla)"
echo ""
echo "Ejemplos:"
echo "  sudo rpi3-evidguard --block /dev/sdX"
echo "  sudo rpi3-evidguard --hash-pre /dev/sdX --save pre.json"
echo "  sudo rpi3-evidguard --hash-post /mnt/imagen.raw --save post.json"
echo "  sudo rpi3-evidguard --verify pre.json post.json"
echo "  sudo rpi3-evidguard --full /dev/sdX /mnt/imagen.raw --case CASO-001"
echo ""
echo "Nota: Si 'rpi3-evidguard' da error de importacion, usa 'rpi3-evidguard-mod'."
