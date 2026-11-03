import SwiftUI
import UniformTypeIdentifiers


/// Home tools that also need to be reachable from GameBox.
private enum GameBoxUtility: String, CaseIterable, Identifiable {
    case modules, tweakStore, appStore, install, sideStore, themes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .modules: return "Módulos"
        case .tweakStore: return "TweakStore"
        case .appStore: return "AppStore"
        case .install: return "Instalar IPA"
        case .sideStore: return "SideStore"
        case .themes: return "Temas"
        }
    }
    var symbol: String {
        switch self {
        case .modules: return "square.stack.3d.up.fill"
        case .tweakStore: return "wrench.and.screwdriver.fill"
        case .appStore: return "square.stack.fill"
        case .install: return "square.and.arrow.down.fill"
        case .sideStore: return "arrow.triangle.2.circlepath"
        case .themes: return "paintpalette.fill"
        }
    }
}

struct LiveBoardConsoleScreen: View {
    let apps: [LCAppModel]
    let mode: String
    let launch: (LCAppModel, Bool) async -> Void
    let manage: (LCAppModel) -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    var launchWithJIT: ((LCAppModel, Bool) async -> Void)? = nil
    var openModuleDestination: ((BloomBoxModulesPanel.Destination) -> Void)? = nil
    var openInstall: (() -> Void)? = nil
    var openSideStore: (() -> Void)? = nil
    var openSources: (() -> Void)? = nil
    var openThemeStore: (() -> Void)? = nil
    @ObservedObject private var appCustomization = LiveBoardAppCustomization.shared
    @State private var appearanceApp: LiveBoardAppearanceSelection?
    @AppStorage("StrataConsoleLayouts", store: LCUtils.appGroupUserDefault) private var savedConsoleLayouts = "{}"
    @State private var layoutSettings = false
    @State private var movingLaunchButton = false
    @State private var dragOrigin: CGPoint?
    private var consoleLayout: LiveBoardConsoleLayout { LiveBoardConsoleLayout.decode(savedConsoleLayouts, mode: mode) }
    private func updateConsoleLayout(_ action: (inout LiveBoardConsoleLayout) -> Void) {
        var layout = consoleLayout; action(&layout)
        savedConsoleLayouts = LiveBoardConsoleLayout.save(layout, mode: mode, in: savedConsoleLayouts)
    }
    @State private var jitSetup = false
    @State private var modulesPresented = false
    @State private var utilitiesPresented = false
    @State private var pendingUtility: GameBoxUtility?
    @State private var tweakStorePresented = false
    @State private var appStorePresented = false
    @State private var quickJITPresented = false
    @State private var jitSwitchRevision = 0
    @ObservedObject private var ramPlus = BloomBoxRAMPlus.shared
    @State private var pendingModuleDestination: BloomBoxModulesPanel.Destination?
    @State private var wallpaperSettings = false
    @State private var pendingWallpaperPicker: GameBoxWallpaperPicker?
    @State private var choosingGameBoxPhoto = false
    @State private var choosingGameBoxMotionPhotos = false
    @State private var choosingGameBoxMotionFiles = false
    @State private var importingGameBoxMotion = false
    @State private var gameBoxPhoto: UIImage?
    @AppStorage("BloomBoxGameBoxWallpaperStyle", store: LCUtils.appGroupUserDefault)
    private var gameBoxWallpaperStyle = "dynamic"
    @AppStorage("BloomBoxGameBoxMotionWallpaper", store: LCUtils.appGroupUserDefault)
    private var gameBoxMotionWallpaper = ""
    @AppStorage("BloomBoxGameBoxWallpaperFit", store: LCUtils.appGroupUserDefault)
    private var gameBoxWallpaperFit = false
    @AppStorage("BloomBoxGameBoxWallpaperDim", store: LCUtils.appGroupUserDefault)
    private var gameBoxWallpaperDim = 0.12
    @AppStorage("BloomBoxGameBoxPauseWallpaper", store: LCUtils.appGroupUserDefault)
    private var gameBoxPauseWallpaper = false

