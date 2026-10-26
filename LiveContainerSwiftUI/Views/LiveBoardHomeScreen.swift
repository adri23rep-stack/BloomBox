import SwiftUI
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
    @ObservedObject private var appCustomization = LiveBoardAppCustomization.shared
    @State private var appearanceApp: LiveBoardAppearanceSelection?
    @State private var jitSetup = false
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
    private enum DesktopAction { case interface, sources, tweaks, wallpaper, apps, settings, jit }

    private var appKeys: [String] {
        apps.filter { !($0.appInfo is BuiltInSideStoreAppInfo) }.map(liveBoardAppKey)
            + [Self.sideStoreKey, Self.installKey]
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
                background.blur(radius: (searching || page == libraryPageIndex) ? 14 : 0)
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ManzanaDesktopView(openSettings: { desktopSettings = true }).tag(0)
                        ForEach(visiblePageIndices, id: \.self) { index in
                            homePage(index, width: geometry.size.width, height: max(400, geometry.size.height - 126)).tag(index + 1)
                        }
                        appLibrary(width: geometry.size.width)
                            .tag(libraryPageIndex)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .blur(radius: openFolder == nil ? 0 : 18)
                    if page != libraryPageIndex {
                        pageControl.padding(.bottom, 18)
                        dock(width: geometry.size.width)
                            .padding(.horizontal, 12)
                            .padding(.bottom, -22)
                            .blur(radius: openFolder == nil ? 0 : 18)
                    }
                    else {
                        Color.clear.frame(height: 20)
                    }
                }
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
                                Button("Biblioteca de apps", systemImage: "square.grid.2x2") { finishEditing(); page = libraryPageIndex }
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
            .onChange(of: appKeys) { _ in reconcile() }
            .onChange(of: layout) {
                savedLayout = $0.encoded
                page = min(page, libraryPageIndex)
            }
            .onAppear {
                layout = LiveBoardHomeLayout.decode(savedLayout)
                reconcile()
                homeHasAppeared = true
                wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
                if page > 0 && hiddenPageIndices.contains(page - 1) {
                    page = (visiblePageIndices.first ?? 0) + 1
                }
            }
        }
        .overlay { if importingMotionWallpaper { ProgressView("Preparando fondo…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
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
    private func libraryCategory(for key: String, assigned: [String: String]) -> String {
        if let custom = assigned[key], !custom.isEmpty {
            return custom
        }
        if key == Self.sideStoreKey || key == Self.installKey { return "Utilidades" }
        let hint = "\(title(key)) \(appMap[key]?.bundleIdentifier ?? "")".lowercased()
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
        let assigned = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        let favorites = favoriteKeys.filter { keys.contains($0) }
        var suggestions = favorites
        suggestions.append(contentsOf: keys.filter { !suggestions.contains($0) })
        let stored = recentLibraryKeys.filter { keys.contains($0) }
        let recent = Array((stored + keys.reversed().filter { !stored.contains($0) }).prefix(8))
        var groups: [String: [String]] = [:]
        for key in keys {
            groups[libraryCategory(for: key, assigned: assigned), default: []].append(key)
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
        appKeys.filter {
            libraryQuery.isEmpty ||
            title($0).localizedCaseInsensitiveContains(libraryQuery) ||
            (appMap[$0]?.bundleIdentifier.localizedCaseInsensitiveContains(libraryQuery) ?? false)
        }.sorted { title($0).localizedStandardCompare(title($1)) == .orderedAscending }
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
        .onDrag { NSItemProvider(object: key as NSString) }
        .accessibilityLabel("Abrir \(title(key))")
    }

    private func launchLibraryKey(_ key: String) {
        if key == Self.sideStoreKey { openSideStore() }
        else if key == Self.installKey { openInstall() }
        else if let app = appMap[key] { launch(app) }
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
        .modifier(LiveBoardEditWobble(active: pageManager && !reduceMotion, phase: 0.4))
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
        .modifier(LiveBoardEditWobble(active: pageManager && !reduceMotion, phase: 0.4))
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
            } else if key == Self.sideStoreKey || key == Self.installKey {
                shortcutIcon(key, showLabel: showLabel)
            } else if let app = appMap[key] {
                LiveBoardHomeIcon(app: app, title: title(key), size: largeIcons ? 76 : 64,
                                  showLabel: showLabel, dark: darkIcons, editing: editing,
                                  reduceMotion: reduceMotion, action: {
                    if editing { return }
                    launch(app)
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
        return Button {
            guard !editing else { return }
            if isSideStore { openSideStore() }
            else { openInstall() }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                        .fill(isSideStore ? Color(red: 0.14, green: 0.26, blue: 0.69)
                                          : Color(red: 0.12, green: 0.58, blue: 0.76))
                    if isSideStore, let icon = BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(darkIcons) {
                        Image(uiImage: icon).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
                    } else {
                        Image(systemName: isSideStore ? "square.stack.3d.up.fill" : "square.and.arrow.down.fill")
                            .font(.system(size: size * 0.44, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: size, height: size)
                .modifier(ManzanaIconTreatment())
                .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
                .modifier(LiveBoardEditWobble(active: editing && !reduceMotion,
                         phase: isSideStore ? 0.7 : 2.1))
                if showLabel {
                    Text(isSideStore ? "SideStore" : "Instalar app")
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
        .accessibilityLabel(isSideStore ? "Abrir SideStore" : "Instalar IPA en LiveContainer")
    }

    @ViewBuilder private func appMenu(_ key: String, app: LCAppModel) -> some View {
        Button("Launch", systemImage: "play.fill") { launch(app) }.disabled(app.isAppRunning || app.isSigningInProgress)
        if let launchWithJIT { Button("Launch with JIT", systemImage: "bolt.fill") { launchWithJIT(app) }.disabled(app.appInfo is BuiltInSideStoreAppInfo) }
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
            Button { page = libraryPageIndex } label: {
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
                                if !query.isEmpty, let app = searchResults.first { closeSearch(); launch(app) }
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
                                Button { closeSearch(); launch(app) } label: {
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
        return Button { closeSearch(); launch(app) } label: {
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
        let hadSavedLayout = layout.initialized
        let knownKeys = Set(layout.pages.flatMap { $0.compactMap { $0 } }
            + layout.dock + layout.folders.flatMap { $0.apps } + layout.hidden)
        let needsShortcuts = [Self.sideStoreKey, Self.installKey]
            .filter { !knownKeys.contains($0) }
        // Only installed guest apps not seen before, never icons the user hid.
        let newGuestKeys = hadSavedLayout
            ? appKeys.filter { appMap[$0] != nil && !knownKeys.contains($0) }
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
    private func title(_ key: String) -> String {
        if key == Self.sideStoreKey { return "SideStore" }
        if key == Self.installKey { return "Instalar app" }
        if let folder = layout.folders.first(where: { $0.id == key }) { return folder.name }
        return appMap[key].map { appCustomization.name($0) } ?? "App"
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
                      key == Self.sideStoreKey || key == Self.installKey ||
                      layout.folders.contains(where: { $0.id == key }) else { return }
                apply(key)
            }
        }
        return true
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
    @ViewBuilder func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { time in
                content.rotationEffect(.degrees(sin(time.date.timeIntervalSinceReferenceDate * 22 + phase) * 1.5))
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
