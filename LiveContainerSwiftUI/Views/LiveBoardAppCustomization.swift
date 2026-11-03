import SwiftUI

/// BloomBox-owned app appearance preferences, independent from guest bundles.
@MainActor final class LiveBoardAppCustomization: ObservableObject {
    static let shared = LiveBoardAppCustomization()
    @Published private(set) var revision = 0

    private let storage = BloomBoxAppAppearanceStorage(defaults: LCUtils.appGroupUserDefault)
    private let cache: NSCache<NSString, UIImage> = {
        let value = NSCache<NSString, UIImage>()
        value.totalCostLimit = 24 * 1024 * 1024
        return value
    }()
    private var cachedLayoutJSON: String?
    private var cachedAliases: [String: String] = [:]

    private init() { storage.migrateIfNeeded() }

    func name(_ app: LCAppModel) -> String {
        let key = liveBoardAppKey(app)
        if let title = storage.names[key], !title.isEmpty { return title }
        let layoutJSON = LCUtils.appGroupUserDefault.string(forKey: "LiveBoardHomeLayout") ?? ""
        if cachedLayoutJSON != layoutJSON {
            cachedAliases = LiveBoardHomeLayout.decode(layoutJSON).aliases
            cachedLayoutJSON = layoutJSON
        }
        return cachedAliases[key] ?? app.displayName
    }

    func rename(_ app: LCAppModel, to value: String) {
        let key = liveBoardAppKey(app)
        storage.updateName(value, for: key)
        var layout = LiveBoardHomeLayout.decode(
            LCUtils.appGroupUserDefault.string(forKey: "LiveBoardHomeLayout") ?? "")
        if layout.aliases.removeValue(forKey: key) != nil {
            let newJSON = layout.encoded
            LCUtils.appGroupUserDefault.set(newJSON, forKey: "LiveBoardHomeLayout")
            cachedLayoutJSON = newJSON
            cachedAliases = layout.aliases
        }
        revision += 1
    }

    func iconCacheIdentifier(_ app: LCAppModel) -> String {
        storage.iconFilename(for: liveBoardAppKey(app)) ?? "original"
    }

    func image(_ app: LCAppModel) -> UIImage? {
        guard let file = storage.iconFilename(for: liveBoardAppKey(app)),
              let url = storage.iconURL(for: liveBoardAppKey(app)) else { return nil }
        if let image = cache.object(forKey: file as NSString) { return image }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: file as NSString, cost: cost)
        return image
    }

    func saveIcon(_ image: UIImage, app: LCAppModel) throws {
        guard image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let side: CGFloat = 512
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { _ in
            let scale = side / min(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * scale,
                              height: image.size.height * scale)
            image.draw(in: CGRect(x: (side - size.width) / 2,
                                  y: (side - size.height) / 2,
                                  width: size.width, height: size.height))
        }
        guard let png = resized.pngData() else { throw CocoaError(.fileWriteUnknown) }
        let key = liveBoardAppKey(app)
        if let old = storage.iconFilename(for: key) {
            cache.removeObject(forKey: old as NSString)
        }
        let filename = try storage.writeIcon(png, for: key)
        let cost = (resized.cgImage?.bytesPerRow ?? 0) * (resized.cgImage?.height ?? 0)
        cache.setObject(resized, forKey: filename as NSString, cost: cost)
        revision += 1
    }

    func resetIcon(_ app: LCAppModel) {
        let key = liveBoardAppKey(app)
        if let filename = storage.iconFilename(for: key) {
            cache.removeObject(forKey: filename as NSString)
        }
        storage.removeIcon(for: key)
        revision += 1
    }
}

struct LiveBoardAppearanceSelection: Identifiable {
    let app: LCAppModel
    var id: String { liveBoardAppKey(app) }
}

struct LiveBoardAppAppearance: View {
    let app: LCAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    @State private var name = ""
    @State private var choosingIcon = false
    @State private var error: String?
    var body: some View {
        NavigationView {
            Form {
                Section("App name") {
                    TextField("Name", text: $name).accessibilityIdentifier("appearance.name")
                        .submitLabel(.done).onSubmit { customization.rename(app, to: name); UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    Button("Save name") { customization.rename(app, to: name); name = customization.name(app) }.accessibilityIdentifier("appearance.saveName")
                    Button("Restore original name") { customization.rename(app, to: ""); name = customization.name(app) }
                }
                Section("App icon") {
                    LiveBoardIconImage(app: app, dark: false).frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 16))
                    Button("Choose image from Photos") { choosingIcon = true }.accessibilityIdentifier("appearance.chooseIcon")
                    Button("Restore original icon") { customization.resetIcon(app) }
                    Text("Names and icons appear in all three interfaces. Console cover artwork stays separate.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("App appearance")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.navigationViewStyle(.stack)
        .onAppear { name = customization.name(app) }
        .sheet(isPresented: $choosingIcon) {
            LiveBoardWallpaperPicker { image in
                if let image { do { try customization.saveIcon(image, app: app) } catch { self.error = error.localizedDescription } }
                choosingIcon = false
            }
        }
    }
}
