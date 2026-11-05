#!/usr/bin/env python3
"""Legacy console is retired; independent GameBox v2 and Home/JIT/RAM+ remain."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "LiveContainerSwiftUI/Views/BloomBox"
host = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
launcher = (ui / "BloomBoxLauncherRoot.swift").read_text()
reserved = (ui / "BloomBoxReservedSection.swift").read_text()
prefs = (ui / "BloomBoxLauncherPreferences.swift").read_text()

for name in (
    "BloomBoxGameBoxScreen.swift", "BloomBoxGameBoxLayout.swift",
    "BloomBoxGameBoxLibrary.swift", "BloomBoxControllerInput.swift",
    "BloomBoxNavigationAudio.swift",
):
    assert not (ui / name).exists(), f"Removed console still has source: {name}"
assert not (root / "LiveContainerSwiftUI/Utilities/BloomBoxGameModeGate.swift").exists()
assert "BloomBoxReservedSection(backToHome:" in host
assert '"reserved"' in launcher and "Espacio reservado" in launcher
assert "BloomBoxRequestGameMode" not in launcher + host
assert "GameBox" not in reserved
assert 'value: "gamebox"' in launcher
assert "BloomBoxGameBoxV2Screen(" in host
assert "BloomBoxNikaidoControllerSlot" in (ui / "BloomBoxGameBoxV2Screen.swift").read_text()
gamebox = (ui / "BloomBoxGameBoxV2Screen.swift").read_text()
journal = (ui / "BloomBoxCrashJournal.swift").read_text()
liveprocess = (root / "LiveProcess/main.m").read_text()
adapter = (root / "LiveContainerSwiftUI/Views/BloomBoxAdapters/LiveContainerDiagnosticsAdapter.swift").read_text()
assert "BloomBoxCrashJournal.shared.enterGameBox()" in gamebox
assert "BloomBoxCrashJournal.shared.leaveGameBox()" in gamebox
assert '"BloomBoxGameBoxSafeGraphics"' in gamebox and "guard !safeGraphics" in gamebox
assert "BloomBoxCrashJournal.shared.beginHostSession()" in (
    root / "LiveContainerSwiftUI/App/AppDelegate.swift"
).read_text()
assert "BloomBoxMetricKitSink" in journal and "jsonRepresentation()" in journal
assert "func makeExport()" in journal and "ShareLink(item: exportURL)" in journal
assert "liveprocess.guest_boot.started" in liveprocess
assert "liveprocess.guest_boot.returned" in liveprocess
assert "Library/BloomBoxDiagnostics" in adapter
assert "LCUtils" not in journal and "LCSharedUtils" not in journal
assert ".allowsHitTesting(false)" in (ui / "BloomBoxGameBoxV2Screen.swift").read_text()
assert "gameRoutePrompt" not in host and "gameGatePrompt" not in host
assert "BloomBoxRAMPlusView" in host and "LiveBoardJITSetup" in host
assert "approveEmulatorLaunch" in host and "remoteGameProfiles" in host
assert "LiveBoardOrientation.beginGuest" in host and "landscapeGuest" in host
assert 'defaults.set("ios", forKey: sessionKey)' in prefs
assert "LiveBoardHomeLayout" in (ui / "BloomBoxHomeScreen.swift").read_text()
print("PASS: Original console retired; GameBox v2 glass UI, inert Nikaido slot, Home/JIT/RAM+ preserved.")
