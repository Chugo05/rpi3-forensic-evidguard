# RPI3 Forensic EvidGuard

**Write Blocker + Hash Checker** diseñado específicamente para **Raspberry Pi 3 Modelo B** como capa de seguridad forense complementaria a `rclone` u otras herramientas de adquisición.

## ¿Por qué existe?

Las herramientas como `rclone` son excelentes para generar imágenes o copiar evidencia, pero **no garantizan** que el sistema operativo no escriba accidentalmente en el disco fuente durante el proceso. Este proyecto añade:

1. **Bloqueo de escritura a nivel kernel** (compatible con el parche de [msuhanov/Linux-write-blocker](https://github.com/msuhanov/Linux-write-blocker))
2. **Hash checker** con verificación de integridad
3. **Logger forense** con timestamps y trazabilidad

## Características

- ✋ **Bloqueo real**: Usa `blockdev --setro` + detección automática del dispositivo padre
- 🔐 **Múltiples algoritmos**: MD5, SHA1, SHA256, SHA512, BLAKE2b
- 📊 **Progreso en tiempo real**: Muestra bytes leídos incluso en dispositivos de bloques
- 📝 **Log forense**: JSON Lines con timestamps ISO8601
- 🔗 **Integración con rclone**: Diseñado para no pisar tu flujo actual
- ⚡ **Modo full**: Bloqueo + hash origen + hash imagen + verificación en un solo comando

## Instalación

```bash
git clone https://github.com/tu-usuario/rpi3-forensic-evidguard.git
cd rpi3-forensic-evidguard
sudo ./install.sh
```

## Uso con rclone (flujo recomendado)

```bash
# 1. Bloquear el dispositivo fuente
sudo rpi3-guard --block /dev/sdb

# 2. Calcular hash del origen
sudo rpi3-guard --hash-pre /dev/sdb --save pre.json

# 3. Ejecutar rclone (o tu herramienta de adquisición)
rclone copy /dev/sdb remote:bucket/evidencia/caso001.raw

# 4. Calcular hash de la imagen generada
sudo rpi3-guard --hash-post /mnt/evidencia/caso001.raw --save post.json

# 5. Verificar integridad
sudo rpi3-guard --verify pre.json post.json
```

## Modo Full (todo en uno)

```bash
sudo rpi3-guard --full /dev/sdb /mnt/evidencia/caso001.raw --case CASE-2026-001
```

Esto:
1. Bloquea `/dev/sdb`
2. Calcula SHA256 del origen
3. Espera a que generes la imagen (o la hashea si ya existe)
4. Compara hashes y genera log

## Comandos disponibles

| Comando | Descripción |
|---------|-------------|
| `--block DEV` | Activa bloqueo de escritura |
| `--unblock DEV` | Desactiva bloqueo (¡cuidado!) |
| `--status DEV` | Verifica estado del bloqueo |
| `--hash-pre DEV` | Hash del dispositivo origen |
| `--hash-post FILE` | Hash de la imagen/archivo |
| `--verify PRE POST` | Compara dos hashes JSON |
| `--full DEV IMAGE` | Flujo completo forense |
| `--algorithm ALG` | md5, sha1, sha256, sha512, blake2b |
| `--case ID` | Identificador del caso para logs |

## Requisitos

- Raspberry Pi 3B (o compatible)
- Raspberry Pi OS / Debian-based
- Python 3.7+
- `blockdev`, `lsblk`
- Parche de kernel de msuhanov **recomendado** (aunque funciona con `blockdev` nativo)

## Arquitectura

```
rpi3-forensic-guard/
├── src/
│   ├── cli.py         # Interfaz de línea de comandos
│   ├── blocker.py     # Gestión de bloqueo de escritura
│   ├── hasher.py      # Cálculo de hashes streaming
│   └── logger.py      # Logger forense JSON
├── udev/
│   └── 01-forensic-readonly.rules  # Bloqueo automático vía udev
└── install.sh         # Instalador
```

## Licencia

MIT License - Libre para uso forense y educativo.
