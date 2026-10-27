#!/usr/bin/env python3
"""Validate the Manzana+SideStore IPA, including the ActivityKit extension."""
import plistlib
import sys
import zipfile
from pathlib import Path

ipa = Path(sys.argv[1] if len(sys.argv) > 1 else "LiveContainer+SideStore.ipa")
if not ipa.is_file():
    raise SystemExit(f"Missing IPA: {ipa}")
with zipfile.ZipFile(ipa) as archive:
    entries = set(archive.namelist())
    app = "Payload/LiveContainer.app/"
    widget = app + "PlugIns/ManzanaExpiryWidget.appex/"
    for relative in (
        app + "Info.plist", widget + "Info.plist", widget + "ManzanaExpiryWidget",
        app + "PlugIns/LiveProcess.appex/LiveProcess",
        app + "PlugIns/JITHelper.appex/ShareExtension",
    ):
        if relative not in entries:
            raise SystemExit(f"Missing essential IPA component: {relative}")
    if not any("/SideStoreApp.framework/" in name for name in entries):
        raise SystemExit("Embedded SideStore app is missing")
    host = plistlib.loads(archive.read(app + "Info.plist"))
    ext = plistlib.loads(archive.read(widget + "Info.plist"))
    if host.get("NSSupportsLiveActivities") is not True:
        raise SystemExit("NSSupportsLiveActivities is not enabled")
    if ext.get("CFBundleExecutable") != "ManzanaExpiryWidget":
        raise SystemExit("The widget executable is not declared")
    if ext.get("CFBundleVersion") != host.get("CFBundleVersion"):
        raise SystemExit("Mismatched widget and host bundle versions")
    if not ext.get("CFBundleIdentifier", "").startswith(host.get("CFBundleIdentifier", "") + "."):
        raise SystemExit("Widget bundle identifier is not scoped under Manzana")
    if ext.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        raise SystemExit("Missing WidgetKit extension point")
print(f"Validated {ipa.name}: Dynamic Island extension, JIT helper, LiveProcess and SideStore are present.")
