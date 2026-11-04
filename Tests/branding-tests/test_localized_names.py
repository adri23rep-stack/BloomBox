#!/usr/bin/env python3
"""Guard the localized display name in both source .strings and signed IPA steps."""
import importlib.util
import plistlib
from pathlib import Path

root = Path(__file__).resolve().parents[2]
module_path = root / "Scripts/brand-bloombox-final-ipa.py"
spec = importlib.util.spec_from_file_location("bloombox_brand", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

localizations = sorted((root / "Resources").glob("*.lproj/InfoPlist.strings"))
assert len(localizations) == 39, "Localized app-name source coverage changed"

for path in localizations:
    source = path.read_bytes()
    assert source.decode("utf-8").strip() == '"CFBundleName" = "BloomBox";', path
    branded = plistlib.loads(module.translated_name(source))
    assert branded["CFBundleName"] == "BloomBox", path
    assert branded["CFBundleDisplayName"] == "BloomBox", path

for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
    source = plistlib.dumps({"CFBundleName": "Strata", "OtherSetting": "keep-me"}, fmt=fmt)
    branded = plistlib.loads(module.translated_name(source))
    assert branded == {
        "CFBundleName": "BloomBox",
        "CFBundleDisplayName": "BloomBox",
        "OtherSetting": "keep-me",
    }
try:
    module.translated_name(b'"CFBundleName" = "Unexpected";')
except ValueError:
    pass
else:
    raise AssertionError("Unknown uncompiled localization must fail safely")
print("PASS: 39 localized BloomBox names, binary/XML compatibility and strict conversion.")
