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
# Free scrolling and selection must stay independent. Do not restore the
# native snapping or ScrollViewReader that previously bounced to app zero.
assert "carousel(iconSize: iconSize)" in gamebox
assert "private func appIconItem(" in gamebox
assert "gameCard(" not in gamebox
assert ".scrollPosition(" not in gamebox
assert ".scrollTargetBehavior(" not in gamebox
assert "ScrollViewReader" not in gamebox
assert "scroll.scrollTo(" not in gamebox
assert "moveSelection(" not in gamebox
assert "let compact = safeHeight < 520" in gamebox
assert "handleIconTap(app)" in gamebox
assert "previousTapUptime" in gamebox
assert "now - previousTapUptime < 0.36" in gamebox
assert "exclusively(before: TapGesture" not in gamebox
assert "AudioServicesPlaySystemSound(1104)" in gamebox
assert "isCarouselDragging" in gamebox
assert "UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)" in gamebox
assert "Image(uiImage: image).resizable().scaledToFit()" in gamebox
assert '"bloombox.gamebox.icon."' in gamebox
assert "Text(title(app))" in gamebox  # details panel only
assert "BloomBoxNikaidoControllerSlot" in gamebox
lookup = (ui / "BloomBoxGameBoxArtworkLookup.swift").read_text()
# Only the selected title is looked up; never send guest filesystem
# metadata or embedded credentials to public artwork services.
assert "SteamSearch" in lookup and "WikipediaResponse" in lookup
assert "store.steampowered.com/api/storesearch/" in lookup
assert "pilicense" in lookup and 'value: "free"' in lookup
assert "normalize($0.name) == normalize(title)" in lookup
assert 'if term.count >= 6 && name.hasPrefix(term + " ")' in lookup
assert '("melonnx", "Nintendo Switch")' in lookup
assert '("delta", "Nintendo DS")' in lookup
assert "download(for: request)" in lookup
assert "permittedHosts.contains(finalHost)" in lookup
assert '["image/jpeg", "image/png", "image/webp"]' in lookup
assert "20 * 1024 * 1024" not in lookup
# Only the native host may disclose a guest's exact bundle identity
# to the wallpaper resolver; the remote data has no executable authority.
bridge = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
resolver = (ui / "BloomBoxRemoteWallpaperRules.swift").read_text()
schema = (root / "LiveContainerSwiftUI/Utilities/BloomBoxWallpaperRuleSchema.swift").read_text()
assert "bundleID: app.bundleIdentifier" in bridge
assert "let bundleID: String?" in gamebox
assert "wallpaperRules.rule(bundleID: app.bundleID, name: app.name)" in gamebox
assert "BloomBoxGameBoxArtworkLookup.find(app.name, rule: rule)" in gamebox
assert "wallpaperRules.refreshIfNeeded()" in gamebox
assert "String(wallpaperRules.revision)" in gamebox
assert 'index?.rule(bundleID: bundleID, name: name)' in resolver
assert 'feature/gamebox-wallpaper-keywords-20261105/catalog/gamebox-wallpaper-rules.json' in resolver
assert 'BloomBoxWallpaperRuleIndex.validated(from: data)' in resolver
assert '"schemaVersion", "catalogID", "updatedAt", "rules"' in schema
assert '"provider", "query", "note"' in schema
assert 'Set(words).count == words.count' in schema
assert 'if let bundleID, let exact = rules.first' in schema
assert 'Self.matchesAlias($0, normalizedName: normalized)' in schema
assert 'normalizedName.hasPrefix(word + " ")' in schema
assert 'allowedSuffixes' in schema
assert "BloomBoxGameBoxAutoBackgrounds" in gamebox
# Curated direct-link images are strictly allowlisted and override fuzzy
# console search. Husk is Android emulation, never Minecraft Dungeons.
assert "let imageURL: String?" in schema
assert "let sourceURL: String?" in schema
assert "let imageLicense: String?" in schema
assert "image.host == \"upload.wikimedia.org\"" in schema
assert "origin.host == \"commons.wikimedia.org\"" in schema
assert 'imageLicense == "Public domain"' in schema
assert "image.lastPathComponent == String(origin.lastPathComponent.dropFirst(5))" in schema
assert "vettedArtworkURL" in lookup
assert "Curated Wikimedia Commons" in lookup
assert "gamebox.wallpaper.curated_image.unavailable" in lookup
assert "if full == \"husk\"" not in lookup
assert '"husk"' in lookup
assert '":" + ($0.imageURL ?? "")' in gamebox

