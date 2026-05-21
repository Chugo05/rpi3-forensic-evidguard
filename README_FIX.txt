# RPI3 Forensic Guard - Instalacion Limpia (Fix)

## Problemas resueltos en esta version

1. **install.sh no falla** al buscar paquetes `blockdev`/`lsblk` (vienen en `util-linux`)
2. **Auto-deteccion del proyecto** en test-forensic.sh (no hardcodea /root)
3. **Dos wrappers** instalados: `rpi3-guard` y `rpi3-guard-mod` (respaldo)
4. **Reglas udev** se instalan correctamente desde cualquier ruta

## Reinstalacion limpia

```bash
# 1. Ir al directorio del proyecto descargado
cd ~/rpi3-forensic-evidguard   # o donde lo tengas

# 2. Reemplazar install.sh y test-forensic.sh con los archivos de esta carpeta

# 3. Ejecutar instalador corregido
sudo ./install.sh

# 4. Verificar que funciona
cd ~
rpi3-guard --help

# Si falla, prueba:
rpi3-guard-mod --help
```

## Script de pruebas

```bash
# Desde cualquier carpeta:
sudo bash test-forensic.sh
```

El script auto-detectara si usaste `rpi3-guard`, `rpi3-guard-mod`, o el proyecto sin instalar.
