#!/usr/bin/env python3
"""Guard removed executable code, while preserving historical settings and copyright."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
VIEWS = ROOT / "LiveContainerSwiftUI" / "Views"
RETIRED = [
    "LiveBoardHomeScreen.swift", "LiveBoard.swift",
    "LiveBoardConsoleScreen.swift", "LiveBoardConsoleLayout.swift",
    "LiveBoardBuiltInJIT.swift", "LiveBoardJITSetup.swift",
    "LiveBoardAppCustomization.swift", "LiveBoardControllerInput.swift",
    "LiveBoardIconEdges.swift", "LiveBoardIconStore.swift",
    "LiveBoardNavigationAudio.swift", "LiveBoardOrientation.swift",
    "LiveBoardLaunchAction.swift",
    "ManzanaOnDevicePairing.swift",
    "ManzanaExpiryReminderCenter.swift", "ManzanaExpiryReminderSettings.swift",
    "LiveBoardModeLibrary.swift",
    "Manzana/ManzanaDesktopView.swift", "Manzana/ManzanaAnimatedWallpaper.swift",
    "Manzana/ManzanaWallpaperMedia.swift",
    "Manzana/ManzanaFileStore.swift", "Manzana/ManzanaFilesView.swift",
    "StrataPairingRecord.swift",
    "BloomBox/BloomBoxGameBoxScreen.swift",
    "BloomBox/BloomBoxGameBoxLayout.swift",
    "BloomBox/BloomBoxGameBoxLibrary.swift",
    "BloomBox/BloomBoxControllerInput.swift",
    "BloomBox/BloomBoxNavigationAudio.swift"
]
REQUIRED = [
    "BloomBox/BloomBoxHomeScreen.swift",
    "BloomBox/BloomBoxReservedSection.swift",
    "BloomBox/BloomBoxLauncherPreferences.swift",
    "BloomBox/BloomBoxAppCustomization.swift",
    "BloomBox/BloomBoxIconEdges.swift", "BloomBox/BloomBoxIconStore.swift",
    "BloomBox/BloomBoxOrientation.swift",
    "BloomBox/BloomBoxLaunchAction.swift",
    "BloomBox/BloomBoxJITCoordinator.swift", "BloomBox/BloomBoxJITSetup.swift",
    "BloomBox/BloomBoxOnDevicePairing.swift",
    "BloomBox/BloomBoxExpiryReminderCenter.swift", "BloomBox/BloomBoxExpiryReminderSettings.swift",
    "BloomBox/BloomBoxLauncherRoot.swift",
    "BloomBox/BloomBoxHomeChrome.swift",
    "BloomBox/BloomBoxHomeLayout.swift",
    "BloomBox/BloomBoxHomeNavigation.swift",
    "BloomBox/BloomBoxWidgetLayout.swift",
    "BloomBox/BloomBoxNewsPage.swift",
    "BloomBox/BloomBoxMotionMedia.swift"
]
OBSOLETE_SYMBOLS = (
    "StrataJITRequestHandler", "StrataJITWorker",
    "StrataPairingRecord", "ManzanaAnimatedWallpaper",
    "ManzanaWallpaperMedia"
)
for old in RETIRED:
    if (VIEWS / old).exists():
        raise SystemExit("Retired launcher module still exists: " + old)
for current in REQUIRED:
    if not (VIEWS / current).is_file():
        raise SystemExit("Missing BloomBox source module: " + current)
for filename in ("ShareExtension/StrataJITWorker.swift",
                 "Scripts/package-combined-session.py"):
    if (ROOT / filename).exists():
        raise SystemExit("Retired Strata executable/packaging path: " + filename)
count = 0
for directory in (VIEWS, ROOT / "ShareExtension", ROOT / "Scripts"):
    for file in directory.rglob("*"):
        if file.resolve() == Path(__file__).resolve():
            continue  # The audit itself contains forbidden names as string literals.
        if file.suffix.lower() not in {".swift", ".m", ".mm", ".h", ".py", ".sh"}:
            continue
        count += 1
        source = file.read_text(encoding="utf-8", errors="replace")
        for symbol in OBSOLETE_SYMBOLS:
            if symbol in source:
                raise SystemExit("Old executable type in " + str(file.relative_to(ROOT)) + ": " + symbol)
home = (VIEWS / "BloomBox/BloomBoxHomeScreen.swift").read_text(encoding="utf-8")
for key in ("LiveBoardHomeLayout", "LiveBoardHiddenPages",
            "ManzanaMotionWallpaper", "ManzanaPageWidgets"):
    if key not in home:
        raise SystemExit("A saved user preference key is missing: " + key)
# Guard the exact persisted Home key, not just an unrelated mention.
if '@AppStorage("LiveBoardHomeLayout", store:' not in home:
    raise SystemExit("Persisted Home layout key was changed: would reset existing desktops")
if 'let keys = ["LiveBoardHomeLayout", "LiveBoardHiddenPages"' not in home:
    raise SystemExit("Theme export no longer includes the legacy Home layout")
if '@AppStorage("BloomBoxHomeLayout", store:' in home:
    raise SystemExit("New un-migrated Home layout key would hide existing user data")
for file in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
    if not (ROOT / file).is_file():
        raise SystemExit("Missing source license/credits: " + file)
credits = (ROOT / "THIRD_PARTY_NOTICES.md").read_text()
for project in ("Strata", "LiveContainer", "SideStore", "StikJIT"):
    if project not in credits:
        raise SystemExit("Attribution missing: " + project)

# Distribution branding must not reintroduce Strata's localized app name or
# store legacy icon binaries in the repository. Build scripts regenerate icons.
import subprocess
localizations = sorted((ROOT / "Resources").glob("*.lproj/InfoPlist.strings"))
if len(localizations) != 39:
    raise SystemExit(f"Unexpected InfoPlist localization count: {len(localizations)}")
for entry in localizations:
    value = entry.read_text(encoding="utf-8")
    if '"CFBundleName" = "BloomBox";' not in value or "Strata" in value:
        raise SystemExit("Legacy localized app name in " + str(entry.relative_to(ROOT)))
if (ROOT / "Resources/Assets.xcassets/LiveBoardByeTunes.imageset").exists():
    raise SystemExit("Retired artwork still present in Assets.xcassets")
for catalog in ("AppIcon.appiconset", "AppIconGrey.appiconset"):
    for path in (ROOT / "Resources/Assets.xcassets" / catalog).glob("*.png"):
        tracked = subprocess.run(
            ["git", "ls-files", "--error-unmatch", str(path.relative_to(ROOT))],
            cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            check=False,
        )
        if tracked.returncode == 0:
            raise SystemExit("Old app icon binary is still committed: " + str(path))
# The removed console is not compiled: only the isolated placeholder stays.
reserved = (VIEWS / "BloomBox/BloomBoxReservedSection.swift").read_text(encoding="utf-8")
launcher = (VIEWS / "BloomBox/BloomBoxLauncherRoot.swift").read_text(encoding="utf-8")
app_list = (VIEWS / "AppList/LCAppListView.swift").read_text(encoding="utf-8")
if "struct BloomBoxReservedSection: View" not in reserved:
    raise SystemExit("Missing independent future-feature slot")
for code in (reserved, launcher, app_list):
    if "BloomBoxRequestGameMode" in code or "BloomBoxGameBoxScreen" in code:
        raise SystemExit("Retired console route returned")
if "GameBox" in launcher or 'value: "reserved"' not in launcher:
    raise SystemExit("Old launcher card returned")
icon_source = (VIEWS / "BloomBox/BloomBoxIconStore.swift").read_text(encoding="utf-8")
if "LiveBoardByeTunes" in icon_source or "com.EduAlexxis.MusicManager" in icon_source:
    raise SystemExit("Legacy music artwork override returned")

print(f"BloomBox code audit passed: {count} source files; GameBox retired, reserved slot active, credits preserved")
