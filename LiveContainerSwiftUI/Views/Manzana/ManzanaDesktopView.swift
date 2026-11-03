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
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var newsLocale: Locale { Locale(identifier: preferredLanguage == "system" ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage) }
    private var english: Bool { newsLocale.languageCode == "en" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BloomBox").font(.largeTitle.bold())
                        Text(english ? "News and desktop" : "Novedades y escritorio")
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
                    .environment(\.locale, newsLocale)
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
    /// Optional launcher key selected by the user. Nil keeps legacy tap behavior.
    /// Old saved widget JSON decodes without this key.
    var tapActionKey: String? = nil
    /// Optional: old layouts continue to decode with their original clock.
    var clockStyle: String? = nil
    var clockTint: String? = nil
    var clock24Hour: Bool? = nil
    var pixelGlow: Double? = nil
    var pixelAnimatedBar: Bool? = nil
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
        else { throw BloomBoxMotionMedia.failure("Selecciona una imagen o GIF válido de hasta 30 MB.") }

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
                throw BloomBoxMotionMedia.failure("No se pudo convertir esa foto. Prueba con JPG, PNG o GIF.")
            }
            extensionName = "jpg"; payload = converted
        }
        let file = "widget-" + UUID().uuidString + "." + extensionName
        let target = directory.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try payload.write(to: target, options: .atomic)
            if isGIF { _ = try BloomBoxMotionMedia.gifFrames(target) }
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
        guard let fileData else { throw BloomBoxMotionMedia.failure("No se pudo leer la imagen.") }
        return try importData(fileData)
    }
}


/// Shared widget accent palette. Automatic mode samples a bounded 24x24
/// thumbnail of the first image/GIF frame, never the full animated media.
/// The result is cached by imported media path, so moving widgets is cheap.
enum BloomBoxWidgetGlowPalette {
    private static let thumbnailCache = NSCache<NSString, UIColor>()
    private static let mint = UIColor(red: 0.38, green: 0.96, blue: 0.78, alpha: 1)

    static func color(_ preset: String?, for widget: BloomBoxPlacedWidget) -> Color {
        switch preset {
        case "mint": return Color(red: 0.38, green: 0.96, blue: 0.78)
        case "blue": return Color(red: 0.25, green: 0.72, blue: 1.0)
        case "pink": return Color(red: 1.0, green: 0.45, blue: 0.78)
        case "amber": return Color(red: 1.0, green: 0.76, blue: 0.32)
        case "red": return Color(red: 1.0, green: 0.32, blue: 0.38)
        case "white": return .white
        default: return automatic(for: widget)
        }
    }

    private static func automatic(for widget: BloomBoxPlacedWidget) -> Color {
        if widget.kind == "clock" {
            switch widget.clockTint {
            case "pink": return color("pink", for: widget)
            case "mint": return color("mint", for: widget)
            case "amber": return color("amber", for: widget)
            case "white", nil: return .white
            default: return Color(uiColor: mint)
            }
        }
        guard widget.kind == "media",
              let url = BloomBoxWidgetMedia.url(for: widget.mediaName),
              FileManager.default.fileExists(atPath: url.path) else {
            return Color(uiColor: mint)
        }
        let key = url.path as NSString
        if let previous = thumbnailCache.object(forKey: key) {
            return Color(uiColor: previous)
        }
        let accent = sampleMediaColor(url) ?? mint
        thumbnailCache.setObject(accent, forKey: key)
        return Color(uiColor: accent)
    }

