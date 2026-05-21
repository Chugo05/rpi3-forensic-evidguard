#!/bin/bash
# ============================================================
# RPI3 Forensic EvidGuard - Script de Pruebas Automatizado
# Auto-detecta la ruta de instalacion
# ============================================================

set -e

DISCO="/dev/sdb"
IMAGEN="/tmp/imagen-prueba.raw"
PRE_HASH="/tmp/pre-hash.json"
POST_HASH="/tmp/post-hash.json"
POST_ATAQUE="/tmp/post-ataque.json"
REPORTE="/tmp/forensic-test-report.txt"

# ============================================================
# DETECTAR COMANDO EVIDGUARD
# ============================================================

if command -v rpi3-evidguard &> /dev/null; then
    GUARD_CMD="rpi3-evidguard"
    echo "[*] Usando comando global: rpi3-evidguard"
elif command -v rpi3-evidguard-mod &> /dev/null; then
    GUARD_CMD="rpi3-evidguard-mod"
    echo "[*] Usando comando alternativo: rpi3-evidguard-mod"
else
    echo "[*] Buscando proyecto en directorios comunes..."
    FOUND=""
    for DIR in "$HOME/rpi3-forensic-evidguard"                "/home/$(logname 2>/dev/null || echo "$USER")/rpi3-forensic-evidguard"                "/opt/rpi3-forensic-evidguard"; do
        if [ -f "$DIR/src/cli.py" ]; then
            FOUND="$DIR"
            break
        fi
    done

    if [ -z "$FOUND" ]; then
        echo "[ERROR] No se encontro el proyecto rpi3-forensic-evidguard."
        echo "  Buscado en:"
        echo "    - ~/rpi3-forensic-evidguard/src/cli.py"
        echo "    - /opt/rpi3-forensic-evidguard/src/cli.py"
        echo ""
        echo "Solucion: Ejecuta primero: sudo ./install.sh"
        exit 1
    fi

    GUARD_CMD="cd $FOUND && sudo python3 -m src.cli"
    echo "[*] Usando proyecto encontrado en: $FOUND"
fi

GUARD() {
    $GUARD_CMD "$@"
}

# ============================================================
# INICIO
# ============================================================

echo "=============================================="
echo "  RPI3 FORENSIC EVIDGUARD - TEST SUITE"
echo "  Disco de prueba: $DISCO"
echo "  Fecha: $(date)"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Ejecutar como root: sudo bash test-forensic.sh"
    exit 1
fi

if [ ! -e "$DISCO" ]; then
    echo "[ERROR] Disco $DISCO no encontrado. Verifica con: lsblk"
    echo "  Debes añadir un segundo disco virtual en VirtualBox:"
    echo "    Configuracion > Almacenamiento > Añadir disco duro > 1GB"
    exit 1
fi

rm -f "$IMAGEN" "$PRE_HASH" "$POST_HASH" "$POST_ATAQUE" "$REPORTE"

# ============================================================
# TEST 1: BLOQUEO DE ESCRITURA
# ============================================================
echo "[TEST 1/7] Activando bloqueo de escritura en $DISCO..."
GUARD --block "$DISCO" > /tmp/test1.log 2>&1
if [ "$(blockdev --getro "$DISCO")" == "1" ]; then
    echo "  [✓ PASS] Bloqueo activado correctamente"
    echo "TEST 1: PASS - Bloqueo activo" >> "$REPORTE"
else
    echo "  [✗ FAIL] El disco sigue en modo lectura/escritura"
    echo "TEST 1: FAIL - Bloqueo no activo" >> "$REPORTE"
    cat /tmp/test1.log
    exit 1
fi

# ============================================================
# TEST 2: HASH PRE-ADQUISICION
# ============================================================
echo ""
echo "[TEST 2/7] Calculando hash SHA256 del origen..."
GUARD --hash-pre "$DISCO" --save "$PRE_HASH" > /tmp/test2.log 2>&1
echo "  [✓ PASS] Hash calculado"
echo "  Hash: $(python3 -c "import json; print(json.load(open('$PRE_HASH'))['hash'])")"
echo "TEST 2: PASS - Hash pre calculado" >> "$REPORTE"

