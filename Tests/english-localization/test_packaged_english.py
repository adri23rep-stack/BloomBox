#!/usr/bin/env python3
"""Fail the build if English Localizable.strings was not shipped in the actual IPA."""
from pathlib import Path
import plistlib
import sys
import zipfile

ipa = Path(sys.argv[1])
assert ipa.exists(), f"IPA missing: {ipa}"
with zipfile.ZipFile(ipa) as archive:
    files = archive.namelist()
    matches = [
        name for name in files
        if name.startswith("Payload/") and
           name.endswith(".app/en.lproj/Localizable.strings")
    ]
    assert matches, "English localization missing from packaged app (en.lproj/Localizable.strings)"
    data = archive.read(matches[0])
    try:
        contents = plistlib.loads(data)
    except (ValueError, TypeError, UnicodeDecodeError):
        contents = data.decode("utf-8-sig")
    for key in ("Módulos", "Instalar app", "Temas", "Juegos", "Sugerencias"):
        assert key in contents, f"English localization key not packaged: {key}"
    print(f"English localization packaged: {matches[0]} ({len(data)} bytes)")
