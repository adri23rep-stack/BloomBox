#!/usr/bin/env python3
"""Restore pinned binary dependencies from the matching Strata source release."""
from pathlib import Path
import hashlib, io, json, urllib.request, zipfile
root = Path(__file__).resolve().parent.parent
expected = json.loads((root / "Scripts/bundled-dependencies.json").read_text())
missing = [name for name, digest in expected.items() if not (root/name).exists() or hashlib.sha256((root/name).read_bytes()).hexdigest() != digest]
if missing:
    url = "https://github.com/huzaifahshahid71-ops/Strata/releases/download/v3.8.11-r11/Strata-r11-source.zip"
    print("Downloading pinned dependencies from Strata revision 11…")
    with urllib.request.urlopen(url, timeout=120) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    for name in missing:
        data = archive.read("Strata/" + name)
        if hashlib.sha256(data).hexdigest() != expected[name]:
            raise SystemExit("Dependency checksum mismatch: " + name)
        destination = root/name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        print("Verified " + name)
print("Bundled dependencies ready.")
