import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

private struct BloomBoxThemeShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


func liveBoardAppKey(_ app: LCAppModel) -> String {
    if app.appInfo is BuiltInSideStoreAppInfo { return "builtin:sidestore" }
    return "\(app.uiIsShared ? "shared" : "local"):\(app.appInfo.relativeBundlePath ?? app.bundleIdentifier)"
}

// BloomBox Alive: view-only motion, no launcher state or guest app data changes.
private struct BloomBoxAliveIconFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct BloomBoxAliveEntrance: ViewModifier {
    let entranceEnabled: Bool
    let revealed: Bool
    let delay: Double
    let playfulStyle: Int?
    let playfulActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(!entranceEnabled || revealed ? 1 : 0)
            .scaleEffect(!entranceEnabled || revealed ? 1 : 0.46, anchor: .bottom)
            .offset(y: entranceEnabled && !revealed ? 22 : 0)
            .offset(y: playfulActive && playfulStyle == 0 ? -11 : 0)
            .offset(x: playfulActive && playfulStyle == 1 ? 4 : 0)
            .rotationEffect(.degrees(playfulActive && playfulStyle == 2 ? 9 : 0))
            .animation(.spring(response: 0.39, dampingFraction: 0.59).delay(entranceEnabled ? delay : 0),
                       value: revealed)
            .animation(.spring(response: 0.21, dampingFraction: 0.35), value: playfulActive)
    }
}

// Keep multiple photo/file sheets out of the huge Home ViewBuilder expression.
private struct BloomBoxWidgetMediaPresentation: ViewModifier {
    @Binding var sourcePresented: Bool
    @Binding var photoPresented: Bool
    @Binding var filePresented: Bool
    @Binding var importing: Bool
    let openPhotos: () -> Void
    let openFiles: () -> Void
    let cancel: () -> Void
    let photoResult: (Data?, Bool) -> Void
    let fileResult: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Foto o GIF para el widget",
                                isPresented: $sourcePresented,
                                titleVisibility: .visible) {
                Button("Elegir de Fotos", action: openPhotos)
                Button("Importar de Archivos", action: openFiles)
                Button("Cancelar", role: .cancel, action: cancel)
            }
            .sheet(isPresented: $photoPresented) {
                BloomBoxMediaPhotosPicker(completion: photoResult)
            }
            .fileImporter(isPresented: $filePresented,
                          allowedContentTypes: [.image, .gif],
                          onCompletion: fileResult)
            .overlay {
                if importing {
                    ProgressView("Importando imagen o GIF…")
                        .padding(22)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
    }
}

