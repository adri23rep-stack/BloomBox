// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack. Original BloomBox console presentation.
//
// GameBox v2 is UI only: the host retains ownership of launch/JIT,
// orientation, signing, app settings and guest containers.
import SwiftUI
import UIKit

struct BloomBoxGameBoxV2Screen: View {
    let apps: [LCAppModel]
    let launch: (LCAppModel) -> Void
    let launchWithJIT: (LCAppModel) -> Void
    let manage: (LCAppModel) -> Void
    let backToHome: () -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    let openInstall: () -> Void

    @ObservedObject private var customization = BloomBoxAppCustomization.shared
    @StateObject private var artwork = BloomBoxArtworkLibrary()
    @AppStorage("BloomBoxGameBoxV2Favorites", store: LCUtils.appGroupUserDefault)
    private var favoritesJSON = "[]"
    @AppStorage("LiveBoardReduceMotion", store: LCUtils.appGroupUserDefault)
    private var localReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var focusedKey: String?
    @State private var alphabetical = false
    @State private var quickMenu = false
    @State private var upcomingFeature: String?
    @State private var constrained = false
    @State private var batteryPercent: Int?

    private var reduceMotion: Bool { systemReduceMotion || localReduceMotion || constrained }
    private var favorites: Set<String> {
        Set(BloomBoxHomeAppPolicy.favorites(from: favoritesJSON))
    }
    private func key(_ app: LCAppModel) -> String { liveBoardAppKey(app) }
    private func title(_ app: LCAppModel) -> String { customization.name(app) }

