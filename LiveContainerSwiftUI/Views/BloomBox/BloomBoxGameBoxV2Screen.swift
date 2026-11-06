// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack. Original BloomBox console presentation.
//
// GameBox v2 is UI only: the host retains ownership of launch/JIT,
// orientation, signing, app settings and guest containers.
import SwiftUI
import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import AudioToolbox
import GameController

/// Portable UI item. Only the existing host adapts installed guest metadata.
struct BloomBoxGameBoxEntry: Identifiable {
    let id: String
    let bundleID: String?
    let name: String
    let icon: UIImage?
    let requiresJIT: Bool
}


/// The original controller-shaped reservation now opens Nikaido's native
/// GameController panel. The integration does not change launch/JIT ownership.
@available(iOS 16.0, *)
private struct BloomBoxNikaidoControllerSlot: View {
    let diameter: CGFloat
    let action: () -> Void
    var batteryPercent: Int? = nil

    var body: some View {
        Button(action: action) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: diameter * 0.39, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background {
                    Circle().fill(.ultraThinMaterial).opacity(0.38)
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if let batteryPercent {
                Text("\(batteryPercent)%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(batteryPercent < 20 ? .orange : .white)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.86), in: Capsule())
                    .offset(x: 9, y: 5)
            }
        }
        .overlay {
            if let batteryPercent {
                Circle()
                    .trim(from: 0, to: CGFloat(batteryPercent) / 100)
                    .stroke(batteryPercent < 20 ? Color.orange : Color.mint,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter + 3, height: diameter + 3)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(BloomBoxGameBoxL10n.t("Nikaido · Ajustes del control") +
                            (batteryPercent.map { BloomBoxGameBoxL10n.t(", batería ") + String($0) + "%" } ?? ""))
        .accessibilityHint("Luces, gatillos adaptativos y perfiles por juego")
    }
}

@available(iOS 16.0, *)
struct BloomBoxGameBoxV2Screen: View {
    let entries: [BloomBoxGameBoxEntry]
    let launch: (String) -> Void
    let launchWithJIT: (String) -> Void
    let manage: (String) -> Void
    let backToHome: () -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    let openInstall: () -> Void

    @StateObject private var artwork = BloomBoxArtworkLibrary()
    @ObservedObject private var wallpaperRules = BloomBoxRemoteWallpaperRules.shared
    @AppStorage("BloomBoxGameBoxAutoBackgrounds", store: LiveContainerPreferencesAdapter.defaults)
    private var autoBackgrounds = true
    @State private var fetchingAutoBackground: String?
    @State private var wallpaperLookupStatus: [String: String] = [:]
    private let autoBackgroundMode = "autoGameBox"
    @AppStorage("BloomBoxGameBoxArtworkIntroEnabled", store: LiveContainerPreferencesAdapter.defaults)
    private var artworkIntroEnabled = true
    @State private var artworkIntroVisible = false
    @State private var artworkIntroDidRun = false
    @State private var artworkIntroStartedAt: Date?
    @State private var artworkIntroAppKey: String?
    @State private var wallpaperCatalogReady = false
    @State private var showSafeGraphicsAlert = false
    @AppStorage("BloomBoxGameBoxV2Favorites", store: LiveContainerPreferencesAdapter.defaults)
    private var favoritesJSON = "[]"
    @AppStorage("LiveBoardReduceMotion", store: LiveContainerPreferencesAdapter.defaults)
    private var localReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var focusedKey: String?
    @GestureState private var isCarouselDragging = false
    @State private var previousTapKey: String?
    @State private var previousTapUptime: TimeInterval = 0
    @State private var alphabetical = false
    @State private var quickMenu = false
    @State private var showNikaidoPanel = false
    @State private var showProfileSwitcher = false
    @AppStorage(BloomBoxProfileStore.activeKey, store: LiveContainerPreferencesAdapter.defaults)
    private var activeProfileID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey, store: LiveContainerPreferencesAdapter.defaults)
    private var storedProfiles = Data()
    @State private var dualSenseBatteryPercent: Int?
    @State private var showDiagnostics = false
    @State private var showExpiryReminders = false
    @State private var freeStorage: String?
    @AppStorage("BloomBoxGameBoxSafeGraphics", store: LiveContainerPreferencesAdapter.defaults)
    private var safeGraphics = false
    @State private var upcomingFeature: String?
    @State private var constrained = false
    @State private var batteryPercent: Int?
    @State private var photoPickerPresented = false
    @State private var filesPickerPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var artworkTargetKey: String?
    @State private var artworkTargetKind: BloomBoxArtworkLibrary.Kind = .cover
    @State private var importingArtwork = false
    @State private var launchPending = false
    @State private var artworkError: String?

    private var reduceMotion: Bool { systemReduceMotion || localReduceMotion || constrained }
    private var gameBoxProfiles: [BloomBoxUserProfile] {
        guard let saved = try? JSONDecoder().decode([BloomBoxUserProfile].self, from: storedProfiles),
              !saved.isEmpty else { return [.initial] }
        return saved.contains(where: { $0.id == BloomBoxUserProfile.primaryID })
            ? saved : [.initial] + saved
    }
    private var currentProfile: BloomBoxUserProfile {
        gameBoxProfiles.first(where: { $0.id == activeProfileID }) ?? gameBoxProfiles[0]
    }
    private var autoBackgroundTaskID: String {
        (focusedKey ?? "") + ":" + String(autoBackgrounds) + ":" +
        String(safeGraphics) + ":" + String(constrained) + ":" +
        String(wallpaperRules.revision) + ":" + String(wallpaperCatalogReady)
    }
    private var artworkIntroTimeoutID: String {
        String(artworkIntroVisible) + ":" + String(safeGraphics)
    }
    private var favorites: Set<String> {
        Set(BloomBoxHomeAppPolicy.favorites(from: favoritesJSON))
    }
    private func key(_ app: BloomBoxGameBoxEntry) -> String { app.id }
    private func title(_ app: BloomBoxGameBoxEntry) -> String { app.name }

    private var visibleApps: [BloomBoxGameBoxEntry] {
        let indexed = Array(entries.enumerated())
        return indexed.sorted { lhs, rhs in
            let favoriteL = favorites.contains(key(lhs.element))
            let favoriteR = favorites.contains(key(rhs.element))
            if favoriteL != favoriteR { return favoriteL }
            if alphabetical {
                let compare = title(lhs.element).localizedStandardCompare(title(rhs.element))
                if compare != .orderedSame { return compare == .orderedAscending }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
    private var selectedApp: BloomBoxGameBoxEntry? {
        visibleApps.first(where: { key($0) == focusedKey }) ?? visibleApps.first
    }
    private var focusedAccent: Color {
        guard let app = selectedApp else { return Color(red: 0.42, green: 0.79, blue: 0.98) }
        return accent(for: app)
    }
    private func accent(for app: BloomBoxGameBoxEntry) -> Color {
        let colors: [Color] = [
            Color(red: 0.44, green: 0.81, blue: 0.99),
            Color(red: 0.99, green: 0.67, blue: 0.40),
            Color(red: 0.82, green: 0.61, blue: 0.99),
            Color(red: 0.48, green: 0.91, blue: 0.78),
            Color(red: 0.99, green: 0.54, blue: 0.69)
        ]
        let seed = key(app).utf8.reduce(0) { (($0 &* 31) &+ Int($1)) & 0x7fffffff }
        return colors[seed % colors.count]
    }
    private func cover(_ app: BloomBoxGameBoxEntry) -> UIImage? {
        guard !safeGraphics else { return nil }
        return artwork.image(for: key(app), kind: .cover)
    }
    private func backdrop(_ app: BloomBoxGameBoxEntry) -> UIImage? {
        guard !safeGraphics else { return nil }
        // Explicit edits always outrank downloads; auto artwork is a separate
        // cache mode and can never replace user-selected artwork.
        return artwork.image(for: key(app), kind: .background) ??
        artwork.image(for: key(app), kind: .cover) ??
        (autoBackgrounds ? artwork.image(for: key(app), kind: .background,
                                        mode: autoBackgroundMode) : nil) ??
        app.icon
    }

    var body: some View {
        GeometryReader { geometry in
            // Geometry may briefly be zero during LiveProcess orientation changes.
            let safeWidth = geometry.size.width.isFinite && geometry.size.width > 0 ? geometry.size.width : 844
            let safeHeight = geometry.size.height.isFinite && geometry.size.height > 0 ? geometry.size.height : 390
            // iPhone landscape can report 375-450 points after safe areas.
            // Its original noncompact sizes exceeded the available height.
            let compact = safeHeight < 520
            // Real app icons, no card shells. Size is bounded by screen height
            // and width, so icons remain whole on iPhone landscape and iPad.
            let iconSize = min(max(safeHeight * 0.41, 110), min(safeWidth * 0.18, 174))
            ZStack {
                consoleBackground
                VStack(spacing: compact ? 7 : 15) {
                    header(compact: compact)
                        .frame(height: compact ? 42 : 55)
                        .padding(.horizontal, compact ? 12 : 25)
                    Spacer(minLength: 0)
                    if visibleApps.isEmpty {
                        emptyLibrary
                            .frame(height: iconSize + 28)
                    } else {
                        carousel(iconSize: iconSize)
                            .frame(height: iconSize + 28)
                    }
                    detailPanel(compact: compact)
                        // Slimmer by ~11%, preserving room for the title and controls.
                        .frame(height: compact ? 100 : 120)
                        .padding(.horizontal, compact ? 12 : 25)
                }
                .padding(.vertical, compact ? 3 : 12)
                if showProfileSwitcher {
                    gameBoxProfilePicker(width: safeWidth, height: safeHeight)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(30)
                }
                if artworkIntroVisible {
                    BloomBoxGameBoxArtworkIntro(
                        icons: Array(visibleApps.prefix(5).compactMap(\.icon)),
                        reduceMotion: reduceMotion,
                        safeMode: safeGraphics,
                        onSkip: { dismissArtworkIntro() },
                        onEnableGraphics: { resumeSafeGraphicsAndLoadArt() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
                }
            }
            .frame(width: safeWidth, height: safeHeight)
        }
        .background(Color.black.ignoresSafeArea())
        .background(BloomBoxOrientationLock(mask: .landscape).frame(width: 0, height: 0))
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $photoPickerPresented, selection: $selectedPhoto, matching: .images)
        .fileImporter(isPresented: $filesPickerPresented, allowedContentTypes: [.image]) { result in
            guard let target = artworkTargetKey else { return }
            let kind = artworkTargetKind
            artworkTargetKey = nil
            do {
                try importArtworkFile(result.get(), for: target, kind: kind)
            } catch {
                artworkError = error.localizedDescription
                BloomBoxCrashJournal.shared.record("gamebox.artwork.files.failed")
            }
        }
        .onChange(of: selectedPhoto) { photo in
            guard let photo, let target = artworkTargetKey else { return }
            let kind = artworkTargetKind
            importingArtwork = true
            Task { @MainActor in
                defer {
                    importingArtwork = false
                    selectedPhoto = nil
                    artworkTargetKey = nil
                }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try artwork.save(try decodeArtwork(data), for: target, kind: kind)
                    BloomBoxCrashJournal.shared.record("gamebox.artwork.import.success")
                } catch {
                    BloomBoxCrashJournal.shared.record("gamebox.artwork.import.failed")
                    artworkError = error.localizedDescription
                }
            }
        }
        .overlay {
            if importingArtwork {
                ProgressView("Importando imagen…")
                    .padding(18)
                    .background(.black.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("No se pudo importar la imagen", isPresented: Binding(
            get: { artworkError != nil },
            set: { if !$0 { artworkError = nil } }
        )) {
            Button("Entendido", role: .cancel) { artworkError = nil }
        } message: {
            Text(artworkError ?? "")
        }
        .onAppear {
            BloomBoxCrashJournal.shared.enterGameBox()
            refreshDualSenseBattery()
            if focusedKey == nil { focusedKey = visibleApps.first.map(key) }
            refreshSystemBudget()
            refreshStorage()
            UIDevice.current.isBatteryMonitoringEnabled = true
            refreshBattery()
            beginArtworkIntroIfNeeded()
        }
        .onDisappear {
            BloomBoxCrashJournal.shared.leaveGameBox()
            artworkIntroVisible = false
            artworkIntroDidRun = false
            wallpaperCatalogReady = false
            showProfileSwitcher = false
        }
        // The catalog refresh is independent of icon swiping. Resolve the
        // selected game's wallpaper only after we have validated the rules
        // (or retained the verified offline cache).
        .task {
            await wallpaperRules.refreshIfNeeded()
            guard !Task.isCancelled else { return }
            wallpaperCatalogReady = true
        }
        .task(id: autoBackgroundTaskID) {
            guard wallpaperCatalogReady else { return }
            await resolveAutomaticBackground()
            if let selectedApp, key(selectedApp) == artworkIntroAppKey {
                await finishArtworkIntroAfterLookup()
            }
        }
        .task(id: artworkIntroTimeoutID) {
            guard artworkIntroVisible else { return }
            // The internet can be down; never keep the GameBox UI covered
            // indefinitely. The normal lookup continues behind this view.
            do { try await Task.sleep(nanoseconds: 6_000_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            dismissArtworkIntro()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            BloomBoxCrashJournal.shared.returnedToForeground(gameBoxVisible: true)
            refreshBattery()
            refreshStorage()
        }
        .sheet(isPresented: $showExpiryReminders) {
            NavigationView {
                if #available(iOS 16.2, *) {
                    BloomBoxExpiryReminderSettings()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Listo") { showExpiryReminders = false }
                            }
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash").font(.largeTitle)
                        Text("Los avisos de caducidad requieren iOS 16.2 o posterior.")
                            .multilineTextAlignment(.center)
                        Button("Cerrar") { showExpiryReminders = false }
                    }
                    .padding()
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationView {
                BloomBoxDiagnosticsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { showDiagnostics = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        .onChange(of: entries.map(key)) { keys in
            if let focusedKey, !keys.contains(focusedKey) {
                self.focusedKey = visibleApps.first.map(key)
            } else if self.focusedKey == nil {
                self.focusedKey = visibleApps.first.map(key)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            BloomBoxCrashJournal.shared.record("gamebox.memory_warning.graphics_safed")
            safeGraphics = true
            dismissArtworkIntro()
            artwork.clearDecodedCache()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            refreshSystemBudget()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            refreshSystemBudget()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            refreshBattery()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            refreshDualSenseBattery()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in
            refreshDualSenseBattery()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refreshDualSenseBattery()
        }
        .sheet(isPresented: $showNikaidoPanel) {
            BloomBoxNikaidoControllerView(
                gameID: selectedApp?.bundleID ?? selectedApp?.id ?? "gamebox",
                gameName: selectedApp?.name ?? "GameBox"
            )
        }
        .confirmationDialog("GameBox", isPresented: $quickMenu) {
            if safeGraphics {
                Button("Reactivar fondos de GameBox", systemImage: "photo") {
                    showSafeGraphicsAlert = true
                }
            }
            Button(BloomBoxGameBoxL10n.t(artworkIntroEnabled ? "Desactivar animación de carga" : "Activar animación de carga"),
                   systemImage: "waveform") {
                artworkIntroEnabled.toggle()
            }
            Button("Actualizar catálogo de fondos", systemImage: "arrow.clockwise") {
                Task {
                    await wallpaperRules.refreshIfNeeded(force: true)
                    await resolveAutomaticBackground(force: true)
                }
            }
            Button("Diagnósticos y recuperación") { showDiagnostics = true }
            Button("Administrar aplicaciones", action: openManagement)
            Button("Instalar IPA", action: openInstall)
            Button("Cambiar interfaz", action: openInterface)
            Button("Volver al escritorio", action: backToHome)
        }
        .alert("Fondos desactivados por seguridad", isPresented: $showSafeGraphicsAlert) {
            Button("Activar fondos") { resumeSafeGraphicsAndLoadArt() }
            Button("Mantener modo seguro", role: .cancel) {}
        } message: {
            Text("GameBox activó SAFE tras una sesión interrumpida o una alerta de memoria. Puedes reactivar los fondos; si vuelve a cerrarse, revisa Diagnósticos.")
        }
        .alert("Función futura", isPresented: Binding(
            get: { upcomingFeature != nil },
            set: { if !$0 { upcomingFeature = nil } }
        )) {
            Button("Entendido", role: .cancel) { upcomingFeature = nil }
        } message: {
            Text(BloomBoxGameBoxL10n.t(upcomingFeature ?? ""))
        }
        .accessibilityIdentifier("bloombox.gamebox.v2")
    }

    private func gameBoxProfilePicker(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.49)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showProfileSwitcher = false
                    }
                }
                .accessibilityLabel("Cerrar selector de perfiles")

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundStyle(BloomBoxWizardPalette.color(currentProfile.accentHex))
                    Text(BloomBoxGameBoxL10n.t("Cambiar perfil"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showProfileSwitcher = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(BloomBoxGameBoxL10n.t("Cerrar"))
                }
                .padding(.horizontal, 5)

                // The exact same widget as in News: switch, add, edit and
                // safely remove profiles through its management view.
                BloomBoxProfileSwitcherWidget(onProfileSelected: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                        showProfileSwitcher = false
                    }
                })
            }
            .padding(14)
            .frame(width: min(max(240, width - 30), 420))
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 29, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.33), radius: 24, y: 12)
            .frame(maxHeight: height - 8)
        }
        .frame(width: width, height: height)
        .accessibilityIdentifier("bloombox.gamebox.profiles.popup")
    }

    private var consoleBackground: some View {
        ZStack {
            LinearGradient(
                colors: [.black, focusedAccent.opacity(0.42), Color(red: 0.05, green: 0.07, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Low Power Mode only softens animation. It must not hide cached
            // wallpapers or prohibit user-enabled automatic backgrounds.
            if let app = selectedApp, let image = backdrop(app) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: constrained ? 4 : 17)
                        .opacity(constrained ? 0.56 : 0.74)
                }
                .allowsHitTesting(false)
            }
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0.06), .black.opacity(0.64)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: focusedKey)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: artwork.revision)
        .accessibilityHidden(true)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 9) {
            topButton("ellipsis", label: "Menú") { quickMenu = true }
            // Native DualSense panel; guest input remains unchanged.
            BloomBoxNikaidoControllerSlot(diameter: 39, batteryPercent: dualSenseBatteryPercent) { showNikaidoPanel = true }
            topButton("arrow.up.arrow.down", label: "Ordenar") {
                alphabetical.toggle()
                selectionHaptic()
            }
            Spacer(minLength: 4)
            HStack(spacing: compact ? 5 : 8) {
                // The avatar, controller logo and username are one
                // discoverable profile control. The separate DualSense
                // button on the left keeps its Nikaido actions.
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
                        showProfileSwitcher.toggle()
                    }
                    selectionHaptic()
                } label: {
                    HStack(spacing: compact ? 4 : 7) {
                        BloomBoxProfileAvatar(profile: currentProfile,
                                              size: compact ? 25 : 30)
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: compact ? 12 : 16, weight: .semibold))
                        Text("GAMEBOX")
                            .font(.system(size: compact ? 12 : 15, weight: .black, design: .rounded))
                            .tracking(compact ? 0.6 : 1.2)
                        Text(currentProfile.name)
                            .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: compact ? 83 : 145, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(BloomBoxGameBoxL10n.t("Cambiar perfil") + ": " + currentProfile.name)
                .accessibilityIdentifier("bloombox.gamebox.profiles.open")
                Button {
                    if safeGraphics { showSafeGraphicsAlert = true }
                } label: {
                    Text(safeGraphics ? "SAFE" : "V2")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(focusedAccent.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(BloomBoxGameBoxL10n.t(safeGraphics ? "Modo seguro; toca para activar fondos" : "Versión 2"))
                TimelineView(.periodic(from: .now, by: 60)) { time in
                    Text(time.date, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                if let batteryPercent {
                    Image(systemName: batteryPercent >= 85 ? "battery.100" :
                          batteryPercent >= 60 ? "battery.75" :
                          batteryPercent >= 35 ? "battery.50" :
                          batteryPercent >= 12 ? "battery.25" : "battery.0")
                        .font(.system(size: 12))
                    Text(String(batteryPercent) + "%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                if let freeStorage, !compact {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                    Text(freeStorage)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, compact ? 10 : 16)
            .frame(height: compact ? 36 : 46)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.36)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.8))
            Spacer(minLength: 4)
            topButton("bell.fill", label: "Avisos de caducidad") {
                showExpiryReminders = true
            }
            topButton("music.note", label: "Música") {
                upcomingFeature = "El reproductor de música y ecualizador aún no están disponibles en GameBox. Se integrarán sin interferir con la apertura de juegos."
            }
            topButton("power", label: "Volver al escritorio", action: backToHome)
            topButton("gearshape.fill", label: "Ajustes", action: openInterface)
        }
    }

    private func topButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 39, height: 39)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.38)
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BloomBoxGameBoxL10n.t(label))
    }

