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
    private var reduceMotion: Bool { systemReduceMotion || customReduceMotion }
    @State private var layout = LiveBoardHomeLayout()
    @State private var page = 1
    @State private var desktopSettings = false
    @State private var editing = false
    @State private var pendingRemovalKey: String?
    @State private var removedIcon: String?
    @State private var pageManager = false
    @State private var pendingPageRemoval: Int?
    @State private var desktopAction: DesktopAction?
    @State private var searching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var customizing = false
    @State private var choosingWallpaper = false
    @State private var wallpaper: UIImage?
    @State private var openFolder: String?
    @State private var folderPage = 0
    @State private var renameKey: String?
    @State private var renameValue = ""
    @State private var newFolderApp: String?
    @State private var folderName = ""
    @State private var wallpaperError: String?

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
    private var favoriteKeys: [String] { (try? JSONDecoder().decode([String].self, from: Data(favorites.utf8))) ?? [] }
    private var wallpaperURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true).appendingPathComponent("wallpaper.jpg")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background.blur(radius: searching ? 8 : 0)
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ManzanaDesktopView(openSettings: { desktopSettings = true }).tag(0)
                        ForEach(layout.pages.indices, id: \.self) { index in
                            homePage(index, width: geometry.size.width, height: max(400, geometry.size.height - 126)).tag(index + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .blur(radius: openFolder == nil ? 0 : 18)
                    pageControl.padding(.bottom, 18)
                    dock(width: geometry.size.width)
                        .padding(.horizontal, 12)
                        .padding(.bottom, -22)
                        .blur(radius: openFolder == nil ? 0 : 18)
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
                                Text("(Int(min(1, max(0, installProgress)) * 100)) %")
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
                                Button("Personalizar", systemImage: "paintbrush") { customizing = true }
                                Button("Añadir página", systemImage: "plus") { addPage() }
                                Button("Gestionar páginas", systemImage: "square.grid.2x2") { pageManager = true }
                                Button("Biblioteca de apps", systemImage: "magnifyingglass") { searching = true }
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
                if !searching && !editing && openFolder == nil && page > 0 &&
                    value.translation.height > 65 && abs(value.translation.height) > abs(value.translation.width) * 1.4 {
                    beginSearch()
                }
            })
            .onChange(of: appKeys) { _ in reconcile() }
            .onChange(of: layout) { savedLayout = $0.encoded; page = min(page, layout.pages.count) }
            .onAppear {
                layout = LiveBoardHomeLayout.decode(savedLayout)
                reconcile()
                wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
            }
        }
        .background(LiveBoardOrientationLock(mask: .portrait))
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .sheet(isPresented: $pageManager) {
            NavigationView {
                List {
                    ForEach(layout.pages.indices, id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Página \(index + 1)")
                                Text("\(layout.pages[index].compactMap { $0 }.count) iconos")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                if layout.pages[index].allSatisfy({ $0 == nil }) {
                                    removePage(index)
                                } else {
                                    pendingPageRemoval = index
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 42, height: 42)
                            }
                            .disabled(layout.pages.count <= 1)
                            .accessibilityLabel("Eliminar página \(index + 1)")
                        }
                    }
                }
                .navigationTitle("Páginas")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Listo") { pageManager = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            addPage()
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .confirmationDialog("Eliminar página", isPresented: Binding(
                        get: { pendingPageRemoval != nil },
                        set: { if !$0 { pendingPageRemoval = nil } }
                    ), titleVisibility: .visible) {
                        Button("Eliminar página y reubicar iconos", role: .destructive) {
                            if let index = pendingPageRemoval { removePage(index) }
                            pendingPageRemoval = nil
                        }
                        Button("Cancelar", role: .cancel) { pendingPageRemoval = nil }
                    } message: {
                        Text("Los iconos se moverán a otra página. No se desinstala ninguna aplicación.")
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
        .sheet(isPresented: $jitSetup) { LiveBoardJITSetup() }
        .sheet(isPresented: $customizing) { customizeSheet }
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

    private var background: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if wallpaperStyle == "photo", let wallpaper {
                    Image(uiImage: wallpaper).resizable().aspectRatio(contentMode: wallpaperFit ? .fit : .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if wallpaperStyle != "black" {
                    LiveBoardRibbonWallpaper(blue: wallpaperStyle == "blue")
                }
                Color.black.opacity(wallpaperDim)
            }
        }.ignoresSafeArea()
    }

    private func homePage(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
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
        Button("App Settings", systemImage: "gearshape") { searching = false; manage(app) }
        Button("Quitar del escritorio", systemImage: "minus.circle", role: .destructive) { removeFromHome(key) }
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
            ForEach(0...layout.pages.count, id: \.self) { index in
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
                        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 4))
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

    private var customizeSheet: some View {
        NavigationView {
            Form {
                Section("Wallpaper") {
                    Button("Choose Photo") { customizing = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { choosingWallpaper = true } }
                    Picker("Background", selection: $wallpaperStyle) {
                        Text("Red ribbons").tag("red"); Text("Blue ribbons").tag("blue"); Text("Black").tag("black")
                        if wallpaper != nil { Text("Your photo").tag("photo") }
                    }
                    if wallpaperStyle == "photo" { Toggle("Fit entire image", isOn: $wallpaperFit) }
                    VStack(alignment: .leading) { Text("Dim wallpaper"); Slider(value: $wallpaperDim, in: 0...0.7) }
                }
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
        guard layout.pages.count > 1 else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            if layout.removePage(at: index) {
                if page > index + 1 { page -= 1 }
                else if page == index + 1 { page = min(index + 1, layout.pages.count) }
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
        let keysBefore = layout.pages.flatMap { $0.compactMap { $0 } }
            + layout.dock + layout.folders.flatMap { $0.apps }
        let needsShortcuts = [Self.sideStoreKey, Self.installKey]
            .filter { !keysBefore.contains($0) }
        layout.reconcile(appKeys, favorites: favoriteKeys)
        // Restore missing shortcuts once. Later moves preserve the user's chosen placement.
        for key in needsShortcuts.reversed() {
            layout.place(key, on: 0)
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
    @ObservedObject var app: LCAppModel
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    let dark: Bool
    var body: some View {
        Group {
            if let image = LiveBoardIconStore.image(app, dark: dark) { Image(uiImage: image).resizable().scaledToFill() }
            else {
                ZStack { Color(white: 0.2); Image(systemName: "app.dashed").resizable().scaledToFit().padding(14).foregroundColor(.white.opacity(0.6)) }
            }
        }.aspectRatio(1, contentMode: .fit)
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
