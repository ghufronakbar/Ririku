#!/usr/bin/env python3
"""Register the Chrome native host for development. Users can do this from Setup → Chrome connection in the app."""
import argparse
import json
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
# The ID is fixed because the extension manifest carries a "key"; pass one only for a fork with another key.
parser.add_argument("extension_id", nargs="?", default="bmmbkmngcmjoihlcmehlnfpedhoefofi", help="Extension ID (default: the official Ririku ID)")
parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1] / "build/Ririku.app")
arguments = parser.parse_args()
if not re.fullmatch(r"[a-p]{32}", arguments.extension_id):
    parser.error("An extension ID must be 32 characters from a to p.")
binary = arguments.app.resolve() / "Contents/Resources/RirikuHost"
if not binary.is_file() or not os.access(binary, os.X_OK):
    parser.error("The native host is not built yet. Run bash scripts/build-app.sh first.")
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
print(f"Registered: {manifest}")
print("Open Ririku, then reload your YouTube or YouTube Music tabs.")