    // The carousel owns only scrolling; selection belongs exclusively to
    // tapping an icon. Do not bind its offset to focusedKey, add snapping,
    // scrollTo, or change focusedKey during a drag.
    private func carousel(iconSize: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: 18) {
                ForEach(visibleApps, id: \.id) { app in
                    appIconItem(app, size: iconSize)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($isCarouselDragging) { _, dragging, _ in
                    dragging = true
                }
        )
        .onChange(of: isCarouselDragging) { dragging in
            guard dragging else { return }
            // One short tactile pulse per swipe, not one per pixel.
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
        .accessibilityIdentifier("bloombox.gamebox.free-scroll")
    }

    private func appIconItem(_ app: BloomBoxGameBoxEntry, size: CGFloat) -> some View {
        let selected = key(app) == focusedKey
        return ZStack(alignment: .topTrailing) {
            gameIcon(app, size: size)
                .overlay {
                    RoundedRectangle(cornerRadius: max(10, size * 0.23), style: .continuous)
                        .strokeBorder(selected ? .white.opacity(0.98) : .white.opacity(0.12),
                                      lineWidth: selected ? 3 : 1)
                }
                .shadow(color: selected ? accent(for: app).opacity(0.45) : .black.opacity(0.16),
                        radius: selected ? 14 : 4, y: 4)
                .scaleEffect(selected && !reduceMotion ? 1.045 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selected)

            if app.requiresJIT {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.black.opacity(0.78), in: Circle())
                    .offset(x: 5, y: -5)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) {
            if favorites.contains(key(app)) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.black.opacity(0.76), in: Circle())
                    .offset(x: -5, y: -5)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size + 16, height: size + 16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Select at first touch-up; do not wait for a second-tap timeout.
            handleIconTap(app)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title(app) + (favorites.contains(key(app)) ? BloomBoxGameBoxL10n.t(", favorito") : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Toca para seleccionar, dos veces para alternar favorito. Usa Play para abrir.")
        .accessibilityAction(named: Text("Alternar favorito")) { toggleFavorite(app) }
        .accessibilityIdentifier("bloombox.gamebox.icon." + key(app))
    }

    @ViewBuilder private func gameIcon(_ app: BloomBoxGameBoxEntry, size: CGFloat) -> some View {
        Group {
            if let image = app.icon {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ZStack {
                    Color.white.opacity(0.16)
                    Image(systemName: "app.dashed")
                        .resizable().scaledToFit()
                        .padding(size * 0.22)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.23), style: .continuous))
    }

    private func detailPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if let app = selectedApp {
                HStack(spacing: 10) {
                    gameIcon(app, size: compact ? 34 : 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title(app))
                            .font(.system(size: compact ? 17 : 23, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        HStack(spacing: 7) {
                            Text(BloomBoxGameBoxL10n.t(favorites.contains(key(app)) ? "★ Favorito" : "Listo para jugar"))
                            Text("•")
                            Text(BloomBoxGameBoxL10n.t(app.requiresJIT ? "JIT disponible" : "Lanzamiento normal"))
                            Text("•")
                            Text(BloomBoxGameBoxL10n.t(wallpaperStatusText(for: app)))
                        }
                        .font(.system(size: compact ? 9 : 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text("GAMEBOX V2")
                        .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.57))
                }
                HStack(spacing: compact ? 9 : 12) {
                    Button {
                        requestLaunch(app, forceJIT: false)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .rounded))
                            .frame(width: compact ? 145 : 195, height: compact ? 34 : 43)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(.white, in: Capsule())
                    .disabled(launchPending)
                    .accessibilityIdentifier("bloombox.gamebox.play")
                    Menu {
                        Button("Abrir con JIT", systemImage: "bolt.fill") {
                            requestLaunch(app, forceJIT: true)
                        }
                        Button(BloomBoxGameBoxL10n.t(favorites.contains(key(app)) ? "Quitar de favoritos" : "Añadir a favoritos"),
                               systemImage: "heart") { toggleFavorite(app) }
                        Button("Ajustes de esta app", systemImage: "gearshape") { manage(key(app)) }
                        Divider()
                        Button("Carátula desde Fotos", systemImage: "photo") {
                            chooseArtwork(for: app, kind: .cover)
                        }
                        Button("Fondo desde Fotos", systemImage: "photo.on.rectangle") {
                            chooseArtwork(for: app, kind: .background)
                        }
                        Button("Carátula desde Archivos", systemImage: "folder") {
                            chooseArtworkFromFiles(for: app, kind: .cover)
                        }
                        Button("Fondo desde Archivos", systemImage: "folder.fill") {
                            chooseArtworkFromFiles(for: app, kind: .background)
                        }
                        Divider()
                        Button(BloomBoxGameBoxL10n.t(autoBackgrounds ? "Desactivar fondos automáticos" : "Activar fondos automáticos"),
                               systemImage: autoBackgrounds ? "globe.americas.fill" : "globe") {
                            autoBackgrounds.toggle()
                        }
                        Button(BloomBoxGameBoxL10n.t(fetchingAutoBackground == key(app) ? "Buscando fondo…" : "Buscar fondo en Internet"),
                               systemImage: "magnifyingglass") {
                            Task {
                                await wallpaperRules.refreshIfNeeded(force: true)
                                await resolveAutomaticBackground(force: true)
                            }
                        }
                        .disabled(fetchingAutoBackground == key(app) || !autoBackgrounds)
                        if artwork.image(for: key(app), kind: .background,
                                         mode: autoBackgroundMode) != nil {
                            if let link = LiveContainerPreferencesAdapter.defaults.string(
                                forKey: "BloomBoxGameBoxArtworkSource:" + key(app)),
                               let sourceURL = URL(string: link), sourceURL.scheme == "https" {
                                Button("Ver origen y atribución", systemImage: "link") {
                                    UIApplication.shared.open(sourceURL)
                                }
                            }
                            Button(role: .destructive) {
                                artwork.remove(for: key(app), kind: .background,
                                               mode: autoBackgroundMode)
                                LiveContainerPreferencesAdapter.defaults.removeObject(
                                    forKey: "BloomBoxGameBoxArtworkSource:" + key(app))
                                LiveContainerPreferencesAdapter.defaults.removeObject(
                                    forKey: "BloomBoxGameBoxArtworkLastAttempt:" + key(app))
                            } label: {
                                Label("Quitar fondo descargado", systemImage: "trash")
                            }
                        }
                        if artwork.image(for: key(app), kind: .background) != nil {
                            Button(role: .destructive) {
                                artwork.remove(for: key(app), kind: .background)
                            } label: {
                                Label("Quitar fondo personalizado", systemImage: "rectangle.on.rectangle.slash")
                            }
                        }
                        if artwork.image(for: key(app), kind: .cover) != nil {
                            Button(role: .destructive) {
                                artwork.remove(for: key(app), kind: .cover)
                            } label: {
                                Label("Quitar carátula", systemImage: "trash")
                            }
                        }
                    } label: {
                        footerCircle("ellipsis", label: "Opciones del juego")
                    }
                    Spacer(minLength: 0)
                    // Nikaido native controller panel for the selected game.
                    BloomBoxNikaidoControllerSlot(diameter: compact ? 34 : 40) { showNikaidoPanel = true }
                    Button { manage(key(app)) } label: {
                        footerCircle("slider.horizontal.3", label: "Ajustes del juego")
                    }
                    .buttonStyle(.plain)
                    Button(action: openManagement) {
                        footerCircle("square.grid.2x2.fill", label: "Biblioteca")
                    }
                    .buttonStyle(.plain)
                    Button { toggleFavorite(app) } label: {
                        footerCircle(favorites.contains(key(app)) ? "star.fill" : "star",
                                     label: "Favorito")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.slash").font(.title2)
                    Text("Aún no hay juegos instalados")
                        .font(.headline)
                    Spacer()
                    Button("Instalar IPA", action: openInstall)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 6 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.42)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(.white.opacity(0.19), lineWidth: 0.8)
        }
    }

    private func footerCircle(_ symbol: String, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 38, height: 38)
            .foregroundStyle(.white)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.37)
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
            .accessibilityLabel(BloomBoxGameBoxL10n.t(label))
    }

    private var emptyLibrary: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(.white.opacity(0.75))
            Text("Tu biblioteca está vacía").font(.headline)
            Text("Instala una app para verla aquí con su icono.")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func handleIconTap(_ app: BloomBoxGameBoxEntry) {
        let id = key(app)
        let now = ProcessInfo.processInfo.systemUptime
        let isSecondTap = previousTapKey == id &&
            now - previousTapUptime > 0 && now - previousTapUptime < 0.36
        previousTapKey = isSecondTap ? nil : id
        previousTapUptime = isSecondTap ? 0 : now
        select(app)
        if isSecondTap { toggleFavorite(app) }
    }

    private func select(_ app: BloomBoxGameBoxEntry) {
        let next = key(app)
        guard focusedKey != next else { return }
        focusedKey = next
        BloomBoxCrashJournal.shared.record("gamebox.selection.changed")
        // Short, system-managed selection click. It respects device sound
        // settings and does not install a looping audio engine.
        AudioServicesPlaySystemSound(1104)
        selectionHaptic()
    }

    private func wallpaperStatusText(for app: BloomBoxGameBoxEntry) -> String {
        let id = key(app)
        if safeGraphics { return "Fondo: SAFE" }
        if artwork.image(for: id, kind: .background) != nil ||
            artwork.image(for: id, kind: .cover) != nil {
            return "Fondo personalizado"
        }
        if !autoBackgrounds { return "Fondo automático apagado" }
        if artwork.image(for: id, kind: .background, mode: autoBackgroundMode) != nil {
            return "Fondo listo"
        }
        if fetchingAutoBackground == id { return "Buscando fondo…" }
        if let current = wallpaperLookupStatus[id] { return current }
        if wallpaperRules.lastError != nil &&
            wallpaperRules.rule(bundleID: app.bundleID, name: app.name) == nil {
            return "Catálogo de fondos sin conexión"
        }
        return "Fondo: pendiente"
    }

    @MainActor
    private func resolveAutomaticBackground(force: Bool = false) async {
        guard autoBackgrounds, !safeGraphics,
              let app = selectedApp else { return }
        let id = key(app)
        let rule = wallpaperRules.rule(bundleID: app.bundleID, name: app.name)
        guard rule != nil || BloomBoxGameBoxArtworkLookup.supported(title(app)) else {
            wallpaperLookupStatus[id] = "Sin fondo identificado"
            return
        }

        let prefs = LiveContainerPreferencesAdapter.defaults
        let attemptedKey = "BloomBoxGameBoxArtworkLastAttempt:" + id
        // Invalidate the old 24-hour cooldown from the previous broken lookup
        // version. New versions use their own retry marker.
        let attemptedRuleKey = "BloomBoxGameBoxArtworkLastAttemptRule-v3:" + id
        let savedRuleKey = "BloomBoxGameBoxArtworkAppliedRule:" + id
        // Rules can change without reinstalling the app. A newly published
        // mapping should be applied even when a fallback image is cached.
        let ruleToken = rule.map {
            // The URL is part of cache identity: a newly curated image
            // replaces an older guessed auto-wallpaper without a reinstall.
            "remote:" + $0.id + ":" + $0.provider + ":" + $0.query +
                ":" + ($0.imageURL ?? "")
        } ?? "built-in:" + app.name

        // Manual image/cover always wins. Remote metadata never overwrites it.
        if artwork.image(for: id, kind: .background) != nil ||
           artwork.image(for: id, kind: .cover) != nil { return }

        if !force {
            let existing = artwork.image(for: id, kind: .background,
                                         mode: autoBackgroundMode) != nil
            if existing && (prefs.string(forKey: savedRuleKey) == ruleToken ||
                            rule == nil) {
                wallpaperLookupStatus[id] = "Fondo listo"
                return
            }
            if prefs.string(forKey: attemptedRuleKey) == ruleToken &&
               Date().timeIntervalSince1970 - prefs.double(forKey: attemptedKey) <
                    24 * 60 * 60 {
                wallpaperLookupStatus[id] = "Sin resultado · reintentar"
                return
            }
            // Avoid network requests while rapidly tapping across the row.
            do { try await Task.sleep(nanoseconds: 650_000_000) }
            catch { return }
        }

        guard !Task.isCancelled, key(selectedApp ?? app) == id,
              fetchingAutoBackground != id else { return }
        // A request for another app may still be winding down after its
        // task was cancelled. Never let it block the newly selected icon.
        fetchingAutoBackground = id
        wallpaperLookupStatus[id] = "Buscando fondo…"
        defer {
            if fetchingAutoBackground == id { fetchingAutoBackground = nil }
        }
        prefs.set(Date().timeIntervalSince1970, forKey: attemptedKey)
        prefs.set(ruleToken, forKey: attemptedRuleKey)
        BloomBoxCrashJournal.shared.record("gamebox.online_wallpaper.lookup")
        guard let found = await BloomBoxGameBoxArtworkLookup.find(app.name, rule: rule),
              !Task.isCancelled, key(selectedApp ?? app) == id,
              artwork.image(for: id, kind: .background) == nil,
              artwork.image(for: id, kind: .cover) == nil else {
            if !Task.isCancelled {
                wallpaperLookupStatus[id] = "Sin resultado · reintentar"
                BloomBoxCrashJournal.shared.record("gamebox.online_wallpaper.unavailable")
            }
            return
        }
        do {
            try artwork.save(found.image, for: id, kind: .background,
                             mode: autoBackgroundMode)
            prefs.set(found.sourceURL.absoluteString,
                      forKey: "BloomBoxGameBoxArtworkSource:" + id)
            prefs.set(ruleToken, forKey: savedRuleKey)
            wallpaperLookupStatus[id] = "Fondo listo"
            BloomBoxCrashJournal.shared.record("gamebox.online_wallpaper.saved")
        } catch {
            wallpaperLookupStatus[id] = "Error al guardar fondo"
            BloomBoxCrashJournal.shared.record("gamebox.online_wallpaper.save_failed")
        }
    }

    private func beginArtworkIntroIfNeeded() {
        guard !artworkIntroDidRun else { return }
        artworkIntroDidRun = true
        guard artworkIntroEnabled, autoBackgrounds, !visibleApps.isEmpty else { return }
        artworkIntroAppKey = selectedApp.map(key)
        artworkIntroStartedAt = Date()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            artworkIntroVisible = true
        }
    }