# ============================================================
# TEST 3: INTENTO DE ESCRITURA (debe fallar)
# ============================================================
echo ""
echo "[TEST 3/7] Intentando escribir en disco bloqueado..."
if sudo dd if=/dev/zero of="$DISCO" bs=512 count=1 2>/dev/null; then
    echo "  [✗ FAIL] ¡Se escribio en el disco! El bloqueo no funciona."
    echo "TEST 3: FAIL - Escritura no bloqueada" >> "$REPORTE"
    exit 1
else
    echo "  [✓ PASS] Escritura bloqueada correctamente (Operation not permitted)"
    echo "TEST 3: PASS - Escritura bloqueada" >> "$REPORTE"
fi

# ============================================================
# TEST 4: INTEGRIDAD POST-ATAQUE
# ============================================================
echo ""
echo "[TEST 4/7] Verificando que el disco no se altero tras intento de escritura..."
GUARD --hash-pre "$DISCO" --save "$POST_ATAQUE" > /tmp/test4.log 2>&1
if GUARD --verify "$PRE_HASH" "$POST_ATAQUE" > /tmp/test4-verify.log 2>&1; then
    echo "  [✓ PASS] Integridad mantenida - hashes coinciden"
    echo "TEST 4: PASS - Integridad post-ataque confirmada" >> "$REPORTE"
else
    echo "  [✗ FAIL] ¡El disco se altero! Los hashes no coinciden."
    echo "TEST 4: FAIL - Integridad comprometida" >> "$REPORTE"
    exit 1
fi

# ============================================================
# TEST 5: ADQUISICION SIMULADA (dd)
# ============================================================
echo ""
echo "[TEST 5/7] Simulando adquisicion con dd (como haria rclone)..."
sudo dd if="$DISCO" of="$IMAGEN" bs=4M status=progress
if [ -f "$IMAGEN" ]; then
    SIZE=$(du -h "$IMAGEN" | cut -f1)
    echo "  [✓ PASS] Imagen creada: $IMAGEN ($SIZE)"
    echo "TEST 5: PASS - Imagen adquirida ($SIZE)" >> "$REPORTE"
else
    echo "  [✗ FAIL] No se creo la imagen"
    echo "TEST 5: FAIL - Adquisicion fallida" >> "$REPORTE"
    exit 1
fi

# ============================================================
# TEST 6: HASH POST-ADQUISICION
# ============================================================
echo ""
echo "[TEST 6/7] Calculando hash de la imagen adquirida..."
GUARD --hash-post "$IMAGEN" --save "$POST_HASH" > /tmp/test6.log 2>&1
echo "  [✓ PASS] Hash calculado"
echo "  Hash: $(python3 -c "import json; print(json.load(open('$POST_HASH'))['hash'])")"
echo "TEST 6: PASS - Hash post calculado" >> "$REPORTE"

# ============================================================
# TEST 7: VERIFICACION INTEGRIDAD ORIGEN vs IMAGEN
# ============================================================
echo ""
echo "[TEST 7/7] Verificando integridad entre origen e imagen..."
if GUARD --verify "$PRE_HASH" "$POST_HASH" > /tmp/test7.log 2>&1; then
    echo "  [✓ PASS] INTEGRIDAD VERIFICADA - Origen e imagen son identicos"
    echo "TEST 7: PASS - Integridad origen/imagen confirmada" >> "$REPORTE"
else
    echo "  [✗ FAIL] Los hashes NO coinciden"
    echo "TEST 7: FAIL - Corrupcion detectada" >> "$REPORTE"
    exit 1
fi

# ============================================================
# REPORTE FINAL
# ============================================================
echo ""
echo "=============================================="
echo "  RESULTADOS FINALES"
echo "=============================================="
cat "$REPORTE"
echo ""
echo "Archivos generados:"
echo "  Hash origen:  $PRE_HASH"
echo "  Hash imagen:  $POST_HASH"
echo "  Imagen:       $IMAGEN"
echo "  Reporte:      $REPORTE"
echo ""
echo "[✓✓✓] TODAS LAS PRUEBAS PASARON"
echo "EvidGuard funciona correctamente."
