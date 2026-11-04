#!/usr/bin/env python3
"""GameBox v2 is new first-party UI; retired launcher machinery stays absent."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "LiveContainerSwiftUI/Views/BloomBox"
host = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
launcher = (ui / "BloomBoxLauncherRoot.swift").read_text()
reserved = (ui / "BloomBoxReservedSection.swift").read_text()
gamebox = (ui / "BloomBoxGameBoxV2Screen.swift").read_text()
prefs = (ui / "BloomBoxLauncherPreferences.swift").read_text()

# None of the removed GameBox 1 runtime/gate or removed assets may return.
for name in (
    "BloomBoxGameBoxScreen.swift", "BloomBoxGameBoxLayout.swift",
    "BloomBoxGameBoxLibrary.swift", "BloomBoxControllerInput.swift",
    "BloomBoxNavigationAudio.swift",
):
    assert not (ui / name).exists(), f"Retired console code returned: {name}"
assert not (root / "LiveContainerSwiftUI/Utilities/BloomBoxGameModeGate.swift").exists()
assert "BloomBoxRequestGameMode" not in launcher + host
assert "gameRoutePrompt" not in host and "gameGatePrompt" not in host

# New view is pure presentation: launch, approval, JIT and signing stay in host.
assert 'value: "gamebox"' in launcher
assert 'value: "ios"' in launcher
assert 'liveBoardMode == "gamebox"' in host
assert "BloomBoxGameBoxV2Screen(" in host
assert "launchFromLiveBoard(app, forceJIT: true)" in host
assert 'liveBoardMode == "ios" || liveBoardMode == "gamebox"' in host
assert "BloomBoxReservedSection(backToHome:" in host
assert "BloomBoxOrientationLock(mask: .landscape)" in gamebox
assert "gameIcon(app, size:" in gamebox and "Image(uiImage: image)" in gamebox
assert "LCAppModel" not in gamebox and "LCUtils" not in gamebox
assert "BloomBoxGameBoxEntry(" in host
assert "BloomBoxArtworkLibrary" in gamebox
assert "LazyHStack" in gamebox and "ScrollViewReader" in gamebox
assert "UISelectionFeedbackGenerator().selectionChanged()" in gamebox
assert "TapGesture(count: 2)" in gamebox
assert "BloomBoxGameBoxV2Favorites" in gamebox
assert "confirmationDialog" in gamebox and "upcomingFeature" in gamebox
assert "ProcessInfo.processInfo" in gamebox
assert "func launchFromLibrary" not in gamebox
assert "func approveEmulatorLaunch" not in gamebox
assert "LCUtils.openSideStore" not in gamebox
assert "GameBox" not in reserved
assert "BloomBoxRAMPlusView" in host and "LiveBoardJITSetup" in host
assert "approveEmulatorLaunch" in host and "remoteGameProfiles" in host
assert "LiveBoardOrientation.beginGuest" in host and "landscapeGuest" in host
assert 'defaults.set("ios", forKey: sessionKey)' in prefs
print("PASS: First-party GameBox v2 UI uses existing guests/JIT with original GameBox 1 gone.")
