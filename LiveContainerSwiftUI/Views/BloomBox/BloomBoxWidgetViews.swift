import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit
import ImageIO

// BloomBox-owned widget views, media importers and thumbnail effects.
// The saved JSON layout and widget IDs remain compatible with older builds.
// MARK: - BloomBox 2.0 Home widgets. Persist only layout metadata in defaults;
// media bytes live in app-owned Application Support and never in UserDefaults.
// BloomBox widget model, layout grid and placement live in BloomBoxWidgetLayout.swift.
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
                            BloomBoxAnimatedWallpaper(url: file, fit: !widget.fill,
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

