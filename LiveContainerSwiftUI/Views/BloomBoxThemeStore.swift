import SwiftUI
import UniformTypeIdentifiers
import ImageIO

private struct BloomBoxThemeStoreShare: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Theme files contain presentation settings and user-supplied pictures only.
/// Never import apps, scripts, credentials, entitlements or executable files.
enum BloomBoxThemePackage {
    enum ThemeError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): return reason }
        }
    }

    static let maxBytes = 90 * 1024 * 1024

    static func read(_ data: Data) throws -> (settings: [String: Any], media: [String: Data]) {
        guard data.count > 0, data.count <= maxBytes,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["format"] as? String == "bbtheme",
              root["version"] as? Int == 2,
              let settings = root["settings"] as? [String: Any],
              let strings = root["mediaBase64"] as? [String: String],
              strings.count <= 150 else {
            throw ThemeError.invalid("Invalid BloomBox theme (v2) or file exceeds 90 MB.")
        }
        let permittedKeys: Set<String> = [
            "wallpaper.jpg", "motion-wallpaper"
        ]
        var media: [String: Data] = [:]
        for (name, encoded) in strings {
            guard permittedKeys.contains(name) || BloomBoxWidgetMedia.url(for: name) != nil,
                  let bytes = Data(base64Encoded: encoded),
                  !bytes.isEmpty, bytes.count <= 80 * 1024 * 1024 else {
                throw ThemeError.invalid("The theme includes an invalid media file.")
            }
            media[name] = bytes
        }
        return (settings, media)
    }

    static func apply(_ data: Data, defaults: UserDefaults,
                      currentLayout: LiveBoardHomeLayout, appKeys: [String],
                      favorites: [String], wallpaperURL: URL) throws -> LiveBoardHomeLayout {
        let payload = try read(data)
        let settings = payload.settings
        var mediaFiles: [String: String] = [:]
        var created: [URL] = []
        let fileManager = FileManager.default

        // Fully validate the saved layout before touching the current desktop.
        var newLayout = currentLayout
        if let raw = settings["LiveBoardHomeLayout"] as? String {
            guard let decoded = raw.data(using: .utf8),
                  let layout = try? JSONDecoder().decode(LiveBoardHomeLayout.self, from: decoded),
                  layout.pages.count <= 24, layout.folders.count <= 80 else {
                throw ThemeError.invalid("This theme has an invalid desktop layout.")
            }
            newLayout = layout
        }
        newLayout.reconcile(appKeys, favorites: favorites)

        var newWidgets: String?
        if let raw = settings["BloomBoxPlacedWidgetsV2"] as? String {
            guard let bytes = raw.data(using: .utf8),
                  var pages = try? JSONDecoder().decode([Int: [BloomBoxPlacedWidget]].self, from: bytes),
                  pages.count <= 24, pages.values.reduce(0, { $0 + $1.count }) <= 160 else {
                throw ThemeError.invalid("This theme has invalid widget placements.")
            }
            for (page, widgets) in pages {
                guard page >= 0, page < newLayout.pages.count else {
                    throw ThemeError.invalid("A widget is outside the desktop pages.")
                }
                var ids = Set<String>()
                for widget in widgets {
                    guard ids.insert(widget.id).inserted,
                          BloomBoxWidgetGrid.cells(slot: widget.slot,
                            columns: widget.columns, rows: widget.rows) != nil else {
                        throw ThemeError.invalid("A widget has an invalid size or position.")
                    }
                }
            }
            // Import only media referenced by actual widgets (no unused assets).
            do {
                for (page, widgets) in pages {
                    pages[page] = try widgets.map { item in
                        var widget = item
                        widget.tapActionKey = nil // untrusted themes cannot launch apps on tap
                        if let name = item.mediaName {
                            guard let source = payload.media[name] else {
                                widget.mediaName = nil
                                return widget
                            }
                            if let imported = mediaFiles[name] {
                                widget.mediaName = imported
                            } else {
                                let imported = try BloomBoxWidgetMedia.importData(source)
                                mediaFiles[name] = imported
                                widget.mediaName = imported
                                if let file = BloomBoxWidgetMedia.url(for: imported) { created.append(file) }
                            }
                        }
                        return widget
                    }
                }
                let encoded = try JSONEncoder().encode(pages)
                newWidgets = String(data: encoded, encoding: .utf8)
            } catch {
                for url in created { try? fileManager.removeItem(at: url) }
                throw error
            }
        }

        var newWallpaper: Data?
        if let picture = payload.media["wallpaper.jpg"] {
            guard picture.count <= 30 * 1024 * 1024,
                  let source = CGImageSourceCreateWithData(picture as CFData, nil),
                  CGImageSourceGetCount(source) > 0,
                  let image = UIImage(data: picture),
                  let jpg = image.jpegData(compressionQuality: 0.88) else {
                for url in created { try? fileManager.removeItem(at: url) }
                throw ThemeError.invalid("The theme wallpaper is invalid.")
            }
            newWallpaper = jpg
        }

        var newMotion = ""
        if let motion = payload.media["motion-wallpaper"] {
            let original = settings["ManzanaMotionWallpaper"] as? String ?? ""
            let ext = (original as NSString).pathExtension.lowercased()
            guard ["gif", "mp4", "mov", "m4v"].contains(ext) else {
                for url in created { try? fileManager.removeItem(at: url) }
                throw ThemeError.invalid("The animated wallpaper format is unsupported.")
            }
            let temp = fileManager.temporaryDirectory
                .appendingPathComponent("theme-motion-" + UUID().uuidString + "." + ext)
            do {
                try motion.write(to: temp, options: .atomic)
                newMotion = try ManzanaWallpaperMedia.importFile(temp)
            } catch {
                for url in created { try? fileManager.removeItem(at: url) }
                throw error
            }
            try? fileManager.removeItem(at: temp)
        }

        do {
            if let newWallpaper {
                try fileManager.createDirectory(at: wallpaperURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
                try newWallpaper.write(to: wallpaperURL, options: .atomic)
            }
        } catch {
            for url in created { try? fileManager.removeItem(at: url) }
            if let url = ManzanaWallpaperMedia.url(newMotion) { try? fileManager.removeItem(at: url) }
            throw error
        }

        // Whitelist visual preferences only. Do not import arbitrary UserDefaults.
        let simpleKeys: Set<String> = [
            "LiveBoardHiddenPages", "ManzanaPageWidgets", "LiveBoardLargeIcons",
            "darkModeIcon", "LiveBoardWallpaperStyle", "LiveBoardWallpaperFit",
            "LiveBoardWallpaperDim", "ManzanaIconStyle", "BloomBoxAliveEnabled",
            "BloomBoxAliveIdleEnabled", "BloomBoxLivingWidgetSettings",
            "BloomBoxWidgetMissingAppFallbacks"
        ]
        for (key, value) in settings where simpleKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
        if let newWidgets { defaults.set(newWidgets, forKey: "BloomBoxPlacedWidgetsV2") }
        defaults.set(newLayout.encoded, forKey: "LiveBoardHomeLayout")
        defaults.set(newMotion, forKey: "ManzanaMotionWallpaper")
        return newLayout
    }
}

