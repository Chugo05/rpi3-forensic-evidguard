#!/bin/bash
# RPI3 Forensic Guard - Installer (CORREGIDO)
# Compatible con Raspberry Pi 3B y VMs x86_64

set -e

echo "============================================"
echo "  RPI3 Forensic Guard - Installer"
echo "============================================"

if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] Ejecutar como root: sudo ./install.sh"
    exit 1
fi

# Detectar usuario real (no root) que invocó sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="/home/$SUDO_USER"
else
    REAL_USER="$(whoami)"
    REAL_HOME="$HOME"
fi

# 1. Dependencias
# NOTA: blockdev y lsblk vienen en util-linux (preinstalado en Debian/Ubuntu/Raspberry Pi OS)
# Solo instalamos python3 si falta
echo "[*] Verificando dependencias..."
apt-get update || true
apt-get install -y python3 util-linux || true

# 2. Instalar reglas udev
echo "[*] Instalando reglas udev..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/udev/01-forensic-readonly.rules" ]; then
    cp "$SCRIPT_DIR/udev/01-forensic-readonly.rules" /etc/udev/rules.d/
    chmod 644 /etc/udev/rules.d/01-forensic-readonly.rules
    udevadm control --reload-rules
    echo "  [OK] Reglas udev instaladas"
else
    echo "  [WARN] No se encontraron reglas udev en $SCRIPT_DIR/udev/"
fi

# 3. Instalar paquete Python
echo "[*] Instalando herramienta..."
INSTALL_DIR="/opt/rpi3-forensic-guard"
mkdir -p "$INSTALL_DIR"

# Copiar desde el directorio del script
if [ -d "$SCRIPT_DIR/src" ]; then
    cp -r "$SCRIPT_DIR/src" "$INSTALL_DIR/"
    echo "  [OK] Codigo copiado desde $SCRIPT_DIR/src"
else
    echo "  [ERROR] No se encuentra $SCRIPT_DIR/src"
    exit 1
fi

# 4. Crear wrapper global
cat > /usr/local/bin/rpi3-guard << EOF
#!/bin/bash
# Wrapper para ejecutar forensic-guard desde cualquier ubicacion
exec python3 /opt/rpi3-forensic-guard/src/cli.py "\$@"
EOF
chmod +x /usr/local/bin/rpi3-guard

# 5. Crear wrapper adicional para ejecucion como modulo desde /opt
# (resuelve el problema de imports relativos)
cat > /usr/local/bin/rpi3-guard-mod << 'EOF'
#!/bin/bash
cd /opt/rpi3-forensic-guard
exec sudo python3 -m src.cli "$@"
EOF
chmod +x /usr/local/bin/rpi3-guard-mod

echo ""
echo "[✓] Instalacion completa!"
echo ""
echo "Comandos disponibles:"
echo "  rpi3-guard --help          (ejecucion directa)"
echo "  rpi3-guard-mod --help      (ejecucion como modulo, si falla el anterior)"
echo ""
echo "Ejemplos:"
echo "  sudo rpi3-guard --block /dev/sdX"
echo "  sudo rpi3-guard --hash-pre /dev/sdX --save pre.json"
echo "  sudo rpi3-guard --hash-post /mnt/imagen.raw --save post.json"
echo "  sudo rpi3-guard --verify pre.json post.json"
echo "  sudo rpi3-guard --full /dev/sdX /mnt/imagen.raw --case CASE-001"
echo ""
echo "Nota: Si 'rpi3-guard' da error de importacion, usa 'rpi3-guard-mod'."
