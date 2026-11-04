import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// BloomBox-owned media: new wallpapers are stored separately, while older
/// LiveBoard files remain accessible without duplicating large video assets.
enum BloomBoxMotionMedia {
    private static let maxFileBytes = 200 * 1024 * 1024
    private static let supported: Set<String> = ["gif", "mp4", "mov", "m4v"]
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/Wallpapers", isDirectory: true)
    }
    static var oldDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true)
    }

    private static func validName(_ name: String) -> Bool {
        guard name.count <= 128, name == (name as NSString).lastPathComponent,
              name.hasPrefix("motion-"), !name.hasPrefix("."),
              let ext = name.split(separator: ".").last.map(String.init),
              supported.contains(ext.lowercased()) else { return false }
        let stem = String(name.dropLast(ext.count + 1))
        return stem.count > 7 && stem.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
    }

    static func resolve(_ name: String, current: URL, legacy: URL) -> URL? {
        guard validName(name) else { return nil }
        let latest = current.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: latest.path) { return latest }
        let previous = legacy.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: previous.path) ? previous : nil
    }
    static func url(_ name: String) -> URL? {
        resolve(name, current: directory, legacy: oldDirectory)
    }
    static func remove(_ name: String) {
        guard validName(name) else { return }
        for folder in [directory, oldDirectory] {
            let item = folder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: item.path) {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }
    static func failure(_ message: String) -> NSError {
        NSError(domain: "BloomBoxWallpaper", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func importFile(_ source: URL, fileExtension: String? = nil) throws -> String {
        let ext = (fileExtension ?? source.pathExtension).lowercased()
        guard supported.contains(ext) else {
            throw failure("Elige un GIF o video MP4/MOV compatible.")
        }
        let secured = source.startAccessingSecurityScopedResource()
        defer { if secured { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("motion-" + UUID().uuidString + "." + ext)
        do {
            var coordinatorError: NSError?
            var readingError: Error?
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinatorError) { readable in
                do {
                    let size = (try? readable.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    guard size > 0, size <= maxFileBytes else {
                        throw failure("El archivo debe tener máximo 200 MB.")
                    }
                    try fm.copyItem(at: readable, to: destination)
                } catch { readingError = error }
            }
            if let coordinatorError { throw coordinatorError }
            if let readingError { throw readingError }
            let attributes = try fm.attributesOfItem(atPath: destination.path)
            let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard bytes > 0 && bytes <= maxFileBytes else {
                throw failure("El archivo supera el límite de 200 MB.")
            }
            if ext == "gif" {
                _ = try gifFrames(destination)
            } else {
                let video = AVURLAsset(url: destination)
                guard video.isPlayable, !video.tracks(withMediaType: .video).isEmpty,
                      video.duration.seconds.isFinite, video.duration.seconds > 0 else {
                    throw failure("El video no se puede reproducir en este iPhone.")
                }
            }
            return destination.lastPathComponent
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }

    static func gifFrames(_ url: URL) throws -> ([CGImage], [NSNumber], Double) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == UTType.gif.identifier else { throw failure("El GIF no es válido.") }
        let count = CGImageSourceGetCount(source)
        guard count > 0 && count <= 500 else {
            throw failure("Este GIF tiene demasiados cuadros.")
        }
        // Conservative 48 MB upper bound for decoded thumbnail pixels.
        let budget = max(1, 48 * 1024 * 1024 / (count * 4))
        let side = min(720, max(32, Int(Double(budget).squareRoot())))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side
        ]
        var frames: [CGImage] = []
        var offsets: [Double] = []
        var elapsed = 0.0
        for index in 0..<count {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
                throw failure("No se pudo leer un cuadro del GIF.")
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            offsets.append(elapsed)
            elapsed += delay.isFinite && delay >= 0.02 ? min(delay, 10) : 0.1
            frames.append(image)
        }
        return (frames, offsets.map { NSNumber(value: $0 / elapsed) }, elapsed)
    }
}