enum BloomBoxThemeLibrary {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/ThemeLibrary", isDirectory: true)
    }

    static func save(_ data: Data, named name: String) throws -> URL {
        let payload = try BloomBoxThemePackage.read(data)
        let folder = directory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safe = String(name.prefix(45))
            .replacingOccurrences(of: "[^a-zA-Z0-9 _-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let file = folder.appendingPathComponent((safe.isEmpty ? "Theme" : safe)
             + "-" + String(UUID().uuidString.prefix(8)) + ".bbtheme")
        try data.write(to: file, options: .atomic)
        // Small still-image preview, never run or decode full animated GIF frames.
        let art = payload.media["wallpaper.jpg"]
            ?? payload.media.first(where: { $0.key.hasPrefix("widget-") })?.value
        if let art, let source = CGImageSourceCreateWithData(art as CFData, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceThumbnailMaxPixelSize: 192,
               kCGImageSourceCreateThumbnailWithTransform: true
           ] as CFDictionary),
           let thumbnail = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72) {
            try? thumbnail.write(to: file.deletingPathExtension().appendingPathExtension("jpg"),
                                 options: .atomic)
        }
        if name == "Recovery" {
            // Keep only the three most recent recovery copies to avoid storage growth.
            let backups = all().filter {
                $0.deletingPathExtension().lastPathComponent.hasPrefix("Recovery-")
            }
            for old in backups.dropFirst(3) {
                try? FileManager.default.removeItem(at: old)
                try? FileManager.default.removeItem(at:
                    old.deletingPathExtension().appendingPathExtension("jpg"))
            }
        }
        return file
    }

    static func all() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        return items.filter { $0.pathExtension.lowercased() == "bbtheme" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return a > b
            }
    }

    static func readFile(_ url: URL) throws -> Data {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard url.pathExtension.lowercased() == "bbtheme",
              fileSize > 0, fileSize <= BloomBoxThemePackage.maxBytes else {
            throw BloomBoxThemePackage.ThemeError.invalid("Choose a .bbtheme file smaller than 90 MB.")
        }
        let data = try Data(contentsOf: url)
        _ = try BloomBoxThemePackage.read(data)
        return data
    }
}

