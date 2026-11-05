import SwiftUI
import ImageIO

/// User-selected console artwork lives separately from emulated app bundles.
/// Previous LiveBoard files remain readable, and preference migration is safe to retry.
@MainActor final class BloomBoxArtworkLibrary: ObservableObject {
    enum Kind: String { case cover, portrait, background }

    @Published private(set) var revision = 0

    private let defaults = LCUtils.appGroupUserDefault
    private let cache: NSCache<NSString, UIImage> = {
        let images = NSCache<NSString, UIImage>()
        images.totalCostLimit = 40 * 1024 * 1024
        return images
    }()
    private let namesKey = "BloomBoxConsoleArtwork"
    private let legacyNamesKey = "LiveBoardConsoleArtwork"
    private let migrationKey = "BloomBoxConsoleArtworkMigrated"

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/Artwork", isDirectory: true)
    }

    private var legacyDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard/Artwork", isDirectory: true)
    }

    init() {
        migratePreferences()
        pruneUnreferencedArtwork()
    }

    // Only generated JPGs in our own artwork directory are eligible.
    // A failed save can leave a file behind after an interruption; clean
    // stale orphans without ever touching installed games or legacy files.
    private func pruneUnreferencedArtwork() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let referenced = Set(mappings.values)
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for file in files where Self.safeFile(file.lastPathComponent)
            && !referenced.contains(file.lastPathComponent) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantFuture
            if modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func dictionary(for key: String) -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    private func migratePreferences() {
        guard !defaults.bool(forKey: migrationKey) else { return }
        var current = dictionary(for: namesKey)
        for (key, file) in dictionary(for: legacyNamesKey)
            where current[key] == nil && Self.safeFile(file) {
            current[key] = file
        }
        defaults.set(current, forKey: namesKey)
        defaults.set(true, forKey: migrationKey)
    }

    private var mappings: [String: String] {
        dictionary(for: namesKey)
    }

    private static func safeFile(_ filename: String) -> Bool {
        !filename.isEmpty && filename.count < 150 &&
        filename == (filename as NSString).lastPathComponent &&
        !filename.hasPrefix(".") && filename.lowercased().hasSuffix(".jpg")
    }

    private func fileURL(_ filename: String) -> URL? {
        guard Self.safeFile(filename) else { return nil }
        let current = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: current.path) { return current }
        let former = legacyDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: former.path) ? former : nil
    }

    // Decode only at display size. Full-size game artwork previously decoded
    // several 2400px images simultaneously while SwiftUI blurred the backdrop.
    private func downsampled(_ url: URL, maxPixels: Int) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let thumb: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumb as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func cacheCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else {
            return Int(max(1, image.size.width * image.scale) *
                       max(1, image.size.height * image.scale) * 4)
        }
        return cg.bytesPerRow * cg.height
    }

    private func identifier(_ key: String, kind: Kind, mode: String) -> String {
        mode + ":" + kind.rawValue + ":" + key
    }

    func image(for key: String, kind: Kind, mode: String = "bigPicture") -> UIImage? {
        let id = identifier(key, kind: kind, mode: mode)
        if let cached = cache.object(forKey: id as NSString) { return cached }
        let filename = mappings[id] ?? (mode == "bigPicture" ? mappings[kind.rawValue + ":" + key] : nil)
        guard let filename, let path = fileURL(filename),
              let image = downsampled(path, maxPixels: kind == .background ? 1440 : 720) else { return nil }
        cache.setObject(image, forKey: id as NSString, cost: cacheCost(image))
        return image
    }

    func save(_ image: UIImage, for key: String, kind: Kind, mode: String = "bigPicture") throws {
        guard image.size.width.isFinite && image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let scale = min(1, 1800 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRendererFormat()
        renderer.scale = 1
        let thumbnail = UIGraphicsImageRenderer(size: size, format: renderer).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = thumbnail.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)

        let id = identifier(key, kind: kind, mode: mode)
        var updated = mappings
        let old = updated.updateValue(filename, forKey: id)
        var previous = [old].compactMap { $0 }
        if mode == "bigPicture", let original = updated.removeValue(forKey: kind.rawValue + ":" + key) {
            previous.append(original)
        }
        defaults.set(updated, forKey: namesKey)
        for previousFile in Set(previous) { deleteUnused(previousFile, map: updated) }
        if let fitted = downsampled(directory.appendingPathComponent(filename),
                                   maxPixels: kind == .background ? 1440 : 720) {
            cache.setObject(fitted, forKey: id as NSString, cost: cacheCost(fitted))
        }
        revision += 1
    }

    /// Release decoded images immediately if iOS warns about memory pressure.
    /// Files and saved mappings stay intact for the next safe launch.
    func clearDecodedCache() {
        cache.removeAllObjects()
        revision &+= 1
    }

    func remove(for key: String, kind: Kind, mode: String = "bigPicture") {
        let id = identifier(key, kind: kind, mode: mode)
        var updated = mappings
        var deleted = [updated.removeValue(forKey: id)].compactMap { $0 }
        if mode == "bigPicture", let original = updated.removeValue(forKey: kind.rawValue + ":" + key) {
            deleted.append(original)
        }
        defaults.set(updated, forKey: namesKey)
        for filename in Set(deleted) { deleteUnused(filename, map: updated) }
        cache.removeObject(forKey: id as NSString)
        revision += 1
    }

    private func deleteUnused(_ filename: String, map: [String: String]) {
        guard Self.safeFile(filename), !map.values.contains(filename) else { return }
        // Keep original LiveBoard files for rollbacks; only remove our own writes.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
