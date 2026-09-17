#!/usr/bin/env python3
"""Check that every English interface string in the code has id/ja translations with matching placeholders."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [ROOT / "Sources/Ririku", ROOT / "Sources/RirikuCore"]
LANGUAGES = ["id", "ja"]
LITERAL = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [re.compile(r'\bt\(' + LITERAL), re.compile(r'\bUIText\(' + LITERAL),
            re.compile(r'BridgeError\.system\(' + LITERAL), re.compile(r'return \(' + LITERAL + r', \[\]\)')]
PLACEHOLDER = re.compile(r'%(?:\d+\$)?@')


def load(language):
    path = ROOT / "Localization" / f"{language}.lproj" / "Localizable.strings"
    result = subprocess.run(["/usr/bin/plutil", "-convert", "json", "-o", "-", str(path)], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"{path}: {result.stderr.strip() or result.stdout.strip()}")
    return json.loads(result.stdout)


keys = {}
for folder in SOURCES:
    for file in sorted(folder.glob("*.swift")):
        for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
            for pattern in PATTERNS:
                for match in pattern.finditer(line):
                    key = match.group(1).replace('\\"', '"')
                    if "\\(" in key:
                        sys.exit(f"{file.relative_to(ROOT)}:{number}: a key must not use Swift interpolation: {key}")
                    if re.search(r"[A-Za-z]", PLACEHOLDER.sub("", key)):
                        keys.setdefault(key, f"{file.relative_to(ROOT)}:{number}")

problems = []
for language in LANGUAGES:
    table = load(language)
    for key, location in sorted(keys.items()):
        if key not in table:
            problems.append(f"[{language}] not translated ({location}): {key}")
        elif len(PLACEHOLDER.findall(key)) != len(PLACEHOLDER.findall(table[key])):
            problems.append(f"[{language}] different number of placeholders: {key}")
    for key in sorted(set(table) - set(keys)):
        problems.append(f"[{language}] unused key: {key}")
load("en")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Localization complete: {len(keys)} keys × {', '.join(LANGUAGES)}")