    private static func sampleMediaColor(_ url: URL) -> UIColor? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 24,
            kCGImageSourceShouldCache: false
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixels,
                                      width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(preview, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Vote by vivid color family rather than averaging against black or transparency.
        var votes = [Double](repeating: 0, count: 12)
        var hueSums = [Double](repeating: 0, count: 12)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.4 else { continue }
            let red = min(1, Double(pixels[offset]) / (255 * alpha))
            let green = min(1, Double(pixels[offset + 1]) / (255 * alpha))
            let blue = min(1, Double(pixels[offset + 2]) / (255 * alpha))
            let maximum = max(red, max(green, blue))
            let minimum = min(red, min(green, blue))
            let difference = maximum - minimum
            guard maximum > 0.18, difference > 0.1,
                  difference / maximum > 0.23 else { continue }
            var hue: Double
            if maximum == red {
                hue = (green - blue) / difference
            } else if maximum == green {
                hue = (blue - red) / difference + 2
            } else {
                hue = (red - green) / difference + 4
            }
            if hue < 0 { hue += 6 }
            let fraction = hue / 6
            let bucket = min(11, Int(fraction * 12))
            let score = alpha * (difference / maximum) * maximum
            votes[bucket] += score
            hueSums[bucket] += score * fraction
        }
        guard let selected = (0..<votes.count).max(by: { votes[$0] < votes[$1] }),
              votes[selected] > 0 else { return nil }
        return UIColor(hue: CGFloat(hueSums[selected] / votes[selected]),
                       saturation: 0.79, brightness: 0.98, alpha: 1)
    }
}

/// Native SwiftUI clock faces. No remote code, assets, or dependencies required.
private struct BloomBoxClockFace: View {
    let widget: BloomBoxPlacedWidget
    let accentOverride: Color?

    private var tint: Color {
        if let accentOverride, widget.clockStyle == "pixel" { return accentOverride }
        switch widget.clockTint {
        case "mint": return Color(red: 0.38, green: 0.96, blue: 0.78)
        case "pink": return Color(red: 1.0, green: 0.61, blue: 0.82)
        case "amber": return Color(red: 1.0, green: 0.76, blue: 0.38)
        default: return .white
        }
    }

    private var style: String { widget.clockStyle ?? "minimal" }
    private var tiny: Bool { widget.columns == 1 || widget.rows == 1 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let components = Calendar.current.dateComponents([.hour, .minute, .second], from: context.date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let second = components.second ?? 0
            let displayHour = (widget.clock24Hour ?? true) ? hour : (hour % 12 == 0 ? 12 : hour % 12)
            let value = String(format: "%02d:%02d", displayHour, minute)
            Group {
                switch style {
                case "flip":
                    flipFace(value: value, date: context.date)
                case "analog":
                    analogFace(hour: hour, minute: minute, second: second)
                case "pixel":
                    pixelFace(value: value, second: second)
                default:
                    minimalFace(value: value, date: context.date)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(tint)
            .accessibilityLabel("Hora: \(value)")
        }
    }

    private func minimalFace(value: String, date: Date) -> some View {
        VStack(spacing: tiny ? 1 : 5) {
            Text(value)
                .font(.system(size: tiny ? 23 : 36, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if !tiny {
                Text(date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.82)
            }
        }
        .padding(8)
    }

    private func flipFace(value: String, date: Date) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: tiny ? 2 : 4) {
                ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        Text(":").font(.system(size: tiny ? 17 : 31, weight: .bold, design: .monospaced))
                    } else {
                        Text(String(character))
                            .font(.system(size: tiny ? 18 : 31, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            // Keep iOS 15 deployment compatibility; flip changes animate via parent.
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, tiny ? 6 : 11)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.black.opacity(0.72))
                                    .overlay(alignment: .center) {
                                        Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                                    }
                            }
                    }
                }
            }
            if !tiny {
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 7)
        .animation(.easeInOut(duration: 0.25), value: value)
    }

    private func analogFace(hour: Int, minute: Int, second: Int) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.87
            ZStack {
                Circle().strokeBorder(tint.opacity(0.78), lineWidth: 2)
                ForEach(0..<12, id: \.self) { tick in
                    Capsule()
                        .fill(tint.opacity(tick.isMultiple(of: 3) ? 0.95 : 0.55))
                        .frame(width: tick.isMultiple(of: 3) ? 2.5 : 1.5, height: side * 0.075)
                        .offset(y: -side * 0.40)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: side * 0.27)
                    .offset(y: -side * 0.13)
                    .rotationEffect(.degrees(Double(hour % 12) * 30 + Double(minute) * 0.5))
                Capsule()
                    .fill(tint)
                    .frame(width: 2.5, height: side * 0.37)
                    .offset(y: -side * 0.17)
                    .rotationEffect(.degrees(Double(minute) * 6 + Double(second) * 0.1))
                Capsule()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: 1.5, height: side * 0.43)
                    .offset(y: -side * 0.14)
                    .rotationEffect(.degrees(Double(second) * 6))
                Circle().fill(tint).frame(width: 7, height: 7)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(7)
    }

    private func pixelFace(value: String, second: Int) -> some View {
        VStack(spacing: tiny ? 2 : 6) {
            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill").font(.system(size: tiny ? 10 : 15))
                if !tiny { Text("PIXEL TIME").font(.system(size: 9, weight: .bold, design: .monospaced)) }
            }
            .opacity(0.8)
            Text(value)
                .font(.system(size: tiny ? 20 : 33, weight: .black, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .shadow(color: tint.opacity(0.75 * max(0, min(1, widget.pixelGlow ?? 1))), radius: 7 * max(0, min(1, widget.pixelGlow ?? 1)))
            if !tiny {
                HStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(index <= ((widget.pixelAnimatedBar ?? false) ? (second / 5) : 5) ? tint : tint.opacity(0.13))
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                    }
                }
            }
        }
        .padding(9)
        .background(Color.black.opacity(0.27), in: RoundedRectangle(cornerRadius: 11))
        .padding(5)
    }
}

