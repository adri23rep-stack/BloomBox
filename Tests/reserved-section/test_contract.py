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
assert "@available(iOS 16.0, *)" in gamebox
assert "if #available(iOS 16.0, *)" in host
assert "if #available(iOS 16.0, *)" in launcher
assert "launchFromLiveBoard(app, forceJIT: true)" in host
assert 'liveBoardMode == "ios" || liveBoardMode == "gamebox"' in host
assert "BloomBoxReservedSection(backToHome:" in host
assert "BloomBoxOrientationLock(mask: .landscape)" in gamebox
assert "gameIcon(app, size:" in gamebox and "Image(uiImage: image)" in gamebox
assert "LCAppModel" not in gamebox and "LCUtils" not in gamebox
assert "BloomBoxGameBoxEntry(" in host
# Crash recovery never mounts the complex GameBox view on an unfinished previous
# session; there is always a usable exit and launch path.
safe = (ui / "BloomBoxGameBoxSafeScreen.swift").read_text()
policy = (root / "LiveContainerSwiftUI/Utilities/BloomBoxGameBoxRecoveryPolicy.swift").read_text()
assert "BloomBoxGameBoxRecoveryPolicy.recoverPreviousSession(" in launcher
assert "BloomBoxGameBoxRecoveryPolicy.begin(" in launcher
assert "BloomBoxGameBoxSafeScreen(" in host
assert "if gameBoxSafeMode {" in host
assert "retryFull:" in host
assert "gameBoxSafeMode = false" in host
assert "guard !gameBoxSafeMode else { return }" in host
assert "icon: nil," in host
assert "gameBoxDisplayEntries[index] = entry" in host
assert "BloomBoxGameBoxRecoveryPolicy.noteIcon(id," in host
assert "BloomBoxGameBoxRecoveryPolicy.shouldSkipIcon(id," in host
assert "private func prepareGameBox() async" in host
assert "BloomBoxGameBoxRecoveryPolicy.useFullUI" in host
assert "BloomBoxGameBoxRecoveryPolicy.close(" in host
assert "static func recoverPreviousSession(defaults:" in policy
assert "BloomBoxGameBoxRecoveryPolicy.shouldSkipIcon" in host
assert "BloomBoxOrientationLock" not in safe
assert "BloomBoxAnimatedWallpaper" not in safe
assert "ScrollView" in safe and "LazyVGrid" in safe
assert "launchWithJIT(app.id)" in safe
assert "launch(app.id)" in safe

# On-entry view construction does not decode every guest icon repeatedly;
# loading happens once after the host's first scene/layout transition.
assert "@State private var gameBoxDisplayEntries:" in host
assert "await Task.yield()" in host
assert "private func prepareGameBox() async" in host
assert "gameBoxDisplayEntries = prepared" in host
assert "gameBoxReady = true" in host
assert "if #available(iOS 16.0, *), gameBoxReady" in host
assert ".task(id: liveBoardMode + (gameBoxSafeMode ? \"-safe\" : \"-full\"))" in host
assert "UIGraphicsImageRenderer(size: size" in host
assert "BloomBoxArtworkLibrary" in gamebox
assert "LazyHStack" in gamebox and "ScrollViewReader" in gamebox
assert "UISelectionFeedbackGenerator().selectionChanged()" in gamebox
assert "TapGesture(count: 2)" in gamebox
# JIT badges use the effective policy, not a static isJITNeeded flag.
assert "BloomBoxJITGuestPolicy.wantsJIT(" in host
assert "requiresJIT: jitEnabled" in host
assert '"bolt.fill"' in gamebox
# Native iOS 17 snapping owns the gesture; the old competing swipe hook is gone.
assert ".scrollTargetBehavior(.viewAligned)" in gamebox
assert ".scrollPosition(id: $focusedKey, anchor: .center)" not in gamebox
assert ".onScrollGeometryChange(for: Int.self" in gamebox
assert ".onScrollPhaseChange" in gamebox
assert "requestedScrollKey = next" in gamebox
assert "withTransaction(transaction) { focusedKey = key }" in gamebox
assert ".simultaneousGesture(DragGesture" not in gamebox
# Cover images and default app icons fit, instead of cropping tall cards.
assert "if let customCover = cover(app)" in gamebox
assert "Image(uiImage: customCover).resizable().scaledToFit()" in gamebox
assert "Image(uiImage: image).resizable().scaledToFit()" in gamebox
# GameBox owns an independent, persistent wallpaper mode with all three media.
assert '"BloomBoxGameBoxV2WallpaperMode"' in gamebox
assert '"BloomBoxGameBoxV2MotionWallpaper"' in gamebox
assert "BloomBoxAnimatedWallpaper(url: url" in gamebox
assert "BloomBoxMotionWallpaperPhotosPicker" in gamebox
assert ".fileImporter(isPresented: $wallpaperFilesPresented" in gamebox
assert 'backgroundMode = "photo"' in gamebox
assert 'backgroundMode = "motion"' in gamebox
assert "backgroundMode = \"auto\"" in gamebox
assert "CGImageSourceCreateThumbnailAtIndex" in gamebox
assert "artworkIsActive = true" in gamebox
assert "guard artworkIsActive else { return nil }" in gamebox
assert '"BloomBoxGameBoxV2OpenStage"' in gamebox
assert "BloomBoxGameBoxRecoveryPolicy.checkpoint" in host
assert "let columns: CGFloat = viewportWidth >= 650 ? 5" in gamebox
assert "geometry.size.width.isFinite && geometry.size.width > 0" in gamebox
assert "geometry.size.height.isFinite && geometry.size.height > 0" in gamebox
assert "guard step.isFinite, offset.isFinite else { return 0 }" in gamebox
assert "guard rawIndex.isFinite else { return 0 }" in gamebox
assert "return Int(min(max(0, rawIndex), upper))" in gamebox
assert "let cardWidth = (viewportWidth - (columns - 1) * 17) / columns" in gamebox
assert "viewportWidth: viewportWidth" in gamebox
assert ".padding(.top, compact ? 23 : 29)" in gamebox
assert "private enum ImportedWallpaperFile: Sendable" in gamebox
assert "Task.detached(priority: .userInitiated)" in gamebox
assert "let size = (try? url.resourceValues(forKeys:" in gamebox
assert "BloomBoxMotionMedia.importFile(url)" in gamebox
assert "BloomBoxMotionMedia.remove(motionWallpaperName)" in gamebox
assert "let old = motionWallpaperName" in gamebox
assert "if !old.isEmpty && old != filename { BloomBoxMotionMedia.remove(old) }" in gamebox
assert "BloomBoxGameBoxV2Favorites" in gamebox
assert ".photosPicker(isPresented:" in gamebox
assert "try artwork.save(UIImage(cgImage: image), for: key, kind: kind)" in gamebox
assert "artwork.remove(for: key(app), kind: .cover)" in gamebox
assert '"Elegir carátula"' in gamebox and '"Elegir fondo"' in gamebox
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
