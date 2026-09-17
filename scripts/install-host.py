#!/usr/bin/env python3
"""Daftarkan native host Chrome untuk pengembangan. Pengguna biasa cukup memakai Setup → Koneksi Chrome di app."""
import argparse
import json
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
# ID tetap karena manifest extension memuat field "key"; argumen hanya untuk fork dengan key berbeda.
parser.add_argument("extension_id", nargs="?", default="bmmbkmngcmjoihlcmehlnfpedhoefofi", help="ID extension (default: ID resmi Ririku)")
parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1] / "build/Ririku.app")
arguments = parser.parse_args()
if not re.fullmatch(r"[a-p]{32}", arguments.extension_id):
    parser.error("Extension ID harus 32 karakter a–p.")
binary = arguments.app.resolve() / "Contents/Resources/RirikuHost"
if not binary.is_file() or not os.access(binary, os.X_OK):
    parser.error("Native host belum dibangun. Jalankan bash scripts/build-app.sh terlebih dahulu.")
folder = Path.home() / "Library/Application Support/Google/Chrome/NativeMessagingHosts"
folder.mkdir(parents=True, exist_ok=True)
manifest = folder / "io.github.lanstheprodigy.ririku.bridge.json"
payload = {
    "name": "io.github.lanstheprodigy.ririku.bridge",
    "description": "Ririku local music bridge",
    "path": str(binary),
    "type": "stdio",
    "allowed_origins": [f"chrome-extension://{arguments.extension_id}/"],
}
temporary = manifest.with_suffix(".json.tmp")
with temporary.open("w", encoding="utf-8") as output:
    json.dump(payload, output, indent=2)
    output.write("\n")
os.chmod(temporary, 0o600)
temporary.replace(manifest)
print(f"Terdaftar: {manifest}")
print("Buka aplikasi Ririku, lalu muat ulang tab YouTube/YouTube Music.")
