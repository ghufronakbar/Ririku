#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP="$ROOT/build/Notch Box.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/NotchBox" "$APP/Contents/MacOS/NotchBox"
cp "$BIN/NotchBoxHost" "$APP/Contents/Resources/NotchBoxHost"
/usr/bin/python3 - "$APP" <<'PY'
import pathlib
import plistlib
import sys
app = pathlib.Path(sys.argv[1])
metadata = {
    "CFBundleExecutable": "NotchBox",
    "CFBundleIdentifier": "local.notchbox.mac",
    "CFBundleName": "Notch Box",
    "CFBundleDisplayName": "Notch Box",
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "0.2.4",
    "CFBundleVersion": "2",
    "LSMinimumSystemVersion": "14.0",
    "LSUIElement": True,
    "NSHighResolutionCapable": True,
}
with (app / "Contents/Info.plist").open("wb") as output:
    plistlib.dump(metadata, output)
PY
codesign --force --sign - "$APP/Contents/Resources/NotchBoxHost"
codesign --force --sign - "$APP"
printf '\nAplikasi lokal: %s\n' "$APP"
