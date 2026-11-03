#!/usr/bin/env python3
"""Guard removed executable code, while preserving historical settings and copyright."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
VIEWS = ROOT / "LiveContainerSwiftUI" / "Views"
RETIRED = [
    "LiveBoardHomeScreen.swift", "LiveBoard.swift",
    "LiveBoardConsoleScreen.swift", "LiveBoardConsoleLayout.swift",
    "LiveBoardModeLibrary.swift",
    "Manzana/ManzanaDesktopView.swift", "Manzana/ManzanaAnimatedWallpaper.swift",
    "Manzana/ManzanaWallpaperMedia.swift",
    "Manzana/ManzanaFileStore.swift", "Manzana/ManzanaFilesView.swift",
    "StrataPairingRecord.swift"
]
REQUIRED = [
    "BloomBox/BloomBoxHomeScreen.swift",
    "BloomBox/BloomBoxGameBoxScreen.swift",
    "BloomBox/BloomBoxGameBoxLayout.swift",
    "BloomBox/BloomBoxGameBoxLibrary.swift",
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
print(f"BloomBox code audit passed: {count} source files; user saves and legal credits preserved")
