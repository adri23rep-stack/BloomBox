import SwiftUI

/// User-owned artwork stays outside executable guest bundles.
final class LiveBoardArtworkStore: ObservableObject {
    enum Kind: String { case cover, portrait, background }
    @Published private(set) var revision = 0
    private let defaults = LCUtils.appGroupUserDefault
    // Evict decoded artwork under pressure instead of retaining every visited cover.
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()
    private var mappings: [String: String] { defaults.dictionary(forKey: "LiveBoardConsoleArtwork") as? [String: String] ?? [:] }
    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard/Artwork", isDirectory: true)
    }
    func image(for key: String, kind: Kind, mode: String = "bigPicture") -> UIImage? {
        let id = mode + ":" + kind.rawValue + ":" + key
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let filename = mappings[id] ?? (mode == "bigPicture" ? mappings[kind.rawValue + ":" + key] : nil), let image = UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) else { return nil }
        cache.setObject(image, forKey: id as NSString, cost: imageCost(image)); return image
    }
    private func imageCost(_ image: UIImage) -> Int {
        if let cg = image.cgImage { return cg.bytesPerRow * cg.height }
        return Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4
    }
    func save(_ image: UIImage, for key: String, kind: Kind, mode: String = "bigPicture") throws {
        let factor = min(1, 2400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = mode + ":" + kind.rawValue + ":" + key
        let filename = UUID().uuidString + ".jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        var map = mappings
        var previousFiles = [map[id]].compactMap { $0 }
        if mode == "bigPicture", let legacy = map.removeValue(forKey: kind.rawValue + ":" + key) { previousFiles.append(legacy) }
        for previous in Set(previousFiles) { try? FileManager.default.removeItem(at: directory.appendingPathComponent(previous)) }
        map[id] = filename; defaults.set(map, forKey: "LiveBoardConsoleArtwork")
        cache.setObject(resized, forKey: id as NSString, cost: imageCost(resized)); revision += 1
    }
    func remove(for key: String, kind: Kind, mode: String = "bigPicture") {
        let id = mode + ":" + kind.rawValue + ":" + key
        var map = mappings
        var removed = [map.removeValue(forKey: id)].compactMap { $0 }
        if mode == "bigPicture", let legacy = map.removeValue(forKey: kind.rawValue + ":" + key) { removed.append(legacy) }
        for filename in Set(removed) { try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename)) }
        defaults.set(map, forKey: "LiveBoardConsoleArtwork"); cache.removeObject(forKey: id as NSString); revision += 1
    }
}