/// Keep a stable tile identity throughout editing. A local drag on an explicit
/// handle avoids UIKit lifting/hiding the animated media view for drag-and-drop.
private struct BloomBoxWidgetInteraction<MenuContent: View>: ViewModifier {
    let editing: Bool
    let select: () -> Void
    let move: (CGSize) -> Void
    let menu: () -> MenuContent
    @GestureState(resetTransaction: Transaction(animation: nil)) private var translation = CGSize.zero

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .contextMenu {
                // Editing has its own options button; do not let a long-press
                // menu recognizer compete with the movement handle.
                if !editing { menu() }
            }
            .overlay(alignment: .bottomLeading) {
                if editing {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.72), in: Circle())
                        .contentShape(Rectangle())
                        .padding(4)
                        .highPriorityGesture(
                            // The page sits inside TabView's UIKit host. Use the fixed
                            // screen coordinate space, never the moving tile/page space.
                            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                .updating($translation) { value, state, transaction in
                                    transaction.animation = nil
                                    transaction.disablesAnimations = true
                                    state = value.translation
                                }
                                .onChanged { _ in select() }
                                .onEnded { value in move(value.translation) }
                        )
                        .accessibilityLabel("Arrastrar widget")
                        .accessibilityHint("Usa Opciones para moverlo a otra página")
                }
            }
            .offset(translation)
            // Finger tracking must be immediate, including gesture reset and
            // the grid-position commit. Never interpolate successive samples.
            .transaction { transaction in
                // Live drag never lerps behind the finger; normal widgets
                // must still receive the BloomBox Alive entrance spring.
                if editing {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}

// Living Widgets 1.0: independent, low-cost motion with no timers when offscreen.
private struct BloomBoxLivingMotion: ViewModifier {
    let mode: String
    let speed: Double
    let travel: Double
    let enabled: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !enabled || mode == "none")) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let frequency = 0.15 + max(0, min(100, speed)) / 100.0 * 0.75
            let phase = t * frequency * .pi * 2
            let distance = CGFloat(max(0, min(100, travel))) * 0.65
            let dx: CGFloat = mode == "horizontal" ? sin(phase) * distance :
                mode == "wander" ? sin(phase * 0.63) * distance : 0
            let dy: CGFloat = mode == "float" ? sin(phase) * distance * 0.45 :
                mode == "wander" ? cos(phase * 0.79) * distance * 0.35 : 0
            content.offset(x: enabled ? dx : 0, y: enabled ? dy : 0)
        }
    }
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
    @AppStorage("BloomBoxBuiltInFolderMigrated", store: LCUtils.appGroupUserDefault)
    private var builtInFolderMigrated = false
    @AppStorage("BloomBoxWidgetMissingAppFallbacks", store: LCUtils.appGroupUserDefault)
    private var widgetFallbacksJSON = "{}"\n    @AppStorage("BloomBoxLivingWidgetSettings", store: LCUtils.appGroupUserDefault)\n    private var livingWidgetSettingsJSON = "{}"
    @State private var themeExportURL: URL?
    @State private var themeExportError: String?
    @State private var layout = LiveBoardHomeLayout()
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
                        ManzanaDesktopView(openSettings: { desktopSettings = true })
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
                if aliveEnabled && aliveBooting && aliveStartupPage == page && !reduceMotion {
                    // A blurred welcome layer that never intercepts taps or swipes.
                    ZStack {
                        // Blur the *existing* wallpaper, do not create a second
                        // video/GIF player just for the welcome screen.
                        Rectangle().fill(.regularMaterial)
                        Color.black.opacity(0.22)
                        VStack(spacing: 12) {
                            Text("BloomBox")
                                .font(.system(size: 53, weight: .bold, design: .rounded))
                                .tracking(-2)
                                .shadow(color: .white.opacity(0.28), radius: 23)
                            Text(aliveSplashLine)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 1, green: 0.87, blue: 0.38))
                                .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
                                .rotationEffect(.degrees(-5))
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .accessibilityLabel(aliveSplashLine)
                        }
                        .scaleEffect(aliveIntroVisible ? 1 : 1.05)
                    }
                    .ignoresSafeArea()
                    .opacity(aliveIntroVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.27), value: aliveIntroVisible)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(20)
                }
                if editing && !searching {
                    // Keep the editing toolbar only as tall as its actual
                    // buttons. The previous full-screen VStack + Spacer was a
                    // topmost interaction layer over page controls and widgets.
                    HStack {
                        Menu {
                            Button("Añadir widget", systemImage: "square.grid.2x2.badge.plus") { showWidgetGallery = true }
                            Button("Personalizar", systemImage: "paintbrush") { iconCustomization = true }
                            Button("Exportar tema", systemImage: "square.and.arrow.up") { exportCurrentTheme() }
                            Button("Añadir página", systemImage: "plus") { addPage() }
                            Button("Gestionar páginas", systemImage: "square.grid.2x2") { pageManager = true }
                            Button("Biblioteca de apps", systemImage: "square.grid.2x2") {
                                finishEditing()
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                                    page = libraryPageIndex
                                }
                            }
                        } label: {
                            Text("Editar").font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                        }
                        .liveBoardGlass(radius: 18, interactive: false)
                        Spacer()
                        Button("Listo") { finishEditing() }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .liveBoardGlass(radius: 18, interactive: false)
                    }
                    .padding(.horizontal, 22)
                    .zIndex(15)
                    .sheet(isPresented: Binding(get: { themeExportURL != nil },
                                                set: { if !$0 { themeExportURL = nil } })) {
                        if let url = themeExportURL { BloomBoxThemeShareSheet(fileURL: url) }
                    }
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
            .onAppear {
                ramPlus.refresh()
                Task { await tweakCatalog.refreshIfNeeded() }
                layout = LiveBoardHomeLayout.decode(savedLayout)
                reconcile()
                migrateLegacyPageWidgets()
                restoreWidgetSpace()
                homeHasAppeared = true
                wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
                if #available(iOS 16.2, *) {
                    Task { await ManzanaExpiryReminderCenter.shared.synchronize() }
                }
                if page > 0 && hiddenPageIndices.contains(page - 1) {
                    page = (visiblePageIndices.first ?? 0) + 1
                }
                startBloomBoxAlive()
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
                ManzanaWidgetGallery()
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
                        let name = try await Task.detached(priority: .userInitiated) { try ManzanaWallpaperMedia.importFile(url) }.value
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
        if old != name, let oldURL = ManzanaWallpaperMedia.url(old) {
            try? FileManager.default.removeItem(at: oldURL)
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
        if [Self.sideStoreKey, Self.installKey, Self.tweakStoreKey, Self.appStoreKey, Self.modulesKey, Self.themesKey].contains(key) { return "Utilidades" }
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
        else if key == Self.themesKey { return } // Placeholder; store comes later.
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
    private func addPlacedWidget(_ kind: String, columns: Int = 2, rows: Int = 2) {
        guard page > 0, layout.pages.indices.contains(page - 1) else { return }
        var all = placedWidgets
        var target = page - 1
        var slot = BloomBoxWidgetGrid.firstAvailable(
            columns: columns, rows: rows, occupied: occupiedCells(on: target))
        if slot == nil {
            layout.pages.append(Array(repeating: nil, count: LiveBoardHomeLayout.capacity))
            target = layout.pages.count - 1
            slot = 0
        }
        guard let slot else { return }
        let widget = BloomBoxPlacedWidget(kind: kind, slot: slot,
                                         columns: columns, rows: rows)
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
        guard let entry = placedWidgets.first(where: { $0.value.contains(where: { $0.id == id }) }),
              let widget = entry.value.first(where: { $0.id == id }) else { return }
        let occupied = occupiedCells(on: entry.key, excluding: id)
        let samePosition = BloomBoxWidgetGrid.cells(slot: widget.slot,
                            columns: columns, rows: rows)
        let newSlot = (samePosition != nil && samePosition!.isDisjoint(with: occupied))
            ? widget.slot : BloomBoxWidgetGrid.firstAvailable(
                            columns: columns, rows: rows, occupied: occupied)
        guard let newSlot else {
            widgetMediaError = "No hay espacio para ese tamaño. Prueba otra página."
            return
        }
        updateWidget(id) { item in
            item.columns = columns; item.rows = rows; item.slot = newSlot
        }
        moveIconsOutOfWidgetArea()
    }
    private func movePlacedWidget(_ id: String, to targetPage: Int, slot: Int?) {
        guard targetPage >= 0, layout.pages.indices.contains(targetPage),
              let source = placedWidgets.first(where: { $0.value.contains(where: { $0.id == id }) }),
              let widget = source.value.first(where: { $0.id == id }) else { return }
        var all = placedWidgets
        let occupied = (all[targetPage] ?? [])
            .filter { $0.id != id }
            .reduce(into: Set<Int>()) { result, widget in
                result.formUnion(BloomBoxWidgetGrid.cells(slot: widget.slot,
                                 columns: widget.columns, rows: widget.rows) ?? [])
            }
        let chosen = slot.flatMap { candidate -> Int? in
            guard let cells = BloomBoxWidgetGrid.cells(
                slot: candidate, columns: widget.columns, rows: widget.rows),
                cells.isDisjoint(with: occupied) else { return nil }
            return candidate
        } ?? BloomBoxWidgetGrid.firstAvailable(
                columns: widget.columns, rows: widget.rows, occupied: occupied)
        guard let chosen else {
            widgetMediaError = "No cabe ese widget en la página seleccionada."
            return
        }
        all[source.key]?.removeAll { $0.id == id }
        var moved = widget; moved.slot = chosen
        all[targetPage, default: []].append(moved)
        savePlacedWidgets(all)
        moveIconsOutOfWidgetArea()
        page = targetPage + 1
        selectedWidgetID = id
        UISelectionFeedbackGenerator().selectionChanged()
    }
    private func moveIconsOutOfWidgetArea() {
        // Reflow, never discard app keys or modify their data. A fully occupied
        // page spills excess icons onto the next available Home page.
        for index in layout.pages.indices {
            let occupied = occupiedCells(on: index)
            var displaced: [String] = []
            for slot in occupied where layout.pages[index].indices.contains(slot) {
                if let key = layout.pages[index][slot] {
                    displaced.append(key)
                    layout.pages[index][slot] = nil
                }
            }
            for key in displaced {
                var target = index
                while true {
                    if !layout.pages.indices.contains(target) {
                        layout.pages.append(Array(repeating: nil, count: LiveBoardHomeLayout.capacity))
                    }
                    let reserved = occupiedCells(on: target)
                    if let free = layout.pages[target].indices.first(where: {
                        layout.pages[target][$0] == nil && !reserved.contains($0)
                    }) {
                        layout.pages[target][free] = key
                        break
                    }
                    target += 1
                }
            }
        }
    }
    private func restoreWidgetSpace() { moveIconsOutOfWidgetArea() }

    private var widgetAddSheet: some View {
        NavigationView {
            List {
                Section("Añade tantos como quieras") {
                    Button { addPlacedWidget("clock"); showWidgetGallery = false } label: {
                        Label("Reloj", systemImage: "clock.fill")
                    }
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

    private func exportCurrentTheme() {
        // Export only presentation settings, never installed app data, credentials or private files.
        let defaults = LCUtils.appGroupUserDefault
        let keys = ["LiveBoardHomeLayout", "LiveBoardHiddenPages", "BloomBoxPlacedWidgetsV2",
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
        if let url = ManzanaWallpaperMedia.url(motionWallpaper),
           let bytes = try? Data(contentsOf: url) {
            media["motion-wallpaper"] = bytes.base64EncodedString()
            settings["ManzanaMotionWallpaper"] = motionWallpaper
        }
        settings["BloomBoxWidgetMissingAppFallbacks"] = widgetFallbacksJSON\n        settings["BloomBoxLivingWidgetSettings"] = livingWidgetSettingsJSON
        let payload: [String: Any] = ["format": "bbtheme", "version": 2,
                                      "mediaBase64": media,
                                      "exportedAt": ISO8601DateFormatter().string(from: Date()),
                                      "settings": settings]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("BloomBox-Theme.bbtheme")
            try data.write(to: url, options: .atomic)
            themeExportURL = url
        } catch {
            themeExportError = "No se pudo exportar el tema: \(error.localizedDescription)"
        }
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
        var mode: String = "none"
        var speed: Double = 75
        var travel: Double = 60
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
        let living = livingSettings(for: widget.id)\n        let delay = Double(widget.slot % 4) * 0.145
            + Double(widget.slot / 4) * 0.026
        return BloomBoxGridWidgetView(widget: widget, width: w, height: h,
                                      active: page == index + 1)
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
            .modifier(BloomBoxLivingMotion(mode: living.mode, speed: living.speed, travel: living.travel,\n                enabled: scenePhase == .active && page == index + 1 && !editing && !reduceMotion && !searching))\n            .zIndex(selectedWidgetID == widget.id ? 2 : 1)
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
            else if isThemes { return } // Intentionally no action until theme store ships.
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
                .modifier(ManzanaIconTreatment())
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
            if isThemes && !layout.folders.isEmpty {
                Menu("Meter en carpeta", systemImage: "folder") {
                    ForEach(layout.folders) { folder in
                        Button(folder.name) { layout.put(key, in: folder.id); reconcile() }
                    }
                }
            }
            if isThemes && layout.folders.contains(where: { $0.apps.contains(key) }) {
                Button("Sacar de carpeta", systemImage: "folder.badge.minus") {
                    layout.place(key, on: max(0, page - 1)); reconcile()
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

    @ViewBuilder private func folderIcon(_ folder: LiveBoardHomeLayout.Folder, showLabel: Bool) -> some View {
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
            .modifier(ManzanaIconTreatment()).clipShape(RoundedRectangle(cornerRadius: 4))
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
        .transition(reduceMotion ? .opacity :
            .asymmetric(insertion: .scale(scale: 0.58, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.78, anchor: .center).combined(with: .opacity)))
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
                Section("Iconos") { ManzanaIconCustomization() }
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
        let previouslyHidden = hiddenPageIndices
        let movedIcons = layout.pages[index].contains { $0 != nil }
        let targetPage = min(index, layout.pages.count - 2)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            if layout.removePage(at: index) {
                var widgetMap = placedWidgets
                let moving = widgetMap.removeValue(forKey: index) ?? []
                var shiftedWidgets: [Int: [BloomBoxPlacedWidget]] = [:]
                for (old, items) in widgetMap {
                    shiftedWidgets[old > index ? old - 1 : old] = items
                }
                savePlacedWidgets(shiftedWidgets)
                for widget in moving {
                    moveWidgetToAvailablePage(widget, preferred: targetPage)
                }
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
    private func addPage() { layout.pages.append(Array(repeating: nil, count: LiveBoardHomeLayout.capacity)); page = layout.pages.count }
    private func setCategory(_ value: String?, key: String) {
        var map = (try? JSONDecoder().decode([String: String].self, from: Data(categories.utf8))) ?? [:]
        map[key] = value
        if let data = try? JSONEncoder().encode(map), let string = String(data: data, encoding: .utf8) { categories = string }
    }
    private func moveWidgetToAvailablePage(_ widget: BloomBoxPlacedWidget, preferred: Int) {
        var target = min(max(0, preferred), max(0, layout.pages.count - 1))
        var occupied = occupiedCells(on: target)
        var chosen = BloomBoxWidgetGrid.firstAvailable(columns: widget.columns,
                                   rows: widget.rows, occupied: occupied)
        if chosen == nil {
            layout.pages.append(Array(repeating: nil, count: LiveBoardHomeLayout.capacity))
            target = layout.pages.count - 1
            occupied = occupiedCells(on: target)
            chosen = BloomBoxWidgetGrid.firstAvailable(columns: widget.columns,
                                   rows: widget.rows, occupied: occupied)
        }
        guard let chosen else { return }
        var all = placedWidgets
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
private struct BloomBoxThemesIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 0.35, green: 0.18, blue: 0.70),
                    Color(red: 0.55, green: 0.30, blue: 0.89),
                    Color(red: 0.21, green: 0.51, blue: 0.86)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(Color.white.opacity(0.20))
                .frame(width: size * 0.44, height: size * 0.46)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.075, y: size * 0.045)
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(LinearGradient(colors: [
                    .white.opacity(0.96),
                    Color(red: 0.83, green: 0.84, blue: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.43, height: size * 0.46)
                .rotationEffect(.degrees(10))
                .offset(x: size * 0.085, y: -size * 0.025)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.23, weight: .semibold))
                        .foregroundStyle(Color(red: 0.48, green: 0.27, blue: 0.79))
                        .offset(x: size * 0.09, y: -size * 0.02)
                }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Temas")
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
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    @AppStorage("BloomBoxRAMPlusExperimentalControls", store: LCUtils.appGroupUserDefault)
    private var ramExperimentalControlsEnabled = false
    @AppStorage("BloomBoxJITTryMeloNXScriptForOtherAppsV2", store: LCUtils.appGroupUserDefault)
    private var melonScriptCrossAppEnabled = false

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
    @ObservedObject private var ramPlus = BloomBoxRAMPlus.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(spacing: 16) {
                        BloomBoxModulesIcon(size: 55)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Módulos")
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                            Text("Tu centro de control, sin menús escondidos")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 16)
                    HStack(spacing: 10) {
                        Label("\(Module.allCases.count) herramientas", systemImage: "square.grid.2x2.fill")
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Label(ramPlus.validation.confirmed ? "RAM+ activa" :
                              (ramPlus.needsAttention ? "Revisar RAM+" : "RAM+ sin confirmar"),
                              systemImage: ramPlus.validation.confirmed ? "checkmark.shield.fill" : "cpu")
                            .foregroundStyle(ramPlus.validation.confirmed ? Color.green : Color.white.opacity(0.78))
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 3)
                    .accessibilityElement(children: .combine)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Module.allCases) { module in
                            NavigationLink(destination: detail(for: module)) {
                                tile(module)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.modules.\(module.rawValue)")
                        }
                    }
                    Text("Accesos directos a funciones reales. JIT y RAM+ conservan sus comprobaciones y permisos originales.")
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
        .frame(minHeight: 154)
        .background {
            // Transparent color surfaces, intentionally no Liquid Glass.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.105, green: 0.12, blue: 0.18).opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [module.tint.opacity(0.17), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [module.tint.opacity(0.62), .white.opacity(0.10)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.title). \(module.subtitle)")
    }

    @ViewBuilder private func detail(for module: Module) -> some View {
        switch module {
        case .ram:
            ramDetail
        case .jit:
            BloomBoxJITControlPanel(apps: apps)
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
        ScrollView {
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
                    Picker("Idioma de BloomBox", selection: $preferredLanguage) {
                        Text("Automático (iPhone)").tag("system")
                        Text("Español").tag("es")
                        Text("English").tag("en")
                    }
                    .accessibilityIdentifier("bloombox.experiments.language.picker")
                    Text("Preferencia experimental para probar los catálogos de noticias por idioma. No cambia el idioma del iPhone; la traducción completa de la interfaz se incorporará por etapas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    NavigationLink {
                        LCStorageManagementView()
                    } label: {
                        Label("Almacenamiento · BloomBox, SideStore y apps", systemImage: "externaldrive.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.storage.open")
                    Text("Mide el espacio utilizado por las apps invitadas, SideStore y BloomBox. Permite identificar datos, cachés y archivos temporales sin borrarlos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    Toggle("Probar script JIT de MeloNX en otras apps", isOn: $melonScriptCrossAppEnabled)
                        .tint(Color(red: 0.72, green: 0.45, blue: 1))
                        .accessibilityIdentifier("bloombox.experiments.melonScriptCrossApp.toggle")
                    Text("Interruptor maestro de seguridad: permite las pruebas de script solo en las apps que selecciones abajo. No cambia el JIT de MeloNX ni activa JIT en todas las apps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        BloomBoxJITGuestControlsView(apps: apps)
                    } label: {
                        Label("Pruebas avanzadas del script MeloNX", systemImage: "flask.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.jitApps.open")
                    Text("Los interruptores habituales están en Módulos > JIT. Aquí se conserva la prueba experimental del script MeloNX en otras apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if melonScriptCrossAppEnabled {
                        Label("La prueba solo se aplicará a las apps seleccionadas. Un motor incompatible puede quedarse congelado o cerrarse.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Divider()
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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

/// Self-contained destination: later move its NavigationLink from Experimental to
/// Modules > JIT without migrating stored choices or changing the launch coordinator.
/// Built-in JIT control surface: every guest has independent launch settings.
private struct BloomBoxJITControlPanel: View {
    let apps: [LCAppModel]
    @State private var search = ""
    @State private var importing = false
    @State private var target: LCAppModel?
    @State private var scriptError: String?
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault)
    private var provider = JITEnablerType.SideJITServer.rawValue

    private var installed: [LCAppModel] {
        var ids = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            !app.appInfo.relativeBundlePath.isEmpty &&
            ids.insert(app.appInfo.relativeBundlePath).inserted
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    private var visible: [LCAppModel] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? installed : installed.filter {
            $0.displayName.localizedCaseInsensitiveContains(q) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(q)
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Label("JIT", systemImage: "bolt.fill").font(.title2.bold()).foregroundStyle(.orange)
                NavigationLink {
                    LiveBoardJITSetup(embedded: true)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.title2).foregroundStyle(.orange)
                            .frame(width: 48, height: 48)
                            .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Habilitar JIT").font(.headline)
                            Text("Pairing, LocalDevVPN y conexión")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(14).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bloombox.modules.jit.enable")

                HStack {
                    Text("JIT por aplicación").font(.headline)
                    Spacer()
                    Text(String(installed.count) + " apps").font(.caption).foregroundStyle(.secondary)
                }
                Text("Encendido: solicita JIT al abrir. Apagado: abre sin JIT. Universal por defecto excepto MeloNX 2.6. Mantén presionada una app para importar otro script.")
                    .font(.footnote).foregroundStyle(.secondary)
                if provider != JITEnablerType.BuiltIn.rawValue {
                    Label("Para scripts integrados, elige Built-in JIT en Habilitar JIT.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
                TextField("Buscar aplicación", text: $search)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                ForEach(visible, id: \.appInfo.relativeBundlePath) { app in
                    BloomBoxJITSwitchRow(app: app) { target = app; importing = true }
                }
                if visible.isEmpty {
                    Text("No hay aplicaciones que coincidan.").foregroundStyle(.secondary)
                }
                Text("Se aplica al próximo lanzamiento. Algunos emuladores requieren scripts propios; evita ejecutarlos si el iPhone se está calentando.")
                    .font(.caption).foregroundStyle(.orange)
            }.padding(18)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).ignoresSafeArea())
        .navigationTitle("JIT").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.javaScript], allowsMultipleSelection: false) { result in
            let app = target
            target = nil
            guard let app else { return }
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard url.pathExtension.lowercased() == "js" else {
                    throw NSError(domain: "BloomBoxJIT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Elige un archivo .js."])
                }
                let data = try Data(contentsOf: url)
                guard !data.isEmpty, data.count <= 512 * 1024,
                      String(data: data, encoding: .utf8) != nil else {
                    throw NSError(domain: "BloomBoxJIT", code: 2, userInfo: [NSLocalizedDescriptionKey: "El script debe ser UTF-8 y tener máximo 512 KB."])
                }
                app.jitLaunchScriptJs = data.base64EncodedString()
            } catch {
                scriptError = error.localizedDescription
            }
        }
        .alert("No se pudo importar el script", isPresented: Binding(
            get: { scriptError != nil },
            set: { if !$0 { scriptError = nil } })) {
            Button("Aceptar") { scriptError = nil }
        } message: { Text(scriptError ?? "") }
    }
}

private struct BloomBoxJITSwitchRow: View {
    @ObservedObject var app: LCAppModel
    let importScript: () -> Void
    @State private var enabled: Bool
    init(app: LCAppModel, importScript: @escaping () -> Void) {
        self.app = app
        self.importScript = importScript
        let mode = BloomBoxJITGuestPolicy.mode(
            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
        let guest = Bundle(path: app.appInfo.bundlePath())
        let melon = BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: guest?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        _enabled = State(initialValue: BloomBoxJITGuestPolicy.wantsJIT(
            automatic: app.appInfo.isJITNeeded || app.appInfo.is32bit || melon,
            forced: nil, mode: mode))
    }
    private var specialMeloNX: Bool {
        let guest = Bundle(path: app.appInfo.bundlePath())
        return BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: guest?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill").foregroundStyle(.purple)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(app.jitLaunchScriptJs?.isEmpty == false ? "Script personalizado" :
                     specialMeloNX ? "Script propio de MeloNX" : "Universal JIT")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Toggle("JIT " + app.displayName, isOn: $enabled).labelsHidden().tint(.orange)
                .onChange(of: enabled) { on in
                    BloomBoxJITGuestPolicy.setMode(on ? .enabled : .disabled,
                        for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
                }
                .accessibilityIdentifier("bloombox.modules.jit.app.toggle")
        }
        .padding(14)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .contextMenu {
            Button { importScript() } label: {
                Label("Importar script JIT (.js)", systemImage: "doc.badge.plus")
            }
            if app.jitLaunchScriptJs?.isEmpty == false {
                Button { app.jitLaunchScriptJs = nil } label: {
                    Label("Restaurar script predeterminado", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}

struct BloomBoxJITGuestControlsView: View {
    let apps: [LCAppModel]
    @State private var searchText = ""
    @AppStorage("BloomBoxJITTryMeloNXScriptForOtherAppsV2", store: LCUtils.appGroupUserDefault)
    private var scriptExperimentEnabled = false
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault)
    private var provider = JITEnablerType.SideJITServer.rawValue

    private var installedApps: [LCAppModel] {
        var seen = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            !app.appInfo.relativeBundlePath.isEmpty &&
            seen.insert(app.appInfo.relativeBundlePath).inserted
        }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var visibleApps: [LCAppModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("JIT por aplicación").font(.title2.bold())
                        Text("Preparación del futuro módulo JIT")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Text("Automático respeta la configuración original. Activado solicita JIT; Desactivado impide solicitarlo. Cambia el siguiente lanzamiento, no cierra apps abiertas.")
                    .font(.footnote).foregroundStyle(.secondary)
                if provider != JITEnablerType.BuiltIn.rawValue {
                    Label("El script experimental de MeloNX solo funciona con Built-in JIT. El control JIT por app también puede afectar otros proveedores.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if !scriptExperimentEnabled {
                    Label("Pruebas con script MeloNX desactivadas globalmente. Puedes preparar las selecciones, pero no se aplicarán hasta encender el interruptor anterior.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                TextField("Buscar aplicación", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("bloombox.experiments.jitApps.search")
                if visibleApps.isEmpty {
                    Text("No hay aplicaciones que coincidan con tu búsqueda.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 18)
                }
                ForEach(visibleApps, id: \.appInfo.relativeBundlePath) { app in
                    BloomBoxJITGuestExperimentRow(
                        app: app,
                        isBuiltIn: provider == JITEnablerType.BuiltIn.rawValue,
                        experimentEnabled: scriptExperimentEnabled)
                }
                Text("Esto es experimental: un script no crea compatibilidad JIT por sí solo. Si falla, vuelve a Automático y desmarca la prueba MeloNX.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            .padding(18)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).ignoresSafeArea())
        .navigationTitle("JIT por app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BloomBoxJITGuestExperimentRow: View {
    @ObservedObject var app: LCAppModel
    let isBuiltIn: Bool
    let experimentEnabled: Bool
    @State private var jitMode: BloomBoxJITGuestPolicy.Mode
    @State private var tryMeloScript: Bool

    init(app: LCAppModel, isBuiltIn: Bool, experimentEnabled: Bool) {
        self.app = app
        self.isBuiltIn = isBuiltIn
        self.experimentEnabled = experimentEnabled
        let defaults = LCUtils.appGroupUserDefault
        _jitMode = State(initialValue: BloomBoxJITGuestPolicy.mode(
            for: app.appInfo.relativeBundlePath, defaults: defaults))
        _tryMeloScript = State(initialValue: BloomBoxJITGuestPolicy.isExperimentSelected(
            for: app.appInfo.relativeBundlePath, defaults: defaults))
    }

    private var isMeloNX26: Bool {
        let bundle = Bundle(path: app.appInfo.bundlePath())
        return BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    private var hasCustomScript: Bool { app.jitLaunchScriptJs?.isEmpty == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.title2).foregroundStyle(.purple)
                    .frame(width: 40, height: 40)
                    .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName).font(.headline)
                    Text(app.bundleIdentifier)
                        .font(.caption2).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            Picker("JIT al abrir", selection: $jitMode) {
                ForEach(BloomBoxJITGuestPolicy.Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .tint(.orange)
            .onChange(of: jitMode) { newMode in
                BloomBoxJITGuestPolicy.setMode(newMode,
                    for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
            }
            .accessibilityIdentifier("bloombox.experiments.jitApps.mode")
            if isMeloNX26 {
                Label("MeloNX 2.6 tiene su perfil automático original.", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Toggle("Probar script de MeloNX 2.6", isOn: $tryMeloScript)
                    .tint(.purple)
                    .disabled(hasCustomScript)
                    .onChange(of: tryMeloScript) { selected in
                        BloomBoxJITGuestPolicy.setExperimentSelected(selected,
                            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
                    }
                    .accessibilityIdentifier("bloombox.experiments.jitApps.melonScript")
                if hasCustomScript {
                    Text("Esta app tiene un script propio; se respeta su prioridad.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if tryMeloScript && experimentEnabled && isBuiltIn && jitMode != .disabled {
                    Text("El script se intentará en el próximo lanzamiento con JIT.")
                        .font(.caption).foregroundStyle(.orange)
                } else if tryMeloScript {
                    Text("Selección guardada; requiere JIT integrado, experimento maestro activo y JIT no desactivado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if jitMode == .disabled {
                Text("JIT desactivado para esta app. «Launch with JIT» mostrará un aviso.")
                    .font(.caption).foregroundStyle(.orange)
            } else if jitMode == .enabled {
                Text("Se solicitará JIT al abrirla, pero esto no garantiza compatibilidad.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.10)))
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

/// Photos' provider URL is temporary: copy the original GIF/video
/// into BloomBox storage before the callback returns.
private struct BloomBoxMotionWallpaperPhotosPicker: UIViewControllerRepresentable {
    let completion: (Result<String, Error>?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.videos, .images])
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (Result<String, Error>?) -> Void
        init(_ completion: @escaping (Result<String, Error>?) -> Void) {
            self.completion = completion
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { self.completion(nil) }
                return
            }
            let isGIF = provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier)
            let type = isGIF ? UTType.gif.identifier :
                provider.registeredTypeIdentifiers.first(where: {
                    UTType($0)?.conforms(to: .movie) == true
                })
            guard let type else {
                DispatchQueue.main.async {
                    self.completion(.failure(ManzanaWallpaperMedia.failure(
                        "Ese archivo no es un GIF ni un video. Para fotos normales usa Elegir foto."
                    )))
                }
                return
            }
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                let result: Result<String, Error>
                if let url {
                    do {
                        let ext = isGIF ? "gif" : (UTType(type)?.preferredFilenameExtension ?? "mov")
                        let name = try ManzanaWallpaperMedia.importFile(url, fileExtension: ext)
                        result = .success(name)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .failure(error ?? ManzanaWallpaperMedia.failure(
                        "Fotos no pudo entregar el video o GIF. Prueba importarlo desde Archivos."
                    ))
                }
                DispatchQueue.main.async { self.completion(result) }
            }
        }
    }
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
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/catalog/tweaks-v2.json")!

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

// BloomBox 2.0: shared, lightweight header style for the integrated stores.
private struct BloomBoxV2StoreHeader: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(colors: [accent, accent.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.085)))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(0.20), lineWidth: 1)
        }
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
                    BloomBoxV2StoreHeader(
                        symbol: "puzzlepiece.extension.fill",
                        title: "Tweak Store",
                        subtitle: "Correcciones, personalización y herramientas",
                        accent: Color(red: 0.48, green: 0.32, blue: 0.76)
                    )
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
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/catalog/apps.json")!
    private static let githubContents = URL(string:
        "https://api.github.com/repos/adri23rep-stack/BloomBox-Catalog/contents/catalog/apps.json?ref=main")!

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
                    BloomBoxV2StoreHeader(
                        symbol: "bag.fill",
                        title: "BloomBox App Store",
                        subtitle: "Aplicaciones de creadores independientes",
                        accent: Color(red: 0.20, green: 0.55, blue: 0.77)
                    )

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
