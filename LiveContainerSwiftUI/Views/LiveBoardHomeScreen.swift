import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

func liveBoardAppKey(_ app: LCAppModel) -> String {
    if app.appInfo is BuiltInSideStoreAppInfo { return "builtin:sidestore" }
    return "\(app.uiIsShared ? "shared" : "local"):\(app.appInfo.relativeBundlePath ?? app.bundleIdentifier)"
}

struct LiveBoardHomeScreen: View {
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

    @AppStorage("LiveBoardHomeLayout", store: LCUtils.appGroupUserDefault) private var savedLayout = ""
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
    @State private var layout = LiveBoardHomeLayout()
    @State private var page = 1
    @State private var homeHasAppeared = false
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault) private var miniatureNote = ""
    @State private var miniatureWidgetPhoto: UIImage?
    @State private var desktopSettings = false
    @State private var editing = false
    @State private var showWidgetGallery = false
    @AppStorage("ManzanaPageWidgets", store: LCUtils.appGroupUserDefault) private var pageWidgetsJSON = "{}"
    @State private var pendingRemovalKey: String?
    @State private var pendingUninstall: LCAppModel?
    @State private var pendingTweakApp: LCAppModel?
    @State private var choosingAppTweak = false
    @State private var appTweakError: String?
    @State private var networkNoticeText: String?
    @State private var networkNoticeToken = UUID()
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
    private enum DesktopAction { case interface, sources, tweaks, wallpaper, apps, settings, jit }

    private var appKeys: [String] {
        apps.filter { !($0.appInfo is BuiltInSideStoreAppInfo) }.map(liveBoardAppKey)
            + [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey]
    }
    private var appMap: [String: LCAppModel] {
        Dictionary(apps.filter { !($0.appInfo is BuiltInSideStoreAppInfo) }.map {
            (liveBoardAppKey($0), $0)
        }, uniquingKeysWith: { first, _ in first })
    }
    private var hiddenPageIndices: Set<Int> {
        let values = (try? JSONDecoder().decode([Int].self, from: Data(hiddenPagesJSON.utf8))) ?? []
        return Set(values.filter { layout.pages.indices.contains($0) })
    }
    private var visiblePageIndices: [Int] {
        layout.pages.indices.filter { !hiddenPageIndices.contains($0) }
    }
    private var libraryPageIndex: Int { layout.pages.count + 1 }
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
            ZStack {
                background
                    .blur(radius: (searching || page == libraryPageIndex) ? 14 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: page == libraryPageIndex)
                // Render every page in the full GeometryReader. The old VStack
                // permanently reserved ~140pt for a Dock that is hidden on
                // Widgets and App Library, leaving a blank strip and clipping
                // the bottom rows of the library.
                ZStack(alignment: .bottom) {
                    TabView(selection: $page) {
                        ManzanaDesktopView(openSettings: { desktopSettings = true })
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                // Keep the last widget reachable above page controls.
                                Color.clear.frame(height: 54)
                            }
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
                    // Widgets: keep navigation, hide only the app Dock.
                    // Library: hide both controls to maximize scrolling space.
                    VStack(spacing: 0) {
                        pageControl
                            .padding(.bottom, 18)
                            .opacity(page == libraryPageIndex ? 0 : 1)
                            .allowsHitTesting(page != libraryPageIndex)
                            .accessibilityHidden(page == libraryPageIndex)
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
                    VStack {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Instalando aplicación…")
                                    .font(.system(size: 14, weight: .semibold))
                                ProgressView(value: min(1, max(0, installProgress)), total: 1)
                                    .tint(.white)
                                Text("\(Int(min(1, max(0, installProgress)) * 100)) %")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(15)
                        .liveBoardGlass(radius: 22, interactive: false)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Instalando aplicación")
                    .accessibilityValue("(Int(min(1, max(0, installProgress)) * 100)) por ciento")
                    .transition(.opacity)
                }
                if editing && !searching {
                    VStack {
                        HStack {
                            Menu {
                                Button("Añadir widget", systemImage: "square.grid.2x2.badge.plus") { showWidgetGallery = true }
                                Button("Personalizar", systemImage: "paintbrush") { iconCustomization = true }
                                Button("Añadir página", systemImage: "plus") { addPage() }
                                Button("Gestionar páginas", systemImage: "square.grid.2x2") { pageManager = true }
                                Button("Biblioteca de apps", systemImage: "square.grid.2x2") {
                                    finishEditing()
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                                        page = libraryPageIndex
                                    }
                                }
                            } label: { Text("Edit").font(.system(size: 16, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 8) }
                            .liveBoardGlass(radius: 18)
                            Spacer()
                            Button("Listo") { finishEditing() }.font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 8).liveBoardGlass(radius: 18)
                        }.padding(.horizontal, 22)
                        Spacer()
                    }.padding(.top, 0)
                }
                if searching { searchOverlay(height: geometry.size.height) }
                if let id = openFolder, let folder = layout.folders.first(where: { $0.id == id }) {
                    folderOverlay(folder, width: geometry.size.width)
                }
            }
            .foregroundColor(.white)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
                if !searching && !editing && openFolder == nil && page > 0 && page < libraryPageIndex &&
                    value.translation.height > 65 && abs(value.translation.height) > abs(value.translation.width) * 1.4 {
                    beginSearch()
                }
            })
            .onChange(of: scenePhase) { phase in
                if phase == .active { ramPlus.refresh() }
                if phase == .active, #available(iOS 16.2, *) {
                    Task { await ManzanaExpiryReminderCenter.shared.synchronize() }
                }
            }
            .onChange(of: appKeys) { _ in reconcile() }
            .onChange(of: layout) {
                savedLayout = $0.encoded
                page = min(page, libraryPageIndex)
            }
            .onAppear {
                ramPlus.refresh()
                Task { await tweakCatalog.refreshIfNeeded() }
                layout = LiveBoardHomeLayout.decode(savedLayout)
                reconcile()
                homeHasAppeared = true
                wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
                if #available(iOS 16.2, *) {
                    Task { await ManzanaExpiryReminderCenter.shared.synchronize() }
                }
                if page > 0 && hiddenPageIndices.contains(page - 1) {
                    page = (visiblePageIndices.first ?? 0) + 1
                }
            }
        }
        .overlay(alignment: .bottom) {
            if ramPlus.needsAttention {
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
            if let networkNoticeText {
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
                Text("Se quitará la app de LiveContainer y del escritorio de Manzana. Sus carpetas de datos se conservarán. Esta acción no se puede deshacer.")
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
        .sheet(isPresented: $showWidgetGallery) {
            if page > 0 && page <= layout.pages.count {
                ManzanaWidgetGallery(pageSelection: Set(widgets(on: page - 1)), onToggle: { toggleWidget($0, on: page - 1) })
            } else { ManzanaWidgetGallery() }
        }
        .fileImporter(isPresented: $choosingMotionWallpaper, allowedContentTypes: [.movie, .gif]) { result in
            switch result {
            case .success(let url):
                importingMotionWallpaper = true
                Task {
                    do {
                        let name = try await Task.detached(priority: .userInitiated) { try ManzanaWallpaperMedia.importFile(url) }.value
                        let old = motionWallpaper
                        motionWallpaper = name; wallpaperStyle = "motion"
                        if old != name, let oldURL = ManzanaWallpaperMedia.url(old) { try? FileManager.default.removeItem(at: oldURL) }
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

    private var background: some View { wallpaperBackground(paused: pageManager) }

    private func wallpaperBackground(paused: Bool) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if wallpaperStyle == "motion", let url = ManzanaWallpaperMedia.url(motionWallpaper) {
                    ManzanaAnimatedWallpaper(url: url, fit: wallpaperFit,
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
    private func libraryCategory(for key: String, assigned: [String: String], appsByKey: [String: LCAppModel]) -> String {
        if let custom = assigned[key], !custom.isEmpty {
            return custom
        }
        if key == Self.sideStoreKey || key == Self.installKey || key == Self.tweakStoreKey || key == Self.appStoreKey || key == Self.modulesKey { return "Utilidades" }
        let hint = "\(title(key, appsByKey: appsByKey)) \(appsByKey[key]?.bundleIdentifier ?? "")".lowercased()
        func containsAny(_ words: [String]) -> Bool { words.contains { hint.contains($0) } }
        if containsAny(["youtube", "tiktok", "instagram", "whatsapp", "discord", "facebook",
                         "twitter", "threads", "telegram", "reddit", "messenger", "social"]) {
            return "Social"
        }
        if containsAny(["game", "mario", "samba", "kart", "taiko", "melon", "emu",
                         "minecraft", "ryujinx", "retro", "puzzle", "play"]) {
            return "Juegos"
        }
        if containsAny(["ibis", "pixiv", "camera", "photo", "editor", "draw", "pinterest",
                         "art", "paint", "creative", "music", "video"]) {
            return "Creatividad"
        }
        if containsAny(["notes", "office", "docs", "drive", "calendar", "notion",
                         "word", "excel", "productivity", "file", "takopi"]) {
            return "Productividad"
        }
        if containsAny(["settings", "clock", "utility", "utilities", "browser",
                         "safari", "remote", "tool", "jit", "terminal", "store"]) {
            return "Utilidades"
        }
        return "Otras apps"
    }

    private var librarySections: [LibrarySection] {
        let keys = appKeys
        let appsByKey = appMap
        let keySet = Set(keys)
        let assigned = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        let favorites = favoriteKeys.filter { keySet.contains($0) }
        var suggestions = favorites
        suggestions.append(contentsOf: keys.filter { !suggestions.contains($0) })
        let stored = recentLibraryKeys.filter { keySet.contains($0) }
        let recent = Array((stored + keys.reversed().filter { !stored.contains($0) }).prefix(8))
        var groups: [String: [String]] = [:]
        for key in keys {
            groups[libraryCategory(for: key, assigned: assigned, appsByKey: appsByKey), default: []].append(key)
        }
        let categoryNames = ["Social", "Productividad", "Utilidades", "Juegos", "Creatividad", "Otras apps"]
        let otherNames = groups.keys.filter { !categoryNames.contains($0) }.sorted()
        let categories = (categoryNames + otherNames).compactMap { name -> LibrarySection? in
            guard let items = groups[name], !items.isEmpty else { return nil }
            return LibrarySection(title: name, keys: items)
        }
        return [LibrarySection(title: "Sugerencias", keys: Array(suggestions.prefix(8))),
                LibrarySection(title: "Añadidas recientemente", keys: recent)] + categories
    }

    private var librarySearchMatches: [String] {
        let appsByKey = appMap
        // Resolve each display name once, instead of decoding preferences during sorting.
        let entries = appKeys.map { (key: $0, name: title($0, appsByKey: appsByKey)) }
        return entries.filter {
            libraryQuery.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(libraryQuery) ||
            (appsByKey[$0.key]?.bundleIdentifier.localizedCaseInsensitiveContains(libraryQuery) ?? false)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { $0.key }
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
            // Fetching the remote registry never executes code. If the network is
            // unavailable, the last verified catalog is used.
            await tweakCatalog.refreshIfNeeded()
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
                                ForEach(widgets(on: index), id: \.self) { id in
                                    Image(systemName: id == "clock" ? "clock" : id == "photo" ? "photo" : "note.text")
                                        .font(.caption).frame(maxWidth: .infinity).padding(6).liveBoardGlass(radius: 8)
                                }
                            }.padding(8)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 7) {
                            ForEach(0..<LiveBoardHomeLayout.capacity, id: \.self) { slot in
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
        guard layout.pages.indices.contains(index) else { return }
        var hidden = hiddenPageIndices
        if hidden.contains(index) {
            hidden.remove(index)
        } else {
            guard layout.pages.count - hidden.count > 1 else { return }
            hidden.insert(index)
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            persistHiddenPages(hidden)
            if page > 0, hidden.contains(page - 1) {
                page = (layout.pages.indices.first { !hidden.contains($0) } ?? 0) + 1
            }
        }
    }

    private func selectPageFromOverview(_ index: Int) {
        guard layout.pages.indices.contains(index) else { return }
        var hidden = hiddenPageIndices
        hidden.remove(index)
        persistHiddenPages(hidden)
        page = index + 1
        pageManager = false
    }

    private var pageWidgets: [Int: [String]] {
        (try? JSONDecoder().decode([Int: [String]].self, from: Data(pageWidgetsJSON.utf8))) ?? [:]
    }
    private func widgets(on index: Int) -> [String] { pageWidgets[index] ?? [] }
    private func saveWidgets(_ values: [Int: [String]]) {
        if let data = try? JSONEncoder().encode(values), let value = String(data: data, encoding: .utf8) { pageWidgetsJSON = value }
    }
    private func toggleWidget(_ id: String, on index: Int) {
        guard layout.pages.indices.contains(index) else { return }
        var values = pageWidgets
        if values[index, default: []].contains(id) { values[index]?.removeAll { $0 == id } }
        else { values[index, default: []].append(id) }
        saveWidgets(values)
    }
    @ViewBuilder private func homePage(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        if widgets(on: index).isEmpty { homeIconGrid(index, width: width, height: height) }
        else {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(widgets(on: index), id: \.self) { id in
                        ManzanaDesktopView(openSettings: { desktopSettings = true }, singleWidget: id)
                            .contextMenu {
                                Menu("Mover a página") {
                                    ForEach(Array(layout.pages.indices), id: \.self) { target in
                                        Button("Página \(target + 1)") {
                                            var values = pageWidgets
                                            values[index]?.removeAll { $0 == id }
                                            if !values[target, default: []].contains(id) { values[target, default: []].append(id) }
                                            saveWidgets(values)
                                            var hidden = hiddenPageIndices; hidden.remove(target); persistHiddenPages(hidden)
                                            page = target + 1
                                        }.disabled(target == index)
                                    }
                                }
                                Button("Quitar widget", role: .destructive) { toggleWidget(id, on: index) }
                            }
                            .padding(.horizontal, 20)
                    }
                    homeIconGrid(index, width: width, height: height).frame(height: height)
                }.padding(.top, editing ? 50 : 20)
            }
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
                            if let key {
                                homeItem(key, showLabel: !largeIcons)
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
                            acceptDrop(providers) { key in
                                withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85)) {
                                    layout.place(key, on: index, slot: slot); reconcile()
                                }
                            }
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
            } else if key == Self.sideStoreKey || key == Self.installKey || key == Self.tweakStoreKey || key == Self.appStoreKey || key == Self.modulesKey {
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
        return Button {
            guard !editing else { return }
            if isSideStore { openSideStore() }
            else if isTweakStore { tweakStorePresented = true }
            else if isAppStore { appStorePresented = true }
            else if isModules { modulesPresented = true }
            else { openInstall() }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isModules {
                        BloomBoxModulesIcon(size: size)
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
                .modifier(ManzanaIconTreatment())
                .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
                .modifier(LiveBoardEditWobble(active: editing && !reduceMotion,
                         phase: isSideStore ? 0.7 : 2.1))
                if showLabel {
                    Text(isSideStore ? "SideStore" : isTweakStore ? "Tweak Store" : isAppStore ? "App Store" : isModules ? "Módulos" : "Instalar app")
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
        }
        .accessibilityLabel(isSideStore ? "Abrir SideStore" : isTweakStore ? "Abrir Tweak Store" : isAppStore ? "Abrir App Store" : "Instalar IPA en LiveContainer")
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
                .accessibilityIdentifier("home.dock.slot.(slot)")
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
                Button { page = index } label: {
                    Circle().fill(.white.opacity(page == index ? 1 : 0.35))
                        .frame(width: 6, height: 6).frame(width: 18, height: 32)
                }
                .accessibilityLabel(index == 0 ? "Widgets" : "Página \(index)")
                .onDrop(of: [UTType.text], delegate: LiveBoardMoveDropDelegate { providers in
                    guard index > 0 else { return false }
                    return acceptDrop(providers) { key in
                        layout.place(key, on: index - 1); page = index; reconcile()
                    }
                })
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
        .frame(height: 32)
        .liveBoardGlass(radius: 16)
        .blur(radius: openFolder == nil ? 0 : 18)
        .accessibilityIdentifier("home.pages")
    }

    private func folderIcon(_ folder: LiveBoardHomeLayout.Folder, showLabel: Bool) -> some View {
        let size: CGFloat = largeIcons ? 76 : 64
        return Button {
            guard !editing else { return }
            folderPage = 0
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
                openFolder = folder.id
            }
        } label: {
            VStack(spacing: 5) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(0..<9, id: \.self) { slot in
                        Group {
                            if slot < folder.apps.count, let app = appMap[folder.apps[slot]] {
                                LiveBoardIconImage(app: app, dark: darkIcons)
                            } else { Color.clear }
                        }.aspectRatio(1, contentMode: .fit)
            .modifier(ManzanaIconTreatment()).clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(6).frame(width: size, height: size)
                .liveBoardGlass(radius: size * 0.23)
                .modifier(LiveBoardEditWobble(active: editing && !reduceMotion, phase: Double(abs(folder.id.hashValue % 31)) / 7))
                if showLabel { Text(folder.name).font(.system(size: 12)).lineLimit(1).shadow(color: .black.opacity(0.8), radius: 2, y: 1).frame(width: 80) }
            }
        }.buttonStyle(.plain)
        .contextMenu {
            Button("Edit Home Screen", systemImage: "square.grid.3x3") { enterEditMode() }
            Button("Rename", systemImage: "pencil") { renameKey = folder.id; renameValue = folder.name }
            Menu("Move to Page") {
                ForEach(layout.pages.indices, id: \.self) { index in Button("Page \(index + 1)") { layout.place(folder.id, on: index) } }
            }
            Button("Remove Folder", systemImage: "folder.badge.minus", role: .destructive) { layout.dissolveFolder(folder.id); reconcile() }
        }
        .onDrop(of: [UTType.text], delegate: LiveBoardMoveDropDelegate { providers in
            acceptDrop(providers) { key in layout.put(key, in: folder.id); reconcile() }
        })
        .accessibilityLabel("\(folder.name), folder, \(folder.apps.count) apps")
    }

    private func folderOverlay(_ folder: LiveBoardHomeLayout.Folder, width: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { openFolder = nil }
            }
            VStack(spacing: 28) {
                Button { renameKey = folder.id; renameValue = folder.name } label: { Text(folder.name).font(.system(size: 30, weight: .semibold)) }.buttonStyle(.plain)
                TabView(selection: $folderPage) {
                    ForEach(0..<max(1, (folder.apps.count + 8) / 9), id: \.self) { p in
                        VStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { row in
                                HStack(alignment: .top, spacing: 0) {
                                    ForEach(0..<3, id: \.self) { col in
                                        let index = p * 9 + row * 3 + col
                                        Group {
                                            if index < folder.apps.count { homeItem(folder.apps[index], showLabel: !largeIcons) }
                                            else { Color.clear.frame(width: 60, height: 80) }
                                        }.frame(maxWidth: .infinity).frame(height: 96, alignment: .top)
                                    }
                                }
                            }
                        }.padding(.horizontal, 12).padding(.top, 28).tag(p)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: folder.apps.count > 9 ? .always : .never))
                .frame(width: min(width - 56, 340), height: 340)
                .liveBoardGlass(radius: 38, interactive: false)
                Button("Cerrar") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { openFolder = nil }
                }.font(.subheadline).accessibilityIdentifier("home.folder.close")
            }.offset(y: -25)
        }
        .accessibilityAddTraits(.isModal)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
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
            ManzanaIconCustomization().padding(12)
                .presentationDetents([.height(420), .medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        } else { ManzanaIconCustomization().padding() }
    }
    private var customizeSheet: some View {
        NavigationView {
            Form {
                Section("Wallpaper") {
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
                Section("Iconos") { ManzanaIconCustomization() }
                Section("Appearance") {
                    Toggle("Large icons", isOn: $largeIcons)
                    Toggle("Reduce motion", isOn: $customReduceMotion)
                    Toggle("Dark app icons", isOn: $darkIcons)
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
        let previouslyHidden = hiddenPageIndices
        let movedIcons = layout.pages[index].contains { $0 != nil }
        let targetPage = min(index, layout.pages.count - 2)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            if layout.removePage(at: index) {
                saveWidgets(ManzanaPageWidgetLayout.removingPage(index, target: targetPage, from: pageWidgets))
                var shifted = Set(previouslyHidden.compactMap { value -> Int? in
                    if value == index { return nil }
                    return value > index ? value - 1 : value
                })
                if movedIcons { shifted.remove(targetPage) }
                persistHiddenPages(shifted)
                if page > index + 1 { page -= 1 }
                else if page == index + 1 { page = min(index + 1, layout.pages.count) }
                if page > 0 && shifted.contains(page - 1) {
                    page = (layout.pages.indices.first { !shifted.contains($0) } ?? 0) + 1
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
        let needsShortcuts = [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey]
            .filter { !knownKeys.contains($0) }
        // Only installed guest apps not seen before, never icons the user hid.
        let newGuestKeys = hadSavedLayout
            ? appKeys.filter { appsByKey[$0] != nil && !knownKeys.contains($0) }
            : []
        layout.reconcile(appKeys, favorites: favoriteKeys)
        for key in needsShortcuts.reversed() {
            layout.place(key, on: 0)
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
    }
    private func title(_ key: String, appsByKey: [String: LCAppModel]? = nil) -> String {
        if key == Self.sideStoreKey { return "SideStore" }
        if key == Self.installKey { return "Instalar app" }
        if key == Self.tweakStoreKey { return "Tweak Store" }
        if key == Self.appStoreKey { return "App Store" }
        if key == Self.modulesKey { return "Módulos" }
        if let folder = layout.folders.first(where: { $0.id == key }) { return folder.name }
        return (appsByKey ?? appMap)[key].map { appCustomization.name($0) } ?? "App"
    }
    private func addPage() { layout.pages.append(Array(repeating: nil, count: LiveBoardHomeLayout.capacity)); page = layout.pages.count }
    private func setCategory(_ value: String?, key: String) {
        var map = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        map[key] = value
        if let data = try? JSONEncoder().encode(map), let string = String(data: data, encoding: .utf8) { categories = string }
    }
    private func acceptDrop(_ providers: [NSItemProvider], apply: @escaping (String) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let key = value as? String else { return }
            DispatchQueue.main.async {
                guard appMap[key] != nil ||
                      key == Self.sideStoreKey || key == Self.installKey || key == Self.tweakStoreKey || key == Self.appStoreKey || key == Self.modulesKey ||
                      layout.folders.contains(where: { $0.id == key }) else { return }
                apply(key)
            }
        }
        return true
    }
}


private struct BloomBoxModulesIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.29, green: 0.48, blue: 1),
                             Color(red: 0.27, green: 0.18, blue: 0.85),
                             Color(red: 0.42, green: 0.23, blue: 0.91)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: size * 0.47, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.38), radius: size * 0.08)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 1.1)
        }
        .accessibilityLabel("Módulos de BloomBox")
    }
}

private struct BloomBoxModulesPanel: View {
    @AppStorage("BloomBoxRAMPlusExperimentalControls", store: LCUtils.appGroupUserDefault)
    private var ramExperimentalControlsEnabled = false

    enum Destination { case jit, desktop, interface, wallpaper, apps, settings, tweaks, sidestore }
    enum Module: String, CaseIterable, Identifiable {
        case ram, jit, desktop, connectivity, privacy, experimental
        var id: String { rawValue }

        var title: String {
            switch self {
            case .ram: return "RAM+"
            case .jit: return "JIT"
            case .desktop: return "Escritorio"
            case .connectivity: return "Conectividad"
            case .privacy: return "Privacidad"
            case .experimental: return "Experimental"
            }
        }
        var subtitle: String {
            switch self {
            case .ram: return "Memoria ampliada"
            case .jit: return "Setup y proveedores"
            case .desktop: return "Personalización"
            case .connectivity: return "Internet y red"
            case .privacy: return "Aislamiento y permisos"
            case .experimental: return "Funciones avanzadas"
            }
        }
        var symbol: String {
            switch self {
            case .ram: return "cpu"
            case .jit: return "bolt.fill"
            case .desktop: return "display"
            case .connectivity: return "wifi"
            case .privacy: return "shield.lefthalf.filled"
            case .experimental: return "flask.fill"
            }
        }
        var tint: Color {
            switch self {
            case .ram: return Color(red: 0.80, green: 0.48, blue: 1)
            case .jit: return Color(red: 1, green: 0.73, blue: 0.43)
            case .desktop: return Color(red: 0.31, green: 0.78, blue: 1)
            case .connectivity: return Color(red: 0.35, green: 0.92, blue: 0.68)
            case .privacy: return Color(red: 1, green: 0.48, blue: 0.75)
            case .experimental: return Color(red: 0.72, green: 0.45, blue: 1)
            }
        }
    }

    let apps: [LCAppModel]
    let onSelect: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(spacing: 16) {
                        BloomBoxModulesIcon(size: 55)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Módulos")
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                            Text("Funciones y herramientas de BloomBox")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 16)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Module.allCases) { module in
                            NavigationLink(destination: detail(for: module)) {
                                tile(module)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.modules.\(module.rawValue)")
                        }
                    }
                    Text("RAM+ comprueba el permiso de la instalación actual y te guía para completar su activación.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.66))
                        .padding(.horizontal, 4)
                }
                .padding(18)
            }
            .background(moduleBackdrop)
            .foregroundStyle(.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }.font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func tile(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: module.symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(module.tint)
                .frame(width: 49, height: 49)
                .background(module.tint.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(module.title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Text(module.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 165)
        .background(Color(red: 0.15, green: 0.16, blue: 0.23).opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(LinearGradient(colors: [module.tint.opacity(0.72), .white.opacity(0.13)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 1)
        }
    }

    @ViewBuilder private func detail(for module: Module) -> some View {
        switch module {
        case .ram:
            ramDetail
        case .jit:
            LiveBoardJITSetup(embedded: true)
        case .desktop:
            desktopDetail
        case .connectivity:
            BloomBoxConnectivityModule(apps: apps)
        case .privacy, .experimental:
            moduleDetail(module)
        }
    }

    private var moduleBackdrop: some View {
        Color(red: 0.055, green: 0.065, blue: 0.13).opacity(0.87)
            .ignoresSafeArea()
    }

    private var desktopDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Escritorio", systemImage: "display")
                    .font(.title2.bold())
                Text("Los accesos del menú Escritorio, ahora dentro de Módulos.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                Button { onSelect(.interface) } label: {
                    moduleShortcut("Interface", subtitle: "iOS Home Screen", symbol: "square.grid.3x3.fill", color: .cyan)
                }
                Button { onSelect(.wallpaper) } label: {
                    moduleShortcut("Wallpaper", subtitle: "Fotos, videos, GIF y fondo", symbol: "photo.fill", color: .pink)
                }
                Button { onSelect(.apps) } label: {
                    moduleShortcut("Apps", subtitle: "Instalar y administrar apps", symbol: "square.stack.3d.up.fill", color: .purple)
                }
            }
            .buttonStyle(.plain)
            .padding(22)
        }
        .background(moduleBackdrop)
        .foregroundStyle(.white)
        .navigationTitle("Escritorio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func moduleShortcut(_ title: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 53, height: 53)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold()).foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.18).opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(color.opacity(0.38)))
    }

    private var ramDetail: some View {
        BloomBoxRAMPlusView { onSelect(.sidestore) }
    }

    private func moduleDetail(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(module.title, systemImage: module.symbol)
                .font(.title2.bold())
                Text(detailDescription(module))
                    .font(.body)
                    .foregroundStyle(.secondary)
            Button {
                switch module {
                case .jit: onSelect(.jit)
                case .desktop: onSelect(.desktop)
                case .connectivity, .privacy: onSelect(.apps)
                case .experimental: onSelect(.settings)
                case .ram: break
                }
            } label: {
                Label(detailButton(module), systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("bloombox.modules.\(module.rawValue).open")
            if module == .experimental {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Experimentos · Funciones avanzadas", systemImage: "flask.fill")
                        .font(.headline)
                    Toggle("Habilitar botones RAM+ para pruebas", isOn: $ramExperimentalControlsEnabled)
                        .tint(Color(red: 0.72, green: 0.45, blue: 1))
                        .accessibilityIdentifier("bloombox.experiments.ramControls.toggle")
                    Text("Permite volver a abrir los controles de reinstalación cuando RAM+ ya está activa. No desactiva RAM+, no solicita permisos a Apple ni reinstala nada al encender el interruptor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if ramExperimentalControlsEnabled {
                        Text("La reinstalación real podría perder RAM+ si la nueva firma no conserva el permiso. Comprueba tu firma antes de instalar.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        NavigationLink {
                            BloomBoxRAMPlusView { onSelect(.sidestore) }
                        } label: {
                            Label("Abrir controles de RAM+", systemImage: "cpu")
                        }
                        .accessibilityIdentifier("bloombox.experiments.ramControls.open")
                    }
                }
                Button("Abrir Tweak Store") { onSelect(.tweaks) }
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(moduleBackdrop)
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailDescription(_ module: Module) -> String {
        switch module {
        case .jit: return "Accede a los proveedores JIT y a su configuración existente."
        case .desktop: return "Abre los controles de escritorio: apariencia, widgets, páginas y personalización."
        case .connectivity: return "El acceso a internet se configura por aplicación desde su administración. No se cambia la conectividad de todo el iPhone."
        case .privacy: return "Revisa las opciones de aislamiento disponibles en cada aplicación instalada. Estas funciones no modifican permisos de iOS."
        case .experimental: return "Consulta las herramientas y opciones avanzadas que ya están disponibles en BloomBox."
        case .ram: return ""
        }
    }

    private func detailButton(_ module: Module) -> String {
        switch module {
        case .jit: return "Configurar JIT"
        case .desktop: return "Abrir controles del escritorio"
        case .connectivity, .privacy: return "Administrar aplicaciones"
        case .experimental: return "Abrir ajustes avanzados"
        case .ram: return ""
        }
    }
}


private struct BloomBoxModulesSheetBackground: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}

/// Uses the same app property as the established per-app Internet switch.
/// Turning Internet on means networkBlocked=false; turning it off means true.
private struct BloomBoxConnectivityModule: View {
    let apps: [LCAppModel]
    @State private var search = ""
    @State private var notice: String?
    @State private var changedCount = 0

    private var availableApps: [LCAppModel] {
        var seen = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            seen.insert(liveBoardAppKey(app)).inserted
        }.sorted {
            $0.appInfo.displayName().localizedCaseInsensitiveCompare($1.appInfo.displayName()) == .orderedAscending
        }
    }

    private var filteredApps: [LCAppModel] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableApps }
        return availableApps.filter {
            $0.appInfo.displayName().localizedCaseInsensitiveContains(query) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "wifi").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Internet por aplicación").font(.title3.bold())
                        Text("Encendido: tiene Internet · Apagado: bloqueado")
                            .font(.footnote).foregroundStyle(.white.opacity(0.7))
                    }
                }
                TextField("Buscar app", text: $search)
                    .padding(12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("bloombox.modules.connectivity.search")

                if let notice {
                    Label(notice, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.footnote)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if availableApps.isEmpty {
                    Label("No hay aplicaciones invitadas instaladas.", systemImage: "square.stack")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(14)
                } else if filteredApps.isEmpty {
                    Text("No se encontraron aplicaciones.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    ForEach(filteredApps, id: \.self) { app in
                        BloomBoxConnectivityRow(app: app) { allowed in
                            changedCount += 1
                            notice = allowed
                                ? "«\(app.appInfo.displayName())» volverá a tener Internet después de reiniciar BloomBox."
                                : "«\(app.appInfo.displayName())» tendrá Internet bloqueado después de reiniciar BloomBox."
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }

                if changedCount > 0 {
                    Label("Hay cambios pendientes de aplicar: cierra BloomBox desde el selector de apps y vuelve a abrirlo.", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                Text("Este ajuste se aplica a las apps invitadas dentro de BloomBox, no a todo iOS. El filtro es experimental y algunas conexiones, incluidas las de iCloud, pueden continuar. Los cambios requieren cerrar y volver a abrir BloomBox.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .padding(20)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).opacity(0.87).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Conectividad")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BloomBoxConnectivityRow: View {
    @ObservedObject var app: LCAppModel
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            LiveBoardIconImage(app: app, dark: false)
                .frame(width: 47, height: 47)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.appInfo.displayName())
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if app.isAppRunning {
                    Text("Cierra la app para cambiar el acceso")
                        .font(.caption2).foregroundStyle(.orange)
                } else if app.isSigningInProgress {
                    Text("Firma en curso")
                        .font(.caption2).foregroundStyle(.orange)
                } else {
                    Label(app.uiNetworkBlocked ? "Internet bloqueado" : "Internet permitido",
                          systemImage: app.uiNetworkBlocked ? "wifi.slash" : "wifi")
                        .font(.caption2)
                        .foregroundStyle(app.uiNetworkBlocked ? Color.orange : Color.green)
                }
            }
            Spacer(minLength: 4)
            Toggle("Internet de \(app.appInfo.displayName())", isOn: Binding(
                get: { !app.uiNetworkBlocked },
                set: { allowed in
                    guard !app.isAppRunning && !app.isSigningInProgress else { return }
                    app.uiNetworkBlocked = !allowed
                    onChange(allowed)
                }
            ))
            .labelsHidden()
            .tint(.green)
            .disabled(app.isAppRunning || app.isSigningInProgress)
            .accessibilityIdentifier("bloombox.modules.connectivity.\(liveBoardAppKey(app))")
        }
        .padding(13)
        .background(Color(white: 0.18).opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(app.uiNetworkBlocked ? Color.orange.opacity(0.35) : Color.white.opacity(0.12)))
    }
}

private struct LiveBoardHomeIcon: View {
    @ObservedObject var app: LCAppModel
    let title: String
    let size: CGFloat
    let showLabel: Bool
    let dark: Bool
    let editing: Bool
    let reduceMotion: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                LiveBoardIconImage(app: app, dark: dark)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
                    .overlay { if app.isSigningInProgress { ProgressView(value: app.signProgress).padding(8).background(.ultraThinMaterial) } }
                    .modifier(LiveBoardEditWobble(active: editing && !reduceMotion, phase: Double(abs(title.hashValue % 31)) / 7))
                if showLabel {
                    Text(title).font(.system(size: 12, weight: .regular)).lineLimit(1)
                        .foregroundColor(.white).shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1).frame(width: 82)
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(LiveBoardHomePressStyle(reduceMotion: reduceMotion))
        .disabled(!editing && app.isSigningInProgress)
        .accessibilityLabel(title)
        .accessibilityHint(editing ? "Drag to rearrange" : "Launch app. Touch and hold for more actions.")

    }
}
private struct LiveBoardEditWobble: ViewModifier {
    let active: Bool
    var phase: Double = 0
    var speed: Double = 22
    var amplitude: Double = 1.5
    @ViewBuilder func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { time in
                content.rotationEffect(.degrees(sin(time.date.timeIntervalSinceReferenceDate * speed + phase) * amplitude))
            }
        } else {
            content.rotationEffect(.zero).transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
    }
}
private struct LiveBoardHomePressStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
struct LiveBoardIconImage: View {
    @AppStorage("ManzanaIconStyle", store: LCUtils.appGroupUserDefault) private var iconStyle = "default"
    @ObservedObject var app: LCAppModel
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    let dark: Bool
    var body: some View {
        Group {
            if let image = LiveBoardIconStore.image(app, dark: dark || iconStyle == "dark") { Image(uiImage: image).resizable().scaledToFill() }
            else {
                ZStack { Color(white: 0.2); Image(systemName: "app.dashed").resizable().scaledToFit().padding(14).foregroundColor(.white.opacity(0.6)) }
            }
        }.aspectRatio(1, contentMode: .fit)
            .modifier(ManzanaIconTreatment())
            .overlay(alignment: .bottomTrailing) {
                if app.uiNetworkBlocked {
                    GeometryReader { geometry in
                        let diameter = min(23, max(12, geometry.size.width * 0.30))
                        if geometry.size.width >= 32 {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: diameter * 0.56, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: diameter, height: diameter)
                                .background(Color.black.opacity(0.88), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.88), lineWidth: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .padding(2)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }
}

/// Original procedural wallpaper; user photos are rendered separately, without app-bundle changes.
private struct LiveBoardRibbonWallpaper: View {
    let blue: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                Ellipse().fill(RadialGradient(colors: [accent.opacity(0.45), accent.opacity(0.08), .black], center: .center, startRadius: 0, endRadius: geometry.size.height * 0.48))
                    .frame(width: geometry.size.width * 1.5, height: geometry.size.height * 0.9).rotationEffect(.degrees(-20)).offset(x: -40, y: -70)
                ForEach(0..<3) { index in
                    Ellipse().stroke(LinearGradient(colors: [.black, accent.opacity(0.6), .black, accent.opacity(0.9), .black], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3 + CGFloat(index) * 1.5)
                        .background(Ellipse().fill(LinearGradient(colors: [.black.opacity(0.9), accent.opacity(0.22), .black], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: geometry.size.width * (0.7 + Double(index) * 0.13), height: geometry.size.height * (0.65 - Double(index) * 0.1))
                        .rotationEffect(.degrees(Double(index) * 38 - 34)).offset(x: CGFloat(index - 1) * 32, y: CGFloat(index - 1) * 35)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
    private var accent: Color { blue ? Color(red: 0.04, green: 0.25, blue: 0.85) : Color(red: 0.7, green: 0.035, blue: 0.01) }
}

struct LiveBoardWallpaperPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (UIImage?) -> Void
        init(_ completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { completion(nil); return }
            item.loadObject(ofClass: UIImage.self) { image, _ in DispatchQueue.main.async { self.completion(image as? UIImage) } }
        }
    }
}

private struct LiveBoardGlassSurface: ViewModifier {
    let radius: CGFloat
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content.background(Color(white: 0.16), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.clear.interactive(interactive), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.04), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6))
        }
    }
}
extension View {
    func liveBoardGlass(radius: CGFloat, interactive: Bool = true) -> some View {
        modifier(LiveBoardGlassSurface(radius: radius, interactive: interactive))
    }
}

/// Explicit move proposal prevents iOS from advertising a green copy (+) badge
/// while rearranging an icon over Home, Dock, page controls or folders.
private struct LiveBoardMoveDropDelegate: DropDelegate {
    let accept: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    func performDrop(info: DropInfo) -> Bool {
        accept(info.itemProviders(for: [UTType.text.identifier]))
    }
}



 // MARK: - BloomBox remote Tweak Store / compatibility catalog
 // App binaries are NOT part of this catalog. No commands or scripts are
 // evaluated from JSON; installing native code always needs user confirmation.

private struct BloomBoxTweakTarget: Codable {
    let bundleID: String
    let minVersion: String?
    let maxVersion: String?
}

private struct BloomBoxTweakEntry: Codable, Identifiable {
    let id: String
    let name: String
    let version: String
    let developer: String?
    // Optional original author repository or official website; display only.
    // Never use this URL as a tweak download source.
    let officialSourceURL: String?
    let description: String?
    let priority: String?
    let alertLevel: Int?
    let alertTitle: String?
    let alertMessage: String?
    let bundleID: String?
    let supportedApps: [BloomBoxTweakTarget]?
    let minAppVersion: String?
    let maxAppVersion: String?
    let fileName: String?
    let fileType: String?
    // Optional direct URL of the target app's *official* App Store artwork.
    // The iTunes lookup API is used when appIconURL is absent.
    let appIconURL: String?
    let appStoreID: Int?
    // A listing may be visible for discovery even if its format or target is
    // not currently supported by the automatic BloomBox installer.
    let listingOnly: Bool?
    let useAtOwnRisk: Bool?
    let targetAppName: String?
    let notes: String?
    let downloadURL: String
    let sha256: String

    var officialProjectURL: URL? {
        guard let officialSourceURL, officialSourceURL.count <= 2048,
              let link = URL(string: officialSourceURL),
              link.scheme == "https", link.host != nil,
              link.user == nil, link.password == nil else { return nil }
        return link
    }

    var projectLinkLabel: String {
        guard let url = officialProjectURL else { return "Sitio del autor" }
        return url.host?.lowercased() == "github.com"
            ? "Ver repositorio" : "Sitio oficial"
    }

    var creditedAuthor: String {
        guard let developer, !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Autor no especificado"
        }
        return developer
    }

    var officialIconURL: URL? {
        guard let appIconURL, let url = URL(string: appIconURL),
              BloomBoxAppStoreArtwork.isTrustedArtwork(url) else { return nil }
        return url
    }

    var targetBundleID: String? {
        supportedApps?.first?.bundleID ?? bundleID
    }

    var assetName: String {
        fileName ?? URL(string: downloadURL)?.lastPathComponent ?? ""
    }

    var isInstallable: Bool {
        listingOnly != true && isValid
    }

    var isValid: Bool {
        // Listings with no compatible on-device installer remain discoverable,
        // but their assets cannot be automatically downloaded or injected.
        guard !id.isEmpty, id.count <= 90, !name.isEmpty, name.count <= 120,
              (0...3).contains(alertLevel ?? 0) else { return false }
        if listingOnly == true {
            return officialProjectURL != nil && !creditedAuthor.isEmpty
        }
        guard !id.isEmpty, id.count <= 90, !name.isEmpty, name.count <= 120,
              !version.isEmpty, version.count <= 60,
              sha256.count == 64,
              sha256.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }),
              (0...3).contains(alertLevel ?? 0),
              fileType == nil || fileType == "dylib",
              let url = URL(string: downloadURL), url.scheme == "https",
              url.host?.lowercased() == "github.com",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              assetName.count < 90, assetName.hasSuffix(".dylib"),
              assetName != ".", assetName != "..",
              assetName.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-").contains($0)
              })
        else { return false }
        let sections = url.path.split(separator: "/").map(String.init)
        return sections.count == 6 && sections[2] == "releases" &&
               sections[3] == "download" && sections[5] == assetName &&
               !(supportedApps ?? []).isEmpty || (
                  sections.count == 6 && sections[2] == "releases" &&
                  sections[3] == "download" && sections[5] == assetName &&
                  bundleID != nil
               )
    }

    func applies(to app: LCAppModel) -> Bool {
        guard !(app.appInfo is BuiltInSideStoreAppInfo) else { return false }
        let identifiers = [
            app.bundleIdentifier,
            app.appInfo.relativeBundlePath ?? "",
            app.appInfo.bundlePath().map { URL(fileURLWithPath: $0).lastPathComponent } ?? "",
            app.appInfo.info()["LCOrignalBundleIdentifier"] as? String ?? ""
        ]
        let targets = supportedApps?.isEmpty == false
            ? supportedApps! : (bundleID.map { [BloomBoxTweakTarget(bundleID: $0,
                                         minVersion: minAppVersion, maxVersion: maxAppVersion)] } ?? [])
        return targets.contains { target in
            guard identifiers.contains(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(target.bundleID) == .orderedSame
            }) else { return false }
            let version = app.version
            if let lower = target.minVersion, version.compare(lower, options: .numeric) == .orderedAscending { return false }
            if let upper = target.maxVersion, version.compare(upper, options: .numeric) == .orderedDescending { return false }
            return true
        }
    }

    func installedFile(for app: LCAppModel) -> URL? {
        guard let folder = app.uiTweakFolder, !folder.isEmpty,
              !folder.contains("/"), folder != ".", folder != ".." else { return nil }
        let root = app.uiIsShared ? LCPath.lcGroupTweakPath : LCPath.tweakPath
        return root.appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(assetName)
    }

    func isInstalled(for app: LCAppModel) -> Bool {
        installedFile(for: app).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    func isActive(for app: LCAppModel) -> Bool {
        isInstalled(for: app) && !app.uiDontInjectTweakLoader && !app.uiDontLoadTweakLoader
    }
}

