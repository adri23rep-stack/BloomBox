import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

// BloomBox-native remote stores, separated from Home layout to keep SwiftUI
// compilation bounded and guest launch behavior unchanged.
struct BloomBoxTweakTarget: Codable {
    let bundleID: String
    let minVersion: String?
    let maxVersion: String?
}

struct BloomBoxTweakEntry: Codable, Identifiable {
    let id: String
    let name: String
    let version: String
    let developer: String?
    // Optional original author repository or official website; display only.
    // Never use this URL as a tweak download source.
    let officialSourceURL: String?
    let description: String?
    let descriptionEn: String?
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
    let notesEn: String?
    let downloadURL: String
    let sha256: String

    var officialProjectURL: URL? {
        guard let officialSourceURL, officialSourceURL.count <= 2048,
              let link = URL(string: officialSourceURL),
              link.scheme == "https", link.host != nil,
              link.user == nil, link.password == nil else { return nil }
        return link
    }

    func localizedDescription(english: Bool) -> String {
        english ? (descriptionEn ?? description ?? "Compatibility fix") : (description ?? "Corrección de compatibilidad")
    }
    func localizedNotes(english: Bool) -> String? { english ? (notesEn ?? notes) : notes }

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

final class BloomBoxTweakCatalog: ObservableObject {
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
    let symbolInk: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(symbolInk)
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
                Text(LocalizedStringKey(title)).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(LocalizedStringKey(subtitle)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.085)))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                 .strokeBorder(accent.opacity(0.36), lineWidth: 1)
        }
    }
}

struct BloomBoxTweakStore: View {
    let apps: [LCAppModel]
    let focusedApp: LCAppModel?

    init(apps: [LCAppModel], focusedApp: LCAppModel?) {
        self.apps = apps
        self.focusedApp = focusedApp
    }
    @AppStorage(BloomBoxProfileStore.activeKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeActiveID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeProfilesData = Data()
    private var profileAccentHex: String {
        BloomBoxProfileTheme.hex(activeID: themeActiveID, profilesData: themeProfilesData)
    }
    private var profileAccent: Color { BloomBoxWizardPalette.color(profileAccentHex) }
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var englishUI: Bool { preferredLanguage == "en" || (preferredLanguage == "system" && (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en")) }
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
                        accent: profileAccent,
                        symbolInk: BloomBoxProfileTheme.ink(for: profileAccentHex)
                    )
                    HStack {
                        Label(englishUI ? "\(catalog.entries.count) tweaks in catalog" : "\(catalog.entries.count) tweaks en catálogo", systemImage: "arrow.triangle.2.circlepath")
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
            .background(BloomBoxProfileThemeBackdrop())
            .tint(profileAccent)
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
                            Text(match.entry.localizedDescription(english: englishUI))
                                .font(.subheadline).foregroundStyle(.secondary)
                            if match.entry.useAtOwnRisk == true {
                                Label("Uso bajo tu propio riesgo · No verificado en BloomBox",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                            if let notes = match.entry.localizedNotes(english: englishUI) {
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
            Text(entry.localizedDescription(english: englishUI))
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
            if let notes = entry.localizedNotes(english: englishUI) {
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
    let descriptionEn: String?
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
    let notesEn: String?
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

    func localizedDescription(english: Bool) -> String { english ? (descriptionEn ?? description) : description }
    func localizedNotes(english: Bool) -> String? { english ? (notesEn ?? notes) : notes }

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

struct BloomBoxAppStore: View {
    let apps: [LCAppModel]
    let openSources: () -> Void

    init(apps: [LCAppModel], openSources: @escaping () -> Void) {
        self.apps = apps
        self.openSources = openSources
    }

    @AppStorage(BloomBoxProfileStore.activeKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeActiveID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeProfilesData = Data()
    private var profileAccentHex: String {
        BloomBoxProfileTheme.hex(activeID: themeActiveID, profilesData: themeProfilesData)
    }
    private var profileAccent: Color { BloomBoxWizardPalette.color(profileAccentHex) }
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var englishUI: Bool { preferredLanguage == "en" || (preferredLanguage == "system" && (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en")) }
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
            [$0.name, $0.creator, $0.categoryTitle, $0.description, $0.descriptionEn ?? ""]
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
                        subtitle: englishUI ? "Apps from independent developers" : "Aplicaciones de creadores independientes",
                        accent: profileAccent,
                        symbolInk: BloomBoxProfileTheme.ink(for: profileAccentHex)
                    )

                    HStack {
                        Label(englishUI ? "\(catalog.listings.count) apps in catalog" : "\(catalog.listings.count) apps en catálogo",
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(profileAccent.opacity(0.24), lineWidth: 1)
                    }

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
            .background(BloomBoxProfileThemeBackdrop())
            .tint(profileAccent)
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
                    Text(LocalizedStringKey(item.categoryTitle))
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if installed(item) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3).foregroundStyle(.green)
                        .accessibilityLabel("Instalada")
                }
            }
            Text(item.localizedDescription(english: englishUI))
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
            if let note = item.localizedNotes(english: englishUI), !note.isEmpty {
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
