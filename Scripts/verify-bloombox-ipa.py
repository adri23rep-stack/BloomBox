#!/usr/bin/env python3
"""Validate the BloomBox+SideStore IPA, including the ActivityKit extension."""
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
    if host.get("CFBundleName") != "BloomBox" or host.get("CFBundleDisplayName") != "BloomBox":
        raise SystemExit("Wrong app! Latest BloomBox display name missing from final IPA")
    if host.get("NSSupportsLiveActivities") is not True:
        raise SystemExit("NSSupportsLiveActivities is not enabled")
    if "processing" not in host.get("UIBackgroundModes", []):
        raise SystemExit("Background processing capability is missing from BloomBox")
    document_types = {
        t for entry in host.get("CFBundleDocumentTypes", [])
        for t in entry.get("LSItemContentTypes", [])
    }
    if not {"org.bloombox.archive.ipa", "org.bloombox.archive.tipa"}.issubset(document_types):
        raise SystemExit("BloomBox cannot receive IPA and TIPA documents from Files")
    if "public.item" in document_types:
        raise SystemExit("BloomBox must not hijack all document types in Files")
    pairing_modes = host.get("BGTaskSchedulerPermittedIdentifiers", [])
    host_id = host.get("CFBundleIdentifier", "")
    if not any(x == host_id + ".pairing.*" for x in pairing_modes):
        raise SystemExit("JIT pairing background task identifier is missing/mismatched")
    ui = app + "Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI"
    if ui not in entries or len(archive.read(ui)) < 100000:
        raise SystemExit("The compiled BloomBox UI is missing/invalid")
    for name in ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"):
        if app + name in entries and not archive.read(app + name).startswith(bytes.fromhex("89504e470d0a1a0a")):
            raise SystemExit("Missing the correct BloomBox RGB app icon: " + name)
    from pathlib import Path
    source_root = Path("LiveContainerSwiftUI/Views")
    for item in ("Manzana/ManzanaDesktopView.swift", "Manzana/ManzanaAnimatedWallpaper.swift",
                 "Manzana/ManzanaFilesView.swift"):
        if not (source_root / item).is_file():
            raise SystemExit("Wrong source branch: missing BloomBox UI file " + item)
    home_source = (source_root / "LiveBoardHomeScreen.swift").read_text()
    for expected in ("ManzanaPageWidgets", "LiveBoardHiddenPages", "ManzanaMotionWallpaper", "ManzanaExpiryReminderCenter"):
        if expected not in home_source:
            raise SystemExit("Missing an expected BloomBox UI feature: " + expected)

    if ext.get("CFBundleExecutable") != "ManzanaExpiryWidget":
        raise SystemExit("The widget executable is not declared")
    if ext.get("CFBundleVersion") != host.get("CFBundleVersion"):
        raise SystemExit("Mismatched widget and host bundle versions")
    if not ext.get("CFBundleIdentifier", "").startswith(host.get("CFBundleIdentifier", "") + "."):
        raise SystemExit("Widget bundle identifier is not scoped under BloomBox")
    if ext.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        raise SystemExit("Missing WidgetKit extension point")
print(f"Validated {ipa.name}: Dynamic Island extension, JIT helper, LiveProcess and SideStore are present.")
