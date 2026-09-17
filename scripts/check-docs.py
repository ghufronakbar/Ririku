#!/usr/bin/env python3
"""Check Markdown documentation: relative links, heading anchors, and translation notes."""
from pathlib import Path
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
FENCE = re.compile(r"```.*?```", re.S)
LINK = re.compile(r"\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.*)$", re.M)
TRANSLATIONS = ["README.id.md", "README.ja.md", "docs/user-guide.id.md", "docs/user-guide.ja.md"]
VERSION = re.search(r'"CFBundleShortVersionString": "([^"]+)"', (ROOT / "scripts/build-app.sh").read_text(encoding="utf-8")).group(1)


def anchor(heading):
    text = re.sub(r"[*`]", "", heading).strip().lower()
    kept = []
    for character in text:
        category = unicodedata.category(character)
        if character in " -":
            kept.append("-")
        elif character == "_" or category[0] in "LN" or category == "Mn":
            kept.append(character)
    return "".join(kept)


files = sorted(set(ROOT.glob("*.md")) | set((ROOT / "docs").rglob("*.md")))
anchors = {file: {anchor(heading) for heading in HEADING.findall(file.read_text(encoding="utf-8"))} for file in files}
problems = []

for file in files:
    body = FENCE.sub("", file.read_text(encoding="utf-8"))
    for link in LINK.findall(body):
        if link.startswith(("http://", "https://", "mailto:")):
            continue
        target, _, fragment = link.partition("#")
        destination = (file.parent / target).resolve() if target else file
        name = file.relative_to(ROOT)
        if not destination.exists():
            problems.append(f"{name}: missing link target {link}")
        elif fragment and destination.suffix == ".md" and fragment not in anchors.get(destination, set()):
            problems.append(f"{name}: unknown anchor {link}")

for translation in TRANSLATIONS:
    path = ROOT / translation
    if not path.is_file():
        problems.append(f"{translation}: missing translation")
    elif VERSION not in path.read_text(encoding="utf-8").split("\n## ")[0]:
        problems.append(f"{translation}: header does not name version {VERSION} of the English document")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Documentation checked: {len(files)} files, links and anchors resolve")