    private func resumeSafeGraphicsAndLoadArt() {
        // A user explicitly opted back into GPU-heavy artwork. Keep the
        // loader visible while the first background is prepared; switching
        // SAFE -> normal restarts the bounded six-second timeout.
        BloomBoxCrashJournal.shared.record("gamebox.safe_graphics.user_resumed")
        artworkIntroAppKey = selectedApp.map(key)
        artworkIntroStartedAt = Date()
        safeGraphics = false
        if artworkIntroEnabled && autoBackgrounds {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                artworkIntroVisible = true
            }
        } else {
            dismissArtworkIntro()
        }
    }

    private func dismissArtworkIntro() {
        guard artworkIntroVisible else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            artworkIntroVisible = false
        }
        artworkIntroStartedAt = nil
        artworkIntroAppKey = nil
    }

    @MainActor
    private func finishArtworkIntroAfterLookup() async {
        guard artworkIntroVisible, !safeGraphics,
              let started = artworkIntroStartedAt else { return }
        // Let the BloomBox Alive-style icon wave finish at least once. Cache
        // hits can return instantly; we still give a short visible transition.
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 1.15 {
            do {
                try await Task.sleep(nanoseconds: UInt64((1.15 - elapsed) * 1_000_000_000))
            } catch { return }
        }
        guard !Task.isCancelled else { return }
        dismissArtworkIntro()
    }

    private func requestLaunch(_ app: BloomBoxGameBoxEntry, forceJIT: Bool) {
        // A double-tap can otherwise launch the same guest twice and race
        // LiveProcess/JIT setup. Unlock shortly afterwards if the host refuses
        // or the guest cannot start; no second launch occurs during the delay.
        guard !launchPending else { return }
        launchPending = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        BloomBoxCrashJournal.shared.record(
            forceJIT ? "gamebox.guest.jit_launch.requested" : "gamebox.guest.launch.requested")
        BloomBoxCrashJournal.shared.leaveGameBox()
        if forceJIT { launchWithJIT(key(app)) }
        else { launch(key(app)) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            launchPending = false
        }
    }

    private func toggleFavorite(_ app: BloomBoxGameBoxEntry) {
        favoritesJSON = BloomBoxHomeAppPolicy.toggledFavorite(key(app), in: favoritesJSON)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func importArtworkFile(_ url: URL, for key: String,
                                   kind: BloomBoxArtworkLibrary.Kind) throws {
        guard !importingArtwork else { return }
        importingArtwork = true
        Task { @MainActor in
            defer { importingArtwork = false }
            do {
                // Reading remote Files/iCloud documents synchronously on the
                // main thread can trigger a watchdog termination. Stream only
                // the allowed prefix off-main to avoid unbounded memory use.
                let bytes = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { file.closeFile() }
                    let limit = 20 * 1024 * 1024
                    let data = try file.read(upToCount: limit + 1) ?? Data()
                    guard !data.isEmpty, data.count <= limit else {
                        throw CocoaError(.fileReadTooLarge)
                    }
                    return data
                }.value
                try artwork.save(decodeArtwork(bytes), for: key, kind: kind)
                BloomBoxCrashJournal.shared.record("gamebox.artwork.files.success")
            } catch {
                artworkError = error.localizedDescription
                BloomBoxCrashJournal.shared.record("gamebox.artwork.files.failed")
            }
        }
    }

    private func decodeArtwork(_ data: Data) throws -> UIImage {
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CocoaError(.fileReadTooLarge)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1800,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return UIImage(cgImage: bitmap)
    }

    private func chooseArtworkFromFiles(for app: BloomBoxGameBoxEntry,
                                        kind: BloomBoxArtworkLibrary.Kind) {
        BloomBoxCrashJournal.shared.record("gamebox.artwork.files.open")
        artworkTargetKey = key(app)
        artworkTargetKind = kind
        filesPickerPresented = true
    }

    private func chooseArtwork(for app: BloomBoxGameBoxEntry,
                               kind: BloomBoxArtworkLibrary.Kind) {
        BloomBoxCrashJournal.shared.record("gamebox.artwork.picker.open")
        artworkTargetKey = key(app)
        artworkTargetKind = kind
        photoPickerPresented = true
    }

    private func selectionHaptic() {
        guard !reduceMotion else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func refreshStorage() {
        guard let stats = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let bytes = stats[.systemFreeSize] as? NSNumber else { return }
        let gb = bytes.doubleValue / 1_073_741_824
        if gb.isFinite, gb >= 0 {
            freeStorage = String(format: "%.1f GB libres", gb)
        }
    }

    private func refreshDualSenseBattery() {
        guard let controller = GCController.controllers().first(where: {
            $0.extendedGamepad is GCDualSenseGamepad
        }), let battery = controller.battery,
           battery.batteryLevel.isFinite,
           battery.batteryLevel >= 0, battery.batteryLevel <= 1 else {
            dualSenseBatteryPercent = nil
            return
        }
        let level = Int((battery.batteryLevel * 100).rounded())
        dualSenseBatteryPercent = (0...100).contains(level) ? level : nil
    }

    private func refreshBattery() {
        let level = UIDevice.current.batteryLevel
        batteryPercent = level >= 0 ? Int((level * 100).rounded()) : nil
    }

    private func refreshSystemBudget() {
        let info = ProcessInfo.processInfo
        constrained = info.isLowPowerModeEnabled ||
            info.thermalState == .serious || info.thermalState == .critical
    }
}
