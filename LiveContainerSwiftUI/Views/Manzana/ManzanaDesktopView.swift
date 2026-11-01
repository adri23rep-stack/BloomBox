import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit
import ImageIO

struct ManzanaDesktopView: View {
    let openSettings: () -> Void
    // Retain the original entry point, but no longer render legacy widgets
    // on the dedicated news page. Existing Home widget data is preserved.
    var singleWidget: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BloomBox").font(.largeTitle.bold())
                        Text("Novedades y escritorio")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: openSettings) {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Ajustes del escritorio")
                }

                // Replace the Files shortcut with a small, live clock.
                // Files itself and its stored content are not modified.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 16) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.cyan)
                            .frame(width: 45, height: 50)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Reloj")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(context.date, format: .dateTime.hour().minute())
                                .font(.system(size: 34, weight: .light, design: .rounded))
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)
                            Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .environment(\.locale, Locale(identifier: "es_MX"))
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liveBoardGlass(radius: 24)
                }
                .accessibilityIdentifier("bloombox.news.clock")

                // The dedicated page is only a news feed + compact clock.
                // Photos, notes and sizeable clocks remain available as
                // freely placed widgets on normal Home pages.
                BloomBoxRemoteNewsSection()
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

/// Standalone widget selector. Uses the same persistent order as the original
/// ManzanaDesktopView; no visual changes to the Home or its existing controls.
struct ManzanaWidgetGallery: View {
    var pageSelection: Set<String>? = nil
    var onToggle: ((String) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("ManzanaWidgetOrder", store: LCUtils.appGroupUserDefault)
    private var savedOrder = "clock,photo,notes"
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault)
    private var note = ""
    @State private var photo: UIImage?
    private let available = ["clock", "photo", "notes"]

    @State private var selection: Set<String> = []
    private var order: [String] {
        if pageSelection != nil { return Array(selection) }
        var seen = Set<String>()
        return savedOrder.split(separator: ",").map(String.init)
            .filter { available.contains($0) && seen.insert($0).inserted }
    }
    private var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox", isDirectory: true)
            .appendingPathComponent("widget-photo.jpg")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Elige los widgets para esta página. Mantén pulsado uno en el escritorio para moverlo a otra página.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(available, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Label(title(id), systemImage: symbol(id))
                                    .font(.headline)
                                Spacer()
                                if order.contains(id) {
                                    Label("Añadido", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.green)
                                }
                            }
                            preview(id)
                                .frame(maxWidth: .infinity)
                                .frame(height: 125)
                                .background(.ultraThinMaterial,
                                            in: RoundedRectangle(cornerRadius: 19))
                            Button {
                                toggle(id)
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Label(order.contains(id) ? "Quitar widget" : "Añadir widget",
                                      systemImage: order.contains(id) ? "minus.circle" : "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(order.contains(id) ? .gray : .accentColor)
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 23))
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Añadir widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { photo = UIImage(contentsOfFile: photoURL.path); selection = pageSelection ?? [] }
        .accessibilityIdentifier("manzana.widgets.gallery")
    }

    private func title(_ id: String) -> String {
        switch id {
        case "clock": return "Reloj"
        case "photo": return "Fotos"
        default: return "Notas"
        }
    }
    private func symbol(_ id: String) -> String {
        switch id {
        case "clock": return "clock.fill"
        case "photo": return "photo.fill"
        default: return "note.text"
        }
    }

    @ViewBuilder private func preview(_ id: String) -> some View {
        switch id {
        case "clock":
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 4) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 39, weight: .light, design: .rounded))
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption)
                }
            }
        case "photo":
            if let photo {
                Image(uiImage: photo)
                    .resizable().scaledToFill()
                    .frame(height: 125).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 19))
            } else {
                Label("Tus recuerdos", systemImage: "photo.on.rectangle.angled")
                    .font(.title3)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "note.text").font(.title3)
                Text(note.isEmpty ? "Escribe lo que quieras recordar…" : note)
                    .font(.subheadline).lineLimit(3)
            }
            .padding(12)
        }
    }

    private func toggle(_ id: String) {
        guard available.contains(id) else { return }
        if let onToggle {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            onToggle(id); return
        }
        var values = order
        if values.contains(id) {
            values.removeAll { $0 == id }
        } else {
            values.append(id)
        }
        savedOrder = values.joined(separator: ",")
    }
}

private struct ManzanaPhotoPicker: UIViewControllerRepresentable {
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
            guard let provider = results.first?.itemProvider else { completion(nil); return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in DispatchQueue.main.async { self.completion(image as? UIImage) } }
        }
    }
}


// MARK: - BloomBox 2.0 Home widgets. Persist only layout metadata in defaults;
// media bytes live in app-owned Application Support and never in UserDefaults.
struct BloomBoxPlacedWidget: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var kind: String
    var slot: Int
    var columns: Int
    var rows: Int
    var mediaName: String? = nil
    var fill: Bool = true
    var glass: Bool = true
}

