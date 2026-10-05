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
rm -f "$APP/Contents/Resources/AppIcon.icns"
if [ -f "$ROOT/Resources/AppIcon.png" ]; then
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.icns"
fi
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
    "CFBundleShortVersionString": "0.4.0",
    "CFBundleVersion": "6",
    "CFBundleDevelopmentRegion": "en",
    "CFBundleLocalizations": ["en", "id", "ja"],
    "LSMinimumSystemVersion": "14.0",
    "LSUIElement": True,
    "NSHighResolutionCapable": True,
    "NSAppleEventsUsageDescription": "Ririku reads the current song and controls playback in Spotify or Music when you enable them in Setup.",
    "NSCalendarsFullAccessUsageDescription": "Ririku shows today's events in the Calendar widget. It only reads your calendars and never changes them.",
    "NSCameraUsageDescription": "Ririku shows your camera as a mirror in the Camera widget, only after you click it. Nothing is recorded or saved.",
}
if (app / "Contents/Resources/AppIcon.icns").exists():
    metadata["CFBundleIconFile"] = "AppIcon"
with (app / "Contents/Info.plist").open("wb") as output:
    plistlib.dump(metadata, output)
PY
codesign --force --sign - "$APP/Contents/Resources/RirikuHost"
codesign --force --sign - "$APP"
printf '\nLocal app bundle: %s\n' "$APP"
