#!/usr/bin/env python3
"""Validate the BloomBox+SideStore IPA, including the ActivityKit extension."""
import hashlib
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
    # Verify the exact owner-supplied starter theme bytes, not just filenames.
    for theme, sha256 in {
        "KirbyPink": "307754522eedd7d152d9a74e4eb4b881ec0f466c3cdf962834601942ebacfa78",
        "YellowBowser": "fa20237daf39266247eb9a5fc8d003da4bde87c235e0affef287d0f8d6e0a82a",
    }.items():
        bundled = app + "StarterThemes/" + theme + ".bbtheme"
        preview = app + "StarterThemes/" + theme + ".jpg"
        if bundled not in entries or preview not in entries:
            raise SystemExit("Missing packaged BloomBox starter theme or preview: " + theme)
        if hashlib.sha256(archive.read(bundled)).hexdigest() != sha256:
            raise SystemExit("BloomBox starter theme bytes changed: " + theme)
        if not archive.read(preview).startswith(bytes.fromhex("ffd8ff")):
            raise SystemExit("BloomBox starter theme preview is not JPEG: " + theme)

    host = plistlib.loads(archive.read(app + "Info.plist"))
    ext = plistlib.loads(archive.read(widget + "Info.plist"))
    if host.get("CFBundleName") != "BloomBox" or host.get("CFBundleDisplayName") != "BloomBox":
        raise SystemExit("Wrong app! Latest BloomBox display name missing from final IPA")
    if host.get("NSSupportsLiveActivities") is not True:
        raise SystemExit("NSSupportsLiveActivities is not enabled")
    ui = app + "Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI"
    if ui not in entries or len(archive.read(ui)) < 100000:
        raise SystemExit("The compiled BloomBox UI is missing/invalid")
    for name in ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"):
        if app + name in entries and not archive.read(app + name).startswith(bytes.fromhex("89504e470d0a1a0a")):
            raise SystemExit("Missing the correct BloomBox RGB app icon: " + name)
    from pathlib import Path
    source_root = Path("LiveContainerSwiftUI/Views")
    for item in ("BloomBox/BloomBoxNewsPage.swift", "BloomBox/BloomBoxWidgetViews.swift", "BloomBox/BloomBoxAnimatedWallpaper.swift",
                 "BloomBox/BloomBoxMotionMedia.swift", "BloomBox/BloomBoxIconCustomization.swift",
                 "BloomBox/BloomBoxArtworkLibrary.swift",
                 "BloomBox/BloomBoxFilesView.swift", "BloomBox/BloomBoxFileStore.swift",
                 "BloomBox/BloomBoxHomeChrome.swift", "BloomBox/BloomBoxHomeScreen.swift",
                 "BloomBox/BloomBoxReservedSection.swift", "BloomBox/BloomBoxLauncherPreferences.swift",
                 "BloomBox/BloomBoxJITCoordinator.swift", "BloomBox/BloomBoxJITSetup.swift",
                 "BloomBox/BloomBoxOnDevicePairing.swift",
                 "BloomBox/BloomBoxLauncherRoot.swift"):
        if not (source_root / item).is_file():
            raise SystemExit("Wrong source branch: missing BloomBox UI file " + item)
    home_source = (source_root / "BloomBox/BloomBoxHomeScreen.swift").read_text()
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