    private var visibleApps: [LCAppModel] {
        let indexed = Array(apps.enumerated())
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
    private var selectedApp: LCAppModel? {
        visibleApps.first(where: { key($0) == focusedKey }) ?? visibleApps.first
    }
    private var focusedAccent: Color {
        guard let app = selectedApp else { return Color(red: 0.42, green: 0.79, blue: 0.98) }
        return accent(for: app)
    }
    private func accent(for app: LCAppModel) -> Color {
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
    private func cover(_ app: LCAppModel) -> UIImage? {
        artwork.image(for: key(app), kind: .cover)
    }
    private func backdrop(_ app: LCAppModel) -> UIImage? {
        artwork.image(for: key(app), kind: .background) ??
        artwork.image(for: key(app), kind: .cover) ??
        LiveBoardIconStore.image(app, dark: false)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 370
            let cardHeight = max(125, min(compact ? 191 : 290, geometry.size.height * (compact ? 0.44 : 0.47)))
            let cardWidth = cardHeight * 0.79
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
                        carousel(cardWidth: cardWidth, height: cardHeight)
                            .frame(height: cardHeight + 12)
                    }
                    detailPanel(compact: compact)
                        .frame(height: compact ? 92 : 122)
                }
                .padding(.horizontal, compact ? 12 : 25)
                .padding(.vertical, compact ? 3 : 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .background(BloomBoxOrientationLock(mask: .landscape).frame(width: 0, height: 0))
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            if focusedKey == nil { focusedKey = visibleApps.first.map(key) }
            refreshSystemBudget()
            UIDevice.current.isBatteryMonitoringEnabled = true
            refreshBattery()
        }
        .onChange(of: apps.map(key)) { keys in
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
            LinearGradient(
                colors: [.black, focusedAccent.opacity(0.42), Color(red: 0.05, green: 0.07, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if !constrained, let app = selectedApp, let image = backdrop(app) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 32)
                        .opacity(0.31)
                }
                .allowsHitTesting(false)
            }
            LinearGradient(
                colors: [.black.opacity(0.25), .clear, .black.opacity(0.66)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: focusedKey)
        .accessibilityHidden(true)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 9) {
            topButton("ellipsis", label: "Menú") { quickMenu = true }
            topButton("person.2.fill", label: "Amigos") {
                upcomingFeature = "La sección de amigos y Discord está reservada para una próxima versión."
            }
            topButton("arrow.up.arrow.down", label: "Ordenar") {
                alphabetical.toggle()
                selectionHaptic()
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: compact ? 13 : 17, weight: .semibold))
                Text("GAMEBOX").font(.system(size: compact ? 12 : 15, weight: .black, design: .rounded))
                    .tracking(1.3)
                Text("V2").font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(focusedAccent.opacity(0.35), in: Capsule())
                if let batteryPercent {
                    Image(systemName: "battery.100").font(.system(size: 12))
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
            Spacer(minLength: 4)
            topButton("bell.fill", label: "Notificaciones") {
                upcomingFeature = "Las notificaciones de GameBox se añadirán después."
            }
            topButton("music.note", label: "Música") {
                upcomingFeature = "El reproductor y el ecualizador están preparados para una próxima actualización."
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
                .background(.white.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func carousel(cardWidth: CGFloat, height: CGFloat) -> some View {
        ScrollViewReader { scroll in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 14) {
                    ForEach(visibleApps, id: \.self) { app in
                        gameCard(app, width: cardWidth, height: height)
                            .id(key(app))
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
                guard abs(value.translation.width) > 45 else { return }
                moveSelection(value.translation.width < 0 ? 1 : -1)
            })
            .onChange(of: focusedKey) { changed in
                guard let changed else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
                    scroll.scrollTo(changed, anchor: .center)
                }
            }
            .onAppear {
                if let focusedKey {
                    scroll.scrollTo(focusedKey, anchor: .center)
                }
            }
        }
    }

    private func gameCard(_ app: LCAppModel, width: CGFloat, height: CGFloat) -> some View {
        let focused = key(app) == selectedApp.map(key)
        return ZStack {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(LinearGradient(colors: [accent(for: app).opacity(0.9),
                                              Color(red: 0.10, green: 0.12, blue: 0.20)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let art = cover(app) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                VStack(spacing: 13) {
                    Spacer(minLength: 5)
                    LiveBoardIconImage(app: app, dark: false)
                        .frame(width: min(width * 0.58, height * 0.48),
                               height: min(width * 0.58, height * 0.48))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
                    Text(title(app))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 9)
                    Spacer(minLength: 12)
                }
                .frame(width: width, height: height)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.06), .black.opacity(0.68)],
                           startPoint: .top, endPoint: .bottom)
            VStack {
                HStack {
                    if favorites.contains(key(app)) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .bold))
                            .padding(7)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    Spacer()
                    if app.appInfo.isJITNeeded {
                        Text("JIT")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.black.opacity(0.57), in: Capsule())
                    }
                }
                Spacer()
                HStack(spacing: 7) {
                    // The real installed app icon remains visible, even with cover art.
                    LiveBoardIconImage(app: app, dark: false)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(title(app))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(9)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(focused ? .white.opacity(0.98) : .white.opacity(0.20),
                              lineWidth: focused ? 2.8 : 1)
        }
        .shadow(color: focused ? focusedAccent.opacity(0.34) : .black.opacity(0.12),
                radius: focused ? 15 : 3, y: 4)
        .scaleEffect(focused && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: focused)
        .contentShape(RoundedRectangle(cornerRadius: 19))
        .onTapGesture {
            select(app)
        }
        .highPriorityGesture(TapGesture(count: 2).onEnded {
            select(app)
            toggleFavorite(app)
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title(app) + (favorites.contains(key(app)) ? ", favorito" : ""))
        .accessibilityAddTraits(focused ? .isSelected : [])
        .accessibilityHint("Toca para seleccionar, dos veces para alternar favorito. Usa Jugar para abrir.")
        .accessibilityIdentifier("bloombox.gamebox.card." + key(app))
    }

    private func detailPanel(compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 18) {
            if let app = selectedApp {
                LiveBoardIconImage(app: app, dark: false)
                    .frame(width: compact ? 54 : 68, height: compact ? 54 : 68)
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
                    launch(app)
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
                    Button("Abrir con JIT", systemImage: "bolt.fill") { launchWithJIT(app) }
                    Button(favorites.contains(key(app)) ? "Quitar de favoritos" : "Añadir a favoritos",
                           systemImage: "heart") { toggleFavorite(app) }
                    Button("Ajustes de esta app", systemImage: "gearshape") { manage(app) }
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

    private func select(_ app: LCAppModel) {
        let next = key(app)
        guard focusedKey != next else { return }
        focusedKey = next
        selectionHaptic()
    }

    private func moveSelection(_ delta: Int) {
        guard !visibleApps.isEmpty else { return }
        let current = visibleApps.firstIndex(where: { key($0) == selectedApp.map(key) }) ?? 0
        let next = min(max(0, current + delta), visibleApps.count - 1)
        select(visibleApps[next])
    }

    private func toggleFavorite(_ app: LCAppModel) {
        favoritesJSON = BloomBoxHomeAppPolicy.toggledFavorite(key(app), in: favoritesJSON)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
