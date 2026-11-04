// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack. Original BloomBox console presentation.
//
// GameBox v2 is UI only: the host retains ownership of launch/JIT,
// orientation, signing, app settings and guest containers.
import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

/// Portable UI item. Only the existing host adapts installed guest metadata.
struct BloomBoxGameBoxEntry: Identifiable {
    let id: String
    let name: String
    let icon: UIImage?
    let requiresJIT: Bool
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
    @AppStorage("BloomBoxGameBoxV2Favorites", store: LiveContainerPreferencesAdapter.defaults)
    private var favoritesJSON = "[]"
    @AppStorage("LiveBoardReduceMotion", store: LiveContainerPreferencesAdapter.defaults)
    private var localReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var focusedKey: String?
    @State private var lastSelectedKey: String?
    // GameBox wallpaper is independent of the Home wallpaper and never modifies it.
    @AppStorage("BloomBoxGameBoxV2WallpaperMode", store: LiveContainerPreferencesAdapter.defaults)
    private var backgroundMode = "auto"
    @AppStorage("BloomBoxGameBoxV2MotionWallpaper", store: LiveContainerPreferencesAdapter.defaults)
    private var motionWallpaperName = ""
    @State private var motionPhotosPresented = false
    @State private var wallpaperFilesPresented = false
    @State private var alphabetical = false
    @State private var quickMenu = false
    @State private var upcomingFeature: String?
    @State private var constrained = false
    @State private var batteryPercent: Int?
    @State private var photoPickerPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var artworkTargetKey: String?
    @State private var artworkTargetKind: BloomBoxArtworkLibrary.Kind = .cover
    @State private var importingArtwork = false
    @State private var artworkError: String?

