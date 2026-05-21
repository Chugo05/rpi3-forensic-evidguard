#!/usr/bin/env python3
"""
RPI3 Forensic EvidGuard
=======================
Bloqueador de escritura + Verificador de hashes para Raspberry Pi 3 Modelo B
Diseñado como capa de seguridad forense complementaria a rclone u otras herramientas

Uso:
    sudo python3 -m src.cli --block /dev/sdb
    sudo python3 -m src.cli --hash-pre /dev/sdb --save pre.json
    sudo python3 -m src.cli --hash-post /mnt/evidencia/imagen.raw --save post.json
    sudo python3 -m src.cli --verify pre.json post.json
    sudo python3 -m src.cli --full /dev/sdb /mnt/evidencia/imagen.raw --case CASO-001
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
        description="RPI3 Forensic EvidGuard - Bloqueador de escritura + Verificador de hashes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Integracion con rclone:
  1. Bloquear:       sudo rpi3-evidguard --block /dev/sdb
  2. Hash origen:    sudo rpi3-evidguard --hash-pre /dev/sdb --save pre.json
  3. Ejecutar rclone: rclone copy /dev/sdb remote:bucket/imagen.raw
  4. Hash imagen:    sudo rpi3-evidguard --hash-post /ruta/imagen.raw --save post.json
  5. Verificar:      sudo rpi3-evidguard --verify pre.json post.json

O todo de golpe:
  sudo rpi3-evidguard --full /dev/sdb /mnt/evidencia/imagen.raw --case CASO-001
        """
    )

    parser.add_argument("--block", metavar="DEV", help="Activar bloqueo de escritura en dispositivo")
    parser.add_argument("--unblock", metavar="DEV", help="Desactivar bloqueo de escritura (PRECAUCION)")
    parser.add_argument("--status", metavar="DEV", help="Comprobar estado del bloqueo")

    parser.add_argument("--hash-pre", metavar="DEV", help="Calcular hash del dispositivo origen")
    parser.add_argument("--hash-post", metavar="ARCHIVO", help="Calcular hash de la imagen/archivo")
    parser.add_argument("--algorithm", "-a", default="sha256", 
                       choices=["md5","sha1","sha256","sha512","blake2b"],
                       help="Algoritmo de hash (default: sha256)")
    parser.add_argument("--save", metavar="ARCHIVO", help="Guardar resultado del hash en archivo JSON")

    parser.add_argument("--verify", nargs=2, metavar=("PRE","POST"),
                       help="Verificar integridad: pre-hash.json post-hash.json")

    parser.add_argument("--full", nargs=2, metavar=("DEV","IMAGEN"),
                       help="Flujo completo: bloquear + hash-pre + hash-post + verificar")
    parser.add_argument("--case", default="SIN_NOMBRE", help="ID del caso para los logs")
    parser.add_argument("--log", default="forensic-evidguard.log", help="Ruta del archivo de log")

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    logger = ForensicLogger(args.log)

    # === BLOCK ===
    if args.block:
        print(f"[*] Activando bloqueo de escritura en {args.block}...")
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
            print("[!] Algunos dispositivos no se pudieron bloquear. Abortando.")
            sys.exit(1)
        status = blocker.status()
        print("\n[ESTADO]")
        for dev, st in status.items():
            print(f"  {dev}: {st}")
        logger.log("BLOCK_STATUS", "Bloqueo confirmado", status)
        print("\n[✓] Dispositivo protegido contra escritura. Seguro para ejecutar rclone.")
        return

    # === UNBLOCK ===
    if args.unblock:
        print(f"[!] ATENCION: Desactivando proteccion en {args.unblock}")
        confirm = input("Escribe SI para confirmar: ")
        if confirm != "SI":
            print("Cancelado.")
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
        print(f"Estado de {args.status}:")
        for dev, st in status.items():
            print(f"  {dev}: {st}")
        return

    # === HASH PRE ===
    if args.hash_pre:
        print(f"[*] Calculando hash {args.algorithm} de {args.hash_pre}...")
        logger.header(args.case)
        hasher = HashChecker(args.algorithm)
        result = hasher.hash_path(args.hash_pre)
        print(f"\n[RESULTADO]")
        print(f"  Algoritmo: {result['algorithm']}")
        print(f"  Hash:      {result['hash']}")
        print(f"  Bytes:     {result['bytes']}")
        print(f"  Origen:    {result['path']}")
        logger.log("HASH_PRE", f"Hash origen calculado", result)
        if args.save:
            with open(args.save, "w") as f:
                json.dump(result, f, indent=2)
            print(f"\n[✓] Guardado en {args.save}")
        return

    # === HASH POST ===
    if args.hash_post:
        if not os.path.exists(args.hash_post):
            print(f"[ERROR] Archivo no encontrado: {args.hash_post}")
            sys.exit(1)
        print(f"[*] Calculando hash {args.algorithm} de {args.hash_post}...")
        hasher = HashChecker(args.algorithm)
        result = hasher.hash_path(args.hash_post)
        print(f"\n[RESULTADO]")
        print(f"  Algoritmo: {result['algorithm']}")
        print(f"  Hash:      {result['hash']}")
        print(f"  Bytes:     {result['bytes']}")
        print(f"  Archivo:   {result['path']}")
        logger.log("HASH_POST", f"Hash imagen calculado", result)
        if args.save:
            with open(args.save, "w") as f:
                json.dump(result, f, indent=2)
            print(f"\n[✓] Guardado en {args.save}")
        return

    # === VERIFY ===
    if args.verify:
        pre_file, post_file = args.verify
        with open(pre_file) as f:
            pre = json.load(f)
        with open(post_file) as f:
            post = json.load(f)
        print(f"[*] Verificando integridad...")
        print(f"  Pre:  {pre['hash']} ({pre['algorithm']})")
        print(f"  Post: {post['hash']} ({post['algorithm']})")
        if pre["algorithm"] != post["algorithm"]:
            print(f"[!] ADVERTENCIA: ¡Algoritmos diferentes!")
        checker = HashChecker(pre["algorithm"])
        match = checker.verify(pre, post)
        if match:
            print(f"\n[✓] INTEGRIDAD VERIFICADA - Los hashes coinciden perfectamente")
            logger.log("VERIFY", "Integridad confirmada", {"match": True})
        else:
            print(f"\n[✗] FALLO DE INTEGRIDAD - Los hashes NO coinciden")
            logger.log("VERIFY", "Fallo de integridad", {"match": False})
            sys.exit(2)
        return

    # === FULL ===
    if args.full:
        device, image_path = args.full
        print(f"[*] FLUJO FORENSE COMPLETO EVIDGUARD")
        print(f"    Caso:   {args.case}")
        print(f"    Origen: {device}")
        print(f"    Imagen: {image_path}")
        print(f"    Hash:   {args.hash}")
        print()
        logger.header(args.case)

        # 1. Block
        print("[1/4] Activando bloqueo de escritura...")
        blocker = WriteBlocker(device)
        for target, ok, msg in blocker.enable():
            if not ok:
                print(f"[ERROR] {target}: {msg}")
                sys.exit(1)
        print("[✓] Bloqueado\n")
        logger.log("BLOCK", "Bloqueo activado")

        # 2. Hash source
        print(f"[2/4] Hasheando origen ({args.hash})...")
        hasher = HashChecker(args.hash)
        pre = hasher.hash_path(device)
        print(f"[✓] {pre['hash']}\n")
        logger.log("HASH_PRE", "Completado", pre)

        # 3. Wait for rclone
        print("[3/4] LISTO PARA RCLONE")
        print(f"""
    El dispositivo origen esta bloqueado y hasheado.
    Ahora ejecuta tu comando de rclone, por ejemplo:

    rclone copy {device} remote:bucket/evidencia/{args.case}.raw

    O si rclone espera un archivo:

    sudo dd if={device} of=/tmp/{args.case}.raw bs=4M status=progress
    rclone copy /tmp/{args.case}.raw remote:bucket/

    Una vez creada la imagen, vuelve a ejecutar esta herramienta con --hash-post
    o pulsa Enter para hashear la imagen ahora (si ya existe).
        """)
        if not os.path.exists(image_path):
            input("Pulsa Enter cuando la imagen este lista...")
        if not os.path.exists(image_path):
            print(f"[ERROR] Imagen no encontrada: {image_path}")
            sys.exit(1)

        # 4. Hash image and verify
        print(f"[4/4] Hasheando imagen y verificando...")
        post = hasher.hash_path(image_path)
        print(f"  Origen: {pre['hash']}")
        print(f"  Imagen: {post['hash']}")
        if hasher.verify(pre, post):
            print(f"\n[✓✓✓] INTEGRIDAD FORENSE CONFIRMADA")
            logger.log("VERIFY", "PASS", {"match": True})
        else:
            print(f"\n[✗✗✗] FALLO DE INTEGRIDAD FORENSE")
            logger.log("VERIFY", "FAIL", {"match": False})
            sys.exit(2)

        logger.footer()
        print(f"\nLog guardado: {args.log}")
        return

if __name__ == "__main__":
    main()
