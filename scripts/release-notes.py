#!/usr/bin/env python3
"""Print GitHub release notes for a version: its changelog section plus install instructions."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
version = sys.argv[1] if len(sys.argv) > 1 else ""
changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
section = re.search(rf"^## \[{re.escape(version)}\].*?$(.*?)(?=^## \[|\Z)", changelog, re.M | re.S)

print(section.group(1).strip() if section else "See CHANGELOG.md.")
print(f"""
## Install

1. Unzip and move **Ririku.app** into your **Applications** folder before opening it.
2. Ririku is signed ad hoc and is not notarized by Apple, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click **Open Anyway**. On macOS 14, Control-click the app and choose **Open** instead.
3. In **Setup → Chrome connection**, follow the four steps to load the Chrome extension.

Full instructions: <https://github.com/ghufronakbar/ririku/blob/main/docs/user-guide.md#install>

- Requires macOS 14 or later. This build contains an arm64 (Apple silicon) executable only.
- After updating, copy the extension again from Setup and reload it in `chrome://extensions`.
- Verify the download with `shasum -a 256 -c SHA256SUMS.txt`.""")
