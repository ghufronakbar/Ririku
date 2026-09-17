#!/usr/bin/env python3
"""Check that the app version is identical everywhere it is written."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def find(path, pattern, label):
    match = re.search(pattern, read(path))
    if not match:
        sys.exit(f"{path}: cannot find {label}")
    return match.group(1)


version = find("scripts/build-app.sh", r'"CFBundleShortVersionString": "([^"]+)"', "CFBundleShortVersionString")
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    sys.exit(f"scripts/build-app.sh: version {version!r} is not MAJOR.MINOR.PATCH")

places = {
    "extension/manifest.json": json.loads(read("extension/manifest.json"))["version"],
    "Sources/Ririku/MediaServices.swift": find("Sources/Ririku/MediaServices.swift", r'"Ririku/([^ ]+) \(', "User-Agent version"),
    "Sources/Ririku/SetupView.swift": find("Sources/Ririku/SetupView.swift", r'"Ririku ([^ ]+) · Native macOS"', "Setup version text"),
}

problems = [f"{place}: {found} (expected {version})" for place, found in places.items() if found != version]
if f"## [{version}]" not in read("CHANGELOG.md"):
    problems.append(f"CHANGELOG.md: no section for {version}")
if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Version {version} is consistent in {len(places) + 2} places")