    private var reduceMotion: Bool { systemReduceMotion || localReduceMotion || constrained }
    private let sharedWallpaperKey = "gamebox:global:wallpaper"
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
        artwork.image(for: key(app), kind: .cover)
    }
    private func backdrop(_ app: BloomBoxGameBoxEntry) -> UIImage? {
        artwork.image(for: key(app), kind: .background) ??
        artwork.image(for: key(app), kind: .cover) ??
        app.icon
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 370
            // Size icon-only cells to the actual landscape viewport, keeping
            // the entire app image visible instead of cropping a cover card.
            let iconSide = min(compact ? 136.0 : 164.0,
                               max(94.0, geometry.size.height * (compact ? 0.37 : 0.39)))
            let cardHeight = iconSide + 36
            let cardWidth = iconSide + 16
            ZStack {
                consoleBackground
                VStack(spacing: compact ? 7 : 15) {
                    header(compact: compact)
                        .frame(height: compact ? 42 : 55)
                    Spacer(minLength: 0)
                    if visibleApps.isEmpty {
                        emptyLibrary
                            .frame(height: cardHeight)
                    } else {
                        carousel(cardWidth: cardWidth, height: cardHeight,
                                 viewportWidth: geometry.size.width)
                            .frame(height: cardHeight + 12)
                    }
                    detailPanel(compact: compact)
                        .frame(height: compact ? 92 : 122)
                }
                .padding(.horizontal, compact ? 23 : 30)
                .padding(.top, compact ? 23 : 29)
                .padding(.bottom, compact ? 8 : 14)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .background(BloomBoxOrientationLock(mask: .landscape).frame(width: 0, height: 0))
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $photoPickerPresented, selection: $selectedPhoto, matching: .images)
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
                    try savePhoto(data, key: target, kind: kind)
                    if target == sharedWallpaperKey { backgroundMode = "photo" }
                } catch {
                    artworkError = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $motionPhotosPresented) {
            BloomBoxMotionWallpaperPhotosPicker { result in
                motionPhotosPresented = false
                guard let result else { return }
                switch result {
                case .success(let filename): useMotionWallpaper(filename)
                case .failure(let error): artworkError = error.localizedDescription
                }
            }
        }
        .fileImporter(isPresented: $wallpaperFilesPresented,
                      allowedContentTypes: [.image, .gif, .movie]) { result in
            switch result {
            case .success(let file): importWallpaperFile(file)
            case .failure(let error): artworkError = error.localizedDescription
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
        .alert("No se pudo importar el fondo o la imagen", isPresented: Binding(
            get: { artworkError != nil },
            set: { if !$0 { artworkError = nil } }
        )) {
            Button("Entendido", role: .cancel) { artworkError = nil }
        } message: {
            Text(artworkError ?? "")
        }
        .onAppear {
            if focusedKey == nil { focusedKey = visibleApps.first.map(key) }
            lastSelectedKey = focusedKey
            refreshSystemBudget()
            UIDevice.current.isBatteryMonitoringEnabled = true
            refreshBattery()
        }
        .onChange(of: focusedKey) { key in
            guard let key, key != lastSelectedKey else { return }
            if lastSelectedKey != nil { selectionHaptic() }
            lastSelectedKey = key
        }
        .onChange(of: entries.map(key)) { keys in
            if let focusedKey, !keys.contains(focusedKey) {
                self.focusedKey = visibleApps.first.map(key)
            }
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
        .confirmationDialog("GameBox", isPresented: $quickMenu) {
            Button("Fondo automático") { backgroundMode = "auto" }
            Button("Elegir wallpaper foto") { chooseWallpaperPhoto() }
            Button("Wallpaper GIF o video desde Fotos") { motionPhotosPresented = true }
            Button("Wallpaper desde Archivos") { wallpaperFilesPresented = true }
            Button("Quitar wallpaper personalizado", role: .destructive) {
                backgroundMode = "auto"
                artwork.remove(for: sharedWallpaperKey, kind: .background)
                if !motionWallpaperName.isEmpty {
                    BloomBoxMotionMedia.remove(motionWallpaperName)
                    motionWallpaperName = ""
                }
            }
            Button("Administrar aplicaciones", action: openManagement)
            Button("Instalar IPA", action: openInstall)
            Button("Cambiar interfaz", action: openInterface)
            Button("Volver al escritorio", action: backToHome)
        }
        .alert("Función preparada", isPresented: Binding(
            get: { upcomingFeature != nil },
            set: { if !$0 { upcomingFeature = nil } }
        )) {
            Button("Entendido", role: .cancel) { upcomingFeature = nil }
        } message: {
            Text(upcomingFeature ?? "")
        }
        .accessibilityIdentifier("bloombox.gamebox.v2")
    }

    private var consoleBackground: some View {
        ZStack {
            // Stable base layer: no parallax, scale/translate or sudden camera
            // movement when a different game becomes selected.
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.09, blue: 0.15),
                         Color(red: 0.15, green: 0.10, blue: 0.27),
                         Color(red: 0.04, green: 0.04, blue: 0.095)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if backgroundMode == "motion", let url = BloomBoxMotionMedia.url(motionWallpaperName) {
                BloomBoxAnimatedWallpaper(url: url, fit: false,
                                         paused: constrained || reduceMotion)
                    .opacity(0.84)
            } else if backgroundMode == "photo",
                      let image = artwork.image(for: sharedWallpaperKey, kind: .background) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped().opacity(0.73)
                }
            } else if backgroundMode == "auto", !constrained,
                      let app = selectedApp, let image = backdrop(app) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 14)
                        .opacity(0.26)
                }
                .id(app.id)
                .transition(.opacity)
            }
            LinearGradient(
                colors: [.black.opacity(0.31), .clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .animation(reduceMotion || backgroundMode != "auto" ? nil :
                   .easeInOut(duration: 0.60), value: focusedKey)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 9) {
            HStack(spacing: 7) {
                topButton("ellipsis", label: "Menú") { quickMenu = true }
                topButton("person.2.fill", label: "Amigos") {
                    upcomingFeature = "La sección de amigos y Discord está reservada para una próxima versión."
                }
                topButton("arrow.up.arrow.down", label: "Ordenar") {
                    alphabetical.toggle()
                    selectionHaptic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: compact ? 5 : 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: compact ? 13 : 17, weight: .semibold))
                Text("GAMEBOX").font(.system(size: compact ? 12 : 15, weight: .black, design: .rounded))
                    .tracking(1.3)
                Text("V2").font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(focusedAccent.opacity(0.35), in: Capsule())
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
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, compact ? 10 : 16)
            .frame(height: compact ? 36 : 46)
            .background(.black.opacity(0.23), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            HStack(spacing: 7) {
                topButton("bell.fill", label: "Notificaciones") {
                    upcomingFeature = "Las notificaciones de GameBox se añadirán después."
                }
                topButton("music.note", label: "Música") {
                    upcomingFeature = "El reproductor y el ecualizador están preparados para una próxima actualización."
                }
                topButton("power", label: "Volver al escritorio", action: backToHome)
                topButton("gearshape.fill", label: "Ajustes", action: openInterface)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func topButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 35, height: 35)
                .background(.white.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func carousel(cardWidth: CGFloat, height: CGFloat,
                          viewportWidth: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            // One native scroll system owns both finger tracking and snapping.
            // Do NOT add a competing DragGesture or second scrollTo on drag end.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 17) {
                    ForEach(visibleApps, id: \.id) { app in
                        gameCard(app, width: cardWidth, height: height)
                            .id(app.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (viewportWidth - cardWidth) / 2))
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedKey, anchor: .center)
        } else {
            // iOS 16 fallback. Only the native pan handles swipes; scrolling
            // programmatically is reserved for deliberate taps.
            ScrollViewReader { scroll in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 17) {
                        ForEach(visibleApps, id: \.id) { app in
                            gameCard(app, width: cardWidth, height: height)
                                .id(app.id)
                        }
                    }
                    .padding(.horizontal, max(0, (viewportWidth - cardWidth) / 2))
                    .padding(.vertical, 4)
                }
                .onChange(of: focusedKey) { key in
                    guard let key else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) {
                        scroll.scrollTo(key, anchor: .center)
                    }
                }
                .onAppear {
                    if let focusedKey { scroll.scrollTo(focusedKey, anchor: .center) }
                }
            }
        }
    }

    private func gameCard(_ app: BloomBoxGameBoxEntry,
                          width: CGFloat, height: CGFloat) -> some View {
        let focused = key(app) == focusedKey
        let side = width - 16
        return VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                // A complete uncropped app icon. Custom covers remain optional,
                // never automatically impose a tall trading-card crop.
                Group {
                    if let customCover = cover(app) {
                        Image(uiImage: customCover).resizable().scaledToFit()
                    } else {
                        gameIcon(app, size: side)
                    }
                }
                .frame(width: side, height: side)
                .background(.white.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .strokeBorder(focused ? .white.opacity(0.97) : .white.opacity(0.12),
                                      lineWidth: focused ? 2.3 : 0.7)
                }
                .shadow(color: focused && !constrained ? focusedAccent.opacity(0.28) : .clear,
                        radius: 15, y: 5)
                if app.requiresJIT {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Color(red: 1, green: 0.84, blue: 0.32), in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.14)))
                        .offset(x: 7, y: -7)
                        .accessibilityLabel("JIT configurado para esta app")
                }
                if favorites.contains(key(app)) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.65), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: -5, y: -5)
                }
            }
            .frame(width: side, height: side)
            Text(title(app))
                .font(.system(size: 12, weight: focused ? .bold : .medium, design: .rounded))
                .foregroundStyle(.white.opacity(focused ? 1 : 0.80))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(width: width)
        }
        .frame(width: width, height: height, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { select(app) }
        .highPriorityGesture(TapGesture(count: 2).onEnded {
            select(app)
            toggleFavorite(app)
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title(app) + (favorites.contains(key(app)) ? ", favorito" : ""))
        .accessibilityAddTraits(focused ? .isSelected : [])
        .accessibilityHint("Toca para seleccionar, dos veces para favoritos. Jugar abre la app.")
        .accessibilityIdentifier("bloombox.gamebox.card." + key(app))
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
        HStack(spacing: compact ? 10 : 18) {
            if let app = selectedApp {
                gameIcon(app, size: compact ? 54 : 68)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title(app))
                        .font(.system(size: compact ? 18 : 23, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(favorites.contains(key(app)) ? "♥ Favorito  ·  Listo para jugar" : "Listo para jugar")
                        .font(.system(size: compact ? 10 : 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.73))
                    Text(String(visibleApps.count) + " aplicaciones")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    launch(key(app))
                } label: {
                    Label("Jugar", systemImage: "play.fill")
                        .font(.system(size: compact ? 14 : 17, weight: .bold, design: .rounded))
                        .frame(width: compact ? 130 : 184, height: compact ? 46 : 55)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(.white, in: Capsule())
                .accessibilityIdentifier("bloombox.gamebox.play")
                Menu {
                    Button("Abrir con JIT", systemImage: "bolt.fill") { launchWithJIT(key(app)) }
                    Button(favorites.contains(key(app)) ? "Quitar de favoritos" : "Añadir a favoritos",
                           systemImage: "heart") { toggleFavorite(app) }
                    Button("Ajustes de esta app", systemImage: "gearshape") { manage(key(app)) }
                    Divider()
                    Button {
                        chooseArtwork(for: app, kind: .cover)
                    } label: {
                        Label("Elegir carátula", systemImage: "photo")
                    }
                    Button {
                        chooseArtwork(for: app, kind: .background)
                    } label: {
                        Label("Elegir fondo", systemImage: "photo.on.rectangle")
                    }
                    if cover(app) != nil {
                        Button(role: .destructive) {
                            artwork.remove(for: key(app), kind: .cover)
                        } label: {
                            Label("Quitar carátula", systemImage: "trash")
                        }
                    }
                } label: {
                    footerCircle("ellipsis", label: "Más opciones")
                }
                Button(action: openManagement) {
                    footerCircle("square.grid.2x2.fill", label: "Biblioteca")
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "gamecontroller").font(.title)
                Text("Agrega tu primera aplicación").font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Instalar IPA", action: openInstall)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, compact ? 13 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(constrained ? 0.72 : 0.44),
                    in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    private func footerCircle(_ symbol: String, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 43, height: 43)
            .foregroundStyle(.white)
            .background(.white.opacity(0.11), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.21)))
            .accessibilityLabel(label)
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

    private func select(_ app: BloomBoxGameBoxEntry) {
        let next = key(app)
        guard focusedKey != next else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) {
            focusedKey = next
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !visibleApps.isEmpty else { return }
        let current = visibleApps.firstIndex(where: { key($0) == selectedApp.map(key) }) ?? 0
        let next = min(max(0, current + delta), visibleApps.count - 1)
        select(visibleApps[next])
    }

    private func toggleFavorite(_ app: BloomBoxGameBoxEntry) {
        favoritesJSON = BloomBoxHomeAppPolicy.toggledFavorite(key(app), in: favoritesJSON)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func chooseWallpaperPhoto() {
        artworkTargetKey = sharedWallpaperKey
        artworkTargetKind = .background
        photoPickerPresented = true
    }

    // Decode a bounded thumbnail instead of expanding a huge 4K photo in RAM.
    private func savePhoto(_ data: Data, key: String,
                           kind: BloomBoxArtworkLibrary.Kind) throws {
        guard !data.isEmpty, data.count <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else {
            throw BloomBoxMotionMedia.failure("La foto no es compatible o supera 30 MB.")
        }
        try artwork.save(UIImage(cgImage: image), for: key, kind: kind)
    }

    private func useMotionWallpaper(_ filename: String) {
        guard BloomBoxMotionMedia.url(filename) != nil else {
            artworkError = "No se encontró el GIF o video importado."
            return
        }
        let old = motionWallpaperName
        motionWallpaperName = filename
        backgroundMode = "motion"
        if !old.isEmpty && old != filename { BloomBoxMotionMedia.remove(old) }
    }

    private enum ImportedWallpaperFile {
        case motion(String)
        case photo(Data)
    }

    private func importWallpaperFile(_ url: URL) {
        importingArtwork = true
        // File coordination, 200 MB videos and GIF verification never block
        // the main-thread touch/scroll animation.
        Task {
            defer { importingArtwork = false }
            do {
                let imported = try await Task.detached(priority: .userInitiated) { () throws -> ImportedWallpaperFile in
                    let extensionName = url.pathExtension.lowercased()
                    if ["gif", "mp4", "mov", "m4v"].contains(extensionName) {
                        return .motion(try BloomBoxMotionMedia.importFile(url))
                    }
                    let secured = url.startAccessingSecurityScopedResource()
                    defer { if secured { url.stopAccessingSecurityScopedResource() } }
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    guard size > 0 && size <= 30 * 1024 * 1024 else {
                        throw BloomBoxMotionMedia.failure("La foto debe pesar máximo 30 MB.")
                    }
                    return .photo(try Data(contentsOf: url))
                }.value
                switch imported {
                case .motion(let filename):
                    useMotionWallpaper(filename)
                case .photo(let data):
                    try savePhoto(data, key: sharedWallpaperKey, kind: .background)
                    backgroundMode = "photo"
                }
            } catch {
                artworkError = error.localizedDescription
            }
        }
    }

    private func chooseArtwork(for app: BloomBoxGameBoxEntry,
                               kind: BloomBoxArtworkLibrary.Kind) {
        artworkTargetKey = key(app)
        artworkTargetKind = kind
        photoPickerPresented = true
    }

    private func selectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
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