assert 'private let autoBackgroundMode = "autoGameBox"' in gamebox
assert "artwork.image(for: key(app), kind: .background) ??" in gamebox
assert "artwork.image(for: key(app), kind: .cover) ??" in gamebox
assert "autoBackgrounds ? artwork.image(" in gamebox
assert "Task.sleep(nanoseconds: 650_000_000)" in gamebox
assert "24 * 60 * 60" in gamebox
assert "Ver origen y atribución" in gamebox
assert "Buscar fondo en Internet" in gamebox
assert "Quitar fondo descargado" in gamebox
assert "mode: autoBackgroundMode" in gamebox
# Background must render regardless of Low Power Mode (constrained only
# reduces blur/motion). A prior request cannot starve the next selection.
assert "if let app = selectedApp, let image = backdrop(app)" in gamebox
assert "if !constrained, let app = selectedApp" not in gamebox
assert "guard autoBackgrounds, !safeGraphics,\n              let app = selectedApp" in gamebox
assert "guard autoBackgrounds, !safeGraphics, !constrained" not in gamebox
assert "fetchingAutoBackground != id" in gamebox
assert "if fetchingAutoBackground == id { fetchingAutoBackground = nil }" in gamebox
assert "BloomBoxGameBoxArtworkLastAttemptRule-v2:" in gamebox
assert 'wallpaperLookupStatus[id] = "Fondo listo"' in gamebox
assert 'wallpaperLookupStatus[id] = "Sin resultado · reintentar"' in gamebox
assert "Text(wallpaperStatusText(for: app))" in gamebox
assert ".animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: artwork.revision)" in gamebox
# Copyright-conscious fallback: Wikimedia Commons must match the selected
# emulator's platform topic, not any game's unrelated artwork.
assert "private static func commonsConsoleArtwork(for platform: String)" in lookup
assert 'URLComponents(string: "https://commons.wikimedia.org/w/api.php")' in lookup
assert 'URLQueryItem(name: "gsrnamespace", value: "6")' in lookup
assert 'URLQueryItem(name: "iiprop", value: "url|mime|size")' in lookup
assert "name.contains(platformName)" in lookup
assert "source.host == \"commons.wikimedia.org\"" in lookup
assert "return await commonsConsoleArtwork(for: article)" in lookup

# GameBox wallpaper lookup gets a bounded mini startup window; animated
# icons never touch the carousel's selection or guest launch paths.
intro = (ui / "BloomBoxGameBoxArtworkIntro.swift").read_text()
assert "BloomBoxGameBoxArtworkIntro(" in gamebox
assert '"BloomBoxGameBoxArtworkIntroEnabled"' in gamebox
assert "private var artworkIntroEnabled = true" in gamebox
assert "beginArtworkIntroIfNeeded()" in gamebox
assert "finishArtworkIntroAfterLookup()" in gamebox
assert "Task.sleep(nanoseconds: 6_000_000_000)" in gamebox
assert "Task.sleep(nanoseconds: UInt64((1.15 - elapsed) * 1_000_000_000))" in gamebox
assert "guard wallpaperCatalogReady else { return }" in gamebox
assert "await wallpaperRules.refreshIfNeeded()" in gamebox
assert "Button(\"Reactivar fondos de GameBox\"" in gamebox
assert ".alert(\"Fondos desactivados por seguridad\"" in gamebox
assert "safeGraphics = false" in gamebox
assert "resumeSafeGraphicsAndLoadArt()" in gamebox
assert "private var artworkIntroTimeoutID: String" in gamebox
assert ".task(id: artworkIntroTimeoutID)" in gamebox
assert '"gamebox.safe_graphics.user_resumed"' in gamebox
assert "onSkip" in intro and "onEnableGraphics" in intro
assert "Bloombox" not in intro  # use GAMEBOX branding
assert "repeatForever(autoreverses: true)" in intro
assert ".delay(Double(slot) * 0.13)" in intro
assert "ProgressView()" in intro
assert "Modo seguro: fondos pausados" in intro
assert "bloombox.gamebox.wallpaper-intro" in intro
assert "Image(uiImage: waveIcons[slot])" in intro
assert "scrollPosition(" not in intro and "moveSelection(" not in intro


# Glass refinement must keep the icon carousel untouched while reducing
# only the panel height and visual density of background surfaces.
assert ".frame(height: compact ? 100 : 120)" in gamebox
assert ".opacity(0.42)" in gamebox  # detail sheet material
assert ".opacity(0.36)" in gamebox  # status capsule material
assert ".opacity(0.38)" in gamebox  # circular header material
assert ".frame(width: 38, height: 38)" in gamebox
assert "carousel(iconSize: iconSize)" in gamebox
assert ".scrollPosition(" not in gamebox
assert ".scrollTargetBehavior(" not in gamebox
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