private struct BloomBoxTweakIndex: Codable {
    let schemaVersion: Int
    let tweakEntries: [BloomBoxTweakEntry]
}

private final class BloomBoxTweakCatalog: ObservableObject {
    static let shared = BloomBoxTweakCatalog()
    @Published private(set) var entries: [BloomBoxTweakEntry] = []
    @Published private(set) var lastError: String?
    @Published private(set) var refreshing = false
    @Published private(set) var lastSuccessfulSync: Date?
    private var refreshedAt: Date?
    private static let lastSyncKey = "BloomBoxTweakCatalogLastSuccessfulSync-v2"
    private static let cacheKey = "BloomBoxTweakCatalogVerifiedCache-v2"
    private static let catalogURL = URL(string:
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/tweaks-v2.json")!

    private init() {
        lastSuccessfulSync = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let parsed = try? JSONDecoder().decode(BloomBoxTweakIndex.self, from: data),
           parsed.schemaVersion == 2 {
            entries = parsed.tweakEntries.filter(\.isValid)
        }
    }

    @MainActor
    func refreshIfNeeded(force: Bool = false) async {
        if refreshing { return }
        if !force, let last = refreshedAt, Date().timeIntervalSince(last) < 90 { return }
        refreshing = true
        defer { refreshing = false }
        do {
            // URLSession's conditional-cache policy can serve a stale catalog
            // even after the JSON was removed from GitHub. A distinct query
            // string also bypasses stale raw.githubusercontent.com CDN entries.
            var urlParts = URLComponents(url: Self.catalogURL, resolvingAgainstBaseURL: false)!
            urlParts.queryItems = [URLQueryItem(
                name: "refresh",
                value: String(Int64(Date().timeIntervalSince1970 * 1000))
            )]
            var request = URLRequest(url: urlParts.url ?? Self.catalogURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  data.count < 256_000 else {
                throw "No se pudo descargar el catálogo remoto de tweaks."
            }
            let index = try JSONDecoder().decode(BloomBoxTweakIndex.self, from: data)
            guard index.schemaVersion == 2,
                  index.tweakEntries.count <= 150,
                  index.tweakEntries.allSatisfy(\.isValid) else {
                throw "El catálogo remoto contiene entradas incompatibles."
            }
            entries = index.tweakEntries
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
            refreshedAt = Date()
            lastSuccessfulSync = refreshedAt
            UserDefaults.standard.set(lastSuccessfulSync, forKey: Self.lastSyncKey)
            lastError = nil
        } catch {
            // Keep the previously verified catalog for offline launches.
            refreshedAt = Date()
            lastError = error.localizedDescription
        }
    }

    func criticalMissing(for app: LCAppModel) -> BloomBoxTweakEntry? {
        entries.first { ($0.alertLevel ?? 0) == 3 &&
            $0.applies(to: app) && !$0.isActive(for: app) }
    }
}


// Apple's public Search API exposes artworkUrl512 for App Store apps.
// Cache by Apple ID or bundle ID, not a device's data-container UUID.
private actor BloomBoxAppStoreArtwork {
    static let shared = BloomBoxAppStoreArtwork()
    private var resolved: [String: URL] = [:]
    private var unavailable = Set<String>()

    static func isTrustedArtwork(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased() else { return false }
        return host == "mzstatic.com" || host.hasSuffix(".mzstatic.com")
    }

    private struct Lookup: Decodable {
        let results: [Result]
    }

    private struct Result: Decodable {
        let bundleId: String?
        let artworkUrl512: String?
        let artworkUrl100: String?
    }

    func iconURL(appStoreID: Int?, bundleID: String?) async -> URL? {
        let id = appStoreID ?? 0
        guard id > 0 || bundleID != nil else { return nil }
        let key = id > 0 ? "id:\(id)" : "bundle:\(bundleID ?? "")"
        if let url = resolved[key] { return url }
        if unavailable.contains(key) { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        var queries = [URLQueryItem(name: "country", value: "us")]
        if id > 0 {
            queries.append(URLQueryItem(name: "id", value: String(id)))
        } else if let bundleID, bundleID.count < 160 {
            queries.append(URLQueryItem(name: "bundleId", value: bundleID))
        } else {
            return nil
        }
        components.queryItems = queries
        guard let url = components.url else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode), data.count < 100_000 else {
                return nil
            }
            let responseData = try JSONDecoder().decode(Lookup.self, from: data)
            if let app = responseData.results.first,
               let str = app.artworkUrl512 ?? app.artworkUrl100,
               let artwork = URL(string: str),
               Self.isTrustedArtwork(artwork) {
                resolved[key] = artwork
                return artwork
            }
            unavailable.insert(key)
        } catch {
            // On offline requests, the installed-app icon remains visible.
        }
        return nil
    }
}

private struct BloomBoxTweakTargetIcon: View {
    let app: LCAppModel?
    let entry: BloomBoxTweakEntry
    @State private var fetchedArtwork: URL?

