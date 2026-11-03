import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

struct BloomBoxHomeScreen: View {
    let apps: [LCAppModel]
    let launch: (LCAppModel) -> Void
    let manage: (LCAppModel) -> Void
    let uninstall: (LCAppModel) -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    let openSideStore: () -> Void
    let openInstall: () -> Void
    let openTab: (LCTabIdentifier) -> Void
    let installInProgress: Bool
    let installProgress: Double
    let secondaryInstance: Bool
    var launchWithJIT: ((LCAppModel) -> Void)? = nil
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var appCustomization = LiveBoardAppCustomization.shared
    @State private var appearanceApp: LiveBoardAppearanceSelection?
    @State private var jitSetup = false
    @State private var tweakStorePresented = false
    @State private var appStorePresented = false
    @State private var modulesPresented = false
    @State private var themesPresented = false
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var englishUI: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    @ObservedObject private var ramPlus = BloomBoxRAMPlus.shared
    @State private var pendingModuleDestination: BloomBoxModulesPanel.Destination?
    @State private var storeFocusedApp: LCAppModel?
    @State private var pendingAlertApp: LCAppModel?
    @State private var pendingAlertTweak: BloomBoxTweakEntry?
    @State private var pendingAlertJIT = false
    @State private var showTweakLevel3Alert = false
    @ObservedObject private var tweakCatalog = BloomBoxTweakCatalog.shared
    @AppStorage("LiveBoardHomeCategories", store: LCUtils.appGroupUserDefault) private var homeCategories = "[\"Games\",\"Ports\",\"Tools\"]"
    @State private var addingCategory = false
    @State private var categoryName = ""
    @State private var categoryApp: String?