    private enum GameBoxWallpaperPicker { case photo, photosMotion, filesMotion }
    private var gameBoxPhotoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true)
            .appendingPathComponent("gamebox-wallpaper.jpg")
    }
    @AppStorage("LiveBoardFavorites", store: LCUtils.appGroupUserDefault) private var favorites = "[]"
    @AppStorage("LiveBoardCategories", store: LCUtils.appGroupUserDefault) private var categories = "{}"
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkIcons = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var controller = LiveBoardControllerInput()
    @StateObject private var artwork = LiveBoardArtworkStore()
    @AppStorage("LiveBoardModeLibraries", store: LCUtils.appGroupUserDefault) private var modeLibraries = "{}"
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @State private var activeCategory: String?
    @State private var managingCategories = false
    @State private var newCategory = ""
    @StateObject private var audio = LiveBoardNavigationAudio()
    private var libraries: [String: LiveBoardModeLibrary] { (try? JSONDecoder().decode([String: LiveBoardModeLibrary].self, from: Data(modeLibraries.utf8))) ?? [:] }
    private var library: LiveBoardModeLibrary { libraries[mode] ?? LiveBoardModeLibrary() }
    private func updateLibrary(_ action: (inout LiveBoardModeLibrary) -> Void) {
        var all = libraries; var state = library; action(&state); all[mode] = state
        if let data = try? JSONEncoder().encode(all), let text = String(data: data, encoding: .utf8) { modeLibraries = text }
    }
    @State private var navigation = LiveBoardConsoleNavigation()
    @State private var favoritesOnly = false
    @State private var details = false
    @State private var detailsIndex = 0
    @State private var searching = false
    @State private var query = ""
    @State private var launching = false
    @State private var launchReturned = false
    @State private var picker: ArtworkRequest?
    @State private var artworkError: String?

    private struct ArtworkRequest: Identifiable {
        let key: String
        let kind: LiveBoardArtworkStore.Kind
        var id: String { key + kind.rawValue }
    }
    private var favoriteKeys: [String] { (try? JSONDecoder().decode([String].self, from: Data(favorites.utf8))) ?? [] }
    private var visibleApps: [LCAppModel] {
        apps.filter { app in
            let key = liveBoardAppKey(app)
            return !library.hidden.contains(key) && (!favoritesOnly || favoriteKeys.contains(key)) && (activeCategory == nil || library.assignments[key] == activeCategory)
        }
    }
    private var selected: LCAppModel? { visibleApps.indices.contains(navigation.selectedIndex) ? visibleApps[navigation.selectedIndex] : visibleApps.first }
    private var keys: [String] { visibleApps.map(liveBoardAppKey) }
    private var bigPicture: Bool { mode == "bigPicture" }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let iconScale = min(CGFloat(consoleLayout.iconScale), max(0.65, (geometry.size.height - 180) / 126))
            ZStack {
                if let app = selected, artwork.image(for: liveBoardAppKey(app), kind: .background, mode: mode) == nil {
                    LiveBoardIconImage(app: app, dark: darkIcons)
                        .frame(width: landscape ? 190 : 148, height: landscape ? 190 : 148)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 40)
                        .opacity(0.75)
                        .position(x: geometry.size.width * 0.78, y: geometry.size.height * 0.5)
                        .allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 0) {
                    header(landscape: landscape).padding(.top, 4)
                    categoryTabs.padding(.bottom, 4)
                    if !bigPicture { carousel(landscape: landscape, scale: iconScale).padding(.leading, -24 - geometry.safeAreaInsets.leading).padding(.trailing, -24 - geometry.safeAreaInsets.trailing).padding(.top, 4) }
                    hero(landscape: landscape).frame(maxHeight: .infinity, alignment: .bottomLeading)
                    if bigPicture { carousel(landscape: landscape, scale: iconScale).padding(.leading, -24 - geometry.safeAreaInsets.leading).padding(.trailing, -24 - geometry.safeAreaInsets.trailing).padding(.top, 8) }
                    footer.padding(.top, landscape ? 8 : 22).padding(.bottom, 8)
                }
                .frame(width: max(0, geometry.size.width - 48), height: geometry.size.height)
                .padding(.horizontal, 24)
                .blur(radius: details ? 12 : 0)
                .allowsHitTesting(!details)
                .opacity(landscape ? 1 : 0)
                .accessibilityHidden(details || !landscape)
                if !landscape {
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.largeTitle)
                        Text("Turn your iPhone sideways").font(.headline)
                        Button("Interface") { controller.stop(); openInterface() }.buttonStyle(.bordered)
                    }
                }
                if landscape, let app = selected {
                    if mode == "cinematic" {
                        // GameBox's launch action has a fixed lower-right home.
                        // Never float over the title, regardless of stored layouts.
                        Button { activate(app) } label: {
                            Group {
                                if launching { ProgressView().tint(.white) }
                                else { Image(systemName: "chevron.right").font(.system(size: 32, weight: .bold)) }
                            }
                            .frame(width: 78, height: 78)
                            .liveBoardGlass(radius: 39)
                            .overlay(Circle().strokeBorder(
                                navigation.focus == .launch ? .white : .white.opacity(0.30),
                                lineWidth: navigation.focus == .launch ? 2 : 1))
                            .shadow(color: .black.opacity(0.25), radius: 14, y: 7)
                        }
                        .buttonStyle(.plain)
                        .disabled(launching || app.isAppRunning || app.isSigningInProgress)
                        .accessibilityLabel("Iniciar " + appCustomization.name(app))
                        .accessibilityIdentifier("console.launch")
                        .position(x: max(42, geometry.size.width - 68),
                                  y: max(42, geometry.size.height - 66))
                        .allowsHitTesting(!details)
                    } else {
                        let scale = min(CGFloat(consoleLayout.launchScale), geometry.size.width / 240, geometry.size.height / 54)
                        let width = 240 * scale
                        let height = 54 * scale
                        let travelX = max(1, geometry.size.width - width)
                        let travelY = max(1, geometry.size.height - height)
                        launchControls(app)
                            .frame(width: 240, height: 54)
                            .scaleEffect(scale)
                            .frame(width: width, height: height)
                            .contentShape(Rectangle())
                            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("console.canvas"))
                                .onChanged { value in
                                    if dragOrigin == nil { dragOrigin = CGPoint(x: consoleLayout.launchX, y: consoleLayout.launchY) }
                                    if let origin = dragOrigin { updateConsoleLayout { $0.launchX = origin.x + value.translation.width / travelX; $0.launchY = origin.y + value.translation.height / travelY } }
                                }.onEnded { _ in dragOrigin = nil }, including: movingLaunchButton ? .all : .none)
                            .position(x: width / 2 + travelX * consoleLayout.launchX, y: height / 2 + travelY * consoleLayout.launchY)
                            .allowsHitTesting(!details)
                        if movingLaunchButton {
                            VStack { HStack { Spacer(); Button { movingLaunchButton = false; bindController() } label: { Image(systemName: "checkmark").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }.buttonStyle(.plain).liveBoardGlass(radius: 22).accessibilityLabel("Done moving").accessibilityIdentifier("console.layout.done").padding(8) }; Spacer() }
                        }
                    }
                }
                if details, let app = selected { detailsOverlay(app, height: geometry.size.height) }
            }
            .coordinateSpace(name: "console.canvas")
            .foregroundColor(.white)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background {
            GeometryReader { fullScreen in backdrop(size: fullScreen.size) }
                .ignoresSafeArea()
                .accessibilityIdentifier("console.backdrop")
        }
        .background(LiveBoardLandscapeLock(enabled: mode == "cinematic" || (!launching && !launchReturned)))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $layoutSettings, onDismiss: bindController) { consoleLayoutSettings }
        .sheet(item: $appearanceApp, onDismiss: bindController) { app in LiveBoardAppAppearance(app: app.app) }
        .sheet(isPresented: $jitSetup, onDismiss: bindController) { LiveBoardJITSetup() }
        .sheet(isPresented: $utilitiesPresented, onDismiss: handleUtilitySelection) {
            gameBoxUtilitiesSheet
        }
        .sheet(isPresented: $tweakStorePresented, onDismiss: bindController) {
            BloomBoxTweakStore(apps: apps, focusedApp: nil)
        }
        .sheet(isPresented: $appStorePresented, onDismiss: bindController) {
            BloomBoxAppStore(apps: apps, openSources: {
                appStorePresented = false
                openSources?()
            })
        }
        .sheet(isPresented: $modulesPresented, onDismiss: handleModuleDismissed) {
            BloomBoxModulesPanel(apps: apps) { destination in
                pendingModuleDestination = destination
                modulesPresented = false
            }
        }
        .sheet(isPresented: $wallpaperSettings, onDismiss: handleWallpaperSettingsDismissed) {
            gameBoxWallpaperSettings
        }
        .sheet(isPresented: $choosingGameBoxPhoto, onDismiss: bindController) {
            LiveBoardWallpaperPicker { image in
                choosingGameBoxPhoto = false
                if let image { saveGameBoxPhoto(image) }
            }
        }
        .sheet(isPresented: $choosingGameBoxMotionPhotos, onDismiss: bindController) {
            BloomBoxMotionWallpaperPhotosPicker { result in
                choosingGameBoxMotionPhotos = false
                if let result {
                    switch result {
                    case .success(let name): installGameBoxMotion(name)
                    case .failure(let error): artworkError = error.localizedDescription
                    }
                }
            }
        }
        .fileImporter(isPresented: $choosingGameBoxMotionFiles,
                      allowedContentTypes: [.movie, .gif]) { result in
            switch result {
            case .success(let url):
                importingGameBoxMotion = true
                Task { @MainActor in
                    do {
                        let name = try await Task.detached(priority: .userInitiated) {
                            try ManzanaWallpaperMedia.importFile(url)
                        }.value
                        installGameBoxMotion(name)
                    } catch { artworkError = error.localizedDescription }
                    importingGameBoxMotion = false
                    bindController()
                }
            case .failure(let error): artworkError = error.localizedDescription
            }
        }
        .overlay {
            if importingGameBoxMotion {
                ProgressView("Preparando fondo GameBox…")
                    .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(true)
            }
        }
        .sheet(isPresented: $managingCategories, onDismiss: bindController) { categoryManager }
        .sheet(isPresented: $searching, onDismiss: bindController) { searchSheet }
        .sheet(item: $picker, onDismiss: bindController) { request in
            LiveBoardWallpaperPicker { image in
                if let image {
                    do { try artwork.save(image, for: request.key, kind: request.kind, mode: mode) }
                    catch { artworkError = error.localizedDescription }
                }
                picker = nil
            }
        }
        .alert("Artwork", isPresented: Binding(get: { artworkError != nil }, set: { if !$0 { artworkError = nil; bindController() } })) {
            Button("OK") { artworkError = nil; bindController() }
        } message: { Text(artworkError ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.pauseNotification)) { _ in controller.stop() }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.resumeNotification)) { _ in bindController() }
        .onAppear {
            migrateLibrariesIfNeeded()
            ramPlus.refresh()
            if mode == "cinematic" { gameBoxPhoto = UIImage(contentsOfFile: gameBoxPhotoURL.path) }
            bindController()
        }
        .onChange(of: navigation.selectedIndex) { _ in if sounds && scenePhase == .active { audio.play() } }
        .onDisappear { controller.stop(); audio.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                ramPlus.refresh()
                jitSwitchRevision &+= 1
                bindController()
            } else { controller.stop() }
        }
        .onChange(of: mode) { _ in activeCategory = nil; favoritesOnly = false; navigation = LiveBoardConsoleNavigation() }
        .onChange(of: keys) { _ in navigation.selectedIndex = min(navigation.selectedIndex, max(0, visibleApps.count - 1)) }
    }

    private func backdrop(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.065)
            if mode == "cinematic", gameBoxWallpaperStyle == "motion",
               let url = ManzanaWallpaperMedia.url(gameBoxMotionWallpaper),
               FileManager.default.fileExists(atPath: url.path) {
                ManzanaAnimatedWallpaper(url: url, fit: gameBoxWallpaperFit,
                                         paused: gameBoxPauseWallpaper || reduceMotion)
                    .id(gameBoxMotionWallpaper)
                    .frame(width: size.width, height: size.height).clipped()
                    .accessibilityIdentifier("gamebox.wallpaper.motion")
            } else if mode == "cinematic", gameBoxWallpaperStyle == "photo",
                      let gameBoxPhoto {
                Image(uiImage: gameBoxPhoto).resizable()
                    .aspectRatio(contentMode: gameBoxWallpaperFit ? .fit : .fill)
                    .frame(width: size.width, height: size.height).clipped()
                    .accessibilityIdentifier("gamebox.wallpaper.photo")
            } else if mode != "cinematic" || gameBoxWallpaperStyle == "dynamic" {
                if let app = selected {
                    if let image = artwork.image(for: liveBoardAppKey(app), kind: .background, mode: mode) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                    } else if let image = LiveBoardIconStore.background(app, dark: darkIcons) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: size.width, height: size.height).clipped()
                    }
                }
            }
            if mode == "cinematic" && gameBoxWallpaperStyle != "dynamic" {
                Color.black.opacity(gameBoxWallpaperDim)
            }
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.15), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.black.opacity(0.68), .clear], startPoint: .leading, endPoint: .trailing)
        }.id(mode == "cinematic" && gameBoxWallpaperStyle != "dynamic"
            ? "gamebox-fixed-wallpaper" : (selected.map(liveBoardAppKey) ?? "none"))
            .transition(.opacity).frame(width: size.width, height: size.height).clipped()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selected.map(liveBoardAppKey))
    }
    private func header(landscape: Bool) -> some View {
        HStack(spacing: landscape ? 18 : 8) {
            ForEach(0..<2, id: \.self) { index in
                Button {
                    favoritesOnly = index == 1
                    activeCategory = nil
                    navigation.selectedIndex = 0
                } label: {
                    Text(index == 0 ? "Library" : "Favorites")
                        .font(.system(size: landscape ? 20 : 18, weight: (activeCategory == nil && favoritesOnly == (index == 1)) ? .semibold : .regular))
                        .foregroundStyle(.white.opacity((activeCategory == nil && favoritesOnly == (index == 1)) ? 1 : 0.5))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            if navigation.focus == .header && navigation.headerIndex == index { Capsule().fill(.white).frame(height: 2) }
                        }
                }.accessibilityIdentifier(index == 0 ? "console.library" : "console.favorites")
            }
            Spacer(minLength: 0)
            Button { openSearch() } label: { Image(systemName: "magnifyingglass").frame(width: 36, height: 36) }.accessibilityLabel("Search").accessibilityIdentifier("console.search")
            Button { controller.stop(); openManagement() } label: {
                Image(systemName: "square.grid.2x2").frame(width: 36, height: 36)
                    .overlay(Circle().stroke(navigation.focus == .header && navigation.headerIndex == 2 ? .white : .clear, lineWidth: 2))
            }.accessibilityLabel("Manage apps").accessibilityIdentifier("console.manage")
            Button { controller.stop(); openInterface() } label: {
                Image(systemName: "gearshape").frame(width: 36, height: 36)
                    .overlay(Circle().stroke(navigation.focus == .header && navigation.headerIndex == 3 ? .white : .clear, lineWidth: 2))
            }.accessibilityLabel("Interface").accessibilityIdentifier("console.interface")
            if mode == "cinematic" {
                Button { controller.stop(); wallpaperSettings = true } label: {
                    Image(systemName: "photo.on.rectangle.angled").frame(width: 36, height: 36)
                        .overlay(Circle().stroke(navigation.focus == .header && navigation.headerIndex == 4 ? .white : .clear, lineWidth: 2))
                }.accessibilityLabel("Fondo de GameBox").accessibilityIdentifier("gamebox.wallpaper.open")
                Button { controller.stop(); utilitiesPresented = true } label: {
                    Image(systemName: "square.grid.2x2.fill").frame(width: 36, height: 36)
                        .overlay(Circle().stroke(navigation.focus == .header && navigation.headerIndex == 5 ? .white : .clear, lineWidth: 2))
                }.accessibilityLabel("Utilidades de BloomBox").accessibilityIdentifier("gamebox.utilities.open")
            }
        }.buttonStyle(.plain).frame(maxWidth: .infinity).frame(height: 40)
    }
    private func migrateLibrariesIfNeeded() {
        var all = libraries
        let previous = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        var changed = false
        for name in ["cinematic", "bigPicture"] where all[name] == nil {
            var state = LiveBoardModeLibrary(); state.assignments = previous
            for category in previous.values.sorted() where !state.categories.contains(category) { state.categories.append(category) }
            all[name] = state; changed = true
        }
        if var gameBox = all["cinematic"] {
            let before = gameBox
            gameBox.migrateGameBoxCategories()
            if gameBox != before {
                all["cinematic"] = gameBox
                changed = true
            }
        }
        if changed, let data = try? JSONEncoder().encode(all), let value = String(data: data, encoding: .utf8) { modeLibraries = value }
    }
    private var categoryTabs: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(library.categories, id: \.self) { name in
                        Button { activeCategory = activeCategory == name ? nil : name; favoritesOnly = false; navigation.selectedIndex = 0 } label: {
                            Text(name).font(.system(size: 13, weight: activeCategory == name ? .bold : .regular)).foregroundStyle(.white.opacity(activeCategory == name ? 1 : 0.55)).padding(.vertical, 6)
                        }.accessibilityIdentifier("console.category." + name)
                    }
                }
            }
            Button { controller.stop(); layoutSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 32, height: 32) }.accessibilityLabel("Customize layout").accessibilityIdentifier("console.layout")
            if mode == "cinematic" {
                HStack(spacing: 3) {
                    Image(systemName: "memorychip.fill").font(.system(size: 15))
                    Text("RAM+").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(ramPlus.validation.confirmed && ramPlus.extensionSigned == true
                                 ? Color.green : Color.orange)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ramPlus.validation.confirmed && ramPlus.extensionSigned == true
                                    ? "RAM+ habilitada" : "RAM+ sin confirmar")
                .accessibilityIdentifier("gamebox.ram.status")
                Button {
                    guard selected != nil else { return }
                    controller.stop()
                    quickJITPresented = true
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(selected.map(jitEnabled(for:)) == true
                                         ? Color.green : Color.orange)
                        .frame(width: 32, height: 32)
                }
                .disabled(selected == nil)
                .popover(isPresented: $quickJITPresented) {
                    gameBoxJITQuickSettings.onDisappear(perform: bindController)
                }
                .accessibilityLabel(selected.map(jitEnabled(for:)) == true
                                    ? "JIT activado para la app seleccionada"
                                    : "JIT desactivado para la app seleccionada")
                .accessibilityIdentifier("gamebox.jit.quickToggle")
            } else {
                Button { controller.stop(); jitSetup = true } label: {
                    Image(systemName: "bolt.fill").frame(width: 32, height: 32)
                }.accessibilityLabel("JIT setup")
            }
            Button { controller.stop(); managingCategories = true } label: { Image(systemName: "tag").overlay(alignment: .bottomTrailing) { Image(systemName: "plus.circle.fill").font(.system(size: 10)).offset(x: 5, y: 5) }.frame(width: 32, height: 32) }.accessibilityLabel("Categories and hidden apps").accessibilityIdentifier("console.categories.manage")
        }.buttonStyle(.plain).frame(height: 28)
    }
    private var categoryManager: some View {
        NavigationView {
            Form {
                Section("Categories for this mode") {
                    HStack { TextField("New category", text: $newCategory).accessibilityIdentifier("console.category.name"); Button("Add") { updateLibrary { _ = $0.addCategory(newCategory) }; newCategory = "" }.accessibilityIdentifier("console.category.add").disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    ForEach(library.categories, id: \.self) { name in
                        HStack { Text(name); Spacer(); Button(role: .destructive) { updateLibrary { $0.removeCategory(name) }; if activeCategory == name { activeCategory = nil } } label: { Image(systemName: "trash") } }
                    }
                }
                Section("Apps in this mode") {
                    ForEach(apps, id: \.self) { app in
                        VStack(alignment: .leading) {
                            Toggle(appCustomization.name(app), isOn: Binding(get: { !library.hidden.contains(liveBoardAppKey(app)) }, set: { show in updateLibrary { if show { $0.hidden.remove(liveBoardAppKey(app)) } else { $0.hidden.insert(liveBoardAppKey(app)) } } }))
                            Picker("Category", selection: Binding(get: { library.assignments[liveBoardAppKey(app)] ?? "" }, set: { name in updateLibrary { $0.assignments[liveBoardAppKey(app)] = name.isEmpty ? nil : name } })) {
                                Text("Uncategorized").tag("")
                                ForEach(library.categories, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                }
                Section { Toggle("Navigation sounds", isOn: $sounds) }
            }.navigationTitle("Categories & visibility")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { managingCategories = false } } }
        }.navigationViewStyle(.stack)
    }
    private func changeSection(_ delta: Int) {
        let sections = ["Library", "Favorites"] + library.categories
        let current = activeCategory.flatMap { sections.firstIndex(of: $0) } ?? (favoritesOnly ? 1 : 0)
        let index = (current + delta + sections.count) % sections.count
        favoritesOnly = index == 1; activeCategory = index >= 2 ? sections[index] : nil; navigation.selectedIndex = 0
    }
    private func carousel(landscape: Bool, scale: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: bigPicture ? 14 : 12) {
                    ForEach(Array(visibleApps.enumerated()), id: \.element) { index, app in
                        let focused = selected == app
                        Button {
                            navigation.selectedIndex = index; navigation.focus = .rail
                        } label: {
                            cover(app, selected: focused, landscape: landscape, scale: scale)
                        }
                        .buttonStyle(.plain)
                        // Double-tap toggles Favorites; a single tap still only selects.
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            favorite(app)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        })
                        .contextMenu {
                            Button(favoriteKeys.contains(liveBoardAppKey(app))
                                   ? "Quitar de favoritos" : "Añadir a favoritos",
                                   systemImage: "star.fill") { favorite(app) }
                            if mode == "cinematic" {
                                Menu("Categoría", systemImage: "tag.fill") {
                                    ForEach(["Games", "Ports", "Emuladores"], id: \.self) { name in
                                        Button {
                                            updateLibrary { $0.assignments[liveBoardAppKey(app)] = name }
                                            if activeCategory != nil { activeCategory = nil }
                                        } label: {
                                            Label(name, systemImage: library.assignments[liveBoardAppKey(app)] == name
                                                  ? "checkmark.circle.fill" : "circle")
                                        }
                                    }
                                    Button("Sin categoría") {
                                        updateLibrary { $0.assignments[liveBoardAppKey(app)] = nil }
                                        activeCategory = nil
                                    }
                                }
                            }
                            Button("Más opciones", systemImage: "ellipsis.circle") {
                                navigation.selectedIndex = visibleApps.firstIndex(of: app) ?? 0
                                showDetails()
                            }
                        }
                        .id(liveBoardAppKey(app))
                        .accessibilityLabel(appCustomization.name(app))
                        .accessibilityValue(focused ? "Selected" : "")
                        .accessibilityIdentifier("console.tile.\(liveBoardAppKey(app))")
                        .accessibilityAddTraits(focused ? .isSelected : [])
                    }
                }.padding(5)
            }
            .frame(height: (bigPicture ? (landscape ? 126 : 196) : (landscape ? 116 : 142)) * scale)
            .task(id: selected.map(liveBoardAppKey)) {
                guard let app = selected else { return }
                // Let the newly selected cover's width settle before calculating its scroll position.
                try? await Task.sleep(nanoseconds: 20_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { proxy.scrollTo(liveBoardAppKey(app), anchor: .center) }
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.018), .init(color: .black, location: 0.982), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
            .accessibilityIdentifier("console.rail")
        }
    }
    private func cover(_ app: LCAppModel, selected: Bool, landscape: Bool, scale: CGFloat) -> some View {
        let h: CGFloat = (bigPicture ? (landscape ? 112 : 180) : (selected ? (landscape ? 106 : 128) : (landscape ? 78 : 88))) * scale
        let w: CGFloat = bigPicture ? (selected ? h * 1.7 : h * 0.68) : h
        return ZStack {
            Color(white: 0.08)
            if let image = artwork.image(for: liveBoardAppKey(app), kind: bigPicture && !selected ? .portrait : .cover, mode: mode) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: w, height: h).clipped()
            } else {
                LiveBoardIconImage(app: app, dark: darkIcons).frame(width: bigPicture ? h * 0.65 : h, height: bigPicture ? h * 0.65 : h)
            }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: bigPicture ? 5 : 18, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: selected)
        .overlay(RoundedRectangle(cornerRadius: bigPicture ? 5 : 18, style: .continuous).strokeBorder(.white.opacity(selected ? 0.9 : 0), lineWidth: selected ? 2 : 0))

    }
    @ViewBuilder private func hero(landscape: Bool) -> some View {
        if let app = selected {
            VStack(alignment: .leading, spacing: landscape ? 4 : 14) {
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Text(category(app).uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.5)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    if favoriteKeys.contains(liveBoardAppKey(app)) { Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow) }
                }
                Text(appCustomization.name(app)).font(.system(size: landscape ? 28 : 38, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.35), radius: 8)
                    .accessibilityIdentifier("console.selected.title")
                if launchReturned {
                    Button("Resume controller navigation") { launchReturned = false; bindController() }.font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: landscape ? 4 : 28)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text(favoritesOnly ? "Your favorites" : "Your library").font(.largeTitle.bold())
                Text(favoritesOnly ? "Add favorites from an app’s options." : "Install your first app to get started.").foregroundStyle(.white.opacity(0.6))
                Button(favoritesOnly ? "All apps" : "Manage apps") {
                    if favoritesOnly { favoritesOnly = false } else { controller.stop(); openManagement() }
                }.buttonStyle(.bordered)
                Spacer()
            }
        }
    }
    private func launchControls(_ app: LCAppModel) -> some View {
        HStack(spacing: 12) {
                    Button { if !movingLaunchButton { activate(app) } } label: {
                        HStack(spacing: 9) {
                            if launching { ProgressView().tint(.white) } else { Image(systemName: "play.fill").font(.system(size: 14)) }
                            Text(category(app) == "Games" ? "Play Game" : "Launch App").font(.system(size: 17, weight: .semibold))
                        }.frame(minWidth: 140, minHeight: 46)
                    }
                    .liveBoardGlass(radius: 23)
                    .overlay(Capsule().stroke(navigation.focus == .launch ? .white : .clear, lineWidth: 2))
                    .disabled(launching || app.isAppRunning || app.isSigningInProgress)
                    .accessibilityIdentifier("console.launch")
                    Button { showDetails() } label: { Image(systemName: "ellipsis").font(.system(size: 22, weight: .semibold)).frame(width: 46, height: 46) }
                        .liveBoardGlass(radius: 23)
                        .overlay(Circle().stroke(navigation.focus == .details ? .white : .clear, lineWidth: 2))
                        .accessibilityLabel("App options").accessibilityIdentifier("console.options")
                }.buttonStyle(.plain).padding(.top, 2)
    }
    private func jitEnabled(for app: LCAppModel) -> Bool {
        // The UI and launch path share exactly the same saved per-app policy.
        // Checking a debugger's availability is NOT the same as JIT being
        // requested; this indicator deliberately displays only the preference.
        _ = jitSwitchRevision
        let bundle = Bundle(path: app.appInfo.bundlePath())
        let melonNX26 = BloomBoxMeloNXProfile.matches(
            bundleID: app.appInfo.bundleIdentifier(),
            version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let policy = BloomBoxJITGuestPolicy.mode(
            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
        return BloomBoxJITGuestPolicy.wantsJIT(
            automatic: app.appInfo.isJITNeeded || app.appInfo.is32bit || melonNX26,
            forced: nil, mode: policy)
    }

    private func setJIT(_ enabled: Bool, for app: LCAppModel) {
        BloomBoxJITGuestPolicy.setMode(enabled ? .enabled : .disabled,
            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
        jitSwitchRevision &+= 1
    }

    private var gameBoxJITQuickSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("JIT por aplicación", systemImage: "bolt.fill")
                .font(.headline)
            if let app = selected {
                Text(appCustomization.name(app))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Toggle("Habilitar JIT", isOn: Binding(
                    get: { jitEnabled(for: app) },
                    set: { setJIT($0, for: app) }))
                    .tint(.green)
                    .accessibilityIdentifier("gamebox.jit.app.toggle")
                Text("Verde: JIT solicitado al abrir. Naranja: se abre sin JIT. El cambio se aplica en el próximo lanzamiento.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Selecciona un juego primero.").foregroundStyle(.secondary)
            }
            Button("Listo") { quickJITPresented = false }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 310)
    }

    private var gameBoxUtilitiesSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 14) {
                    ForEach(GameBoxUtility.allCases) { utility in
                        Button {
                            pendingUtility = utility
                            utilitiesPresented = false
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: utility.symbol)
                                    .font(.system(size: 27, weight: .semibold))
                                    .frame(width: 54, height: 54)
                                    .foregroundStyle(.white)
                                    .background(Color.purple.opacity(0.23),
                                                in: RoundedRectangle(cornerRadius: 16))
                                Text(utility.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("gamebox.utility." + utility.rawValue)
                    }
                }.padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.11).ignoresSafeArea())
            .navigationTitle("Apps de BloomBox")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { utilitiesPresented = false }
                }
            }
        }.navigationViewStyle(.stack)
    }

    private func handleUtilitySelection() {
        guard let utility = pendingUtility else { bindController(); return }
        pendingUtility = nil
        switch utility {
        case .modules: modulesPresented = true
        case .tweakStore: tweakStorePresented = true
        case .appStore: appStorePresented = true
        case .install: openInstall?()
        case .sideStore: openSideStore?()
        case .themes: openThemeStore?()
        }
    }

    private var gameBoxWallpaperSettings: some View {
        NavigationView {
            Form {
                Section("Fondo de GameBox") {
                    Picker("Tipo de fondo", selection: $gameBoxWallpaperStyle) {
                        Text("Dinámico por juego").tag("dynamic")
                        Text("Foto").tag("photo")
                        Text("GIF o video").tag("motion")
                    }
                    .accessibilityIdentifier("gamebox.wallpaper.style")
                    Text("Este fondo es independiente del escritorio iOS. El modo dinámico muestra las ilustraciones de cada juego.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Seleccionar") {
                    Button("Foto de la galería") {
                        pendingWallpaperPicker = .photo
                        wallpaperSettings = false
                    }
                    Button("GIF o video de Fotos") {
                        pendingWallpaperPicker = .photosMotion
                        wallpaperSettings = false
                    }
                    Button("GIF o video de Archivos") {
                        pendingWallpaperPicker = .filesMotion
                        wallpaperSettings = false
                    }
                    .accessibilityIdentifier("gamebox.wallpaper.files")
                }
                if gameBoxWallpaperStyle == "photo" || gameBoxWallpaperStyle == "motion" {
                    Section("Apariencia") {
                        Toggle("Mostrar imagen completa", isOn: $gameBoxWallpaperFit)
                        HStack {
                            Text("Oscurecer fondo")
                            Slider(value: $gameBoxWallpaperDim, in: 0...0.65)
                        }
                        if gameBoxWallpaperStyle == "motion" {
                            Toggle("Pausar animación", isOn: $gameBoxPauseWallpaper)
                        }
                    }
                }
                Section {
                    Button("Usar fondo dinámico otra vez") { gameBoxWallpaperStyle = "dynamic" }
                }
            }
            .navigationTitle("Fondo de GameBox")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { wallpaperSettings = false }
            }}
        }.navigationViewStyle(.stack)
    }

    private func handleWallpaperSettingsDismissed() {
        guard let next = pendingWallpaperPicker else { bindController(); return }
        pendingWallpaperPicker = nil
        DispatchQueue.main.async {
            switch next {
            case .photo: choosingGameBoxPhoto = true
            case .photosMotion: choosingGameBoxMotionPhotos = true
            case .filesMotion: choosingGameBoxMotionFiles = true
            }
        }
    }

    private func handleModuleDismissed() {
        jitSwitchRevision &+= 1
        ramPlus.refresh()
        guard let destination = pendingModuleDestination else { bindController(); return }
        pendingModuleDestination = nil
        switch destination {
        case .jit: jitSetup = true
        case .desktop, .wallpaper: wallpaperSettings = true
        case .interface: openInterface()
        case .apps: openManagement()
        default: openModuleDestination?(destination)
        }
    }

    private func saveGameBoxPhoto(_ image: UIImage) {
        do {
            let size = image.size
            guard size.width > 0 && size.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
            let factor = min(1, 2400 / max(size.width, size.height))
            let scaled = CGSize(width: size.width * factor, height: size.height * factor)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let result = UIGraphicsImageRenderer(size: scaled, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaled))
            }
            guard let data = result.jpegData(compressionQuality: 0.88) else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: gameBoxPhotoURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: gameBoxPhotoURL, options: .atomic)
            gameBoxPhoto = result
            gameBoxWallpaperStyle = "photo"
        } catch { artworkError = error.localizedDescription }
    }

    private func installGameBoxMotion(_ name: String) {
        let previous = gameBoxMotionWallpaper
        gameBoxMotionWallpaper = name
        gameBoxWallpaperStyle = "motion"
        // Do not remove an asset still selected by the independent iOS Home.
        let iosName = LCUtils.appGroupUserDefault.string(forKey: "ManzanaMotionWallpaper") ?? ""
        if previous != name, previous != iosName, let old = ManzanaWallpaperMedia.url(previous) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    private var consoleLayoutSettings: some View {
        NavigationView {
            Form {
                Section("Cover size") {
                    Slider(value: Binding(get: { consoleLayout.iconScale }, set: { value in updateConsoleLayout { $0.iconScale = value } }), in: 0.65...2.5)
                        .accessibilityIdentifier("console.layout.scale")
                    Text("\(Int(consoleLayout.iconScale * 100))% · Size is limited to the available screen height.").font(.footnote)
                }
                if mode != "cinematic" {
                    Section("Play button size") {
                        Slider(value: Binding(get: { consoleLayout.launchScale }, set: { value in updateConsoleLayout { $0.launchScale = value } }), in: 0.75...2)
                            .accessibilityIdentifier("console.layout.buttonScale")
                        Text("\(Int(consoleLayout.launchScale * 100))%").font(.footnote)
                    }
                    Section("Launch button position") {
                        Text("Horizontal")
                        Slider(value: Binding(get: { consoleLayout.launchX }, set: { value in updateConsoleLayout { $0.launchX = value } }), in: 0...1)
                        Text("Vertical")
                        Slider(value: Binding(get: { consoleLayout.launchY }, set: { value in updateConsoleLayout { $0.launchY = value } }), in: 0...1)
                        Button("Drag button on screen") { layoutSettings = false; movingLaunchButton = true }
                    }
                } else {
                    Section {
                        Text("El botón de inicio de GameBox permanece abajo a la derecha y nunca cubre el nombre del juego.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Reset this mode’s layout") { savedConsoleLayouts = LiveBoardConsoleLayout.save(LiveBoardConsoleLayout(), mode: mode, in: savedConsoleLayouts) }
                    Text("GameBox and legacy Big Picture keep separate layouts.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Customize layout")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if mode != "cinematic" {
                            Button("Move button") { layoutSettings = false; movingLaunchButton = true }
                                .accessibilityIdentifier("console.layout.drag")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { layoutSettings = false } }
                }
        }.navigationViewStyle(.stack)
    }
    private var footer: some View {
        HStack(spacing: 16) {
            Text(bigPicture ? "STRATA / BIG PICTURE" : "BLOOMBOX / GAMEBOX")
                .font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 0)
            if controller.connected {
                Label("Launch", systemImage: controller.confirmSymbol)
                Label("Options", systemImage: controller.detailsSymbol)
            } else { Image(systemName: "gamecontroller").foregroundStyle(.white.opacity(0.4)).accessibilityLabel("Connect a controller to navigate") }
        }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
    }
    private func detailsOverlay(_ app: LCAppModel, height: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { details = false }
            VStack(alignment: .leading, spacing: 10) {
                Text(appCustomization.name(app)).font(.headline).lineLimit(1)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach((0..<10).filter { bigPicture || $0 != 6 }, id: \.self) { index in
                                Button { detailAction(index, app: app) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: ["play.fill", "gearshape", "photo", "rectangle", "star", "arrow.counterclockwise", "rectangle.portrait", "eye.slash", "bolt.fill", "pencil"][index]).frame(width: 24)
                                        Text(["Launch", "App settings", "Choose landscape cover", "Choose background", favoriteKeys.contains(liveBoardAppKey(app)) ? "Remove favorite" : "Add favorite", "Reset artwork", "Choose portrait cover", "Hide in this mode", "Launch with JIT", "Rename / change app icon"][index]).font(.system(size: 15))
                                        Spacer(minLength: 0)
                                    }.padding(10).frame(minHeight: 40).background(detailsIndex == index ? .white.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).id(index).accessibilityIdentifier("console.option.\(index)")
                            }
                        }
                    }.accessibilityIdentifier("console.options.scroll").onChange(of: detailsIndex) { index in proxy.scrollTo(index) }
                }
                Button("Close") { details = false }.frame(maxWidth: .infinity, minHeight: 36).accessibilityIdentifier("console.options.close")
            }.padding(16).frame(width: 340).frame(maxHeight: max(160, height - 24))
                .liveBoardGlass(radius: 24, interactive: false).padding(.horizontal, 12)
        }.accessibilityAddTraits(.isModal)
    }
    private var searchSheet: some View {
        NavigationView {
            List {
                ForEach(apps.filter { query.isEmpty || appCustomization.name($0).localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query) }, id: \.self) { app in
                    Button {
                        favoritesOnly = false; activeCategory = nil
                        updateLibrary { $0.hidden.remove(liveBoardAppKey(app)) }
                        navigation.selectedIndex = visibleApps.firstIndex(of: app) ?? 0
                        navigation.focus = .rail; searching = false
                    } label: {
                        HStack(spacing: 12) {
                            LiveBoardIconImage(app: app, dark: darkIcons).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 11))
                            Text(appCustomization.name(app)).foregroundStyle(.primary)
                        }
                    }.buttonStyle(.plain)
                }
            }.searchable(text: $query, prompt: "Search library")
                .navigationTitle("Library").navigationBarHidden(false)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { searching = false } } }
        }.navigationViewStyle(.stack)
    }
    private func category(_ app: LCAppModel) -> String {
        return library.assignments[liveBoardAppKey(app)] ?? "App"
    }
    private func favorite(_ app: LCAppModel) {
        var keys = favoriteKeys; let key = liveBoardAppKey(app)
        if keys.contains(key) { keys.removeAll { $0 == key } } else { keys.append(key) }
        if let data = try? JSONEncoder().encode(keys), let string = String(data: data, encoding: .utf8) { favorites = string }
    }
    private func openSearch() { controller.stop(); searching = true }
    private func showDetails() { guard selected != nil else { return }; detailsIndex = 0; details = true }
    private func detailAction(_ index: Int, app: LCAppModel) {
        switch index {
        case 0: details = false; activate(app)
        case 1: details = false; controller.stop(); manage(app)
        case 2, 3, 6:
            details = false; controller.stop()
            picker = ArtworkRequest(key: liveBoardAppKey(app), kind: index == 2 ? .cover : (index == 6 ? .portrait : .background))
        case 8: details = false; activate(app, forceJIT: true)
        case 9: details = false; controller.stop(); appearanceApp = LiveBoardAppearanceSelection(app: app)
        case 4: favorite(app)
        case 7: updateLibrary { $0.hidden.insert(liveBoardAppKey(app)) }; details = false
        case 5:
            artwork.remove(for: liveBoardAppKey(app), kind: .cover, mode: mode)
            artwork.remove(for: liveBoardAppKey(app), kind: .background, mode: mode)
            artwork.remove(for: liveBoardAppKey(app), kind: .portrait, mode: mode)
        default: break
        }
    }
    private func activate(_ app: LCAppModel, forceJIT: Bool = false) {
        guard !launching, !movingLaunchButton else { return }
        let launcherWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first { $0.isKeyWindow }
        if mode != "cinematic" {
            LiveBoardOrientation.setLandscape(false, window: launcherWindow)
        }
        controller.stop(); audio.stop(); launching = true
        Task { @MainActor in
            // This actual rendered console knows whether we are in Game.
            // Do not ask AppStorage again during a pending scene rotation.
            let fromGame = mode == "cinematic"
            if forceJIT, let launchWithJIT { await launchWithJIT(app, fromGame) }
            else { await launch(app, fromGame) }
            launching = false
            // Do not reclaim the gamepad after a guest starts in-process.
            // Scene reactivation or an explicit touch resumes launcher input after a canceled launch.
            launchReturned = true
        }
    }
    private func bindController() {
        guard scenePhase == .active, !searching, !managingCategories, !jitSetup,
              !modulesPresented, !utilitiesPresented, !tweakStorePresented,
              !appStorePresented, !quickJITPresented, !wallpaperSettings, !choosingGameBoxPhoto,
              !choosingGameBoxMotionPhotos, !choosingGameBoxMotionFiles,
              !importingGameBoxMotion, !layoutSettings, !movingLaunchButton,
              appearanceApp == nil, picker == nil, artworkError == nil, !launching else { return }
        controller.onCommand = { command in handle(command) }
        controller.start()
    }
    private func handle(_ command: LiveBoardControllerInput.Command) {
        guard !launching, !movingLaunchButton else { return }
        if details {
            switch command {
            case .up: detailsIndex = max(0, detailsIndex - 1); if !bigPicture && detailsIndex == 6 { detailsIndex = 5 }
            case .down: detailsIndex = min(9, detailsIndex + 1); if !bigPicture && detailsIndex == 6 { detailsIndex = 7 }
            case .confirm: if let app = selected { detailAction(detailsIndex, app: app) }
            case .back, .details: details = false
            default: break
            }
            return
        }
        switch command {
        case .confirm:
            if navigation.focus == .header {
                switch navigation.headerIndex {
                case 0: favoritesOnly = false
                case 1: favoritesOnly = true
                case 2: controller.stop(); openManagement()
                case 3: controller.stop(); openInterface()
                case 4 where mode == "cinematic": controller.stop(); wallpaperSettings = true
                case 5 where mode == "cinematic": controller.stop(); utilitiesPresented = true
                default: controller.stop(); openInterface()
                }
            } else if navigation.focus == .details { showDetails() }
            else if let app = selected { activate(app) }
        case .details: showDetails()
        case .favorite: if let app = selected { favorite(app) }
        case .previousSection: changeSection(-1)
        case .nextSection: changeSection(1)
        default: navigation.move(command, count: visibleApps.count, headerCount: mode == "cinematic" ? 6 : 4)
        }
    }
}