    var body: some View {
        Group {
            if let remote = entry.officialIconURL ?? fetchedArtwork {
                AsyncImage(url: remote) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        localIcon
                    @unknown default:
                        localIcon
                    }
                }
            } else {
                localIcon
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Icono de \(app?.displayName ?? entry.targetAppName ?? "aplicación")")
        .task(id: entry.id) {
            if entry.officialIconURL == nil {
                fetchedArtwork = await BloomBoxAppStoreArtwork.shared.iconURL(
                    appStoreID: entry.appStoreID,
                    bundleID: entry.targetBundleID
                )
            }
        }
    }

    @ViewBuilder private var localIcon: some View {
        if let app {
            LiveBoardIconImage(app: app, dark: false)
        } else {
            ZStack {
                Color(red: 0.31, green: 0.25, blue: 0.47)
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct BloomBoxTweakMatch: Identifiable {
    let app: LCAppModel
    let entry: BloomBoxTweakEntry
    var id: String {
        "\(entry.id)|\(app.appInfo.relativeBundlePath ?? app.bundleIdentifier)|\(app.uiIsShared)"
    }
}

private struct BloomBoxTweakStore: View {
    let apps: [LCAppModel]
    let focusedApp: LCAppModel?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var catalog = BloomBoxTweakCatalog.shared
    @State private var installingID: String?
    @State private var notice: String?
    @State private var errorText: String?
    @State private var importMatch: BloomBoxTweakMatch?
    @State private var selectedLocalFile = false
    @State private var selectedSection = 0
    @State private var pendingRiskMatch: BloomBoxTweakMatch?
    @State private var confirmRiskInstallation = false

    private var installedApps: [LCAppModel] {
        let provided = apps + sharedModel.apps
        let all = sharedModel.isHiddenAppUnlocked ? provided + sharedModel.hiddenApps : provided
        var found = Set<ObjectIdentifier>()
        return all.filter { found.insert(ObjectIdentifier($0)).inserted }
    }
    private var matches: [BloomBoxTweakMatch] {
        var result: [BloomBoxTweakMatch] = []
        let targets = focusedApp.map { [$0] } ?? installedApps
        for entry in catalog.entries {
            for app in targets where entry.applies(to: app) {
                result.append(BloomBoxTweakMatch(app: app, entry: entry))
            }
        }
        return result.sorted { ($0.entry.alertLevel ?? 0) > ($1.entry.alertLevel ?? 0) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 65, height: 65)
                            .background(Color(red: 0.48, green: 0.32, blue: 0.76),
                                        in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BloomBox Tweaks").font(.title2.bold())
                            Text("Catálogo comunitario remoto")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Label("\(catalog.entries.count) tweaks en catálogo", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Actualizar") { Task { await catalog.refreshIfNeeded(force: true) } }
                            .disabled(catalog.refreshing || installingID != nil)
                    }
                    if catalog.refreshing {
                        ProgressView("Sincronizando catálogo...")
                    } else if let lastSuccess = catalog.lastSuccessfulSync {
                        Label("Catálogo sincronizado: \(lastSuccess.formatted(date: .abbreviated, time: .shortened))",
                              systemImage: "checkmark.arrow.trianglehead.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if !catalog.entries.isEmpty {
                        Label("Datos locales: pendientes de verificación en línea",
                              systemImage: "externaldrive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let lastError = catalog.lastError {
                        Text("Sin conexión o catálogo no disponible. Se conserva la última lista válida. \(lastError)")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let notice {
                        Label(notice, systemImage: "checkmark.circle.fill")
                            .font(.footnote).foregroundStyle(.green)
                    }
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    Picker("Tienda", selection: $selectedSection) {
                        Text("Mis apps").tag(0)
                        Text("Explorar").tag(1)
                    }
                    .pickerStyle(.segmented)
                    if selectedSection == 0 {
                        if matches.isEmpty && !catalog.refreshing {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sin correcciones compatibles").font(.headline)
                                Text("Explora todos los tweaks aunque todavía no tengas instaladas sus apps.")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Button("Ir a Explorar") { selectedSection = 1 }
                                    .buttonStyle(.bordered)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        }
                        ForEach(matches) { match in
                            installedTweakCard(match)
                        }
                    } else {
                        Text("Todos los tweaks · incluidos los de apps no instaladas")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(catalog.entries) { entry in
                            if let match = matches.first(where: { $0.entry.id == entry.id }) {
                                installedTweakCard(match)
                            } else {
                                availableTweakCard(entry)
                            }
                        }
                    }
                    Text("Los tweaks son código nativo: solo instala correcciones de autores confiables. La tienda no realiza instalaciones silenciosas ni distribuye juegos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Tweak Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .task { await catalog.refreshIfNeeded() }
            .confirmationDialog("Tweak no verificado en BloomBox",
                                isPresented: $confirmRiskInstallation,
                                titleVisibility: .visible) {
                Button("Instalar bajo mi responsabilidad", role: .destructive) {
                    if let match = pendingRiskMatch {
                        Task { await install(match: match, localData: nil) }
                    }
                    pendingRiskMatch = nil
                }
                Button("Cancelar", role: .cancel) { pendingRiskMatch = nil }
            } message: {
                Text("Este tweak es de terceros y no ha sido probado en BloomBox. Puede cerrar la app, afectar sus datos o requerir funciones no disponibles. Haz un respaldo antes de continuar.")
            }
            .fileImporter(isPresented: $selectedLocalFile, allowedContentTypes: [.data, .item]) { result in
                guard let match = importMatch else { return }
                do {
                    let fileURL = try result.get()
                    Task { await importVerified(fileURL, match: match) }
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func installedTweakCard(_ match: BloomBoxTweakMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 13) {
                                BloomBoxTweakTargetIcon(app: match.app, entry: match.entry)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(match.entry.name).font(.headline)
                                    Text("Para: \(match.app.displayName)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                if (match.entry.alertLevel ?? 0) == 3 {
                                    Text("NIVEL 3")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(.orange.opacity(0.22), in: Capsule())
                                } else if let level = match.entry.alertLevel, level > 0 {
                                    Text("NIVEL \(level)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(.secondary.opacity(0.12), in: Capsule())
                                }
                            }
                            Text(match.entry.description ?? "Corrección de compatibilidad")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if match.entry.useAtOwnRisk == true {
                                Label("Uso bajo tu propio riesgo · No verificado en BloomBox",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                            if let notes = match.entry.notes {
                                Text(notes).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(match.app.displayName) · \(match.app.uiIsShared ? "Compartida" : "Privada")")
                                .font(.footnote.bold())
                            Text("Bundle: \(match.app.bundleIdentifier) · Carpeta: \(match.app.appInfo.relativeBundlePath ?? "?")")
                                .font(.caption2).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Text("Versión \(match.entry.version)")
                                .font(.caption2).foregroundStyle(.secondary)
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Desarrollado por")
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Text(match.entry.creditedAuthor)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                Spacer(minLength: 0)
                            }
                            if let originalURL = match.entry.officialProjectURL {
                                Link(destination: originalURL) {
                                    Label(match.entry.projectLinkLabel, systemImage: "arrow.up.right.square")
                                        .font(.footnote.weight(.medium))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(Color.accentColor.opacity(0.09),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityHint("Abrir sitio del autor en el navegador")
                            }
                            if match.entry.listingOnly == true {
                                Label("Solo consulta · Instalación automática aún no compatible",
                                      systemImage: "info.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if match.entry.isActive(for: match.app) {
                                Label("Instalado y habilitado", systemImage: "checkmark.shield.fill")
                                    .font(.footnote).foregroundStyle(.green)
                            } else if match.entry.isInstalled(for: match.app) {
                                Label("Instalado; cargador de tweaks desactivado", systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(.orange)
                                Button("Activar para esta app") {
                                    match.app.uiDontInjectTweakLoader = false
                                    match.app.uiDontLoadTweakLoader = false
                                    notice = "Cargador habilitado. Reinicia \(match.app.displayName)."
                                }.buttonStyle(.borderedProminent)
                            } else {
                                Button {
                                    if match.entry.useAtOwnRisk == true {
                                        pendingRiskMatch = match
                                        confirmRiskInstallation = true
                                    } else {
                                        Task { await install(match: match, localData: nil) }
                                    }
                                } label: {
                                    Label(installingID == match.id ? "Instalando…" : "Instalar \(match.entry.name)",
                                          systemImage: "arrow.down.to.line")
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(.borderedProminent)
                                    .disabled(installingID != nil || !match.entry.isInstallable)
                                Button {
                                    importMatch = match
                                    selectedLocalFile = true
                                } label: {
                                    Label("Importar .dylib verificado", systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                .disabled(installingID != nil)
                            }
        }
        .padding(17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private func availableTweakCard(_ entry: BloomBoxTweakEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BloomBoxTweakTargetIcon(app: nil, entry: entry)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(.headline)
                    Text("Para: \(entry.targetAppName ?? entry.targetBundleID ?? "Varios juegos y apps")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(entry.description ?? "Tweak disponible en GitHub")
                .font(.subheadline).foregroundStyle(.secondary)
            if entry.useAtOwnRisk == true {
                Label("Uso bajo tu propio riesgo · No verificado en BloomBox",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
            if entry.listingOnly == true {
                Label("Solo consulta · Instalación automática aún no compatible",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("App compatible no instalada o versión no reconocida",
                      systemImage: "square.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = entry.notes {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
            Text("Versión \(entry.version) · Autor: \(entry.creditedAuthor)")
                .font(.caption).foregroundStyle(.secondary)
            if let original = entry.officialProjectURL {
                Link(destination: original) {
                    Label(entry.projectLinkLabel, systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    @MainActor
    private func importVerified(_ url: URL, match: BloomBoxTweakMatch) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard url.lastPathComponent == match.entry.assetName else {
                throw "Selecciona el archivo original \(match.entry.assetName)."
            }
            let data = try Data(contentsOf: url)
            await install(match: match, localData: data)
        } catch { errorText = error.localizedDescription }
    }

    @MainActor
    private func install(match: BloomBoxTweakMatch, localData: Data?) async {
        guard installingID == nil else { return }
        installingID = match.id
        notice = nil
        errorText = nil
        defer { installingID = nil }
        do {
            let app = match.app, entry = match.entry
            guard entry.isInstallable, entry.applies(to: app), !app.isAppRunning else {
                throw "La app no coincide con el tweak o está en ejecución."
            }
            let data: Data
            if let localData {
                data = localData
            } else {
                guard let source = URL(string: entry.downloadURL) else { throw "URL inválida" }
                var request = URLRequest(url: source)
                request.timeoutInterval = 35
                let (download, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode) else {
                    throw "La descarga no se completó."
                }
                data = download
            }
            guard (8_192...10_000_000).contains(data.count),
                  Array(data.prefix(8)) == [0xcf, 0xfa, 0xed, 0xfe, 0x0c, 0, 0, 0x01] else {
                throw "El archivo no es una biblioteca ARM64 válida."
            }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == entry.sha256 else {
                throw "SHA-256 no coincide con la versión aprobada en el catálogo."
            }
            let previousFolder = app.uiTweakFolder
            let folderName = previousFolder ?? ("BloomBoxTweak-" + UUID().uuidString.prefix(12))
            guard !folderName.contains("/"), folderName != ".", folderName != ".." else {
                throw "La carpeta de tweaks tiene una ruta inválida."
            }
            let root = app.uiIsShared ? LCPath.lcGroupTweakPath : LCPath.tweakPath
            let folder = root.appendingPathComponent(folderName, isDirectory: true)
            let dest = folder.appendingPathComponent(entry.assetName)
            let backup = folder.appendingPathComponent(entry.assetName + ".bloombox-backup")
            let fm = FileManager.default
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let hadPrevious = fm.fileExists(atPath: dest.path)
            if hadPrevious {
                if fm.fileExists(atPath: backup.path) {
                    throw "Existe un respaldo pendiente de una instalación anterior."
                }
                try fm.moveItem(at: dest, to: backup)
            }
            do {
                try data.write(to: dest, options: .atomic)
                LCParseMachO((dest.path as NSString).utf8String, false) { path, header, _, _ in
                    LCPatchAddRPath(path, header)
                }
                try await LCUtils.signTweaks(tweakFolderUrl: folder, force: true) { _ in }
                app.uiTweakFolder = folderName
                app.uiDontInjectTweakLoader = false
                app.uiDontLoadTweakLoader = false
                if !app.uiIsShared && !sharedModel.tweakFolderNames.contains(folderName) {
                    sharedModel.tweakFolderNames.append(folderName)
                }
                if hadPrevious { try? fm.removeItem(at: backup) }
                notice = "\(entry.name) v\(entry.version) instalado para \(app.displayName). Reinicia la app."
            } catch {
                try? fm.removeItem(at: dest)
                if hadPrevious { try? fm.moveItem(at: backup, to: dest) }
                throw error
            }
        } catch { errorText = error.localizedDescription }
    }
}


// MARK: - BloomBox App Store: remote, author-attributed guest IPA discovery
// This is a launcher catalogue, not the official Apple App Store.
// Only explicitly reviewed upstream release URLs with a published SHA-256
// enter the existing installation flow; other items remain external listings.

private struct BloomBoxAppCatalogResponse: Decodable {
    let schemaVersion: Int
    let apps: [BloomBoxAppListing]
}

private struct BloomBoxAppListing: Decodable, Identifiable {
    struct JITInfo: Decodable {
        let externalHelper: String?
        let scriptStatus: String?
        let bloomboxTested: Bool?
    }

    let id: String
    let name: String
    let creator: String
    let category: String
    let description: String
    let officialWebsite: String
    let officialReleases: String
    let currentOfficialRelease: String?
    let directDownloadURL: String?
    let fileName: String?
    let sha256: String?
    let installMode: String?
    let buildTool: String?
    let sourceVerified: Bool?
    let featured: Bool?
    let useAtOwnRisk: Bool?
    let notes: String?
    let warnings: [String]?
    let jit: JITInfo?
    let bundleID: String?
    let appStoreID: Int?
    let appIconURL: String?
    let aliases: [String]?

    private static func safeWebsite(_ value: String) -> URL? {
        guard value.count <= 2048, let url = URL(string: value),
              url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    var officialURL: URL? { Self.safeWebsite(officialWebsite) }
    var releasesURL: URL? { Self.safeWebsite(officialReleases) }
    var buildToolURL: URL? {
        guard let buildTool else { return nil }
        return Self.safeWebsite(buildTool)
    }

    var isValid: Bool {
        !id.isEmpty && id.count < 100 &&
        !name.isEmpty && name.count < 140 &&
        !creator.isEmpty && creator.count < 150 &&
        officialURL != nil && releasesURL != nil
    }

    var verifiedGuestIPA: URL? {
        guard installMode == "guest", sourceVerified == true,
              let directDownloadURL, let fileName,
              fileName.hasSuffix(".ipa"), !fileName.contains("/"),
              let sha256, sha256.count == 64,
              sha256.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "0123456789abcdef").contains($0)
              }),
              let url = Self.safeWebsite(directDownloadURL),
              url.host?.lowercased() == "github.com",
              url.query == nil, url.fragment == nil else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 6, parts[2] == "releases",
              parts[3] == "download", parts[5] == fileName else { return nil }
        return url
    }

    var shouldWarn: Bool { useAtOwnRisk != false }
    var requiresJIT: Bool { jit?.externalHelper != nil }
    var categoryTitle: String {
        switch category {
        case "emulation": return "Emuladores"
        case "ports": return "Ports de juegos"
        case "tools": return "Herramientas"
        case "utilities": return "Utilidades"
        default: return "Aplicaciones"
        }
    }
}

private final class BloomBoxAppCatalog: ObservableObject {
    static let shared = BloomBoxAppCatalog()
    @Published private(set) var listings: [BloomBoxAppListing] = []
    @Published private(set) var refreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?
    private var refreshedAt: Date?
    private static let cacheKey = "BloomBoxAppStoreCatalogueVerified-v1"
    private static let syncKey = "BloomBoxAppStoreCatalogueLastSync-v1"
    private static let source = URL(string:
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/store-catalog/catalog/apps.json")!
    private static let githubContents = URL(string:
        "https://api.github.com/repos/adri23rep-stack/BloomBox/contents/catalog/apps.json?ref=store-catalog")!

    private struct GitHubFile: Decodable {
        let content: String
        let encoding: String
    }

    /// Prefer GitHub's branch-aware Contents API; raw.githubusercontent.com is
    /// an independent fallback for rate limits or temporary API outages.
    private static func fetchCatalogue(at source: URL, githubAPI: Bool) async throws -> Data {
        var components = URLComponents(url: source, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(
            name: "_refresh", value: String(Int64(Date().timeIntervalSince1970 * 1000))
        ))
        components.queryItems = queryItems

        var request = URLRequest(url: components.url ?? source)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("BloomBox/1.2 (App Store catalogue)", forHTTPHeaderField: "User-Agent")
        if githubAPI {
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        }
        request.timeoutInterval = 15

        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty, data.count < 700_000 else {
            throw "No se pudo descargar el catálogo remoto de apps."
        }
        guard githubAPI else { return data }
        let file = try JSONDecoder().decode(GitHubFile.self, from: data)
        guard file.encoding.lowercased() == "base64",
              let decoded = Data(base64Encoded: file.content, options: .ignoreUnknownCharacters) else {
            throw "La respuesta de GitHub no contiene un catálogo válido."
        }
        return decoded
    }

    private init() {
        lastSync = UserDefaults.standard.object(forKey: Self.syncKey) as? Date
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let response = try? JSONDecoder().decode(BloomBoxAppCatalogResponse.self, from: data),
           response.schemaVersion == 1 {
            listings = response.apps.filter(\.isValid)
        }
    }

    @MainActor
    func refreshIfNeeded(force: Bool = false) async {
        if refreshing { return }
        if !force, let refreshedAt, Date().timeIntervalSince(refreshedAt) < 90 { return }
        refreshing = true
        defer { refreshing = false }

        do {
            let data: Data
            do {
                data = try await Self.fetchCatalogue(at: Self.githubContents, githubAPI: true)
            } catch {
                data = try await Self.fetchCatalogue(at: Self.source, githubAPI: false)
            }
            guard data.count < 300_000 else {
                throw "La tienda recibió un catálogo demasiado grande."
            }
            let decoded = try JSONDecoder().decode(BloomBoxAppCatalogResponse.self, from: data)
            guard decoded.schemaVersion == 1, decoded.apps.count <= 120,
                  decoded.apps.allSatisfy(\.isValid) else {
                throw "La tienda recibió fichas inválidas."
            }
            listings = decoded.apps
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
            let now = Date()
            refreshedAt = now
            lastSync = now
            UserDefaults.standard.set(now, forKey: Self.syncKey)
            lastError = nil
        } catch {
            // Keep the last verified catalogue. Do not throttle the next retry
            // after a network failure; the user may have just reconnected.
            lastError = error.localizedDescription
        }
    }
}

private struct BloomBoxAppStoreIcon: View {
    let app: BloomBoxAppListing
    @State private var artwork: URL?

    var body: some View {
        Group {
            if let artwork {
                AsyncImage(url: artwork) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .task(id: app.id) {
            if let direct = app.appIconURL, let url = URL(string: direct),
               BloomBoxAppStoreArtwork.isTrustedArtwork(url) {
                artwork = url
            } else if app.appStoreID != nil || app.bundleID != nil {
                artwork = await BloomBoxAppStoreArtwork.shared.iconURL(
                    appStoreID: app.appStoreID, bundleID: app.bundleID
                )
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(red: 0.20, green: 0.48, blue: 0.65)
            Image(systemName: app.category == "emulation" ? "gamecontroller.fill" :
                    app.category == "tools" ? "wrench.and.screwdriver.fill" : "app.fill")
                .font(.system(size: 25))
                .foregroundStyle(.white)
        }
    }
}

private struct BloomBoxAppStore: View {
    let apps: [LCAppModel]
    let openSources: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var catalog = BloomBoxAppCatalog.shared

    @State private var section = 0
    @State private var query = ""
    @State private var pendingInstall: BloomBoxAppListing?
    @State private var confirmInstall = false

    private var visibleListings: [BloomBoxAppListing] {
        let base: [BloomBoxAppListing]
        switch section {
        case 0: base = catalog.listings.filter { $0.featured == true }
        case 2: base = catalog.listings.filter { $0.category == "ports" }
        default: base = catalog.listings
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return base }
        return base.filter {
            [$0.name, $0.creator, $0.categoryTitle, $0.description]
                .contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    /// MeloCafé and MeloCafe (or apps renamed during sideloading) should
    /// resolve to the same app without confusing unrelated bundle IDs.
    private func normalizedAppName(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return folded.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func installed(_ listing: BloomBoxAppListing) -> Bool {
        let installedApps = apps + sharedModel.apps +
            (sharedModel.isHiddenAppUnlocked ? sharedModel.hiddenApps : [])
        let expectedBundle = listing.bundleID?.lowercased()
        let expectedNames = Set(([listing.name, listing.id] + (listing.aliases ?? []))
            .map(normalizedAppName)
            .filter { !$0.isEmpty })

        return installedApps.contains { guest in
            guard !(guest.appInfo is BuiltInSideStoreAppInfo) else { return false }
            if let expectedBundle,
               expectedBundle.caseInsensitiveCompare(guest.bundleIdentifier) == .orderedSame {
                return true
            }
            let bundleTail = guest.bundleIdentifier.split(separator: ".").last.map(String.init) ?? ""
            let installationName = URL(fileURLWithPath:
                guest.appInfo.relativeBundlePath ?? ""
            ).deletingPathExtension().lastPathComponent
            return [guest.displayName, bundleTail, installationName].contains {
                expectedNames.contains(normalizedAppName($0))
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 65, height: 65)
                            .background(Color(red: 0.20, green: 0.55, blue: 0.77),
                                        in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BloomBox App Store").font(.title2.bold())
                            Text("Aplicaciones de creadores independientes")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("\(catalog.listings.count) apps en catálogo",
                              systemImage: "square.stack.3d.up")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Actualizar") {
                            Task { await catalog.refreshIfNeeded(force: true) }
                        }.disabled(catalog.refreshing)
                    }
                    if catalog.refreshing {
                        ProgressView("Actualizando tienda...")
                    } else if let last = catalog.lastSync {
                        Label("Sincronizado: \(last.formatted(date: .abbreviated, time: .shortened))",
                              systemImage: "checkmark.circle")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let error = catalog.lastError {
                        Label("Sin conexión: se conserva la última lista válida. \(error)",
                              systemImage: "wifi.exclamationmark")
                            .font(.caption).foregroundStyle(.orange)
                    }

                    Picker("Explorar apps", selection: $section) {
                        Text("Destacadas").tag(0)
                        Text("Explorar").tag(1)
                        Text("Ports").tag(2)
                    }.pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Buscar apps, autores, categorías", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if visibleListings.isEmpty && !catalog.refreshing {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No se encontraron aplicaciones").font(.headline)
                            Text("Prueba otra búsqueda o actualiza el catálogo.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }

                    ForEach(visibleListings) { listing in
                        listingCard(listing)
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.async { openSources() }
                    } label: {
                        Label("Explorar repositorios AltStore", systemImage: "tray.full.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Text("BloomBox no distribuye IPAs de terceros. Cada ficha enlaza al autor original. Solo descarga archivos de proyectos en los que confíes. La ejecución dentro del contenedor puede fallar por restricciones de iOS o JIT.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }
            .navigationTitle("App Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await catalog.refreshIfNeeded(force: true) }
            .confirmationDialog("Instalar IPA en BloomBox",
                                isPresented: $confirmInstall,
                                titleVisibility: .visible) {
                Button("Descargar e instalar bajo mi responsabilidad", role: .destructive) {
                    guard let selected = pendingInstall,
                          let url = selected.verifiedGuestIPA,
                          let sha256 = selected.sha256 else { return }
                    pendingInstall = nil
                    dismiss()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.InstallAppNotification,
                            object: ["url": url, "sha256": sha256]
                        )
                    }
                }
                Button("Cancelar", role: .cancel) { pendingInstall = nil }
            } message: {
                Text("La IPA se descargará desde el release original. Se verificará su SHA-256 antes de instalarla. Puede requerir JIT o permisos no disponibles en BloomBox; haz un respaldo de tus datos.")
            }
        }
    }

    private func listingCard(_ item: BloomBoxAppListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                BloomBoxAppStoreIcon(app: item)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.headline)
                    Text(item.creator)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(item.categoryTitle)
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if installed(item) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3).foregroundStyle(.green)
                        .accessibilityLabel("Instalada")
                }
            }
            Text(item.description)
                .font(.subheadline).foregroundStyle(.secondary)
            if item.requiresJIT {
                Label("Puede requerir JIT · \(item.jit?.externalHelper ?? "depurador")",
                      systemImage: "bolt.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if item.shouldWarn {
                Label("Uso bajo tu propio riesgo · No probado en BloomBox",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.orange)
            }
            if let note = item.notes, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            if let release = item.currentOfficialRelease {
                Text("Versión publicada: \(release)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if installed(item) {
                Label("Detectada en BloomBox", systemImage: "checkmark.shield.fill")
                    .font(.footnote).foregroundStyle(.green)
            } else if item.verifiedGuestIPA != nil {
                Button {
                    pendingInstall = item
                    confirmInstall = true
                } label: {
                    Label("Descargar e instalar IPA", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
            } else {
                Label("Instalación directa no habilitada · consulta el lanzamiento",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let project = item.officialURL {
                    Link(destination: project) {
                        Label("Autor", systemImage: "person.crop.circle")
                    }
                }
                if let releases = item.releasesURL {
                    Link(destination: releases) {
                        Label("Releases", systemImage: "arrow.up.right.square")
                    }
                }
                if let builder = item.buildToolURL {
                    Link(destination: builder) {
                        Label("PadMint", systemImage: "hammer.fill")
                    }
                }
            }
            .font(.footnote.weight(.medium))
        }
        .padding(17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}