enum BloomBoxWidgetGrid {
    static func cells(slot: Int, columns: Int, rows: Int) -> Set<Int>? {
        let x = slot % 4, y = slot / 4
        guard slot >= 0, slot < 24, columns >= 1, columns <= 4,
              rows >= 1, rows <= 4, x + columns <= 4, y + rows <= 6 else { return nil }
        return Set((0..<rows).flatMap { row in (0..<columns).map { slot + row * 4 + $0 } })
    }
    static func firstAvailable(columns: Int, rows: Int, occupied: Set<Int>) -> Int? {
        (0..<24).first { slot in
            guard let area = cells(slot: slot, columns: columns, rows: rows) else { return false }
            return area.isDisjoint(with: occupied)
        }
    }
}

enum BloomBoxWidgetMedia {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/WidgetMedia", isDirectory: true)
    }
    static func url(for name: String?) -> URL? {
        guard let name, name.hasPrefix("widget-"),
              (name as NSString).lastPathComponent == name,
              ["gif", "jpg", "png", "webp"].contains((name as NSString).pathExtension.lowercased())
        else { return nil }
        return directory.appendingPathComponent(name)
    }
    static func importData(_ data: Data) throws -> String {
        guard data.count > 0, data.count <= 30 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let type = CGImageSourceGetType(source) as String?,
              let imageType = UTType(type), imageType.conforms(to: .image)
        else { throw ManzanaWallpaperMedia.failure("Selecciona una imagen o GIF válido de hasta 30 MB.") }

        let isGIF = type == UTType.gif.identifier
        // Image providers can return HEIC/HEIF/TIFF and other iPhone formats.
        // The old importer mislabeled these bytes as .jpg, making the widget
        // fail to display. Convert unsupported static formats to a real JPEG.
        let extensionName: String
        let payload: Data
        if isGIF {
            extensionName = "gif"; payload = data
        } else if type == UTType.png.identifier {
            extensionName = "png"; payload = data
        } else if type == UTType.jpeg.identifier {
            extensionName = "jpg"; payload = data
        } else if type == UTType.webP.identifier {
            extensionName = "webp"; payload = data
        } else {
            guard let image = UIImage(data: data),
                  let converted = image.jpegData(compressionQuality: 0.9) else {
                throw ManzanaWallpaperMedia.failure("No se pudo convertir esa foto. Prueba con JPG, PNG o GIF.")
            }
            extensionName = "jpg"; payload = converted
        }
        let file = "widget-" + UUID().uuidString + "." + extensionName
        let target = directory.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try payload.write(to: target, options: .atomic)
            if isGIF { _ = try ManzanaWallpaperMedia.gifFrames(target) }
            return file
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }
    static func importFile(_ url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var coordError: NSError?, fileData: Data?, readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { safeURL in
            do { fileData = try Data(contentsOf: safeURL, options: .mappedIfSafe) }
            catch { readError = error }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        guard let fileData else { throw ManzanaWallpaperMedia.failure("No se pudo leer la imagen.") }
        return try importData(fileData)
    }
}

