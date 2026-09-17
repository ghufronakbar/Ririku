#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
/usr/bin/python3 scripts/check-localization.py
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP="$ROOT/build/Ririku.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Ririku" "$APP/Contents/MacOS/Ririku"
cp "$BIN/RirikuHost" "$APP/Contents/Resources/RirikuHost"
rm -rf "$APP/Contents/Resources/"*.lproj
cp -R "$ROOT/Localization/"*.lproj "$APP/Contents/Resources/"
rm -rf "$APP/Contents/Resources/ChromeExtension"
cp -R "$ROOT/extension" "$APP/Contents/Resources/ChromeExtension"
/usr/bin/python3 - "$APP" <<'PY'
import pathlib
import plistlib
import sys
app = pathlib.Path(sys.argv[1])
metadata = {
    "CFBundleExecutable": "Ririku",
    "CFBundleIdentifier": "io.github.lanstheprodigy.ririku",
    "CFBundleName": "Ririku",
    "CFBundleDisplayName": "Ririku",
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "0.3.0",
    "CFBundleVersion": "4",
    "CFBundleDevelopmentRegion": "en",
    "CFBundleLocalizations": ["en", "id", "ja"],
    "LSMinimumSystemVersion": "14.0",
    "LSUIElement": True,
    "NSHighResolutionCapable": True,
}
with (app / "Contents/Info.plist").open("wb") as output:
    plistlib.dump(metadata, output)
PY
codesign --force --sign - "$APP/Contents/Resources/RirikuHost"
codesign --force --sign - "$APP"
printf '\nAplikasi lokal: %s\n' "$APP"
