import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit

// Reusable BloomBox launcher tiles, drag feedback, wallpaper pickers and glass.
// Nothing below launches guests or changes persisted layout identifiers.

struct LiveBoardHomeIcon: View {
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
struct LiveBoardEditWobble: ViewModifier {
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
struct LiveBoardHomePressStyle: ButtonStyle {
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
            .modifier(BloomBoxIconTreatment())
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
struct LiveBoardRibbonWallpaper: View {
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
struct BloomBoxMotionWallpaperPhotosPicker: UIViewControllerRepresentable {
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
                    self.completion(.failure(BloomBoxMotionMedia.failure(
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
                        let name = try BloomBoxMotionMedia.importFile(url, fileExtension: ext)
                        result = .success(name)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .failure(error ?? BloomBoxMotionMedia.failure(
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
struct LiveBoardMoveDropDelegate: DropDelegate {
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