struct BloomBoxGridWidgetView: View {
    let widget: BloomBoxPlacedWidget
    let width: CGFloat
    let height: CGFloat
    var active = true
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault) private var note = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if widget.glass {
                RoundedRectangle(cornerRadius: 19).fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 19).fill(Color.clear)
            }
            Group {
                switch widget.kind {
                case "clock":
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        VStack(spacing: 2) {
                            Text(context.date, format: .dateTime.hour().minute())
                                .font(.system(size: widget.columns == 1 ? 15 : 31,
                                              weight: .medium, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.5)
                            if widget.rows > 1 {
                                Text(context.date, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(7)
                    }
                case "notes":
                    Text(note.isEmpty ? "Notas" : note)
                        .font(.system(size: widget.columns == 1 ? 11 : 16))
                        .lineLimit(max(2, widget.rows * 3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                default:
                    if let file = BloomBoxWidgetMedia.url(for: widget.mediaName),
                       FileManager.default.fileExists(atPath: file.path) {
                        if file.pathExtension.lowercased() == "gif" {
                            ManzanaAnimatedWallpaper(url: file, fit: !widget.fill,
                                paused: scenePhase != .active || !active,
                                clearBackground: true)
                        } else if let image = UIImage(contentsOfFile: file.path) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: widget.fill ? .fill : .fit)
                        } else {
                            Image(systemName: "photo.badge.exclamationmark")
                        }
                    } else {
                        VStack(spacing: 5) {
                            Image(systemName: "photo.on.rectangle.angled").font(.title2)
                            Text("Añadir foto o GIF").font(.caption2).multilineTextAlignment(.center)
                        }.padding(8)
                    }
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay {
            if widget.glass {
                RoundedRectangle(cornerRadius: 19)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.7)
            }
        }
        .accessibilityLabel(widget.kind == "clock" ? "Widget de reloj"
                            : widget.kind == "notes" ? "Widget de notas" : "Widget de foto o GIF")
    }
}

/// Preserve GIF bytes from Photos instead of converting animated images to a
/// single UIImage frame. The callback receives raw data, then the media
/// importer validates and copies it to app-owned storage.
struct BloomBoxMediaPhotosPicker: UIViewControllerRepresentable {
    let completion: (Data?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (Data?) -> Void
        init(_ completion: @escaping (Data?) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { self.completion(nil) }
                return
            }
            // Request a concrete format; 'public.image' is an abstract UTType,
            // and some Photos providers return nil for that identifier.
            let preference = [
                UTType.gif.identifier,
                UTType.png.identifier,
                UTType.jpeg.identifier,
                UTType.heic.identifier,
                UTType.webP.identifier
            ]
            let identifier = preference.first(where: {
                provider.hasItemConformingToTypeIdentifier($0)
            }) ?? provider.registeredTypeIdentifiers.first(where: {
                guard let candidate = UTType($0) else { return false }
                return candidate.conforms(to: .image)
            })
            guard let identifier else {
                fallbackToImageObject(provider)
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { [weak self] data, _ in
                guard let self else { return }
                if let data, !data.isEmpty {
                    DispatchQueue.main.async { self.completion(data) }
                } else {
                    self.fallbackToImageObject(provider)
                }
            }
        }
        private func fallbackToImageObject(_ provider: NSItemProvider) {
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { self.completion(nil) }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                let image = object as? UIImage
                let data = image?.pngData() ?? image?.jpegData(compressionQuality: 0.9)
                DispatchQueue.main.async { self.completion(data) }
            }
        }
    }
}

// MARK: - Read-only remote news. No HTML, scripts, or execution paths.
private struct BloomBoxNewsFeed: Decodable {
    let posts: [BloomBoxNewsPost]
}
private struct BloomBoxNewsPost: Decodable, Identifiable {
    let id: String
    let title: String
    let text: String
    let media: String?
}

private struct BloomBoxRemoteNewsSection: View {
    @AppStorage("BloomBoxNewsFeedURL", store: LCUtils.appGroupUserDefault)
    private var feedAddress = "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/feature/bloombox-2-ui-foundation-20261031/remote/news.json"
    @State private var posts: [BloomBoxNewsPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var editingFeed = false
    @State private var feedDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Novedades de BloomBox", systemImage: "newspaper.fill")
                    .font(.headline)
                Spacer()
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.disabled(loading).accessibilityLabel("Actualizar novedades")
                Button { feedDraft = feedAddress; editingFeed = true } label: {
                    Image(systemName: "link")
                }.accessibilityLabel("Cambiar fuente de noticias")
            }
            if loading && posts.isEmpty { ProgressView("Cargando novedades…") }
            if let error, posts.isEmpty {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(posts.prefix(12))) { post in
                VStack(alignment: .leading, spacing: 11) {
                    Text(post.title).font(.headline)
                    Text(post.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if let media = post.media, let url = URL(string: media),
                       url.scheme?.lowercased() == "https" {
                        BloomBoxRemoteNewsImage(url: url)
                            .frame(height: 210)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 22))
            }
        }
        .task(id: feedAddress) { await refresh() }
        .alert("Fuente de novedades", isPresented: $editingFeed) {
            TextField("Enlace HTTPS a JSON", text: $feedDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Guardar") {
                let input = feedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: input),
                      url.scheme?.lowercased() == "https" else {
                    error = "Usa un enlace HTTPS válido."
                    return
                }
                feedAddress = url.absoluteString
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes modificar las noticias desde cualquier archivo JSON remoto, sin reinstalar BloomBox.")
        }
        .accessibilityIdentifier("bloombox.news.remote")
    }

    @MainActor private func refresh() async {
        guard let url = URL(string: feedAddress), url.scheme?.lowercased() == "https" else {
            error = "La fuente debe ser HTTPS."; return
        }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count <= 256_000 else { throw ManzanaWallpaperMedia.failure("La lista de noticias no está disponible.") }
            let decoded = try JSONDecoder().decode(BloomBoxNewsFeed.self, from: data)
            posts = Array(decoded.posts.prefix(12))
            error = nil
        } catch {
            self.error = "No se pudieron cargar las noticias. Desliza o toca actualizar para intentar otra vez."
        }
    }
}

private struct BloomBoxRemoteNewsImage: View {
    let url: URL
    @State private var gifFile: URL?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if url.pathExtension.lowercased() == "gif" {
                if let gifFile {
                    ManzanaAnimatedWallpaper(url: gifFile, fit: false,
                                             paused: scenePhase != .active,
                                             clearBackground: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: url) {
            guard url.pathExtension.lowercased() == "gif" else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      data.count > 0, data.count <= 10 * 1_024 * 1_024 else { return }
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("BloomBoxNewsGIF", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let name = SHA256.hash(data: Data(url.absoluteString.utf8))
                    .map { String(format: "%02x", $0) }.joined() + ".gif"
                let target = directory.appendingPathComponent(name)
                try data.write(to: target, options: .atomic)
                _ = try ManzanaWallpaperMedia.gifFrames(target)
                gifFile = target
            } catch {
                gifFile = nil
            }
        }
    }
}