struct BloomBoxGridWidgetView: View {
    let widget: BloomBoxPlacedWidget
    let width: CGFloat
    let height: CGFloat
    var active = true
    var clockAccentColor: Color? = nil
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
                    BloomBoxClockFace(widget: widget, accentOverride: clockAccentColor)
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
        // UIKit-rendered GIFs and a clear/no-glass background can leave no
        // hit-testable SwiftUI pixels. This nearly invisible backing surface
        // keeps the whole widget tile touchable without adding glass.
        .background {
            RoundedRectangle(cornerRadius: 19)
                .fill(Color.black.opacity(0.002))
                .contentShape(Rectangle())
        }
        .contentShape(RoundedRectangle(cornerRadius: 19))
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
    let completion: (Data?, Bool) -> Void
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
        let completion: (Data?, Bool) -> Void
        init(_ completion: @escaping (Data?, Bool) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { self.completion(nil, false) }
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
                    DispatchQueue.main.async { self.completion(data, true) }
                } else {
                    self.fallbackToImageObject(provider)
                }
            }
        }
        private func fallbackToImageObject(_ provider: NSItemProvider) {
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { self.completion(nil, true) }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                let image = object as? UIImage
                let data = image?.pngData() ?? image?.jpegData(compressionQuality: 0.9)
                DispatchQueue.main.async { self.completion(data, true) }
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
    private var feedAddress = ""
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var english: Bool { (preferredLanguage == "system" ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage).lowercased().hasPrefix("en") }
    private var defaultFeed: String { "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/news/\(english ? "en" : "es").json" }
    // Earlier builds persisted the old built-in feed URL. Treat that legacy
    // default as automatic so upgrades use BloomBox-Catalog and its locale feeds.
    // Preserve any genuinely custom HTTPS news source selected by the user.
    private var activeFeed: String {
        let saved = feedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if saved.isEmpty || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/feature/bloombox-2-ui-foundation-20261031/remote/news.json" || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/main/remote/news.json" {
            return defaultFeed
        }
        return saved
    }
    @State private var posts: [BloomBoxNewsPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var editingFeed = false
    @State private var feedDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(english ? "BloomBox News" : "Novedades de BloomBox", systemImage: "newspaper.fill")
                    .font(.headline)
                Spacer()
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.disabled(loading).accessibilityLabel("Actualizar novedades")
                Button { feedDraft = activeFeed; editingFeed = true } label: {
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
        .task(id: activeFeed) { await refresh() }
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
        guard let url = URL(string: activeFeed), url.scheme?.lowercased() == "https" else {
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
                  data.count <= 256_000 else { throw BloomBoxMotionMedia.failure("La lista de noticias no está disponible.") }
            let decoded = try JSONDecoder().decode(BloomBoxNewsFeed.self, from: data)
            posts = Array(decoded.posts.prefix(12))
            error = nil
        } catch {
            self.error = english ? "Could not load news. Tap refresh to try again." : "No se pudieron cargar las noticias. Desliza o toca actualizar para intentar otra vez."
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
                _ = try BloomBoxMotionMedia.gifFrames(target)
                gifFile = target
            } catch {
                gifFile = nil
            }
        }
    }
}