private struct BloomBoxOnlineThemeIndex: Decodable {
    let version: Int
    let themes: [BloomBoxOnlineTheme]
}

private struct BloomBoxOnlineTheme: Decodable, Identifiable {
    let id: String
    let name: String
    let author: String
    let description: String
    let downloadURL: String
    let previewURL: String?
}

struct BloomBoxThemeStoreView: View {
    let onApply: (Data) throws -> Void
    let onSaveCurrent: () throws -> Data
    @State private var shareURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var library: [URL] = []
    @State private var online: [BloomBoxOnlineTheme] = []
    @State private var importing = false
    @State private var loading = false
    @State private var downloading: String?
    @State private var selected: URL?
    @State private var confirming = false
    @State private var message: String?
    @State private var notice: String?
    @State private var search = ""

    private var shownLibrary: [URL] {
        library.filter { search.isEmpty ||
            $0.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(search) }
    }
    private var shownOnline: [BloomBoxOnlineTheme] {
        online.filter { search.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.author.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Theme Store", systemImage: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("Make your desktop your own. Import, preview, share and apply .bbtheme files.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Import .bbtheme", systemImage: "square.and.arrow.down") { importing = true }
                                .buttonStyle(.borderedProminent)
                            Button("Export Current", systemImage: "square.and.arrow.up") {
                                do {
                                    let url = FileManager.default.temporaryDirectory
                                        .appendingPathComponent("BloomBox-Theme.bbtheme")
                                    try onSaveCurrent().write(to: url, options: .atomic)
                                    shareURL = url
                                } catch { message = error.localizedDescription }
                            }
                                .buttonStyle(.bordered)
                        }
                        Button("Save My Desktop to Library", systemImage: "bookmark.fill") {
                            do {
                                _ = try BloomBoxThemeLibrary.save(onSaveCurrent(), named: "My Desktop")
                                refresh()
                                notice = "Your desktop was saved in My Themes."
                            } catch { message = error.localizedDescription }
                        }.font(.subheadline)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))

                    TextField("Search themes", text: $search)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("My Themes", systemImage: "square.stack.3d.up")
                            .font(.headline)
                        if shownLibrary.isEmpty {
                            Text("No saved themes yet. Import a .bbtheme file or save your desktop above.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(shownLibrary, id: \.path) { url in
                                HStack(spacing: 12) {
                                    savedArt(url)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.subheadline.weight(.semibold)).lineLimit(2)
                                        Text("Saved locally · .bbtheme")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 5)
                                    Button("Apply") { selected = url; confirming = true }
                                        .buttonStyle(.borderedProminent).controlSize(.small)
                                    Button(role: .destructive) {
                                        do {
                                            try FileManager.default.removeItem(at: url)
                                            try? FileManager.default.removeItem(at:
                                                url.deletingPathExtension().appendingPathExtension("jpg"))
                                            refresh()
                                        } catch { message = error.localizedDescription }
                                    } label: {
                                        Image(systemName: "trash")
                                    }.buttonStyle(.borderless)
                                        .accessibilityLabel("Delete saved theme")
                                }
                                .padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Explore Online", systemImage: "globe")
                                .font(.headline)
                            Spacer()
                            if loading { ProgressView().controlSize(.small) }
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                Task { await loadCatalog() }
                            }.font(.caption)
                        }
                        Text("Themes are downloaded from the official BloomBox-Catalog repository.")
                            .font(.caption).foregroundStyle(.secondary)
                        if shownOnline.isEmpty && !loading {
                            Text("No community themes have been published yet. You can still import and share your own themes.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(shownOnline) { item in
                            HStack(spacing: 12) {
                                themeArt
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name).font(.headline)
                                    Text("By " + item.author).font(.caption).foregroundStyle(.secondary)
                                    Text(item.description).font(.caption).lineLimit(3)
                                }
                                Spacer(minLength: 5)
                                Button(downloading == item.id ? "Downloading" : "Get") {
                                    Task { await download(item) }
                                }
                                .disabled(downloading != nil)
                                .buttonStyle(.borderedProminent).controlSize(.small)
                            }
                            .padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
                        }
                    }
                }
                .padding(18)
            }
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL { BloomBoxThemeStoreShare(url: shareURL) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try BloomBoxThemeLibrary.readFile(url)
                    selected = try BloomBoxThemeLibrary.save(data, named: url.deletingPathExtension().lastPathComponent)
                    refresh()
                    confirming = true
                } catch { message = error.localizedDescription }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { message = error.localizedDescription }
            }
        }
        .alert("Apply Theme?", isPresented: $confirming) {
            Button("Apply", role: .destructive) {
                guard let selected else { return }
                do {
                    try onApply(BloomBoxThemeLibrary.readFile(selected))
                    notice = "Theme applied! Your previous desktop was saved as a recovery copy."
                } catch { message = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your desktop layout, widgets and wallpaper may change. Installed apps and their data will not be removed.")
        }
        .alert("Theme Store", isPresented: Binding(
            get: { message != nil || notice != nil },
            set: { if !$0 { message = nil; notice = nil } }
        )) {
            Button("OK") { message = nil; notice = nil }
        } message: { Text(message ?? notice ?? "") }
        .onAppear { refresh(); Task { await loadCatalog() } }
    }

    @ViewBuilder private func savedArt(_ url: URL) -> some View {
        let preview = url.deletingPathExtension().appendingPathExtension("jpg")
        if let image = UIImage(contentsOfFile: preview.path) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 59, height: 59)
                .clipShape(RoundedRectangle(cornerRadius: 15))
        } else {
            themeArt
        }
    }

    private var themeArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(colors: [
                    Color(red: 0.12, green: 0.64, blue: 0.88),
                    Color(red: 0.57, green: 0.24, blue: 0.88)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 23)).foregroundStyle(.white)
        }.frame(width: 59, height: 59)
    }

    private func refresh() { library = BloomBoxThemeLibrary.all() }

    @MainActor private func loadCatalog() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        guard let url = URL(string:
            "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/catalog/themes.json")
        else { return }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 512 * 1024
            else { throw BloomBoxThemePackage.ThemeError.invalid("The theme catalog is unavailable.") }
            let index = try JSONDecoder().decode(BloomBoxOnlineThemeIndex.self, from: data)
            guard index.version == 1, index.themes.count <= 100 else {
                throw BloomBoxThemePackage.ThemeError.invalid("Unsupported theme catalog.")
            }
            online = index.themes.filter { safeDownloadURL($0.downloadURL) != nil }
        } catch {
            online = []
            // The store is still usable offline. Don't interrupt import with errors.
        }
    }

    private func safeDownloadURL(_ path: String) -> URL? {
        guard let url = URL(string: path), url.scheme == "https",
              url.host == "raw.githubusercontent.com",
              url.path.hasPrefix("/adri23rep-stack/BloomBox-Catalog/main/themes/"),
              url.pathExtension.lowercased() == "bbtheme"
        else { return nil }
        return url
    }

    @MainActor private func download(_ item: BloomBoxOnlineTheme) async {
        guard let url = safeDownloadURL(item.downloadURL), downloading == nil else { return }
        downloading = item.id
        defer { downloading = nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= BloomBoxThemePackage.maxBytes else {
                throw BloomBoxThemePackage.ThemeError.invalid("The theme download failed or is too large.")
            }
            selected = try BloomBoxThemeLibrary.save(data, named: item.name)
            refresh()
            confirming = true
        } catch { message = error.localizedDescription }
    }
}
