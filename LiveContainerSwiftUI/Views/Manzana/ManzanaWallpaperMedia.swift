import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Imports into app-owned storage; never holds a transient document-provider URL.
enum ManzanaWallpaperMedia {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true)
    }
    static func url(_ name: String) -> URL? {
        guard name.hasPrefix("motion-"), name == (name as NSString).lastPathComponent else { return nil }
        return directory.appendingPathComponent(name)
    }
    static func importFile(_ source: URL) throws -> String {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent("motion-" + UUID().uuidString + "." + source.pathExtension.lowercased())
        do {
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                do {
                    let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 200 * 1024 * 1024 else { throw failure("Elige un archivo de hasta 200 MB.") }
                    try fm.copyItem(at: readable, to: staging)
                } catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            if staging.pathExtension == "gif" {
                _ = try gifFrames(staging)
            } else {
                let asset = AVURLAsset(url: staging)
                guard asset.isPlayable, !asset.tracks(withMediaType: .video).isEmpty,
                      asset.duration.seconds.isFinite, asset.duration.seconds > 0 else {
                    throw failure("No se pudo reproducir ese video. Prueba un MP4 o MOV compatible con tu iPhone.")
                }
            }
            return staging.lastPathComponent
        } catch { try? fm.removeItem(at: staging); throw error }
    }
    static func failure(_ message: String) -> NSError { NSError(domain: "ManzanaWallpaper", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    static func gifFrames(_ url: URL) throws -> ([CGImage], [NSNumber], Double) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier else { throw failure("El GIF no es válido.") }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 500 else { throw failure("Este GIF tiene demasiados cuadros. Usa uno de hasta 500.") }
        // Conservative square bound: at most 48 MB of decoded frame pixels.
        let dimension = min(720, max(64, Int(sqrt(Double(48 * 1024 * 1024 / (count * 4))))))
        var frames: [CGImage] = []; var times: [Double] = []; var duration = 0.0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: dimension,
                kCGImageSourceCreateThumbnailWithTransform: true
            ] as CFDictionary) else { throw failure("No se pudo leer un cuadro del GIF.") }
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            frames.append(frame); times.append(duration); duration += delay >= 0.02 ? delay : 0.1
        }
        return (frames, times.map { NSNumber(value: $0 / duration) }, duration)
    }
}

