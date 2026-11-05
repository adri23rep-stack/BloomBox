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
# Second-pass audit: prevent regressions in native launch, mobile geometry,
# gesture precedence, cross-process logging and recovery export.
assert ".scrollTargetBehavior(.viewAligned)" in gamebox
assert ".scrollPosition(id: $focusedKey)" in gamebox
assert "let compact = safeHeight < 520" in gamebox
assert "exclusively(before: TapGesture(count: 1))" in gamebox
assert "guard !launchPending else { return }" in gamebox
assert ".disabled(launchPending)" in gamebox
assert "if (!handle)" in liveprocess and "if (!payloadEntry)" in liveprocess
assert "BloomBoxFailRequest" in liveprocess
assert "liveprocess.custom_payload.dlopen_failed" in liveprocess
assert "liveprocess.bookmarks.invalid_format" in liveprocess
assert "Retrieved app info: %@" not in liveprocess
assert "ftruncate(fd, 0)" in liveprocess
assert "FileManager.default.urls(for: .applicationSupportDirectory" in adapter
assert "String(decoding: data.suffix" in journal
assert "contentModificationDate" in journal
assert "BloomBox-Diagnostics-" in journal
app_delegate = (root / "LiveContainerSwiftUI/App/AppDelegate.swift").read_text()
assert "if let original = class_getInstanceMethod" in app_delegate
assert "self.keyWindow!" not in app_delegate
assert ".allowsHitTesting(false)" in (ui / "BloomBoxGameBoxV2Screen.swift").read_text()
assert "gameRoutePrompt" not in host and "gameGatePrompt" not in host
assert "BloomBoxRAMPlusView" in host and "LiveBoardJITSetup" in host
assert "approveEmulatorLaunch" in host and "remoteGameProfiles" in host
assert "LiveBoardOrientation.beginGuest" in host and "landscapeGuest" in host
assert 'defaults.set("ios", forKey: sessionKey)' in prefs
assert "LiveBoardHomeLayout" in (ui / "BloomBoxHomeScreen.swift").read_text()
print("PASS: Original console retired; GameBox v2 glass UI, inert Nikaido slot, Home/JIT/RAM+ preserved.")