    @AppStorage("BloomBoxHomeLayout", store: LCUtils.appGroupUserDefault) private var savedLayout = ""
    @AppStorage("LiveBoardFavorites", store: LCUtils.appGroupUserDefault) private var favorites = "[]"
    @AppStorage("LiveBoardCategories", store: LCUtils.appGroupUserDefault) private var categories = "{}"
    @AppStorage("LiveBoardLargeIcons", store: LCUtils.appGroupUserDefault) private var largeIcons = false
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkIcons = false
    @AppStorage("LiveBoardWallpaperStyle", store: LCUtils.appGroupUserDefault) private var wallpaperStyle = "red"
    @AppStorage("LiveBoardWallpaperFit", store: LCUtils.appGroupUserDefault) private var wallpaperFit = false
    @AppStorage("LiveBoardWallpaperDim", store: LCUtils.appGroupUserDefault) private var wallpaperDim = 0.1
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("LiveBoardReduceMotion", store: LCUtils.appGroupUserDefault) private var customReduceMotion = false
    @AppStorage("LiveBoardHiddenPages", store: LCUtils.appGroupUserDefault) private var hiddenPagesJSON = "[]"
    private var reduceMotion: Bool { systemReduceMotion || customReduceMotion }
    @AppStorage("BloomBoxBuiltInFolderMigrated", store: LCUtils.appGroupUserDefault)
    private var builtInFolderMigrated = false
    @AppStorage("BloomBoxWidgetMissingAppFallbacks", store: LCUtils.appGroupUserDefault)
    private var widgetFallbacksJSON = "{}"
    @AppStorage("BloomBoxLivingWidgetSettings", store: LCUtils.appGroupUserDefault)
    private var livingWidgetSettingsJSON = "{}"
    @State private var themeExportURL: URL?
    @State private var themeExportError: String?
    @State private var layout = BloomBoxHomeLayout()
    @State private var page = 1
    @State private var homeHasAppeared = false
    @AppStorage("BloomBoxAliveEnabled", store: LCUtils.appGroupUserDefault)
    private var aliveEnabled = true
    @AppStorage("BloomBoxAliveIdleEnabled", store: LCUtils.appGroupUserDefault)
    private var aliveIdleEnabled = true
    @State private var aliveStartupPlayed = false
    @State private var aliveBooting = false
    @State private var aliveIntroVisible = false
    @State private var aliveRevealed = true
    @State private var aliveStartupPage = 1
    @State private var aliveVisibleIcons: Set<String> = []
    @State private var alivePlayfulKey: String?
    @State private var alivePlayfulStyle = 0
    @State private var alivePlayfulActive = false
    @State private var aliveLastInteraction = Date()
    @State private var aliveSplashLine = "El desmadre está por comenzar."
    @AppStorage("BloomBoxAlivePreviousSplash", store: LCUtils.appGroupUserDefault)
    private var alivePreviousSplash = ""
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault) private var miniatureNote = ""
    @State private var miniatureWidgetPhoto: UIImage?
    @State private var desktopSettings = false
    @State private var editing = false
    @State private var showWidgetGallery = false
    @State private var selectedWidgetID: String?
    @AppStorage("ManzanaPageWidgets", store: LCUtils.appGroupUserDefault) private var pageWidgetsJSON = "{}"
    @AppStorage("BloomBoxPlacedWidgetsV2", store: LCUtils.appGroupUserDefault) private var placedWidgetsJSON = "{}"
    @AppStorage("BloomBoxPlacedWidgetsMigrated", store: LCUtils.appGroupUserDefault) private var placedWidgetsMigrated = false
    @State private var widgetMediaID: String?
    @State private var widgetMediaChoicePresented = false
    @State private var pendingWidgetMediaAfterGallery: String?
    @State private var widgetMediaImporting = false
    @State private var choosingWidgetFile = false
    @State private var choosingWidgetPhoto = false
    @State private var editingWidgetNote = false
    @State private var widgetMediaError: String?
    @State private var startupNoticesEnabled = false
    @State private var pendingRemovalKey: String?
    @State private var pendingUninstall: LCAppModel?
    @State private var pendingTweakApp: LCAppModel?
    @State private var choosingAppTweak = false
    @State private var appTweakError: String?
    @State private var networkNoticeText: String?
    @State private var networkNoticeToken = UUID()
    @State private var removedIcon: String?
    @State private var pageManager = false
    @State private var pendingPageRemoval: Int?
    @State private var desktopAction: DesktopAction?
    @State private var searching = false
    @State private var query = ""
    @State private var libraryQuery = ""
    @AppStorage("ManzanaLibraryRecents", store: LCUtils.appGroupUserDefault) private var libraryRecentsJSON = "[]"
    @FocusState private var librarySearchFocused: Bool
    @State private var expandedLibraryCategory: LibrarySection?
    @FocusState private var searchFocused: Bool
    @State private var customizing = false
    @State private var iconCustomization = false
    @State private var choosingWallpaper = false
    @State private var choosingMotionWallpaper = false
    @State private var choosingMotionWallpaperPhotos = false
    @State private var importingMotionWallpaper = false
    @AppStorage("ManzanaMotionWallpaper", store: LCUtils.appGroupUserDefault) private var motionWallpaper = ""
    @AppStorage("ManzanaPauseWallpaper", store: LCUtils.appGroupUserDefault) private var pauseWallpaper = false
    @State private var wallpaper: UIImage?
    @State private var openFolder: String?
    @State private var folderPage = 0
    @State private var renameKey: String?
    @State private var renameValue = ""
    @State private var newFolderApp: String?
    @State private var folderName = ""
    @State private var wallpaperError: String?

    private struct LibrarySection: Identifiable {
        let title: String
        let keys: [String]
        var id: String { title }
    }

    private static let sideStoreKey = "manzana:sidestore"
    private static let installKey = "manzana:install"
    private static let tweakStoreKey = "manzana:tweakstore"
    private static let appStoreKey = "manzana:appstore"
    private static let modulesKey = "manzana:modules"
    // Permanent shortcut ID for future theme export and import.
    private static let themesKey = "manzana:themes"

    // Original, short rotating splash messages — reminiscent of playful game menus.
    private static let aliveSplashLines = [
        "El desmadre está por comenzar.",
        "Más vivo que nunca. 🫧",
        "¿Y si le movemos a todo?",
        "No despiertes a los widgets.",
        "40 GB… yo no fui. 👀",
        "Cuidado: iconos hiperactivos.",
        "JIT me if you can. ⚡",
        "La RAM no crece en árboles.",
        "La ola ya viene. 🌊",
        "Si brinca, no es un bug.",
        "Yamcha no vio venir esto.",
        "Modo travesura activado.",
        "¿Quién dejó suelto al Dock?",
        "No es magia, es BloomBox.",
        "Se aceptan ideas locas.",
        "Despertando a los iconos…",
        "Tu iPhone no esperaba esto.",
        "Esto se está poniendo bueno.",
        "¡Ya llegó el relajo!",
        "100 % hecho con desmadre.",
        "Más personalidad, menos menús.",
        "¿Otra IPA? Va, dale.",
        "Los widgets tienen sueño.",
        "Si tiembla, saluda.",
        "La siguiente pantalla te espera."
    ]
    private enum DesktopAction { case interface, sources, tweaks, wallpaper, apps, settings, jit }

    private var appKeys: [String] {
        apps.filter { !($0.appInfo is BuiltInSideStoreAppInfo) }.map(liveBoardAppKey)
            + [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey, Self.themesKey]
    }
    private var appMap: [String: LCAppModel] {
        Dictionary(apps.filter { !($0.appInfo is BuiltInSideStoreAppInfo) }.map {
            (liveBoardAppKey($0), $0)
        }, uniquingKeysWith: { first, _ in first })
    }
    private var homeNavigation: BloomBoxHomeNavigation {
        BloomBoxHomeNavigation(pageCount: layout.pages.count, currentPage: page,
                               hiddenJSON: hiddenPagesJSON)
    }
    private var hiddenPageIndices: Set<Int> { homeNavigation.hidden }
    private var visiblePageIndices: [Int] { homeNavigation.visible }
    private var libraryPageIndex: Int { homeNavigation.libraryPage }
    private var recentLibraryKeys: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(libraryRecentsJSON.utf8))) ?? []
    }
    private var favoriteKeys: [String] { (try? JSONDecoder().decode([String].self, from: Data(favorites.utf8))) ?? [] }
    private var wallpaperURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true).appendingPathComponent("wallpaper.jpg")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                background
                    .blur(radius: (searching || page == libraryPageIndex) ? 14 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: page == libraryPageIndex)
                // Render every page in the full GeometryReader. The old VStack
                // permanently reserved ~140pt for a Dock that is hidden on
                // Widgets and App Library, leaving a blank strip and clipping
                // the bottom rows of the library.
                ZStack(alignment: .bottom) {
                    TabView(selection: $page) {
                        BloomBoxNewsPage(openSettings: { desktopSettings = true })
                            .tag(0)
                        ForEach(visiblePageIndices, id: \.self) { index in
                            homePage(index,
                                     width: geometry.size.width,
                                     height: max(400, geometry.size.height - 146))
                                // Home pages still reserve space for their Dock;
                                // Widgets and App Library use the full viewport.
                                .padding(.bottom, 146)
                                .tag(index + 1)
                        }
                        appLibrary(width: geometry.size.width)
                            .tag(libraryPageIndex)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .blur(radius: openFolder == nil ? 0 : 18)

                    // Overlay instead of taking height away from the pages.
                    // Widgets and Library both hide floating navigation and Dock.
                    // On the widgets page, swiping still switches Home pages.
                    VStack(spacing: 0) {
                        pageControl
                            .padding(.bottom, 18)
                            .opacity(page == libraryPageIndex || page == 0 ? 0 : 1)
                            .allowsHitTesting(page != libraryPageIndex && page != 0)
                            .accessibilityHidden(page == libraryPageIndex || page == 0)
                        dock(width: geometry.size.width)
                            .padding(.horizontal, 12)
                            .padding(.bottom, -22)
                            .blur(radius: openFolder == nil ? 0 : 18)
                            .opacity((page == 0 || page == libraryPageIndex) ? 0 : 1)
                            .allowsHitTesting(page > 0 && page < libraryPageIndex)
                            .accessibilityHidden(page == 0 || page == libraryPageIndex)
                    }
                    .padding(.bottom, 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.38),
                               value: page == libraryPageIndex)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.28),
                               value: page == 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .blur(radius: searching ? 14 : 0)
                .allowsHitTesting(!searching)
                .accessibilityHidden(searching)
                if installInProgress {
                    BloomBoxHomeInstallationNotice(progress: installProgress)
                        .transition(.opacity)
                }
                if aliveEnabled && aliveBooting && aliveStartupPage == page && !reduceMotion {
                    BloomBoxHomeWelcome(message: aliveSplashLine, visible: aliveIntroVisible)
                        .zIndex(20)
                }
                if editing && !searching {
                    BloomBoxHomeEditorToolbar(
                        exportURL: $themeExportURL,
                        addWidget: { showWidgetGallery = true },
                        customize: { iconCustomization = true },
                        exportTheme: exportCurrentTheme,
                        addPage: addPage,
                        managePages: { pageManager = true },
                        openLibrary: {
                            finishEditing()
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                                page = libraryPageIndex
                            }
                        },
                        finish: finishEditing
                    )
                    .zIndex(15)
                }
                if let exportError = themeExportError {
                    Color.clear.frame(width: 0, height: 0).alert("Exportar tema", isPresented: Binding(
                        get: { themeExportError != nil }, set: { if !$0 { themeExportError = nil } })) {
                        Button("Aceptar", role: .cancel) { themeExportError = nil }
                    } message: { Text(exportError) }
                }
                if searching { searchOverlay(height: geometry.size.height) }
                if let id = openFolder, let folder = layout.folders.first(where: { $0.id == id }) {
                    folderOverlay(folder, width: geometry.size.width)
                }
            }
            .foregroundColor(.white)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "bloombox.alive.viewport")
            .onPreferenceChange(BloomBoxAliveIconFrames.self) { frames in
                let viewport = CGRect(origin: .zero, size: geometry.size)
                let visible = Set(frames.compactMap { name, rect in
                    rect.width > 0 && rect.height > 0 && rect.intersects(viewport) ? name : nil
                })
                if visible != aliveVisibleIcons {
                    aliveVisibleIcons = visible
                    if let current = alivePlayfulKey, !visible.contains(current) {
                        alivePlayfulKey = nil
                        alivePlayfulActive = false
                    }
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
                stopAlivePlayfulness()
                if !searching && !editing && openFolder == nil && page > 0 && page < libraryPageIndex &&
                    value.translation.height > 65 && abs(value.translation.height) > abs(value.translation.width) * 1.4 {
                    beginSearch()
                }
            })
            .onChange(of: scenePhase) { phase in
                stopAlivePlayfulness()
                if phase == .active { ramPlus.refresh() }
                if phase == .active, #available(iOS 16.2, *) {
                    Task { await ManzanaExpiryReminderCenter.shared.synchronize() }
                }
            }
            .onChange(of: page) { _ in stopAlivePlayfulness() }
            .onChange(of: editing) { _ in stopAlivePlayfulness() }
            .onChange(of: searching) { _ in stopAlivePlayfulness() }
            .onChange(of: openFolder) { _ in stopAlivePlayfulness() }
            .onChange(of: aliveEnabled) { enabled in
                if !enabled {
                    aliveBooting = false
                    aliveIntroVisible = false
                    aliveRevealed = true
                    stopAlivePlayfulness()
                }
            }
            .onChange(of: appKeys) { _ in reconcile() }
            .onChange(of: layout) {
                savedLayout = $0.encoded
                page = min(page, libraryPageIndex)
            }
            .sheet(isPresented: $themesPresented) {
                BloomBoxThemeStoreView(onApply: { data in
                    try applyImportedTheme(data)
                }, onSaveCurrent: {
                    try currentThemeData()
                })
            }
            .onAppear {
                ramPlus.refresh()
                Task { await tweakCatalog.refreshIfNeeded() }
                layout = BloomBoxHomeLayout.decode(savedLayout)
                reconcile()
                migrateLegacyPageWidgets()
                restoreWidgetSpace()
                homeHasAppeared = true
                wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
                if #available(iOS 16.2, *) {
                    Task { await ManzanaExpiryReminderCenter.shared.synchronize() }
                }
                // Recover from hidden or stale pages without losing saved widgets.
                let navigation = homeNavigation
                if hiddenPagesJSON != navigation.encodedHidden {
                    hiddenPagesJSON = navigation.encodedHidden
                }
                page = navigation.safePage
                startBloomBoxAlive()
                if LCUtils.appGroupUserDefault.bool(forKey: "BloomBoxGameBoxOpenThemeStore") {
                    LCUtils.appGroupUserDefault.set(false, forKey: "BloomBoxGameBoxOpenThemeStore")
                    DispatchQueue.main.async { themesPresented = true }
                }
            }
            .task {
                // Noncritical popups and status notices are intentionally quiet
                // for the first 10 seconds. App launches/security prompts are not delayed.
                do { try await Task.sleep(nanoseconds: 10_000_000_000) }
                catch { return }
                startupNoticesEnabled = true
            }
            .task(id: scenePhase) {
                // Task cancellation also stops this loop when the screen goes away.
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: UInt64.random(in: 9...16) * 1_000_000_000)
                    } catch { break }
                    guard scenePhase == .active, aliveEnabled, aliveIdleEnabled,
                          Date().timeIntervalSince(aliveLastInteraction) >= 5,
                          !reduceMotion, !aliveBooting, !editing, !searching,
                          openFolder == nil, !pageManager, !customizing,
                          !desktopSettings, !appStorePresented, !tweakStorePresented,
                          !modulesPresented, !jitSetup,
                          page > 0, page < libraryPageIndex,
                          layout.pages.indices.contains(page - 1) else { continue }
                    guard triggerAliveIconTrick() else { continue }
                    let selectedKey = alivePlayfulKey
                    do { try await Task.sleep(nanoseconds: 620_000_000) } catch { break }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.60)) {
                        alivePlayfulActive = false
                    }
                    do { try await Task.sleep(nanoseconds: 400_000_000) } catch { break }
                    if alivePlayfulKey == selectedKey { alivePlayfulKey = nil }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if ramPlus.needsAttention && startupNoticesEnabled {
                Button { modulesPresented = true } label: {
                    Label("RAM+ solicitada, pero el permiso no está confirmado. Toca para revisar.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 100)
                .accessibilityIdentifier("bloombox.ram.warning")
            }
        }
        .overlay { if importingMotionWallpaper { ProgressView("Preparando fondo…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
        .overlay(alignment: .top) {
            if startupNoticesEnabled, let networkNoticeText {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(networkNoticeText)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Se aplica al reiniciar BloomBox. Algunas conexiones de iCloud pueden continuar.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { self.networkNoticeText = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Cerrar aviso")
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25)))
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }
        }
        .background(LiveBoardOrientationLock(mask: .portrait))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .confirmationDialog("Desinstalar aplicación", isPresented: Binding(
            get: { pendingUninstall != nil },
            set: { if !$0 { pendingUninstall = nil } }
        ), titleVisibility: .visible) {
            if let app = pendingUninstall {
                if app.uiIsShared {
                    Button("Abrir ajustes para convertir a privada") {
                        pendingUninstall = nil
                        manage(app)
                    }
                } else {
                    Button("Desinstalar app", role: .destructive) {
                        pendingUninstall = nil
                        uninstall(app)
                    }
                }
            }
            Button("Cancelar", role: .cancel) { pendingUninstall = nil }
        } message: {
            if pendingUninstall?.uiIsShared == true {
                Text("Esta app está compartida entre instancias de LiveContainer. Por seguridad, conviértela a app privada desde sus ajustes antes de desinstalarla.")
            } else {
                Text("Se quitará la app de LiveContainer y del escritorio de BloomBox. Sus carpetas de datos se conservarán. Esta acción no se puede deshacer.")
            }
        }
        .confirmationDialog("Editar icono", isPresented: Binding(
            get: { pendingRemovalKey != nil },
            set: { if !$0 { pendingRemovalKey = nil } }
        ), titleVisibility: .visible) {
            if let key = pendingRemovalKey {
                if let app = appMap[key] {
                    Button("Quitar de la pantalla de inicio", role: .destructive) {
                        removeFromHome(key)
                    }
                    if !(app.appInfo is BuiltInSideStoreAppInfo) {
                        Button("Administrar o desinstalar…") {
                            pendingRemovalKey = nil
                            finishEditing()
                            manage(app)
                        }
                    }
                } else if layout.folders.contains(where: { $0.id == key }) {
                    Button("Deshacer carpeta", role: .destructive) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            layout.dissolveFolder(key)
                            reconcile()
                        }
                        pendingRemovalKey = nil
                    }
                }
            }
            Button("Cancelar", role: .cancel) { pendingRemovalKey = nil }
        } message: {
            Text("Quitar un icono del inicio no desinstala la aplicación ni borra sus datos.")
        }
        .fullScreenCover(isPresented: $pageManager) {
            GeometryReader { geometry in
                ZStack {
                    wallpaperBackground(paused: false)
                    Color.black.opacity(0.22).ignoresSafeArea()
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button { pageManager = false } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 21, weight: .semibold))
                                    .frame(width: 70, height: 45)
                                    .liveBoardGlass(radius: 23)
                            }
                            .accessibilityLabel("Listo")
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 15)

                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 22),
                                GridItem(.flexible(), spacing: 22)
                            ], alignment: .center, spacing: 24) {
                                ForEach([-1] + Array(layout.pages.indices), id: \.self) { index in
                                    VStack(spacing: 12) {
                                        Button {
                                            if index == -1 {
                                                page = 0
                                                pageManager = false
                                            } else {
                                                selectPageFromOverview(index)
                                            }
                                        } label: {
                                            Group {
                                                if index == -1 {
                                                    widgetPageMiniature()
                                                } else {
                                                    pageMiniature(index)
                                                        .opacity(hiddenPageIndices.contains(index) ? 0.55 : 1)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            if index >= 0 && layout.pages.count > 1 {
                                                Button("Eliminar página", systemImage: "trash", role: .destructive) {
                                                    if layout.pages[index].allSatisfy({ $0 == nil }) { removePage(index) }
                                                    else { pendingPageRemoval = index }
                                                }
                                            }
                                        }
                                        .accessibilityLabel(index == -1
                                            ? "Página de widgets" : "Página \(index + 1). Mantén pulsado para eliminarla")
                                        if index == -1 {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 29, weight: .light))
                                                .foregroundStyle(.white)
                                                .frame(width: 45, height: 42)
                                                .liveBoardGlass(radius: 22)
                                                .accessibilityLabel("Página de widgets siempre disponible")
                                        } else {
                                            Button { togglePageVisibility(index) } label: {
                                                Image(systemName: hiddenPageIndices.contains(index)
                                                      ? "circle" : "checkmark.circle.fill")
                                                    .font(.system(size: 29, weight: .light))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 45, height: 42)
                                                    .liveBoardGlass(radius: 22)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(hiddenPageIndices.contains(index)
                                                ? "Mostrar página \(index + 1)" : "Ocultar página \(index + 1)")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 25)
                            .padding(.top, max(70, min(310, geometry.size.height * 0.22)))
                            .padding(.bottom, 30)
                        }
                        // Compatible with deployment targets older than iOS 16.

                        HStack(spacing: 22) {
                            Button {
                                addPage()
                            } label: {
                                Label("Añadir página", systemImage: "plus")
                            }
                            Button {
                                if layout.pages.count > 1 {
                                    let index = min(max(0, page - 1), layout.pages.count - 1)
                                    if layout.pages[index].allSatisfy({ $0 == nil }) { removePage(index) }
                                    else { pendingPageRemoval = index }
                                }
                            } label: {
                                Label("Eliminar página", systemImage: "trash")
                            }
                            .disabled(layout.pages.count < 2)
                        }
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .liveBoardGlass(radius: 24, interactive: false)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(LinearGradient(
                                    colors: [.white.opacity(0.40), .white.opacity(0.08), .white.opacity(0.24)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 0.8)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .foregroundStyle(.white)
            }
            .onAppear {
                let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Manzana", isDirectory: true)
                    .appendingPathComponent("widget-photo.jpg")
                miniatureWidgetPhoto = UIImage(contentsOfFile: url.path)
            }
            .confirmationDialog("Eliminar página", isPresented: Binding(
                get: { pendingPageRemoval != nil },
                set: { if !$0 { pendingPageRemoval = nil } }
            ), titleVisibility: .visible) {
                Button("Eliminar página y conservar sus iconos", role: .destructive) {
                    if let index = pendingPageRemoval { removePage(index) }
                    pendingPageRemoval = nil
                }
                Button("Cancelar", role: .cancel) { pendingPageRemoval = nil }
            } message: {
                Text("Los iconos se reubicarán en otra página sin desinstalar aplicaciones.")
            }
        }
        .alert("New Home category", isPresented: $addingCategory) {
            TextField("Category name", text: $categoryName)
            Button("Add") {
                let value = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, value.count <= 30 else { return }
                var names = (try? JSONDecoder().decode([String].self, from: Data(homeCategories.utf8))) ?? []
                if !names.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { names.append(value) }
                if let data = try? JSONEncoder().encode(names), let text = String(data: data, encoding: .utf8) { homeCategories = text }
                if let key = categoryApp { setCategory(value, key: key) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $desktopSettings, onDismiss: performDesktopAction) {
            NavigationView {
                controls
                    .navigationTitle("Escritorio")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { desktopSettings = false }
                        }
                    }
            }.navigationViewStyle(.stack)
        }
        .sheet(item: $expandedLibraryCategory) { section in
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), spacing: 24) {
                        ForEach(section.keys, id: \.self) { key in
                            libraryLaunchIcon(key, size: 64, label: true)
                        }
                    }
                    .padding(20)
                }
                .navigationTitle(section.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { expandedLibraryCategory = nil }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $jitSetup) { LiveBoardJITSetup() }
        .sheet(isPresented: $tweakStorePresented, onDismiss: { storeFocusedApp = nil }) {
            BloomBoxTweakStore(apps: apps, focusedApp: storeFocusedApp)
        }
        .sheet(isPresented: $appStorePresented) {
            BloomBoxAppStore(apps: apps, openSources: {
                appStorePresented = false
                openTab(.sources)
            })
        }
        .sheet(isPresented: $modulesPresented, onDismiss: performModuleAction) {
            BloomBoxModulesPanel(apps: apps + (!LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") || sharedModel.isHiddenAppUnlocked ? sharedModel.hiddenApps : [])) { destination in
                pendingModuleDestination = destination
                modulesPresented = false
            }
            .modifier(BloomBoxModulesSheetBackground())
        }
        .alert("Compatibilidad · Nivel 3 (máximo)", isPresented: $showTweakLevel3Alert) {
            Button("Instalar corrección") {
                storeFocusedApp = pendingAlertApp
                showTweakLevel3Alert = false
                tweakStorePresented = true
            }
            Button("Abrir de todas formas") {
                if let app = pendingAlertApp {
                    if pendingAlertJIT, let launchWithJIT { launchWithJIT(app) }
                    else { launch(app) }
                }
                pendingAlertApp = nil
                pendingAlertTweak = nil
            }
            Button("Cancelar", role: .cancel) {
                pendingAlertApp = nil
                pendingAlertTweak = nil
            }
        } message: {
            Text(pendingAlertTweak?.alertMessage ??
                 "La app necesita una corrección de compatibilidad para abrir correctamente.")
        }
        .sheet(isPresented: $customizing) { customizeSheet }
        .sheet(isPresented: $iconCustomization) { iconCustomizationSheet }
        .sheet(isPresented: $showWidgetGallery, onDismiss: {
            // A picker cannot be presented while the gallery sheet is
            // dismissing. Launch the media choice only once it is gone.
            if let target = pendingWidgetMediaAfterGallery {
                pendingWidgetMediaAfterGallery = nil
                requestWidgetMedia(for: target)
            }
        }) {
            if page > 0 && page <= layout.pages.count {
                widgetAddSheet
            } else {
                BloomBoxWidgetGallery()
            }
        }
        .modifier(BloomBoxWidgetMediaPresentation(
            sourcePresented: $widgetMediaChoicePresented,
            photoPresented: $choosingWidgetPhoto,
            filePresented: $choosingWidgetFile,
            importing: $widgetMediaImporting,
            openPhotos: { beginWidgetMediaImport(fromPhotos: true) },
            openFiles: { beginWidgetMediaImport(fromPhotos: false) },
            cancel: { widgetMediaID = nil },
            photoResult: handleWidgetPhotoResult,
            fileResult: handleWidgetFileResult
        ))
        .sheet(isPresented: $editingWidgetNote) {
            NavigationView {
                TextEditor(text: $miniatureNote)
                    .padding()
                    .navigationTitle("Notas")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { editingWidgetNote = false }
                        }
                    }
            }.navigationViewStyle(.stack)
        }
        .alert("Widget de foto o GIF", isPresented: Binding(
            get: { widgetMediaError != nil },
            set: { if !$0 { widgetMediaError = nil } }
        )) {
            Button("Aceptar") { widgetMediaError = nil }
        } message: {
            Text(widgetMediaError ?? "")
        }
        .sheet(isPresented: $choosingMotionWallpaperPhotos) {
            BloomBoxMotionWallpaperPhotosPicker { result in
                choosingMotionWallpaperPhotos = false
                guard let result else { return }
                switch result {
                case .success(let name): installMotionWallpaper(name)
                case .failure(let error): wallpaperError = error.localizedDescription
                }
            }
        }
        .fileImporter(isPresented: $choosingMotionWallpaper, allowedContentTypes: [.movie, .gif]) { result in
            switch result {
            case .success(let url):
                importingMotionWallpaper = true
                Task {
                    do {
                        let name = try await Task.detached(priority: .userInitiated) { try BloomBoxMotionMedia.importFile(url) }.value
                        installMotionWallpaper(name)
                    } catch { wallpaperError = error.localizedDescription }
                    importingMotionWallpaper = false
                }
            case .failure(let error): wallpaperError = error.localizedDescription
            }
        }
        .sheet(isPresented: $choosingWallpaper) {
            LiveBoardWallpaperPicker { image in
                choosingWallpaper = false
                guard let image else { return }
                do {
                    let size = image.size
                    let factor = min(1, 2400 / max(size.width, size.height))
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let resized = UIGraphicsImageRenderer(size: CGSize(width: size.width * factor, height: size.height * factor), format: format).image { _ in
                        image.draw(in: CGRect(x: 0, y: 0, width: size.width * factor, height: size.height * factor))
                    }
                    guard let data = resized.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
                    try FileManager.default.createDirectory(at: wallpaperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: wallpaperURL, options: .atomic)
                    wallpaper = resized; wallpaperStyle = "photo"
                } catch { wallpaperError = error.localizedDescription }
            }
        }
        .sheet(item: $appearanceApp) { app in LiveBoardAppAppearance(app: app.app) }
        .alert("Rename", isPresented: Binding(get: { renameKey != nil }, set: { if !$0 { renameKey = nil } })) {
            TextField("Name", text: $renameValue)
            Button("Cancel", role: .cancel) { renameKey = nil }
            Button("Save") {
                if let key = renameKey {
                    let name = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let index = layout.folders.firstIndex(where: { $0.id == key }) {
                        if !name.isEmpty { layout.folders[index].name = name }
                    } else if let app = appMap[key] { appCustomization.rename(app, to: name); layout.aliases[key] = nil }
                }
                renameKey = nil
            }
        }
        .alert("New Folder", isPresented: Binding(get: { newFolderApp != nil }, set: { if !$0 { newFolderApp = nil } })) {
            TextField("Folder name", text: $folderName)
            Button("Cancel", role: .cancel) { newFolderApp = nil }
            Button("Create") {
                if let key = newFolderApp {
                    layout.createFolder(name: folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Apps" : folderName, app: key)
                    reconcile()
                }
                newFolderApp = nil
            }
        }
        .alert("Wallpaper", isPresented: Binding(get: { wallpaperError != nil }, set: { if !$0 { wallpaperError = nil } })) {
            Button("OK") { wallpaperError = nil }
        } message: { Text(wallpaperError ?? "") }
        .fileImporter(isPresented: $choosingAppTweak,
                      allowedContentTypes: [.dylib, .lcFramework],
                      allowsMultipleSelection: true) { result in
            guard let app = pendingTweakApp else { return }
            switch result {
            case .success(let urls):
                installTweakFiles(urls, for: app)
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    appTweakError = error.localizedDescription
                }
            }
            pendingTweakApp = nil
        }
        .alert("No se pudo añadir el Tweak",
               isPresented: Binding(get: { appTweakError != nil },
                                    set: { if !$0 { appTweakError = nil } })) {
            Button("Aceptar") { appTweakError = nil }
        } message: {
            Text(appTweakError ?? "")
        }
    }

    private func installMotionWallpaper(_ name: String) {
        let old = motionWallpaper
        motionWallpaper = name
        wallpaperStyle = "motion"
        if old != name { BloomBoxMotionMedia.remove(old) }
    }

    private var background: some View { wallpaperBackground(paused: pageManager) }

    private func wallpaperBackground(paused: Bool) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if wallpaperStyle == "motion", let url = BloomBoxMotionMedia.url(motionWallpaper) {
                    BloomBoxAnimatedWallpaper(url: url, fit: wallpaperFit,
                        paused: pauseWallpaper || reduceMotion || paused)
                        .id(motionWallpaper)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if wallpaperStyle == "photo", let wallpaper {
                    Image(uiImage: wallpaper).resizable().aspectRatio(contentMode: wallpaperFit ? .fit : .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if wallpaperStyle != "black" {
                    LiveBoardRibbonWallpaper(blue: wallpaperStyle == "blue")
                }
                Color.black.opacity(wallpaperDim)
            }
        }.ignoresSafeArea()
    }

    /// Native Home page management shows the wallpaper once, behind floating
    /// glass previews. A miniature is material, not another wallpaper image.
    // MARK: - App Library: final page of Manzana's Home
    // Only guests installed in LiveContainer are listed, not unrelated iOS apps.
    // Classification, favorites, recents and search are owned by BloomBox's
    // portable library policy rather than baked into the SwiftUI Home view.
    private func libraryEntries() -> [BloomBoxAppLibraryPolicy.Entry] {
        let appsByKey = appMap
        let builtIns = Set([
            Self.sideStoreKey, Self.installKey, Self.tweakStoreKey,
            Self.appStoreKey, Self.modulesKey, Self.themesKey
        ])
        return appKeys.map { key in
            BloomBoxAppLibraryPolicy.Entry(
                key: key,
                name: title(key, appsByKey: appsByKey),
                bundleID: appsByKey[key]?.bundleIdentifier ?? "",
                isBuiltIn: builtIns.contains(key)
            )
        }
    }

    private var librarySections: [LibrarySection] {
        let assigned = (try? JSONDecoder().decode([String: String].self,
                              from: Data(categories.utf8))) ?? [:]
        return BloomBoxAppLibraryPolicy.sections(
            entries: libraryEntries(),
            favorites: favoriteKeys,
            recent: recentLibraryKeys,
            assigned: assigned
        ).map { LibrarySection(title: $0.title, keys: $0.keys) }
    }

    private var librarySearchMatches: [String] {
        BloomBoxAppLibraryPolicy.search(libraryEntries(), query: libraryQuery)
    }

    private func appLibrary(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22))
                    TextField("Biblioteca de apps", text: $libraryQuery)
                        .font(.system(size: 21))
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .focused($librarySearchFocused)
                        .submitLabel(.search)
                    if !libraryQuery.isEmpty {
                        Button { libraryQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }.accessibilityLabel("Borrar búsqueda")
                    }
                }
                .padding(.horizontal, 19)
                .frame(height: 56)
                .liveBoardGlass(radius: 28, interactive: false)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 0.7)
                }
                .contentShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 22)
                .padding(.top, 20)
                if libraryQuery.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 2),
                              alignment: .center, spacing: 26) {
                        ForEach(librarySections) { section in
                            VStack(spacing: 9) {
                                librarySectionTile(section)
                                Text(section.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 23)
                } else if librarySearchMatches.isEmpty {
                    Text("No se encontraron aplicaciones")
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 9) {
                        ForEach(librarySearchMatches, id: \.self) { key in
                            Button {
                                librarySearchFocused = false
                                launchLibraryKey(key)
                            } label: {
                                HStack(spacing: 14) {
                                    miniatureIcon(key, size: 43)
                                    Text(title(key))
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding(8)
                            }
                            .buttonStyle(.plain)
                            .liveBoardGlass(radius: 17, interactive: false)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
            .padding(.bottom, 80)
        }
        .onTapGesture { if librarySearchFocused { librarySearchFocused = false } }
        .accessibilityIdentifier("manzana.app-library")
    }

    private func librarySectionTile(_ section: LibrarySection) -> some View {
        GeometryReader { geometry in
            let gap: CGFloat = 8
            let pad: CGFloat = 11
            let size = (geometry.size.width - pad * 2 - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    libraryTileSlot(section, offset: 0, size: size)
                    libraryTileSlot(section, offset: 1, size: size)
                }
                HStack(spacing: gap) {
                    libraryTileSlot(section, offset: 2, size: size)
                    Button {
                        expandedLibraryCategory = section
                    } label: {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 2), spacing: 3) {
                            ForEach(3..<7, id: \.self) { index in
                                if section.keys.indices.contains(index) {
                                    miniatureIcon(section.keys[index], size: (size - 4) / 2)
                                        .frame(width: (size - 4) / 2, height: (size - 4) / 2)
                                } else {
                                    Color.white.opacity(0.07)
                                        .frame(width: (size - 4) / 2, height: (size - 4) / 2)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                        }
                    }
                    .frame(width: size, height: size)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Abrir categoría \(section.title)")
                }
            }
            .padding(pad)
            .liveBoardGlass(radius: 25, interactive: false)
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.43), .white.opacity(0.10), .white.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.9)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func libraryTileSlot(_ section: LibrarySection, offset: Int, size: CGFloat) -> some View {
        if section.keys.indices.contains(offset) {
            libraryLaunchIcon(section.keys[offset], size: size, label: false)
                .frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func libraryLaunchIcon(_ key: String, size: CGFloat, label: Bool) -> some View {
        Button { launchLibraryKey(key) } label: {
            VStack(spacing: 5) {
                miniatureIcon(key, size: size)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
                if label {
                    Text(title(key))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let app = appMap[key] {
                appMenu(key, app: app)
            }
        }
        .onDrag { NSItemProvider(object: key as NSString) }
        .accessibilityLabel("Abrir \(title(key))")
    }


    private func requestLaunch(_ app: LCAppModel, jit: Bool = false) {
        guard !(app.appInfo is BuiltInSideStoreAppInfo) else {
            launch(app)
            return
        }
        Task { @MainActor in
            // Don't block Launch with JIT behind a network request that can take
            // 12+ seconds and make the button look dead. Use the already verified
            // catalog now, and update it for future launches in the background.
            // The catalog is also refreshed when the Home screen appears.
            Task { await tweakCatalog.refreshIfNeeded() }
            if let tweak = tweakCatalog.criticalMissing(for: app) {
                pendingAlertApp = app
                pendingAlertTweak = tweak
                pendingAlertJIT = jit
                showTweakLevel3Alert = true
            } else if jit, let launchWithJIT {
                launchWithJIT(app)
            } else {
                launch(app)
            }
        }
    }

    private func launchLibraryKey(_ key: String) {
        if key == Self.sideStoreKey { openSideStore() }
        else if key == Self.installKey { openInstall() }
        else if key == Self.tweakStoreKey { storeFocusedApp = nil; tweakStorePresented = true }
        else if key == Self.appStoreKey { appStorePresented = true }
        else if key == Self.modulesKey { modulesPresented = true }
        else if key == Self.themesKey { themesPresented = true }
        else if let app = appMap[key] { requestLaunch(app) }
    }

    private func pageMiniature(_ index: Int) -> some View {
        GeometryReader { geometry in
            let iconSize = min(34, max(15, geometry.size.width / 5.25))
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .liveBoardGlass(radius: 24, interactive: false)
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    VStack(spacing: 0) {
                        if !widgets(on: index).isEmpty {
                            HStack {
                                ForEach(widgets(on: index)) { widget in
                                    Image(systemName: widget.kind == "clock" ? "clock" : widget.kind == "media" ? "photo" : "note.text")
                                        .font(.caption).frame(maxWidth: .infinity).padding(6).liveBoardGlass(radius: 8)
                                }
                            }.padding(8)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 7) {
                            ForEach(0..<BloomBoxHomeLayout.capacity, id: \.self) { slot in
                                if let key = layout.pages[index][slot] {
                                    miniatureIcon(key, size: iconSize)
                                } else {
                                    Color.clear.frame(width: iconSize, height: iconSize)
                                }
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.top, 15)
                        Spacer(minLength: 3)
                        HStack(spacing: 7) {
                            ForEach(0..<4, id: \.self) { slot in
                                if layout.dock.indices.contains(slot) {
                                    miniatureIcon(layout.dock[slot], size: iconSize * 0.8)
                                } else {
                                    Color.clear.frame(width: iconSize * 0.8, height: iconSize * 0.8)
                                }
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .liveBoardGlass(radius: 13, interactive: false)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 11)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.52), .white.opacity(0.12), .white.opacity(0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.9)
            }
        }
        .aspectRatio(0.54, contentMode: .fit)
        .modifier(LiveBoardEditWobble(active: pageManager && !reduceMotion,
                                     phase: 0.4, speed: 7, amplitude: 0.85))
    }

    private func widgetPageMiniature() -> some View {
        GeometryReader { geometry in
            let pad: CGFloat = 12
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .liveBoardGlass(radius: 24, interactive: false)
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    VStack(spacing: 9) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reloj")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(timeline.date, format: .dateTime.hour().minute())
                                .font(.system(size: 30, weight: .light, design: .rounded))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .frame(height: geometry.size.height * 0.24)
                        .liveBoardGlass(radius: 13, interactive: false)
                        HStack(spacing: 8) {
                            Group {
                                if let photo = miniatureWidgetPhoto {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 25))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height * 0.27)
                            .clipped()
                            .liveBoardGlass(radius: 13, interactive: false)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "note.text")
                                Text(miniatureNote.isEmpty ? "Notas" : miniatureNote)
                                    .lineLimit(3)
                            }
                            .font(.system(size: 9))
                            .padding(9)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .frame(height: geometry.size.height * 0.27)
                            .liveBoardGlass(radius: 13, interactive: false)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, pad)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.52), .white.opacity(0.12), .white.opacity(0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.9)
            }
        }
        .aspectRatio(0.54, contentMode: .fit)
        .modifier(LiveBoardEditWobble(active: pageManager && !reduceMotion,
                                     phase: 0.4, speed: 7, amplitude: 0.85))
    }

    @ViewBuilder private func miniatureIcon(_ key: String, size: CGFloat) -> some View {
        if let folder = layout.folders.first(where: { $0.id == key }) {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(.ultraThinMaterial)
                .overlay {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 2), spacing: 1) {
                        ForEach(Array(folder.apps.prefix(4)), id: \.self) { child in
                            if let app = appMap[child] {
                                LiveBoardIconImage(app: app, dark: darkIcons)
                                    .frame(width: size * 0.38, height: size * 0.38)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                    .padding(3)
                }
                .frame(width: size, height: size)
        } else if key == Self.sideStoreKey {
            if let icon = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(darkIcons) {
                Image(uiImage: icon).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
            } else {
                Image(systemName: "square.stack.fill")
                    .frame(width: size, height: size)
            }
        } else if key == Self.modulesKey {
            BloomBoxModulesIcon(size: size)
        } else if key == Self.themesKey {
            BloomBoxThemesIcon(size: size)
        } else if key == Self.appStoreKey {
            Image(systemName: "bag.fill")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color(red: 0.20, green: 0.55, blue: 0.77),
                            in: RoundedRectangle(cornerRadius: size * 0.23))
        } else if key == Self.tweakStoreKey {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color(red: 0.48, green: 0.32, blue: 0.76),
                            in: RoundedRectangle(cornerRadius: size * 0.23))
        } else if key == Self.installKey {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: size * 0.5))
                .frame(width: size, height: size)
                .background(Color.cyan, in: RoundedRectangle(cornerRadius: size * 0.23))
        } else if let app = appMap[key] {
            LiveBoardIconImage(app: app, dark: darkIcons)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
        } else {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(.white.opacity(0.22))
                .frame(width: size, height: size)
        }
    }

    private func persistHiddenPages(_ indices: Set<Int>) {
        let valid = indices.filter { layout.pages.indices.contains($0) }.sorted()
        if let data = try? JSONEncoder().encode(valid), let value = String(data: data, encoding: .utf8) {
            hiddenPagesJSON = value
        }
    }

    private func togglePageVisibility(_ index: Int) {
        guard let updated = homeNavigation.toggledVisibility(at: index) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            hiddenPagesJSON = updated.encodedHidden
            page = updated.safePage
        }
    }

    private func selectPageFromOverview(_ index: Int) {
        guard let updated = homeNavigation.selectedFromOverview(index) else { return }
        hiddenPagesJSON = updated.encodedHidden
        page = updated.safePage
        pageManager = false
    }

    private var pageWidgets: [Int: [String]] {
        (try? JSONDecoder().decode([Int: [String]].self, from: Data(pageWidgetsJSON.utf8))) ?? [:]
    }
    private var placedWidgets: [Int: [BloomBoxPlacedWidget]] {
        (try? JSONDecoder().decode([Int: [BloomBoxPlacedWidget]].self,
                                   from: Data(placedWidgetsJSON.utf8))) ?? [:]
    }
    private func savePlacedWidgets(_ values: [Int: [BloomBoxPlacedWidget]]) {
        if let data = try? JSONEncoder().encode(values),
           let encoded = String(data: data, encoding: .utf8) {
            placedWidgetsJSON = encoded
        }
    }
    private func widgets(on index: Int) -> [BloomBoxPlacedWidget] {
        placedWidgets[index] ?? []
    }
    private func occupiedCells(on index: Int, excluding id: String? = nil) -> Set<Int> {
        widgets(on: index).filter { $0.id != id }.reduce(into: Set<Int>()) { cells, widget in
            cells.formUnion(BloomBoxWidgetGrid.cells(slot: widget.slot,
                           columns: widget.columns, rows: widget.rows) ?? [])
        }
    }
    private func migrateLegacyPageWidgets() {
        guard !placedWidgetsMigrated else { return }
        var all = placedWidgets
        for (index, values) in pageWidgets where layout.pages.indices.contains(index) {
            for kind in values where ["clock", "photo", "notes"].contains(kind) {
                let occupied = all[index, default: []].reduce(into: Set<Int>()) { result, widget in
                    result.formUnion(BloomBoxWidgetGrid.cells(slot: widget.slot,
                                    columns: widget.columns, rows: widget.rows) ?? [])
                }
                guard let slot = BloomBoxWidgetGrid.firstAvailable(
                    columns: 4, rows: 2, occupied: occupied) else { continue }
                var migrated = BloomBoxPlacedWidget(kind: kind == "photo" ? "media" : kind,
                                                    slot: slot, columns: 4, rows: 2)
                if kind == "photo" {
                    let oldPhoto = FileManager.default.urls(for: .applicationSupportDirectory,
                                                            in: .userDomainMask)[0]
                        .appendingPathComponent("BloomBox/widget-photo.jpg")
                    if let data = try? Data(contentsOf: oldPhoto),
                       let file = try? BloomBoxWidgetMedia.importData(data) {
                        migrated.mediaName = file
                    }
                }
                all[index, default: []].append(migrated)
            }
        }
        savePlacedWidgets(all)
        placedWidgetsMigrated = true
    }
    private func addPlacedWidget(_ kind: String, columns: Int = 2, rows: Int = 2, clockStyle: String? = nil) {
        guard page > 0, layout.pages.indices.contains(page - 1) else { return }
        var all = placedWidgets
        let free = BloomBoxWidgetPlacement.freePosition(
            columns: columns, rows: rows, preferredPage: page - 1,
            visiblePages: visiblePageIndices, in: all
        )
        // Invalid widget dimensions should never create an empty Home page.
        guard free != nil ||
              BloomBoxWidgetGrid.cells(slot: 0, columns: columns, rows: rows) != nil else {
            return
        }
        if free == nil {
            layout.pages.append(Array(repeating: nil, count: BloomBoxHomeLayout.capacity))
        }
        let target = free?.page ?? (layout.pages.count - 1)
        let slot = free?.slot ?? 0
        var widget = BloomBoxPlacedWidget(kind: kind, slot: slot,
                                         columns: columns, rows: rows)
        widget.clockStyle = clockStyle
        all[target, default: []].append(widget)
        savePlacedWidgets(all)
        moveIconsOutOfWidgetArea()
        page = target + 1
        if kind == "media" {
            // Do not chain a second modal on top of the Add Widget gallery.
            pendingWidgetMediaAfterGallery = widget.id
        }
    }
    private func requestWidgetMedia(for id: String) {
        guard placedWidgets.values.flatMap({ $0 }).contains(where: { $0.id == id && $0.kind == "media" }) else {
            widgetMediaError = "El widget ya no está disponible. Crea uno nuevo o vuelve a intentarlo."
            return
        }
        widgetMediaID = id
        widgetMediaChoicePresented = true
    }
    private func beginWidgetMediaImport(fromPhotos: Bool) {
        // SwiftUI dismisses the confirmation dialog before opening the picker.
        // Keep widgetMediaID until the imported data is assigned.
        widgetMediaChoicePresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard widgetMediaID != nil else { return }
            if fromPhotos { choosingWidgetPhoto = true }
            else { choosingWidgetFile = true }
        }
    }
    private func handleWidgetPhotoResult(_ data: Data?, pickedItem: Bool) {
        choosingWidgetPhoto = false
        guard let data else {
            widgetMediaID = nil
            if pickedItem {
                widgetMediaError = "No pude leer esta imagen desde Fotos. Prueba con otra o impórtala desde Archivos."
            }
            return
        }
        importWidgetMedia(data: data)
    }
    private func handleWidgetFileResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let file):
            guard let target = widgetMediaID else {
                widgetMediaError = "No se encontró el widget. Vuelve a tocar la imagen para importarla."
                return
            }
            widgetMediaImporting = true
            Task {
                defer { widgetMediaImporting = false; widgetMediaID = nil }
                do {
                    let name = try await Task.detached(priority: .userInitiated) {
                        try BloomBoxWidgetMedia.importFile(file)
                    }.value
                    setWidgetMedia(target, name: name)
                } catch {
                    widgetMediaError = error.localizedDescription
                }
            }
        case .failure(let error):
            widgetMediaID = nil
            widgetMediaError = error.localizedDescription
        }
    }
    private func importWidgetMedia(data: Data) {
        guard let target = widgetMediaID else {
            widgetMediaError = "Se perdió la selección del widget. Vuelve a intentarlo."
            return
        }
        widgetMediaImporting = true
        Task {
            defer { widgetMediaImporting = false; widgetMediaID = nil }
            do {
                let name = try await Task.detached(priority: .userInitiated) {
                    try BloomBoxWidgetMedia.importData(data)
                }.value
                setWidgetMedia(target, name: name)
            } catch {
                widgetMediaError = error.localizedDescription
            }
        }
    }

    private func setWidgetMedia(_ id: String, name: String) {
        var all = placedWidgets
        var updated = false
        for index in all.keys {
            guard let position = all[index]?.firstIndex(where: { $0.id == id }) else { continue }
            all[index]?[position].mediaName = name
            updated = true
        }
        if updated {
            savePlacedWidgets(all)
        } else {
            // Never leak the import if its target was deleted mid-operation.
            if let url = BloomBoxWidgetMedia.url(for: name) {
                try? FileManager.default.removeItem(at: url)
            }
            widgetMediaError = "No se pudo asignar la imagen: el widget ya no existe."
        }
    }
    private func updateWidget(_ id: String, change: (inout BloomBoxPlacedWidget) -> Void) {
        var all = placedWidgets
        for index in all.keys {
            if let position = all[index]?.firstIndex(where: { $0.id == id }) {
                change(&all[index]![position])
                savePlacedWidgets(all)
                return
            }
        }
    }
    private func removePlacedWidget(_ id: String) {
        var all = placedWidgets
        let original = all.values.flatMap { $0 }.first { $0.id == id }
        for index in all.keys { all[index]?.removeAll { $0.id == id } }
        savePlacedWidgets(all)
        if let name = original?.mediaName,
           let file = BloomBoxWidgetMedia.url(for: name),
           !all.values.flatMap({ $0 }).contains(where: { $0.mediaName == name }) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    private func resizeWidget(_ id: String, columns: Int, rows: Int) {
        guard let plan = BloomBoxWidgetPlacement.resize(
            id, columns: columns, rows: rows, in: placedWidgets
        ) else {
            widgetMediaError = "No hay espacio para ese tamaño. Prueba otra página."
            return
        }
        savePlacedWidgets(plan.pages)
        moveIconsOutOfWidgetArea()
        selectedWidgetID = id
    }

    private func movePlacedWidget(_ id: String, to targetPage: Int, slot: Int?) {
        guard layout.pages.indices.contains(targetPage) else { return }
        guard let plan = BloomBoxWidgetPlacement.move(
            id, to: targetPage, requestedSlot: slot, in: placedWidgets
        ) else {
            widgetMediaError = "No cabe ese widget en la página seleccionada."
            return
        }
        savePlacedWidgets(plan.pages)
        moveIconsOutOfWidgetArea()
        page = plan.page + 1
        selectedWidgetID = id
        UISelectionFeedbackGenerator().selectionChanged()
    }
    private func moveIconsOutOfWidgetArea() {
        layout = BloomBoxHomeIconReflow.apply(
            to: layout, widgets: placedWidgets, hiddenPages: hiddenPageIndices
        )
    }
    private func restoreWidgetSpace() { moveIconsOutOfWidgetArea() }

    private var widgetAddSheet: some View {
        NavigationView {
            List {
                Section("Relojes · BloomBox") {
                    Button { addPlacedWidget("clock", clockStyle: "minimal"); showWidgetGallery = false } label: {
                        Label("Minimalista · hora y fecha", systemImage: "clock")
                    }
                    Button { addPlacedWidget("clock", clockStyle: "flip"); showWidgetGallery = false } label: {
                        Label("Flip · números retro", systemImage: "rectangle.split.2x1")
                    }
                    Button { addPlacedWidget("clock", clockStyle: "analog"); showWidgetGallery = false } label: {
                        Label("Analógico · manecillas", systemImage: "clock.fill")
                    }
                    Button { addPlacedWidget("clock", clockStyle: "pixel"); showWidgetGallery = false } label: {
                        Label("Pixel · estilo videojuego", systemImage: "gamecontroller.fill")
                    }
                }
                Section("Añade tantos como quieras") {
                    Button { addPlacedWidget("notes"); showWidgetGallery = false } label: {
                        Label("Notas", systemImage: "note.text")
                    }
                    Button { addPlacedWidget("media"); showWidgetGallery = false } label: {
                        Label("Imagen o GIF animado", systemImage: "photo.on.rectangle.angled")
                    }
                }
                Section {
                    Text("Toca un widget para seleccionarlo. Arrastra el botón de flechas para moverlo y toca ••• para cambiar tamaño, imagen o fondo. Pulsa Listo al terminar.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Añadir widget")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { showWidgetGallery = false }
                }
            }
        }.navigationViewStyle(.stack)
    }

    private func stopAlivePlayfulness() {
        aliveLastInteraction = Date()
        guard alivePlayfulKey != nil || alivePlayfulActive else { return }
        alivePlayfulKey = nil
        alivePlayfulActive = false
    }

    private func currentThemeData() throws -> Data {
        // Export only presentation settings, never installed app data, credentials or private files.
        let defaults = LCUtils.appGroupUserDefault
        let keys = ["BloomBoxHomeLayout", "LiveBoardHiddenPages", "BloomBoxPlacedWidgetsV2",
                    "ManzanaPageWidgets", "LiveBoardLargeIcons", "darkModeIcon",
                    "LiveBoardWallpaperStyle", "LiveBoardWallpaperFit", "LiveBoardWallpaperDim",
                    "ManzanaIconStyle", "BloomBoxAliveEnabled", "BloomBoxAliveIdleEnabled"]
        var settings: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) { settings[key] = value }
        }
        var media: [String: String] = [:]
        for widget in placedWidgets.values.flatMap({ $0 }) {
            guard let name = widget.mediaName,
                  let url = BloomBoxWidgetMedia.url(for: name),
                  let bytes = try? Data(contentsOf: url) else { continue }
            media[name] = bytes.base64EncodedString()
        }
        if let wallpaper = try? Data(contentsOf: wallpaperURL) {
            media["wallpaper.jpg"] = wallpaper.base64EncodedString()
        }
        if let url = BloomBoxMotionMedia.url(motionWallpaper),
           let bytes = try? Data(contentsOf: url) {
            media["motion-wallpaper"] = bytes.base64EncodedString()
            settings["ManzanaMotionWallpaper"] = motionWallpaper
        }
        settings["BloomBoxWidgetMissingAppFallbacks"] = widgetFallbacksJSON
        settings["BloomBoxLivingWidgetSettings"] = livingWidgetSettingsJSON
        let payload: [String: Any] = ["format": "bbtheme", "version": 2,
                                      "mediaBase64": media,
                                      "exportedAt": ISO8601DateFormatter().string(from: Date()),
                                      "settings": settings]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private func exportCurrentTheme() {
        do {
            let data = try currentThemeData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("BloomBox-Theme.bbtheme")
            try data.write(to: url, options: .atomic)
            themeExportURL = url
        } catch {
            themeExportError = "No se pudo exportar el tema: \(error.localizedDescription)"
        }
    }

    private func applyImportedTheme(_ data: Data) throws {
        // Validate and save a recovery copy before applying any new visual settings.
        _ = try BloomBoxThemePackage.read(data)
        let old = try currentThemeData()
        _ = try BloomBoxThemeLibrary.save(old, named: "Recovery")
        let newLayout = try BloomBoxThemePackage.apply(
            data, defaults: LCUtils.appGroupUserDefault,
            currentLayout: layout, appKeys: appKeys, favorites: favoriteKeys,
            wallpaperURL: wallpaperURL)
        layout = newLayout
        savedLayout = newLayout.encoded
        // AppStorage and the Home model now observe the imported settings.
        wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
        page = 1
        selectedWidgetID = nil
        finishEditing()
    }

    private func aliveEligibleIconKeys() -> [String] {
        guard page > 0, page < libraryPageIndex,
              layout.pages.indices.contains(page - 1) else { return [] }

        let builtinIcons: Set<String> = [
            Self.sideStoreKey, Self.installKey, Self.tweakStoreKey,
            Self.appStoreKey, Self.modulesKey, Self.themesKey
        ]
        // The top three rows remain visible even if TabView does not send geometry.
        // Never choose an icon hidden beneath a media/widget tile.
        let blocked = occupiedCells(on: page - 1)
        let desktopKeys = layout.pages[page - 1].enumerated().compactMap { slot, entry -> String? in
            guard let key = entry,
                  appMap[key] != nil || builtinIcons.contains(key) ||
                    layout.folders.contains(where: { $0.id == key }),
                  !blocked.contains(slot) else { return nil }
            return aliveVisibleIcons.contains(key) || slot < 12 ? key : nil
        }
        // Dock icons are visible on every home page and participate in the same random motion.
        return Array(Set(desktopKeys + layout.dock))
    }

    @discardableResult
    private func triggerAliveIconTrick() -> Bool {
        guard aliveEnabled, aliveIdleEnabled, !reduceMotion,
              !aliveBooting, !editing, !searching,
              openFolder == nil, !pageManager, scenePhase == .active,
              let chosen = aliveEligibleIconKeys().randomElement() else {
            return false
        }
        alivePlayfulKey = chosen
        alivePlayfulStyle = Int.random(in: 0...2)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.36)) {
            alivePlayfulActive = true
        }
        return true
    }

    private func startBloomBoxAlive() {
        guard !aliveStartupPlayed else { return }
        aliveStartupPlayed = true
        guard aliveEnabled, !reduceMotion,
              page > 0, page < libraryPageIndex else { return }
        aliveStartupPage = page
        // Never show the same phrase on consecutive starts.
        let choices = Self.aliveSplashLines.filter { $0 != alivePreviousSplash }
        aliveSplashLine = (choices.isEmpty ? Self.aliveSplashLines : choices).randomElement()
            ?? "El desmadre está por comenzar."
        alivePreviousSplash = aliveSplashLine
        stopAlivePlayfulness()
        aliveBooting = true
        aliveIntroVisible = true
        aliveRevealed = false
        // Welcome -> transparent horizontal wave. UI stays tappable throughout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.67) {
            guard aliveBooting else { return }
            aliveIntroVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
                guard aliveBooting else { return }
                aliveRevealed = true
                // UIKit feedback was previously too soft and arrived without
                // preparing the engine; prewarm each clearly separated tick.
                // Four pulses only, matched to the actual Dock entrances.
                for slot in 0..<min(layout.dock.count, 4) {
                    let offset = 0.69 + Double(slot) * 0.16
                    DispatchQueue.main.asyncAfter(deadline: .now() + offset - 0.09) {
                        guard aliveBooting, aliveStartupPage == page, !reduceMotion,
                              !editing, !searching, openFolder == nil,
                              UIApplication.shared.applicationState == .active else { return }
                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                        haptic.prepare()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                            guard aliveBooting, aliveStartupPage == page, !reduceMotion,
                                  !editing, !searching, openFolder == nil,
                                  UIApplication.shared.applicationState == .active else { return }
                            haptic.impactOccurred(intensity: 1.0)
                        }
                    }
                }
                // Final dock icon has entered before we end the startup gate.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
                    aliveBooting = false
                }
            }
        }
    }

    private func aliveEntrance(for pageIndex: Int, delay: Double, key: String? = nil) -> BloomBoxAliveEntrance {
        let enabled = aliveEnabled && !reduceMotion && aliveBooting &&
                      aliveStartupPage == pageIndex + 1 && page == pageIndex + 1
        return BloomBoxAliveEntrance(
            entranceEnabled: enabled, revealed: !enabled || aliveRevealed,
            delay: delay, playfulStyle: key == alivePlayfulKey ? alivePlayfulStyle : nil,
            playfulActive: key == alivePlayfulKey && alivePlayfulActive &&
                           aliveIdleEnabled && !editing && !reduceMotion
        )
    }

    private func homePage(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        let cellWidth = (width - 28) / 4
        let pitch = min(editing ? 92 : 99,
                        max(72, (height - (editing ? 69 : 39)) / 6))
        return homeIconGrid(index, width: width, height: height)
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(widgets(on: index)) { widget in
                        homeWidgetTile(widget, pageIndex: index,
                                       cellWidth: cellWidth, pitch: pitch)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
    }

    /// Keep each GIF tile in its own SwiftUI expression so the huge Home
    /// screen does not time out when type-checking drag + context menus.
    private struct LivingSettings: Codable {
        var mode: String = "float"
        var speed: Double = 75
        var travel: Double = 60
        var depth: Bool? = nil
        var glow: Bool? = nil
        var adaptiveGlass: Bool? = nil
        // Nil preserves old themes. "auto" samples the first image/GIF frame once.
        var glowColor: String? = nil
        var pixelFollowGlow: Bool? = nil
    }

    private func livingSettings(for id: String) -> LivingSettings {
        let values = (try? JSONDecoder().decode([String: LivingSettings].self,
            from: Data(livingWidgetSettingsJSON.utf8))) ?? [:]
        return values[id] ?? LivingSettings()
    }

    private func setLivingSettings(_ id: String, change: (inout LivingSettings) -> Void) {
        var values = (try? JSONDecoder().decode([String: LivingSettings].self,
            from: Data(livingWidgetSettingsJSON.utf8))) ?? [:]
        var settings = values[id] ?? LivingSettings()
        change(&settings)
        values[id] = settings
        if let data = try? JSONEncoder().encode(values),
           let json = String(data: data, encoding: .utf8) {
            livingWidgetSettingsJSON = json
        }
    }

    private func homeWidgetTile(_ widget: BloomBoxPlacedWidget,
                                pageIndex index: Int,
                                cellWidth: CGFloat, pitch: CGFloat) -> some View {
        let w = CGFloat(widget.columns) * cellWidth - 5
        let h = CGFloat(widget.rows) * pitch - 5
        let living = livingSettings(for: widget.id)
        let accent = BloomBoxWidgetGlowPalette.color(living.glowColor, for: widget)
        let pixelAccent: Color? = (living.pixelFollowGlow ?? false) && widget.clockStyle == "pixel"
            ? accent : nil
        let delay = Double(widget.slot % 4) * 0.145
            + Double(widget.slot / 4) * 0.026
        return BloomBoxGridWidgetView(widget: widget, width: w, height: h,
                                      active: page == index + 1,
                                      clockAccentColor: pixelAccent)
            .allowsHitTesting(false)
            .frame(width: w, height: h)
            .overlay {
                // SwiftUI owns input, independently of transparent GIF pixels.
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture {
                        if selectedWidgetID != widget.id { selectedWidgetID = widget.id }
                        if !editing, widget.tapActionKey != nil {
                            runWidgetTapAction(widget)
                        } else if !editing && widget.kind == "media" && widget.mediaName == nil {
                            requestWidgetMedia(for: widget.id)
                        } else if !editing {
                            enterEditMode()
                        }
                    }
            }
            .overlay {
                if editing {
                    RoundedRectangle(cornerRadius: 19)
                        .strokeBorder(selectedWidgetID == widget.id ? Color.cyan : Color.white.opacity(0.55),
                                      style: StrokeStyle(lineWidth: 2, dash: selectedWidgetID == widget.id ? [] : [5, 4]))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if editing { editWidgetOptionsHandle(widget, pageIndex: index) }
            }
            .modifier(BloomBoxWidgetInteraction(editing: editing, select: {
                // Avoid invalidating the entire Home tree on every finger sample.
                if selectedWidgetID != widget.id { selectedWidgetID = widget.id }
            }, move: { translation in
                let column = min(4 - widget.columns, max(0,
                    widget.slot % 4 + Int((translation.width / cellWidth).rounded())))
                let row = min(6 - widget.rows, max(0,
                    widget.slot / 4 + Int((translation.height / pitch).rounded())))
                let slot = row * 4 + column
                guard let cells = BloomBoxWidgetGrid.cells(slot: slot, columns: widget.columns, rows: widget.rows),
                      cells.isDisjoint(with: occupiedCells(on: index, excluding: widget.id)) else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                movePlacedWidget(widget.id, to: index, slot: slot)
            }, menu: {
                homeWidgetMenu(widget, pageIndex: index)
            }))
            // Position the entire interaction surface, including every gesture.
            .offset(x: 14 + CGFloat(widget.slot % 4) * cellWidth,
                    y: (editing ? 50 : 20) + CGFloat(widget.slot / 4) * pitch)
            .modifier(BloomBoxLivingMotion(mode: living.mode, speed: living.speed, travel: living.travel,
                enabled: scenePhase == .active && page == index + 1 && !editing && !reduceMotion && !searching))
            .shadow(color: (living.depth ?? false) && !editing ? Color.black.opacity(0.38) : .clear,
                    radius: (living.depth ?? false) && !editing ? 15 : 0, x: 0, y: 12)
            .shadow(color: (living.glow ?? false) && !editing ? accent.opacity(0.48) : .clear,
                    radius: (living.glow ?? false) && !editing ? 20 : 0, x: 0, y: 8)
            .overlay {
                if (living.adaptiveGlass ?? false) && widget.glass && !editing {
                    RoundedRectangle(cornerRadius: 19)
                        .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(selectedWidgetID == widget.id ? 2 : 1)
            // Animate the entire interactive tile, not only its disabled
            // GIF/photo content. Editing still tracks the finger instantly.
            .modifier(aliveEntrance(for: index, delay: delay))
            .accessibilityIdentifier("bloombox.widget.\(widget.id)")
    }

    /// Normal taps launch the configured target. Editing/dragging do not.
    private func setWidgetFallback(_ id: String, value: String?) {
        var values = (try? JSONDecoder().decode([String: String].self,
            from: Data(widgetFallbacksJSON.utf8))) ?? [:]
        values[id] = value
        if let data = try? JSONEncoder().encode(values),
           let string = String(data: data, encoding: .utf8) {
            widgetFallbacksJSON = string
        }
    }

    private func runWidgetTapAction(_ widget: BloomBoxPlacedWidget) {
        guard !editing, let target = widget.tapActionKey else { return }
        switch target {
        case "widget:jit": jitSetup = true
        case "widget:desktop": desktopSettings = true
        case "widget:wallpaper": customizing = true
        case "widget:interface": openInterface()
        case "widget:apps": openManagement()
        case "widget:settings": openTab(.settings)
        case "widget:sources": openTab(.sources)
        case Self.sideStoreKey, Self.installKey, Self.tweakStoreKey,
             Self.appStoreKey, Self.modulesKey, Self.themesKey:
            launchLibraryKey(target)
        default:
            guard let app = appMap[target] else {
                let fallbacks = (try? JSONDecoder().decode([String: String].self,
                    from: Data(widgetFallbacksJSON.utf8))) ?? [:]
                if fallbacks[widget.id] == "appstore" {
                    launchLibraryKey(Self.appStoreKey)
                } else if fallbacks[widget.id] == "installer" {
                    launchLibraryKey(Self.installKey)
                } else {
                    widgetMediaError = "La aplicación asignada no está instalada. Configura una acción alternativa en el menú del widget."
                }
                return
            }
            requestLaunch(app)
        }
    }

    private func editWidgetOptionsHandle(_ widget: BloomBoxPlacedWidget,
                                         pageIndex index: Int) -> some View {
        Menu {
            homeWidgetMenu(widget, pageIndex: index)
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(7)
                .background(.black.opacity(0.72), in: Circle())
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Opciones del widget")
    }

    @ViewBuilder private func homeWidgetMenu(_ widget: BloomBoxPlacedWidget,
                                             pageIndex index: Int) -> some View {
        Menu("Acción al tocar", systemImage: "hand.tap.fill") {
            Button("Comportamiento normal", systemImage: "hand.tap") {
                updateWidget(widget.id) { $0.tapActionKey = nil }
            }
            Menu("Apps de BloomBox", systemImage: "square.grid.2x2.fill") {
                Button("App Store", systemImage: "bag.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = Self.appStoreKey }
                }
                Button("Módulos", systemImage: "square.stack.3d.up.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = Self.modulesKey }
                }
                Button("Tweak Store", systemImage: "puzzlepiece.extension.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = Self.tweakStoreKey }
                }
                Button("SideStore", systemImage: "square.stack.3d.up.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = Self.sideStoreKey }
                }
                Button("Instalar app", systemImage: "square.and.arrow.down.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = Self.installKey }
                }
            }
            Menu("Herramientas y módulos", systemImage: "slider.horizontal.3") {
                Button("JIT", systemImage: "bolt.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:jit" }
                }
                Button("Escritorio", systemImage: "square.grid.3x3.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:desktop" }
                }
                Button("Wallpapers", systemImage: "photo.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:wallpaper" }
                }
                Button("Personalizar interfaz", systemImage: "paintbrush.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:interface" }
                }
                Button("Administrar apps", systemImage: "square.grid.2x2.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:apps" }
                }
                Button("Ajustes", systemImage: "gearshape.fill") {
                    updateWidget(widget.id) { $0.tapActionKey = "widget:settings" }
                }
            }
            Menu("Abrir app instalada", systemImage: "app.badge") {
                ForEach(appKeys.filter { appMap[$0] != nil }.sorted {
                    title($0).localizedCaseInsensitiveCompare(title($1)) == .orderedAscending
                }, id: \.self) { key in
                    Button(title(key)) {
                        updateWidget(widget.id) { $0.tapActionKey = key }
                    }
                }
            }
        }
        if let target = widget.tapActionKey, !target.hasPrefix("widget:"),
           !target.hasPrefix("manzana:") {
            Menu("Si falta la app", systemImage: "arrow.triangle.branch") {
                Button("Abrir App Store de BloomBox", systemImage: "bag.fill") {
                    setWidgetFallback(widget.id, value: "appstore")
                }
                Button("Abrir instalador de BloomBox", systemImage: "square.and.arrow.down") {
                    setWidgetFallback(widget.id, value: "installer")
                }
                Button("Solo mostrar aviso", systemImage: "exclamationmark.bubble") {
                    setWidgetFallback(widget.id, value: nil)
                }
            }
        }
        Button("Mover widget", systemImage: "hand.draw.fill") {
            selectedWidgetID = widget.id
            enterEditMode()
        }
        if widget.kind == "notes" {
            Button("Editar nota", systemImage: "square.and.pencil") {
                editingWidgetNote = true
            }
        }
        if widget.kind == "media" {
            Button("Cambiar imagen o GIF", systemImage: "photo.badge.plus") {
                requestWidgetMedia(for: widget.id)
            }
            Button(widget.fill ? "Mostrar imagen completa" : "Rellenar widget",
                   systemImage: "arrow.up.left.and.arrow.down.right") {
                updateWidget(widget.id) { $0.fill.toggle() }
            }
        }
        if widget.kind == "clock" {
            Menu("Estilo de reloj", systemImage: "clock") {
                Button("Minimalista") { updateWidget(widget.id) { $0.clockStyle = "minimal" } }
                Button("Flip retro") { updateWidget(widget.id) { $0.clockStyle = "flip" } }
                Button("Analógico") { updateWidget(widget.id) { $0.clockStyle = "analog" } }
                Button("Pixel") { updateWidget(widget.id) { $0.clockStyle = "pixel" } }
            }
            Menu("Color del reloj", systemImage: "paintpalette") {
                Button("Blanco") { updateWidget(widget.id) { $0.clockTint = "white" } }
                Button("Menta") { updateWidget(widget.id) { $0.clockTint = "mint" } }
                Button("Rosa") { updateWidget(widget.id) { $0.clockTint = "pink" } }
                Button("Ámbar") { updateWidget(widget.id) { $0.clockTint = "amber" } }
            }
            Menu("Formato de hora", systemImage: "textformat.123") {
                Button("24 horas") { updateWidget(widget.id) { $0.clock24Hour = true } }
                Button("12 horas") { updateWidget(widget.id) { $0.clock24Hour = false } }
            }
            if widget.clockStyle == "pixel" {
                Menu("Brillo Pixel Time", systemImage: "sun.max") {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                        Button("\(value)%") {
                            updateWidget(widget.id) { $0.pixelGlow = Double(value) / 100 }
                        }
                    }
                }
                Button("Animar barra Pixel Time · activar/desactivar") {
                    updateWidget(widget.id) { $0.pixelAnimatedBar = !($0.pixelAnimatedBar ?? false) }
                }
                Button((livingSettings(for: widget.id).pixelFollowGlow ?? false)
                    ? "Pixel Time: volver a su color original"
                    : "Pixel Time: usar el color del brillo") {
                    setLivingSettings(widget.id) { $0.pixelFollowGlow = !($0.pixelFollowGlow ?? false) }
                }
            }
        }
        Menu("Living Widget · Movimiento", systemImage: "sparkles.rectangle.stack") {
            Button("Sin movimiento") { setLivingSettings(widget.id) { $0.mode = "none" } }
            Button("Flotar ↕") { setLivingSettings(widget.id) { $0.mode = "float" } }
            Button("Izquierda y derecha ↔") { setLivingSettings(widget.id) { $0.mode = "horizontal" } }
            Button("Paseo suave ✦") { setLivingSettings(widget.id) { $0.mode = "wander" } }
            Menu("Velocidad") {
                ForEach([10, 25, 50, 75, 100], id: \.self) { value in
                    Button("\(value)%") { setLivingSettings(widget.id) { $0.speed = Double(value) } }
                }
            }
            Menu("Recorrido") {
                ForEach([10, 25, 40, 60, 80, 100], id: \.self) { value in
                    Button("\(value)%") { setLivingSettings(widget.id) { $0.travel = Double(value) } }
                }
            }
        }
        Menu("Profundidad y cristal", systemImage: "square.3.layers.3d") {
            Button("Sombra flotante · activar/desactivar") {
                setLivingSettings(widget.id) { $0.depth = !($0.depth ?? false) }
            }
            Button("Brillo inferior · activar/desactivar") {
                setLivingSettings(widget.id) { $0.glow = !($0.glow ?? false) }
            }
            Button("Borde del color del brillo · activar/desactivar") {
                setLivingSettings(widget.id) { $0.adaptiveGlass = !($0.adaptiveGlass ?? false) }
            }
            Menu("Color del brillo", systemImage: "paintpalette.fill") {
                Button("Automático · imagen o reloj") {
                    setLivingSettings(widget.id) { $0.glowColor = "auto"; $0.glow = true }
                }
                Button("Menta") {
                    setLivingSettings(widget.id) { $0.glowColor = "mint"; $0.glow = true }
                }
                Button("Azul") {
                    setLivingSettings(widget.id) { $0.glowColor = "blue"; $0.glow = true }
                }
                Button("Rosa") {
                    setLivingSettings(widget.id) { $0.glowColor = "pink"; $0.glow = true }
                }
                Button("Ámbar") {
                    setLivingSettings(widget.id) { $0.glowColor = "amber"; $0.glow = true }
                }
                Button("Rojo") {
                    setLivingSettings(widget.id) { $0.glowColor = "red"; $0.glow = true }
                }
                Button("Blanco") {
                    setLivingSettings(widget.id) { $0.glowColor = "white"; $0.glow = true }
                }
            }
        }
        Menu("Tamaño del widget", systemImage: "arrow.up.left.and.arrow.down.right") {
            Button("Pequeño · 1×1") { resizeWidget(widget.id, columns: 1, rows: 1) }
            Button("Cuadrado · 2×2") { resizeWidget(widget.id, columns: 2, rows: 2) }
            Button("Ancho · 4×2") { resizeWidget(widget.id, columns: 4, rows: 2) }
            Button("Grande · 4×4") { resizeWidget(widget.id, columns: 4, rows: 4) }
        }
        Button(widget.glass ? "Sin Liquid Glass" : "Activar Liquid Glass",
               systemImage: "square.on.square") {
            updateWidget(widget.id) { $0.glass.toggle() }
        }
        Menu("Mover a página", systemImage: "rectangle.on.rectangle") {
            ForEach(layout.pages.indices, id: \.self) { target in
                Button("Página \(target + 1)") {
                    movePlacedWidget(widget.id, to: target, slot: nil)
                }.disabled(target == index)
            }
        }
        Button("Eliminar widget", systemImage: "trash", role: .destructive) {
            removePlacedWidget(widget.id)
        }
    }

    private func homeIconGrid(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        let cellWidth = (width - 28) / 4
        let pitch = min(editing ? 92 : 99, max(72, (height - (editing ? 69 : 39)) / 6))
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<4, id: \.self) { column in
                        let slot = row * 4 + column
                        let key = layout.pages[index][slot]
                        ZStack(alignment: .top) {
                            if let key, !occupiedCells(on: index).contains(slot) {
                                homeItem(key, showLabel: !largeIcons)
                                    .modifier(aliveEntrance(for: index,
                                        delay: Double(column) * 0.145 + Double(row) * 0.026,
                                        key: key))
                                    .background {
                                        GeometryReader { iconGeometry in
                                            Color.clear.preference(
                                                key: BloomBoxAliveIconFrames.self,
                                                value: page == index + 1
                                                    ? [key: iconGeometry.frame(in: .named("bloombox.alive.viewport"))]
                                                    : [:])
                                        }
                                    }
                                    .transition(reduceMotion ? .opacity : .scale(scale: 0.25).combined(with: .opacity))
                            }
                            else {
                                Color.clear.frame(width: largeIcons ? 76 : 64, height: largeIcons ? 76 : 80)
                                    .contentShape(Rectangle())
                                    .onLongPressGesture(minimumDuration: 0.48, maximumDistance: 14, perform: enterEditMode)
                            }
                        }
                        .frame(width: cellWidth, height: pitch, alignment: .top)
                        .contentShape(Rectangle())
                        .onDrop(of: [UTType.text], delegate: LiveBoardMoveDropDelegate { providers in
                            acceptHomeDrop(providers, pageIndex: index, slot: slot)
                        })
                    }
                }
            }
            Spacer(minLength: 0)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.48, maximumDistance: 14, perform: enterEditMode)
        }
        .padding(.horizontal, 14)
        .padding(.top, editing ? 50 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            // Background hit-testing only: gestures on app icons keep their context menus.
            Color.clear.contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.48, maximumDistance: 14, perform: enterEditMode)
        }
    }

    private func homeItem(_ key: String, showLabel: Bool) -> some View {
        Group {
            if let folder = layout.folders.first(where: { $0.id == key }) {
                folderIcon(folder, showLabel: showLabel)
            } else if [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey, Self.themesKey].contains(key) {
                shortcutIcon(key, showLabel: showLabel)
            } else if let app = appMap[key] {
                LiveBoardHomeIcon(app: app, title: title(key), size: largeIcons ? 76 : 64,
                                  showLabel: showLabel, dark: darkIcons, editing: editing,
                                  reduceMotion: reduceMotion, action: {
                    if editing { return }
                    requestLaunch(app)
                })
                .contextMenu { appMenu(key, app: app) }
            }
        }
        .overlay(alignment: .topLeading) {
            if editing && (appMap[key] != nil || layout.folders.contains(where: { $0.id == key })) {
                Button { pendingRemovalKey = key } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .frame(width: 25, height: 25)
                        .background(Circle().fill(Color(white: 0.82)))
                }
                .buttonStyle(.plain)
                .offset(x: -7, y: -8)
                .zIndex(2)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                .accessibilityLabel("Opciones para quitar \(title(key))")
            }
        }
        .onDrag { NSItemProvider(object: key as NSString) }
        .accessibilityIdentifier("home.icon.\(key)")
    }

    private func shortcutIcon(_ key: String, showLabel: Bool) -> some View {
        let size: CGFloat = largeIcons ? 76 : 64
        let isSideStore = key == Self.sideStoreKey
        let isTweakStore = key == Self.tweakStoreKey
        let isAppStore = key == Self.appStoreKey
        let isModules = key == Self.modulesKey
        let isThemes = key == Self.themesKey
        return Button {
            guard !editing else { return }
            if isSideStore { openSideStore() }
            else if isTweakStore { tweakStorePresented = true }
            else if isAppStore { appStorePresented = true }
            else if isModules { modulesPresented = true }
            else if isThemes { themesPresented = true }
            else { openInstall() }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isModules {
                        BloomBoxModulesIcon(size: size)
                    } else if isThemes {
                        BloomBoxThemesIcon(size: size)
                    } else {
                        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                            .fill(isSideStore ? Color(red: 0.14, green: 0.26, blue: 0.69)
                                               : isTweakStore ? Color(red: 0.48, green: 0.32, blue: 0.76)
                                               : isAppStore ? Color(red: 0.20, green: 0.55, blue: 0.77)
                                               : Color(red: 0.12, green: 0.58, blue: 0.76))
                        if isSideStore, let icon = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(darkIcons) {
                            Image(uiImage: icon).resizable().scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
                        } else {
                            Image(systemName: isSideStore ? "square.stack.3d.up.fill" : isTweakStore ? "puzzlepiece.extension.fill" : isAppStore ? "bag.fill" : "square.and.arrow.down.fill")
                                .font(.system(size: size * 0.44, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: size, height: size)
                .modifier(BloomBoxIconTreatment())
                .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
                .modifier(LiveBoardEditWobble(active: editing && !reduceMotion,
                         phase: isSideStore ? 0.7 : 2.1))
                if showLabel {
                    Text(isSideStore ? "SideStore" : isTweakStore ? "Tweak Store" : isAppStore ? "App Store" : isModules ? "Módulos" : isThemes ? "Temas" : "Instalar app")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                        .frame(width: 82)
                }
            }
        }
        .buttonStyle(LiveBoardHomePressStyle(reduceMotion: reduceMotion))
        .contextMenu {
            Button("Editar pantalla de inicio", systemImage: "square.grid.3x3") { enterEditMode() }
            if layout.dock.contains(key) {
                Button("Mover al escritorio", systemImage: "rectangle.bottomthird.inset.filled") {
                    layout.place(key, on: max(0, page - 1)); reconcile()
                }
            } else if layout.dock.count < 4 {
                Button("Añadir al Dock", systemImage: "rectangle.bottomthird.inset.filled") {
                    layout.putInDock(key); reconcile()
                }
            }
            Menu("Mover a página", systemImage: "rectangle.on.rectangle") {
                ForEach(layout.pages.indices, id: \.self) { index in
                    Button("Página \(index + 1)") {
                        layout.place(key, on: index); page = index + 1; reconcile()
                    }
                }
            }
            Menu(englishUI ? "Folder" : "Carpeta", systemImage: "folder") {
                Button(englishUI ? "New Folder" : "Nueva carpeta", systemImage: "folder.badge.plus") {
                    newFolderApp = key
                    folderName = "BloomBox"
                }
                ForEach(layout.folders) { folder in
                    Button(folder.name, systemImage: "folder") {
                        layout.put(key, in: folder.id)
                        reconcile()
                    }
                }
                if layout.folders.contains(where: { $0.apps.contains(key) }) {
                    Button(englishUI ? "Move Out of Folder" : "Sacar de carpeta", systemImage: "folder.badge.minus") {
                        layout.place(key, on: max(0, page - 1))
                        reconcile()
                    }
                }
            }
        }
        .accessibilityLabel(isThemes ? "Temas" : title(key))
    }

    @ViewBuilder private func appMenu(_ key: String, app: LCAppModel) -> some View {
        Button("Launch", systemImage: "play.fill") { requestLaunch(app) }.disabled(app.isAppRunning || app.isSigningInProgress)
        if let launchWithJIT { Button("Launch with JIT", systemImage: "bolt.fill") { requestLaunch(app, jit: true) }.disabled(app.appInfo is BuiltInSideStoreAppInfo) }
        Button("Edit Home Screen", systemImage: "square.grid.3x3") { enterEditMode() }
        Button("Rename", systemImage: "pencil") { renameValue = title(key); renameKey = key }
        Button("Change app icon", systemImage: "photo") { appearanceApp = LiveBoardAppearanceSelection(app: app) }
        Button(favoriteKeys.contains(key) ? "Unfavorite" : "Favorite", systemImage: "star") {
            var values = favoriteKeys
            if values.contains(key) { values.removeAll { $0 == key } } else { values.append(key) }
            if let data = try? JSONEncoder().encode(values), let string = String(data: data, encoding: .utf8) { favorites = string }
        }
        if layout.dock.contains(key) {
            Button("Remove from Dock", systemImage: "rectangle.bottomthird.inset.filled") { layout.place(key, on: max(0, page - 1)); reconcile() }
        } else if layout.dock.count < 4 {
            Button("Add to Dock", systemImage: "rectangle.bottomthird.inset.filled") { layout.putInDock(key); reconcile() }
        }
        Menu("Move to Page", systemImage: "rectangle.on.rectangle") {
            ForEach(layout.pages.indices, id: \.self) { index in
                Button("Page \(index + 1)") { layout.place(key, on: index); reconcile() }
            }
            Button("New Page") { let target = layout.pages.count; layout.place(key, on: target); page = target + 1; reconcile() }
        }
        Menu("Folder", systemImage: "folder") {
            Button("New Folder") { newFolderApp = key; folderName = "Apps" }
            ForEach(layout.folders) { folder in
                Button(folder.name) { layout.put(key, in: folder.id); reconcile() }
            }
            if layout.folders.contains(where: { $0.apps.contains(key) }) {
                Button("Move out of Folder") { layout.place(key, on: max(0, page - 1)); reconcile() }
            }
        }
        Menu("Category", systemImage: "tag") {
            ForEach((try? JSONDecoder().decode([String].self, from: Data(homeCategories.utf8))) ?? ["Games", "Ports", "Tools"], id: \.self) { value in Button(value) { setCategory(value, key: key) } }
            Button("New Category…") { categoryApp = key; categoryName = ""; addingCategory = true }
            Button("Uncategorized") { setCategory(nil, key: key) }
        }
        Button(app.uiNetworkBlocked ? "Permitir Internet" : "Bloquear Internet (experimental)",
               systemImage: app.uiNetworkBlocked ? "wifi" : "wifi.slash") {
            app.uiNetworkBlocked.toggle()
            let blocked = app.uiNetworkBlocked
            let name = title(key)
            // A context menu must dismiss before its in-app notice can be shown.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showNetworkNotice(blocked
                    ? "«\(name)» ya no contará con acceso a Internet."
                    : "«\(name)» volverá a tener acceso a Internet.")
            }
        }
        .disabled(app.isAppRunning)
        Button("Añadir Tweak", systemImage: "square.and.arrow.down.on.square") {
            pendingTweakApp = app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if pendingTweakApp === app { choosingAppTweak = true }
            }
        }
        .disabled(app.isSigningInProgress)
        Button("Ajustes de LiveContainer", systemImage: "gearshape") {
            searching = false
            manage(app)
        }
        Button("Desinstalar app", systemImage: "trash", role: .destructive) {
            pendingUninstall = app
        }
        .disabled(app.isAppRunning || app.isSigningInProgress)
        Button("Quitar del escritorio", systemImage: "minus.circle", role: .destructive) {
            removeFromHome(key)
        }
    }

    private func showNetworkNotice(_ message: String) {
        let token = UUID()
        networkNoticeToken = token
        withAnimation(reduceMotion ? nil : .spring(response: 0.33, dampingFraction: 0.85)) {
            networkNoticeText = message
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard networkNoticeToken == token else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                networkNoticeText = nil
            }
        }
    }

    /// Import selected dylibs into this app's assigned tweak folder.
    /// Existing associations stay unchanged, and Files originals remain intact.
    private func installTweakFiles(_ urls: [URL], for app: LCAppModel) {
        guard !urls.isEmpty else { return }
        let fm = FileManager.default
        let folderName = app.uiTweakFolder ?? ("BloomBox-" + String(UUID().uuidString.prefix(12)))
        let root = app.uiIsShared ? LCPath.lcGroupTweakPath : LCPath.tweakPath
        let folder = root.appendingPathComponent(folderName, isDirectory: true)
        var imported = 0
        var failures: [String] = []

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let name = url.lastPathComponent
                guard url.isFileURL, !name.isEmpty, name != ".", name != "..",
                      !name.contains("/"), !name.contains("\\") else {
                    throw CocoaError(.fileReadInvalidFileName)
                }
                let dylib = name.lowercased().hasSuffix(".dylib")
                let framework = name.lowercased().hasSuffix(".framework")
                guard dylib || framework else {
                    throw NSError(domain: "BloomBox.Tweaks", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Solo admite .dylib y .framework"])
                }
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent(name)
                guard !fm.fileExists(atPath: destination.path) else {
                    throw NSError(domain: "BloomBox.Tweaks", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Ya existe \(name) en la carpeta de la app"])
                }
                try fm.copyItem(at: url, to: destination)
                if dylib {
                    LCParseMachO((destination.path as NSString).utf8String, false) { path, header, _, _ in
                        LCPatchAddRPath(path, header)
                    }
                }
                imported += 1
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if imported > 0 {
            if app.uiTweakFolder == nil { app.uiTweakFolder = folderName }
            if !app.uiIsShared && !sharedModel.tweakFolderNames.contains(folderName) {
                sharedModel.tweakFolderNames.append(folderName)
            }
        }
        if !failures.isEmpty {
            appTweakError = failures.joined(separator: "\n")
        }
    }

    private func dock(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { slot in
                ZStack {
                    if layout.dock.indices.contains(slot) {
                        homeItem(layout.dock[slot], showLabel: false)
                            .modifier(aliveEntrance(for: max(0, page - 1),
                                 delay: 0.69 + Double(slot) * 0.16, key: layout.dock[slot]))
                    } else {
                        Color.clear
                            .frame(width: largeIcons ? 76 : 64, height: largeIcons ? 76 : 80)
                    }
                }
                .frame(width: (width - 32) / 4, height: 110)
                .contentShape(Rectangle())
                .onDrop(of: [UTType.text], delegate: LiveBoardMoveDropDelegate { providers in
                    acceptDrop(providers) { key in
                        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.84)) {
                            _ = layout.moveToDock(key, at: slot, fallbackPage: max(0, page - 1))
                            reconcile()
                        }
                    }
                })
                .accessibilityIdentifier("home.dock.slot.\(slot)")
            }
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .liveBoardGlass(radius: 34, interactive: false)
        .contentShape(RoundedRectangle(cornerRadius: 34))
        .accessibilityIdentifier("home.dock")
    }

    private var pageControl: some View {
        HStack(spacing: 5) {
            Button { page = 1 } label: { Image(systemName: "house.fill").frame(width: 32, height: 32) }
                .accessibilityLabel("Pantalla de inicio")
            Button { beginSearch() } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 32)
            }.accessibilityLabel("Search")
            Rectangle().fill(.white.opacity(0.22)).frame(width: 0.5, height: 12).padding(.trailing, 3)
            ForEach([0] + visiblePageIndices.map { $0 + 1 }, id: \.self) { index in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        page = index
                    }
                } label: {
                    Circle().fill(.white.opacity(page == index ? 1 : 0.35))
                        .frame(width: 6, height: 6)
                        .frame(width: 27, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(index == 0 ? "Widgets" : "Página \(index)")
                // Do not attach a drop target to navigation buttons; it can
                // consume taps. Use the widget's "Mover a página" menu instead.
            }
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                    page = libraryPageIndex
                }
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(page == libraryPageIndex ? 1 : 0.55))
                    .frame(width: 21, height: 32)
            }
            .accessibilityLabel("Biblioteca de apps")
            if editing {
                Button { pageManager = true } label: {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 32)
                }.accessibilityLabel("Gestionar páginas")
                Button { addPage() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 32)
                }.accessibilityLabel("Añadir página")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(height: 40)
        .liveBoardGlass(radius: 16, interactive: false)
        .blur(radius: openFolder == nil ? 0 : 18)
        .accessibilityIdentifier("home.pages")
    }

    @ViewBuilder private func folderIcon(_ folder: BloomBoxHomeLayout.Folder, showLabel: Bool) -> some View {
        let size: CGFloat = largeIcons ? 76 : 64
        let folderTile = Button {
            guard !editing else { return }
            folderPage = 0
            withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.78)) {
                openFolder = folder.id
            }
        } label: {
            VStack(spacing: 5) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(0..<9, id: \.self) { slot in
                        Group {
                            if slot < folder.apps.count {
                                let key = folder.apps[slot]
                                if let app = appMap[key] {
                                    LiveBoardIconImage(app: app, dark: darkIcons)
                                } else if [Self.modulesKey, Self.tweakStoreKey, Self.appStoreKey,
                                           Self.installKey, Self.sideStoreKey, Self.themesKey].contains(key) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(key == Self.themesKey ? Color(red: 0.56, green: 0.30, blue: 0.84) :
                                                  key == Self.modulesKey ? Color.indigo :
                                                  key == Self.tweakStoreKey ? Color.purple :
                                                  key == Self.appStoreKey ? Color.blue :
                                                  key == Self.sideStoreKey ? Color(red: 0.14, green: 0.26, blue: 0.69) : Color.cyan)
                                        Image(systemName: key == Self.themesKey ? "square.on.square.fill" :
                                              key == Self.modulesKey ? "square.grid.2x2.fill" :
                                              key == Self.tweakStoreKey ? "puzzlepiece.extension.fill" :
                                              key == Self.appStoreKey ? "bag.fill" :
                                              key == Self.installKey ? "square.and.arrow.down.fill" : "square.stack.3d.up.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                } else { Color.clear }
                            } else { Color.clear }
                        }.aspectRatio(1, contentMode: .fit)
            .modifier(BloomBoxIconTreatment()).clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(6).frame(width: size, height: size)
                .liveBoardGlass(radius: size * 0.23)
                .modifier(LiveBoardEditWobble(active: editing && !reduceMotion,
                                                phase: Double(abs(folder.id.hashValue % 31)) / 7,
                                                speed: 8.0, amplitude: 1.0))
                if showLabel { Text(folder.name).font(.system(size: 12)).lineLimit(1).shadow(color: .black.opacity(0.8), radius: 2, y: 1).frame(width: 80) }
            }
        }.buttonStyle(.plain)
        if editing {
            // While editing it is a drag *source*, not a competing drop
            // target/context menu. The parent homeItem's onDrag can lift it.
            folderTile
                .accessibilityLabel("\(folder.name), carpeta movible")
        } else {
            folderTile
                .contextMenu {
                    Button("Editar pantalla de inicio", systemImage: "square.grid.3x3") { enterEditMode() }
                    Button("Renombrar", systemImage: "pencil") {
                        renameKey = folder.id; renameValue = folder.name
                    }
                    Menu("Mover a página") {
                        ForEach(layout.pages.indices, id: \.self) { index in
                            Button("Página \(index + 1)") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    layout.place(folder.id, on: index)
                                    reconcile()
                                }
                            }
                        }
                    }
                    Button("Eliminar carpeta", systemImage: "folder.badge.minus", role: .destructive) {
                        layout.dissolveFolder(folder.id); reconcile()
                    }
                }
                .onDrop(of: [UTType.text], delegate: LiveBoardMoveDropDelegate { providers in
                    acceptDrop(providers) { key in layout.put(key, in: folder.id); reconcile() }
                })
                .accessibilityLabel("\(folder.name), carpeta, \(folder.apps.count) apps")
        }
    }

    private func folderOverlay(_ folder: BloomBoxHomeLayout.Folder, width: CGFloat) -> some View {
        BloomBoxFolderPanel(
            folder: folder,
            width: width,
            reduceMotion: reduceMotion,
            page: $folderPage,
            icon: { key in homeItem(key, showLabel: !largeIcons) },
            rename: {
                renameKey = folder.id
                renameValue = folder.name
            },
            close: {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                    openFolder = nil
                }
            }
        )
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { requestDesktopAction(.interface) } label: { controlCard("Interface", detail: "iOS Home Screen", symbol: "square.grid.3x3.fill", wide: true) }
                HStack(spacing: 16) {
                    Button { requestDesktopAction(.sources) } label: {
                        controlCard("lc.tabView.sources".loc, detail: secondaryInstance ? "Manage in primary instance" : "Discover & install", symbol: "books.vertical", wide: false)
                    }.disabled(secondaryInstance).accessibilityIdentifier("home.controls.sources")
                    Button { requestDesktopAction(.tweaks) } label: {
                        controlCard("lc.tabView.tweaks".loc, detail: secondaryInstance ? "Manage in primary instance" : "App extensions", symbol: "wrench.and.screwdriver", wide: false)
                    }.disabled(secondaryInstance).accessibilityIdentifier("home.controls.tweaks")
                }
                HStack(spacing: 16) {
                    Button { requestDesktopAction(.wallpaper) } label: { controlCard("Wallpaper", detail: "Customize", symbol: "photo", wide: false) }
                    Button { requestDesktopAction(.apps) } label: { controlCard("Apps", detail: "Install & manage", symbol: "square.stack.3d.up", wide: false) }
                }
                HStack(spacing: 16) {
                    Button { requestDesktopAction(.settings) } label: { controlCard("lc.tabView.settings".loc, detail: "LiveContainer", symbol: "gearshape.fill", wide: false) }.accessibilityIdentifier("home.controls.settings")
                    Button { requestDesktopAction(.jit) } label: { controlCard("JIT", detail: "Setup & providers", symbol: "bolt.fill", wide: false) }.accessibilityIdentifier("home.controls.jit")
                }
            }.buttonStyle(.plain).padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
        }
    }
    private func controlCard(_ title: String, detail: String, symbol: String, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(.white.opacity(0.95))
            Spacer(minLength: 2)
            Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
            if !detail.isEmpty {
                Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: wide ? 124 : 128)
        .liveBoardGlass(radius: 28, interactive: false)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }

    private var searchResults: [LCAppModel] {
        apps.filter { query.isEmpty || title(liveBoardAppKey($0)).localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query) }
    }
    private func beginSearch() {
        openFolder = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { searching = true }
    }
    private func closeSearch() {
        searchFocused = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { searching = false }
        query = ""
    }

    private func searchOverlay(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.12).contentShape(Rectangle()).onTapGesture { closeSearch() }
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 21)).foregroundStyle(.white.opacity(0.75))
                        TextField("Search Apps", text: $query)
                            .font(.system(size: 22, weight: .regular))
                            .textInputAutocapitalization(.never).disableAutocorrection(true)
                            .submitLabel(.search).focused($searchFocused)
                            .accessibilityIdentifier("home.search.field")
                            .onSubmit {
                                if !query.isEmpty, let app = searchResults.first { closeSearch(); requestLaunch(app) }
                            }
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.65)) }
                                .accessibilityLabel("Clear search")
                        }
                    }.padding(.horizontal, 18).frame(height: 58).liveBoardGlass(radius: 28)
                    Button { closeSearch() } label: {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .medium)).frame(width: 48, height: 48)
                    }.liveBoardGlass(radius: 24).accessibilityLabel("Done").accessibilityIdentifier("home.search.done")
                }
                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Suggestions").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 18) {
                            ForEach(Array(searchResults.prefix(8)), id: \.self) { app in
                                searchIcon(app)
                            }
                        }
                    }.padding(18).liveBoardGlass(radius: 30, interactive: false)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { app in
                                let key = liveBoardAppKey(app)
                                Button { closeSearch(); requestLaunch(app) } label: {
                                    HStack(spacing: 14) {
                                        LiveBoardIconImage(app: app, dark: darkIcons).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        Text(title(key)).font(.system(size: 17)).lineLimit(1)
                                        Spacer()
                                        if layout.hidden.contains(key) { Image(systemName: "plus.circle").foregroundStyle(.white.opacity(0.6)) }
                                    }.padding(.horizontal, 18).padding(.vertical, 11)
                                }.buttonStyle(.plain).contextMenu { searchMenu(key, app: app) }
                            }
                            if searchResults.isEmpty { Text("No Results").foregroundStyle(.white.opacity(0.65)).padding(24) }
                        }
                    }
                    .frame(height: min(380, height * 0.48, CGFloat(max(1, searchResults.count)) * 66))
                    .liveBoardGlass(radius: 30, interactive: false)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { closeSearch() }
    }
    private func searchIcon(_ app: LCAppModel) -> some View {
        let key = liveBoardAppKey(app)
        return Button { closeSearch(); requestLaunch(app) } label: {
            VStack(spacing: 6) {
                LiveBoardIconImage(app: app, dark: darkIcons).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title(key)).font(.system(size: 12)).lineLimit(1)
            }
        }.buttonStyle(.plain).contextMenu { searchMenu(key, app: app) }
    }
    @ViewBuilder private func searchMenu(_ key: String, app: LCAppModel) -> some View {
        if layout.hidden.contains(key) {
            Button("Add to Home Screen", systemImage: "plus") { layout.place(key, on: max(0, page - 1)); reconcile() }
        }
        appMenu(key, app: app)
    }

    @ViewBuilder private var iconCustomizationSheet: some View {
        if #available(iOS 16.4, *) {
            BloomBoxIconCustomization().padding(12)
                .presentationDetents([.height(420), .medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        } else { BloomBoxIconCustomization().padding() }
    }
    private var customizeSheet: some View {
        NavigationView {
            Form {
                Section("Wallpaper") {
                    Button("Elegir video o GIF (Fotos)") {
                        customizing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { choosingMotionWallpaperPhotos = true }
                    }
                    .disabled(importingMotionWallpaper)
                    Button("Importar video o GIF (Archivos)") { customizing = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { choosingMotionWallpaper = true } }
                        .disabled(importingMotionWallpaper)
                    if importingMotionWallpaper { ProgressView("Preparando fondo…") }
                    if !motionWallpaper.isEmpty { Toggle("Pausar fondo animado", isOn: $pauseWallpaper) }
                    Button("Choose Photo") { customizing = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { choosingWallpaper = true } }
                    Picker("Background", selection: $wallpaperStyle) {
                        Text("Red ribbons").tag("red"); Text("Blue ribbons").tag("blue"); Text("Black").tag("black")
                        if wallpaper != nil { Text("Your photo").tag("photo") }
                        if !motionWallpaper.isEmpty { Text("Video / GIF").tag("motion") }
                    }
                    if wallpaperStyle == "photo" || wallpaperStyle == "motion" { Toggle("Mostrar fondo completo", isOn: $wallpaperFit) }
                    VStack(alignment: .leading) { Text("Dim wallpaper"); Slider(value: $wallpaperDim, in: 0...0.7) }
                }
                Section("Iconos") { BloomBoxIconCustomization() }
                Section("Appearance") {
                    Toggle("Large icons", isOn: $largeIcons)
                    Toggle("Reduce motion", isOn: $customReduceMotion)
                    Toggle("BloomBox Alive al iniciar", isOn: $aliveEnabled)
                    Toggle("Iconos traviesos en reposo", isOn: $aliveIdleEnabled)
                        .disabled(!aliveEnabled || reduceMotion)
                    Text("La ola va de izquierda a derecha. Los iconos solo se mueven cuando estás sin interactuar en la página visible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Dark app icons", isOn: $darkIcons)
                }
                Section("BloomBox Alive") {
                    Button("Probar brinco de un icono") {
                        customizing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                            if triggerAliveIconTrick() {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
                                    withAnimation(.spring(response: 0.29, dampingFraction: 0.60)) {
                                        alivePlayfulActive = false
                                    }
                                    alivePlayfulKey = nil
                                }
                            }
                        }
                    }
                    .disabled(!aliveEnabled || !aliveIdleEnabled || reduceMotion)
                    Button("Repetir ola de bienvenida") {
                        customizing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                            aliveStartupPlayed = false
                            startBloomBoxAlive()
                        }
                    }
                    .disabled(!aliveEnabled || reduceMotion)
                    Text("La frase cambia en cada inicio. El brinco solo elige iconos visibles de la página actual.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Home Screen") {
                    Button("Edit Home Screen") { customizing = false; editing = true }
                    Button("Add Page") { addPage(); customizing = false; editing = true }
                    Button("App Management") { customizing = false; openManagement() }
                    Button("Interface Options") { customizing = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openInterface() } }
                }
            }
            .navigationTitle("Customize")
            .navigationBarHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { customizing = false } } }
        }.navigationViewStyle(.stack)
    }
    private func performModuleAction() {
        guard let destination = pendingModuleDestination else { return }
        pendingModuleDestination = nil
        switch destination {
        case .jit: jitSetup = true
        case .desktop: desktopSettings = true
        case .interface: openInterface()
        case .wallpaper: customizing = true
        case .apps: openManagement()
        case .settings: openTab(.settings)
        case .sidestore: openSideStore()
        case .tweaks: storeFocusedApp = nil; tweakStorePresented = true
        }
    }

    private func performDesktopAction() {
        guard let action = desktopAction else { return }
        desktopAction = nil
        switch action {
        case .interface: openInterface()
        case .sources: openTab(.sources)
        case .tweaks: openTab(.tweaks)
        case .wallpaper: customizing = true
        case .apps: openManagement()
        case .settings: openTab(.settings)
        case .jit: jitSetup = true
        }
    }

    private func requestDesktopAction(_ action: DesktopAction) {
        desktopAction = action
        desktopSettings = false
    }

    private func removeFromHome(_ key: String) {
        guard key != Self.sideStoreKey, key != Self.installKey else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
            layout.hide(key)
            reconcile()
        }
        pendingRemovalKey = nil
    }

    private func removePage(_ index: Int) {
        guard layout.pages.count > 1, layout.pages.indices.contains(index) else { return }
        let navigator = homeNavigation
        let movedIcons = layout.pages[index].contains { $0 != nil }
        let targetPage = min(index, layout.pages.count - 2)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            if layout.removePage(at: index) {
                // Repair visibility before redistributing widgets; never move
                // a displaced widget into a Home page that is now hidden.
                if let updated = navigator.removedPage(at: index,
                                                       destinationContainsIcons: movedIcons,
                                                       newPageCount: layout.pages.count) {
                    hiddenPagesJSON = updated.encodedHidden
                    page = updated.safePage
                }
                let widgets = BloomBoxHomeNavigation.reindexWidgets(placedWidgets, removing: index)
                savePlacedWidgets(widgets.remaining)
                for widget in widgets.displaced {
                    moveWidgetToAvailablePage(widget, preferred: targetPage)
                }
                reconcile()
            }
        }
    }

    private func enterEditMode() {
        guard !editing, !searching, openFolder == nil else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            editing = true
        }
    }

    private func finishEditing() {
        selectedWidgetID = nil
        pendingRemovalKey = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            editing = false
        }
    }

    private func reconcile() {
        let appsByKey = appMap
        let hadSavedLayout = layout.initialized
        let knownKeys = Set(layout.pages.flatMap { $0.compactMap { $0 } }
            + layout.dock + layout.folders.flatMap { $0.apps } + layout.hidden)
        let needsShortcuts = [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey, Self.themesKey]
            .filter { !knownKeys.contains($0) }
        // Only installed guest apps not seen before, never icons the user hid.
        let newGuestKeys = hadSavedLayout
            ? appKeys.filter { appsByKey[$0] != nil && !knownKeys.contains($0) }
            : []
        layout.reconcile(appKeys, favorites: favoriteKeys)
        for key in needsShortcuts.reversed() {
            layout.place(key, on: 0)
        }
        if !builtInFolderMigrated {
            layout.groupBuiltInShortcuts([
                Self.modulesKey, Self.tweakStoreKey, Self.appStoreKey,
                Self.installKey, Self.sideStoreKey
            ])
            builtInFolderMigrated = true
        }
        if !newGuestKeys.isEmpty {
            let prior = recentLibraryKeys
            let merged = Array(newGuestKeys.reversed()) + prior.filter { !newGuestKeys.contains($0) }
            if let data = try? JSONEncoder().encode(Array(merged.prefix(50))),
               let string = String(data: data, encoding: .utf8) {
                libraryRecentsJSON = string
            }
            let visible = visiblePageIndices
            let preferred = (page > 0 && visible.contains(page - 1))
                ? page - 1 : (visible.first ?? 0)
            if let target = layout.revealNewApps(
                newGuestKeys, visiblePages: visible, preferredPage: preferred
            ), homeHasAppeared {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                    page = target + 1
                }
            }
        }
        if placedWidgetsMigrated { moveIconsOutOfWidgetArea() }
    }
    private func title(_ key: String, appsByKey: [String: LCAppModel]? = nil) -> String {
        if key == Self.sideStoreKey { return "SideStore" }
        if key == Self.installKey { return "Instalar app" }
        if key == Self.tweakStoreKey { return "Tweak Store" }
        if key == Self.appStoreKey { return "App Store" }
        if key == Self.modulesKey { return "Módulos" }
        if key == Self.themesKey { return "Temas" }
        if let folder = layout.folders.first(where: { $0.id == key }) { return folder.name }
        return (appsByKey ?? appMap)[key].map { appCustomization.name($0) } ?? "App"
    }
    private func addPage() { layout.pages.append(Array(repeating: nil, count: BloomBoxHomeLayout.capacity)); page = layout.pages.count }
    private func setCategory(_ value: String?, key: String) {
        var map = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        map[key] = value
        if let data = try? JSONEncoder().encode(map), let string = String(data: data, encoding: .utf8) { categories = string }
    }
    private func moveWidgetToAvailablePage(_ widget: BloomBoxPlacedWidget, preferred: Int) {
        var all = placedWidgets
        let free = BloomBoxWidgetPlacement.freePosition(
            columns: widget.columns, rows: widget.rows, preferredPage: preferred,
            visiblePages: visiblePageIndices, in: all
        )
        guard free != nil || BloomBoxWidgetGrid.cells(
            slot: 0, columns: widget.columns, rows: widget.rows
        ) != nil else { return }
        if free == nil {
            layout.pages.append(Array(repeating: nil, count: BloomBoxHomeLayout.capacity))
        }
        let target = free?.page ?? (layout.pages.count - 1)
        let chosen = free?.slot ?? 0
        var moved = widget
        moved.slot = chosen
        all[target, default: []].append(moved)
        savePlacedWidgets(all)
        moveIconsOutOfWidgetArea()
    }
    private func acceptHomeDrop(_ providers: [NSItemProvider], pageIndex: Int, slot: Int) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) })
        else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let key = object as? String else { return }
            DispatchQueue.main.async {
                if key.hasPrefix("bloombox-widget:") {
                    movePlacedWidget(String(key.dropFirst("bloombox-widget:".count)),
                                     to: pageIndex, slot: slot)
                } else {
                    guard appMap[key] != nil ||
                          layout.folders.contains(where: { $0.id == key }) ||
                          [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey,
                           Self.appStoreKey, Self.modulesKey, Self.themesKey].contains(key) else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.25,
                                                              dampingFraction: 0.85)) {
                        layout.place(key, on: pageIndex, slot: slot)
                        reconcile()
                        moveIconsOutOfWidgetArea()
                    }
                }
            }
        }
        return true
    }
    private func acceptPageDrop(_ providers: [NSItemProvider], pageIndex: Int) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) })
        else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let key = object as? String else { return }
            DispatchQueue.main.async {
                if key.hasPrefix("bloombox-widget:") {
                    movePlacedWidget(String(key.dropFirst("bloombox-widget:".count)),
                                     to: pageIndex, slot: nil)
                } else if appMap[key] != nil ||
                          layout.folders.contains(where: { $0.id == key }) ||
                          [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey,
                           Self.appStoreKey, Self.modulesKey, Self.themesKey].contains(key) {
                    layout.place(key, on: pageIndex)
                    page = pageIndex + 1
                    reconcile()
                    moveIconsOutOfWidgetArea()
                }
            }
        }
        return true
    }
    private func acceptDrop(_ providers: [NSItemProvider], apply: @escaping (String) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let key = value as? String else { return }
            DispatchQueue.main.async {
                guard appMap[key] != nil ||
                      key == Self.sideStoreKey || key == Self.installKey || key == Self.tweakStoreKey || key == Self.appStoreKey || key == Self.modulesKey || key == Self.themesKey ||
                      layout.folders.contains(where: { $0.id == key }) else { return }
                apply(key)
            }
        }
        return true
    }
}


/// Visual-only shortcut. Future .bbtheme exports will retain this stable key.

// Source-compatible entry point for LiveContainer's existing host navigation.
// New launcher logic and UI are implemented in BloomBoxHomeScreen.
typealias LiveBoardHomeScreen = BloomBoxHomeScreen
